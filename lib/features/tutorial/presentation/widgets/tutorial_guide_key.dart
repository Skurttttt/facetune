import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../domain/entities/tutorial_guide_type.dart';
import '../utils/tutorial_labels.dart';

/// A compact legend for the marks drawn on the guideline image.
///
/// Shows only the guide types this step's instructions actually reference.
/// Listing all four on a step that uses two would send the user looking for
/// markings that were never drawn, which is the opposite of a key's job.
///
/// Every entry pairs the glyph with its name, so meaning never rests on the
/// symbol alone — the glyphs are small, and on a phone at arm's length a dot
/// and a period are the same shape.
class TutorialGuideKey extends StatelessWidget {
  const TutorialGuideKey({required this.types, super.key});

  final List<TutorialGuideType> types;

  @override
  Widget build(BuildContext context) {
    if (types.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: TutorialLabels.guideKeySemantics,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          // Derived from the active scheme rather than a fixed tint, so the key
          // reads as a quiet panel in both themes instead of a light card
          // stranded on a dark page.
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TutorialLabels.guideKey,
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.muted(context),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Wrap rather than Row: at large text scales four entries cannot
            // share one line, and a Row would overflow rather than reflow.
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [for (final type in types) _GuideKeyEntry(type: type)],
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideKeyEntry extends StatelessWidget {
  const _GuideKeyEntry({required this.type});

  final TutorialGuideType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      // One node per entry, spoken as its meaning. Without excludeSemantics the
      // glyph would be announced as its own unhelpful node first.
      container: true,
      excludeSemantics: true,
      label: TutorialLabels.guideTypeSemantics(type),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            type.symbol,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              TutorialLabels.guideTypeName(type),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
