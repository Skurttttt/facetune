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
/// Expansion is **controlled by the parent**. The card owns no expansion state
/// of its own, which is what lets the Palette keep at most one card open: the
/// page holds a single expanded key, so opening one card closes the previous
/// one without the two cards knowing about each other. It is still presentation
/// state over already-loaded data — opening or closing issues no Gemini call, no
/// recommendation call, and no preview call.
class RecommendationItemCard extends StatelessWidget {
  const RecommendationItemCard({
    required this.title,
    required this.item,
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final String title;
  final MakeupRecommendationItem item;

  /// Whether this card's education is showing. Owned by the page.
  final bool expanded;

  /// Asks the page to open this card, or close it if it is already open.
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final education = item.education;

    return AppCard(
      // Tighter than the default card inset. Device review found the collapsed
      // cards carrying more vertical weight than their three lines of content
      // earned, which pushed the first recommendation down the screen.
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        education == null ? AppSpacing.sm : AppSpacing.xxs,
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
                    // The strongest text on the card. Everything below it is
                    // an attribute of the thing this line names.
                    Text(title, style: theme.textTheme.titleMedium),
                    Text(item.name, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              // Metadata, not a headline. It keeps the brand accent — that is
              // how the app marks a qualifying value — but steps down to the
              // smallest label token so a one-word qualifier stops reading as
              // loud as the category beside it.
              //
              // Resolved through [AppColors.onTint] rather than used raw:
              // `rose` is tuned for light surfaces and reaches only 3.1:1 on
              // the dark card, which is below AA — and a smaller label is
              // exactly where that shortfall starts to bite.
              Text(
                ResultFormatters.label(item.intensity),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.onTint(context, AppColors.rose),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          // Tertiary. The quietest thing on the collapsed card, because it
          // qualifies the shade rather than naming it.
          Text(
            ResultFormatters.label(item.finish),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.muted(context),
            ),
          ),
          if (education != null)
            _WhyThisWorks(
              title: title,
              education: education,
              expanded: expanded,
              onToggle: onToggle,
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
/// Built by hand rather than with `ExpansionTile`, for two reasons the tile
/// could not serve. Its expansion is seeded once from `initiallyExpanded` and
/// never re-read, so a parent cannot close a card it did not open — which is
/// exactly what one-card-at-a-time requires. And its internal padding decides
/// the row's height and the chevron's position, which left the label and the
/// chevron reading as two separate things and the tap target outside this
/// widget's control.
///
/// The `Semantics` wrapper is what makes the collapsed and expanded states
/// legible to a screen reader — expansion announced only by a turning chevron
/// is invisible to one.
class _WhyThisWorks extends StatelessWidget {
  const _WhyThisWorks({
    required this.title,
    required this.education,
    required this.expanded,
    required this.onToggle,
  });

  /// The accessible floor for a control, and the reason the row is given a
  /// minimum rather than being left to size to its text.
  static const double _minimumTapTarget = 44;

  final String title;
  final MakeupRecommendationEducation education;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          button: true,
          expanded: expanded,
          label: '$title, why this works for you',
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            // The whole row is the control, so the chevron is not a separate
            // target the label happens to sit beside.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _minimumTapTarget),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Why this works for you',
                      // Quieter than the category above it. It is an invitation
                      // to read more, not a second heading competing with the
                      // thing being explained — so it steps down in size and
                      // weight rather than in colour. Muting it would paint it
                      // `taupe`, which is the exact tone the button themes use
                      // for a *disabled* control.
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: AppIconSizes.md,
                    color: AppColors.muted(context),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Absent when closed rather than merely hidden, so a collapsed card
        // costs nothing to lay out and a screen reader is not walked through
        // text the user has not asked for.
        AnimatedSize(
          duration: AppDurations.quick,
          curve: AppCurves.standard,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _EducationSection(
                        heading: 'Your features',
                        body: education.features,
                      ),
                      _EducationSection(
                        heading: 'The effect',
                        body: education.effect,
                      ),
                      _EducationSection(
                        heading: 'The style',
                        body: education.style,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// One titled explanation.
class _EducationSection extends StatelessWidget {
  const _EducationSection({
    required this.heading,
    required this.body,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.xs),
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
          // Smaller than the category, so the three sections read as parts of
          // one explanation rather than three articles stacked in a card.
          Text(heading, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xxs),
          // Supporting content, so it sits a full step below the heading that
          // introduces it rather than matching its size and differing only in
          // weight. `bodySmall` also carries the scale's tighter line height
          // (1.45 against 1.5), which is where most of the expanded card's
          // height comes back — no hand-written multiplier needed.
          //
          // No maxLines and no ellipsis: an explanation that is cut off is
          // worse than one that makes the card taller, and the page scrolls.
          Text(body, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
