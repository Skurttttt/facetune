import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/entities/plan_price.dart';
import '../../domain/entities/top_up_pack.dart';

/// One top-up pack on the paywall.
///
/// The same rules as `SubscriptionPlanCard`: the price slot renders whatever
/// the billing provider returned and nothing else, and the card can grant
/// nothing — tapping it opens Google Play's purchase sheet, and what the
/// account holds afterwards is read back from the server.
///
/// Reading order: what the pack is, what it adds, whether that includes the
/// Tutorial, what it costs, and the action. The capability line is stated on
/// every card, in words, because the two packs cost the same and differ only
/// in it — a person must never buy a Preview Boost believing it carries the
/// Tutorial.
class TopUpPackCard extends StatelessWidget {
  const TopUpPackCard({
    required this.pack,
    required this.price,
    required this.purchaseAvailable,
    super.key,
    this.onSelect,
    this.inFlightLabel,
  });

  final TopUpPack pack;

  /// The provider's localized price, or null when none is available.
  final PlanPrice? price;

  /// Whether a purchase can actually be started from this build.
  final bool purchaseAvailable;

  final VoidCallback? onSelect;

  /// What the action says while a purchase of *this* pack is in flight.
  final String? inFlightLabel;

  /// Shown in place of a price the store has not supplied.
  static const String priceFallback = 'Price shown at checkout';

  /// The one line that tells the two packs apart.
  static String capabilityLine(TopUpPack pack) => pack.tutorialCapable
      ? 'Includes the Step-by-Step Tutorial'
      : 'Final Previews only — no Tutorial';

  /// What every pack has in common, said once per card so it is never
  /// missed: credits are kept, and they are spent after the plan's own.
  static const String persistenceLine =
      'Used after your plan\'s included allowance. Kept on your account, '
      'even across renewals — usable while a paid plan is active.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTone.info.resolve(context).accent;
    final priceLabel = price?.displayPrice ?? priceFallback;
    final capability = capabilityLine(pack);

    final description = Semantics(
      container: true,
      label: [
        pack.displayName,
        pack.quantityLine,
        capability,
        priceLabel,
        persistenceLine,
      ].join('. '),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  pack.tutorialCapable
                      ? Icons.add_circle_outline_rounded
                      : Icons.add_photo_alternate_outlined,
                  size: AppIconSizes.md,
                  color: accent,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    pack.displayName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(priceLabel, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xxs),
            Text(pack.quantityLine, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              capability,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: pack.tutorialCapable ? null : AppColors.muted(context),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              persistenceLine,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted(context),
              ),
            ),
          ],
        ),
      ),
    );

    return AppCard(
      key: ValueKey('top-up-card-${pack.code}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          description,
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            key: ValueKey('top-up-action-${pack.code}'),
            label: inFlightLabel ?? 'Add ${pack.displayName}',
            showIcon: false,
            isLoading: inFlightLabel != null,
            // Disabled until the store can sell this pack, exactly as a plan.
            onPressed: purchaseAvailable ? onSelect : null,
          ),
        ],
      ),
    );
  }
}
