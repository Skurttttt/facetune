import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/entities/makeup_kit_category.dart';
import '../../domain/entities/makeup_kit_product.dart';
import '../utils/makeup_kit_display.dart';
import 'makeup_kit_product_tile.dart';

/// One category of the kit overview: a heading with its count, then its
/// products on their own card.
///
/// Each category used to be a band inside one card that held the whole kit, so
/// ten categories ran together. Now each is its own section. An empty category
/// keeps only its heading and a one-line note, so a sparse kit stays short.
class MakeupKitCategorySection extends StatelessWidget {
  const MakeupKitCategorySection({
    required this.category,
    required this.products,
    this.onProductTap,
    super.key,
  });

  final MakeupKitCategory category;
  final List<MakeupKitProduct> products;
  final ValueChanged<MakeupKitProduct>? onProductTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.muted(context));
    final count = products.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // One heading for assistive technology, rather than an icon, a label
        // and a bare number read out separately. A container of its own: in
        // the list, an empty category's note was otherwise merged into the
        // heading and announced as part of it.
        Semantics(
          container: true,
          header: true,
          label: '${category.label}, $count product${count == 1 ? '' : 's'}',
          child: ExcludeSemantics(
            child: Row(
              children: [
                Icon(
                  category.icon,
                  size: AppIconSizes.sm,
                  color: AppColors.rose,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    category.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (products.isEmpty)
          Padding(
            // Aligned with the label, under the icon's width and its gap.
            padding: const EdgeInsets.only(
              left: AppIconSizes.sm + AppSpacing.xs,
            ),
            child: Text('No products in this category yet.', style: muted),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < products.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  MakeupKitProductTile(
                    product: products[i],
                    onTap: onProductTap == null
                        ? null
                        : () => onProductTap!(products[i]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
