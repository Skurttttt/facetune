import 'package:facetune/features/subscription/domain/entities/ai_look_operation_id.dart';
import 'package:facetune/features/subscription/domain/entities/billing_provider.dart';
import 'package:facetune/features/subscription/domain/entities/entitlement_status.dart';
import 'package:facetune/features/subscription/domain/entities/generation_authorization.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_allowance.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_entitlement.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_period.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_error_code.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubscriptionPeriod', () {
    test('a recurring billing period carries period_start/period_end', () {
      final period = RecurringBillingPeriod(
        periodStart: DateTime.utc(2026, 9, 7),
        periodEnd: DateTime.utc(2026, 10, 7),
      );
      expect(period.periodStart, DateTime.utc(2026, 9, 7));
      expect(period.periodEnd, DateTime.utc(2026, 10, 7));
      expect(period.startedAt, period.periodStart);
    });

    test('an admin grant carries starts_at/expires_at and must expire', () {
      final period = AdminGrantedPeriod(
        startsAt: DateTime.utc(2026, 9, 7),
        expiresAt: DateTime.utc(2026, 12, 7),
      );
      expect(period.startsAt, DateTime.utc(2026, 9, 7));
      expect(period.expiresAt, DateTime.utc(2026, 12, 7));
      expect(period.startedAt, period.startsAt);
    });

    test('Free is perpetual, with no end date to renew or reset', () {
      final period = PerpetualPeriod(startsAt: DateTime.utc(2026, 9, 7));
      expect(period.startedAt, DateTime.utc(2026, 9, 7));
    });

    test('the two date pairs are not interchangeable types', () {
      final recurring = RecurringBillingPeriod(
        periodStart: DateTime.utc(2026, 9, 7),
        periodEnd: DateTime.utc(2026, 10, 7),
      );
      final granted = AdminGrantedPeriod(
        startsAt: DateTime.utc(2026, 9, 7),
        expiresAt: DateTime.utc(2026, 10, 7),
      );
      expect(recurring, isNot(isA<AdminGrantedPeriod>()));
      expect(granted, isNot(isA<RecurringBillingPeriod>()));
      // Identical instants, different meanings — never equal.
      expect(recurring, isNot(granted));
    });

    test('matching is exhaustive over the sealed hierarchy', () {
      String describe(SubscriptionPeriod period) => switch (period) {
        RecurringBillingPeriod() => 'recurring',
        AdminGrantedPeriod() => 'granted',
        PerpetualPeriod() => 'perpetual',
      };

      expect(
        describe(
          RecurringBillingPeriod(
            periodStart: DateTime.utc(2026, 9, 7),
            periodEnd: DateTime.utc(2026, 10, 7),
          ),
        ),
        'recurring',
      );
      expect(
        describe(
          AdminGrantedPeriod(
            startsAt: DateTime.utc(2026, 9, 7),
            expiresAt: DateTime.utc(2026, 10, 7),
          ),
        ),
        'granted',
      );
      expect(
        describe(PerpetualPeriod(startsAt: DateTime.utc(2026, 9, 7))),
        'perpetual',
      );
    });

    test('value equality follows the project convention', () {
      final a = RecurringBillingPeriod(
        periodStart: DateTime.utc(2026, 9, 7),
        periodEnd: DateTime.utc(2026, 10, 7),
      );
      final b = RecurringBillingPeriod(
        periodStart: DateTime.utc(2026, 9, 7),
        periodEnd: DateTime.utc(2026, 10, 7),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('SubscriptionEntitlement', () {
    test('represents a recurring Pro subscription', () {
      final entitlement = SubscriptionEntitlement(
        id: 'e1',
        userId: 'u1',
        planCode: SubscriptionPlanCode.pro,
        status: EntitlementStatus.active,
        billingProvider: BillingProvider.googlePlay,
        period: RecurringBillingPeriod(
          periodStart: DateTime.utc(2026, 9, 7),
          periodEnd: DateTime.utc(2026, 10, 7),
        ),
        allowance: const SubscriptionAllowance(baseAllowance: 8),
        autoRenew: true,
        providerProductId: 'facetune_pro_monthly',
        verifiedAt: DateTime.utc(2026, 9, 7, 12),
      );

      expect(entitlement.planCode, SubscriptionPlanCode.pro);
      expect(entitlement.allowance.effectiveAllowance, 8);
      expect(entitlement.period, isA<RecurringBillingPeriod>());
    });

    test('represents an adjusted Salon Pilot grant', () {
      final entitlement = SubscriptionEntitlement(
        id: 'e2',
        userId: 'u2',
        planCode: SubscriptionPlanCode.salonPilot,
        status: EntitlementStatus.active,
        billingProvider: BillingProvider.adminGranted,
        period: AdminGrantedPeriod(
          startsAt: DateTime.utc(2026, 9, 7),
          expiresAt: DateTime.utc(2026, 12, 7),
        ),
        allowance: const SubscriptionAllowance(
          baseAllowance: 30,
          adjustmentTotal: 10,
        ),
        autoRenew: false,
      );

      // The entitlement's own allowance outranks the plan's default of 30.
      expect(entitlement.allowance.effectiveAllowance, 40);
      expect(entitlement.autoRenew, isFalse);
      expect(entitlement.providerProductId, isNull);
      expect(entitlement.verifiedAt, isNull);
    });

    test('represents the complimentary Free entitlement', () {
      final entitlement = SubscriptionEntitlement(
        id: 'e3',
        userId: 'u3',
        planCode: SubscriptionPlanCode.free,
        status: EntitlementStatus.active,
        billingProvider: BillingProvider.none,
        period: PerpetualPeriod(startsAt: DateTime.utc(2026, 9, 7)),
        allowance: const SubscriptionAllowance(baseAllowance: 1),
        autoRenew: false,
      );

      expect(entitlement.billingProvider, BillingProvider.none);
      expect(entitlement.period, isA<PerpetualPeriod>());
      expect(entitlement.allowance.effectiveAllowance, 1);
    });

    test(
      'a cancelled subscription is still entitled until its period ends',
      () {
        final entitlement = SubscriptionEntitlement(
          id: 'e4',
          userId: 'u4',
          planCode: SubscriptionPlanCode.plus,
          status: EntitlementStatus.active,
          billingProvider: BillingProvider.googlePlay,
          period: RecurringBillingPeriod(
            periodStart: DateTime.utc(2026, 9, 7),
            periodEnd: DateTime.utc(2026, 10, 7),
          ),
          allowance: const SubscriptionAllowance(baseAllowance: 3),
          // Cancelled at the provider, so it will not renew...
          autoRenew: false,
        );
        // ...but the entitlement itself is still active.
        expect(entitlement.status.permitsNewAiLooks, isTrue);
      },
    );
  });

  group('AiLookOperationId', () {
    const valid = '3f2504e0-4f89-11d3-9a0c-0305e82c3301';

    test('parses and normalizes a valid operation identity', () {
      expect(AiLookOperationId.parse(valid).value, valid);
      expect(
        AiLookOperationId.parse(valid.toUpperCase()).value,
        valid,
        reason: 'case must not create two identities for one operation',
      );
      expect(AiLookOperationId.parse('  $valid  ').value, valid);
    });

    test('equal ids are the same operation', () {
      expect(
        AiLookOperationId.parse(valid),
        AiLookOperationId.parse(valid.toUpperCase()),
      );
      expect(
        AiLookOperationId.parse(valid).hashCode,
        AiLookOperationId.parse(valid.toUpperCase()).hashCode,
      );
    });

    test('rejects user content and private paths as keys', () {
      const rejected = [
        '',
        'operation-1',
        'user@example.com',
        'u1/analyses/a1/generated/r1/preview_0001.png',
        '3f2504e0-4f89-11d3-9a0c-0305e82c3301-extra',
        'not-a-uuid',
      ];
      for (final input in rejected) {
        expect(
          AiLookOperationId.tryParse(input),
          isNull,
          reason: '"$input" must not be usable as an idempotency key',
        );
        expect(AiLookOperationId.isValid(input), isFalse);
        expect(
          () => AiLookOperationId.parse(input),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test('never echoes the rejected value back', () {
      try {
        AiLookOperationId.parse('u1/analyses/a1/original/secret.jpg');
        fail('expected a FormatException');
      } on FormatException catch (error) {
        expect(error.toString(), isNot(contains('secret')));
        expect(error.toString(), isNot(contains('analyses')));
      }
    });
  });

  group('GenerationAuthorization', () {
    test('an authorization carries the capacity it was granted against', () {
      const decision = GenerationAuthorized(availableAiLooks: 2);
      expect(decision.isAuthorized, isTrue);
      expect(decision.availableAiLooks, 2);
    });

    test('authorizing with no capacity is not constructible', () {
      expect(
        () => GenerationAuthorized(availableAiLooks: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a denial carries a reason, not just a false flag', () {
      const decision = GenerationDenied(
        SubscriptionErrorCode.aiLookLimitReached,
      );
      expect(decision.isAuthorized, isFalse);
      expect(decision.reason, SubscriptionErrorCode.aiLookLimitReached);
    });

    test('matching is exhaustive and distinguishes capacity from access', () {
      String prompt(GenerationAuthorization decision) => switch (decision) {
        GenerationAuthorized() => 'generate',
        GenerationDenied(reason: SubscriptionErrorCode.aiLookLimitReached) =>
          'upgrade',
        GenerationDenied() => 'explain',
      };

      expect(
        prompt(const GenerationAuthorized(availableAiLooks: 1)),
        'generate',
      );
      expect(
        prompt(
          const GenerationDenied(SubscriptionErrorCode.aiLookLimitReached),
        ),
        'upgrade',
      );
      // A suspended entitlement must not be sold an upgrade.
      expect(
        prompt(
          const GenerationDenied(SubscriptionErrorCode.entitlementSuspended),
        ),
        'explain',
      );
    });

    test('value equality follows the project convention', () {
      expect(
        const GenerationDenied(SubscriptionErrorCode.entitlementExpired),
        const GenerationDenied(SubscriptionErrorCode.entitlementExpired),
      );
      expect(
        const GenerationDenied(SubscriptionErrorCode.entitlementExpired),
        isNot(const GenerationDenied(SubscriptionErrorCode.entitlementRevoked)),
      );
    });
  });

  group('SubscriptionFailure', () {
    test('carries a controlled code, display copy, and retryability', () {
      const failure = SubscriptionFailure(
        SubscriptionErrorCode.temporaryBackendFailure,
        'Please try again shortly.',
        retryable: true,
      );
      expect(failure.code, SubscriptionErrorCode.temporaryBackendFailure);
      expect(failure.message, 'Please try again shortly.');
      expect(failure.retryable, isTrue);
      expect(failure, isA<Exception>());
    });

    test('defaults to not retryable', () {
      const failure = SubscriptionFailure(
        SubscriptionErrorCode.aiLookLimitReached,
        'You have used all of your AI Looks.',
      );
      expect(failure.retryable, isFalse);
    });
  });
}
