import 'package:facetune/features/subscription/data/models/subscription_summary_dto.dart';
import 'package:facetune/features/subscription/domain/entities/billing_provider.dart';
import 'package:facetune/features/subscription/domain/entities/entitlement_status.dart';
import 'package:facetune/features/subscription/domain/entities/reset_policy.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// Payloads shaped exactly as `resolve_subscription_state()` returns them.
/// The values are the ones observed from the live function during SUB-3.
Map<String, Object?> payload({
  String planCode = 'plus',
  String? status = 'active',
  bool hasEntitlement = true,
  String displayName = 'FaceTune Plus',
  String billingProvider = 'google_play',
  String resetPolicy = 'billing_period',
  int effectiveAllowance = 3,
  int committedUsage = 0,
  int reservedUsage = 0,
  bool generationAuthorized = true,
  String? denialReason,
  String? periodEnd = '2026-10-07T00:00:00Z',
  String? resetAt = '2026-10-07T00:00:00Z',
  String? expiresAt,
  bool autoRenew = true,
}) => {
  'hasEntitlement': hasEntitlement,
  'entitlementId': 'e1000000-0000-4000-8000-000000000003',
  'planCode': planCode,
  'planDisplayName': displayName,
  'entitlementStatus': status,
  'billingProvider': billingProvider,
  'resetPolicy': resetPolicy,
  'periodStart': '2026-09-07T00:00:00Z',
  'periodEnd': periodEnd,
  'startsAt': '2026-09-07T00:00:00Z',
  'expiresAt': expiresAt,
  'resetAt': resetAt,
  'autoRenew': autoRenew,
  'baseAllowance': effectiveAllowance,
  'allowanceAdjustmentTotal': 0,
  'effectiveAllowance': effectiveAllowance,
  'committedUsage': committedUsage,
  'reservedUsage': reservedUsage,
  'availableAiLooks': effectiveAllowance - committedUsage - reservedUsage,
  'remainingAiLooks': effectiveAllowance - committedUsage,
  'generationAuthorized': generationAuthorized,
  'denialReason': denialReason,
  'resolvedAt': '2026-09-07T12:00:00Z',
};

void main() {
  group('plan mapping', () {
    test('Free maps with a one-time allowance that never resets', () {
      final summary = SubscriptionSummaryDto.fromResponse(
        payload(
          planCode: 'free',
          displayName: 'FaceTune Free',
          billingProvider: 'none',
          resetPolicy: 'none',
          effectiveAllowance: 1,
          periodEnd: null,
          resetAt: null,
          autoRenew: false,
        ),
      );

      expect(summary.planCode, SubscriptionPlanCode.free);
      expect(summary.planDisplayName, 'FaceTune Free');
      expect(summary.billingProvider, BillingProvider.none);
      expect(summary.resetPolicy, ResetPolicy.none);
      expect(summary.replenishes, isFalse);
      expect(summary.resetAt, isNull);
      expect(summary.usage.effectiveAllowance, 1);
      expect(summary.usage.remainingAiLooks, 1);
    });

    test('Plus maps with 3 per verified billing period', () {
      final summary = SubscriptionSummaryDto.fromResponse(payload());

      expect(summary.planCode, SubscriptionPlanCode.plus);
      expect(summary.billingProvider, BillingProvider.googlePlay);
      expect(summary.resetPolicy, ResetPolicy.billingPeriod);
      expect(summary.replenishes, isTrue);
      expect(summary.usage.effectiveAllowance, 3);
      expect(summary.resetAt, DateTime.utc(2026, 10, 7));
      expect(summary.autoRenew, isTrue);
    });

    test('Pro maps with 8', () {
      final summary = SubscriptionSummaryDto.fromResponse(
        payload(
          planCode: 'pro',
          displayName: 'FaceTune Pro',
          effectiveAllowance: 8,
        ),
      );
      expect(summary.planCode, SubscriptionPlanCode.pro);
      expect(summary.usage.effectiveAllowance, 8);
    });

    test('Salon Pro maps with 35', () {
      final summary = SubscriptionSummaryDto.fromResponse(
        payload(
          planCode: 'salon_pro',
          displayName: 'Salon Pro',
          effectiveAllowance: 35,
        ),
      );
      expect(summary.planCode, SubscriptionPlanCode.salonPro);
      expect(summary.usage.effectiveAllowance, 35);
    });

    test('Salon Pilot maps as an admin grant with an expiry', () {
      final summary = SubscriptionSummaryDto.fromResponse(
        payload(
          planCode: 'salon_pilot',
          displayName: 'Salon Pilot',
          billingProvider: 'admin_granted',
          resetPolicy: 'none',
          // An adjusted grant: 30 base plus 10.
          effectiveAllowance: 40,
          periodEnd: null,
          resetAt: null,
          expiresAt: '2026-12-07T00:00:00Z',
          autoRenew: false,
        ),
      );

      expect(summary.planCode, SubscriptionPlanCode.salonPilot);
      expect(summary.billingProvider, BillingProvider.adminGranted);
      expect(summary.usage.effectiveAllowance, 40);
      expect(summary.expiresAt, DateTime.utc(2026, 12, 7));
      expect(summary.resetAt, isNull);
      expect(summary.autoRenew, isFalse);
    });
  });

  group('capacity is carried from the server, not recomputed', () {
    test('reserved usage reduces available but not remaining', () {
      final summary = SubscriptionSummaryDto.fromResponse(
        payload(effectiveAllowance: 3, committedUsage: 2, reservedUsage: 1),
      );
      expect(summary.usage.committedUsage, 2);
      expect(summary.usage.reservedUsage, 1);
      expect(summary.usage.availableAiLooks, 0);
      expect(summary.usage.remainingAiLooks, 1);
      expect(summary.usage.isExhausted, isTrue);
    });

    test('an exhausted plan carries the denial reason', () {
      final summary = SubscriptionSummaryDto.fromResponse(
        payload(
          planCode: 'free',
          billingProvider: 'none',
          resetPolicy: 'none',
          effectiveAllowance: 1,
          committedUsage: 1,
          generationAuthorized: false,
          denialReason: 'AI_LOOK_LIMIT_REACHED',
          periodEnd: null,
          resetAt: null,
          autoRenew: false,
        ),
      );
      expect(summary.generationAuthorized, isFalse);
      expect(summary.denialReason, 'AI_LOOK_LIMIT_REACHED');
      expect(summary.usage.remainingAiLooks, 0);
    });

    test('a blocked entitlement is not authorized despite having capacity', () {
      final summary = SubscriptionSummaryDto.fromResponse(
        payload(
          planCode: 'pro',
          status: 'suspended',
          effectiveAllowance: 8,
          generationAuthorized: false,
          denialReason: 'ENTITLEMENT_SUSPENDED',
        ),
      );
      // Capacity remains, but access does not — the two are independent, and
      // the client must not infer one from the other.
      expect(summary.usage.availableAiLooks, 8);
      expect(summary.generationAuthorized, isFalse);
      expect(summary.status, EntitlementStatus.suspended);
    });

    test('a malformed negative count is clamped rather than crashing', () {
      final summary = SubscriptionSummaryDto.fromResponse(
        payload()..['committedUsage'] = -5,
      );
      expect(summary.usage.committedUsage, 0);
    });

    test('a numeric count from a JSON decoder is accepted', () {
      final summary = SubscriptionSummaryDto.fromResponse(
        payload()..['effectiveAllowance'] = 8.0,
      );
      expect(summary.usage.effectiveAllowance, 8);
    });
  });

  group('no entitlement', () {
    test('is reported as absent, not as a Free grant', () {
      final summary = SubscriptionSummaryDto.fromResponse({
        'hasEntitlement': false,
        'planCode': 'free',
        'planDisplayName': 'FaceTune Free',
        'entitlementStatus': null,
        'billingProvider': 'none',
        'resetPolicy': 'none',
        'baseAllowance': 1,
        'effectiveAllowance': 0,
        'committedUsage': 0,
        'reservedUsage': 0,
        'availableAiLooks': 0,
        'remainingAiLooks': 0,
        'generationAuthorized': false,
        'denialReason': 'ENTITLEMENT_NOT_FOUND',
        'resolvedAt': '2026-09-07T12:00:00Z',
      });

      expect(summary.hasEntitlement, isFalse);
      expect(summary.status, isNull);
      // The plan code is a label; the allowance is what was actually granted.
      expect(summary.usage.effectiveAllowance, 0);
      expect(summary.generationAuthorized, isFalse);
      expect(summary.denialReason, 'ENTITLEMENT_NOT_FOUND');
    });
  });

  group('unrecognised identity is rejected, never coerced', () {
    test('an unknown plan code throws', () {
      expect(
        () => SubscriptionSummaryDto.fromResponse(payload(planCode: 'premium')),
        throwsA(isA<FormatException>()),
      );
    });

    test('an unknown status throws rather than becoming active', () {
      expect(
        () => SubscriptionSummaryDto.fromResponse(payload(status: 'whatever')),
        throwsA(isA<FormatException>()),
      );
    });

    test('an unknown billing provider throws', () {
      expect(
        () => SubscriptionSummaryDto.fromResponse(
          payload(billingProvider: 'stripe'),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('a malformed payload throws', () {
      expect(
        () => SubscriptionSummaryDto.fromResponse('not a map'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SubscriptionSummaryDto.fromResponse(null),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
