import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../data/providers/tutorial_v3_providers.dart';
import '../../domain/entities/tutorial_v3_step.dart';
import '../../domain/entities/tutorial_v3_step_instructions.dart';
import '../../domain/entities/tutorial_v3_step_spec.dart';
import '../controllers/tutorial_v3_session_controller.dart';
import '../controllers/tutorial_v3_session_state.dart';
import '../utils/tutorial_v3_display.dart';
import '../widgets/tutorial_v3_guideline_view.dart';
import '../widgets/tutorial_v3_step_details.dart';
import '../widgets/tutorial_v3_step_navigation.dart';
import '../widgets/tutorial_v3_target_reference.dart';

/// The V3 tutorial screen.
///
/// ```text
/// STEP N OF TOTAL
/// CATEGORY
/// [ original selfie + personalized Flutter overlay ]
/// TARGET LOOK      [ canonical final preview ]
/// APPLY / WHERE / DIRECTION / TECHNIQUE / WHY / TIP
/// ← Previous                            Next →
/// ```
///
/// There is no Guidelines ↔ Result slider and no intermediate makeup-result
/// image, because V3 produces neither: a non-final step is the untouched
/// original photograph with a deterministic overlay, and the only "result"
/// that exists is the canonical preview shown as the target.
class TutorialV3Page extends ConsumerWidget {
  const TutorialV3Page({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tutorialV3SessionControllerProvider);
    final controller = ref.read(tutorialV3SessionControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Step-by-step tutorial')),
      body: SafeArea(
        child: switch (state.phase) {
          TutorialV3Phase.idle || TutorialV3Phase.opening => const Center(
            child: LoadingState(label: 'Opening your tutorial…'),
          ),
          TutorialV3Phase.planning => const Center(
            child: LoadingState(
              label: 'Building your personalized tutorial…',
              supportingText: 'This happens once per look.',
            ),
          ),
          TutorialV3Phase.failed => _Failure(
            state: state,
            onRetry: controller.retryOpen,
          ),
          TutorialV3Phase.ready => _Tutorial(
            state: state,
            controller: controller,
          ),
        },
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.state, required this.onRetry});

  final TutorialV3SessionState state;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => PageFrame(
    child: Center(
      child: StatusState(
        title: 'This tutorial could not be opened',
        message: state.message ?? 'Please try again.',
        icon: Icons.error_outline_rounded,
        liveRegion: true,
        actionLabel: state.retryable ? 'Try again' : null,
        onAction: state.retryable ? onRetry : null,
      ),
    ),
  );
}

class _Tutorial extends StatelessWidget {
  const _Tutorial({required this.state, required this.controller});

  final TutorialV3SessionState state;
  final TutorialV3SessionController controller;

  @override
  Widget build(BuildContext context) {
    final step = state.currentStep;
    if (step == null) {
      return const PageFrame(
        child: Center(
          child: StatusState(
            title: 'Nothing to show yet',
            message: 'This tutorial has no steps.',
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: PageFrame(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dynamic: the count comes from the persisted plan, which
                  // varies with the look and, in Kit mode, with what is owned.
                  Semantics(
                    header: true,
                    child: Text(
                      'STEP ${step.stepIndex} OF ${state.totalSteps}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        letterSpacing: 1.4,
                        color: AppColors.taupe,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    step.spec.category.label,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _StepImage(state: state, step: step, controller: controller),
                  const SizedBox(height: AppSpacing.lg),
                  _TargetLook(state: state, controller: controller),
                  const SizedBox(height: AppSpacing.lg),
                  _StepBody(step: step),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: TutorialV3StepNavigation(
            canGoPrevious: state.canGoPrevious,
            canGoNext: state.canGoNext,
            onPrevious: controller.previous,
            onNext: controller.next,
          ),
        ),
      ],
    );
  }
}

/// The image area: the canonical preview on the final step, the selfie plus
/// overlay on every other one.
class _StepImage extends StatelessWidget {
  const _StepImage({
    required this.state,
    required this.step,
    required this.controller,
  });

  final TutorialV3SessionState state;
  final TutorialV3Step step;
  final TutorialV3SessionController controller;

  @override
  Widget build(BuildContext context) {
    final images = state.images;

    if (state.imagesPhase == TutorialV3ImagesPhase.failed || images == null) {
      return _ImageFrame(
        child: state.imagesPhase == TutorialV3ImagesPhase.failed
            ? StatusState(
                title: 'Your photo could not be loaded',
                message: 'Check your connection and try again.',
                icon: Icons.image_not_supported_outlined,
                actionLabel: 'Try again',
                onAction: controller.retryImages,
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }

    // The final step reuses the premium canonical preview exactly as it is.
    // No overlay is drawn on it, because nothing is left to teach.
    if (step.isFinalLook) {
      return _ImageFrame(
        child: PrivateImage(
          url: images.canonicalPreviewUrl,
          fit: BoxFit.contain,
          semanticLabel: 'Your finished look',
        ),
      );
    }

    // The geometry's own loading and failure states are siblings of the
    // photograph, not children of it: a selfie that fails to load must not
    // also swallow the retry for a guideline that failed independently.
    return _ImageFrame(
      child: Stack(
        fit: StackFit.expand,
        children: [
          TutorialV3GuidelineView(
            image: NetworkImage(images.originalSelfieUrl),
            geometry: state.geometry,
            semanticLabel: state.hasOverlay
                ? 'Your photo with the guideline for this step'
                : 'Your photo',
          ),
          if (state.geometryPhase == TutorialV3StepGeometryPhase.loading)
            const _Scrim(child: CircularProgressIndicator()),
          if (state.geometryPhase == TutorialV3StepGeometryPhase.failed)
            _Scrim(
              child: _GeometryRetry(state: state, controller: controller),
            ),
        ],
      ),
    );
  }
}

class _ImageFrame extends StatelessWidget {
  const _ImageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadii.lg),
    child: AspectRatio(
      aspectRatio: 3 / 4,
      child: ColoredBox(color: AppColors.sand, child: child),
    ),
  );
}

/// A translucent layer over the selfie, so a spinner or a retry stays legible
/// without hiding the photograph underneath it.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.cocoa.withValues(alpha: 0.45),
    child: Center(child: child),
  );
}

class _GeometryRetry extends StatelessWidget {
  const _GeometryRetry({required this.state, required this.controller});

  final TutorialV3SessionState state;
  final TutorialV3SessionController controller;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.gesture_outlined,
            color: Colors.white,
            size: AppIconSizes.lg,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            // No universal fallback overlay is ever drawn: a missing guideline
            // is better than a confidently wrong one.
            state.message ?? 'The guideline for this step is not available.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
          if (state.canRetryGeometry) ...[
            const SizedBox(height: AppSpacing.sm),
            FilledButton.tonal(
              onPressed: controller.retryGeometry,
              child: const Text('Try again'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _TargetLook extends StatelessWidget {
  const _TargetLook({required this.state, required this.controller});

  final TutorialV3SessionState state;
  final TutorialV3SessionController controller;

  @override
  Widget build(BuildContext context) {
    final images = state.images;
    // On the final step the canonical preview is already the main image, so
    // repeating it as a reference below itself would be noise.
    if (images == null || state.isFinalStep) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'TARGET LOOK',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: AppColors.taupe,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TutorialV3TargetReference(imageUrl: images.canonicalPreviewUrl),
      ],
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({required this.step});

  final TutorialV3Step step;

  @override
  Widget build(BuildContext context) {
    final spec = step.spec;
    return switch (spec) {
      TutorialV3GuidelineStepSpec() => TutorialV3StepDetails(
        instructions: TutorialV3StepInstructions.fromSpec(spec),
      ),
      TutorialV3FinalLookStepSpec() => _FinalLookBody(spec: spec),
    };
  }
}

class _FinalLookBody extends StatelessWidget {
  const _FinalLookBody({required this.spec});

  final TutorialV3FinalLookStepSpec spec;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('YOUR FINISHED LOOK', style: _labelStyle(context)),
      const SizedBox(height: AppSpacing.xxs),
      // Copied from the persisted spec, like every other word on this screen.
      Text(spec.targetRationale, style: Theme.of(context).textTheme.bodyLarge),
    ],
  );

  TextStyle? _labelStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
        color: AppColors.taupe,
      );
}
