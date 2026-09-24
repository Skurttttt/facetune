import '../../../shared/admin_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/subscription/domain/entities/entitlement_status.dart';
import '../../../theme/admin_tokens.dart';
import '../../../app/admin_routes.dart';
import '../../../shared/admin_labels.dart';
import '../../../shared/admin_list_widgets.dart';
import '../../domain/admin_audit_models.dart';
import '../admin_audit_controller.dart';

class AdminAuditDetailPage extends ConsumerWidget {
  const AdminAuditDetailPage({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminAuditDetailControllerProvider(eventId));
    return Column(
      key: const Key('admin-audit-detail'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: () => context.go(AdminSection.audit.path),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back to audit'),
        ),
        const SizedBox(height: AdminSpacing.xs),
        const AdminPageHeader(
          title: 'Audit event',
          subtitle:
              'Read-only operational evidence with privacy-reviewed state.',
        ),
        const SizedBox(height: AdminSpacing.lg),
        switch (state) {
          AdminAuditDetailLoading() => const AdminListLoadingRow(
            label: 'Loading audit event',
          ),
          AdminAuditDetailNotFound() => const AdminListNotice(
            key: Key('admin-audit-detail-not-found'),
            icon: Icons.search_off_outlined,
            message: 'Audit event not found.',
          ),
          AdminAuditDetailUnavailable(:final retryable) => AdminListNotice(
            key: const Key('admin-audit-detail-unavailable'),
            icon: Icons.error_outline,
            message: 'Audit event could not be loaded.',
            action: retryable
                ? TextButton(
                    onPressed: ref
                        .read(
                          adminAuditDetailControllerProvider(eventId).notifier,
                        )
                        .load,
                    child: const Text('Try again'),
                  )
                : null,
          ),
          AdminAuditDetailReady(:final event) => _AuditDetail(event: event),
        },
      ],
    );
  }
}

class _AuditDetail extends StatelessWidget {
  const _AuditDetail({required this.event});
  final AdminAuditDetail event;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('admin-audit-detail-ready'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _ReadOnlyPanel(
        title: 'Event',
        rows: [
          ('Admin', event.adminEmail ?? 'Deleted administrator'),
          ('Admin user ID', event.adminUserId ?? 'Not retained'),
          ('Action', event.action.label),
          ('Target user', event.targetEmail ?? 'No email'),
          ('Target user ID', event.targetUserId),
          (
            'Target entitlement ID',
            event.targetEntitlementId ?? 'Not applicable',
          ),
          ('Reason', event.reason ?? 'Not provided'),
          ('Timestamp', formatUtcDateTime(event.createdAt)),
          (
            'Request correlation ID',
            event.requestCorrelationId ?? 'Not available',
          ),
          ('Event source', event.source.label),
        ],
      ),
      const SizedBox(height: AdminSpacing.sm),
      LayoutBuilder(
        builder: (context, constraints) {
          final panels = [
            _SnapshotPanel(title: 'Before state', snapshot: event.beforeState),
            _SnapshotPanel(title: 'After state', snapshot: event.afterState),
          ];
          if (constraints.maxWidth < 900) {
            return Column(
              children: [
                panels.first,
                const SizedBox(height: AdminSpacing.sm),
                panels.last,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: panels.first),
              const SizedBox(width: AdminSpacing.sm),
              Expanded(child: panels.last),
            ],
          );
        },
      ),
      if (event.targetEntitlementId != null) ...[
        const SizedBox(height: AdminSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('admin-audit-detail-history'),
            onPressed: () => context.go(
              AdminRoutes.entitlementHistory(event.targetEntitlementId!),
            ),
            icon: const Icon(Icons.timeline_outlined, size: 18),
            label: const Text('View entitlement history'),
          ),
        ),
      ],
    ],
  );
}

class _SnapshotPanel extends StatelessWidget {
  const _SnapshotPanel({required this.title, required this.snapshot});
  final String title;
  final AdminEntitlementStateSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final state = snapshot;
    return _ReadOnlyPanel(
      title: title,
      rows: state == null
          ? const [('State', 'Not applicable')]
          : [
              ('Status', _status(state.status)),
              ('Plan', state.planCode?.code ?? 'Not available'),
              (
                'Effective allowance',
                state.effectiveAllowance?.toString() ?? 'Not available',
              ),
              (
                'Allowance adjustment total',
                state.allowanceAdjustmentTotal?.toString() ?? 'Not available',
              ),
              (
                'Expiration',
                state.expiresAt == null
                    ? 'Not applicable'
                    : formatUtcDateTime(state.expiresAt!),
              ),
              ('Version', state.version?.toString() ?? 'Not available'),
            ],
    );
  }

  static String _status(EntitlementStatus? status) =>
      status == null ? 'Not available' : entitlementStatusLabel(status);
}

class _ReadOnlyPanel extends StatelessWidget {
  const _ReadOnlyPanel({required this.title, required this.rows});
  final String title;
  final List<(String, String)> rows;

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
                      width: 210,
                      child: Text(row.$1, style: theme.textTheme.labelMedium),
                    ),
                    Expanded(child: SelectableText(row.$2)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
