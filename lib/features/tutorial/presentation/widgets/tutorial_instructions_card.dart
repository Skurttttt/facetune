import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/entities/tutorial_instruction.dart';
import '../utils/tutorial_labels.dart';

/// The editorial instructions for this step and its optional goal.
///
/// [goal] is shown only when authoritative text exists for it. Standard Mode
/// carries the recommendation's own one-sentence reasoning; My Makeup Kit has no
/// equivalent field, so a kit step shows the instructions without a goal rather
/// than a sentence composed to fill the space.
///
/// Numbering lives here, in the list, and nowhere else. Placing numbers on the
/// face would require per-mark coordinates, which would mean face geometry the
/// tutorial deliberately does not have.
class TutorialInstructionsCard extends StatelessWidget {
  const TutorialInstructionsCard({
    required this.instructions,
    this.goal,
    super.key,
  });

  final TutorialInstructionSequence instructions;
  final String? goal;

  @override
  Widget build(BuildContext context) {
    final goalText = goal;
    final hasGoal = goalText != null && goalText.trim().isNotEmpty;
    if (!hasGoal && instructions.isEmpty) return const SizedBox.shrink();

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (instructions.isNotEmpty) ...[
            Semantics(
              header: true,
              sortKey: const OrdinalSortKey(0),
              child: const SectionHeader(TutorialLabels.howToApply),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (var index = 0; index < instructions.steps.length; index += 1)
              _InstructionRailItem(
                step: instructions.steps[index],
                order: index + 1,
                showConnector: index < instructions.steps.length - 1,
              ),
          ],
          if (hasGoal) ...[
            if (instructions.isNotEmpty) const SizedBox(height: AppSpacing.lg),
            _GoalCallout(goal: goalText, order: instructions.steps.length + 1),
          ],
        ],
      ),
    );
  }
}

class _InstructionRailItem extends StatelessWidget {
  const _InstructionRailItem({
    required this.step,
    required this.order,
    required this.showConnector,
  });

  final TutorialInstructionStep step;
  final int order;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          excludeSemantics: true,
          sortKey: OrdinalSortKey(order.toDouble()),
          // Spoken as an ordered instruction naming its guide, so a
          // screen-reader user gets the same symbol-to-text link a sighted user
          // gets visually. The zero padding is visual rhythm, not spoken copy.
          label:
              'Step ${step.sequence}. ${step.shortTitle}. '
              '${TutorialLabels.guideTypeSemantics(step.guideType)}. '
              '${step.instruction}',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // One token-wide gutter makes 01–04 a stable visual anchor and
              // gives the connectors below one consistent centre line.
              SizedBox(
                width: AppSpacing.xl,
                child: Text(
                  step.sequence.toString().padLeft(2, '0'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The title carries the guide glyph beside it, so the
                    // instruction and drawing stay tied together at a glance.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            step.shortTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          step.guideType.symbol,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      step.instruction,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showConnector)
          SizedBox(
            width: AppSpacing.xl,
            height: AppSpacing.lg,
            child: VerticalDivider(
              width: AppSpacing.xl,
              thickness: AppBorders.hairline,
              color: theme.colorScheme.outlineVariant,
            ),
          ),
      ],
    );
  }
}

class _GoalCallout extends StatelessWidget {
  const _GoalCallout({required this.goal, required this.order});

  final String goal;
  final int order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      excludeSemantics: true,
      sortKey: OrdinalSortKey(order.toDouble()),
      label: '${TutorialLabels.yourGoal}. $goal',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TutorialLabels.yourGoal,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.muted(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: theme.colorScheme.primary,
                  width: AppBorders.emphasis,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Text(goal, style: theme.textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}
