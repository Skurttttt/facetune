import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/subscription/domain/entities/entitlement_status.dart';
import '../../../../theme/app_tokens.dart';
import '../../../app/admin_routes.dart';
import '../../../shared/admin_keyset_list_controller.dart';
import '../../../shared/admin_labels.dart';
import '../../../shared/admin_list_widgets.dart';
import '../../domain/admin_research_models.dart';
import '../admin_pilot_metrics_controller.dart';
import '../admin_research_controller.dart';

/// The Salon Pilot research dashboard (WA-13).
///
/// Two independent server reads: the aggregate across every Salon Pilot grant
/// and a paged table with one row per grant. Renders the server's counts and
/// only the server's counts — no rates, no trends, no charts. The cost tile is
/// honest about what the system knows: usage is metered in tokens, images,
/// and attempts, and no monetary provider cost exists in the data, so the
/// effective cost per delivered AI Look is shown as not available rather than
/// estimated from a planning figure.
class AdminSalonPilotResearchPage extends ConsumerWidget {
  const AdminSalonPilotResearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminResearchControllerProvider);
    final controller = ref.read(adminResearchControllerProvider.notifier);
    final pilots = ref.watch(adminPilotMetricsControllerProvider);
    final pilotsController = ref.read(
      adminPilotMetricsControllerProvider.notifier,
    );
    final theme = Theme.of(context);

    return Column(
      key: const Key('admin-section-research'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: AdminSectionHeading(
                title: 'Salon Pilot research',
                description:
                    'Every Salon Pilot grant, aggregated on the server. '
                    'Counts are exact; nothing here is estimated.',
              ),
            ),
            if (state is AdminResearchReady)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Text(
                  'As of ${formatUtcDateTime(state.research.asOf)}',
                  key: const Key('admin-research-as-of'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            OutlinedButton.icon(
              key: const Key('admin-research-refresh'),
              onPressed: switch (state) {
                AdminResearchReady(refreshing: true) => null,
                AdminResearchLoading() => null,
                _ => () {
                  controller.refresh();
                  pilotsController.refresh();
                },
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        switch (state) {
          AdminResearchLoading() => const AdminListLoadingRow(
            key: Key('admin-research-loading'),
            label: 'Loading research metrics',
          ),
          AdminResearchUnavailable(:final retryable) => AdminListNotice(
            key: const Key('admin-research-unavailable'),
            icon: Icons.error_outline,
            message:
                'Research metrics could not be loaded. '
                '${retryable ? 'Try again in a moment.' : 'Sign in again to continue.'}',
            action: retryable
                ? TextButton(
                    key: const Key('admin-research-retry'),
                    onPressed: controller.load,
                    child: const Text('Try again'),
                  )
                : null,
          ),
          AdminResearchReady(:final research, :final refreshing) =>
            research.pilots.entitlements == 0
                ? const AdminListNotice(
                    key: Key('admin-research-empty'),
                    icon: Icons.science_outlined,
                    message:
                        'No Salon Pilot has been granted yet. Figures will '
                        'appear with the first grant.',
                  )
                : _Aggregate(research: research, refreshing: refreshing),
        },
        const SizedBox(height: AppSpacing.xl),
        Semantics(
          header: true,
          child: Text('Per pilot', style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'One row per Salon Pilot grant, newest first. Telemetry is attributed '
          'to the grant it ran under.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        switch (pilots) {
          AdminListLoading() => const AdminListLoadingRow(
            key: Key('admin-pilots-loading'),
            label: 'Loading pilots',
          ),
          AdminListRejected() => const AdminListNotice(
            key: Key('admin-pilots-rejected'),
            icon: Icons.error_outline,
            message:
                'The server did not accept this page request. Reload the '
                'section to start from the first page.',
          ),
          AdminListUnavailable(:final retryable) => AdminListNotice(
            key: const Key('admin-pilots-unavailable'),
            icon: Icons.error_outline,
            message: 'Pilot rows could not be loaded. Try again in a moment.',
            action: retryable
                ? TextButton(
                    key: const Key('admin-pilots-retry'),
                    onPressed: pilotsController.load,
                    child: const Text('Try again'),
                  )
                : null,
          ),
          AdminListReady(:final page) when page.items.isEmpty =>
            const AdminListNotice(
              key: Key('admin-pilots-empty'),
              icon: Icons.science_outlined,
              message: 'No Salon Pilot grants exist.',
            ),
          AdminListReady() => _PilotTable(
            state: pilots,
            controller: pilotsController,
          ),
        },
      ],
    );
  }
}

class _Aggregate extends StatelessWidget {
  const _Aggregate({required this.research, required this.refreshing});

  final AdminSalonPilotResearch research;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final p = research.pilots;
    final l = research.aiLooks;
    final o = research.operations;
    final u = research.billableUsage;
    final c = research.cost;

    return Opacity(
      opacity: refreshing ? 0.6 : 1,
      child: Column(
        key: const Key('admin-research-metrics'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Group(
            title: 'Pilots',
            tiles: [
              _Tile('Users', '${p.users}', key: const Key('tile-pilot-users')),
              _Tile(
                'Grants',
                '${p.entitlements}',
                key: const Key('tile-pilot-grants'),
              ),
              _Tile(
                'In force',
                '${p.inForce}',
                key: const Key('tile-pilot-in-force'),
              ),
              _Tile(
                'Suspended',
                '${p.suspended}',
                key: const Key('tile-pilot-suspended'),
              ),
              _Tile(
                'Lapsed or expired',
                '${p.lapsedOrExpired}',
                key: const Key('tile-pilot-lapsed'),
              ),
              _Tile(
                'Revoked',
                '${p.revoked}',
                key: const Key('tile-pilot-revoked'),
              ),
              _Tile(
                'Expiring within 14 days',
                '${p.expiringWithin14Days}',
                key: const Key('tile-pilot-expiring'),
                emphasis: p.expiringWithin14Days > 0,
              ),
            ],
          ),
          _Group(
            title: 'AI Looks',
            caption:
                'Committed = a persisted Final Makeup Preview. Remaining = '
                'effective allowance minus committed.',
            tiles: [
              _Tile(
                'Granted at start',
                '${l.grantedBase}',
                key: const Key('tile-looks-granted'),
              ),
              _Tile(
                'Admin adjustments',
                _signed(l.adminAdjustmentsTotal),
                key: const Key('tile-looks-adjustments'),
              ),
              _Tile(
                'Effective allowance',
                '${l.effectiveAllowance}',
                key: const Key('tile-looks-effective'),
              ),
              _Tile(
                'Committed',
                '${l.committed}',
                key: const Key('tile-looks-committed'),
              ),
              _Tile(
                'Reserved',
                '${l.reserved}',
                key: const Key('tile-looks-reserved'),
              ),
              _Tile(
                'Released',
                '${l.released}',
                key: const Key('tile-looks-released'),
              ),
              _Tile(
                'Remaining',
                '${l.remaining}',
                key: const Key('tile-looks-remaining'),
              ),
            ],
          ),
          _Group(
            title: 'Operations',
            caption:
                'Telemetry outcomes for work attributed to a Salon Pilot grant '
                '(${o.telemetryEvents} events).',
            tiles: [
              _OutcomeTile(
                'Final Preview',
                o.finalPreview,
                key: const Key('tile-ops-final-preview'),
              ),
              _OutcomeTile(
                'Tutorial manifest',
                o.tutorialManifest,
                key: const Key('tile-ops-tutorial-manifest'),
              ),
              _OutcomeTile(
                'Tutorial step',
                o.tutorialStep,
                key: const Key('tile-ops-tutorial-step'),
              ),
            ],
          ),
          _Group(
            title: 'Billable usage',
            caption:
                'Provider usage in the units the system meters. '
                '${u.eventsWithoutTokenData} of ${u.eventsWithTokenData + u.eventsWithoutTokenData} '
                'events carried no token data and are excluded from the token '
                'totals.',
            tiles: [
              _Tile(
                'Provider attempts',
                '${u.providerAttempts}',
                key: const Key('tile-usage-attempts'),
              ),
              _Tile(
                'Total tokens',
                '${u.totalTokens}',
                detail: '${u.inputTokens} in · ${u.outputTokens} out',
                key: const Key('tile-usage-total-tokens'),
              ),
              _Tile(
                'Output images',
                '${u.outputImages}',
                key: const Key('tile-usage-output-images'),
              ),
              _Tile(
                'Image tokens',
                '${u.inputImageTokens + u.outputImageTokens}',
                detail: '${u.inputImageTokens} in · ${u.outputImageTokens} out',
                key: const Key('tile-usage-image-tokens'),
              ),
              _Tile(
                'Cached tokens',
                '${u.cachedTokens}',
                key: const Key('tile-usage-cached-tokens'),
              ),
              _Tile(
                'Thinking tokens',
                '${u.thoughtsTokens}',
                key: const Key('tile-usage-thoughts-tokens'),
              ),
            ],
          ),
          _Group(
            title: 'Cost',
            caption: c.available
                ? 'Computed from recorded provider cost data only.'
                : 'The system records provider usage, not provider cost. No '
                      'cost is estimated in its place.',
            tiles: [
              _Tile(
                'Total billable cost',
                _money(c, c.totalBillableCost),
                key: const Key('tile-cost-total'),
                detail: c.available ? null : c.reason,
              ),
              _Tile(
                'Effective cost per delivered AI Look',
                _money(c, c.effectiveCostPerDeliveredAiLook),
                key: const Key('tile-cost-per-look'),
                detail: c.available ? 'Per committed Final Preview' : c.reason,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _signed(int value) => value >= 0 ? '+$value' : '$value';

  static String _money(PilotCostAvailability cost, num? value) {
    if (!cost.available || value == null) return 'Not available';
    final currency = cost.currency;
    return currency == null ? '$value' : '$value $currency';
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.tiles, this.caption});

  final String title;
  final String? caption;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(caption!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
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
  final String value;
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
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(
              color: emphasis
                  ? theme.colorScheme.tertiary
                  : theme.colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                value,
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

/// The four telemetry outcomes of one operation kind, written out.
class _OutcomeTile extends StatelessWidget {
  const _OutcomeTile(this.label, this.outcomes, {super.key});

  final String label;
  final OperationOutcomes outcomes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final o = outcomes;
    final numeric = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Semantics(
      label:
          '$label: ${o.succeeded} succeeded, ${o.failed} failed, '
          '${o.denied} denied, ${o.duplicate} duplicate',
      child: ExcludeSemantics(
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${o.succeeded}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text('succeeded', style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xxs),
              Text('${o.failed} failed', style: numeric),
              Text('${o.denied} denied', style: numeric),
              Text('${o.duplicate} duplicate', style: numeric),
            ],
          ),
        ),
      ),
    );
  }
}

class _PilotTable extends StatelessWidget {
  const _PilotTable({required this.state, required this.controller});

  final AdminListReady<AdminPilotMetricsRow, void> state;
  final AdminPilotMetricsController controller;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: state.refreshing ? 0.6 : 1,
      child: Column(
        key: const Key('admin-pilots-results'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: AppSpacing.md,
                columns: const [
                  DataColumn(label: Text('User')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Effective allowance'), numeric: true),
                  DataColumn(label: Text('Committed'), numeric: true),
                  DataColumn(label: Text('Reserved'), numeric: true),
                  DataColumn(label: Text('Remaining'), numeric: true),
                  DataColumn(label: Text('Delivered'), numeric: true),
                  DataColumn(label: Text('Released'), numeric: true),
                  DataColumn(label: Text('Preview failures'), numeric: true),
                  DataColumn(label: Text('Tutorial ops'), numeric: true),
                  DataColumn(label: Text('Tutorial failures'), numeric: true),
                  DataColumn(label: Text('Attempts'), numeric: true),
                  DataColumn(label: Text('Tokens'), numeric: true),
                  DataColumn(label: Text('Images'), numeric: true),
                  DataColumn(label: Text('Starts')),
                  DataColumn(label: Text('Expires')),
                  DataColumn(label: Text('Last activity')),
                  DataColumn(label: Text('')),
                ],
                rows: [
                  for (final row in state.page.items)
                    DataRow(
                      key: ValueKey('admin-pilot-${row.entitlementId}'),
                      cells: [
                        DataCell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(row.email ?? 'No email'),
                              AdminIdCell(row.userId),
                            ],
                          ),
                        ),
                        DataCell(
                          AdminStatusBadge(
                            key: Key('pilot-status-${row.entitlementId}'),
                            label: _status(row),
                            semanticsPrefix: 'Entitlement status',
                            emphasis: _emphasis(row.effectiveStatus),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${row.effectiveAllowance}',
                            key: Key('pilot-effective-${row.entitlementId}'),
                          ),
                        ),
                        DataCell(Text('${row.committed}')),
                        DataCell(Text('${row.reserved}')),
                        DataCell(Text('${row.remaining}')),
                        DataCell(
                          Text(
                            '${row.deliveredFinalPreviews}',
                            key: Key('pilot-delivered-${row.entitlementId}'),
                          ),
                        ),
                        DataCell(Text('${row.releasedOperations}')),
                        DataCell(Text('${row.finalPreviewFailures}')),
                        DataCell(Text('${row.tutorialOperations}')),
                        DataCell(Text('${row.tutorialFailures}')),
                        DataCell(Text('${row.providerAttempts}')),
                        DataCell(
                          Text(
                            '${row.totalTokens}',
                            key: Key('pilot-tokens-${row.entitlementId}'),
                          ),
                        ),
                        DataCell(Text('${row.outputImages}')),
                        DataCell(Text(formatUtcDate(row.startsAt))),
                        DataCell(
                          Text(
                            row.expiresAt == null
                                ? 'Not applicable'
                                : formatUtcDate(row.expiresAt!),
                          ),
                        ),
                        DataCell(
                          Text(
                            row.lastActivityAt == null
                                ? 'None'
                                : formatUtcDate(row.lastActivityAt!),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                key: Key('view-user-${row.entitlementId}'),
                                onPressed: () => context.go(
                                  AdminRoutes.userDetail(row.userId),
                                ),
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
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AdminPaginationBar(
            keyPrefix: 'admin-pilots',
            state: state,
            onPrevious: controller.previousPage,
            onNext: controller.nextPage,
          ),
        ],
      ),
    );
  }

  /// The effective status, with the stored one alongside when they differ
  /// (an `active` row past its expiration reads "Expired (stored: Active)").
  static String _status(AdminPilotMetricsRow row) {
    final effective = entitlementStatusLabel(row.effectiveStatus);
    if (row.effectiveStatus == row.storedStatus) return effective;
    return '$effective (stored: ${entitlementStatusLabel(row.storedStatus)})';
  }

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
