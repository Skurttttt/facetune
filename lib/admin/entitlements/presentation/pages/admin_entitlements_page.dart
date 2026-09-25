import '../../../shared/admin_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/subscription/domain/entities/billing_provider.dart';
import '../../../../features/subscription/domain/entities/entitlement_status.dart';
import '../../../../features/subscription/domain/entities/subscription_plan_code.dart';
import '../../../shared/admin_form_widgets.dart';
import '../../../theme/admin_tokens.dart';
import '../../../app/admin_routes.dart';
import '../../../shared/admin_keyset_list_controller.dart';
import '../../../shared/admin_labels.dart';
import '../../../shared/admin_list_widgets.dart';
import '../../../shared/admin_wire.dart';
import '../../domain/admin_entitlement_models.dart';
import '../admin_entitlements_controller.dart';

/// Every entitlement row the system holds, filtered and paginated on the
/// server, with the server's own allowance and usage figures. Read-only.
class AdminEntitlementsPage extends ConsumerStatefulWidget {
  const AdminEntitlementsPage({
    super.key,
    this.initialFilters = AdminEntitlementFilters.none,
  });

  /// Filters carried in from a deep link (`?userId=`). Applied to the first
  /// request, never merged with anything remembered.
  final AdminEntitlementFilters initialFilters;

  @override
  ConsumerState<AdminEntitlementsPage> createState() =>
      _AdminEntitlementsPageState();
}

class _AdminEntitlementsPageState extends ConsumerState<AdminEntitlementsPage> {
  late final TextEditingController _userId = TextEditingController(
    text: widget.initialFilters.userId ?? '',
  );
  late SubscriptionPlanCode? _plan = widget.initialFilters.planCode;
  late EntitlementStatus? _status = widget.initialFilters.status;
  late BillingProvider? _provider = widget.initialFilters.billingProvider;
  late AdminExpirationWindow? _expiration = widget.initialFilters.expiration;
  String? _userIdError;
  // Bumped by Clear so the form-field dropdowns rebuild from their initial
  // values; a DropdownButtonFormField reads initialValue only once.
  int _filterGeneration = 0;

  @override
  void dispose() {
    _userId.dispose();
    super.dispose();
  }

  AdminEntitlementsController get _controller => ref.read(
    adminEntitlementsControllerProvider(widget.initialFilters).notifier,
  );

  Future<void> _apply() async {
    if (isMalformedUuidInput(_userId.text)) {
      setState(() => _userIdError = 'Enter a full User ID.');
      return;
    }
    setState(() => _userIdError = null);
    await _controller.applyFilters(
      AdminEntitlementFilters(
        userId: normalizeUuid(_userId.text),
        planCode: _plan,
        status: _status,
        billingProvider: _provider,
        expiration: _expiration,
      ),
    );
  }

  Future<void> _clear() async {
    setState(() {
      _userId.clear();
      _plan = null;
      _status = null;
      _provider = null;
      _expiration = null;
      _userIdError = null;
      _filterGeneration++;
    });
    await _controller.applyFilters(AdminEntitlementFilters.none);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      adminEntitlementsControllerProvider(widget.initialFilters),
    );
    final busy = state is AdminListLoading;

    return Column(
      key: const Key('admin-section-entitlements'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const AdminPageHeader(
          title: 'Entitlements',
          subtitle:
              'Every entitlement on record, with server-resolved allowance '
              'and usage. Filters apply on the server.',
        ),
        const SizedBox(height: AdminSpacing.md),
        KeyedSubtree(
          key: ValueKey(_filterGeneration),
          child: AdminFilterPanel(
            key: const Key('admin-entitlements-filter-panel'),
            fields: [
              AdminLabeledField(
                label: 'User ID',
                child: TextField(
                  key: const Key('admin-entitlements-filter-user'),
                  controller: _userId,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _apply(),
                  decoration: InputDecoration(
                    helperText: 'Exact UUID. Leave blank for all accounts.',
                    errorText: _userIdError,
                  ),
                ),
              ),
              AdminLabeledField(
                label: 'Plan',
                child: DropdownButtonFormField<SubscriptionPlanCode?>(
                  isExpanded: true,
                  key: const Key('admin-entitlements-filter-plan'),
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
                label: 'Status',
                child: DropdownButtonFormField<EntitlementStatus?>(
                  isExpanded: true,
                  key: const Key('admin-entitlements-filter-status'),
                  initialValue: _status,
                  decoration: const InputDecoration(),
                  items: [
                    const DropdownMenuItem(child: Text('Any status')),
                    for (final status in EntitlementStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(entitlementStatusLabel(status)),
                      ),
                  ],
                  onChanged: (value) => setState(() => _status = value),
                ),
              ),
              AdminLabeledField(
                label: 'Provider',
                child: DropdownButtonFormField<BillingProvider?>(
                  isExpanded: true,
                  key: const Key('admin-entitlements-filter-provider'),
                  initialValue: _provider,
                  decoration: const InputDecoration(),
                  items: [
                    const DropdownMenuItem(child: Text('Any provider')),
                    for (final provider in BillingProvider.values)
                      DropdownMenuItem(
                        value: provider,
                        child: Text(billingProviderLabel(provider)),
                      ),
                  ],
                  onChanged: (value) => setState(() => _provider = value),
                ),
              ),
              AdminLabeledField(
                label: 'Expiration',
                child: DropdownButtonFormField<AdminExpirationWindow?>(
                  isExpanded: true,
                  key: const Key('admin-entitlements-filter-expiration'),
                  initialValue: _expiration,
                  decoration: const InputDecoration(),
                  items: [
                    const DropdownMenuItem(child: Text('Any expiration')),
                    for (final window in AdminExpirationWindow.values)
                      DropdownMenuItem(
                        value: window,
                        child: Text(window.label),
                      ),
                  ],
                  onChanged: (value) => setState(() => _expiration = value),
                ),
              ),
            ],
            actions: [
              FilledButton.icon(
                key: const Key('admin-entitlements-apply'),
                onPressed: busy ? null : _apply,
                icon: const Icon(Icons.filter_alt_outlined, size: 18),
                label: const Text('Apply filters'),
              ),
              TextButton(
                key: const Key('admin-entitlements-clear'),
                onPressed: busy ? null : _clear,
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AdminSpacing.lg),
        switch (state) {
          AdminListLoading() => const AdminListLoadingRow(
            key: Key('admin-entitlements-loading'),
            label: 'Loading entitlements',
          ),
          AdminListRejected() => const AdminListNotice(
            key: Key('admin-entitlements-rejected'),
            icon: Icons.error_outline,
            message:
                'The server did not accept these filters. Adjust them and '
                'apply again.',
          ),
          AdminListUnavailable(:final retryable) => AdminListNotice(
            key: const Key('admin-entitlements-unavailable'),
            icon: Icons.error_outline,
            message: 'Entitlements could not be loaded. Try again in a moment.',
            action: retryable
                ? TextButton(
                    onPressed: _controller.load,
                    child: const Text('Try again'),
                  )
                : null,
          ),
          AdminListReady(:final page) when page.items.isEmpty =>
            const AdminListNotice(
              key: Key('admin-entitlements-empty'),
              icon: Icons.verified_user_outlined,
              message: 'No entitlements matched these filters.',
            ),
          AdminListReady() => _Results(state: state, controller: _controller),
        },
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.state, required this.controller});

  final AdminListReady<AdminEntitlementListItem, AdminEntitlementFilters> state;
  final AdminEntitlementsController controller;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: state.refreshing ? 0.6 : 1,
      child: Column(
        key: const Key('admin-entitlements-results'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminTable(
            key: const Key('admin-entitlements-table'),
            columns: const [
              DataColumn(label: Text('User')),
              DataColumn(label: Text('Plan')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Provider')),
              DataColumn(label: Text('Effective allowance'), numeric: true),
              DataColumn(label: Text('Committed'), numeric: true),
              DataColumn(label: Text('Reserved'), numeric: true),
              DataColumn(label: Text('Remaining'), numeric: true),
              DataColumn(label: Text('Period')),
              DataColumn(label: Text('Expiration')),
              DataColumn(label: Text('Auto renew')),
              DataColumn(label: Text('Created')),
              DataColumn(label: Text('Updated')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final row in state.page.items)
                DataRow(
                  key: ValueKey('admin-entitlement-${row.entitlementId}'),
                  cells: [
                    DataCell(
                      AdminIdentityCell(email: row.email, userId: row.userId),
                    ),
                    DataCell(Text(row.planDisplayName)),
                    DataCell(
                      AdminStatusBadge(
                        key: Key('entitlement-status-${row.entitlementId}'),
                        label: entitlementStatusLabel(row.effectiveStatus),
                        semanticsPrefix: 'Entitlement status',
                        emphasis: _emphasis(row.effectiveStatus),
                      ),
                    ),
                    DataCell(Text(billingProviderLabel(row.billingProvider))),
                    DataCell(
                      Tooltip(
                        message:
                            'Base ${row.baseAllowance}, adjustments '
                            '${_signed(row.allowanceAdjustmentTotal)}',
                        child: Text(
                          '${row.effectiveAllowance} '
                          '${row.allowanceUnit.label(row.effectiveAllowance)}',
                        ),
                      ),
                    ),
                    DataCell(Text('${row.committedUsage}')),
                    DataCell(Text('${row.reservedUsage}')),
                    DataCell(
                      Tooltip(
                        message:
                            'Available for a new generation: '
                            '${row.availableAiLooks}',
                        child: Text('${row.remainingAiLooks}'),
                      ),
                    ),
                    DataCell(Text(_period(row))),
                    DataCell(Text(_expiration(row))),
                    DataCell(Text(row.autoRenew ? 'On' : 'Off')),
                    DataCell(Text(formatUtcDate(row.createdAt))),
                    DataCell(Text(formatUtcDate(row.updatedAt))),
                    DataCell(
                      AdminTableActions(
                        children: [
                          TextButton(
                            key: Key('view-user-${row.entitlementId}'),
                            onPressed: () =>
                                context.go(AdminRoutes.userDetail(row.userId)),
                            child: const Text('View user'),
                          ),
                          TextButton(
                            key: Key('view-usage-${row.entitlementId}'),
                            onPressed: () => context.go(
                              AdminRoutes.usageForEntitlement(
                                row.entitlementId,
                              ),
                            ),
                            child: const Text('View usage'),
                          ),
                          TextButton(
                            key: Key('view-history-${row.entitlementId}'),
                            onPressed: () => context.go(
                              AdminRoutes.entitlementHistory(row.entitlementId),
                            ),
                            child: const Text('View history'),
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
            keyPrefix: 'admin-entitlements',
            state: state,
            onPrevious: controller.previousPage,
            onNext: controller.nextPage,
          ),
        ],
      ),
    );
  }

  static String _period(AdminEntitlementListItem row) {
    final start = row.periodStart;
    final end = row.periodEnd;
    if (start == null || end == null) return 'Not applicable';
    return '${formatUtcDate(start)} – ${formatUtcDate(end)}';
  }

  static String _expiration(AdminEntitlementListItem row) =>
      row.expiresAt == null ? 'Not applicable' : formatUtcDate(row.expiresAt!);

  static String _signed(int value) => value >= 0 ? '+$value' : '$value';

  static AdminBadgeEmphasis _emphasis(EntitlementStatus status) =>
      switch (status) {
        EntitlementStatus.active => AdminBadgeEmphasis.positive,
        EntitlementStatus.gracePeriod ||
        EntitlementStatus.pending => AdminBadgeEmphasis.caution,
        EntitlementStatus.expired ||
        EntitlementStatus.suspended ||
        EntitlementStatus.revoked => AdminBadgeEmphasis.negative,
      };
}
