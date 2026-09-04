import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../../data/providers/tutorial_providers.dart';
import '../../domain/catalog/tutorial_instruction_catalog.dart';
import '../../domain/entities/canonical_preview_ref.dart';
import '../../domain/entities/tutorial_step.dart';
import '../controllers/tutorial_controller.dart';
import '../controllers/tutorial_state.dart';
import '../utils/tutorial_image_focus.dart';
import '../utils/tutorial_labels.dart';
import '../widgets/tutorial_bottom_navigation.dart';
import '../widgets/tutorial_final_look_card.dart';
import '../widgets/tutorial_guide_key.dart';
import '../widgets/tutorial_image_viewer.dart';
import '../widgets/tutorial_instructions_card.dart';
import '../widgets/tutorial_redraw_sheet.dart';
import '../widgets/tutorial_product_cards.dart';

/// The guideline image's full-screen tap target.
///
/// Named so a test can press the thing the user presses. The alternative —
/// finding an `InkWell` by type — would also match every card on the page, and
/// would keep passing while pressing the wrong one.
@visibleForTesting
const Key guidelineViewerTapKey = Key('tutorial.guideline.openViewer');

/// Navigation arguments for [TutorialPage].
///
/// A typed object rather than a loose map, so a caller cannot route to a
/// tutorial with a preview id but no source mode — the pair is meaningless
/// apart, since the mode decides which table holds the preview.
class TutorialPageArgs {
  const TutorialPageArgs({required this.preview, this.finalPreviewUrl});

  final CanonicalPreviewRef preview;

  /// A signed URL for the canonical final preview, so the end of the tutorial
  /// reuses the image the user already has rather than generating anything.
  final String? finalPreviewUrl;
}

/// The step-by-step tutorial for one canonical final preview.
///
/// Generation is started from [initState], never from `build`. That separation
/// is the whole reason the page is stateful: a build can run many times for
/// reasons that have nothing to do with intent — a keyboard opening, a theme
/// change, a parent rebuilding — and every one of those would otherwise be a
/// paid AI call.
class TutorialPage extends ConsumerStatefulWidget {
  const TutorialPage({required this.preview, this.finalPreviewUrl, super.key});

  final CanonicalPreviewRef preview;

  /// The canonical final preview, reused at the end of the tutorial rather than
  /// generated again. Null when the caller has no signed URL to hand over.
  final String? finalPreviewUrl;

  @override
  ConsumerState<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends ConsumerState<TutorialPage> {
  @override
  void initState() {
    super.initState();
    // Deferred to after the first frame so the provider is not mutated during
    // widget construction. `open` is idempotent, so a rebuild that somehow
    // reached here again would cost nothing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(tutorialControllerProvider.notifier);
      controller.open(widget.preview).then((_) {
        if (!mounted) return;
        controller.generateCurrentStep();
      });
    });
  }

  TutorialController get _controller =>
      ref.read(tutorialControllerProvider.notifier);

  Future<void> _next() async {
    final state = ref.read(tutorialControllerProvider);
    if (state.isLastStep) {
      await _controller.goToStep(state.currentIndex);
      return;
    }
    await _controller.next();
    // Prefetch exactly one step ahead, after the user has shown they are moving
    // forward. Never on open, so a user who views one step pays for one step.
    await _controller.prefetchNext();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tutorialControllerProvider);
    // Body and footer are decided by one switch rather than two, so there is no
    // way for the page to show a step without its navigation, or navigation
    // over a loading spinner. A null footer means "this is not a step".
    final (Widget content, Widget? footer) = switch (state.status) {
      TutorialStatus.idle ||
      TutorialStatus.opening ||
      TutorialStatus.analyzingManifest => (
        const LoadingState(label: TutorialLabels.preparingTutorial),
        null,
      ),
      // A modelled outcome, not a fault: the preview legitimately contains a
      // category the kit cannot reproduce. Same tone the Makeup Breakdown gives
      // the identical situation, so the two screens agree about what it means.
      TutorialStatus.kitPreviewMismatch => (
        StatusState(
          tone: AppTone.warning,
          title: TutorialLabels.emptyTitle,
          message: state.message ?? TutorialLabels.emptyMessage,
          icon: Icons.info_outline,
        ),
        null,
      ),
      TutorialStatus.failed when state.session == null => (
        StatusState.error(
          title: TutorialLabels.guidelineUnavailable,
          message: state.message ?? '',
          actionLabel: state.retryable ? TutorialLabels.retry : null,
          onAction: state.retryable
              ? () => _controller.open(widget.preview)
              : null,
        ),
        null,
      ),
      // A look with no steps is an absence, not a failure.
      _ when state.stepCount == 0 => (
        const StatusState.empty(
          title: TutorialLabels.emptyTitle,
          message: TutorialLabels.emptyMessage,
        ),
        null,
      ),
      _ => (
        _TutorialBody(
          state: state,
          finalPreviewUrl: widget.finalPreviewUrl,
          onRetry: _controller.generateCurrentStep,
          onRedraw: _controller.regenerateCurrentStep,
        ),
        TutorialBottomNavigation(
          // Both flags come from the accepted manifest's own category list, by
          // way of the view state. Neither the footer nor this page counts
          // steps for itself, and neither knows which category is last.
          isLastStep: state.isLastStep,
          canGoBack: state.currentIndex > 0,
          onBack: () => _controller.previous(),
          onNext: () => _next(),
          // The same `maybePop` Finish has always called, so finishing and
          // closing leave by one path — and neither cancels, restarts, or
          // regenerates anything.
          onFinish: () => Navigator.of(context).maybePop(),
        ),
      ),
    };
    return Scaffold(
      // Tutorial is a top-level GoRoute, so it must provide its own Material
      // page surface. Without a Scaffold the route was transparent and the
      // navigator's black backing showed through in Light, Dark, and System.
      // This colour remains wholly owned by the active global ColorScheme.
      backgroundColor: Theme.of(context).colorScheme.surface,
      // The way out. Until now a user on step 3 of 8 had no on-screen way to
      // leave — the in-page Back button moves to the previous *step*, and on
      // step 1 it is disabled, so the only exit was the Android system gesture.
      //
      // Deliberately a close cross rather than the default back arrow: an arrow
      // in the corner next to a "Back" button in the page would be two
      // retreats that mean different things wearing the same icon. This one
      // leaves the tutorial; that one moves within it.
      //
      // `maybePop` is what the Finish button already calls, so leaving early
      // and finishing exit by the identical path — and neither cancels,
      // restarts, or regenerates anything.
      appBar: AppBar(
        leading: Semantics(
          button: true,
          label: TutorialLabels.closeTutorial,
          excludeSemantics: true,
          child: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: TutorialLabels.closeTutorial,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      body: SafeArea(
        child: PageFrame(
          // `PageFrame`'s generous bottom tail exists, by its own account, so a
          // screen's last element clears the navigation bar and the gesture
          // area. The footer's own `SafeArea` now does that job, and keeping
          // both would reserve the same space twice. A normal gap remains, so
          // the last content still stands off the strip's rule rather than
          // butting against it.
          padding: footer == null
              ? PageFrame.defaultPadding
              : PageFrame.defaultPadding.copyWith(bottom: AppSpacing.md),
          child: content,
        ),
      ),
      // Persistent, in reserved layout space, and outside the scroll view. The
      // body is measured against what is left after this, so there is no scroll
      // position at which content hides underneath it.
      bottomNavigationBar: footer,
    );
  }
}

/// The scrollable part of a step.
///
/// Step navigation is deliberately not here any more: it lives in the
/// Scaffold's bottom slot as [TutorialBottomNavigation], so this list is only
/// ever about the content of the step. Redraw stays in this content beside the
/// guide it replaces rather than sitting permanently under the user's thumb
/// next to Next.
class _TutorialBody extends StatelessWidget {
  const _TutorialBody({
    required this.state,
    required this.finalPreviewUrl,
    required this.onRetry,
    required this.onRedraw,
  });

  final TutorialViewState state;
  final String? finalPreviewUrl;
  final Future<void> Function() onRetry;
  final Future<void> Function() onRedraw;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = state.currentCategory!;
    final instructions = TutorialInstructionCatalog.forCategory(category);
    return ListView(
      children: [
        // Where am I, and how far through. The counter and the bar say the same
        // thing, so they sit together rather than straddling the title — which
        // used to leave the bar reading as a divider under the heading instead
        // of as progress through the tutorial.
        _StepProgressHeader(
          stepNumber: state.stepNumber,
          stepCount: state.stepCount,
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          header: true,
          child: Text(
            TutorialLabels.categoryName(category),
            style: theme.textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _GuidelineView(state: state, onRetry: onRetry),
        // The key explains marks drawn on the image directly above it, so it is
        // tucked tight against it rather than floating a full gap away where it
        // read as an unrelated panel.
        const SizedBox(height: AppSpacing.xs),
        TutorialGuideKey(types: instructions.referencedGuideTypes),
        const SizedBox(height: AppSpacing.xxs),
        Align(
          alignment: Alignment.centerLeft,
          // Confirmed before it spends anything. Keeping this beside the guide
          // makes the object of the action clear, while tertiary emphasis keeps
          // it distinct from the free tutorial navigation in the footer.
          child: TertiaryButton(
            label: TutorialLabels.redrawGuide,
            icon: Icons.refresh_rounded,
            onPressed: state.hasCurrentGuideline
                ? () => _confirmRedraw(context)
                : null,
          ),
        ),
        // The final look sits immediately under the guideline, so the two
        // questions a step raises — where does this go, what should it end up
        // looking like — are answered next to each other rather than one of
        // them being five steps away.
        if (finalPreviewUrl != null) ...[
          const SizedBox(height: AppSpacing.sm),
          TutorialFinalLookCard(url: finalPreviewUrl!),
        ],
        const SizedBox(height: AppSpacing.lg),
        TutorialInstructionsCard(instructions: instructions, goal: _goal()),
        const SizedBox(height: AppSpacing.md),
        if (state.isMyMakeupKit)
          MyMakeupKitProductCard(
            // Prefer the step's own items, but fall back to the look plan when
            // they are empty. A step loaded outside a full session carries no
            // products, and showing nothing there would hide products the user
            // definitely selected.
            items: switch (state.currentStep?.productSnapshotItems) {
              final items? when items.isNotEmpty => items,
              _ => state.session!.lookPlan.productSnapshot.itemsFor(category),
            },
          )
        else
          StandardProductCard(
            entries: state.session!.lookPlan.standardEntriesFor(category),
          ),
      ],
    );
  }

  /// Asks before spending a generation, and only redraws if the user says yes.
  ///
  /// The sheet may offer a reason, but the reason never triggers anything — the
  /// confirm button is the only thing that does, and dismissing costs nothing.
  /// Every existing guard still applies afterwards: quota, the server's
  /// attempt ceiling, and in-flight coalescing.
  Future<void> _confirmRedraw(BuildContext context) async {
    final confirmed = await TutorialRedrawSheet.confirm(
      context,
      attemptsUsed: state.currentStep?.generationAttempt ?? 0,
    );
    if (confirmed) await onRedraw();
  }

  /// The goal sentence for this step, or null when none is authoritative.
  ///
  /// Standard Mode carries the recommendation's own reasoning — a validated
  /// one-sentence account of what the category does in this look. My Makeup Kit
  /// records what the user owns, not why it was chosen, so it has no equivalent
  /// and a kit step shows no goal. Composing one from the style name or the
  /// category would be exactly the generic filler the quality contract forbids.
  String? _goal() {
    for (final entry in state.session!.lookPlan.standardEntriesFor(
      state.currentCategory!,
    )) {
      final reasoning = entry.reasoning?.trim();
      if (reasoning != null && reasoning.isNotEmpty) return reasoning;
    }
    return null;
  }
}

/// The 1K guideline image, with its loading, error, and retry states.
class _GuidelineView extends StatelessWidget {
  const _GuidelineView({required this.state, required this.onRetry});

  final TutorialViewState state;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final category = state.currentCategory!;
    final step = state.currentStep;
    final url = state.currentGuidelineUrl;

    // Failure is checked before the absent-step case. A generation that failed
    // before any row existed leaves `step` null, and treating that as "still
    // loading" would spin forever with no way to retry.
    if (state.status == TutorialStatus.failed) {
      return AspectRatio(
        aspectRatio: 3 / 4,
        child: SingleChildScrollView(
          child: StatusState.error(
            title: TutorialLabels.guidelineUnavailable,
            message: state.message ?? TutorialLabels.imageUnavailable,
            icon: Icons.image_not_supported_outlined,
            actionLabel: state.retryable ? TutorialLabels.retry : null,
            onAction: state.retryable ? () => onRetry() : null,
          ),
        ),
      );
    }
    if (state.status == TutorialStatus.generatingStep || step == null) {
      return const AspectRatio(
        aspectRatio: 3 / 4,
        child: LoadingState(label: TutorialLabels.drawingStep),
      );
    }
    if (step.status == TutorialStepStatus.failed || url == null) {
      return AspectRatio(
        aspectRatio: 3 / 4,
        child: SingleChildScrollView(
          child: StatusState.error(
            title: TutorialLabels.guidelineUnavailable,
            message: state.message ?? TutorialLabels.imageUnavailable,
            icon: Icons.image_not_supported_outlined,
            actionLabel: TutorialLabels.retry,
            onAction: () => onRetry(),
          ),
        ),
      );
    }
    // Tapping opens the same image full screen, at a zoom chosen for this
    // category. It is a viewing action over an artifact already on screen: no
    // request, no signing, and above all no generation.
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label:
          '${TutorialLabels.guidelineImageLabel(category)}. '
          '${TutorialLabels.tapToEnlarge}.',
      child: InkWell(
        key: guidelineViewerTapKey,
        onTap: () => TutorialImageViewer.open(
          context,
          url: url,
          title: TutorialLabels.categoryName(category),
          semanticLabel: TutorialLabels.guidelineImageLabel(category),
          focus: TutorialImageFocus.forCategory(category),
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PrivateImage(
                  url: url,
                  semanticLabel: TutorialLabels.guidelineImageLabel(category),
                  errorChild: SingleChildScrollView(
                    child: StatusState.error(
                      title: TutorialLabels.imageUnavailable,
                      message: '',
                      actionLabel: TutorialLabels.retry,
                      onAction: () => onRetry(),
                    ),
                  ),
                ),
                // The viewer entry affordance. Tapping the guideline has always
                // opened it full screen, but nothing on screen said so — the
                // Final Look card beside it carries a zoom icon and the same
                // words, so the more important image was the less discoverable
                // one.
                //
                // Bottom-left, small, and over the scrim: the guides a user
                // needs to read run across the face and down the right side of
                // it, and a corner chip must not sit on top of the thing being
                // taught.
                const Positioned(
                  left: AppSpacing.xs,
                  bottom: AppSpacing.xs,
                  child: _EnlargeHint(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Step 3 of 8" and the bar that shows the same thing.
///
/// Side by side at normal text sizes, stacked once the counter grows past what
/// can share a line with a usable bar. The counter is not flexible — shrinking
/// "Step 3 of 8" to fit would be the wrong sacrifice — so past that width the
/// two go on separate lines instead of one of them overflowing.
class _StepProgressHeader extends StatelessWidget {
  const _StepProgressHeader({
    required this.stepNumber,
    required this.stepCount,
  });

  final int stepNumber;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = TutorialLabels.stepProgress(stepNumber, stepCount);

    final counter = Semantics(
      liveRegion: true,
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: AppColors.muted(context),
        ),
      ),
    );

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: LinearProgressIndicator(
        value: stepCount == 0 ? 0 : stepNumber / stepCount,
        // Scheme-derived so the unfilled track stays a quiet surface in both
        // themes; the fixed sand tint read as a light bar on a dark page.
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        // The bar keeps its own spoken label. The counter beside it is a live
        // region — announced when it *changes* — which is a different job from
        // telling someone what this bar is when they land on it.
        semanticsLabel: label,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final counterWidth = _counterWidth(context, label, theme);
        // Leave the bar a width where it still reads as a bar rather than a
        // dash. Below that the pair stacks.
        final fitsOneLine =
            constraints.maxWidth - counterWidth - AppSpacing.sm >= 96;
        if (fitsOneLine) {
          return Row(
            children: [
              counter,
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: bar),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            counter,
            const SizedBox(height: AppSpacing.xs),
            bar,
          ],
        );
      },
    );
  }

  /// How wide the counter wants to be at the reader's current text size.
  static double _counterWidth(
    BuildContext context,
    String label,
    ThemeData theme,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: theme.textTheme.labelMedium),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.width;
  }
}

/// The "tap to enlarge" chip drawn over the guideline image.
///
/// Excluded from semantics on purpose: it sits inside the guideline's own
/// `Semantics(button: true, excludeSemantics: true)` node, whose label already
/// ends with "Tap to enlarge". Announcing it again would repeat the phrase to a
/// screen-reader user while telling a sighted user something new.
///
/// The scrim is what makes it legible: it floats over a generated portrait
/// whose brightness at that corner is unknowable, so the chip carries its own
/// ground rather than trusting the image beneath it.
class _EnlargeHint extends StatelessWidget {
  const _EnlargeHint();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .68),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.zoom_out_map,
              size: AppIconSizes.sm,
              color: Colors.white,
            ),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              TutorialLabels.tapToEnlarge,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    ),
  );
}

// The canonical final preview is rendered by TutorialFinalLookCard, which
// replaced the private _FinalPreview widget that used to live here. The two
// presentations it now covers — a compact reference on every step and the
// full-size image on the last — read the same signed URL for the same
// canonical artifact, so there is still exactly one final preview per look.
