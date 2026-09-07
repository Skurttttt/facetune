import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../controllers/paywall_controller.dart';
import '../controllers/paywall_state.dart';
import '../controllers/subscription_controller.dart';
import '../utils/plan_presentation.dart';
import '../widgets/subscription_plan_card.dart';

/// The public plan comparison.
///
/// Shows Free, Plus, Pro, and Salon Pro. Salon Pilot is absent by construction:
/// the list comes from the plans the catalog marks publicly purchasable, and
/// Salon Pilot is admin-granted research access with no store product behind
/// it, so it cannot be added here by editing presentation code.
///
/// This screen cannot grant anything. Its actions are inert until Google Play
/// Billing exists, and the screen says so rather than offering a button that
/// silently fails.
///
/// There is deliberately no countdown, no "limited time", no struck-through
/// price, and no annual saving — none of those are real, and inventing them
/// would be a lie told to sell a subscription.
class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paywall = ref.watch(paywallControllerProvider);
    final subscription = ref.watch(subscriptionControllerProvider);
    final purchaseAvailable = ref.watch(purchaseAvailableProvider);
    final currentPlan = subscription.summary?.hasEntitlement == true
        ? subscription.summary?.planCode
        : null;

    return Scaffold(
      appBar: const FaceTuneTopBar(title: 'Plans'),
      body: SafeArea(
        top: false,
        child: PageFrame.scrolling(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            children: [
              Text(
                'Choose how many AI Looks you need',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Every plan uses the same AI and includes the Step-by-Step '
                'Tutorial. Plans differ only in how many AI Looks you can '
                'create.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted(context),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              if (!purchaseAvailable)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AppNotice(
                    key: const ValueKey('paywall-purchases-unavailable'),
                    title: 'Purchasing is not available yet',
                    message:
                        'You can compare plans here. Buying a plan will be '
                        'available in a future update of FaceTune.',
                    tone: AppTone.info,
                  ),
                ),

              if (paywall.status == PaywallStatus.loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: LoadingState(label: 'Loading plan prices…'),
                )
              else if (paywall.status == PaywallStatus.failure ||
                  !paywall.hasPrices)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AppNotice(
                    key: const ValueKey('paywall-prices-unavailable'),
                    title: 'Prices are not available right now',
                    message:
                        'Each plan still shows what it includes. The price you '
                        'pay is always the one shown by Google Play at '
                        'checkout, in your own currency.',
                    tone: AppTone.info,
                    actions: [
                      TertiaryButton(
                        label: 'Try again',
                        onPressed: () => ref
                            .read(paywallControllerProvider.notifier)
                            .retry(),
                      ),
                    ],
                  ),
                ),

              for (final plan in PlanPresentation.comparisonPlans)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: SubscriptionPlanCard(
                    plan: plan,
                    isCurrentPlan: currentPlan == plan,
                    price: paywall.priceFor(plan),
                    purchaseAvailable: purchaseAvailable,
                  ),
                ),

              // The restore seat SUB-11 will wire. Present so the layout and
              // the entry point are settled, and disabled for the same reason
              // the plan actions are.
              TertiaryButton(
                key: const ValueKey('paywall-restore-purchases'),
                label: 'Restore purchases',
                icon: Icons.restore_rounded,
                onPressed: purchaseAvailable ? () {} : null,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'An AI Look is one finished Final Makeup Preview you can '
                'reopen any time. Opening your History, Saved Looks, or a '
                'Tutorial never uses one.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted(context),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
