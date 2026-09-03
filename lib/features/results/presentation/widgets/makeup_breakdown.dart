import 'package:flutter/material.dart';

import '../../../../shared/widgets/surfaces/app_card.dart';
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
        // A category fed by one plan key stays a single card titled with the
        // canonical category name — "Contour & Bronzer", not "Contour" — so no
        // heading is added where there is nothing to group. A category fed by
        // several gets the heading, and its cards keep their own product names
        // so the user can still tell the lipstick from the gloss.
        if (!group.hasMultipleEntries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _BreakdownCard(
              title: TutorialLabels.categoryName(group.category),
              item: group.entries.single.item,
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              TutorialLabels.categoryName(group.category),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final entry in group.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _BreakdownCard(
                title: ResultFormatters.label(entry.planKey),
                item: entry.item,
              ),
            ),
        ],
    ],
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
