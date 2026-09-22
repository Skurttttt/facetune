import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/subscription/domain/entities/billing_provider.dart';
import '../../../../features/subscription/domain/entities/entitlement_status.dart';
import '../../../../features/subscription/domain/entities/subscription_plan_code.dart';
import '../../../../theme/app_tokens.dart';
import '../../../app/admin_routes.dart';
import '../../domain/admin_user_models.dart';
import '../admin_users_controller.dart';
import 'admin_users_page.dart' show formatDate;

class AdminUserDetailPage extends ConsumerWidget {
  const AdminUserDetailPage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminUserDetailControllerProvider(userId));
    final theme = Theme.of(context);
    return Column(
      key: const Key('admin-user-detail'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          key: const Key('admin-user-detail-back'),
          onPressed: () => context.go(AdminSection.users.path),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back to users'),
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          header: true,
          child: Text('User detail', style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.lg),
        switch (state) {
          AdminUserDetailLoading() => const _DetailLoading(),
          AdminUserDetailNotFound() => const _DetailNotice(
            key: Key('admin-user-detail-not-found'),
            message: 'User not found.',
          ),
          AdminUserDetailUnavailable(:final retryable) => _DetailNotice(
            key: const Key('admin-user-detail-unavailable'),
            message: 'User detail could not be loaded.',
            action: retryable
                ? TextButton(
                    onPressed: ref
                        .read(
                          adminUserDetailControllerProvider(userId).notifier,
                        )
                        .load,
                    child: const Text('Try again'),
                  )
                : null,
          ),
          AdminUserDetailReady(:final detail) => _Detail(detail: detail),
        },
      ],
    );
  }
}

class _DetailLoading extends StatelessWidget {
  const _DetailLoading();

  @override
  Widget build(BuildContext context) => const Row(
    key: Key('admin-user-detail-loading'),
    children: [
      SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          semanticsLabel: 'Loading user detail',
        ),
      ),
      SizedBox(width: AppSpacing.sm),
      Text('Loading user detailâ€¦'),
    ],
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.detail});

  final AdminUserDetail detail;

  @override
  Widget build(BuildContext context) {
    final entitlement = detail.entitlement;
    return Column(
      key: const Key('admin-user-detail-ready'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Panel(
          title: 'Account',
          rows: [
            ('User ID', detail.userId),
            ('Email', detail.email ?? 'No email'),
            ('Account created', formatDate(detail.accountCreatedAt)),
            ('Account status', detail.accountStatus.label),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // WA-6: the same account's rows in the read-only listings.
        Row(
          children: [
            TextButton.icon(
              key: const Key('admin-user-detail-entitlements'),
              onPressed: () =>
                  context.go(AdminRoutes.entitlementsForUser(detail.userId)),
              icon: const Icon(Icons.verified_user_outlined, size: 18),
              label: const Text('All entitlements'),
            ),
            TextButton.icon(
              key: const Key('admin-user-detail-usage'),
              onPressed: () =>
                  context.go(AdminRoutes.usageForUser(detail.userId)),
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: const Text('Usage ledger'),
            ),
            const Spacer(),
            // WA-7: the one privileged action so far. The server decides
            // whether this account may receive a grant; the button only
            // opens the reviewed, confirmed workflow.
            FilledButton.tonalIcon(
              key: const Key('admin-user-detail-grant-salon-pilot'),
              onPressed: () =>
                  context.go(AdminRoutes.grantSalonPilot(detail.userId)),
              icon: const Icon(Icons.card_giftcard_outlined, size: 18),
              label: const Text('Grant Salon Pilot'),
            ),
            // WA-8: only an admin-granted Salon Pilot has an editable
            // allowance; the server re-checks this whatever the button says.
            if (entitlement != null &&
                entitlement.planCode == SubscriptionPlanCode.salonPilot &&
                entitlement.billingProvider ==
                    BillingProvider.adminGranted) ...[
              const SizedBox(width: AppSpacing.xs),
              FilledButton.tonalIcon(
                key: const Key('admin-user-detail-adjust-allowance'),
                onPressed: () =>
                    context.go(AdminRoutes.adjustAllowance(detail.userId)),
                icon: const Icon(Icons.tune_outlined, size: 18),
                label: const Text('Adjust allowance'),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (entitlement == null)
          const _DetailNotice(
            key: Key('admin-user-detail-no-entitlement'),
            message: 'No entitlement is available for this account.',
          )
        else
          _EntitlementPanel(entitlement: entitlement),
      ],
    );
  }
}

class _EntitlementPanel extends StatelessWidget {
  const _EntitlementPanel({required this.entitlement});

  final AdminEntitlementDetail entitlement;

  @override
  Widget build(BuildContext context) {
    final unit = entitlement.allowanceUnit;
    return _Panel(
      key: const Key('admin-user-entitlement-detail'),
      title: 'Current subscription',
      rows: [
        ('Current plan', entitlement.planDisplayName),
        ('Entitlement status', _status(entitlement.effectiveStatus)),
        ('Billing provider', _provider(entitlement.billingProvider)),
        ('${unit.singular} limit', '${entitlement.effectiveAllowance}'),
        ('Committed usage', '${entitlement.committedUsage}'),
        ('Reserved usage', '${entitlement.reservedUsage}'),
        ('Remaining usage', '${entitlement.remainingAiLooks}'),
        ('Available for a new generation', '${entitlement.availableAiLooks}'),
        ('Period start', _dateOrDash(entitlement.periodStart)),
        ('Period end', _dateOrDash(entitlement.periodEnd)),
        ('Expiration', _dateOrDash(entitlement.expiresAt)),
        ('Auto-renew', entitlement.autoRenew ? 'On' : 'Off'),
      ],
    );
  }

  static String _status(EntitlementStatus status) => switch (status) {
    EntitlementStatus.pending => 'Pending',
    EntitlementStatus.active => 'Active',
    EntitlementStatus.gracePeriod => 'Grace Period',
    EntitlementStatus.expired => 'Expired',
    EntitlementStatus.suspended => 'Suspended',
    EntitlementStatus.revoked => 'Revoked',
  };

  static String _provider(BillingProvider provider) => switch (provider) {
    BillingProvider.none => 'None',
    BillingProvider.googlePlay => 'Google Play',
    BillingProvider.appleAppStore => 'Apple App Store',
    BillingProvider.adminGranted => 'Admin Granted',
  };

  static String _dateOrDash(DateTime? value) =>
      value == null ? 'Not applicable' : formatDate(value);
}

class _Panel extends StatelessWidget {
  const _Panel({super.key, required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 220,
                      child: Text(row.$1, style: theme.textTheme.labelMedium),
                    ),
                    Expanded(
                      child: SelectableText(
                        row.$2,
                        style: row.$1 == 'User ID'
                            ? theme.textTheme.bodyMedium?.copyWith(
                                fontFamily: 'monospace',
                              )
                            : theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailNotice extends StatelessWidget {
  const _DetailNotice({super.key, required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
            ?action,
          ],
        ),
      ),
    );
  }
}
