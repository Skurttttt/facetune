import '../../domain/entities/plan_price.dart';
import '../../domain/entities/subscription_plan_code.dart';
import '../../domain/repositories/plan_price_source.dart';

/// The price source in force until Google Play Billing is wired in SUB-9.
///
/// Returns nothing, so the paywall says it cannot show prices yet instead of
/// inventing them. Substituting the planning baseline here would put a number
/// on screen that nothing verifies and that the store may not charge — exactly
/// the "hardcoded UI price treated as proof of what the user purchased" the
/// pricing rules forbid.
class UnavailablePlanPriceSource implements PlanPriceSource {
  const UnavailablePlanPriceSource();

  @override
  Future<Map<SubscriptionPlanCode, PlanPrice>> loadPrices() async =>
      const <SubscriptionPlanCode, PlanPrice>{};
}
