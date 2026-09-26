import 'dart:async';

import 'package:facetune/admin/app/admin_app.dart';
import 'package:facetune/admin/auth/domain/admin_auth_failure.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_controller.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_state.dart';
import 'package:facetune/admin/dashboard/data/admin_dashboard_gateway_provider.dart';
import 'package:facetune/admin/dashboard/data/admin_dashboard_v2_gateway_provider.dart';
import 'package:facetune/admin/dashboard/domain/admin_dashboard_metrics.dart';
import 'package:facetune/admin/dashboard/domain/admin_dashboard_v2_metrics.dart';
import 'package:facetune/admin/dashboard/presentation/widgets/admin_dashboard_charts.dart';
import 'package:facetune/admin/research/data/admin_research_gateway_provider.dart';
import 'package:facetune/admin/research/domain/admin_research_gateway.dart';
import 'package:facetune/admin/research/domain/admin_research_models.dart';
import 'package:facetune/admin/shared/admin_cards.dart';
import 'package:facetune/admin/shared/admin_keyset_list_controller.dart';
import 'package:facetune/admin/shared/admin_list_widgets.dart';
import 'package:facetune/admin/shared/admin_read_failure.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_error_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_dashboard_controller_test.dart' show ScriptedDashboardGateway;
import 'admin_dashboard_metrics_test.dart' show payload;
import 'admin_dashboard_v2_controller_test.dart'
    show ScriptedDashboardV2Gateway, v2Metrics;
import 'admin_dashboard_v2_metrics_test.dart' show dashboardV2Payload;
import 'admin_research_models_test.dart' show pilotRow, pilotsPayload;
import 'admin_shell_test.dart' show FrozenAuthorization, identity;

class DashboardResearchGateway implements AdminResearchGateway {
  DashboardResearchGateway(this.pages);

  final List<Future<AdminListPage<AdminPilotMetricsRow>> Function(String?)>
  pages;
  int listCalls = 0;
  Completer<AdminListPage<AdminPilotMetricsRow>>? pending;

  @override
  Future<AdminSalonPilotResearch> fetchResearch() =>
      Completer<AdminSalonPilotResearch>().future;

  @override
  Future<AdminListPage<AdminPilotMetricsRow>> listPilots({String? cursor}) {
    listCalls++;
    if (pages.isNotEmpty) return pages.removeAt(0)(cursor);
    pending = Completer<AdminListPage<AdminPilotMetricsRow>>();
    return pending!.future;
  }
}

Future<AdminDashboardMetrics> fixture() async =>
    AdminDashboardMetrics.decode(payload());

Future<AdminDashboardMetrics> empty() async => AdminDashboardMetrics.decode(
  payload(
    overrides: {
      'accounts': {'totalUsers': 0, 'anonymousGuests': 0},
    },
    inForceByPlan: {
      for (final plan in SubscriptionPlanCode.values) plan.code: 0,
    },
  ),
);

Future<AdminListPage<AdminPilotMetricsRow>> pilotPage(String? _) async =>
    AdminPilotMetricsRow.decodePage(pilotsPayload([pilotRow()]));

Future<AdminListPage<AdminPilotMetricsRow>> emptyPilotPage(String? _) async =>
    AdminPilotMetricsRow.decodePage(pilotsPayload([]));

Future<
  (
    FrozenAuthorization,
    ScriptedDashboardGateway,
    ScriptedDashboardV2Gateway,
    DashboardResearchGateway,
  )
>
pumpDashboard(
  WidgetTester tester,
  List<Future<AdminDashboardMetrics> Function()> answers, {
  List<Future<AdminDashboardV2Metrics> Function()>? v2Answers,
  List<Future<AdminListPage<AdminPilotMetricsRow>> Function(String?)>?
  pilotAnswers,
  AdminAuthorizationState state = const AdminAuthorized(identity),
  Size size = const Size(1400, 1800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final authorization = FrozenAuthorization(state);
  final gateway = ScriptedDashboardGateway(answers);
  final v2Gateway = ScriptedDashboardV2Gateway(v2Answers ?? [v2Metrics]);
  final researchGateway = DashboardResearchGateway(pilotAnswers ?? [pilotPage]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminAuthorizationControllerProvider.overrideWith(
          (ref) => authorization,
        ),
        adminDashboardGatewayProvider.overrideWithValue(gateway),
        adminDashboardV2GatewayProvider.overrideWithValue(v2Gateway),
        adminResearchGatewayProvider.overrideWithValue(researchGateway),
      ],
      child: const FaceTuneAdminApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
  return (authorization, gateway, v2Gateway, researchGateway);
}

String tileValue(WidgetTester tester, String key) {
  final texts = tester.widgetList<Text>(
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)),
  );
  return texts.elementAt(1).data!;
}

void main() {
  test('7D presentation uses the final seven server points', () {
    final metrics = AdminDashboardV2Metrics.decode(dashboardV2Payload());
    final seven = dashboardDailyWindow(metrics.committedDaily, 7);
    expect(seven, hasLength(7));
    expect(seven.first, same(metrics.committedDaily[23]));
    expect(seven.last, same(metrics.committedDaily.last));
  });

  testWidgets('renders honest summaries and all four authoritative charts', (
    tester,
  ) async {
    await pumpDashboard(tester, [fixture]);
    await tester.pump();

    expect(tileValue(tester, 'tile-total-users'), '13');
    expect(tileValue(tester, 'tile-in-force-entitlements'), '26');
    expect(tileValue(tester, 'tile-pilot-in-force'), '2');
    expect(tileValue(tester, 'tile-ai-looks-today'), '7');
    expect(find.byType(AdminStatCard), findsNWidgets(6));
    expect(find.byType(AdminChartCard), findsNWidgets(4));
    expect(
      find.text('9 Preview credits separate · 2 legacy / unattributed'),
      findsOneWidget,
    );
    expect(find.text('Active Paid'), findsNothing);

    expect(find.byKey(const Key('chart-committed-ai-looks')), findsOneWidget);
    expect(find.text('Committed AI Looks'), findsOneWidget);
    expect(
      find.text('Authoritative daily AI Look units · UTC'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('chart-final-previews-by-plan')),
      findsOneWidget,
    );
    expect(find.text('Final Previews Delivered by Plan'), findsOneWidget);
    expect(find.text('Legacy / Unattributed: 3'), findsOneWidget);
    expect(find.byKey(const Key('chart-usage-outcomes')), findsOneWidget);
    expect(find.text('Usage Outcomes'), findsOneWidget);
    expect(find.text('Current month · Operations'), findsOneWidget);
    expect(find.text('Committed Operations'), findsOneWidget);
    expect(find.text('Released Operations'), findsOneWidget);
    expect(find.byKey(const Key('chart-entitlement-status')), findsOneWidget);
    expect(find.text('Current Entitlement Status'), findsOneWidget);
    expect(
      find.text('Current governing entitlements · Effective status'),
      findsOneWidget,
    );

    for (final label in [
      'Free 0',
      'Plus 1',
      'Plus Preview 2',
      'Pro 3',
      'Pro Preview 4',
      'Salon Pro 5',
      'Salon Preview 6',
      'Salon Pilot 7',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.textContaining('AI Looks by Plan'), findsNothing);
    expect(find.byKey(const Key('admin-pilot-usage-rows')), findsOneWidget);

    expect(
      tester
          .widget<SegmentedButton<int>>(
            find.byKey(const Key('dashboard-activity-window')),
          )
          .selected,
      {30},
    );
    await tester.tap(find.text('7D'));
    await tester.pump();
    expect(
      tester
          .widget<SegmentedButton<int>>(
            find.byKey(const Key('dashboard-activity-window')),
          )
          .selected,
      {7},
    );
  });

  testWidgets('AI Looks Today never includes Preview credits or unattributed', (
    tester,
  ) async {
    await pumpDashboard(tester, [fixture]);
    await tester.pump();
    expect(tileValue(tester, 'tile-ai-looks-today'), '7');
    expect(tileValue(tester, 'tile-ai-looks-today'), isNot('18'));
  });

  testWidgets('all zero-valued chart series render explicit no-data states', (
    tester,
  ) async {
    Future<AdminDashboardMetrics> noOutcomes() async =>
        AdminDashboardMetrics.decode(
          payload(
            overrides: {
              'aiLooks': {
                'committedToday': {'subscription': 0, 'purchasedCredit': 0},
                'committedThisMonth': {'subscription': 0, 'purchasedCredit': 0},
                'reservedOpen': 0,
                'releasedToday': 0,
                'releasedThisMonth': 0,
              },
            },
          ),
        );
    final daily = dashboardV2Payload()['committedDaily']! as List<Object?>;
    Future<AdminDashboardV2Metrics> zeros() async =>
        AdminDashboardV2Metrics.decode(
          dashboardV2Payload(
            daily: [
              for (final value in daily)
                {...Map<String, Object?>.from(value! as Map), 'aiLook': 0},
            ],
            plans: [
              for (final plan in SubscriptionPlanCode.values)
                {'planCode': plan.code, 'delivered': 0},
            ],
            overrides: {
              'finalPreviewsUnattributed30d': 0,
              'entitlementStatusDistribution': {
                'total': 0,
                'byStoredStatus': {
                  'pending': 0,
                  'active': 0,
                  'grace_period': 0,
                  'expired': 0,
                  'suspended': 0,
                  'revoked': 0,
                },
                'byEffectiveStatus': {
                  'pending': 0,
                  'active': 0,
                  'grace_period': 0,
                  'expired': 0,
                  'suspended': 0,
                  'revoked': 0,
                },
              },
            },
          ),
        );
    await pumpDashboard(tester, [noOutcomes], v2Answers: [zeros]);
    await tester.pump();
    expect(
      find.byKey(const Key('chart-committed-ai-looks-empty')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('chart-final-previews-by-plan-empty')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('chart-usage-outcomes-empty')), findsOneWidget);
    expect(
      find.byKey(const Key('chart-entitlement-status-empty')),
      findsOneWidget,
    );
    expect(find.text('No committed AI Looks'), findsOneWidget);
    expect(find.text('No final previews delivered'), findsOneWidget);
    expect(find.text('No usage outcomes yet'), findsOneWidget);
    expect(find.text('No governing entitlements'), findsOneWidget);
    expect(find.byKey(const Key('chart-committed-ai-looks')), findsNothing);
    expect(find.byKey(const Key('chart-usage-outcomes')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('usage outcome sums only fixed committed source buckets', (
    tester,
  ) async {
    await pumpDashboard(tester, [fixture]);
    await tester.pump();
    final semantics = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((widget) => widget.properties.label ?? '')
        .join('\n');
    expect(semantics, contains('Committed Operations: 44'));
    expect(semantics, contains('Released Operations: 5'));
    expect(
      semantics,
      isNot(contains('46')),
      reason: '2 open reservations are not historical outcomes',
    );
  });

  testWidgets('zero pilot allowance is safe and uses server row values', (
    tester,
  ) async {
    Future<AdminListPage<AdminPilotMetricsRow>> zeroPage(String? _) async =>
        AdminPilotMetricsRow.decodePage(
          pilotsPayload([
            pilotRow(
              overrides: {
                'initialAllowance': 0,
                'adminAdjustmentsTotal': 0,
                'effectiveAllowance': 0,
                'committed': 0,
                'reserved': 0,
                'remaining': 0,
                'available': 0,
              },
            ),
          ]),
        );
    await pumpDashboard(tester, [fixture], pilotAnswers: [zeroPage]);
    await tester.pump();
    expect(find.text('0 / 0 committed'), findsOneWidget);
    expect(find.text('0 remaining'), findsOneWidget);
    final progress = tester.widget<LinearProgressIndicator>(
      find.descendant(
        of: find.byKey(
          const Key('pilot-progress-31000000-0000-4000-8000-000000000001'),
        ),
        matching: find.byType(LinearProgressIndicator),
      ),
    );
    expect(progress.value, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pilot presentation is capped at five rows from one page', (
    tester,
  ) async {
    Future<AdminListPage<AdminPilotMetricsRow>> sixRows(
      String? _,
    ) async => AdminPilotMetricsRow.decodePage(
      pilotsPayload([
        for (var index = 1; index <= 6; index++)
          pilotRow(
            id: '31000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
            userId:
                '20000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
            email: 'pilot$index@example.invalid',
          ),
      ], nextCursor: 'next'),
    );
    await pumpDashboard(tester, [fixture], pilotAnswers: [sixRows]);
    await tester.pump();
    expect(find.byKey(const Key('admin-pilot-usage-rows')), findsOneWidget);
    expect(find.text('pilot5@example.invalid'), findsOneWidget);
    expect(find.text('pilot6@example.invalid'), findsNothing);
    expect(
      find.text('Showing 5 pilots from the first bounded page.'),
      findsOneWidget,
    );
  });

  testWidgets('V2 failure leaves V1 and Usage Outcomes operational', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      [fixture],
      v2Answers: [
        () async => throw const AdminReadFailure(
          AdminReadFailureType.unavailable,
          retryable: true,
        ),
      ],
    );
    await tester.pump();
    expect(find.byKey(const Key('admin-dashboard-metrics')), findsOneWidget);
    expect(tileValue(tester, 'tile-total-users'), '13');
    expect(tileValue(tester, 'tile-ai-looks-today'), 'Unavailable');
    expect(find.byKey(const Key('chart-usage-outcomes')), findsOneWidget);
    expect(
      find.byKey(const Key('chart-committed-ai-looks-unavailable')),
      findsOneWidget,
    );
    expect(find.textContaining('No values were fabricated'), findsNWidgets(3));
  });

  testWidgets('optional pilot failure leaves the dashboard operational', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      [fixture],
      pilotAnswers: [
        (_) async => throw const AdminReadFailure(
          AdminReadFailureType.unavailable,
          retryable: true,
        ),
      ],
    );
    await tester.pump();
    expect(find.byKey(const Key('chart-committed-ai-looks')), findsOneWidget);
    expect(
      find.byKey(const Key('admin-pilot-usage-unavailable')),
      findsOneWidget,
    );
  });

  testWidgets('loading and empty baseline behavior remain explicit', (
    tester,
  ) async {
    final (_, gateway, _, _) = await pumpDashboard(tester, []);
    expect(find.byKey(const Key('admin-dashboard-loading')), findsOneWidget);
    expect(find.byType(AdminSkeletonRows), findsNWidgets(3));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('admin-dashboard-refresh')),
          )
          .onPressed,
      isNull,
    );
    gateway.pending!.complete(await empty());
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('admin-dashboard-empty')), findsOneWidget);
  });

  testWidgets('one refresh intentionally reloads all Dashboard-owned reads', (
    tester,
  ) async {
    final (_, v1, v2, pilots) = await pumpDashboard(tester, [fixture]);
    await tester.pump();
    expect((v1.calls, v2.calls, pilots.listCalls), (1, 1, 1));
    await tester.tap(find.byKey(const Key('admin-dashboard-refresh')));
    await tester.pump();
    expect((v1.calls, v2.calls, pilots.listCalls), (2, 2, 2));
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('admin-dashboard-refresh')),
          )
          .onPressed,
      isNull,
    );
    v1.pending!.complete(await fixture());
    v2.pending!.complete(await v2Metrics());
    pilots.pending!.complete(await pilotPage(null));
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('admin-dashboard-refresh')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'baseline backend error still owns the whole-page unavailable state',
    (tester) async {
      await pumpDashboard(tester, [
        () async => throw const AdminAuthFailure(
          SubscriptionErrorCode.temporaryBackendFailure,
          retryable: true,
        ),
      ]);
      await tester.pump();
      expect(
        find.byKey(const Key('admin-dashboard-unavailable')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('admin-dashboard-metrics')), findsNothing);
    },
  );

  testWidgets(
    'an admin refusal moves the whole application to the secure state',
    (tester) async {
      final (authorization, _, _, _) = await pumpDashboard(tester, [
        () async => throw const AdminAuthFailure(
          SubscriptionErrorCode.adminUnauthorized,
        ),
      ]);
      await tester.pump();
      await tester.pump();
      expect(authorization.state, isA<AdminUnauthorized>());
      expect(find.text('Not authorized'), findsOneWidget);
      expect(find.byKey(const Key('admin-dashboard-metrics')), findsNothing);
    },
  );

  testWidgets('representative dashboard widths do not overflow', (
    tester,
  ) async {
    for (final width in [1600.0, 1366.0, 1100.0, 1024.0, 768.0]) {
      await pumpDashboard(tester, [fixture], size: Size(width, 1800));
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'dashboard overflowed at width $width',
      );
    }
  });

  testWidgets('dashboard requests and renders no private product data', (
    tester,
  ) async {
    await pumpDashboard(tester, [fixture]);
    await tester.pump();
    final text = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .join('\n')
        .toLowerCase();
    for (final forbidden in [
      'selfie',
      'signed url',
      'storage path',
      'raw prompt',
      'purchase token',
      'provider payload',
    ]) {
      expect(text, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}
