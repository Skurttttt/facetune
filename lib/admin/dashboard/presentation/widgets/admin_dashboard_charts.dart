import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../features/subscription/domain/entities/entitlement_status.dart';
import '../../../../features/subscription/domain/entities/subscription_plan_code.dart';
import '../../../shared/admin_cards.dart';
import '../../../shared/admin_labels.dart';
import '../../../shared/admin_list_widgets.dart';
import '../../../theme/admin_tokens.dart';
import '../../domain/admin_dashboard_v2_metrics.dart';

/// Selects a bounded suffix of the server's complete 30-point series.
List<AdminDashboardDailyPoint> dashboardDailyWindow(
  List<AdminDashboardDailyPoint> points,
  int days,
) {
  if (days <= 0 || days > points.length) {
    throw ArgumentError.value(days, 'days');
  }
  return List.unmodifiable(points.sublist(points.length - days));
}

class DashboardActivityChart extends StatefulWidget {
  const DashboardActivityChart({super.key, required this.points});

  final List<AdminDashboardDailyPoint> points;

  @override
  State<DashboardActivityChart> createState() => _DashboardActivityChartState();
}

class _DashboardActivityChartState extends State<DashboardActivityChart> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    if (widget.points.every((point) => point.aiLook == 0)) {
      return const AdminChartCard(
        key: Key('chart-committed-ai-looks-empty'),
        title: 'Committed AI Looks',
        description: 'Authoritative daily AI Look units · UTC',
        child: _ChartEmptyContent(
          title: 'No committed AI Looks',
          message: 'No AI Look usage was committed in this reporting window.',
        ),
      );
    }
    final theme = Theme.of(context);
    final points = dashboardDailyWindow(widget.points, _days);
    final maxValue = points.fold<int>(
      0,
      (value, point) => math.max(value, point.aiLook),
    );
    final maxY = math.max(1, maxValue).toDouble();
    final description = points
        .map((point) => '${_date(point.day)}: ${point.aiLook}')
        .join(', ');

    return AdminChartCard(
      key: const Key('chart-committed-ai-looks'),
      title: 'Committed AI Looks',
      description: 'Authoritative daily AI Look units · UTC',
      trailing: SegmentedButton<int>(
        key: const Key('dashboard-activity-window'),
        segments: const [
          ButtonSegment(value: 7, label: Text('7D')),
          ButtonSegment(value: 30, label: Text('30D')),
        ],
        selected: {_days},
        showSelectedIcon: false,
        onSelectionChanged: (selection) {
          setState(() => _days = selection.single);
        },
      ),
      child: Semantics(
        label:
            'Committed AI Looks for the last $_days days in UTC. $description',
        child: ExcludeSemantics(
          child: SizedBox(
            height: 280,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (points.length - 1).toDouble(),
                minY: 0,
                maxY: maxY * 1.15,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: _interval(maxY),
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AdminColors.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    left: BorderSide(color: AdminColors.borderStrong),
                    bottom: BorderSide(color: AdminColors.borderStrong),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: _interval(maxY),
                      getTitlesWidget: (value, meta) =>
                          _axisLabel(context, value.toInt().toString()),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (value != index ||
                            index < 0 ||
                            index >= points.length ||
                            (index != 0 &&
                                index != points.length ~/ 2 &&
                                index != points.length - 1)) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: _axisLabel(
                            context,
                            _monthDay(points[index].day),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((spot) {
                      final point = points[spot.x.round()];
                      return LineTooltipItem(
                        '${_date(point.day)} UTC\n${point.aiLook} AI Looks',
                        theme.textTheme.bodySmall!.copyWith(
                          color: AdminColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var index = 0; index < points.length; index++)
                        FlSpot(
                          index.toDouble(),
                          points[index].aiLook.toDouble(),
                        ),
                    ],
                    color: AdminColors.accent,
                    barWidth: 2.5,
                    isCurved: false,
                    dotData: FlDotData(show: _days == 7),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AdminColors.accentSubtle,
                    ),
                  ),
                ],
              ),
              duration: Duration.zero,
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardPlanChart extends StatelessWidget {
  const DashboardPlanChart({
    super.key,
    required this.deliveries,
    required this.unattributed,
  });

  final Map<SubscriptionPlanCode, int> deliveries;
  final int unattributed;

  @override
  Widget build(BuildContext context) {
    if (deliveries.values.every((value) => value == 0) && unattributed == 0) {
      return const AdminChartCard(
        key: Key('chart-final-previews-by-plan-empty'),
        title: 'Final Previews Delivered by Plan',
        description: 'Last 30 days · UTC',
        child: _ChartEmptyContent(
          title: 'No final previews delivered',
          message: 'No final-preview deliveries were reported in this window.',
        ),
      );
    }
    final plans = SubscriptionPlanCode.values;
    final maxValue = plans.fold<int>(
      0,
      (value, plan) => math.max(value, deliveries[plan]!),
    );
    final semantics = plans
        .map((plan) => '${planCodeLabel(plan)}: ${deliveries[plan]}')
        .join(', ');

    return AdminChartCard(
      key: const Key('chart-final-previews-by-plan'),
      title: 'Final Previews Delivered by Plan',
      description: 'Last 30 days · UTC',
      footer: unattributed > 0
          ? Text(
              'Legacy / Unattributed: $unattributed',
              key: const Key('dashboard-plan-unattributed'),
              style: Theme.of(context).textTheme.bodySmall,
            )
          : null,
      child: Semantics(
        label: 'Final Previews Delivered by Plan over 30 days. $semantics',
        child: ExcludeSemantics(
          child: Column(
            children: [
              SizedBox(
                height: 210,
                child: BarChart(
                  BarChartData(
                    minY: 0,
                    maxY: math.max(1, maxValue).toDouble() * 1.15,
                    alignment: BarChartAlignment.spaceAround,
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: _interval(
                        math.max(1, maxValue).toDouble(),
                      ),
                      getDrawingHorizontalLine: (_) => const FlLine(
                        color: AdminColors.border,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 34,
                          interval: _interval(math.max(1, maxValue).toDouble()),
                          getTitlesWidget: (value, meta) =>
                              _axisLabel(context, value.toInt().toString()),
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final plan = plans[group.x];
                          return BarTooltipItem(
                            '${planCodeLabel(plan)}\n${rod.toY.toInt()} delivered',
                            const TextStyle(
                              color: AdminColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ),
                    barGroups: [
                      for (var index = 0; index < plans.length; index++)
                        BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: deliveries[plans[index]]!.toDouble(),
                              width: 18,
                              color: index.isEven
                                  ? AdminColors.accent
                                  : AdminColors.information,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AdminRadii.control),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  duration: Duration.zero,
                ),
              ),
              const SizedBox(height: AdminSpacing.sm),
              _PlanLegend(deliveries: deliveries),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardUsageOutcomesChart extends StatelessWidget {
  const DashboardUsageOutcomesChart({
    super.key,
    required this.committed,
    required this.released,
  });

  final int committed;
  final int released;

  @override
  Widget build(BuildContext context) {
    if (committed == 0 && released == 0) {
      return const AdminChartCard(
        key: Key('chart-usage-outcomes-empty'),
        title: 'Usage Outcomes',
        description: 'Current month · Operations',
        child: _ChartEmptyContent(
          title: 'No usage outcomes yet',
          message:
              'No committed or released operations were reported this month.',
        ),
      );
    }
    final maxValue = math.max(1, math.max(committed, released)).toDouble();
    return AdminChartCard(
      key: const Key('chart-usage-outcomes'),
      title: 'Usage Outcomes',
      description: 'Current month · Operations',
      child: Semantics(
        label:
            'Usage Outcomes for the current month. Committed Operations: '
            '$committed. Released Operations: $released.',
        child: ExcludeSemantics(
          child: Column(
            children: [
              SizedBox(
                height: 230,
                child: BarChart(
                  BarChartData(
                    minY: 0,
                    maxY: maxValue * 1.15,
                    alignment: BarChartAlignment.spaceEvenly,
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: _interval(maxValue),
                      getDrawingHorizontalLine: (_) => const FlLine(
                        color: AdminColors.border,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) => SideTitleWidget(
                            meta: meta,
                            child: _axisLabel(
                              context,
                              value == 0 ? 'Committed' : 'Released',
                            ),
                          ),
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 34,
                          interval: _interval(maxValue),
                          getTitlesWidget: (value, meta) =>
                              _axisLabel(context, value.toInt().toString()),
                        ),
                      ),
                    ),
                    barGroups: [
                      _outcomeBar(0, committed, AdminColors.accent),
                      _outcomeBar(1, released, AdminColors.information),
                    ],
                  ),
                  duration: Duration.zero,
                ),
              ),
              const Wrap(
                alignment: WrapAlignment.center,
                spacing: AdminSpacing.md,
                runSpacing: AdminSpacing.xs,
                children: [
                  _LegendItem(
                    color: AdminColors.accent,
                    label: 'Committed Operations',
                  ),
                  _LegendItem(
                    color: AdminColors.information,
                    label: 'Released Operations',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static BarChartGroupData _outcomeBar(int x, int value, Color color) =>
      BarChartGroupData(
        x: x,
        barRods: [
          BarChartRodData(
            toY: value.toDouble(),
            width: 44,
            color: color,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AdminRadii.control),
            ),
          ),
        ],
      );
}

class DashboardEntitlementStatusChart extends StatelessWidget {
  const DashboardEntitlementStatusChart({
    super.key,
    required this.distribution,
  });

  final EntitlementStatusDistribution distribution;

  static const _colors = {
    EntitlementStatus.pending: AdminColors.textDisabled,
    EntitlementStatus.active: AdminColors.success,
    EntitlementStatus.gracePeriod: AdminColors.warning,
    EntitlementStatus.expired: AdminColors.textSecondary,
    EntitlementStatus.suspended: AdminColors.information,
    EntitlementStatus.revoked: AdminColors.error,
  };

  @override
  Widget build(BuildContext context) {
    if (distribution.total == 0) {
      return const AdminChartCard(
        key: Key('chart-entitlement-status-empty'),
        title: 'Current Entitlement Status',
        description: 'Current governing entitlements · Effective status',
        child: _ChartEmptyContent(
          title: 'No governing entitlements',
          message: 'There are no current entitlement statuses to chart.',
        ),
      );
    }
    final visible = EntitlementStatus.values
        .where((status) => distribution.byEffectiveStatus[status]! > 0)
        .toList(growable: false);
    final semantics = EntitlementStatus.values
        .map(
          (status) =>
              '${entitlementStatusLabel(status)}: '
              '${distribution.byEffectiveStatus[status]}',
        )
        .join(' ');

    return AdminChartCard(
      key: const Key('chart-entitlement-status'),
      title: 'Current Entitlement Status',
      description: 'Current governing entitlements · Effective status',
      child: Semantics(
        label:
            'Current governing entitlement status. Total '
            '${distribution.total}. $semantics',
        child: ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final chart = SizedBox(
                height: 230,
                width: compact ? double.infinity : 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        centerSpaceRadius: 58,
                        sectionsSpace: 3,
                        sections: visible.isEmpty
                            ? [
                                PieChartSectionData(
                                  value: 1,
                                  color: AdminColors.borderStrong,
                                  radius: 34,
                                  showTitle: false,
                                ),
                              ]
                            : [
                                for (final status in visible)
                                  PieChartSectionData(
                                    value: distribution
                                        .byEffectiveStatus[status]!
                                        .toDouble(),
                                    color: _colors[status],
                                    radius: 34,
                                    showTitle: false,
                                  ),
                              ],
                      ),
                      duration: Duration.zero,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${distribution.total}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(
                          'Total',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              );
              final legend = Wrap(
                spacing: AdminSpacing.md,
                runSpacing: AdminSpacing.sm,
                direction: compact ? Axis.horizontal : Axis.vertical,
                children: [
                  for (final status in visible)
                    _LegendItem(
                      color: _colors[status]!,
                      label:
                          '${entitlementStatusLabel(status)} '
                          '${distribution.byEffectiveStatus[status]}',
                    ),
                  if (visible.isEmpty)
                    const _LegendItem(
                      color: AdminColors.borderStrong,
                      label: 'No governing entitlements',
                    ),
                ],
              );
              return compact
                  ? Column(
                      children: [
                        chart,
                        const SizedBox(height: AdminSpacing.sm),
                        legend,
                      ],
                    )
                  : Row(
                      children: [
                        chart,
                        const SizedBox(width: AdminSpacing.lg),
                        Expanded(child: legend),
                      ],
                    );
            },
          ),
        ),
      ),
    );
  }
}

class _PlanLegend extends StatelessWidget {
  const _PlanLegend({required this.deliveries});

  final Map<SubscriptionPlanCode, int> deliveries;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AdminSpacing.md,
      runSpacing: AdminSpacing.xs,
      children: [
        for (var index = 0; index < SubscriptionPlanCode.values.length; index++)
          _LegendItem(
            color: index.isEven ? AdminColors.accent : AdminColors.information,
            label:
                '${planCodeLabel(SubscriptionPlanCode.values[index])} '
                '${deliveries[SubscriptionPlanCode.values[index]]}',
          ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AdminSpacing.xxs),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ChartEmptyContent extends StatelessWidget {
  const _ChartEmptyContent({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => AdminListNotice(
    icon: Icons.query_stats_outlined,
    title: title,
    message: message,
    bordered: false,
  );
}

Widget _axisLabel(BuildContext context, String label) => Text(
  label,
  style: Theme.of(
    context,
  ).textTheme.labelSmall?.copyWith(color: AdminColors.textSecondary),
);

double _interval(double max) => math.max(1, (max / 4).ceil()).toDouble();

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _monthDay(DateTime value) =>
    '${value.month.toString().padLeft(2, '0')}/'
    '${value.day.toString().padLeft(2, '0')}';
