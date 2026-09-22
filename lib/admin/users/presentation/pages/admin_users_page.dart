import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/subscription/domain/entities/entitlement_status.dart';
import '../../../../theme/app_tokens.dart';
import '../../../app/admin_routes.dart';
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
    final theme = Theme.of(context);

    return Column(
      key: const Key('admin-section-users'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text('Users', style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Find an account by exact email address or User ID.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
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
              const SizedBox(width: AppSpacing.sm),
              FilledButton.icon(
                key: const Key('admin-user-search-submit'),
                onPressed: state is AdminUsersLoading ? null : _submit,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Search'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
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
    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
    child: Row(
      children: [
        SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            semanticsLabel: 'Loading users',
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Text('Loading accountsâ€¦'),
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
          Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('User ID')),
                  DataColumn(label: Text('Current plan')),
                  DataColumn(label: Text('Entitlement')),
                  DataColumn(label: Text('Remaining')),
                  DataColumn(label: Text('Renewal / expiration')),
                  DataColumn(label: Text('Account')),
                  DataColumn(label: Text('')),
                ],
                rows: [
                  for (final user in state.page.items)
                    DataRow(
                      key: ValueKey('admin-user-${user.userId}'),
                      cells: [
                        DataCell(Text(user.email ?? 'No email')),
                        DataCell(
                          Tooltip(
                            message: user.userId,
                            child: Text(
                              _shortId(user.userId),
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                          ),
                        ),
                        DataCell(Text(user.currentPlanDisplayName ?? 'None')),
                        DataCell(
                          Text(
                            _statusLabel(user.entitlementStatus),
                            key: Key('user-status-${user.userId}'),
                          ),
                        ),
                        DataCell(Text(_remaining(user))),
                        DataCell(Text(_renewal(user))),
                        DataCell(Text(user.accountStatus.label)),
                        DataCell(
                          TextButton(
                            key: Key('view-user-${user.userId}'),
                            onPressed: () =>
                                context.go(AdminRoutes.userDetail(user.userId)),
                            child: const Text('View'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                'Page ${state.pageNumber} Â· ${state.page.items.length} of up to ${state.page.pageSize}',
                key: const Key('admin-users-page-label'),
              ),
              const Spacer(),
              OutlinedButton(
                key: const Key('admin-users-previous'),
                onPressed: state.canGoBack ? controller.previousPage : null,
                child: const Text('Previous'),
              ),
              const SizedBox(width: AppSpacing.xs),
              OutlinedButton(
                key: const Key('admin-users-next'),
                onPressed: state.page.nextCursor == null
                    ? null
                    : controller.nextPage,
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _remaining(AdminUserSummary user) {
    final count = user.remainingAiLooks;
    final unit = user.allowanceUnit;
    if (count == null || unit == null) return 'â€”';
    return '$count ${unit.label(count)}';
  }

  static String _renewal(AdminUserSummary user) {
    if (user.expiresAt != null) return 'Expires ${formatDate(user.expiresAt!)}';
    if (user.periodEnd == null) return 'â€”';
    return '${user.autoRenew == true ? 'Renews' : 'Ends'} ${formatDate(user.periodEnd!)}';
  }
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
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
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

String _shortId(String value) => value.length <= 14
    ? value
    : '${value.substring(0, 8)}â€¦${value.substring(value.length - 4)}';

String _statusLabel(EntitlementStatus? status) => switch (status) {
  EntitlementStatus.pending => 'Pending',
  EntitlementStatus.active => 'Active',
  EntitlementStatus.gracePeriod => 'Grace Period',
  EntitlementStatus.expired => 'Expired',
  EntitlementStatus.suspended => 'Suspended',
  EntitlementStatus.revoked => 'Revoked',
  null => 'None',
};
