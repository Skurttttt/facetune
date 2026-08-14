import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../../makeup_styles/domain/catalog/makeup_style_catalog.dart';
import '../../domain/catalog/tutorial_placement_overlay_catalog.dart';
import '../../domain/entities/tutorial_session.dart';
import '../../domain/entities/tutorial_step.dart';
import 'placement_result_comparison.dart';
import 'tutorial_instruction_card.dart';

/// The Step-by-Step Tutorial viewer: header, dynamic step progress, the
/// Placement/Result slider, the written instruction card, and Previous/Next
/// controls (FACETUNE_STEP_BY_STEP_TUTORIAL_GUIDE.md §18).
///
/// Renders only from already-loaded [TutorialSession]/[TutorialStep] domain
/// data — it never triggers generation. [session.steps] may be a strict
/// prefix of [session.totalSteps] planned steps (a session still generating
/// or partially complete), so navigation is bounded by the steps actually
/// available rather than the planned total.
class TutorialStepViewer extends StatefulWidget {
  const TutorialStepViewer({required this.session, super.key});

  final TutorialSession session;

  @override
  State<TutorialStepViewer> createState() => _TutorialStepViewerState();
}

class _TutorialStepViewerState extends State<TutorialStepViewer> {
  int _index = 0;

  @override
  void didUpdateWidget(TutorialStepViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A refreshed session (e.g. more steps finished generating) must not
    // leave the viewer pointing past the end of the new step list.
    if (_index >= widget.session.steps.length) {
      _index = widget.session.steps.isEmpty
          ? 0
          : widget.session.steps.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.session.steps;
    if (steps.isEmpty) {
      return const StatusState(
        title: 'No steps yet',
        message: 'This tutorial does not have any generated steps to show yet.',
        icon: Icons.auto_stories_outlined,
      );
    }
    final step = steps[_index];
    return ListView(
      children: [
        _Header(session: widget.session, step: step, index: _index),
        const SizedBox(height: AppSpacing.md),
        if (step.placementImageUrl != null && step.resultImageUrl != null)
          PlacementResultComparison(
            placementImageUrl: step.placementImageUrl!,
            resultImageUrl: step.resultImageUrl!,
            placementMetadata:
                step.placementMetadata ??
                TutorialPlacementOverlayCatalog.defaultFor(step.category),
          )
        else
          const StatusState(
            title: 'Step still generating',
            message: 'This step\'s images are not ready yet.',
            icon: Icons.hourglass_top_rounded,
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
