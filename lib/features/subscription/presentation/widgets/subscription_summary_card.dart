import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../controllers/subscription_controller.dart';
import '../controllers/subscription_state.dart';
import '../utils/ai_look_allowance_copy.dart';

/// The account's plan and remaining AI Looks, for the Profile screen.
///
/// Renders nothing at all until the server has answered. There is deliberately
/// no placeholder count and no optimistic default: an allowance the app made up
/// would be worse than silence, because the user would act on it.
class SubscriptionSummaryCard extends ConsumerWidget {
  const SubscriptionSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionControllerProvider);
    final copy = AiLookAllowanceCopy.forState(state);

    if (copy == null) {
      // Loading, signed out, unprovisioned, or a failure with nothing cached.
      // A retry is offered only when the failure is worth retrying and there is
      // no stale answer already on screen.
      if (state.status == SubscriptionStatus.failure && state.retryable) {
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: AppNotice(
            key: const ValueKey('subscription-summary-unavailable'),
            title: 'Subscription unavailable',
            message:
                state.message ??
                'Your subscription could not be loaded. Please try again.',
            tone: AppTone.info,
            actions: [
              TertiaryButton(
                label: 'Try again',
                onPressed: () =>
                    ref.read(subscriptionControllerProvider.notifier).refresh(),
              ),
            ],
          ),
        );
      }
      // Zero height, not merely invisible: a hidden card must not reserve
      // space or shift the rest of the page, on Profile or anywhere else it is
      // placed.
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    // The card owns its own leading gap, so the surrounding page needs no
    // spacer that would survive the card being hidden.
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: AppCard(
        key: const ValueKey('subscription-summary-card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(copy.planName, style: theme.textTheme.titleMedium),
                      if (copy.planQualifier != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          copy.planQualifier!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (state.isRefreshing)
                  const Padding(
                    padding: EdgeInsets.only(left: AppSpacing.sm),
                    child: SizedBox(
                      width: AppIconSizes.sm,
                      height: AppIconSizes.sm,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // The count and the date read as one statement to a screen reader,
            // rather than as two unrelated fragments.
            Semantics(
              container: true,
              label: copy.renewalLine == null
                  ? copy.remainingLine
                  : '${copy.remainingLine}. ${copy.renewalLine}',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(copy.remainingLine, style: theme.textTheme.titleLarge),
                    if (copy.renewalLine != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        copy.renewalLine!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (copy.headline != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppNotice(
                key: const ValueKey('subscription-summary-headline'),
                title: copy.headline,
                message: copy.detail ?? '',
                tone: copy.tone,
                actions: [
                  // Only where an upgrade is genuinely the next step. Salon
                  // Pilot is admin-granted and has no store product, so it
                  // never gets a route into the paywall.
                  if (copy.upgradePrompt)
                    TertiaryButton(
                      key: const ValueKey('subscription-summary-upgrade'),
                      label: 'See plans',
                      onPressed: () =>
                          context.push(AppConstants.subscriptionRoute),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TertiaryButton(
                key: const ValueKey('subscription-summary-compare-plans'),
                label: 'Compare plans',
                icon: Icons.list_alt_outlined,
                expand: false,
                onPressed: () => context.push(AppConstants.subscriptionRoute),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
