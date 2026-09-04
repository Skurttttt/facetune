import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';

/// Presentation-ready values for one row in [TutorialRecommendationSection].
///
/// This type deliberately contains no repository, mode, product, or
/// recommendation object. Authority-specific adapters decide which values may
/// enter it; the shared widget only lays those values out.
class TutorialRecommendationItem {
  const TutorialRecommendationItem({
    required this.displayName,
    required this.swatch,
    this.finish,
    this.intensity,
    this.brand,
  });

  final String displayName;
  final Color? swatch;
  final String? finish;
  final String? intensity;
  final String? brand;
}

/// The shared beauty-oriented recommendation presentation for both modes.
///
/// Mode authority stays outside this component. It receives display values,
/// draws the same hierarchy for either source, and performs no fallback or
/// substitution.
class TutorialRecommendationSection extends StatelessWidget {
  const TutorialRecommendationSection({
    required this.sectionLabel,
    required this.items,
    super.key,
  });

  final String sectionLabel;
  final List<TutorialRecommendationItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(sectionLabel, style: theme.textTheme.titleSmall),
          ),
          for (var index = 0; index < items.length; index += 1) ...[
            const SizedBox(height: AppSpacing.sm),
            _RecommendationItemRow(item: items[index]),
          ],
        ],
      ),
    );
  }
}

class _RecommendationItemRow extends StatelessWidget {
  const _RecommendationItemRow({required this.item});

  final TutorialRecommendationItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metadata = <String>[];
    if (item.finish case final finish? when finish.isNotEmpty) {
      metadata.add(finish);
    }
    if (item.intensity case final intensity? when intensity.isNotEmpty) {
      metadata.add(intensity);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppColorSwatch(
          color: item.swatch,
          size: AppColorSwatch.largeSize,
          semanticLabel: 'Shade for ${item.displayName}',
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.brand case final brand? when brand.isNotEmpty) ...[
                Text(
                  brand,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
              ],
              Text(
                item.displayName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (metadata.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  metadata.join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
