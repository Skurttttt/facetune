import 'package:facetune/features/subscription/domain/entities/subscription_allowance.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_usage_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubscriptionAllowance', () {
    test('effective allowance is base plus adjustments', () {
      const allowance = SubscriptionAllowance(
        baseAllowance: 30,
        adjustmentTotal: 10,
      );
      expect(allowance.effectiveAllowance, 40);
      expect(allowance.isAdjusted, isTrue);
    });

    test('an unadjusted allowance is simply its base', () {
      const allowance = SubscriptionAllowance(baseAllowance: 8);
      expect(allowance.effectiveAllowance, 8);
      expect(allowance.isAdjusted, isFalse);
    });

    test('a valid reduction lowers the effective allowance', () {
      const allowance = SubscriptionAllowance(
        baseAllowance: 30,
        adjustmentTotal: -5,
      );
      expect(allowance.effectiveAllowance, 25);
    });

    test('an over-reduction floors at zero rather than going negative', () {
      const allowance = SubscriptionAllowance(
        baseAllowance: 3,
        adjustmentTotal: -10,
      );
      expect(allowance.effectiveAllowance, 0);
    });

    test('a negative base allowance is not constructible', () {
      expect(
        () => SubscriptionAllowance(baseAllowance: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('value equality follows the project convention', () {
      const a = SubscriptionAllowance(baseAllowance: 30, adjustmentTotal: 10);
      const b = SubscriptionAllowance(baseAllowance: 30, adjustmentTotal: 10);
      const c = SubscriptionAllowance(baseAllowance: 40);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      // 30 + 10 and a flat 40 reach the same effective total but are different
      // facts, and must not compare equal.
      expect(a, isNot(c));
    });
  });

  group('SubscriptionUsageSummary', () {
    test('available capacity subtracts committed and reserved usage', () {
      const summary = SubscriptionUsageSummary(
        effectiveAllowance: 8,
        committedUsage: 5,
        reservedUsage: 1,
      );
      expect(summary.availableAiLooks, 2);
    });

    test('user-facing remaining ignores in-flight reservations', () {
      const summary = SubscriptionUsageSummary(
        effectiveAllowance: 3,
        committedUsage: 1,
        reservedUsage: 1,
      );
      // One look is committed and one is being generated right now. The user
      // has 2 of 3 remaining — the in-progress one is not consumed yet — but
      // only 1 is available to start another generation with.
      expect(summary.remainingAiLooks, 2);
      expect(summary.availableAiLooks, 1);
    });

    test('the last AI Look cannot be spent twice', () {
      const beforeReserving = SubscriptionUsageSummary(
        effectiveAllowance: 3,
        committedUsage: 2,
      );
      expect(beforeReserving.availableAiLooks, 1);
      expect(beforeReserving.isExhausted, isFalse);

      const whileReserved = SubscriptionUsageSummary(
        effectiveAllowance: 3,
        committedUsage: 2,
        reservedUsage: 1,
      );
      expect(whileReserved.availableAiLooks, 0);
      expect(whileReserved.isExhausted, isTrue);
      // Still shown as 1 of 3 remaining: the reservation may yet be released.
      expect(whileReserved.remainingAiLooks, 1);
    });

    test('available capacity never goes negative', () {
      const summary = SubscriptionUsageSummary(
        effectiveAllowance: 1,
        committedUsage: 3,
        reservedUsage: 2,
      );
      expect(summary.availableAiLooks, 0);
      expect(summary.availableAiLooks, greaterThanOrEqualTo(0));
    });

    test('user-facing remaining never goes negative', () {
      const summary = SubscriptionUsageSummary(
        effectiveAllowance: 1,
        committedUsage: 4,
      );
      expect(summary.remainingAiLooks, 0);
    });

    test('an exhausted Free entitlement reads as 0 of 1', () {
      const summary = SubscriptionUsageSummary(
        effectiveAllowance: 1,
        committedUsage: 1,
      );
      expect(summary.remainingAiLooks, 0);
      expect(summary.effectiveAllowance, 1);
      expect(summary.isExhausted, isTrue);
    });

    test('a fresh billing period restores the full allowance', () {
      // No rollover: an unused prior period contributes nothing here.
      const newPeriod = SubscriptionUsageSummary(
        effectiveAllowance: 3,
        committedUsage: 0,
      );
      expect(newPeriod.availableAiLooks, 3);
      expect(newPeriod.remainingAiLooks, 3);
    });

    test('reports whether capacity is currently held', () {
      const idle = SubscriptionUsageSummary(
        effectiveAllowance: 8,
        committedUsage: 0,
      );
      const busy = SubscriptionUsageSummary(
        effectiveAllowance: 8,
        committedUsage: 0,
        reservedUsage: 2,
      );
      expect(idle.hasActiveReservations, isFalse);
      expect(busy.hasActiveReservations, isTrue);
    });

    test('negative inputs are not constructible', () {
      expect(
        () =>
            SubscriptionUsageSummary(effectiveAllowance: -1, committedUsage: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () =>
            SubscriptionUsageSummary(effectiveAllowance: 3, committedUsage: -1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => SubscriptionUsageSummary(
          effectiveAllowance: 3,
          committedUsage: 0,
          reservedUsage: -1,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('value equality follows the project convention', () {
      const a = SubscriptionUsageSummary(
        effectiveAllowance: 8,
        committedUsage: 3,
        reservedUsage: 1,
      );
      const b = SubscriptionUsageSummary(
        effectiveAllowance: 8,
        committedUsage: 3,
        reservedUsage: 1,
      );
      const c = SubscriptionUsageSummary(
        effectiveAllowance: 8,
        committedUsage: 4,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
