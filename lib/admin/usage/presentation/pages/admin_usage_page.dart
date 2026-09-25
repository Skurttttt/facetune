import '../../../shared/admin_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/subscription/domain/entities/purchased_credit_summary.dart'
    show AllowanceSource;
import '../../../../features/subscription/domain/entities/subscription_plan_code.dart';
import '../../../../features/subscription/domain/entities/usage_status.dart';
import '../../../shared/admin_form_widgets.dart';
import '../../../theme/admin_tokens.dart';
import '../../../app/admin_routes.dart';
import '../../../shared/admin_keyset_list_controller.dart';
import '../../../shared/admin_labels.dart';
import '../../../shared/admin_list_widgets.dart';
import '../../../shared/admin_wire.dart';
import '../../domain/admin_usage_models.dart';
import '../admin_usage_controller.dart';

/// The AI Look ledger: reserved, committed, released. Filtered and paginated
/// on the server; every row is shown in its canonical state. Read-only.
class AdminUsagePage extends ConsumerStatefulWidget {
  const AdminUsagePage({
    super.key,
    this.initialFilters = AdminUsageFilters.none,
  });

  /// Filters carried in from a deep link (`?userId=`, `?entitlementId=`).
  final AdminUsageFilters initialFilters;

  @override
  ConsumerState<AdminUsagePage> createState() => _AdminUsagePageState();
}

class _AdminUsagePageState extends ConsumerState<AdminUsagePage> {
  late final TextEditingController _userId = TextEditingController(
    text: widget.initialFilters.userId ?? '',
  );
  late final TextEditingController _entitlementId = TextEditingController(
    text: widget.initialFilters.entitlementId ?? '',
  );
  late UsageStatus? _status = widget.initialFilters.status;
  late SubscriptionPlanCode? _plan = widget.initialFilters.planCode;
  late AllowanceSource? _source = widget.initialFilters.allowanceSource;
  late AdminUsageDateRange? _range = widget.initialFilters.dateRange;
  String? _userIdError;
  String? _entitlementIdError;
  // Bumped by Clear so the form-field dropdowns rebuild from their initial
  // values; a DropdownButtonFormField reads initialValue only once.
  int _filterGeneration = 0;

  @override
  void dispose() {
    _userId.dispose();
    _entitlementId.dispose();
    super.dispose();
  }

  AdminUsageController get _controller =>
      ref.read(adminUsageControllerProvider(widget.initialFilters).notifier);

  Future<void> _apply() async {
    final userIdBad = isMalformedUuidInput(_userId.text);
    final entitlementIdBad = isMalformedUuidInput(_entitlementId.text);
    setState(() {
      _userIdError = userIdBad ? 'Enter a full User ID.' : null;
      _entitlementIdError = entitlementIdBad
          ? 'Enter a full Entitlement ID.'
          : null;
    });
    if (userIdBad || entitlementIdBad) return;
    await _controller.applyFilters(
      AdminUsageFilters.withRange(
        AdminUsageFilters(
          userId: normalizeUuid(_userId.text),
          entitlementId: normalizeUuid(_entitlementId.text),
          status: _status,
          planCode: _plan,
          allowanceSource: _source,
        ),
        _range,
        now: DateTime.now(),
      ),
    );
  }

  Future<void> _clear() async {
    setState(() {
      _userId.clear();
      _entitlementId.clear();
      _status = null;
      _plan = null;
      _source = null;
      _range = null;
      _userIdError = null;
      _entitlementIdError = null;
      _filterGeneration++;
    });
    await _controller.applyFilters(AdminUsageFilters.none);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      adminUsageControllerProvider(widget.initialFilters),
    );
    final busy = state is AdminListLoading;

    return Column(
      key: const Key('admin-section-usage'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const AdminPageHeader(
          title: 'Usage',
          subtitle:
              'The AI Look ledger. A committed row consumed one unit; a '
              'released row consumed none; a reserved row is holding one.',
        ),
        const SizedBox(height: AdminSpacing.md),
        KeyedSubtree(
          key: ValueKey(_filterGeneration),
          child: AdminFilterPanel(
            key: const Key('admin-usage-filter-panel'),
            fields: [
              AdminLabeledField(
                label: 'User ID',
                child: TextField(
                  key: const Key('admin-usage-filter-user'),
                  controller: _userId,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _apply(),
                  decoration: InputDecoration(
                    helperText: 'Exact UUID.',
                    errorText: _userIdError,
                  ),
                ),
              ),
              AdminLabeledField(
                label: 'Entitlement ID',
                child: TextField(
                  key: const Key('admin-usage-filter-entitlement'),
                  controller: _entitlementId,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _apply(),
                  decoration: InputDecoration(
                    helperText: 'Exact UUID.',
                    errorText: _entitlementIdError,
                  ),
                ),
              ),
              AdminLabeledField(
                label: 'Status',
                child: DropdownButtonFormField<UsageStatus?>(
                  isExpanded: true,
                  key: const Key('admin-usage-filter-status'),
                  initialValue: _status,
                  decoration: const InputDecoration(),
                  items: [
                    const DropdownMenuItem(child: Text('Any status')),
                    for (final status in UsageStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(usageStatusLabel(status)),
                      ),
                  ],
                  onChanged: (value) => setState(() => _status = value),
                ),
              ),
              AdminLabeledField(
                label: 'Plan',
                child: DropdownButtonFormField<SubscriptionPlanCode?>(
                  isExpanded: true,
                  key: const Key('admin-usage-filter-plan'),
                  initialValue: _plan,
                  decoration: const InputDecoration(),
                  items: [
                    const DropdownMenuItem(child: Text('Any plan')),
                    for (final plan in SubscriptionPlanCode.values)
                      DropdownMenuItem(
                        value: plan,
                        child: Text(planCodeLabel(plan)),
                      ),
                  ],
                  onChanged: (value) => setState(() => _plan = value),
                ),
              ),
              AdminLabeledField(
                label: 'Source',
                child: DropdownButtonFormField<AllowanceSource?>(
                  isExpanded: true,
                  key: const Key('admin-usage-filter-source'),
                  initialValue: _source,
                  decoration: const InputDecoration(),
                  items: [
                    const DropdownMenuItem(child: Text('Any source')),
                    for (final source in AllowanceSource.values)
                      DropdownMenuItem(
                        value: source,
                        child: Text(allowanceSourceLabel(source)),
                      ),
                  ],
                  onChanged: (value) => setState(() => _source = value),
                ),
              ),
              AdminLabeledField(
                label: 'Created within',
                child: DropdownButtonFormField<AdminUsageDateRange?>(
                  isExpanded: true,
                  key: const Key('admin-usage-filter-range'),
                  initialValue: _range,
                  decoration: const InputDecoration(),
                  items: [
                    const DropdownMenuItem(child: Text('Any time')),
                    for (final range in AdminUsageDateRange.values)
                      DropdownMenuItem(value: range, child: Text(range.label)),
                  ],
                  onChanged: (value) => setState(() => _range = value),
                ),
              ),
            ],
            actions: [
              FilledButton.icon(
                key: const Key('admin-usage-apply'),
                onPressed: busy ? null : _apply,
                icon: const Icon(Icons.filter_alt_outlined, size: 18),
                label: const Text('Apply filters'),
              ),
              TextButton(
                key: const Key('admin-usage-clear'),
                onPressed: busy ? null : _clear,
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AdminSpacing.lg),
        switch (state) {
          AdminListLoading() => const AdminListLoadingRow(
            key: Key('admin-usage-loading'),
            label: 'Loading usage',
          ),
          AdminListRejected() => const AdminListNotice(
            key: Key('admin-usage-rejected'),
            icon: Icons.error_outline,
            message:
                'The server did not accept these filters. Adjust them and '
                'apply again.',
          ),
          AdminListUnavailable(:final retryable) => AdminListNotice(
            key: const Key('admin-usage-unavailable'),
            icon: Icons.error_outline,
            message: 'Usage could not be loaded. Try again in a moment.',
            action: retryable
                ? TextButton(
                    onPressed: _controller.load,
                    child: const Text('Try again'),
                  )
                : null,
          ),
          AdminListReady(:final page) when page.items.isEmpty =>
            const AdminListNotice(
              key: Key('admin-usage-empty'),
              icon: Icons.receipt_long_outlined,
              message: 'No usage records matched these filters.',
            ),
          AdminListReady() => _Results(state: state, controller: _controller),
        },
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.state, required this.controller});

  final AdminListReady<AdminUsageListItem, AdminUsageFilters> state;
  final AdminUsageController controller;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: state.refreshing ? 0.6 : 1,
      child: Column(
        key: const Key('admin-usage-results'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminTable(
            key: const Key('admin-usage-table'),
            columns: const [
              DataColumn(label: Text('Created')),
              DataColumn(label: Text('User')),
              DataColumn(label: Text('Plan')),
              DataColumn(label: Text('Usage type')),
              DataColumn(label: Text('Operation ID')),
              DataColumn(label: Text('Entitlement ID')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Unit impact')),
              DataColumn(label: Text('Source')),
              DataColumn(label: Text('Committed at')),
              DataColumn(label: Text('Released at')),
              DataColumn(label: Text('Failure code')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final row in state.page.items)
                DataRow(
                  key: ValueKey('admin-usage-${row.usageId}'),
                  cells: [
                    DataCell(Text(formatUtcDateTime(row.createdAt))),
                    DataCell(
                      AdminIdentityCell(email: row.email, userId: row.userId),
                    ),
                    DataCell(
                      Text(
                        row.planCode == null
                            ? 'Not stamped'
                            : planCodeLabel(row.planCode!),
                      ),
                    ),
                    DataCell(Text(_usageType(row))),
                    DataCell(AdminIdCell(row.operationId)),
                    DataCell(AdminIdCell(row.entitlementId)),
                    DataCell(
                      AdminStatusBadge(
                        key: Key('usage-status-${row.usageId}'),
                        label: usageStatusLabel(row.status),
                        semanticsPrefix: 'Usage status',
                        emphasis: switch (row.status) {
                          UsageStatus.committed => AdminBadgeEmphasis.positive,
                          UsageStatus.reserved => AdminBadgeEmphasis.caution,
                          UsageStatus.released => AdminBadgeEmphasis.neutral,
                        },
                      ),
                    ),
                    DataCell(
                      Text(
                        _impact(row),
                        key: Key('usage-impact-${row.usageId}'),
                      ),
                    ),
                    DataCell(Text(_source(row))),
                    DataCell(Text(_timestamp(row.committedAt))),
                    DataCell(Text(_timestamp(row.releasedAt))),
                    DataCell(
                      Text(
                        row.sanitizedFailureCode ?? '—',
                        key: Key('usage-failure-${row.usageId}'),
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    DataCell(
                      AdminTableActions(
                        children: [
                          TextButton(
                            key: Key('view-user-${row.usageId}'),
                            onPressed: () =>
                                context.go(AdminRoutes.userDetail(row.userId)),
                            child: const Text('View user'),
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
            keyPrefix: 'admin-usage',
            state: state,
            onPrevious: controller.previousPage,
            onNext: controller.nextPage,
          ),
        ],
      ),
    );
  }

  static String _usageType(AdminUsageListItem row) {
    final base = switch (row.usageType.code) {
      'final_makeup_preview' => 'Final Makeup Preview',
      final other => other,
    };
    final mode = row.sourceMode;
    return mode == null ? base : '$base · ${mode.label}';
  }

  /// The contract's meaning of each canonical state (Shared Contract §25–§27,
  /// Web Admin SOT §37), written out so a released failure can never be read
  /// as consumption.
  static String _impact(AdminUsageListItem row) {
    final unit = row.allowanceUnit?.singular ?? 'unit';
    return switch (row.status) {
      UsageStatus.committed => '1 $unit consumed',
      UsageStatus.reserved => '1 $unit held',
      UsageStatus.released => '0 consumed',
    };
  }

  static String _source(AdminUsageListItem row) =>
      allowanceSourceLabel(row.allowanceSource);

  static String _timestamp(DateTime? value) =>
      value == null ? '—' : formatUtcDateTime(value);
}
