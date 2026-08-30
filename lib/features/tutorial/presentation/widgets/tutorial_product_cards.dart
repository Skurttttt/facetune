import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/entities/look_product_snapshot.dart';
import '../../domain/entities/standard_look_entry.dart';
import '../utils/tutorial_labels.dart';

/// A colour chip showing an exact stored shade.
///
/// The hex is displayed as text as well as colour, because colour alone is not
/// an accessible way to convey a value and a user comparing against a physical
/// product needs the code.
class _ShadeChip extends StatelessWidget {
  const _ShadeChip({required this.hex, this.label});

  final String hex;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final parsed = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    final color = parsed == null ? null : Color(0xFF000000 | parsed);
    return Semantics(
      // container + excludeSemantics so the swatch and the hex text read as one
      // node. Without it the label never forms its own node, and a screen
      // reader announces a bare hex string with no indication it is a colour.
      container: true,
      excludeSemantics: true,
      label: label == null ? 'Shade $hex' : 'Shade $label, hex code $hex',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color ?? AppColors.sand,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.taupeLight),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(hex, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

Widget _detailRow(BuildContext context, String label, String value) => Padding(
  padding: const EdgeInsets.only(top: AppSpacing.xxs),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 92,
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.taupe),
        ),
      ),
      Expanded(
        child: Text(value, style: Theme.of(context).textTheme.bodySmall),
      ),
    ],
  ),
);

/// Standard Mode: brand-neutral colour guidance.
///
/// Shows a shade description such as "warm peach" and never a product to buy —
/// the upstream recommendation carries no brand, retailer, or price, and this
/// card adds none.
class StandardProductCard extends StatelessWidget {
  const StandardProductCard({required this.entries, super.key});

  final List<StandardLookEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TutorialLabels.suggestedShades,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final entry in entries) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              entry.shadeName,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (entry.colorHex != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              _ShadeChip(hex: entry.colorHex!),
            ],
            if (entry.finish.isNotEmpty)
              _detailRow(context, TutorialLabels.finish, entry.finish),
            if (entry.intensity.isNotEmpty)
              _detailRow(context, TutorialLabels.intensity, entry.intensity),
          ],
        ],
      ),
    );
  }
}

/// My Makeup Kit: the user's own products, exactly as captured.
///
/// Every value comes from the immutable snapshot taken when the look was
/// validated, so a product edited or deleted since then still displays as it
/// was used. Nothing is substituted for a missing field — an unnamed product
/// shows its category instead of an invented name.
class MyMakeupKitProductCard extends StatelessWidget {
  const MyMakeupKitProductCard({required this.items, super.key});

  final List<LookProductSnapshotItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return AppCard(
      color: AppColors.petal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 18,
                color: AppColors.rose,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                items.length == 1
                    ? TutorialLabels.fromYourKit
                    : TutorialLabels.fromYourKitPlural(items.length),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          for (final item in items) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              // An unnamed product is described by what it is, never by an
              // invented name.
              item.productName ??
                  TutorialLabels.inventoryCategory(item.kitCategory),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xxs),
            _ShadeChip(hex: item.color.value, label: item.colorLabel),
            if (item.colorLabel != null)
              _detailRow(context, TutorialLabels.shade, item.colorLabel!),
            _detailRow(
              context,
              TutorialLabels.finish,
              TutorialLabels.finishName(item.finish),
            ),
            if (item.foundationDepth != null)
              _detailRow(
                context,
                TutorialLabels.depth,
                TutorialLabels.depthName(item.foundationDepth!),
              ),
            if (item.foundationUndertone != null)
              _detailRow(
                context,
                TutorialLabels.undertone,
                TutorialLabels.undertoneName(item.foundationUndertone!),
              ),
          ],
        ],
      ),
    );
  }
}
