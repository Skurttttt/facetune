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

    test('exactly one plan is professional, and it is purchasable', () {
      final professional = SubscriptionPlanCode.values
          .where(
            (plan) =>
                PlanPresentation.emphasis(plan) == PlanEmphasis.professional,
          )
          .toList();

      expect(professional, [SubscriptionPlanCode.salonPro]);
      expect(PlanPresentation.purchasablePlans, contains(professional.single));
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
