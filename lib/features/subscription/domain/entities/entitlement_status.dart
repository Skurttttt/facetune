/// The canonical lifecycle state of a user's entitlement.
///
/// This is the *entitlement service's* conclusion, resolved server-side. It is
/// deliberately separate from the raw provider lifecycle
/// (`PurchaseLifecycleStatus`): translating verified provider state into
/// entitlement state is authoritative business logic and does not belong in
/// Flutter.
enum EntitlementStatus {
  /// Creation or provider verification has not reached a final usable state.
  ///
  /// Google Play purchases can legitimately sit in a pending state (for example
  /// a payment method that completes out of band), so this is a real state the
  /// app must be able to show — not a placeholder. Premium must never be
  /// assumed available merely because purchase UI returned success.
  pending('pending'),

  /// Currently valid. Entitled AI operations may proceed *if allowance remains*
  /// — `active` never implies unlimited usage.
  active('active'),

  /// A provider-verified subscription that remains temporarily entitled
  /// according to the provider's own lifecycle.
  ///
  /// The application must not invent its own grace duration; the duration is
  /// whatever verified provider state says it is.
  gracePeriod('grace_period'),

  /// The valid entitlement period ended. New paid generation is blocked, while
  /// existing History, Saved Looks, previews, and tutorials remain available.
  expired('expired'),

  /// Temporarily blocked by an authorized administrative action. Reactivation
  /// may be allowed through a later authorized admin operation.
  suspended('suspended'),

  /// Intentionally terminated by an authorized administrative or provider
  /// action. Historical usage remains immutable and auditable.
  revoked('revoked');

  const EntitlementStatus(this.code);

  /// The stable wire/persistence identifier.
  final String code;

  /// Whether this status is one under which new AI Looks may be generated,
  /// **for presentation purposes only**.
  ///
  /// This exists so the UI can choose between "2 of 3 remaining" and an upgrade
  /// prompt without every widget re-deriving the rule. It is deliberately NOT
  /// an authorization decision:
  ///
  ///   * it knows nothing about remaining allowance;
  ///   * it knows nothing about active reservations;
  ///   * it is computed from a value the client was handed, which may be stale.
  ///
  /// The authoritative answer to "may this user generate right now" is the
  /// server's `GenerationAuthorization`. Never gate a generation request on
  /// this getter, and never treat it as a client-side `isPremium`.
  bool get permitsNewAiLooks =>
      this == EntitlementStatus.active || this == EntitlementStatus.gracePeriod;

  /// Returns the status for [code], or `null` when [code] is outside the
  /// controlled vocabulary.
  ///
  /// An unrecognised status must never be coerced into [active].
  static EntitlementStatus? fromCode(String code) {
    for (final status in values) {
      if (status.code == code) return status;
    }
    return null;
  }
}
