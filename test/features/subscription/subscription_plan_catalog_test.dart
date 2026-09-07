import 'package:facetune/features/subscription/domain/catalog/subscription_plan_catalog.dart';
import 'package:facetune/features/subscription/domain/entities/reset_policy.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubscriptionPlanCatalog', () {
    test('defines every plan in the controlled vocabulary', () {
      for (final plan in SubscriptionPlanCode.values) {
        expect(
          SubscriptionPlanCatalog.definitionFor(plan).planCode,
          plan,
          reason: 'every plan code needs a definition',
        );
      }
      expect(
        SubscriptionPlanCatalog.all,
        hasLength(SubscriptionPlanCode.values.length),
      );
    });

    test('carries the approved V1 allowances', () {
      int allowanceOf(SubscriptionPlanCode plan) =>
          SubscriptionPlanCatalog.definitionFor(plan).baseAiLookAllowance;

      expect(allowanceOf(SubscriptionPlanCode.free), 1);
      expect(allowanceOf(SubscriptionPlanCode.plus), 3);
      expect(allowanceOf(SubscriptionPlanCode.pro), 8);
      expect(allowanceOf(SubscriptionPlanCode.salonPro), 35);
      expect(allowanceOf(SubscriptionPlanCode.salonPilot), 30);
    });

    test('carries the approved V1 reset policies', () {
      ResetPolicy resetOf(SubscriptionPlanCode plan) =>
          SubscriptionPlanCatalog.definitionFor(plan).resetPolicy;

      expect(resetOf(SubscriptionPlanCode.free), ResetPolicy.none);
      expect(resetOf(SubscriptionPlanCode.plus), ResetPolicy.billingPeriod);
      expect(resetOf(SubscriptionPlanCode.pro), ResetPolicy.billingPeriod);
      expect(resetOf(SubscriptionPlanCode.salonPro), ResetPolicy.billingPeriod);
      expect(resetOf(SubscriptionPlanCode.salonPilot), ResetPolicy.none);
    });

    test('Free never resets, so its one AI Look is genuinely one-time', () {
      final free = SubscriptionPlanCatalog.definitionFor(
        SubscriptionPlanCode.free,
      );
      expect(free.baseAiLookAllowance, 1);
      expect(free.resetPolicy, ResetPolicy.none);
    });

    test('Salon Pilot is a non-renewing grant, not a monthly subscription', () {
      final pilot = SubscriptionPlanCatalog.definitionFor(
        SubscriptionPlanCode.salonPilot,
      );
      expect(pilot.resetPolicy, ResetPolicy.none);
      expect(pilot.publiclyPurchasable, isFalse);
    });

    test('only Plus, Pro and Salon Pro may reach purchase UI', () {
      expect(
        SubscriptionPlanCatalog.publiclyPurchasable
            .map((definition) => definition.planCode)
            .toList(),
        [
          SubscriptionPlanCode.plus,
          SubscriptionPlanCode.pro,
          SubscriptionPlanCode.salonPro,
        ],
      );
    });

    test('public plans are ordered by ascending allowance', () {
      final allowances = SubscriptionPlanCatalog.publiclyPurchasable
          .map((definition) => definition.baseAiLookAllowance)
          .toList();
      final sorted = [...allowances]..sort();
      expect(allowances, sorted);
    });

    test('display names are copy, never identity', () {
      // A plan is resolved by code. Nothing may look a plan up by its label.
      expect(
        SubscriptionPlanCatalog.definitionFor(
          SubscriptionPlanCode.salonPro,
        ).displayName,
        'Salon Pro',
      );
      expect(SubscriptionPlanCode.fromCode('Salon Pro'), isNull);
    });
  });
}
