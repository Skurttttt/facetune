import 'dart:async';

import 'package:facetune/admin/auth/domain/admin_auth_failure.dart';
import 'package:facetune/admin/dashboard/domain/admin_dashboard_v2_gateway.dart';
import 'package:facetune/admin/dashboard/domain/admin_dashboard_v2_metrics.dart';
import 'package:facetune/admin/dashboard/presentation/admin_dashboard_v2_controller.dart';
import 'package:facetune/admin/shared/admin_read_failure.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_error_code.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_dashboard_v2_metrics_test.dart' show dashboardV2Payload;

class ScriptedDashboardV2Gateway implements AdminDashboardV2Gateway {
  ScriptedDashboardV2Gateway(this.answers);

  final List<Future<AdminDashboardV2Metrics> Function()> answers;
  int calls = 0;
  Completer<AdminDashboardV2Metrics>? pending;

  @override
  Future<AdminDashboardV2Metrics> fetchMetrics() {
    calls++;
    if (answers.isNotEmpty) return answers.removeAt(0)();
    pending = Completer<AdminDashboardV2Metrics>();
    return pending!.future;
  }
}

Future<AdminDashboardV2Metrics> v2Metrics() async =>
    AdminDashboardV2Metrics.decode(dashboardV2Payload());

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('loads and keeps V2 metrics visible during refresh', () async {
    final gateway = ScriptedDashboardV2Gateway([v2Metrics]);
    final controller = AdminDashboardV2Controller(
      gateway: gateway,
      onServerRefusal: (_) => fail('no refusal expected'),
      isAuthorized: () => true,
    );
    await settle();
    expect(controller.state, isA<AdminDashboardV2Ready>());
    final refresh = controller.refresh();
    final during = controller.state as AdminDashboardV2Ready;
    expect(during.refreshing, isTrue);
    gateway.pending!.complete(await v2Metrics());
    await refresh;
    expect((controller.state as AdminDashboardV2Ready).refreshing, isFalse);
  });

  test('optional V2 read failure is unavailable and retryable', () async {
    final controller = AdminDashboardV2Controller(
      gateway: ScriptedDashboardV2Gateway([
        () async => throw const AdminReadFailure(
          AdminReadFailureType.unavailable,
          retryable: true,
        ),
      ]),
      onServerRefusal: (_) => fail('not an authorization refusal'),
      isAuthorized: () => true,
    );
    await settle();
    final state = controller.state as AdminDashboardV2Unavailable;
    expect(state.retryable, isTrue);
  });

  test('authorization refusal is forwarded and fails closed', () async {
    final refusals = <AdminAuthFailure>[];
    final controller = AdminDashboardV2Controller(
      gateway: ScriptedDashboardV2Gateway([
        () async => throw const AdminAuthFailure(
          SubscriptionErrorCode.adminUnauthorized,
        ),
      ]),
      onServerRefusal: refusals.add,
      isAuthorized: () => true,
    );
    await settle();
    expect(refusals.single.code, SubscriptionErrorCode.adminUnauthorized);
    expect(controller.state, isA<AdminDashboardV2Unavailable>());
  });

  test('never reads V2 before authorization is established', () async {
    final gateway = ScriptedDashboardV2Gateway([v2Metrics]);
    final controller = AdminDashboardV2Controller(
      gateway: gateway,
      onServerRefusal: (_) {},
      isAuthorized: () => false,
    );
    expect(controller.state, isA<AdminDashboardV2Unavailable>());
    expect(gateway.calls, 0);
  });
}
