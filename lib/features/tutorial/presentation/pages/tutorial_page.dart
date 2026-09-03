import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../data/providers/tutorial_providers.dart';
import '../../domain/catalog/tutorial_instruction_catalog.dart';
import '../../domain/entities/canonical_preview_ref.dart';
import '../../domain/entities/tutorial_step.dart';
import '../controllers/tutorial_controller.dart';
import '../controllers/tutorial_state.dart';
import '../utils/tutorial_image_focus.dart';
import '../utils/tutorial_labels.dart';
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
    final content = switch (state.status) {
      TutorialStatus.idle ||
      TutorialStatus.opening ||
      TutorialStatus.analyzingManifest => const LoadingState(
        label: TutorialLabels.preparingTutorial,
      ),
      TutorialStatus.kitPreviewMismatch => StatusState(
        title: TutorialLabels.emptyTitle,
        message: state.message ?? TutorialLabels.emptyMessage,
        icon: Icons.info_outline,
      ),
      TutorialStatus.failed when state.session == null => StatusState(
        title: TutorialLabels.guidelineUnavailable,
        message: state.message ?? '',
        icon: Icons.error_outline,
        actionLabel: state.retryable ? TutorialLabels.retry : null,
        onAction: state.retryable
            ? () => _controller.open(widget.preview)
            : null,
      ),
      _ when state.stepCount == 0 => const StatusState(
        title: TutorialLabels.emptyTitle,
        message: TutorialLabels.emptyMessage,
        icon: Icons.inbox_outlined,
      ),
      _ => _TutorialBody(
        state: state,
        finalPreviewUrl: widget.finalPreviewUrl,
        onNext: _next,
        onPrevious: _controller.previous,
        onRetry: _controller.generateCurrentStep,
        onRedraw: _controller.regenerateCurrentStep,
      ),
    };
    return Scaffold(
      // Tutorial is a top-level GoRoute, so it must provide its own Material
      // page surface. Without a Scaffold the route was transparent and the
      // navigator's black backing showed through in Light, Dark, and System.
      // This colour remains wholly owned by the active global ColorScheme.
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(child: PageFrame(child: content)),
    );
  }
}

class _TutorialBody extends StatelessWidget {
  const _TutorialBody({
    required this.state,
    required this.finalPreviewUrl,
    required this.onNext,
    required this.onPrevious,
    required this.onRetry,
    required this.onRedraw,
  });

  final TutorialViewState state;
  final String? finalPreviewUrl;
  final Future<void> Function() onNext;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onRetry;
  final Future<void> Function() onRedraw;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = state.currentCategory!;
    final instructions = TutorialInstructionCatalog.forCategory(category);
    return ListView(
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            TutorialLabels.stepProgress(state.stepNumber, state.stepCount),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.muted(context),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          TutorialLabels.categoryName(category),
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        LinearProgressIndicator(
          value: state.stepCount == 0 ? 0 : state.stepNumber / state.stepCount,
          // Scheme-derived so the unfilled track stays a quiet surface in both
          // themes; the fixed sand tint read as a light bar on a dark page.
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          semanticsLabel: TutorialLabels.stepProgress(
            state.stepNumber,
            state.stepCount,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _GuidelineView(state: state, onRetry: onRetry),
        const SizedBox(height: AppSpacing.sm),
        TutorialGuideKey(types: instructions.referencedGuideTypes),
        // The final look sits immediately under the guideline, so the two
        // questions a step raises — where does this go, what should it end up
        // looking like — are answered next to each other rather than one of
        // them being five steps away.
        if (finalPreviewUrl != null && !state.isLastStep) ...[
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
        // The last step keeps the full-size presentation it has always had:
        // there is nothing left to apply, so the finished look is the content
        // of the step rather than a reference beside it.
        if (state.isLastStep && finalPreviewUrl != null) ...[
          const SizedBox(height: AppSpacing.lg),
          TutorialFinalLookCard(url: finalPreviewUrl!, expanded: true),
        ],
        const SizedBox(height: AppSpacing.lg),
        _controls(context),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: TextButton(
            // Confirmed before it spends anything. This used to regenerate on
            // a single tap, on a scrolling page, with no warning — which made
            // an accidental brush against it cost a paid image.
            onPressed: state.hasCurrentGuideline
                ? () => _confirmRedraw(context)
                : null,
            child: const Text(TutorialLabels.redraw),
          ),
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

  Widget _controls(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final back = SecondaryButton(
        label: TutorialLabels.back,
        onPressed: state.currentIndex == 0 ? null : () => onPrevious(),
      );
      final next = PrimaryButton(
        label: state.isLastStep ? TutorialLabels.finish_ : TutorialLabels.next,
        onPressed: state.isLastStep
            ? () => Navigator.of(context).maybePop()
            : () => onNext(),
      );
      final scaledBodySize = MediaQuery.textScalerOf(context).scale(14);
      if (constraints.maxWidth < 360 || scaledBodySize > 20) {
        return Column(
          children: [
            back,
            const SizedBox(height: AppSpacing.xs),
            next,
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: back),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: next),
        ],
      );
    },
  );
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
          child: StatusState(
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
          child: StatusState(
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
            child: PrivateImage(
              url: url,
              semanticLabel: TutorialLabels.guidelineImageLabel(category),
              errorChild: SingleChildScrollView(
                child: StatusState(
                  title: TutorialLabels.imageUnavailable,
                  message: '',
                  icon: Icons.image_not_supported_outlined,
                  actionLabel: TutorialLabels.retry,
                  onAction: () => onRetry(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// The canonical final preview is rendered by TutorialFinalLookCard, which
// replaced the private _FinalPreview widget that used to live here. The two
// presentations it now covers — a compact reference on every step and the
// full-size image on the last — read the same signed URL for the same
// canonical artifact, so there is still exactly one final preview per look.
