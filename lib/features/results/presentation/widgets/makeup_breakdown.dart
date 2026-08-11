import 'package:flutter/material.dart';

import '../../../../shared/widgets/surfaces/app_card.dart';
import '../../../../theme/app_tokens.dart';
import '../../../recommendation/domain/entities/makeup_recommendation.dart';
import '../utils/result_formatters.dart';

class MakeupBreakdown extends StatelessWidget {
  const MakeupBreakdown({required this.recommendation, super.key});

  final MakeupRecommendation recommendation;

  @override
  Widget build(BuildContext context) => Column(
    children: recommendation.items.entries
        .map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _BreakdownCard(
              title: ResultFormatters.label(entry.key),
              item: entry.value,
            ),
          ),
        )
        .toList(),
  );
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.title, required this.item});

  final String title;
  final MakeupRecommendationItem item;

  @override
  Widget build(BuildContext context) => AppCard(
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(top: AppSpacing.xs),
      shape: const Border(),
      collapsedShape: const Border(),
      leading: CircleAvatar(
        backgroundColor: AppColors.petal,
        foregroundColor: AppColors.rose,
        child: item.hex == null
            ? const Icon(Icons.brush_outlined)
            : Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Color(
                    int.parse('FF${item.hex!.substring(1)}', radix: 16),
                  ),
                  shape: BoxShape.circle,
                ),
              ),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text('${item.name} · ${item.intensity} · ${item.finish}'),
      children: [
        _Detail(label: 'Placement', value: item.placement),
        _Detail(label: 'Technique', value: item.technique),
        _Detail(label: 'Why it works', value: item.reasoning),
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
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    ),
  );
}
