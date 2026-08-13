import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../domain/entities/makeup_kit_category.dart';
import '../../domain/entities/makeup_kit_product.dart';
import '../utils/makeup_kit_display.dart';
import 'makeup_kit_color_swatch.dart';

/// A single registered product, shown inside its category's section.
class MakeupKitProductTile extends StatelessWidget {
  const MakeupKitProductTile({required this.product, this.onTap, super.key});

  final MakeupKitProduct product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // The finish label doubles as the title when no name/shade label was
    // given, so it must not also be repeated in the subtitle below it.
    final hasDisplayName =
        product.productName != null || product.colorLabel != null;
    final title =
        product.productName ?? product.colorLabel ?? product.finish.label;
    final isFoundation = product.category == MakeupKitCategory.foundation;
    final subtitleParts = <String>[
      if (product.productName != null && product.colorLabel != null)
        product.colorLabel!,
      if (hasDisplayName) product.finish.label,
      if (isFoundation && product.foundationDepth != null)
        product.foundationDepth!.label,
      if (isFoundation && product.foundationUndertone != null)
        product.foundationUndertone!.label,
    ];
    final subtitle = subtitleParts.isEmpty
        ? product.color.value
        : subtitleParts.join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            MakeupKitColorSwatch(color: product.color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted(context),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
