import 'reset_policy.dart';
import 'subscription_plan_code.dart';

/// The classification facts that define one Subscription V1 plan.
///
/// This is a plan *description*, not a purchase record and not an entitlement.
/// It answers "what does Pro mean as a product?" — never "what is this user
/// entitled to right now?", which only a `SubscriptionEntitlement` carrying
/// server-verified state can answer.
///
/// Three things are deliberately **absent**:
///
///   * **Price.** Business pricing belongs to the Subscription Source of Truth,
///     and the price a user actually pays belongs to verified, localized store
///     configuration. A price compiled into the app would be a second answer,
///     wrong the moment a store price changes and unable to represent any
///     currency but the one it was typed in.
///   * **Billing provider and auto-renew.** Both are verified provider truth
///     resolved per entitlement. Hardcoding "plus is billed through Google
///     Play" into a Flutter constructor would put purchase truth in the client.
///   * **Provider product ids.** Mapping a store product to a plan code is a
///     server responsibility; a client-side map would be a way to claim a plan.
class SubscriptionPlanDefinition {
  const SubscriptionPlanDefinition({
    required this.planCode,
    required this.displayName,
    required this.publiclyPurchasable,
    required this.baseAiLookAllowance,
    required this.resetPolicy,
  }) : assert(baseAiLookAllowance >= 0, 'A plan allowance cannot be negative.');

  /// The plan's stable identity.
  final SubscriptionPlanCode planCode;

  /// The product name shown to users.
  ///
  /// Display copy only. It is never the identity contract — [planCode] is.
  final String displayName;

  /// Whether the plan can be bought from the app's purchase UI.
  ///
  /// `false` for Salon Pilot, which is admin granted and must never appear in a
  /// public purchase flow.
  final bool publiclyPurchasable;

  /// The plan's configured AI Look allowance, before any administrative
  /// adjustment.
  ///
  /// For recurring plans this is the allowance per verified billing period. For
  /// Free it is the one-time complimentary look, and for Salon Pilot it is the
  /// default initial grant.
  final int baseAiLookAllowance;

  /// Whether and how the allowance replenishes.
  final ResetPolicy resetPolicy;

  @override
  bool operator ==(Object other) =>
      other is SubscriptionPlanDefinition &&
      other.planCode == planCode &&
      other.displayName == displayName &&
      other.publiclyPurchasable == publiclyPurchasable &&
      other.baseAiLookAllowance == baseAiLookAllowance &&
      other.resetPolicy == resetPolicy;

  @override
  int get hashCode => Object.hash(
    planCode,
    displayName,
    publiclyPurchasable,
    baseAiLookAllowance,
    resetPolicy,
  );

  @override
  String toString() =>
      'SubscriptionPlanDefinition(${planCode.code}, '
      '$baseAiLookAllowance AI Looks, ${resetPolicy.code})';
}
