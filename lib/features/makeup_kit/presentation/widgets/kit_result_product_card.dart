import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/entities/kit_makeup_recommendation.dart';

class KitResultProductCard extends StatelessWidget {
  const KitResultProductCard({
    required this.selection,
    required this.snapshot,
    super.key,
  });

  final KitMakeupSelection selection;
  final KitProductSnapshot snapshot;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(
                  int.parse(snapshot.colorHex.substring(1), radix: 16) |
                      0xFF000000,
                ),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snapshot.productName ?? _label(snapshot.category),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    snapshot.productName == null
                        ? 'Owned product snapshot'
                        : '${_label(snapshot.category)} · Owned product snapshot',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${snapshot.colorLabel ?? 'Registered shade'} · ${snapshot.colorHex}',
        ),
        Text(
          '${_label(snapshot.finish)} finish · ${_label(selection.intensity)}',
        ),
        if (snapshot.foundationDepth != null ||
            snapshot.foundationUndertone != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            [
              if (snapshot.foundationDepth != null)
                '${_label(snapshot.foundationDepth!)} depth',
              if (snapshot.foundationUndertone != null)
                '${_label(snapshot.foundationUndertone!)} undertone',
            ].join(' · '),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          selection.placement,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.muted(context)),
        ),
      ],
    ),
  );

  static String _label(String value) {
    final words = value.replaceAll('_', ' ');
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }
}
