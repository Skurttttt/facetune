import 'package:facetune/features/subscription/domain/entities/billing_provider.dart';
import 'package:facetune/features/subscription/domain/entities/entitlement_status.dart';
import 'package:facetune/features/subscription/domain/entities/reset_policy.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_summary.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_usage_summary.dart';
import 'package:flutter_test/flutter_test.dart';

/// What "the plan this account currently holds" means, read from the server's
/// effective state rather than from the stored status alone.
///
/// The stored status is a historical record moved only by a verified provider
/// read (SUB-11). The server refuses generation on a lapsed verified period
/// regardless, and names why; these getters follow that refusal.
SubscriptionSummary summary({
  bool hasEntitlement = true,
  SubscriptionPlanCode plan = SubscriptionPlanCode.plus,
  EntitlementStatus? status = EntitlementStatus.active,
  bool autoRenew = true,
  String? denialReason,
}) => SubscriptionSummary(
  hasEntitlement: hasEntitlement,
  planCode: plan,
  planDisplayName: 'FaceTune Plus',
  usage: const SubscriptionUsageSummary(
    effectiveAllowance: 3,
    committedUsage: 0,
  ),
  generationAuthorized: hasEntitlement && denialReason == null,
  resolvedAt: DateTime.utc(2026, 9, 19, 12),
  status: hasEntitlement ? status : null,
  billingProvider: BillingProvider.googlePlay,
  resetPolicy: ResetPolicy.billingPeriod,
  autoRenew: autoRenew,
  denialReason: denialReason,
);

void main() {
  group('hasEnded', () {
    test('false while the server authorizes generation', () {
      expect(summary().hasEnded, isFalse);
    });

    test('false when there is no entitlement at all', () {
      expect(
        summary(
          hasEntitlement: false,
          denialReason: 'ENTITLEMENT_NOT_FOUND',
        ).hasEnded,
        isFalse,
      );
    });

    test('true on a lapsed period even while the stored status is active', () {
      expect(
        summary(
          status: EntitlementStatus.active,
          denialReason: 'ENTITLEMENT_EXPIRED',
        ).hasEnded,
        isTrue,
      );
    });

    test('true once a provider read has moved the status too', () {
      expect(
        summary(
          status: EntitlementStatus.expired,
          denialReason: 'ENTITLEMENT_EXPIRED',
        ).hasEnded,
        isTrue,
      );
      expect(
        summary(
          status: EntitlementStatus.revoked,
          denialReason: 'ENTITLEMENT_REVOKED',
        ).hasEnded,
        isTrue,
      );
    });

    test('true when an admin-granted term lapses', () {
      expect(
        summary(
          plan: SubscriptionPlanCode.salonPilot,
          denialReason: 'SALON_PILOT_EXPIRED',
        ).hasEnded,
        isTrue,
      );
    });

    test('refusals that leave the subscription held are not "ended"', () {
      for (final reason in [
        'AI_LOOK_LIMIT_REACHED',
        'ENTITLEMENT_SUSPENDED',
        'ENTITLEMENT_PENDING',
        'ENTITLEMENT_INACTIVE',
      ]) {
        expect(
          summary(denialReason: reason).hasEnded,
          isFalse,
          reason: '$reason must not read as ended',
        );
      }
    });

    test('an unrecognised refusal is not treated as ended', () {
      // A newer backend code is handled as unknown, never mapped onto a known
      // one — so it cannot quietly unlock a repurchase either.
      expect(summary(denialReason: 'SOME_FUTURE_CODE').hasEnded, isFalse);
    });
  });

  group('currentPlan', () {
    test('is the held plan while it is live', () {
      expect(summary().currentPlan, SubscriptionPlanCode.plus);
    });

    test('stays the held plan when cancelled but paid through', () {
      // auto_renew off says nothing about now; the paid period still runs.
      expect(
        summary(autoRenew: false).currentPlan,
        SubscriptionPlanCode.plus,
      );
    });

    test('stays the held plan when merely exhausted', () {
      expect(
        summary(denialReason: 'AI_LOOK_LIMIT_REACHED').currentPlan,
        SubscriptionPlanCode.plus,
      );
    });

    test('is null once the plan has ended', () {
      expect(summary(denialReason: 'ENTITLEMENT_EXPIRED').currentPlan, isNull);
      expect(
        summary(
          status: EntitlementStatus.revoked,
          denialReason: 'ENTITLEMENT_REVOKED',
        ).currentPlan,
        isNull,
      );
    });

    test('is null when nothing is held', () {
      expect(
        summary(
          hasEntitlement: false,
          denialReason: 'ENTITLEMENT_NOT_FOUND',
        ).currentPlan,
        isNull,
      );
    });
  });
}
