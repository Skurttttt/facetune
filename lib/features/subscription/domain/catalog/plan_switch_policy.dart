import '../entities/subscription_plan_code.dart';

/// How a purchase of [PlanSwitch.to] must be started when the account already
/// holds an active store subscription for [PlanSwitch.from].
///
/// A provider will happily sell a second, independent subscription beside the
/// one an account already has. Google Play in particular only *replaces* a
/// subscription when the purchase request says which purchase it replaces and
/// how; without that it reports both as active, and the server — which retires
/// whichever live entitlement it did not just verify — then alternates between
/// them on every verification. So the kind of switch is decided here, once, and
/// the billing layer starts the purchase the way the kind requires.
enum PlanSwitchKind {
  /// The account already holds this exact product. Nothing to buy; the
  /// purchase should be restored rather than repeated.
  samePlan,

  /// An approved switch between a plan and its Preview-only sibling.
  ///
  /// Locked for V1 by the Subscription Expansion Source of Truth: the two
  /// products share a price, the switch takes effect immediately, the billing
  /// cycle is kept, and nothing further is charged now. The billing layer
  /// expresses this as an immediate replacement *without proration*.
  equalPriceReplacement,

  /// A switch whose commercial terms have not been approved.
  ///
  /// Every cross-tier change is one of these. Source of Truth §38: no
  /// proration rule may be invented in the client, and an unsupported
  /// upgrade/downgrade path must not be exposed merely because the pricing UI
  /// shows several cards. The billing layer refuses to start these rather than
  /// guess a replacement mode or, worse, sell a second subscription.
  unapproved,
}

/// The approved plan-switch policy.
///
/// Deliberately a closed table rather than a rule such as "same price": Plus
/// and Plus Preview sharing a price is a business decision, and inferring the
/// switch policy from prices would silently approve a new switch the day two
/// unrelated plans happened to cost the same.
abstract final class PlanSwitchPolicy {
  /// The unordered pairs approved as immediate equal-price replacements.
  static const List<Set<SubscriptionPlanCode>> _equalPricePairs = [
    {SubscriptionPlanCode.plus, SubscriptionPlanCode.plusPreview},
    {SubscriptionPlanCode.pro, SubscriptionPlanCode.proPreview},
    {SubscriptionPlanCode.salonPro, SubscriptionPlanCode.salonPreview},
  ];

  /// Classifies a switch from the plan the account currently holds to the
  /// plan being bought.
  static PlanSwitchKind classify({
    required SubscriptionPlanCode from,
    required SubscriptionPlanCode to,
  }) {
    if (from == to) return PlanSwitchKind.samePlan;
    for (final pair in _equalPricePairs) {
      if (pair.contains(from) && pair.contains(to)) {
        return PlanSwitchKind.equalPriceReplacement;
      }
    }
    return PlanSwitchKind.unapproved;
  }

  /// The plan [plan] may be switched to as an equal-price replacement, or
  /// `null` when it has no approved sibling. Used for user-facing copy only.
  static SubscriptionPlanCode? equalPriceSiblingOf(SubscriptionPlanCode plan) {
    for (final pair in _equalPricePairs) {
      if (pair.contains(plan)) {
        return pair.firstWhere((candidate) => candidate != plan);
      }
    }
    return null;
  }
}
