import 'allowance_unit.dart';
import 'subscription_plan_code.dart';

/// The capability a purchased credit carries, fixed at purchase.
///
/// This is the provenance the Source of Truth requires every purchased credit
/// to keep: a cheaper Preview-only credit never becomes Tutorial-capable
/// because the account later moves to a Tutorial-enabled plan, and a
/// Tutorial-capable credit is never spent as anything less. The server stamps
/// the class onto the usage row when the credit is reserved; this enum only
/// names it for display.
enum PurchasedCreditClass {
  /// Spends as an AI Look: the Step-by-Step Tutorial for the result is
  /// included. Usable only under a Tutorial-enabled plan.
  tutorialCapableAiLook('tutorial_capable_ai_look', AllowanceUnit.aiLook),

  /// Spends as a Final Preview Credit: the Final Preview only, never a
  /// Tutorial, whatever the plan.
  previewOnlyFinalPreview(
    'preview_only_final_preview',
    AllowanceUnit.finalPreviewCredit,
  );

  const PurchasedCreditClass(this.code, this.unit);

  /// The stable wire/persistence identifier.
  final String code;

  /// The allowance unit one credit of this class spends as.
  final AllowanceUnit unit;

  /// Whether a credit of this class carries the Tutorial.
  bool get tutorialCapable => unit == AllowanceUnit.aiLook;

  /// Returns the class for [code], or `null` when [code] is outside the
  /// controlled vocabulary. An unknown class must never silently become the
  /// Tutorial-capable one.
  static PurchasedCreditClass? fromCode(String code) {
    for (final value in values) {
      if (value.code == code) return value;
    }
    return null;
  }
}

/// The approved V1 top-up packs.
///
/// Two, and only two, as the post-SUB-13 commercial gate approved them. The
/// quantity and class here mirror the server's `top_up_packs` table for
/// display; the server's row is what a verified purchase is actually worth,
/// and `purchased_top_up_credits_contract_test.dart` keeps the two in step.
///
/// There is deliberately no price here. Prices live in Google Play and reach
/// the app only as the store's own localized string.
enum TopUpPack {
  /// One Tutorial-capable AI Look, sold to the Tutorial-enabled paid plans.
  extraAiLook(
    'extra_ai_look',
    displayName: 'Extra AI Look',
    creditClass: PurchasedCreditClass.tutorialCapableAiLook,
    quantity: 1,
    eligiblePlans: {
      SubscriptionPlanCode.plus,
      SubscriptionPlanCode.pro,
      SubscriptionPlanCode.salonPro,
    },
  ),

  /// Ten Preview-only Final Preview Credits, sold to the Preview-only paid
  /// plans.
  previewBoost(
    'preview_boost',
    displayName: 'Preview Boost',
    creditClass: PurchasedCreditClass.previewOnlyFinalPreview,
    quantity: 10,
    eligiblePlans: {
      SubscriptionPlanCode.plusPreview,
      SubscriptionPlanCode.proPreview,
      SubscriptionPlanCode.salonPreview,
    },
  );

  const TopUpPack(
    this.code, {
    required this.displayName,
    required this.creditClass,
    required this.quantity,
    required this.eligiblePlans,
  });

  /// The stable identifier shared with the server's pack catalog.
  final String code;

  /// Product name as approved. Display copy only.
  final String displayName;

  /// What each credit in the pack spends as.
  final PurchasedCreditClass creditClass;

  /// How many credits one purchase grants.
  final int quantity;

  /// The plans approved to buy this pack. Exact, as the server's pack row
  /// says it: a Tutorial plan buys Extra AI Look, a Preview-only plan buys
  /// Preview Boost. Free and Salon Pilot buy neither. The server refuses a
  /// grant outside this set; the paywall simply does not offer one.
  final Set<SubscriptionPlanCode> eligiblePlans;

  /// Whether [plan] may buy this pack.
  bool isOfferedTo(SubscriptionPlanCode plan) => eligiblePlans.contains(plan);

  /// Whether the credits include the Step-by-Step Tutorial.
  bool get tutorialCapable => creditClass.tutorialCapable;

  /// The unit the pack's credits count in.
  AllowanceUnit get unit => creditClass.unit;

  /// e.g. "+1 AI Look", "+10 Final Preview Credits".
  String get quantityLine => '+$quantity ${unit.label(quantity)}';

  /// Returns the pack for [code], or `null` when [code] is not one of ours.
  static TopUpPack? fromCode(String code) {
    for (final pack in values) {
      if (pack.code == code) return pack;
    }
    return null;
  }
}
