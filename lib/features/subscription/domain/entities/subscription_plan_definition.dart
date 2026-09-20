import 'allowance_unit.dart';
import 'reset_policy.dart';
import 'subscription_plan_code.dart';

/// The classification facts that define one plan.
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
///
/// Capability — [allowanceUnit] and [tutorialEnabled] — is present, as a
/// description of the product for the paywall to explain. It is not what
/// authorizes anything: the server enforces Tutorial access from its own
/// product configuration, and a resolved `SubscriptionSummary` carries the
/// server's answer for the account.
class SubscriptionPlanDefinition {
  const SubscriptionPlanDefinition({
    required this.planCode,
    required this.displayName,
    required this.publiclyPurchasable,
    required this.baseAllowance,
    required this.resetPolicy,
    required this.allowanceUnit,
    required this.tutorialEnabled,
  }) : assert(baseAllowance >= 0, 'A plan allowance cannot be negative.'),
       assert(
         allowanceUnit != AllowanceUnit.finalPreviewCredit || !tutorialEnabled,
         'A Final Preview Credit never authorizes a Tutorial.',
       );

  /// The plan's stable identity.
  final SubscriptionPlanCode planCode;

  /// The product name shown to users.
  ///
  /// Display copy only. It is never the identity contract — [planCode] is.
  final String displayName;

  /// Whether the plan can be bought from the app's purchase UI.
  ///
  /// `false` for Free, which has nothing to buy, and for Salon Pilot, which is
  /// admin granted and must never appear in a public purchase flow.
  final bool publiclyPurchasable;

  /// The plan's configured allowance, in [allowanceUnit], before any
  /// administrative adjustment.
  ///
  /// For recurring plans this is the allowance per verified billing period. For
  /// Free it is the one-time complimentary look, and for Salon Pilot it is the
  /// default initial grant.
  final int baseAllowance;

  /// Whether and how the allowance replenishes.
  final ResetPolicy resetPolicy;

  /// What one unit of [baseAllowance] is.
  final AllowanceUnit allowanceUnit;

  /// Whether the plan includes the Step-by-Step Tutorial for its results.
  final bool tutorialEnabled;

  @override
  bool operator ==(Object other) =>
      other is SubscriptionPlanDefinition &&
      other.planCode == planCode &&
      other.displayName == displayName &&
      other.publiclyPurchasable == publiclyPurchasable &&
      other.baseAllowance == baseAllowance &&
      other.resetPolicy == resetPolicy &&
      other.allowanceUnit == allowanceUnit &&
      other.tutorialEnabled == tutorialEnabled;

  @override
  int get hashCode => Object.hash(
    planCode,
    displayName,
    publiclyPurchasable,
    baseAllowance,
    resetPolicy,
    allowanceUnit,
    tutorialEnabled,
  );

  @override
  String toString() =>
      'SubscriptionPlanDefinition(${planCode.code}, '
      '$baseAllowance ${allowanceUnit.label(baseAllowance)}, '
      '${resetPolicy.code}, tutorial: $tutorialEnabled)';
}
