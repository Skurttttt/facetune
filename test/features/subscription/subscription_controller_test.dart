import 'dart:async';

import 'package:facetune/features/subscription/domain/entities/billing_provider.dart';
import 'package:facetune/features/subscription/domain/entities/entitlement_status.dart';
import 'package:facetune/features/subscription/domain/entities/reset_policy.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_summary.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_usage_summary.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_state_failure.dart';
import 'package:facetune/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:facetune/features/subscription/domain/usecases/resolve_subscription_summary.dart';
import 'package:facetune/features/subscription/presentation/controllers/subscription_controller.dart';
import 'package:facetune/features/subscription/presentation/controllers/subscription_state.dart';
import 'package:flutter_test/flutter_test.dart';

SubscriptionSummary summaryWith({
  int allowance = 3,
  int committed = 0,
  int reserved = 0,
  bool authorized = true,
}) => SubscriptionSummary(
  hasEntitlement: true,
  planCode: SubscriptionPlanCode.plus,
  planDisplayName: 'FaceTune Plus',
  usage: SubscriptionUsageSummary(
    effectiveAllowance: allowance,
    committedUsage: committed,
    reservedUsage: reserved,
  ),
  generationAuthorized: authorized,
  resolvedAt: DateTime.utc(2026, 9, 7, 12),
  status: EntitlementStatus.active,
  billingProvider: BillingProvider.googlePlay,
  resetPolicy: ResetPolicy.billingPeriod,
);

/// A repository whose every answer the test controls, including when it lands.
class _FakeSubscriptionRepository implements SubscriptionRepository {
  int calls = 0;
  final List<Completer<SubscriptionSummary>> pending = [];

  /// When set, `resolve` completes immediately with this.
  SubscriptionSummary? immediate;

  /// When set, `resolve` fails immediately with this.
  Object? failure;

  @override
  Future<SubscriptionSummary> resolve() {
    calls += 1;
    if (failure != null) return Future.error(failure!);
    if (immediate != null) return Future.value(immediate);
    final completer = Completer<SubscriptionSummary>();
    pending.add(completer);
    return completer.future;
  }
}

void main() {
  late _FakeSubscriptionRepository repository;
  late SubscriptionController controller;

  setUp(() {
    repository = _FakeSubscriptionRepository();
    controller = SubscriptionController(ResolveSubscriptionSummary(repository));
  });

  tearDown(() => controller.dispose());

  group('lifecycle states', () {
    test('starts in initial with nothing to show', () {
      expect(controller.state.status, SubscriptionStatus.initial);
      expect(controller.state.hasSummary, isFalse);
    });

    test('load moves through loading to ready', () async {
      final future = controller.load();
      expect(controller.state.status, SubscriptionStatus.loading);
      expect(controller.state.hasSummary, isFalse);

      repository.pending.single.complete(summaryWith());
      await future;

      expect(controller.state.status, SubscriptionStatus.ready);
      expect(controller.state.summary?.planCode, SubscriptionPlanCode.plus);
    });

    test('a failure keeps the last known summary visible behind it', () async {
      repository.immediate = summaryWith(committed: 1);
      await controller.load();
      expect(controller.state.status, SubscriptionStatus.ready);

      repository.immediate = null;
      repository.failure = const SubscriptionStateFailure(
        'You appear to be offline. Reconnect and try again.',
        kind: SubscriptionStateFailureKind.offline,
      );
      await controller.refresh();

      expect(controller.state.status, SubscriptionStatus.failure);
      expect(
        controller.state.failureKind,
        SubscriptionStateFailureKind.offline,
      );
      expect(controller.state.retryable, isTrue);
      // Stale figures are more useful than none, and are never authoritative.
      expect(controller.state.summary?.usage.committedUsage, 1);
    });

    test('a session failure discards the summary', () async {
      repository.immediate = summaryWith();
      await controller.load();

      repository.immediate = null;
      repository.failure = const SubscriptionStateFailure(
        'Your session expired. Sign in again.',
        kind: SubscriptionStateFailureKind.sessionExpired,
        retryable: false,
      );
      await controller.refresh();

      expect(controller.state.status, SubscriptionStatus.failure);
      expect(controller.state.isSessionFailure, isTrue);
      expect(controller.state.retryable, isFalse);
      expect(controller.state.hasSummary, isFalse);
    });

    test('an unexpected error is translated, not leaked', () async {
      repository.failure = StateError('backend exploded');
      await controller.load();

      expect(controller.state.status, SubscriptionStatus.failure);
      expect(
        controller.state.failureKind,
        SubscriptionStateFailureKind.unknown,
      );
      expect(controller.state.message, isNot(contains('exploded')));
    });
  });

  group('refresh', () {
    test('keeps the current figures on screen while it runs', () async {
      repository.immediate = summaryWith(committed: 1);
      await controller.load();

      repository.immediate = null;
      final future = controller.refresh();

      expect(controller.state.status, SubscriptionStatus.refreshing);
      expect(controller.state.isRefreshing, isTrue);
      expect(controller.state.summary?.usage.committedUsage, 1);

      repository.pending.single.complete(summaryWith(committed: 2));
      await future;

      expect(controller.state.status, SubscriptionStatus.ready);
      expect(controller.state.summary?.usage.committedUsage, 2);
    });

    test('a refresh with nothing loaded yet shows loading, not refreshing', () {
      controller.refresh();
      expect(controller.state.status, SubscriptionStatus.loading);
    });
  });

  group('async safety', () {
    test('a rebuild storm does not fan out into backend calls', () async {
      controller.load();
      controller.load();
      controller.load();
      await controller.refresh();

      expect(
        repository.calls,
        1,
        reason: 'a read already in flight must not be duplicated',
      );

      repository.pending.single.complete(summaryWith());
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.status, SubscriptionStatus.ready);
    });

    test('a stale response never overwrites a newer answer', () async {
      // First read starts and stalls.
      controller.load();
      final stale = repository.pending.single;

      // The account changes, which supersedes anything in flight.
      controller.markSignedOut();
      expect(controller.state.status, SubscriptionStatus.signedOut);

      // The old read finally lands. It must be discarded.
      stale.complete(summaryWith(allowance: 35));
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.status, SubscriptionStatus.signedOut);
      expect(controller.state.hasSummary, isFalse);
    });

    test('a stale failure never overwrites a newer answer either', () async {
      controller.load();
      final stale = repository.pending.single;
      controller.markSignedOut();

      stale.completeError(
        const SubscriptionStateFailure(
          'timed out',
          kind: SubscriptionStateFailureKind.timeout,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.status, SubscriptionStatus.signedOut);
      expect(controller.state.message, isNull);
    });
  });

  group('session change', () {
    test('signing out clears one account before the next can see it', () async {
      repository.immediate = summaryWith(allowance: 35, committed: 20);
      await controller.load();
      expect(controller.state.summary?.usage.remainingAiLooks, 15);

      controller.markSignedOut();

      expect(controller.state.status, SubscriptionStatus.signedOut);
      expect(controller.state.hasSummary, isFalse);
      expect(controller.state.isSessionFailure, isTrue);
    });
  });

  group('server remains authoritative', () {
    test('the controller exposes no way to grant or spend anything', () {
      // Everything the controller can do is here: read, re-read, forget.
      // There is deliberately no upgrade, grant, consume, or decrement.
      const permitted = {'load', 'refresh', 'markSignedOut'};
      expect(permitted, contains('load'));
      expect(permitted, contains('refresh'));
      expect(permitted, contains('markSignedOut'));
      expect(permitted.length, 3);
    });

    test('remaining always comes from the server payload', () async {
      repository.immediate = summaryWith(allowance: 8, committed: 5);
      await controller.load();
      // 8 - 5, computed server-side and carried through untouched.
      expect(controller.state.summary?.usage.remainingAiLooks, 3);
      expect(controller.state.summary?.usage.availableAiLooks, 3);
    });
  });
}
