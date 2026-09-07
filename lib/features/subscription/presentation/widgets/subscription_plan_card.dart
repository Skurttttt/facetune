import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
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
class SubscriptionPlanCard extends StatelessWidget {
  const SubscriptionPlanCard({
    required this.plan,
    required this.isCurrentPlan,
    required this.price,
    required this.purchaseAvailable,
    super.key,
    this.onSelect,
  });

  final SubscriptionPlanCode plan;

  /// Whether this is the account's current plan, per authoritative state.
  final bool isCurrentPlan;

  /// The provider's localized price, or null when none is available.
  final PlanPrice? price;

  /// Whether a purchase can actually be started from this build.
  final bool purchaseAvailable;

  final VoidCallback? onSelect;

  bool get _isFree => plan == SubscriptionPlanCode.free;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final definition = SubscriptionPlanCatalog.definitionFor(plan);
    final allowanceLine = PlanPresentation.allowanceLine(plan);
    final priceLabel = _isFree
        ? 'Free'
        : (price?.displayPrice ?? 'Price shown at checkout');

    return Semantics(
      container: true,
      // One statement rather than five fragments, and it names the current
      // plan explicitly so a screen reader user is not left to infer it from a
      // visual badge.
      label: [
        definition.displayName,
        if (isCurrentPlan) 'Your current plan',
        allowanceLine,
        priceLabel,
      ].join('. '),
      child: ExcludeSemantics(
        child: AppCard(
          key: ValueKey('plan-card-${plan.code}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    PlanPresentation.icon(plan),
                    size: AppIconSizes.md,
                    color: AppColors.rose,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      definition.displayName,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (isCurrentPlan)
                    Chip(
                      key: ValueKey('plan-current-${plan.code}'),
                      label: const Text('Current plan'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                PlanPresentation.tagline(plan),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted(context),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                priceLabel,
                key: ValueKey('plan-price-${plan.code}'),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                allowanceLine,
                key: ValueKey('plan-allowance-${plan.code}'),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              for (final feature in PlanPresentation.features(plan))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.check_rounded,
                          size: AppIconSizes.sm,
                          color: AppColors.rose,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(feature, style: theme.textTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
              if (!_isFree) ...[
                const SizedBox(height: AppSpacing.md),
                if (isCurrentPlan)
                  SecondaryButton(
                    key: ValueKey('plan-action-${plan.code}'),
                    label: 'Your current plan',
                    showIcon: false,
                    onPressed: null,
                  )
                else
                  PrimaryButton(
                    key: ValueKey('plan-action-${plan.code}'),
                    label: 'Choose ${definition.displayName}',
                    showIcon: false,
                    // Disabled until billing exists. An enabled button that
                    // quietly does nothing would be worse than an honest one
                    // the screen explains.
                    onPressed: purchaseAvailable ? onSelect : null,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
