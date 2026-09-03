import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../../../recommendation/domain/entities/makeup_recommendation.dart';
import '../../../tutorial/domain/catalog/realized_look_filter.dart';
import '../../../tutorial/presentation/utils/tutorial_labels.dart';
import '../utils/result_formatters.dart';

/// The categories the canonical final preview actually contains.
///
/// [groups] arrive pre-filtered, pre-grouped and pre-ordered by
/// [RealizedLookFilter], which reads the accepted dynamic manifest — the same
/// authority the Step-by-Step tutorial builds its steps from. Before V4-QA-6B
/// this widget rendered `recommendation.items` directly, which is the *intent*
/// formed before the preview existed, so a Natural look could list Contour here
/// and omit it from the tutorial.
///
/// One group is one section, however many products feed it. That is what makes
/// the two screens comparable: `lipstick` and `lipGloss` are two entries inside
/// one Lips section, not two categories, so an Everyday look reads six
/// categories here and six steps there.
///
/// UI-P4 made that containment *visual* as well as structural. A multi-product
/// category previously rendered as a bare heading followed by loose cards, which
/// on screen was indistinguishable from two separate categories — the exact
/// misreading the category invariant exists to prevent. Those entries are now
/// nested inside one bounded card carrying the category name.
///
/// No filtering and no grouping happen in this widget, and none may be added to
/// it. It is handed a structure and renders it; what belongs in that structure
/// is a domain question with one owner.
class MakeupBreakdown extends StatelessWidget {
  const MakeupBreakdown({required this.groups, super.key});

  final List<RealizedCategoryGroup<RealizedStandardEntry>> groups;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final group in groups)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          // A category fed by one plan key stays a single card titled with the
          // canonical category name — "Contour & Bronzer", not "Contour" — so
          // no heading is added where there is nothing to group. A category fed
          // by several becomes one card that contains them, and its entries
          // keep their own product names so the user can still tell the
          // lipstick from the gloss.
          child: group.hasMultipleEntries
              ? _MultiProductCategory(group: group)
              : _BreakdownCard(
                  title: TutorialLabels.categoryName(group.category),
                  item: group.entries.single.item,
                ),
        ),
    ],
  );
}

/// One canonical category that several products contribute to.
///
/// The card boundary is the point: everything inside it belongs to the one
/// category named at the top, and the count in the header states how many
/// products that is so the section cannot be mistaken for a category list.
class _MultiProductCategory extends StatelessWidget {
  const _MultiProductCategory({required this.group});

  final RealizedCategoryGroup<RealizedStandardEntry> group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = AppTone.info.resolve(context);
    final categoryName = TutorialLabels.categoryName(group.category);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            excludeSemantics: true,
            header: true,
            label:
                '$categoryName, one category with '
                '${group.entries.length} products',
            child: Row(
              children: [
                Expanded(
                  child: Text(categoryName, style: theme.textTheme.titleMedium),
                ),
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xxs / 2,
                  ),
                  decoration: BoxDecoration(
                    color: info.surface,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: Border.all(
                      color: info.border,
                      width: AppBorders.hairline,
                    ),
                  ),
                  child: Text(
                    '${group.entries.length} products',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: info.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final entry in group.entries)
            _BreakdownTile(
              title: ResultFormatters.label(entry.planKey),
              item: entry.item,
            ),
        ],
      ),
    );
  }
}

/// A single canonical category, rendered as its own card.
class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.title, required this.item});

  final String title;
  final MakeupRecommendationItem item;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xxs,
    ),
    child: _BreakdownTile(title: title, item: item),
  );
}

/// The expandable body shared by both shapes above.
class _BreakdownTile extends StatelessWidget {
  const _BreakdownTile({required this.title, required this.item});

  final String title;
  final MakeupRecommendationItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.xs),
      shape: const Border(),
      collapsedShape: const Border(),
      leading: AppColorSwatch(
        color: _swatchColour(item.hex),
        semanticLabel: item.hex == null
            ? null
            : 'Shade ${item.name}, hex code ${item.hex}',
      ),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Text(
        // The recommendation's own metadata, verbatim and unreordered.
        '${item.name} · ${item.intensity} · ${item.finish}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.muted(context),
        ),
      ),
      children: [
        DetailRow(label: 'Placement', value: item.placement),
        DetailRow(label: 'Technique', value: item.technique),
        DetailRow(
          label: 'Why it works',
          value: item.reasoning,
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  /// The recommendation's shade, or null when it supplied none.
  ///
  /// Null renders the swatch's neutral placeholder rather than a guessed
  /// colour: an absent hex is missing data, and inventing one would show a
  /// shade the recommendation never made.
  static Color? _swatchColour(String? hex) {
    if (hex == null) return null;
    final parsed = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return parsed == null ? null : Color(0xFF000000 | parsed);
  }
}
