import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/catalog/subscription_plan_catalog.dart';
import '../../domain/entities/plan_price.dart';
import '../../domain/entities/subscription_plan_code.dart';
import '../utils/plan_presentation.dart';

/// One plan on the paywall.
///
/// The price slot renders whatever the billing provider returned and nothing
/// else. When no price is available it says so plainly rather than falling
/// back to a figure typed into the app, because a price the store does not
/// charge is worse than no price at all.
///
/// Reading order, top to bottom: who the plan is, who it is for, what it
/// costs, how many AI Looks it gives, what else it includes, and the action.
/// The price and the allowance are the two things a person compares across
/// cards, so they are the two things drawn heaviest.
class SubscriptionPlanCard extends StatelessWidget {
  const SubscriptionPlanCard({
    required this.plan,
    required this.isCurrentPlan,
    required this.price,
    required this.purchaseAvailable,
    super.key,
    this.onSelect,
    this.inFlightLabel,
  });

  final SubscriptionPlanCode plan;

  /// Whether this is the account's current plan, per authoritative state.
  final bool isCurrentPlan;

  /// The provider's localized price, or null when none is available.
  final PlanPrice? price;

  /// Whether a purchase can actually be started from this build.
  final bool purchaseAvailable;

  final VoidCallback? onSelect;

  /// What the action says while a purchase of *this* plan is in flight, or
  /// null when none is.
  ///
  /// Wording only. Non-null draws the button's spinner and its in-progress
  /// label; it does not decide whether the button is enabled — that is still
  /// [purchaseAvailable], which the page derives from the same purchase state
  /// and which is already false while any purchase is open.
  final String? inFlightLabel;

  /// Shown in place of a price the store has not supplied.
  static const String priceFallback = 'Price shown at checkout';

  bool get _isFree => plan == SubscriptionPlanCode.free;

  /// Whether the paywall leads with this plan. Presentation metadata from
  /// [PlanPresentation.emphasis]; it says nothing about what the account has.
  bool get _isRecommended =>
      PlanPresentation.emphasis(plan) == PlanEmphasis.recommended;

  /// The recommendation is shown only while it is still a recommendation.
  /// Once the plan is the account's own, "Current plan" is the one word that
  /// matters and the badge slot belongs to it.
  bool get _showsRecommendation => _isRecommended && !isCurrentPlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final definition = SubscriptionPlanCatalog.definitionFor(plan);
    final allowanceLine = PlanPresentation.allowanceLine(plan);
    final tagline = PlanPresentation.tagline(plan);
    // The theme's accent, resolved per brightness: rose on the light card and
    // the lightened tone on the dark one, where raw rose falls under 3:1.
    final accent = AppTone.info.resolve(context).accent;
    // What a screen reader is told the price is. The same words a sighted
    // reader sees, in the same order.
    final priceLabel = _isFree
        ? 'Free'
        : (price?.displayPrice ?? priceFallback);

    // Two nodes for assistive technology, not one and not many. The first is
    // the plan described as a single statement — name, state, allowance,
    // price, purpose — so a screen reader user hears the card as one thing
    // rather than as six fragments. The second is the action, which stays a
    // real button: reachable, labelled, and honest about being disabled.
    // (Until SUB-UI-6 the whole card sat behind one ExcludeSemantics, and the
    // purchase button could not be reached by a screen reader at all.)
    final description = Semantics(
      container: true,
      // The card the account is on is the selected one among its peers.
      selected: isCurrentPlan,
      label: [
        definition.displayName,
        if (isCurrentPlan) 'Your current plan',
        if (_showsRecommendation) 'Recommended',
        allowanceLine,
        priceLabel,
        tagline,
      ].join('. '),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Identity. Name and badge share a Wrap rather than a Row, so
            // on a narrow screen with large text the badge drops under the
            // name instead of squeezing it — or overflowing the card.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  PlanPresentation.icon(plan),
                  size: AppIconSizes.md,
                  color: accent,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xxs,
                    children: [
                      Text(
                        definition.displayName,
                        style: theme.textTheme.titleMedium,
                      ),
                      // One badge at most. Current plan outranks
                      // recommendation: telling someone the plan they
                      // already pay for is "recommended" is noise at best
                      // and a sales pitch at worst. The slot cross-fades
                      // when the server's answer changes which badge this
                      // is — after a verified purchase, "Recommended"
                      // becomes "Current plan" rather than snapping.
                      AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : AppDurations.quick,
                        switchInCurve: AppCurves.standard,
                        switchOutCurve: AppCurves.standard,
                        child: isCurrentPlan
                            ? _PlanBadge(
                                key: ValueKey('plan-current-${plan.code}'),
                                label: 'Current plan',
                                icon: Icons.check_circle_outline_rounded,
                              )
                            : _showsRecommendation
                            ? _PlanBadge(
                                key: ValueKey('plan-recommended-${plan.code}'),
                                label: 'Recommended',
                                icon: Icons.recommend_outlined,
                                tinted: true,
                              )
                            : SizedBox.shrink(
                                key: ValueKey('plan-no-badge-${plan.code}'),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Purpose.
            const SizedBox(height: AppSpacing.xxs),
            Text(
              tagline,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted(context),
              ),
            ),
            // Price.
            const SizedBox(height: AppSpacing.md),
            _PriceLine(plan: plan, price: price, isFree: _isFree),
            // Allowance — the number a person is actually choosing between.
            const SizedBox(height: AppSpacing.sm),
            _AllowanceRow(plan: plan, line: allowanceLine),
            // Benefits.
            const SizedBox(height: AppSpacing.md),
            for (final feature in PlanPresentation.features(plan))
              _FeatureRow(feature: feature, accent: accent),
          ],
        ),
      ),
    );

    return AppCard(
      key: ValueKey('plan-card-${plan.code}'),
      // The heavier boundary marks the plan the account holds, and the plan
      // the page recommends. Each carries its own badge, so two emphasized
      // cards on one screen are never ambiguous. Selection is reported by the
      // description node above, so the card itself stays silent about it —
      // otherwise a merely recommended card would be read as "selected".
      emphasized: isCurrentPlan || _showsRecommendation,
      selected: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          description,
          // Action. One filled button on the page — the recommended
          // plan's — and outlined buttons for the rest, so the hierarchy
          // the badges state is the hierarchy the buttons draw. Every
          // branch keeps the same key, label and callback: only the
          // emphasis differs.
          if (!_isFree) ...[
            const SizedBox(height: AppSpacing.sm),
            if (isCurrentPlan)
              SecondaryButton(
                key: ValueKey('plan-action-${plan.code}'),
                label: 'Your current plan',
                showIcon: false,
                onPressed: null,
              )
            else if (_isRecommended)
              PrimaryButton(
                key: ValueKey('plan-action-${plan.code}'),
                label: inFlightLabel ?? 'Choose ${definition.displayName}',
                showIcon: false,
                // A spinner while this plan's purchase is in flight. The
                // button is already disabled then (the store refuses a
                // second purchase while one is open), so this changes what
                // is drawn, not what can be tapped.
                isLoading: inFlightLabel != null,
                // Disabled until the store can sell this plan. An enabled
                // button that quietly does nothing would be worse than an
                // honest one the screen explains.
                onPressed: purchaseAvailable ? onSelect : null,
              )
            else
              SecondaryButton(
                key: ValueKey('plan-action-${plan.code}'),
                label: inFlightLabel ?? 'Choose ${definition.displayName}',
                showIcon: false,
                isLoading: inFlightLabel != null,
                onPressed: purchaseAvailable ? onSelect : null,
              ),
          ],
        ],
      ),
    );
  }
}

/// A plan's one-word state, beside its name.
///
/// The themed `Chip` with a glyph in front of the word, so the state is
/// carried by an icon and a label together and never by tint alone. The
/// untinted form is for the plan the account is on — a fact, drawn on the
/// card's own surface. The tinted form is for the recommendation — a
/// suggestion, drawn on the info role's surface so it reads as the page
/// speaking rather than as a property of the plan.
class _PlanBadge extends StatelessWidget {
  const _PlanBadge({
    required this.label,
    required this.icon,
    super.key,
    this.tinted = false,
  });

  final String label;
  final IconData icon;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final role = AppTone.info.resolve(context);
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(icon, size: AppIconSizes.sm, color: role.accent),
      label: Text(label),
      labelStyle: tinted
          ? theme.chipTheme.labelStyle?.copyWith(color: role.onSurface)
          : null,
      backgroundColor: tinted ? role.surface : null,
      side: tinted
          ? BorderSide(color: role.border, width: AppBorders.hairline)
          : null,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// The price, with the store's amount leading and its billing period
/// following in the supporting role.
///
/// One paragraph, not two widgets: the two spans share a baseline without any
/// alignment arithmetic, they wrap together when a localized amount is long,
/// and the plain text still reads `amount / period` — exactly the string
/// `PlanPrice.displayPrice` produces, so nothing that matched the price before
/// stops matching it now. The amount is never parsed, split, or reformatted;
/// it is the provider's string, verbatim.
class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.plan,
    required this.price,
    required this.isFree,
  });

  final SubscriptionPlanCode plan;
  final PlanPrice? price;
  final bool isFree;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final key = ValueKey('plan-price-${plan.code}');
    final amountStyle = theme.textTheme.headlineSmall;

    if (isFree) return Text('Free', key: key, style: amountStyle);

    final quoted = price;
    if (quoted == null) {
      // Not a price, so not set in the price role: a fallback drawn at amount
      // weight would read as though the store had answered.
      return Text(
        SubscriptionPlanCard.priceFallback,
        key: key,
        style: theme.textTheme.titleMedium?.copyWith(
          color: AppColors.muted(context),
        ),
      );
    }

    final period = quoted.billingPeriodLabel;
    return Text.rich(
      TextSpan(
        style: amountStyle,
        children: [
          TextSpan(text: quoted.formattedPrice),
          if (period != null)
            TextSpan(
              text: ' / $period',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted(context),
              ),
            ),
        ],
      ),
      key: key,
    );
  }
}

/// The AI Look allowance on its own quiet tinted row, so the eye finds the
/// number without reading the card.
///
/// The info role supplies surface, border and foreground together, which is
/// what keeps the row legible in dark mode — the tint there is dark and the
/// text light, not petal with near-white text on it.
class _AllowanceRow extends StatelessWidget {
  const _AllowanceRow({required this.plan, required this.line});

  final SubscriptionPlanCode plan;
  final String line;

  @override
  Widget build(BuildContext context) {
    final role = AppTone.info.resolve(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: role.surface,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: role.border, width: AppBorders.hairline),
      ),
      child: Row(
        children: [
          Icon(
            Icons.face_retouching_natural_outlined,
            size: AppIconSizes.sm,
            color: role.accent,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              line,
              key: ValueKey('plan-allowance-${plan.code}'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: role.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

/// One included benefit: a check and a line of copy.
///
/// The check is centred on the *first line* of the text rather than on the
/// whole block, so a benefit that wraps still reads as a bullet and not as a
/// glyph floating beside a paragraph. The offset comes from the text style's
/// own line height and the user's text scale, not from a typed-in constant.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature, required this.accent});

  final String feature;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final fontSize = MediaQuery.textScalerOf(
      context,
    ).scale(style?.fontSize ?? 14);
    final lineHeight = fontSize * (style?.height ?? 1.0);
    final iconInset = ((lineHeight - AppIconSizes.sm) / 2).clamp(
      0.0,
      lineHeight,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: iconInset),
            child: Icon(
              Icons.check_rounded,
              size: AppIconSizes.sm,
              color: accent,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(feature, style: style)),
        ],
      ),
    );
  }
}
