import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/subscription/domain/entities/entitlement_status.dart';
import '../../../app/admin_routes.dart';
import '../../../shared/admin_labels.dart';
import '../../../shared/admin_list_widgets.dart';
import '../../../shared/admin_page_header.dart';
import '../../../theme/admin_tokens.dart';
import '../../domain/admin_account_status.dart';
import '../../domain/admin_user_models.dart';
import '../admin_users_controller.dart';

/// Exact account lookup plus a fixed-size, server-paginated account list.
class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _submit() =>
      ref.read(adminUsersControllerProvider.notifier).search(_search.text);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminUsersControllerProvider);
    final controller = ref.read(adminUsersControllerProvider.notifier);

    return Column(
      key: const Key('admin-section-users'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const AdminPageHeader(
          title: 'Users',
          subtitle: 'Find an account by exact email address or User ID.',
        ),
        const SizedBox(height: AdminSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('admin-user-search'),
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Email or User ID',
                    helperText: 'Exact matches only. Leave blank to browse.',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: AdminSpacing.sm),
              FilledButton.icon(
                key: const Key('admin-user-search-submit'),
                onPressed: state is AdminUsersLoading ? null : _submit,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Search'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AdminSpacing.lg),
        switch (state) {
          AdminUsersLoading() => const _Loading(),
          AdminUsersUnavailable(:final retryable) => _Unavailable(
            retryable: retryable,
            onRetry: controller.load,
          ),
          AdminUsersReady(:final page) when page.items.isEmpty =>
            const _NoResults(),
          AdminUsersReady() => _Results(state: state, controller: controller),
        },
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    key: Key('admin-users-loading'),
    padding: EdgeInsets.symmetric(vertical: AdminSpacing.lg),
    child: Row(
      children: [
        SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            semanticsLabel: 'Loading users',
          ),
        ),
        SizedBox(width: AdminSpacing.sm),
        Text('Loading accounts…'),
      ],
    ),
  );
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) => const _Notice(
    key: Key('admin-users-empty'),
    icon: Icons.person_search_outlined,
    message: 'No users matched your search.',
  );
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.retryable, required this.onRetry});

  final bool retryable;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => _Notice(
    key: const Key('admin-users-unavailable'),
    icon: Icons.error_outline,
    message: 'Accounts could not be loaded. Try again in a moment.',
    action: retryable
        ? TextButton(onPressed: onRetry, child: const Text('Try again'))
        : null,
  );
}

class _Results extends StatelessWidget {
  const _Results({required this.state, required this.controller});

  final AdminUsersReady state;
  final AdminUsersController controller;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: state.refreshing ? 0.6 : 1,
      child: Column(
        key: const Key('admin-users-results'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminTable(
            key: const Key('admin-users-table'),
            columns: const [
              DataColumn(label: Text('User')),
              DataColumn(label: Text('Current plan')),
              DataColumn(label: Text('Entitlement')),
              DataColumn(label: Text('Remaining')),
              DataColumn(label: Text('Renewal / expiration')),
              DataColumn(label: Text('Account')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final user in state.page.items)
                DataRow(
                  key: ValueKey('admin-user-${user.userId}'),
                  cells: [
                    DataCell(
                      AdminIdentityCell(email: user.email, userId: user.userId),
                    ),
                    DataCell(Text(user.currentPlanDisplayName ?? 'None')),
                    DataCell(
                      AdminStatusBadge(
                        key: Key('user-status-${user.userId}'),
                        label: user.entitlementStatus == null
                            ? 'None'
                            : entitlementStatusLabel(user.entitlementStatus!),
                        semanticsPrefix: 'Entitlement status',
                        emphasis: _entitlementEmphasis(user.entitlementStatus),
                      ),
                    ),
                    DataCell(Text(_remaining(user))),
                    DataCell(Text(_renewal(user))),
                    DataCell(
                      AdminStatusBadge(
                        label: user.accountStatus.label,
                        semanticsPrefix: 'Account status',
                        emphasis: _accountEmphasis(user.accountStatus),
                      ),
                    ),
                    DataCell(
                      AdminTableActions(
                        children: [
                          TextButton(
                            key: Key('view-user-${user.userId}'),
                            onPressed: () =>
                                context.go(AdminRoutes.userDetail(user.userId)),
                            child: const Text('View'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AdminSpacing.sm),
          AdminPaginationControl(
            keyPrefix: 'admin-users',
            pageNumber: state.pageNumber,
            itemCount: state.page.items.length,
            pageSize: state.page.pageSize,
            canGoBack: state.canGoBack,
            canGoNext: state.page.nextCursor != null,
            onPrevious: controller.previousPage,
            onNext: controller.nextPage,
          ),
        ],
      ),
    );
  }

  static String _remaining(AdminUserSummary user) {
    final count = user.remainingAiLooks;
    final unit = user.allowanceUnit;
    if (count == null || unit == null) return '—';
    return '$count ${unit.label(count)}';
  }

  static String _renewal(AdminUserSummary user) {
    if (user.expiresAt != null) return 'Expires ${formatDate(user.expiresAt!)}';
    if (user.periodEnd == null) return '—';
    return '${user.autoRenew == true ? 'Renews' : 'Ends'} ${formatDate(user.periodEnd!)}';
  }

  static AdminBadgeEmphasis _entitlementEmphasis(EntitlementStatus? status) =>
      switch (status) {
        EntitlementStatus.active => AdminBadgeEmphasis.positive,
        EntitlementStatus.gracePeriod ||
        EntitlementStatus.pending => AdminBadgeEmphasis.caution,
        EntitlementStatus.expired ||
        EntitlementStatus.suspended ||
        EntitlementStatus.revoked => AdminBadgeEmphasis.negative,
        null => AdminBadgeEmphasis.neutral,
      };

  static AdminBadgeEmphasis _accountEmphasis(AdminAccountStatus status) =>
      switch (status) {
        AdminAccountStatus.active => AdminBadgeEmphasis.positive,
        AdminAccountStatus.unconfirmed => AdminBadgeEmphasis.caution,
        AdminAccountStatus.banned => AdminBadgeEmphasis.negative,
        AdminAccountStatus.anonymous => AdminBadgeEmphasis.information,
      };
}

class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
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
            Icon(icon, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AdminSpacing.sm),
            Expanded(child: Text(message)),
            ?action,
          ],
        ),
      ),
    );
  }
}

String formatDate(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  final utc = value.toUtc();
  return '${utc.year}-${two(utc.month)}-${two(utc.day)} UTC';
}
