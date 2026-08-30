import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../data/providers/tutorial_providers.dart';
import '../../domain/entities/canonical_preview_ref.dart';
import '../../domain/entities/tutorial_step.dart';
import '../controllers/tutorial_controller.dart';
import '../controllers/tutorial_state.dart';
import '../utils/tutorial_labels.dart';
import '../widgets/tutorial_product_cards.dart';

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
    return PageFrame(
      child: switch (state.status) {
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
      },
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
    final category = state.currentCategory!;
    return ListView(
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            TutorialLabels.stepProgress(state.stepNumber, state.stepCount),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.taupe),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          TutorialLabels.categoryName(category),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        LinearProgressIndicator(
          value: state.stepCount == 0 ? 0 : state.stepNumber / state.stepCount,
          backgroundColor: AppColors.sand,
          semanticsLabel: TutorialLabels.stepProgress(
            state.stepNumber,
            state.stepCount,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _GuidelineView(state: state, onRetry: onRetry),
        const SizedBox(height: AppSpacing.lg),
        _instructions(context),
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
        if (state.isLastStep && finalPreviewUrl != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _FinalPreview(url: finalPreviewUrl!),
        ],
        const SizedBox(height: AppSpacing.lg),
        _controls(context),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: TextButton(
            onPressed: state.hasCurrentGuideline ? () => onRedraw() : null,
            child: const Text(TutorialLabels.redraw),
          ),
        ),
      ],
    );
  }

  /// Short structured guidance, taken from the validated recommendation.
  ///
  /// Standard Mode has placement and technique wording; My Makeup Kit steps
  /// rely on the drawn guideline plus the product card, so nothing is invented
  /// to fill the gap.
  Widget _instructions(BuildContext context) {
    final entries = state.session!.lookPlan.standardEntriesFor(
      state.currentCategory!,
    );
    if (entries.isEmpty) return const SizedBox.shrink();
    final entry = entries.first;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TutorialLabels.whereToApply,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(entry.placement),
          const SizedBox(height: AppSpacing.sm),
          Text(
            TutorialLabels.howToApply,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(entry.technique),
        ],
      ),
    );
  }

  Widget _controls(BuildContext context) => Row(
    children: [
      Expanded(
        child: SecondaryButton(
          label: TutorialLabels.back,
          onPressed: state.currentIndex == 0 ? null : () => onPrevious(),
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: PrimaryButton(
          label: state.isLastStep
              ? TutorialLabels.finish_
              : TutorialLabels.next,
          onPressed: state.isLastStep
              ? () => Navigator.of(context).maybePop()
              : () => onNext(),
        ),
      ),
    ],
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
        child: StatusState(
          title: TutorialLabels.guidelineUnavailable,
          message: state.message ?? TutorialLabels.imageUnavailable,
          icon: Icons.image_not_supported_outlined,
          actionLabel: state.retryable ? TutorialLabels.retry : null,
          onAction: state.retryable ? () => onRetry() : null,
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
        child: StatusState(
          title: TutorialLabels.guidelineUnavailable,
          message: state.message ?? TutorialLabels.imageUnavailable,
          icon: Icons.image_not_supported_outlined,
          actionLabel: TutorialLabels.retry,
          onAction: () => onRetry(),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: PrivateImage(
          url: url,
          semanticLabel: TutorialLabels.guidelineImageLabel(category),
          errorChild: StatusState(
            title: TutorialLabels.imageUnavailable,
            message: '',
            icon: Icons.image_not_supported_outlined,
            actionLabel: TutorialLabels.retry,
            onAction: () => onRetry(),
          ),
        ),
      ),
    );
  }
}

/// The canonical final preview, reused rather than regenerated.
class _FinalPreview extends StatelessWidget {
  const _FinalPreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        TutorialLabels.yourFinalLook,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: AppSpacing.xs),
      ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: PrivateImage(
            url: url,
            semanticLabel: TutorialLabels.yourFinalLook,
          ),
        ),
      ),
    ],
  );
}
