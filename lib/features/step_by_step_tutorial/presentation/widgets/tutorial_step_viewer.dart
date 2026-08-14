import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../../makeup_styles/domain/catalog/makeup_style_catalog.dart';
import '../../domain/entities/tutorial_generation_status.dart';
import '../../domain/entities/tutorial_session.dart';
import '../../domain/entities/tutorial_step.dart';
import '../controllers/tutorial_session_controller.dart';
import '../controllers/tutorial_session_state.dart';
import 'placement_result_comparison.dart';
import 'tutorial_instruction_card.dart';

/// The Step-by-Step Tutorial viewer: header, dynamic step progress, the
/// Placement/Result slider, the written instruction card, and Previous/Next
/// controls (FACETUNE_STEP_BY_STEP_TUTORIAL_GUIDE.md §18).
///
/// [state.session.steps] may be a strict prefix of [state.session.totalSteps]
/// planned steps (a session still generating or partially complete), so
/// navigation is bounded by the steps actually available rather than the
/// planned total.
///
/// Generation itself (ST-10) is driven from here: a step the user navigates
/// to that has no Result yet shows an explicit "Generate this step" action
/// rather than generating automatically on navigation — the same
/// explicit-user-action principle `TutorialSessionController.generate`
/// already applies to creating a session (see ARCHITECTURE_NOTES.md ST-8).
/// Only the step immediately after the last completed one may be generated,
/// matching the backend's cumulative ordering requirement
/// (`generate-tutorial-step` rejects out-of-order generation with
/// `PREVIOUS_STEP_NOT_READY`) — this widget mirrors that rule client-side
/// so the user sees "generate previous steps first" instead of a
/// server-rejected request.
class TutorialStepViewer extends ConsumerStatefulWidget {
  const TutorialStepViewer({required this.state, super.key});

  final TutorialSessionState state;

  @override
  ConsumerState<TutorialStepViewer> createState() => _TutorialStepViewerState();
}

class _TutorialStepViewerState extends ConsumerState<TutorialStepViewer> {
  int _index = 0;

  TutorialSession get _session => widget.state.session!;

  @override
  void didUpdateWidget(TutorialStepViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A refreshed session (e.g. more steps finished generating) must not
    // leave the viewer pointing past the end of the new step list.
    if (_index >= _session.steps.length) {
      _index = _session.steps.isEmpty ? 0 : _session.steps.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _session.steps;
    if (steps.isEmpty) {
      return const StatusState(
        title: 'No steps yet',
        message: 'This tutorial does not have any generated steps to show yet.',
        icon: Icons.auto_stories_outlined,
      );
    }
    final step = steps[_index];
    final placementImageUrl =
        step.placementImageUrl ??
        (_index == 0
            ? widget.state.originalImageUrl
            : steps[_index - 1].resultImageUrl);
    final firstMissingIndex = steps.indexWhere(
      (candidate) => candidate.resultImageUrl == null,
    );
    final isNextToGenerate = firstMissingIndex == _index;
    return ListView(
      children: [
        _Header(session: _session, step: step, index: _index),
        const SizedBox(height: AppSpacing.md),
        _StepBody(
          step: step,
          placementImageUrl: placementImageUrl,
          state: widget.state,
          isNextToGenerate: isNextToGenerate,
          onGenerate: () => ref
              .read(tutorialSessionControllerProvider.notifier)
              .generateStep(step.id),
        ),
        const SizedBox(height: AppSpacing.lg),
        TutorialInstructionCard(instruction: step.instruction),
        const SizedBox(height: AppSpacing.lg),
        _StepControls(
          canGoPrevious: _index > 0,
          canGoNext: _index < steps.length - 1,
          onPrevious: () => setState(() => _index -= 1),
          onNext: () => setState(() => _index += 1),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

/// Renders whichever of the six progressive states (roadmap ST-10 task 4)
/// applies to [step]: a completed step shows the Placement/Result slider;
/// otherwise one of generating / failed / ready-to-generate / not-yet-
/// eligible.
class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.step,
    required this.placementImageUrl,
    required this.state,
    required this.isNextToGenerate,
    required this.onGenerate,
  });

  final TutorialStep step;
  final String? placementImageUrl;
  final TutorialSessionState state;
  final bool isNextToGenerate;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    if (placementImageUrl != null && step.resultImageUrl != null) {
      return PlacementResultComparison(
        placementImageUrl: placementImageUrl!,
        resultImageUrl: step.resultImageUrl!,
        placementMetadata: step.placementMetadata,
      );
    }
    if (state.generatingStepId == step.id) {
      return const LoadingState(label: 'Generating this step…');
    }
    final hasFreshFailure = state.stepFailureStepId == step.id;
    final hasPersistedFailure =
        step.generationStatus == TutorialStepGenerationStatus.failed;
    if (hasFreshFailure || hasPersistedFailure) {
      // A fresh failure carries its own retryability (e.g. a deleted
      // source reports `retryable: false` — tapping "Try again" would
      // just fail identically every time). A persisted failure from an
      // earlier app session carries no such flag, so it defaults to
      // offering retry rather than silently trapping the user with no
      // action at all (roadmap ST-13 hardening).
      final canRetry = hasFreshFailure ? state.stepFailureRetryable : true;
      return StatusState(
        title: 'This step could not be generated',
        message: hasFreshFailure
            ? (state.stepFailureMessage ?? 'Please try again.')
            : 'Please try again.',
        icon: Icons.error_outline_rounded,
        actionLabel: canRetry ? 'Try again' : null,
        onAction: canRetry ? onGenerate : null,
        liveRegion: true,
      );
    }
    if (isNextToGenerate) {
      return StatusState(
        title: 'Ready to generate',
        message: 'Generate the "${step.title}" step to see it applied.',
        icon: Icons.auto_awesome_rounded,
        actionLabel: 'Generate this step',
        onAction: onGenerate,
      );
    }
    return const StatusState(
      title: 'Not yet available',
      message: 'Generate the previous steps first.',
      icon: Icons.hourglass_top_rounded,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.session,
    required this.step,
    required this.index,
  });

  final TutorialSession session;
  final TutorialStep step;
  final int index;

  @override
  Widget build(BuildContext context) {
    final styleName = MakeupStyleCatalog.styles
        .where((style) => style.code == session.styleCode)
        .firstOrNull
        ?.name;
    final total = session.totalSteps > 0
        ? session.totalSteps
        : session.steps.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How to Apply This Look',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          styleName == null
              ? 'Variation ${session.generationNumber}'
              : '$styleName · Variation ${session.generationNumber}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.rose,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'STEP ${index + 1} OF $total — ${step.title.toUpperCase()}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: LinearProgressIndicator(
            value: (index + 1) / total,
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _StepControls extends StatelessWidget {
  const _StepControls({
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: canGoPrevious ? onPrevious : null,
          icon: const Icon(Icons.chevron_left_rounded),
          label: const Text('Previous'),
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: FilledButton.icon(
          onPressed: canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right_rounded),
          label: const Text('Next Step'),
        ),
      ),
    ],
  );
}
