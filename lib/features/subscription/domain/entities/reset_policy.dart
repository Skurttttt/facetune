/// How (or whether) a plan's allowance replenishes.
///
/// V1 mapping:
///
/// ```text
/// free         → none
/// plus         → billing_period
/// pro          → billing_period
/// salon_pro    → billing_period
/// salon_pilot  → none
/// ```
///
/// Salon Pilot allowance changes are administrative *adjustments*, not resets.
/// Salon Pilot must never be modelled as a recurring monthly subscription.
enum ResetPolicy {
  /// The allowance never automatically replenishes.
  ///
  /// Used by the one-time Free AI Look and by the Salon Pilot total grant.
  none('none'),

  /// The allowance replenishes when a new *verified* billing period begins.
  ///
  /// The period comes from verified provider state — never from the device
  /// clock, and never from a local calendar calculation. Unused allowance does
  /// not roll over into the next period.
  billingPeriod('billing_period');

  const ResetPolicy(this.code);

  /// The stable wire/persistence identifier.
  final String code;

  /// Returns the reset policy for [code], or `null` when [code] is outside the
  /// controlled vocabulary.
  static ResetPolicy? fromCode(String code) {
    for (final policy in values) {
      if (policy.code == code) return policy;
    }
    return null;
  }
}
