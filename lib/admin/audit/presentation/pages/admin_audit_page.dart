import '../../../shared/admin_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/admin_tokens.dart';
import '../../../app/admin_routes.dart';
import '../../../shared/admin_keyset_list_controller.dart';
import '../../../shared/admin_labels.dart';
import '../../../shared/admin_list_widgets.dart';
import '../../../shared/admin_wire.dart';
import '../../domain/admin_audit_models.dart';
import '../admin_audit_controller.dart';

class AdminAuditPage extends ConsumerStatefulWidget {
  const AdminAuditPage({
    super.key,
    this.initialFilters = AdminAuditFilters.none,
  });

  final AdminAuditFilters initialFilters;

  @override
  ConsumerState<AdminAuditPage> createState() => _AdminAuditPageState();
}

class _AdminAuditPageState extends ConsumerState<AdminAuditPage> {
  late final TextEditingController _adminId = TextEditingController(
    text: widget.initialFilters.adminUserId ?? '',
  );
  late final TextEditingController _targetUserId = TextEditingController(
    text: widget.initialFilters.targetUserId ?? '',
  );
  late final TextEditingController _entitlementId = TextEditingController(
    text: widget.initialFilters.targetEntitlementId ?? '',
  );
  late AdminAuditAction? _action = widget.initialFilters.action;
  late AdminAuditSource? _source = widget.initialFilters.source;
  late AdminAuditDateRange? _dateRange = widget.initialFilters.dateRange;
  String? _adminError;
  String? _userError;
  String? _entitlementError;
  int _filterGeneration = 0;

  @override
  void dispose() {
    _adminId.dispose();
    _targetUserId.dispose();
    _entitlementId.dispose();
    super.dispose();
  }

  AdminAuditController get _controller =>
      ref.read(adminAuditControllerProvider(widget.initialFilters).notifier);

  Future<void> _apply() async {
    final adminError = isMalformedUuidInput(_adminId.text);
    final userError = isMalformedUuidInput(_targetUserId.text);
    final entitlementError = isMalformedUuidInput(_entitlementId.text);
    setState(() {
      _adminError = adminError ? 'Enter a full Admin user ID.' : null;
      _userError = userError ? 'Enter a full target User ID.' : null;
      _entitlementError = entitlementError
          ? 'Enter a full Entitlement ID.'
          : null;
    });
    if (adminError || userError || entitlementError) return;

    final filters = AdminAuditFilters(
      adminUserId: normalizeUuid(_adminId.text),
      action: _action,
      targetUserId: normalizeUuid(_targetUserId.text),
      targetEntitlementId: normalizeUuid(_entitlementId.text),
      source: _source,
    );
    await _controller.applyFilters(
      AdminAuditFilters.withRange(
        filters,
        _dateRange,
        now: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> _clear() async {
    setState(() {
      _adminId.clear();
      _targetUserId.clear();
      _entitlementId.clear();
      _action = null;
      _source = null;
      _dateRange = null;
      _adminError = null;
      _userError = null;
      _entitlementError = null;
      _filterGeneration++;
    });
    await _controller.applyFilters(AdminAuditFilters.none);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      adminAuditControllerProvider(widget.initialFilters),
    );
    final busy = state is AdminListLoading;
    return Column(
      key: const Key('admin-section-audit'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const AdminPageHeader(
          title: 'Audit',
          subtitle:
              'Immutable administrative actions, filtered and paginated on '
              'the server. Open a row for its privacy-reviewed state change.',
        ),
        const SizedBox(height: AdminSpacing.md),
        KeyedSubtree(
          key: ValueKey(_filterGeneration),
          child: Wrap(
            spacing: AdminSpacing.sm,
            runSpacing: AdminSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              AdminFilterSlot(
                width: 330,
                child: TextField(
                  key: const Key('admin-audit-filter-admin'),
                  controller: _adminId,
                  decoration: InputDecoration(
                    labelText: 'Admin user ID',
                    helperText: 'Exact UUID',
                    errorText: _adminError,
                  ),
                ),
              ),
              AdminFilterSlot(
                width: 330,
                child: TextField(
                  key: const Key('admin-audit-filter-target-user'),
                  controller: _targetUserId,
                  decoration: InputDecoration(
                    labelText: 'Target user ID',
                    helperText: 'Exact UUID',
                    errorText: _userError,
                  ),
                ),
              ),
              AdminFilterSlot(
                width: 330,
                child: TextField(
                  key: const Key('admin-audit-filter-entitlement'),
                  controller: _entitlementId,
                  decoration: InputDecoration(
                    labelText: 'Target entitlement ID',
                    helperText: 'Exact UUID',
                    errorText: _entitlementError,
                  ),
                ),
              ),
              AdminFilterSlot(
                width: 250,
                child: DropdownButtonFormField<AdminAuditAction?>(
                  key: const Key('admin-audit-filter-action'),
                  initialValue: _action,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Action'),
                  items: [
                    const DropdownMenuItem(child: Text('Any action')),
                    for (final action in AdminAuditAction.values)
                      DropdownMenuItem(
                        value: action,
                        child: Text(action.label),
                      ),
                  ],
                  onChanged: (value) => setState(() => _action = value),
                ),
              ),
              AdminFilterSlot(
                child: DropdownButtonFormField<AdminAuditSource?>(
                  key: const Key('admin-audit-filter-source'),
                  initialValue: _source,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Event source'),
                  items: [
                    const DropdownMenuItem(child: Text('Any source')),
                    for (final source in AdminAuditSource.values)
                      DropdownMenuItem(
                        value: source,
                        child: Text(source.label),
                      ),
                  ],
                  onChanged: (value) => setState(() => _source = value),
                ),
              ),
              AdminFilterSlot(
                child: DropdownButtonFormField<AdminAuditDateRange?>(
                  key: const Key('admin-audit-filter-date'),
                  initialValue: _dateRange,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Date'),
                  items: [
                    const DropdownMenuItem(child: Text('Any date')),
                    for (final range in AdminAuditDateRange.values)
                      DropdownMenuItem(value: range, child: Text(range.label)),
                  ],
                  onChanged: (value) => setState(() => _dateRange = value),
                ),
              ),
              FilledButton.icon(
                key: const Key('admin-audit-apply'),
                onPressed: busy ? null : _apply,
                icon: const Icon(Icons.filter_alt_outlined, size: 18),
                label: const Text('Apply filters'),
              ),
              TextButton(
                key: const Key('admin-audit-clear'),
                onPressed: busy ? null : _clear,
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AdminSpacing.lg),
        switch (state) {
          AdminListLoading() => const AdminListLoadingRow(
            key: Key('admin-audit-loading'),
            label: 'Loading audit events',
          ),
          AdminListRejected() => const AdminListNotice(
            key: Key('admin-audit-rejected'),
            icon: Icons.error_outline,
            message: 'The server did not accept these audit filters.',
          ),
          AdminListUnavailable(:final retryable) => AdminListNotice(
            key: const Key('admin-audit-unavailable'),
            icon: Icons.error_outline,
            message: 'Audit events could not be loaded.',
            action: retryable
                ? TextButton(
                    onPressed: _controller.load,
                    child: const Text('Try again'),
                  )
                : null,
          ),
          AdminListReady(:final page) when page.items.isEmpty =>
            const AdminListNotice(
              key: Key('admin-audit-empty'),
              icon: Icons.history_outlined,
              message: 'No audit events matched these filters.',
            ),
          AdminListReady() => _AuditResults(
            state: state,
            controller: _controller,
          ),
        },
      ],
    );
  }
}

class _AuditResults extends StatelessWidget {
  const _AuditResults({required this.state, required this.controller});

  final AdminListReady<AdminAuditListItem, AdminAuditFilters> state;
  final AdminAuditController controller;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: state.refreshing ? 0.6 : 1,
    child: Column(
      key: const Key('admin-audit-results'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminTable(
          key: const Key('admin-audit-table'),
          columns: const [
            DataColumn(label: Text('Timestamp')),
            DataColumn(label: Text('Admin')),
            DataColumn(label: Text('Action')),
            DataColumn(label: Text('Target user')),
            DataColumn(label: Text('Target entitlement')),
            DataColumn(label: Text('Event source')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final row in state.page.items)
              DataRow(
                key: ValueKey('admin-audit-${row.id}'),
                cells: [
                  DataCell(Text(formatUtcDateTime(row.createdAt))),
                  DataCell(
                    AdminIdentityCell(
                      email: row.adminEmail,
                      userId: row.adminUserId,
                      emptyLabel: 'Deleted administrator',
                    ),
                  ),
                  DataCell(Text(row.action.label)),
                  DataCell(
                    AdminIdentityCell(
                      email: row.targetEmail,
                      userId: row.targetUserId,
                      emptyLabel: 'Deleted administrator',
                    ),
                  ),
                  DataCell(
                    row.targetEntitlementId == null
                        ? const Text('Not applicable')
                        : AdminIdCell(row.targetEntitlementId!),
                  ),
                  DataCell(Text(row.source.label)),
                  DataCell(
                    AdminTableActions(
                      children: [
                        TextButton(
                          key: Key('admin-audit-view-${row.id}'),
                          onPressed: () =>
                              context.go(AdminRoutes.auditDetail(row.id)),
                          child: const Text('View details'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: AdminSpacing.sm),
        AdminPaginationBar(
          keyPrefix: 'admin-audit',
          state: state,
          onPrevious: controller.previousPage,
          onNext: controller.nextPage,
        ),
      ],
    ),
  );
}
