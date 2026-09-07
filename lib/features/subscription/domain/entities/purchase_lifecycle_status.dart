/// The raw provider-reported lifecycle state of a purchase.
///
/// This is intentionally a *separate* vocabulary from [EntitlementStatus]. The
/// two answer different questions:
///
/// ```text
/// PurchaseLifecycleStatus  →  "what did the billing provider last tell us?"
/// EntitlementStatus        →  "what is this user actually entitled to?"
/// ```
///
/// Collapsing them would bake the translation into whichever layer happened to
/// hold the single enum. The clearest example is cancellation:
///
/// ```text
/// cancelled  ≠  immediately expired
/// ```
///
/// A cancelled recurring subscription normally remains entitled until the end
/// of the verified paid period. Only the server-side entitlement service
/// performs that translation; Flutter must not, and Web Admin must not
/// hand-falsify provider lifecycle to force an entitlement outcome.
///
/// This type exists in SUB-1 so later phases have a stable contract to parse
/// verified provider state into. It carries no provider SDK dependency.
enum PurchaseLifecycleStatus {
  /// Payment has not completed. Not yet a grant of anything.
  pending('pending'),

  /// A new purchase was verified.
  purchased('purchased'),

  /// A verified renewal advanced the subscription into a new billing period.
  renewed('renewed'),

  /// Auto-renewal was turned off. The paid period may still be running.
  cancelled('cancelled'),

  /// The verified paid period has ended.
  expired('expired'),

  /// The purchase was refunded.
  refunded('refunded'),

  /// The provider withdrew the purchase (for example a chargeback).
  revoked('revoked');

  const PurchaseLifecycleStatus(this.code);

  /// The stable wire/persistence identifier.
  final String code;

  /// Returns the lifecycle state for [code], or `null` when [code] is outside
  /// the controlled vocabulary.
  static PurchaseLifecycleStatus? fromCode(String code) {
    for (final status in values) {
      if (status.code == code) return status;
    }
    return null;
  }
}
