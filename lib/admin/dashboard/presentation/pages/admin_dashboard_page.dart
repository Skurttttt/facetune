import '../../../shared/admin_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/subscription/domain/catalog/subscription_plan_catalog.dart';
import '../../../../features/subscription/domain/entities/subscription_plan_code.dart';
import '../../../theme/admin_tokens.dart';
import '../../../app/admin_routes.dart';
import '../../domain/admin_dashboard_metrics.dart';
import '../admin_dashboard_controller.dart';

/// The read-only operational dashboard (WA-4).
///
/// Renders the server's counts and only the server's counts: no percentages,
/// no trends, no derived totals. Four states — loading, ready (optionally
/// refreshing over the previous figures), empty, unavailable — each drawn
/// deliberately. Reached only inside the authorized shell.
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminDashboardControllerProvider);
    final controller = ref.read(adminDashboardControllerProvider.notifier);
    final theme = Theme.of(context);

    return Column(
      key: const Key('admin-section-dashboard'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminPageHeader(
          title: 'Dashboard',
          subtitle: 'Live counts from the server. Nothing here is estimated.',
          actions: [
            if (state is AdminDashboardReady)
              Text(
                'As of ${_clock(state.metrics.asOf)} UTC',
                key: const Key('admin-dashboard-as-of'),
                style: theme.textTheme.bodySmall,
              ),
            OutlinedButton.icon(
              key: const Key('admin-dashboard-refresh'),
              onPressed: switch (state) {
                AdminDashboardReady(refreshing: true) => null,
                AdminDashboardLoading() => null,
                _ => controller.refresh,
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: AdminSpacing.lg),
        switch (state) {
          AdminDashboardLoading() => const _Loading(),
          AdminDashboardUnavailable(:final code, :final retryable) =>
            _Unavailable(
              code: code.code,
              retryable: retryable,
              onRetry: controller.load,
            ),
          AdminDashboardReady(:final metrics, :final refreshing) =>
            metrics.isEmpty
                ? const _Empty()
                : _Metrics(metrics: metrics, refreshing: refreshing),
        },
      ],
    );
  }

  static String _clock(DateTime utc) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
        '${two(utc.hour)}:${two(utc.minute)}';
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: Key('admin-dashboard-loading'),
      padding: EdgeInsets.symmetric(vertical: AdminSpacing.xl),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: 'Loading dashboard',
            ),
          ),
          SizedBox(width: AdminSpacing.sm),
          Text('Loading counts…'),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Panel(
      key: const Key('admin-dashboard-empty'),
      child: Row(
        children: [
          Icon(Icons.inbox_outlined, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AdminSpacing.sm),
          const Expanded(
            child: Text(
              'No accounts exist yet. Counts will appear as soon as the first '
              'user signs up.',
            ),
          ),
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({
    required this.code,
    required this.retryable,
    required this.onRetry,
  });

  final String code;
  final bool retryable;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Panel(
      key: const Key('admin-dashboard-unavailable'),
      borderColor: theme.colorScheme.error,
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: AdminSpacing.sm),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                'The dashboard is unavailable. '
                '${retryable ? 'Try again in a moment.' : 'Sign in again to continue.'} '
                '($code)',
              ),
            ),
          ),
          if (retryable)
            TextButton(
              key: const Key('admin-dashboard-retry'),
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
        ],
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.metrics, required this.refreshing});

  final AdminDashboardMetrics metrics;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = metrics.accounts;
    final e = metrics.entitlements;
    final l = metrics.aiLooks;
    final p = metrics.salonPilot;

    return Opacity(
      opacity: refreshing ? 0.6 : 1,
      child: Column(
        key: const Key('admin-dashboard-metrics'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Group(
            title: 'Accounts',
            tiles: [
              _Tile('Users', a.totalUsers, key: const Key('tile-total-users')),
              _Tile(
                'Anonymous guests',
                a.anonymousGuests,
                key: const Key('tile-guests'),
              ),
            ],
          ),
          _Group(
            title: 'AI Looks',
            caption:
                'Committed = a persisted Final Makeup Preview. Purchased '
                'credits are counted apart from included allowance.',
            tiles: [
              _Tile(
                'Committed today',
                l.committedToday.subscription,
                detail: _credits(l.committedToday.purchasedCredit),
                key: const Key('tile-committed-today'),
              ),
              _Tile(
                'Committed this month',
                l.committedThisMonth.subscription,
                detail: _credits(l.committedThisMonth.purchasedCredit),
                key: const Key('tile-committed-month'),
              ),
              _Tile(
                'Open reservations',
                l.reservedOpen,
                key: const Key('tile-reserved'),
              ),
              _Tile(
                'Released today',
                l.releasedToday,
                key: const Key('tile-released-today'),
              ),
              _Tile(
                'Released this month',
                l.releasedThisMonth,
                key: const Key('tile-released-month'),
              ),
            ],
          ),
          _Group(
            title: 'Salon Pilot',
            trailing: TextButton(
              key: const Key('admin-dashboard-research-link'),
              onPressed: () => context.go(AdminRoutes.salonPilotResearch),
              child: const Text('Research metrics'),
            ),
            tiles: [
              _Tile(
                'In force',
                p.inForce,
                key: const Key('tile-pilot-in-force'),
              ),
              _Tile(
                'Expiring within ${metrics.expiringSoonWindowDays} days',
                p.expiringSoon,
                key: const Key('tile-pilot-expiring'),
                emphasis: p.expiringSoon > 0,
              ),
            ],
          ),
          _Group(
            title: 'Entitlements',
            tiles: [
              _Tile('Pending', e.pending, key: const Key('tile-pending')),
              _Tile('Suspended', e.suspended, key: const Key('tile-suspended')),
              _Tile(
                'Active purchased-credit grants',
                metrics.purchasedCredits.activeGrants,
                key: const Key('tile-credit-grants'),
              ),
            ],
          ),
          const SizedBox(height: AdminSpacing.md),
          Semantics(
            header: true,
            child: Text('In force by plan', style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: AdminSpacing.xs),
          _PlanTable(inForceByPlan: e.inForceByPlan),
        ],
      ),
    );
  }

  static String? _credits(int count) =>
      count == 0 ? null : '+$count from purchased credits';
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.tiles,
    this.caption,
    this.trailing,
  });

  final String title;
  final String? caption;
  final List<Widget> tiles;

  /// An optional link beside the heading, to a page that goes deeper.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AdminSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AdminSpacing.sm),
                trailing!,
              ],
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: AdminSpacing.xxs),
            Text(caption!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: AdminSpacing.sm),
          Wrap(
            spacing: AdminSpacing.sm,
            runSpacing: AdminSpacing.sm,
            children: tiles,
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(
    this.label,
    this.value, {
    super.key,
    this.detail,
    this.emphasis = false,
  });

  final String label;
  final int value;
  final String? detail;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $value${detail == null ? '' : ', $detail'}',
      child: ExcludeSemantics(
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(AdminSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(
              color: emphasis
                  ? theme.colorScheme.tertiary
                  : theme.colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(AdminRadii.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: AdminSpacing.xxs),
              Text(
                '$value',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (detail != null)
                Text(detail!, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanTable extends StatelessWidget {
  const _PlanTable({required this.inForceByPlan});

  final Map<SubscriptionPlanCode, int> inForceByPlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Panel(
      key: const Key('admin-dashboard-plan-table'),
      padding: EdgeInsets.zero,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(),
          1: IntrinsicColumnWidth(),
          2: IntrinsicColumnWidth(),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            children: [
              _cell(context, 'Plan', header: true),
              _cell(context, 'Code', header: true),
              _cell(context, 'In force', header: true, numeric: true),
            ],
          ),
          for (final plan in SubscriptionPlanCode.values)
            TableRow(
              children: [
                _cell(
                  context,
                  SubscriptionPlanCatalog.definitionFor(plan).displayName,
                  key: Key('plan-row-${plan.code}'),
                ),
                _cell(context, plan.code, mono: true),
                _cell(
                  context,
                  '${inForceByPlan[plan] ?? 0}',
                  numeric: true,
                  key: Key('plan-count-${plan.code}'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    String text, {
    bool header = false,
    bool numeric = false,
    bool mono = false,
    Key? key,
  }) {
    final theme = Theme.of(context);
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.md,
        vertical: AdminSpacing.xs,
      ),
      child: Text(
        text,
        textAlign: numeric ? TextAlign.right : TextAlign.left,
        style: header
            ? theme.textTheme.labelMedium
            : mono
            ? theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')
            : theme.textTheme.bodyMedium?.copyWith(
                fontFeatures: numeric
                    ? const [FontFeature.tabularFigures()]
                    : null,
              ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    super.key,
    required this.child,
    this.borderColor,
    this.padding = const EdgeInsets.all(AdminSpacing.md),
  });

  final Widget child;
  final Color? borderColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor ?? theme.colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(AdminRadii.card),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
