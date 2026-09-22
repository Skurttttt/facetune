import 'dart:async';

import 'package:facetune/admin/auth/domain/admin_auth_failure.dart';
import 'package:facetune/admin/dashboard/domain/admin_dashboard_gateway.dart';
import 'package:facetune/admin/dashboard/domain/admin_dashboard_metrics.dart';
import 'package:facetune/admin/dashboard/presentation/admin_dashboard_controller.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_error_code.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_dashboard_metrics_test.dart' show payload;

class ScriptedDashboardGateway implements AdminDashboardGateway {
  ScriptedDashboardGateway(this._answers);

  final List<Future<AdminDashboardMetrics> Function()> _answers;
  int calls = 0;
  Completer<AdminDashboardMetrics>? pending;

  @override
  Future<AdminDashboardMetrics> fetchMetrics() {
    calls++;
    if (_answers.isEmpty) {
      pending = Completer<AdminDashboardMetrics>();
      return pending!.future;
    }
    return _answers.removeAt(0)();
  }
}

Future<AdminDashboardMetrics> metrics({int users = 13}) async =>
    AdminDashboardMetrics.decode(
      payload(
        overrides: {
          'accounts': {'totalUsers': users, 'anonymousGuests': 0},
        },
      ),
    );

Future<AdminDashboardMetrics> Function() refuse(
  SubscriptionErrorCode code, {
  bool retryable = false,
}) =>
    () async => throw AdminAuthFailure(code, retryable: retryable);

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('AdminDashboardController', () {
    test('loads figures when the session is authorized', () async {
      final gateway = ScriptedDashboardGateway([() => metrics()]);
      final refusals = <AdminAuthFailure>[];
      final controller = AdminDashboardController(
        gateway: gateway,
        onServerRefusal: refusals.add,
        isAuthorized: () => true,
      );
      expect(controller.state, isA<AdminDashboardLoading>());
      await settle();
      final state = controller.state;
      expect(state, isA<AdminDashboardReady>());
      expect((state as AdminDashboardReady).metrics.accounts.totalUsers, 13);
      expect(state.refreshing, isFalse);
      expect(gateway.calls, 1);
      expect(refusals, isEmpty);
      controller.dispose();
    });

    test(
      'never asks the server before admin authorization is established',
      () async {
        final gateway = ScriptedDashboardGateway([() => metrics()]);
        final controller = AdminDashboardController(
          gateway: gateway,
          onServerRefusal: (_) {},
          isAuthorized: () => false,
        );
        await settle();
        expect(controller.state, isA<AdminDashboardUnavailable>());
        expect(gateway.calls, 0);
        await controller.refresh();
        expect(gateway.calls, 0);
        controller.dispose();
      },
    );

    test(
      'a server refusal is handed to the authorization controller',
      () async {
        final refusals = <AdminAuthFailure>[];
        final controller = AdminDashboardController(
          gateway: ScriptedDashboardGateway([
            refuse(SubscriptionErrorCode.adminUnauthorized),
          ]),
          onServerRefusal: refusals.add,
          isAuthorized: () => true,
        );
        await settle();
        expect(refusals.single.code, SubscriptionErrorCode.adminUnauthorized);
        final state = controller.state;
        expect(state, isA<AdminDashboardUnavailable>());
        expect((state as AdminDashboardUnavailable).retryable, isFalse);
        controller.dispose();
      },
    );

    test('an expired session mid-fetch is also handed over', () async {
      final refusals = <AdminAuthFailure>[];
      final controller = AdminDashboardController(
        gateway: ScriptedDashboardGateway([
          refuse(SubscriptionErrorCode.authRequired),
        ]),
        onServerRefusal: refusals.add,
        isAuthorized: () => true,
      );
      await settle();
      expect(refusals.single.isUnauthenticated, isTrue);
      controller.dispose();
    });

    test(
      'a backend error is unavailable and retryable; retry recovers',
      () async {
        final refusals = <AdminAuthFailure>[];
        final controller = AdminDashboardController(
          gateway: ScriptedDashboardGateway([
            refuse(
              SubscriptionErrorCode.temporaryBackendFailure,
              retryable: true,
            ),
            () => metrics(),
          ]),
          onServerRefusal: refusals.add,
          isAuthorized: () => true,
        );
        await settle();
        final failed = controller.state;
        expect(failed, isA<AdminDashboardUnavailable>());
        expect((failed as AdminDashboardUnavailable).retryable, isTrue);
        expect(refusals, isEmpty, reason: 'not an authorization matter');
        await controller.load();
        expect(controller.state, isA<AdminDashboardReady>());
        controller.dispose();
      },
    );

    test('an unexpected exception fails closed as unavailable', () async {
      final controller = AdminDashboardController(
        gateway: ScriptedDashboardGateway([() async => throw StateError('x')]),
        onServerRefusal: (_) {},
        isAuthorized: () => true,
      );
      await settle();
      expect(controller.state, isA<AdminDashboardUnavailable>());
      controller.dispose();
    });

    test(
      'refresh keeps the previous figures on screen while in flight',
      () async {
        final gateway = ScriptedDashboardGateway([() => metrics(users: 13)]);
        final controller = AdminDashboardController(
          gateway: gateway,
          onServerRefusal: (_) {},
          isAuthorized: () => true,
        );
        await settle();
        final refresh = controller.refresh();
        final during = controller.state;
        expect(during, isA<AdminDashboardReady>());
        expect((during as AdminDashboardReady).refreshing, isTrue);
        expect(during.metrics.accounts.totalUsers, 13);
        gateway.pending!.complete(await metrics(users: 14));
        await refresh;
        final after = controller.state as AdminDashboardReady;
        expect(after.refreshing, isFalse);
        expect(after.metrics.accounts.totalUsers, 14);
        controller.dispose();
      },
    );

    test('a stale answer never overwrites a newer one', () async {
      final gateway = ScriptedDashboardGateway([]);
      final controller = AdminDashboardController(
        gateway: gateway,
        onServerRefusal: (_) {},
        isAuthorized: () => true,
      );
      await settle();
      final first = gateway.pending!;
      final second = controller.load();
      final secondCompleter = gateway.pending!;
      secondCompleter.complete(await metrics(users: 20));
      await second;
      first.complete(await metrics(users: 10));
      await settle();
      expect(
        (controller.state as AdminDashboardReady).metrics.accounts.totalUsers,
        20,
      );
      controller.dispose();
    });
  });
}
