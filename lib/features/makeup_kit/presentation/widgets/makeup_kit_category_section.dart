import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../domain/entities/makeup_kit_category.dart';
import '../../domain/entities/makeup_kit_product.dart';
import '../utils/makeup_kit_display.dart';
import 'makeup_kit_product_tile.dart';

/// One category's worth of products (or its empty state), inside the kit
/// overview list.
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(category.icon, size: AppIconSizes.sm, color: AppColors.rose),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                category.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              products.isEmpty ? 'No products' : '${products.length}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted(context)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (products.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.lg + AppSpacing.xs),
            child: Text(
              'No products in this category yet.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted(context)),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.lg + AppSpacing.xs),
            child: Column(
              children: [
                for (final product in products)
                  MakeupKitProductTile(
                    product: product,
                    onTap: onProductTap == null
                        ? null
                        : () => onProductTap!(product),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}
