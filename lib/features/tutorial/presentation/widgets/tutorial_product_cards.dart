import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/entities/look_product_snapshot.dart';
import '../../domain/entities/standard_look_entry.dart';
import '../../domain/entities/tutorial_shade_details.dart';
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
    final scheme = Theme.of(context).colorScheme;
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
              // The fill is recommendation/snapshot data, not a UI theme
              // colour. Only an invalid value falls back to a themed surface.
              color: color ?? scheme.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.outlineVariant),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(hex, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

Widget _detailRow(BuildContext context, String label, String value) {
  final body = Theme.of(context).textTheme.bodySmall;
  // Derived from the effective body colour rather than a fixed token, because
  // these rows appear on two different surfaces: the default card, and the
  // petal card whose foreground AppCard has already overridden. A global muted
  // token is correct on one and wrong on the other; a softened version of
  // whatever colour is actually in force is correct on both.
  final labelColor = body?.color?.withValues(alpha: 0.72);
  return Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xxs),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final useStack =
            constraints.maxWidth < 220 ||
            MediaQuery.textScalerOf(context).scale(12) > 18;
        final labelWidget = Text(
          label,
          style: body?.copyWith(color: labelColor),
        );
        final valueWidget = Text(value, style: body);
        if (useStack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelWidget, const SizedBox(height: 2), valueWidget],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 92, child: labelWidget),
            Expanded(child: valueWidget),
          ],
        );
      },
    ),
  );
}

Widget _hexDetailRow(BuildContext context, String hex, {String? shadeLabel}) {
  final body = Theme.of(context).textTheme.bodySmall;
  final labelColor = body?.color?.withValues(alpha: 0.72);
  return Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xxs),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final useStack =
            constraints.maxWidth < 220 ||
            MediaQuery.textScalerOf(context).scale(12) > 18;
        final labelWidget = Text(
          TutorialLabels.hex,
          style: body?.copyWith(color: labelColor),
        );
        final valueWidget = _ShadeChip(hex: hex, label: shadeLabel);
        if (useStack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelWidget, const SizedBox(height: 2), valueWidget],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 92, child: labelWidget),
            Expanded(child: valueWidget),
          ],
        );
      },
    ),
  );
}

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
            _detailRow(context, TutorialLabels.shade, entry.shadeName),
            if (entry.colorHex != null)
              _hexDetailRow(
                context,
                entry.colorHex!,
                shadeLabel: entry.shadeName,
              ),
            if (entry.finish.isNotEmpty)
              _detailRow(context, TutorialLabels.finish, entry.finish),
            // Routed through the controlled vocabulary rather than printed raw.
            // A value outside the validated set is shown as nothing at all —
            // displaying an unrecognised strength would be a guess.
            ?switch (TutorialIntensity.fromCode(entry.intensity)) {
              final intensity? => _detailRow(
                context,
                TutorialLabels.intensity,
                TutorialLabels.intensityName(intensity),
              ),
              null => null,
            },
            // The recommendation's own placement and technique wording. It is
            // look-specific and authoritative, so it belongs with the rest of
            // the recommendation metadata — not in the numbered instructions,
            // which describe the drawn guides and must reference a symbol.
            if (entry.placement.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                TutorialLabels.whereToApply,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                entry.placement,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (entry.technique.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                TutorialLabels.technique,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                entry.technique,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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
            if (item.colorLabel != null)
              _detailRow(context, TutorialLabels.shade, item.colorLabel!),
            _hexDetailRow(
              context,
              item.color.value,
              shadeLabel: item.colorLabel,
            ),
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
