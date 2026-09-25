import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/subscription/domain/entities/billing_provider.dart';
import '../../../../features/subscription/domain/entities/entitlement_status.dart';
import '../../../../features/subscription/domain/entities/subscription_plan_code.dart';
import '../../../app/admin_routes.dart';
import '../../../shared/admin_cards.dart';
import '../../../shared/admin_page_header.dart';
import '../../../theme/admin_tokens.dart';
import '../../domain/admin_user_models.dart';
import '../admin_users_controller.dart';
import 'admin_users_page.dart' show formatDate;

class AdminUserDetailPage extends ConsumerWidget {
  const AdminUserDetailPage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminUserDetailControllerProvider(userId));
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
        const SizedBox(height: AdminSpacing.xs),
        const AdminPageHeader(
          title: 'User detail',
          subtitle:
              'One account: its current plan, allowance, and the '
              'administrative workflows it is eligible for.',
        ),
        const SizedBox(height: AdminSpacing.lg),
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
      SizedBox(width: AdminSpacing.sm),
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
        const SizedBox(height: AdminSpacing.sm),
        // WA-6: the same account's rows in the read-only listings.
        Wrap(
          spacing: AdminSpacing.xs,
          runSpacing: AdminSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
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
            TextButton.icon(
              key: const Key('admin-user-detail-audit'),
              onPressed: () =>
                  context.go(AdminRoutes.auditForUser(detail.userId)),
              icon: const Icon(Icons.history_outlined, size: 18),
              label: const Text('Audit events'),
            ),
            if (entitlement != null)
              TextButton.icon(
                key: const Key('admin-user-detail-history'),
                onPressed: () => context.go(
                  AdminRoutes.entitlementHistory(entitlement.entitlementId),
                ),
                icon: const Icon(Icons.timeline_outlined, size: 18),
                label: const Text('Entitlement history'),
              ),
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
              const SizedBox(width: AdminSpacing.xs),
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
        if (entitlement != null &&
            entitlement.planCode == SubscriptionPlanCode.salonPilot &&
            entitlement.billingProvider == BillingProvider.adminGranted) ...[
          const SizedBox(height: AdminSpacing.xs),
          _LifecycleActions(detail: detail, entitlement: entitlement),
        ],
        const SizedBox(height: AdminSpacing.sm),
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

class _LifecycleActions extends StatelessWidget {
  const _LifecycleActions({required this.detail, required this.entitlement});

  final AdminUserDetail detail;
  final AdminEntitlementDetail entitlement;

  bool get _canExtend =>
      entitlement.storedStatus != EntitlementStatus.expired &&
      entitlement.storedStatus != EntitlementStatus.revoked;

  bool get _canSuspend =>
      entitlement.effectiveStatus == EntitlementStatus.active ||
      entitlement.effectiveStatus == EntitlementStatus.gracePeriod;

  bool get _canReactivate =>
      entitlement.storedStatus == EntitlementStatus.suspended;

  bool get _canRevoke =>
      entitlement.storedStatus == EntitlementStatus.active ||
      entitlement.storedStatus == EntitlementStatus.gracePeriod ||
      entitlement.storedStatus == EntitlementStatus.suspended;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (_canExtend)
        OutlinedButton.icon(
          key: const Key('admin-user-detail-extend-expiration'),
          onPressed: () =>
              context.go(AdminRoutes.extendExpiration(detail.userId)),
          icon: const Icon(Icons.event_outlined, size: 18),
          label: const Text('Extend expiration'),
        ),
      if (_canSuspend)
        OutlinedButton.icon(
          key: const Key('admin-user-detail-suspend'),
          onPressed: () =>
              context.go(AdminRoutes.suspendEntitlement(detail.userId)),
          icon: const Icon(Icons.pause_circle_outline, size: 18),
          label: const Text('Suspend'),
        ),
      if (_canReactivate)
        OutlinedButton.icon(
          key: const Key('admin-user-detail-reactivate'),
          onPressed: () =>
              context.go(AdminRoutes.reactivateEntitlement(detail.userId)),
          icon: const Icon(Icons.play_circle_outline, size: 18),
          label: const Text('Reactivate'),
        ),
      if (_canRevoke)
        OutlinedButton.icon(
          key: const Key('admin-user-detail-revoke'),
          onPressed: () =>
              context.go(AdminRoutes.revokeEntitlement(detail.userId)),
          icon: const Icon(Icons.block_outlined, size: 18),
          label: const Text('Revoke access'),
        ),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();
    return Wrap(
      key: const Key('admin-user-detail-lifecycle-actions'),
      spacing: AdminSpacing.xs,
      runSpacing: AdminSpacing.xs,
      children: actions,
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
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: AdminSpacing.sm),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AdminSpacing.xxs),
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
        borderRadius: BorderRadius.circular(AdminRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: AdminSpacing.sm),
            Expanded(child: Text(message)),
            ?action,
          ],
        ),
      ),
    );
  }
}
