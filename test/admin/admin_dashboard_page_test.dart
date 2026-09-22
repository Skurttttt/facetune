import 'package:facetune/admin/app/admin_app.dart';
import 'package:facetune/admin/auth/domain/admin_auth_failure.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_controller.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_state.dart';
import 'package:facetune/admin/dashboard/data/admin_dashboard_gateway_provider.dart';
import 'package:facetune/admin/dashboard/domain/admin_dashboard_metrics.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_error_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_dashboard_controller_test.dart' show ScriptedDashboardGateway;
import 'admin_dashboard_metrics_test.dart' show payload;
import 'admin_shell_test.dart' show FrozenAuthorization, identity;

/// The dashboard inside the real shell and router, with the metrics gateway
/// scripted and authorization frozen as an admin.
Future<(FrozenAuthorization, ScriptedDashboardGateway)> pumpDashboard(
  WidgetTester tester,
  List<Future<AdminDashboardMetrics> Function()> answers, {
  AdminAuthorizationState state = const AdminAuthorized(identity),
}) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = FrozenAuthorization(state);
  final gateway = ScriptedDashboardGateway(answers);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminAuthorizationControllerProvider.overrideWith((ref) => controller),
        adminDashboardGatewayProvider.overrideWithValue(gateway),
      ],
      child: const FaceTuneAdminApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
  return (controller, gateway);
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

String tileValue(WidgetTester tester, String key) {
  final texts = tester.widgetList<Text>(
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)),
  );
  return texts.elementAt(1).data!;
}

void main() {
  testWidgets('renders the server figures verbatim, with no percentages', (
    tester,
  ) async {
    await pumpDashboard(tester, [fixture]);
    await tester.pump();
    expect(find.byKey(const Key('admin-dashboard-metrics')), findsOneWidget);
    expect(tileValue(tester, 'tile-total-users'), '13');
    expect(tileValue(tester, 'tile-guests'), '2');
    expect(tileValue(tester, 'tile-committed-today'), '6');
    expect(find.text('+1 from purchased credits'), findsOneWidget);
    expect(tileValue(tester, 'tile-committed-month'), '41');
    expect(tileValue(tester, 'tile-reserved'), '2');
    expect(tileValue(tester, 'tile-released-month'), '5');
    expect(tileValue(tester, 'tile-pilot-in-force'), '2');
    expect(tileValue(tester, 'tile-pilot-expiring'), '1');
    expect(tileValue(tester, 'tile-pending'), '1');
    expect(tileValue(tester, 'tile-credit-grants'), '5');
    expect(find.byKey(const Key('admin-dashboard-as-of')), findsOneWidget);
    expect(find.textContaining('2026-09-22 10:15'), findsOneWidget);

    // Nothing invented: no percent sign anywhere on the page.
    final all = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join('\n');
    expect(all.contains('%'), isFalse);
    expect(all.contains('trend'), isFalse);
  });

  testWidgets('the plan table lists every canonical plan with its count', (
    tester,
  ) async {
    await pumpDashboard(tester, [fixture]);
    await tester.pump();
    for (final plan in SubscriptionPlanCode.values) {
      expect(find.byKey(Key('plan-row-${plan.code}')), findsOneWidget);
      expect(find.text(plan.code), findsOneWidget);
    }
    expect(find.text('FaceTune Plus Preview'), findsOneWidget);
    expect(find.text('Salon Pilot'), findsWidgets);
  });

  testWidgets('shows a loading state and no figures until the server answers', (
    tester,
  ) async {
    final (_, gateway) = await pumpDashboard(tester, []);
    expect(find.byKey(const Key('admin-dashboard-loading')), findsOneWidget);
    expect(find.byKey(const Key('admin-dashboard-metrics')), findsNothing);
    final refresh = tester.widget<OutlinedButton>(
      find.byKey(const Key('admin-dashboard-refresh')),
    );
    expect(refresh.onPressed, isNull, reason: 'no double-fetch while loading');
    gateway.pending!.complete(await fixture());
    await tester.pump();
    expect(find.byKey(const Key('admin-dashboard-metrics')), findsOneWidget);
  });

  testWidgets('an empty system is stated, not shown as a wall of zeros', (
    tester,
  ) async {
    await pumpDashboard(tester, [empty]);
    await tester.pump();
    expect(find.byKey(const Key('admin-dashboard-empty')), findsOneWidget);
    expect(find.byKey(const Key('admin-dashboard-metrics')), findsNothing);
  });

  testWidgets('a backend error shows an unavailable state with retry', (
    tester,
  ) async {
    await pumpDashboard(tester, [
      () async => throw const AdminAuthFailure(
        SubscriptionErrorCode.temporaryBackendFailure,
        retryable: true,
      ),
      fixture,
    ]);
    await tester.pump();
    expect(
      find.byKey(const Key('admin-dashboard-unavailable')),
      findsOneWidget,
    );
    expect(find.textContaining('TEMPORARY_BACKEND_FAILURE'), findsOneWidget);
    expect(find.byKey(const Key('admin-dashboard-metrics')), findsNothing);
    await tester.tap(find.byKey(const Key('admin-dashboard-retry')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('admin-dashboard-metrics')), findsOneWidget);
  });

  testWidgets(
    'a refusal from the metrics call sends the whole admin to the secure state',
    (tester) async {
      final (controller, _) = await pumpDashboard(tester, [
        () async => throw const AdminAuthFailure(
          SubscriptionErrorCode.adminUnauthorized,
        ),
      ]);
      await tester.pump();
      await tester.pump();
      expect(controller.state, isA<AdminUnauthorized>());
      expect(find.text('Not authorized'), findsOneWidget);
      expect(find.byKey(const Key('admin-dashboard-metrics')), findsNothing);
      expect(find.byKey(const Key('admin-nav-rail')), findsNothing);
    },
  );

  testWidgets(
    'refresh re-asks the server and keeps figures visible meanwhile',
    (tester) async {
      final (_, gateway) = await pumpDashboard(tester, [fixture]);
      await tester.pump();
      expect(gateway.calls, 1);
      await tester.tap(find.byKey(const Key('admin-dashboard-refresh')));
      await tester.pump();
      expect(gateway.calls, 2);
      expect(find.byKey(const Key('admin-dashboard-metrics')), findsOneWidget);
      final refresh = tester.widget<OutlinedButton>(
        find.byKey(const Key('admin-dashboard-refresh')),
      );
      expect(refresh.onPressed, isNull);
      gateway.pending!.complete(await fixture());
      await tester.pump();
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('admin-dashboard-refresh')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('no metrics call is made while authorization is pending', (
    tester,
  ) async {
    final (_, gateway) = await pumpDashboard(tester, [
      fixture,
    ], state: const AdminAuthorizationPending());
    await tester.pump();
    expect(gateway.calls, 0);
    expect(find.text('Checking authorization…'), findsOneWidget);
  });

  testWidgets('nothing identifying is rendered', (tester) async {
    await pumpDashboard(tester, [fixture]);
    await tester.pump();
    final all = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join('\n');
    // Only the signed-in admin's own email appears (identity chip).
    final emails = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+').allMatches(all);
    expect(emails.map((m) => m.group(0)).toSet(), {'ops@example.invalid'});
    expect(
      RegExp(
        r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
      ).hasMatch(all),
      isFalse,
    );
  });
}
