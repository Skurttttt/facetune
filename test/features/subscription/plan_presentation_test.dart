import 'package:facetune/features/subscription/domain/catalog/subscription_plan_catalog.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/presentation/utils/plan_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlanEmphasis is a presentation contract, not a plan', () {
    test('every plan code resolves to an emphasis', () {
      // Exhaustive by the switch, but pinned so that a new plan code cannot be
      // added without deciding how it is drawn.
      for (final plan in SubscriptionPlanCode.values) {
        expect(PlanPresentation.emphasis(plan), isA<PlanEmphasis>());
      }
    });

    test('exactly one plan is recommended, and it is purchasable', () {
      final recommended = SubscriptionPlanCode.values
          .where(
            (plan) =>
                PlanPresentation.emphasis(plan) == PlanEmphasis.recommended,
          )
          .toList();

      expect(recommended, [SubscriptionPlanCode.plus]);
      expect(PlanPresentation.purchasablePlans, contains(recommended.single));
    });

    test('exactly the two Salon offers are professional, and purchasable', () {
      final professional = SubscriptionPlanCode.values
          .where(
            (plan) =>
                PlanPresentation.emphasis(plan) == PlanEmphasis.professional,
          )
          .toList();

      expect(professional, [
        SubscriptionPlanCode.salonPro,
        SubscriptionPlanCode.salonPreview,
      ]);
      for (final plan in professional) {
        expect(PlanPresentation.purchasablePlans, contains(plan));
      }
    });

    test('sections follow capability, never a hand-written list', () {
      expect(PlanPresentation.plansIn(PaywallSection.tutorial), [
        SubscriptionPlanCode.free,
        SubscriptionPlanCode.plus,
        SubscriptionPlanCode.pro,
      ]);
      expect(PlanPresentation.plansIn(PaywallSection.previewOnly), [
        SubscriptionPlanCode.plusPreview,
        SubscriptionPlanCode.proPreview,
      ]);
      expect(PlanPresentation.plansIn(PaywallSection.professional), [
        SubscriptionPlanCode.salonPro,
        SubscriptionPlanCode.salonPreview,
      ]);
      // Salon Pilot is in no section: it is not on the paywall at all.
      for (final section in PaywallSection.values) {
        expect(
          PlanPresentation.plansIn(section),
          isNot(contains(SubscriptionPlanCode.salonPilot)),
        );
      }
    });

    test('every card states its Tutorial capability in plain words', () {
      for (final plan in PlanPresentation.comparisonPlans) {
        final definition = SubscriptionPlanCatalog.definitionFor(plan);
        final line = PlanPresentation.capabilityLine(plan);
        if (definition.tutorialEnabled) {
          expect(line, contains('Tutorial included'), reason: plan.code);
        } else {
          expect(line, contains('no Tutorial'), reason: plan.code);
          expect(
            PlanPresentation.features(plan),
            contains('Step-by-Step Tutorial not included'),
            reason: plan.code,
          );
          expect(
            PlanPresentation.features(plan).join(' '),
            isNot(contains('Tutorial included')),
            reason: plan.code,
          );
        }
      }
    });

    test('allowance lines name the unit the plan actually counts', () {
      expect(
        PlanPresentation.allowanceLine(SubscriptionPlanCode.plus),
        '3 AI Looks per month',
      );
      expect(
        PlanPresentation.allowanceLine(SubscriptionPlanCode.plusPreview),
        '30 Final Preview Credits per month',
      );
      expect(
        PlanPresentation.allowanceLine(SubscriptionPlanCode.proPreview),
        '80 Final Preview Credits per month',
      );
      expect(
        PlanPresentation.allowanceLine(SubscriptionPlanCode.salonPreview),
        '350 Final Preview Credits per month',
      );
      expect(
        PlanPresentation.allowanceLine(SubscriptionPlanCode.free),
        '1 one-time AI Look',
      );
    });

    test('Free and Pro are drawn plainly', () {
      expect(
        PlanPresentation.emphasis(SubscriptionPlanCode.free),
        PlanEmphasis.standard,
      );
      expect(
        PlanPresentation.emphasis(SubscriptionPlanCode.pro),
        PlanEmphasis.standard,
      );
    });

    test('Salon Pilot is never given a paywall emphasis', () {
      // It is not on the paywall; standard is the only honest answer.
      expect(
        PlanPresentation.emphasis(SubscriptionPlanCode.salonPilot),
        PlanEmphasis.standard,
      );
    });

    test('the emphasis vocabulary carries no plan, price, or allowance', () {
      // Three members, named for weight only. A member named after a plan, a
      // tier, or a price would be a second place plan identity lived.
      expect(PlanEmphasis.values.map((e) => e.name), [
        'standard',
        'recommended',
        'professional',
      ]);
    });
  });
}
