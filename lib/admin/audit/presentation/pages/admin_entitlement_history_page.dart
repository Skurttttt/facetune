import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../theme/app_tokens.dart';
import '../../../app/admin_routes.dart';
import '../../../shared/admin_keyset_list_controller.dart';
import '../../../shared/admin_labels.dart';
import '../../../shared/admin_list_widgets.dart';
import '../../domain/admin_audit_models.dart';
import '../admin_audit_controller.dart';

class AdminEntitlementHistoryPage extends ConsumerWidget {
  const AdminEntitlementHistoryPage({super.key, required this.entitlementId});

  final String entitlementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      adminEntitlementHistoryControllerProvider(entitlementId),
    );
    final controller = ref.read(
      adminEntitlementHistoryControllerProvider(entitlementId).notifier,
    );
    return Column(
      key: const Key('admin-entitlement-history'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: () => context.go(AdminSection.entitlements.path),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back to entitlements'),
        ),
        const SizedBox(height: AppSpacing.xs),
        const AdminSectionHeading(
          title: 'Entitlement history',
          description:
              'Newest first. Administrative actions and verified provider '
              'lifecycle events are shown from immutable records.',
        ),
        const SizedBox(height: AppSpacing.xs),
        SelectableText(
          entitlementId,
          key: const Key('admin-entitlement-history-id'),
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        const SizedBox(height: AppSpacing.lg),
        switch (state) {
          AdminListLoading() => const AdminListLoadingRow(
            label: 'Loading entitlement history',
          ),
          AdminListRejected() => const AdminListNotice(
            key: Key('admin-entitlement-history-rejected'),
            icon: Icons.error_outline,
            message: 'The history request was not accepted.',
          ),
          AdminListUnavailable(:final retryable) => AdminListNotice(
            key: const Key('admin-entitlement-history-unavailable'),
            icon: Icons.error_outline,
            message: 'Entitlement history could not be loaded.',
            action: retryable
                ? TextButton(
                    onPressed: controller.load,
                    child: const Text('Try again'),
                  )
                : null,
          ),
          AdminListReady(:final page) when page.items.isEmpty =>
            const AdminListNotice(
              key: Key('admin-entitlement-history-empty'),
              icon: Icons.timeline_outlined,
              message: 'No lifecycle events are recorded for this entitlement.',
            ),
          AdminListReady() => _HistoryResults(
            state: state,
            controller: controller,
          ),
        },
      ],
    );
  }
}

class _HistoryResults extends StatelessWidget {
  const _HistoryResults({required this.state, required this.controller});

  final AdminListReady<AdminEntitlementHistoryEvent, String> state;
  final AdminEntitlementHistoryController controller;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: state.refreshing ? 0.6 : 1,
    child: Column(
      key: const Key('admin-entitlement-history-results'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final event in state.page.items) ...[
          _HistoryCard(event: event),
          const SizedBox(height: AppSpacing.sm),
        ],
        AdminPaginationBar(
          keyPrefix: 'admin-entitlement-history',
          state: state,
          onPrevious: controller.previousPage,
          onNext: controller.nextPage,
        ),
      ],
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.event});
  final AdminEntitlementHistoryEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      key: ValueKey('admin-history-${event.source.code}-${event.id}'),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              event.source == AdminAuditSource.provider
                  ? Icons.cloud_sync_outlined
                  : Icons.admin_panel_settings_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _title(event),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Text(formatUtcDateTime(event.occurredAt)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(_summary(event)),
                  if (event.reason != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text('Reason: ${event.reason}'),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _actor(event),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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

  static String _title(
    AdminEntitlementHistoryEvent event,
  ) => switch (event.eventType) {
    AdminEntitlementHistoryEventType.grantSalonPilot => 'Salon Pilot granted',
    AdminEntitlementHistoryEventType.increaseAllowance ||
    AdminEntitlementHistoryEventType.decreaseAllowance => 'Allowance adjusted',
    AdminEntitlementHistoryEventType.extendExpiration => 'Expiration extended',
    AdminEntitlementHistoryEventType.suspendEntitlement => 'Suspended',
    AdminEntitlementHistoryEventType.reactivateEntitlement => 'Reactivated',
    AdminEntitlementHistoryEventType.revokeEntitlement => 'Revoked',
    AdminEntitlementHistoryEventType.providerStateChange =>
      'Provider-driven state change',
  };

  static String _summary(AdminEntitlementHistoryEvent event) {
    final before = event.beforeState;
    final after = event.afterState;
    return switch (event.eventType) {
      AdminEntitlementHistoryEventType.grantSalonPilot =>
        '${after?.effectiveAllowance ?? 'Not available'} AI Looks granted',
      AdminEntitlementHistoryEventType.increaseAllowance ||
      AdminEntitlementHistoryEventType.decreaseAllowance =>
        'Effective allowance ${before?.effectiveAllowance ?? '—'} → '
            '${after?.effectiveAllowance ?? '—'}',
      AdminEntitlementHistoryEventType.extendExpiration =>
        '${_date(before?.expiresAt)} → ${_date(after?.expiresAt)}',
      AdminEntitlementHistoryEventType.suspendEntitlement ||
      AdminEntitlementHistoryEventType.reactivateEntitlement ||
      AdminEntitlementHistoryEventType.revokeEntitlement =>
        '${before?.status?.code ?? 'unknown'} → '
            '${after?.status?.code ?? 'unknown'}',
      AdminEntitlementHistoryEventType.providerStateChange =>
        '${event.provider?.code ?? 'provider'} lifecycle reconciliation',
    };
  }

  static String _actor(AdminEntitlementHistoryEvent event) {
    if (event.source == AdminAuditSource.provider) {
      return 'Source: ${event.provider?.code ?? 'provider'}';
    }
    return 'Admin: ${event.actorEmail ?? event.actorUserId ?? 'deleted account'}';
  }

  static String _date(DateTime? value) =>
      value == null ? 'not available' : formatUtcDateTime(value);
}
