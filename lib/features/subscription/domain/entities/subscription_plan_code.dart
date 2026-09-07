/// The canonical Subscription V1 plan identities.
///
/// [code] is the stable identifier shared by Flutter, the backend, and the
/// future Web Admin. It is the plan's *identity* — never a display label, never
/// a price, never a limit.
///
/// A plan must always be carried explicitly. It must never be inferred from:
/// price, localized store text, AI Look limit, whether an expiration date
/// exists, a boolean such as `isPremium`, a UI label, or a product title
/// returned by a billing provider.
///
/// Substitute names such as `premium`, `premium_plus`, `professional`, `salon`,
/// `salon_test`, `salon_research`, or `salon_trial` are forbidden without an
/// approved revision of the Subscription/Admin Shared Contract.
enum SubscriptionPlanCode {
  free('free'),
  plus('plus'),
  pro('pro'),
  salonPro('salon_pro'),
  salonPilot('salon_pilot');

  const SubscriptionPlanCode(this.code);

  /// The stable wire/persistence identifier.
  final String code;

  /// Returns the plan for [code], or `null` when [code] is outside the
  /// controlled vocabulary.
  ///
  /// Returning `null` rather than throwing matches the existing project
  /// convention (see `MakeupKitCategory.fromCode`) and lets a data layer decide
  /// whether an unknown value is a recoverable parse failure or a hard error.
  /// An unrecognised plan code must never silently fall back to a paid plan.
  static SubscriptionPlanCode? fromCode(String code) {
    for (final plan in values) {
      if (plan.code == code) return plan;
    }
    return null;
  }
}
