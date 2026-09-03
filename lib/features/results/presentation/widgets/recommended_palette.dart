import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../../recommendation/domain/entities/makeup_recommendation.dart';
import '../utils/result_formatters.dart';

class RecommendedPalette extends StatelessWidget {
  const RecommendedPalette({required this.recommendation, super.key});

  final MakeupRecommendation recommendation;

  /// Larger than the default swatch: here the shade *is* the content, not an
  /// annotation on a row of text.
  static const double _swatchDiameter = 58;

  @override
  Widget build(BuildContext context) {
    final colors = recommendation.items.entries
        .where((entry) => entry.value.hex != null)
        .toList();
    // The strip has to be given a height, and a fixed one clipped the shade
    // name as soon as the reader raised their text size. The swatch keeps its
    // diameter; only the two lines of caption underneath it scale.
    final captionHeight =
        MediaQuery.textScalerOf(context).scale(11) * 2 * 1.45 + AppSpacing.xs;
    return SizedBox(
      height: _swatchDiameter + captionHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: colors.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final entry = colors[index];
          final hex = entry.value.hex!;
          final color = Color(int.parse('FF${hex.substring(1)}', radix: 16));
          return Semantics(
            container: true,
            excludeSemantics: true,
            // Swatch and caption read as one node. Split, a screen reader
            // announces a colour and then an unrelated product name.
            label:
                '${ResultFormatters.label(entry.key)}, ${entry.value.name}, color $hex',
            child: SizedBox(
              width: 84,
              child: Column(
                children: [
                  AppColorSwatch(color: color, size: _swatchDiameter),
                  const SizedBox(height: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      entry.value.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
