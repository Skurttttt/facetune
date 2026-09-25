import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/admin_routes.dart';
import '../../../research/domain/admin_research_models.dart';
import '../../../research/presentation/admin_pilot_metrics_controller.dart';
import '../../../shared/admin_keyset_list_controller.dart';
import '../../../shared/admin_labels.dart';
import '../../../shared/admin_page_header.dart';
import '../../../theme/admin_tokens.dart';
import '../../domain/admin_dashboard_metrics.dart';
import '../../domain/admin_dashboard_v2_metrics.dart';
import '../admin_dashboard_controller.dart';
import '../admin_dashboard_v2_controller.dart';
import '../widgets/admin_dashboard_charts.dart';

/// The read-only operational Dashboard V2.
///
/// V1 remains the required baseline. The WA-DASH-1 charts and the bounded
/// first Salon Pilot page fail independently, so an optional read outage never
/// turns authoritative V1 counts into zero or blanks the whole dashboard.
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminDashboardControllerProvider);
    final v2State = ref.watch(adminDashboardV2ControllerProvider);
    final pilotState = ref.watch(adminPilotMetricsControllerProvider);
    final refreshing = _isRefreshing(state, v2State, pilotState);
    final theme = Theme.of(context);

    return Column(
      key: const Key('admin-section-dashboard'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminPageHeader(
          title: 'Dashboard',
          subtitle: 'Authoritative subscription and delivery operations.',
          actions: [
            if (state is AdminDashboardReady)
              Text(
                'Last updated ${_clock(state.metrics.asOf)} UTC',
                key: const Key('admin-dashboard-as-of'),
                style: theme.textTheme.bodySmall,
              ),
            OutlinedButton.icon(
              key: const Key('admin-dashboard-refresh'),
              onPressed: refreshing ? null : () => _refreshAll(ref),
              icon: const Icon(Icons.refresh, size: AdminIconSizes.md),
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
              onRetry: () => _refreshAll(ref),
            ),
          AdminDashboardReady(:final metrics, :final refreshing) =>
            metrics.isEmpty
                ? const _Empty()
                : Opacity(
                    opacity: refreshing ? 0.65 : 1,
                    child: _DashboardBody(
                      metrics: metrics,
                      v2State: v2State,
                      pilotState: pilotState,
                    ),
                  ),
        },
      ],
    );
  }

  static bool _isRefreshing(
    AdminDashboardState v1,
    AdminDashboardV2State v2,
    AdminPilotMetricsState pilots,
  ) =>
      v1 is AdminDashboardLoading ||
      v1 is AdminDashboardReady && v1.refreshing ||
      v2 is AdminDashboardV2Loading ||
      v2 is AdminDashboardV2Ready && v2.refreshing ||
      pilots is AdminListLoading<AdminPilotMetricsRow, void> ||
      pilots is AdminListReady<AdminPilotMetricsRow, void> && pilots.refreshing;

  static Future<void> _refreshAll(WidgetRef ref) async {
    await Future.wait([
      ref.read(adminDashboardControllerProvider.notifier).refresh(),
      ref.read(adminDashboardV2ControllerProvider.notifier).refresh(),
      ref.read(adminPilotMetricsControllerProvider.notifier).refresh(),
    ]);
  }

  static String _clock(DateTime utc) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
        '${two(utc.hour)}:${two(utc.minute)}';
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.metrics,
    required this.v2State,
    required this.pilotState,
  });

  final AdminDashboardMetrics metrics;
  final AdminDashboardV2State v2State;
  final AdminPilotMetricsState pilotState;

  AdminDashboardV2Metrics? get v2 => switch (v2State) {
    AdminDashboardV2Ready(:final metrics) => metrics,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final v2Metrics = v2;
    return Column(
      key: const Key('admin-dashboard-metrics'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(title: 'Summary'),
        const SizedBox(height: AdminSpacing.sm),
        _ResponsiveGrid(
          minItemWidth: 260,
          maxColumns: 4,
          children: [
            _SummaryMetric(
              label: 'Total Users',
              value: '${metrics.accounts.totalUsers}',
              icon: Icons.people_outline,
              key: const Key('tile-total-users'),
            ),
            _SummaryMetric(
              label: 'In-Force Entitlements',
              value: '${metrics.inForceEntitlements}',
              detail: 'Across 8 canonical plans',
              icon: Icons.verified_user_outlined,
              key: const Key('tile-in-force-entitlements'),
            ),
            _SummaryMetric(
              label: 'Salon Pilot',
              value: '${metrics.salonPilot.inForce}',
              detail: 'In-force entitlements',
              icon: Icons.science_outlined,
              key: const Key('tile-pilot-in-force'),
            ),
            _SummaryMetric(
              label: 'AI Looks Today',
              value: v2Metrics == null
                  ? 'Unavailable'
                  : '${v2Metrics.committedTodayByUnit.aiLook}',
              detail: v2Metrics == null
                  ? 'V2 metrics could not be loaded'
                  : _todayDetail(v2Metrics.committedTodayByUnit),
              icon: Icons.auto_graph_outlined,
              key: const Key('tile-ai-looks-today'),
            ),
          ],
        ),
        const SizedBox(height: AdminSpacing.xl),
        const _SectionHeading(
          title: 'AI Look Activity',
          subtitle: 'Committed usage reported by the server.',
        ),
        const SizedBox(height: AdminSpacing.sm),
        _V2Region(
          state: v2State,
          unavailableKey: const Key('chart-committed-ai-looks-unavailable'),
          child: v2Metrics == null
              ? null
              : DashboardActivityChart(points: v2Metrics.committedDaily),
        ),
        const SizedBox(height: AdminSpacing.xl),
        _ResponsiveGrid(
          minItemWidth: 430,
          maxColumns: 2,
          children: [
            _V2Region(
              state: v2State,
              unavailableKey: const Key(
                'chart-final-previews-by-plan-unavailable',
              ),
              child: v2Metrics == null
                  ? null
                  : DashboardPlanChart(
                      deliveries: v2Metrics.finalPreviewsByPlan30d,
                      unattributed: v2Metrics.finalPreviewsUnattributed30d,
                    ),
            ),
            DashboardUsageOutcomesChart(
              committed: metrics.committedOperationsThisMonth,
              released: metrics.aiLooks.releasedThisMonth,
            ),
          ],
        ),
        const SizedBox(height: AdminSpacing.xl),
        const _SectionHeading(title: 'Entitlement Status'),
        const SizedBox(height: AdminSpacing.sm),
        _V2Region(
          state: v2State,
          unavailableKey: const Key('chart-entitlement-status-unavailable'),
          child: v2Metrics == null
              ? null
              : DashboardEntitlementStatusChart(
                  distribution: v2Metrics.entitlementStatusDistribution,
                ),
        ),
        const SizedBox(height: AdminSpacing.xl),
        _SectionHeading(
          title: 'Salon Pilot',
          subtitle: 'Operational status and bounded usage detail.',
          trailing: TextButton(
            key: const Key('admin-dashboard-research-link'),
            onPressed: () => context.go(AdminRoutes.salonPilotResearch),
            child: const Text('Research metrics'),
          ),
        ),
        const SizedBox(height: AdminSpacing.sm),
        _ResponsiveGrid(
          minItemWidth: 240,
          maxColumns: 2,
          children: [
            _SummaryMetric(
              label: 'Active Pilots',
              value: '${metrics.salonPilot.inForce}',
              icon: Icons.check_circle_outline,
              key: const Key('tile-active-pilots'),
            ),
            _SummaryMetric(
              label: 'Expiring Soon',
              value: '${metrics.salonPilot.expiringSoon}',
              detail: 'Within ${metrics.expiringSoonWindowDays} days',
              icon: Icons.schedule_outlined,
              emphasized: metrics.salonPilot.expiringSoon > 0,
              key: const Key('tile-pilot-expiring'),
            ),
          ],
        ),
        const SizedBox(height: AdminSpacing.lg),
        _PilotUsage(state: pilotState),
      ],
    );
  }

  static String _todayDetail(CommittedByUnit units) {
    final metadata = <String>[];
    if (units.finalPreviewCredit > 0) {
      metadata.add('${units.finalPreviewCredit} Preview credits separate');
    }
    if (units.unattributed > 0) {
      metadata.add('${units.unattributed} legacy / unattributed');
    }
    return metadata.isEmpty
        ? 'AI Look allowance unit only'
        : metadata.join(' · ');
  }
}

class _V2Region extends StatelessWidget {
  const _V2Region({
    required this.state,
    required this.unavailableKey,
    required this.child,
  });

  final AdminDashboardV2State state;
  final Key unavailableKey;
  final Widget? child;

  @override
  Widget build(BuildContext context) => switch (state) {
    AdminDashboardV2Loading() => const _ChartPlaceholder(),
    AdminDashboardV2Unavailable() => _ChartUnavailable(key: unavailableKey),
    AdminDashboardV2Ready() => child!,
  };
}

class _PilotUsage extends StatelessWidget {
  const _PilotUsage({required this.state});

  final AdminPilotMetricsState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(title: 'Pilot Usage'),
        const SizedBox(height: AdminSpacing.sm),
        switch (state) {
          AdminListLoading<AdminPilotMetricsRow, void>() =>
            const _ChartPlaceholder(key: Key('admin-pilot-usage-loading')),
          AdminListUnavailable<AdminPilotMetricsRow, void>() ||
          AdminListRejected<
            AdminPilotMetricsRow,
            void
          >() => const _ChartUnavailable(
            key: Key('admin-pilot-usage-unavailable'),
            message:
                'Pilot usage detail is unavailable. Summary counts remain current.',
          ),
          AdminListReady<AdminPilotMetricsRow, void>(:final page) =>
            page.items.isEmpty
                ? const _ChartUnavailable(
                    key: Key('admin-pilot-usage-empty'),
                    message: 'No Salon Pilot grants to show.',
                    isError: false,
                  )
                : _PilotRows(page: page),
        },
      ],
    );
  }
}

class _PilotRows extends StatelessWidget {
  const _PilotRows({required this.page});

  final AdminListPage<AdminPilotMetricsRow> page;

  @override
  Widget build(BuildContext context) {
    final rows = page.items.take(5).toList(growable: false);
    final moreAvailable =
        page.items.length > rows.length || page.nextCursor != null;
    return DecoratedBox(
      key: const Key('admin-pilot-usage-rows'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AdminRadii.card),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _PilotProgressRow(row: rows[index]),
            if (index != rows.length - 1)
              const Divider(height: 1, color: AdminColors.border),
          ],
          if (moreAvailable)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AdminSpacing.md,
                AdminSpacing.xs,
                AdminSpacing.md,
                AdminSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    'Showing 5 pilots from the first bounded page.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go(AdminRoutes.salonPilotResearch),
                    child: const Text('View all'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PilotProgressRow extends StatelessWidget {
  const _PilotProgressRow({required this.row});

  final AdminPilotMetricsRow row;

  @override
  Widget build(BuildContext context) {
    final fraction = row.effectiveAllowance == 0
        ? 0.0
        : (row.committed / row.effectiveAllowance).clamp(0.0, 1.0);
    final identity = row.email ?? shortId(row.userId);
    final expiry = row.expiresAt == null
        ? 'No expiration'
        : 'Expires ${formatUtcDate(row.expiresAt!)}';
    return Semantics(
      label:
          '$identity, ${entitlementStatusLabel(row.effectiveStatus)}, '
          '${row.committed} of ${row.effectiveAllowance} committed, '
          '${row.remaining} remaining, $expiry',
      child: ExcludeSemantics(
        child: Padding(
          key: Key('pilot-progress-${row.entitlementId}'),
          padding: const EdgeInsets.all(AdminSpacing.md),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final identityBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(identity, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: AdminSpacing.xxs),
                  Text(
                    '${entitlementStatusLabel(row.effectiveStatus)} · $expiry',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
              final progress = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${row.committed} / ${row.effectiveAllowance} committed',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const Spacer(),
                      Text(
                        '${row.remaining} remaining',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: AdminSpacing.xs),
                  LinearProgressIndicator(
                    value: fraction,
                    minHeight: 7,
                    color: AdminColors.accent,
                    backgroundColor: AdminColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(AdminRadii.control),
                  ),
                  if (row.reserved > 0) ...[
                    const SizedBox(height: AdminSpacing.xxs),
                    Text(
                      '${row.reserved} currently reserved',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    identityBlock,
                    const SizedBox(height: AdminSpacing.sm),
                    progress,
                  ],
                );
              }
              return Row(
                children: [
                  SizedBox(width: 250, child: identityBlock),
                  const SizedBox(width: AdminSpacing.lg),
                  Expanded(child: progress),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({
    required this.minItemWidth,
    required this.maxColumns,
    required this.children,
  });

  final double minItemWidth;
  final int maxColumns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final possible =
            ((constraints.maxWidth + AdminSpacing.md) /
                    (minItemWidth + AdminSpacing.md))
                .floor();
        final columns = possible.clamp(1, maxColumns);
        final width =
            (constraints.maxWidth - AdminSpacing.md * (columns - 1)) / columns;
        return Wrap(
          spacing: AdminSpacing.md,
          runSpacing: AdminSpacing.md,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? detail;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $value${detail == null ? '' : ', $detail'}',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(
              color: emphasized
                  ? theme.colorScheme.tertiary
                  : theme.colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(AdminRadii.card),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AdminSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: AdminIconSizes.md),
                    const SizedBox(width: AdminSpacing.xs),
                    Expanded(
                      child: Text(label, style: theme.textTheme.labelMedium),
                    ),
                  ],
                ),
                const SizedBox(height: AdminSpacing.xs),
                Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: AdminSpacing.xxs),
                  Text(detail!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({this.title, this.subtitle, this.trailing});

  final String? title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Semantics(
                  header: true,
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              if (subtitle != null) ...[
                const SizedBox(height: AdminSpacing.xxs),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
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
          Text('Loading dashboard…'),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const _MessagePanel(
      key: Key('admin-dashboard-empty'),
      icon: Icons.inbox_outlined,
      message:
          'No accounts exist yet. Metrics will appear after the first user signs up.',
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
    return _MessagePanel(
      key: const Key('admin-dashboard-unavailable'),
      icon: Icons.error_outline,
      error: true,
      message:
          'The dashboard is unavailable. '
          '${retryable ? 'Try again in a moment.' : 'Sign in again to continue.'} '
          '($code)',
      action: retryable
          ? TextButton(
              key: const Key('admin-dashboard-retry'),
              onPressed: onRetry,
              child: const Text('Try again'),
            )
          : null,
    );
  }
}

class _ChartPlaceholder extends StatelessWidget {
  const _ChartPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MessagePanel(
      icon: Icons.query_stats_outlined,
      message: 'Loading authoritative metrics…',
    );
  }
}

class _ChartUnavailable extends StatelessWidget {
  const _ChartUnavailable({
    super.key,
    this.message =
        'Authoritative metrics are unavailable. No values were fabricated.',
    this.isError = true,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return _MessagePanel(
      icon: isError ? Icons.error_outline : Icons.inbox_outlined,
      error: isError,
      message: message,
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    super.key,
    required this.icon,
    required this.message,
    this.error = false,
    this.action,
  });

  final IconData icon;
  final String message;
  final bool error;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = error
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(
          color: error
              ? theme.colorScheme.error
              : theme.colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(AdminRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: AdminSpacing.sm),
            Expanded(
              child: Semantics(liveRegion: error, child: Text(message)),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
