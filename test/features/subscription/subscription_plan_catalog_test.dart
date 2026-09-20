import 'package:facetune/features/subscription/domain/catalog/subscription_plan_catalog.dart';
import 'package:facetune/features/subscription/domain/entities/allowance_unit.dart';
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

    test('carries the locked allowances', () {
      int allowanceOf(SubscriptionPlanCode plan) =>
          SubscriptionPlanCatalog.definitionFor(plan).baseAllowance;

      expect(allowanceOf(SubscriptionPlanCode.free), 1);
      expect(allowanceOf(SubscriptionPlanCode.plus), 3);
      expect(allowanceOf(SubscriptionPlanCode.plusPreview), 30);
      expect(allowanceOf(SubscriptionPlanCode.pro), 8);
      expect(allowanceOf(SubscriptionPlanCode.proPreview), 80);
      expect(allowanceOf(SubscriptionPlanCode.salonPro), 35);
      expect(allowanceOf(SubscriptionPlanCode.salonPreview), 350);
      expect(allowanceOf(SubscriptionPlanCode.salonPilot), 30);
    });

    test('carries the locked allowance units and Tutorial capability', () {
      // Tutorial-enabled plans count AI Looks; Preview-only plans count Final
      // Preview Credits and never include the Tutorial. Free and Salon Pilot
      // keep their approved V1 behaviour.
      for (final plan in [
        SubscriptionPlanCode.free,
        SubscriptionPlanCode.plus,
        SubscriptionPlanCode.pro,
        SubscriptionPlanCode.salonPro,
        SubscriptionPlanCode.salonPilot,
      ]) {
        final definition = SubscriptionPlanCatalog.definitionFor(plan);
        expect(
          definition.allowanceUnit,
          AllowanceUnit.aiLook,
          reason: plan.code,
        );
        expect(definition.tutorialEnabled, isTrue, reason: plan.code);
      }
      for (final plan in [
        SubscriptionPlanCode.plusPreview,
        SubscriptionPlanCode.proPreview,
        SubscriptionPlanCode.salonPreview,
      ]) {
        final definition = SubscriptionPlanCatalog.definitionFor(plan);
        expect(
          definition.allowanceUnit,
          AllowanceUnit.finalPreviewCredit,
          reason: plan.code,
        );
        expect(definition.tutorialEnabled, isFalse, reason: plan.code);
        expect(definition.resetPolicy, ResetPolicy.billingPeriod);
        expect(definition.publiclyPurchasable, isTrue);
      }
    });

    test(
      'a Preview-only sibling is never told apart from its pair by price',
      () {
        // Nothing in the definition carries a price. The pairs differ in unit,
        // allowance and capability, and in the store product behind them.
        for (final (tutorial, preview) in [
          (SubscriptionPlanCode.plus, SubscriptionPlanCode.plusPreview),
          (SubscriptionPlanCode.pro, SubscriptionPlanCode.proPreview),
          (SubscriptionPlanCode.salonPro, SubscriptionPlanCode.salonPreview),
        ]) {
          final a = SubscriptionPlanCatalog.definitionFor(tutorial);
          final b = SubscriptionPlanCatalog.definitionFor(preview);
          expect(a.allowanceUnit, isNot(b.allowanceUnit));
          expect(a.tutorialEnabled, isNot(b.tutorialEnabled));
          expect(b.baseAllowance, greaterThan(a.baseAllowance));
        }
      },
    );

    test('carries the approved reset policies', () {
      ResetPolicy resetOf(SubscriptionPlanCode plan) =>
          SubscriptionPlanCatalog.definitionFor(plan).resetPolicy;

      expect(resetOf(SubscriptionPlanCode.free), ResetPolicy.none);
      expect(resetOf(SubscriptionPlanCode.plus), ResetPolicy.billingPeriod);
      expect(
        resetOf(SubscriptionPlanCode.plusPreview),
        ResetPolicy.billingPeriod,
      );
      expect(resetOf(SubscriptionPlanCode.pro), ResetPolicy.billingPeriod);
      expect(
        resetOf(SubscriptionPlanCode.proPreview),
        ResetPolicy.billingPeriod,
      );
      expect(resetOf(SubscriptionPlanCode.salonPro), ResetPolicy.billingPeriod);
      expect(
        resetOf(SubscriptionPlanCode.salonPreview),
        ResetPolicy.billingPeriod,
      );
      expect(resetOf(SubscriptionPlanCode.salonPilot), ResetPolicy.none);
    });

    test('Free never resets, so its one AI Look is genuinely one-time', () {
      final free = SubscriptionPlanCatalog.definitionFor(
        SubscriptionPlanCode.free,
      );
      expect(free.baseAllowance, 1);
      expect(free.resetPolicy, ResetPolicy.none);
    });

    test('Salon Pilot is a non-renewing grant, not a monthly subscription', () {
      final pilot = SubscriptionPlanCatalog.definitionFor(
        SubscriptionPlanCode.salonPilot,
      );
      expect(pilot.resetPolicy, ResetPolicy.none);
      expect(pilot.publiclyPurchasable, isFalse);
    });

    test('only the six store plans may reach purchase UI', () {
      expect(
        SubscriptionPlanCatalog.publiclyPurchasable
            .map((definition) => definition.planCode)
            .toList(),
        [
          SubscriptionPlanCode.plus,
          SubscriptionPlanCode.plusPreview,
          SubscriptionPlanCode.pro,
          SubscriptionPlanCode.proPreview,
          SubscriptionPlanCode.salonPro,
          SubscriptionPlanCode.salonPreview,
        ],
      );
    });

    test('public plans ascend in allowance within each unit', () {
      for (final unit in AllowanceUnit.values) {
        final allowances = SubscriptionPlanCatalog.publiclyPurchasable
            .where((definition) => definition.allowanceUnit == unit)
            .map((definition) => definition.baseAllowance)
            .toList();
        final sorted = [...allowances]..sort();
        expect(allowances, sorted, reason: unit.code);
      }
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
