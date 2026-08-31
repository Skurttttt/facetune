import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/entities/tutorial_instruction.dart';
import '../utils/tutorial_labels.dart';

/// The goal for this step and the numbered instructions for reaching it.
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
    final theme = Theme.of(context);
    final goalText = goal?.trim();
    final hasGoal = goalText != null && goalText.isNotEmpty;
    if (!hasGoal && instructions.isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (instructions.isNotEmpty) ...[
            Text(TutorialLabels.howToApply, style: theme.textTheme.titleSmall),
            for (final step in instructions.steps) ...[
              const SizedBox(height: AppSpacing.sm),
              _InstructionRow(step: step),
            ],
          ],
          if (hasGoal) ...[
            if (instructions.isNotEmpty) const SizedBox(height: AppSpacing.md),
            Text(TutorialLabels.yourGoal, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xxs),
            Text(goalText, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _InstructionRow extends StatelessWidget {
  const _InstructionRow({required this.step});

  final TutorialInstructionStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      excludeSemantics: true,
      // Spoken as an ordered instruction naming its guide, so a screen-reader
      // user gets the same symbol-to-text link a sighted user gets visually.
      label:
          'Step ${step.sequence}. ${step.shortTitle}. '
          '${TutorialLabels.guideTypeSemantics(step.guideType)}. '
          '${step.instruction}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed-width gutter so the numbers form a column and the text edges
          // align, which is what makes a numbered list scannable.
          SizedBox(
            width: 24,
            child: Text(
              '${step.sequence}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The title carries the guide glyph beside it, so the
                // instruction and the drawing are tied together at a glance
                // rather than only in the prose.
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        step.shortTitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      step.guideType.symbol,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  step.instruction,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
