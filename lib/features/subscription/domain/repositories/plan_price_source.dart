import '../entities/plan_price.dart';
import '../entities/subscription_plan_code.dart';

/// Supplies localized prices for the publicly purchasable plans.
///
/// This exists so the paywall has exactly one place prices can come from, and
/// that place is the billing provider. The approved business baseline lives in
/// the Subscription Source of Truth as a *planning* figure; what a user is
/// actually charged is whatever the store says in their region, and only the
/// store can say it.
///
/// Backed by Google Play (`GooglePlayPlanPriceSource`). When the store is
/// unreachable, or has no product configured for a plan, the answer is simply
/// absent: the paywall handles that honestly rather than substituting a
/// literal, because a hardcoded price that disagrees with the store is worse
/// than no price — the user would believe it.
abstract interface class PlanPriceSource {
  /// Prices keyed by plan, omitting any the provider did not return.
  ///
  /// An empty map means "no prices are available", never "these plans are
  /// free".
  Future<Map<SubscriptionPlanCode, PlanPrice>> loadPrices();
}
