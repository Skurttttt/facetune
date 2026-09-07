import 'package:facetune/features/subscription/domain/entities/billing_provider.dart';
import 'package:facetune/features/subscription/domain/entities/entitlement_status.dart';
import 'package:facetune/features/subscription/domain/entities/purchase_lifecycle_status.dart';
import 'package:facetune/features/subscription/domain/entities/reset_policy.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/entities/usage_status.dart';
import 'package:facetune/features/subscription/domain/entities/usage_type.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_error_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every identifier crossing the Flutter/backend/Web Admin boundary is pinned
/// here. These are not "does the enum work" tests — they are the contract. A
/// renamed code silently breaks a system this repository cannot compile, so the
/// literal strings are asserted rather than derived.
void main() {
  group('SubscriptionPlanCode', () {
    test('serializes exactly the five canonical plan codes', () {
      expect(SubscriptionPlanCode.free.code, 'free');
      expect(SubscriptionPlanCode.plus.code, 'plus');
      expect(SubscriptionPlanCode.pro.code, 'pro');
      expect(SubscriptionPlanCode.salonPro.code, 'salon_pro');
      expect(SubscriptionPlanCode.salonPilot.code, 'salon_pilot');
    });

    test('has no members beyond the canonical five', () {
      expect(SubscriptionPlanCode.values.map((plan) => plan.code).toSet(), {
        'free',
        'plus',
        'pro',
        'salon_pro',
        'salon_pilot',
      });
    });

    test('round-trips every code', () {
      for (final plan in SubscriptionPlanCode.values) {
        expect(SubscriptionPlanCode.fromCode(plan.code), plan);
      }
    });

    test('rejects the forbidden substitute identifiers', () {
      const forbidden = [
        'premium',
        'premium_plus',
        'professional',
        'salon',
        'salon_test',
        'salon_research',
        'research_salon',
        'salon_trial',
      ];
      for (final code in forbidden) {
        expect(
          SubscriptionPlanCode.fromCode(code),
          isNull,
          reason: '"$code" is not an approved plan code',
        );
      }
    });

    test('rejects near-misses rather than coercing them', () {
      for (final code in ['', ' free', 'FREE', 'Salon_Pro', 'salonpro']) {
        expect(SubscriptionPlanCode.fromCode(code), isNull);
      }
    });
  });

  group('EntitlementStatus', () {
    test('serializes exactly the six canonical statuses', () {
      expect(EntitlementStatus.values.map((status) => status.code).toSet(), {
        'pending',
        'active',
        'grace_period',
        'expired',
        'suspended',
        'revoked',
      });
    });

    test('round-trips every code', () {
      for (final status in EntitlementStatus.values) {
        expect(EntitlementStatus.fromCode(status.code), status);
      }
    });

    test('rejects invented statuses', () {
      for (final code in [
        'disabled',
        'blocked',
        'premium_off',
        'inactive',
        'cancelled_entitlement',
        'bad',
      ]) {
        expect(EntitlementStatus.fromCode(code), isNull);
      }
    });

    test('only active and grace_period are entitled states', () {
      expect(EntitlementStatus.active.permitsNewAiLooks, isTrue);
      expect(EntitlementStatus.gracePeriod.permitsNewAiLooks, isTrue);
      expect(EntitlementStatus.pending.permitsNewAiLooks, isFalse);
      expect(EntitlementStatus.expired.permitsNewAiLooks, isFalse);
      expect(EntitlementStatus.suspended.permitsNewAiLooks, isFalse);
      expect(EntitlementStatus.revoked.permitsNewAiLooks, isFalse);
    });
  });

  group('UsageStatus', () {
    test('serializes exactly reserved, committed, released', () {
      expect(UsageStatus.values.map((status) => status.code).toSet(), {
        'reserved',
        'committed',
        'released',
      });
    });

    test('round-trips every code', () {
      for (final status in UsageStatus.values) {
        expect(UsageStatus.fromCode(status.code), status);
      }
    });

    test('rejects vague states', () {
      for (final code in [
        'used',
        'done',
        'finished',
        'failed_charge',
        'cancelled_usage',
      ]) {
        expect(UsageStatus.fromCode(code), isNull);
      }
    });

    test('reserved and committed hold capacity; released returns it', () {
      expect(UsageStatus.reserved.consumesAvailableCapacity, isTrue);
      expect(UsageStatus.committed.consumesAvailableCapacity, isTrue);
      expect(UsageStatus.released.consumesAvailableCapacity, isFalse);
    });
  });

  group('UsageType', () {
    test('V1 has exactly one user-facing billable type', () {
      expect(UsageType.values, [UsageType.finalMakeupPreview]);
      expect(UsageType.finalMakeupPreview.code, 'final_makeup_preview');
    });

    test('rejects types that must not become AI Look deductions', () {
      for (final code in [
        'tutorial',
        'manifest',
        'analysis',
        'recommendation',
        'makeup_kit',
      ]) {
        expect(
          UsageType.fromCode(code),
          isNull,
          reason: '"$code" must not be a user-facing billable unit in V1',
        );
      }
    });
  });

  group('BillingProvider', () {
    test('serializes exactly the four canonical provider codes', () {
      expect(BillingProvider.values.map((p) => p.code).toSet(), {
        'none',
        'google_play',
        'apple_app_store',
        'admin_granted',
      });
    });

    test('round-trips every code', () {
      for (final provider in BillingProvider.values) {
        expect(BillingProvider.fromCode(provider.code), provider);
      }
    });
  });

  group('PurchaseLifecycleStatus', () {
    test('is a separate vocabulary from EntitlementStatus', () {
      expect(PurchaseLifecycleStatus.values.map((s) => s.code).toSet(), {
        'pending',
        'purchased',
        'renewed',
        'cancelled',
        'expired',
        'refunded',
        'revoked',
      });
      // `cancelled` exists here and deliberately has no entitlement
      // counterpart: a cancelled subscription is not an expired one.
      expect(EntitlementStatus.fromCode('cancelled'), isNull);
      expect(PurchaseLifecycleStatus.fromCode('grace_period'), isNull);
    });

    test('round-trips every code', () {
      for (final status in PurchaseLifecycleStatus.values) {
        expect(PurchaseLifecycleStatus.fromCode(status.code), status);
      }
    });
  });

  group('ResetPolicy', () {
    test('serializes exactly none and billing_period', () {
      expect(ResetPolicy.values.map((policy) => policy.code).toSet(), {
        'none',
        'billing_period',
      });
    });

    test('round-trips every code', () {
      for (final policy in ResetPolicy.values) {
        expect(ResetPolicy.fromCode(policy.code), policy);
      }
    });
  });

  group('SubscriptionErrorCode', () {
    test('covers the shared sanitized error vocabulary', () {
      final codes = SubscriptionErrorCode.values.map((e) => e.code).toSet();
      expect(
        codes,
        containsAll(<String>[
          'AUTH_REQUIRED',
          'ADMIN_UNAUTHORIZED',
          'ENTITLEMENT_NOT_FOUND',
          'ENTITLEMENT_PENDING',
          'ENTITLEMENT_INACTIVE',
          'ENTITLEMENT_EXPIRED',
          'ENTITLEMENT_SUSPENDED',
          'ENTITLEMENT_REVOKED',
          'AI_LOOK_LIMIT_REACHED',
          'AI_LOOK_RESERVATION_CONFLICT',
          'USAGE_OPERATION_NOT_FOUND',
          'USAGE_ALREADY_COMMITTED',
          'USAGE_ALREADY_RELEASED',
          'USAGE_STATE_CONFLICT',
          'INVALID_PLAN_CODE',
          'INVALID_ENTITLEMENT_TRANSITION',
          'INVALID_ALLOWANCE_ADJUSTMENT',
          'ALLOWANCE_BELOW_COMMITTED_USAGE',
          'ALLOWANCE_CONFLICTS_WITH_ACTIVE_RESERVATION',
          'SALON_PILOT_ALREADY_GRANTED',
          'SALON_PILOT_EXPIRED',
          'PURCHASE_VERIFICATION_FAILED',
          'PROVIDER_STATE_CONFLICT',
          'IDEMPOTENCY_CONFLICT',
          'CONCURRENT_MODIFICATION',
          'TEMPORARY_BACKEND_FAILURE',
        ]),
      );
    });

    test('round-trips every code and rejects unknown ones', () {
      for (final code in SubscriptionErrorCode.values) {
        expect(SubscriptionErrorCode.fromCode(code.code), code);
      }
      expect(SubscriptionErrorCode.fromCode('SOMETHING_NEW'), isNull);
    });
  });
}
