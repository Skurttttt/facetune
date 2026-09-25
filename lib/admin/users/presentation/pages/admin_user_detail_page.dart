import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/subscription/domain/entities/billing_provider.dart';
import '../../../../features/subscription/domain/entities/entitlement_status.dart';
import '../../../../features/subscription/domain/entities/subscription_plan_code.dart';
import '../../../app/admin_routes.dart';
import '../../../shared/admin_cards.dart';
import '../../../shared/admin_list_widgets.dart';
import '../../../shared/admin_page_header.dart';
import '../../../theme/admin_tokens.dart';
import '../../domain/admin_account_status.dart';
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
      Text('Loading user detail...'),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _IdentitySummary(detail: detail),
        const SizedBox(height: AdminSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final account = _Panel(
              key: const Key('admin-user-account-detail'),
              title: 'Account',
              rows: [
                ('User ID', detail.userId),
                ('Email', detail.email ?? 'No email'),
                ('Account created', formatDate(detail.accountCreatedAt)),
                ('Account status', detail.accountStatus.label),
              ],
            );
            final subscription = entitlement == null
                ? const _NoEntitlementPanel()
                : _EntitlementPanel(entitlement: entitlement);
            if (constraints.maxWidth >= 960) {
              return Row(
                key: const Key('admin-user-detail-information-wide'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: account),
                  const SizedBox(width: AdminSpacing.lg),
                  Expanded(child: subscription),
                ],
              );
            }
            return Column(
              key: const Key('admin-user-detail-information-stacked'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                account,
                const SizedBox(height: AdminSpacing.lg),
                subscription,
              ],
            );
          },
        ),
        const SizedBox(height: AdminSpacing.lg),
        _RelatedLinks(detail: detail, entitlement: entitlement),
        const SizedBox(height: AdminSpacing.lg),
        _AdministrativeActions(detail: detail, entitlement: entitlement),
      ],
    );
  }
}

class _IdentitySummary extends StatelessWidget {
  const _IdentitySummary({required this.detail});

  final AdminUserDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label:
          'User identity: ${detail.email ?? 'No email'}, '
          'account status: ${detail.accountStatus.label}',
      child: ExcludeSemantics(
        child: Row(
          key: const Key('admin-user-detail-identity'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.email ?? 'No email',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AdminSpacing.xxs),
                  SelectableText(
                    detail.userId,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AdminSpacing.md),
            AdminStatusBadge(
              label: detail.accountStatus.label,
              semanticsPrefix: 'Account status',
              emphasis: _accountEmphasis(detail.accountStatus),
            ),
          ],
        ),
      ),
    );
  }

  static AdminBadgeEmphasis _accountEmphasis(AdminAccountStatus status) =>
      switch (status) {
        AdminAccountStatus.active => AdminBadgeEmphasis.positive,
        AdminAccountStatus.unconfirmed => AdminBadgeEmphasis.caution,
        AdminAccountStatus.banned => AdminBadgeEmphasis.negative,
        AdminAccountStatus.anonymous => AdminBadgeEmphasis.information,
      };
}

class _RelatedLinks extends StatelessWidget {
  const _RelatedLinks({required this.detail, required this.entitlement});

  final AdminUserDetail detail;
  final AdminEntitlementDetail? entitlement;

  @override
  Widget build(BuildContext context) => AdminCard(
    key: const Key('admin-user-detail-related'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          title: 'Related',
          description: "Open this account's server-backed operational records.",
        ),
        const SizedBox(height: AdminSpacing.sm),
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
                  AdminRoutes.entitlementHistory(entitlement!.entitlementId),
                ),
                icon: const Icon(Icons.timeline_outlined, size: 18),
                label: const Text('Entitlement history'),
              ),
          ],
        ),
      ],
    ),
  );
}

class _AdministrativeActions extends StatelessWidget {
  const _AdministrativeActions({
    required this.detail,
    required this.entitlement,
  });

  final AdminUserDetail detail;
  final AdminEntitlementDetail? entitlement;

  bool get _isAdminGrantedPilot =>
      entitlement != null &&
      entitlement!.planCode == SubscriptionPlanCode.salonPilot &&
      entitlement!.billingProvider == BillingProvider.adminGranted;

  @override
  Widget build(BuildContext context) => AdminCard(
    key: const Key('admin-user-detail-administrative-actions'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          title: 'Administrative actions',
          description:
              'Open a reviewed workflow. Eligibility and changes remain '
              'server-authoritative.',
        ),
        const SizedBox(height: AdminSpacing.md),
        Wrap(
          spacing: AdminSpacing.xs,
          runSpacing: AdminSpacing.xs,
          children: [
            FilledButton.icon(
              key: const Key('admin-user-detail-grant-salon-pilot'),
              onPressed: () =>
                  context.go(AdminRoutes.grantSalonPilot(detail.userId)),
              icon: const Icon(Icons.card_giftcard_outlined, size: 18),
              label: const Text('Grant Salon Pilot'),
            ),
            if (_isAdminGrantedPilot)
              FilledButton.tonalIcon(
                key: const Key('admin-user-detail-adjust-allowance'),
                onPressed: () =>
                    context.go(AdminRoutes.adjustAllowance(detail.userId)),
                icon: const Icon(Icons.tune_outlined, size: 18),
                label: const Text('Adjust allowance'),
              ),
          ],
        ),
        if (_isAdminGrantedPilot) ...[
          const SizedBox(height: AdminSpacing.md),
          _LifecycleActions(detail: detail, entitlement: entitlement!),
        ],
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: AdminSpacing.xxs),
        Text(description, style: theme.textTheme.bodySmall),
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
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
            side: BorderSide(color: Theme.of(context).colorScheme.error),
          ),
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

class _NoEntitlementPanel extends StatelessWidget {
  const _NoEntitlementPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminCard(
      key: const Key('admin-user-entitlement-detail'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Current subscription',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: AdminSpacing.sm),
          const _DetailNotice(
            key: Key('admin-user-detail-no-entitlement'),
            message: 'No entitlement is available for this account.',
          ),
        ],
      ),
    );
  }
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
            LayoutBuilder(
              builder: (context, constraints) {
                final value = SelectableText(
                  row.$2,
                  style: row.$1 == 'User ID'
                      ? theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                        )
                      : theme.textTheme.bodyMedium,
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AdminSpacing.xxs,
                  ),
                  child: constraints.maxWidth < 420
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(row.$1, style: theme.textTheme.labelMedium),
                            const SizedBox(height: AdminSpacing.xxs),
                            value,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 180,
                              child: Text(
                                row.$1,
                                style: theme.textTheme.labelMedium,
                              ),
                            ),
                            Expanded(child: value),
                          ],
                        ),
                );
              },
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
