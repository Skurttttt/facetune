import 'package:flutter/material.dart';

import '../../../../shared/widgets/surfaces/app_card.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/entities/makeup_recommendation.dart';

class RecommendationItemCard extends StatelessWidget {
  const RecommendationItemCard({
    required this.title,
    required this.item,
    super.key,
  });

  final String title;
  final MakeupRecommendationItem item;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (item.hex != null) ...[
              _ColorSwatch(hex: item.hex!),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(item.name, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
            Text(
              item.intensity,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.rose,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _Detail(label: 'Placement', value: item.placement),
        _Detail(label: 'Technique', value: item.technique),
        _Detail(label: 'Finish', value: item.finish),
        const SizedBox(height: AppSpacing.xs),
        Text(
          item.reasoning,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.muted(context)),
        ),
      ],
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.hex});

  final String hex;

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse('FF${hex.substring(1)}', radix: 16));
    return Semantics(
      label: 'Color $hex',
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
      ),
    );
  }
}
