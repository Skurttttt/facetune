import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../../recommendation/domain/entities/makeup_recommendation.dart';
import '../utils/result_formatters.dart';

class RecommendedPalette extends StatelessWidget {
  const RecommendedPalette({required this.recommendation, super.key});

  final MakeupRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final colors = recommendation.items.entries
        .where((entry) => entry.value.hex != null)
        .toList();
    return SizedBox(
      height: 116,
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
            label:
                '${ResultFormatters.label(entry.key)}, ${entry.value.name}, color $hex',
            child: ExcludeSemantics(
              child: SizedBox(
                width: 84,
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      entry.value.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
