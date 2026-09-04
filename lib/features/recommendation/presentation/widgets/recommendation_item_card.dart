import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../../results/presentation/utils/result_formatters.dart';
import '../../domain/entities/makeup_recommendation.dart';

/// One category on the Personalized Palette.
///
/// The Palette answers **what** was chosen and **why** it suits this person.
/// It deliberately does not answer where to put it or how to blend it: those
/// are `placement` and `technique`, they are still carried by the
/// recommendation, and they are still presented by the Makeup Breakdown and by
/// the Step-by-Step tutorial. LSEP-2 removed them from *this* surface only.
/// Removing them from the presentation is not removing them from the system —
/// nothing downstream of the recommendation changed.
///
/// Collapsed by default. Expansion is local presentation state and reads
/// already-loaded data, so opening or closing a card issues no Gemini call, no
/// recommendation call, and no preview call.
class RecommendationItemCard extends StatefulWidget {
  const RecommendationItemCard({
    required this.title,
    required this.item,
    super.key,
  });

  final String title;
  final MakeupRecommendationItem item;

  @override
  State<RecommendationItemCard> createState() => _RecommendationItemCardState();
}

class _RecommendationItemCardState extends State<RecommendationItemCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final education = item.education;

    return AppCard(
      // The tail padding closes up when an ExpansionTile is present, because
      // the tile brings its own.
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        education == null ? AppSpacing.md : AppSpacing.xxs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppColorSwatch(
                color: _swatchColour(item.hex),
                semanticLabel: item.hex == null
                    ? null
                    : 'Shade ${item.name}, hex code ${item.hex}',
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: theme.textTheme.titleMedium),
                    Text(item.name, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                ResultFormatters.label(item.intensity),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.rose,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            ResultFormatters.label(item.finish),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.muted(context),
            ),
          ),
          if (education != null)
            _WhyThisWorks(
              title: widget.title,
              education: education,
              expanded: _expanded,
              onExpansionChanged: (value) => setState(() => _expanded = value),
            )
          else ...[
            // A plan generated before education existed. Its own one-line
            // reasoning is real authored data for this exact recommendation, so
            // showing it is not a fallback paragraph — it is the only "why"
            // this plan was ever given. Nothing is generated to fill the gap
            // and no AI call is made to backfill it.
            const SizedBox(height: AppSpacing.xs),
            Text(
              item.reasoning,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The recommendation's shade, or null when it supplied none.
  ///
  /// Matches the Breakdown's rule: null draws the swatch's neutral placeholder
  /// rather than a guessed colour, because an absent hex is missing data and
  /// inventing one would show a shade the recommendation never made.
  static Color? _swatchColour(String? hex) {
    if (hex == null) return null;
    final parsed = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return parsed == null ? null : Color(0xFF000000 | parsed);
  }
}

/// The three grounded explanations, behind one disclosure.
///
/// The same `ExpansionTile` treatment the Makeup Breakdown uses, so the two
/// surfaces disclose detail the same way. The `Semantics` wrapper is what makes
/// the collapsed and expanded states legible to a screen reader — expansion
/// that is only announced by a rotating chevron is invisible to one.
class _WhyThisWorks extends StatelessWidget {
  const _WhyThisWorks({
    required this.title,
    required this.education,
    required this.expanded,
    required this.onExpansionChanged,
  });

  final String title;
  final MakeupRecommendationEducation education;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      button: true,
      expanded: expanded,
      label: '$title, why this works for you',
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.xs),
        shape: const Border(),
        collapsedShape: const Border(),
        initiallyExpanded: expanded,
        onExpansionChanged: onExpansionChanged,
        title: Text(
          'Why this works for you',
          style: theme.textTheme.labelLarge,
        ),
        children: [
          _EducationSection(heading: 'Your features', body: education.features),
          _EducationSection(heading: 'The effect', body: education.effect),
          _EducationSection(
            heading: 'The style',
            body: education.style,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

/// One titled explanation.
class _EducationSection extends StatelessWidget {
  const _EducationSection({
    required this.heading,
    required this.body,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.sm),
  });

  final String heading;
  final String body;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xxs),
          // No maxLines and no ellipsis: an explanation that is cut off is
          // worse than one that makes the card taller, and the page scrolls.
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
