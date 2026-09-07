/// How many AI Looks an entitlement is granted, before any usage is counted.
///
/// The canonical rule is:
///
/// ```text
/// base_allowance + sum(valid allowance adjustments) = effective_allowance
/// ```
///
/// [baseAllowance] and [adjustmentTotal] are kept as separate fields rather
/// than pre-summed into one number so an administrative adjustment stays
/// visible and auditable. "Salon Pilot started at 30 and an admin added 10" and
/// "Salon Pilot was granted 40" are different facts, and only the first can be
/// reviewed later.
///
/// Adjustments apply to entitlements that permit them (Salon Pilot in V1). For
/// public plans [adjustmentTotal] is `0` and [effectiveAllowance] is simply the
/// plan's configured allowance for the current verified period.
///
/// Both values arrive from the server. Flutter never computes an adjustment.
class SubscriptionAllowance {
  const SubscriptionAllowance({
    required this.baseAllowance,
    this.adjustmentTotal = 0,
  }) : assert(baseAllowance >= 0, 'A base allowance cannot be negative.');

  /// The plan's granted allowance before adjustments.
  final int baseAllowance;

  /// The signed sum of authorized allowance adjustments. Negative when an admin
  /// has validly reduced an editable allowance.
  final int adjustmentTotal;

  /// The allowance actually in force.
  ///
  /// Clamped at zero: a reduction can validly bring an allowance down, but the
  /// granted total can never be a negative quantity of AI Looks. The server
  /// separately refuses reductions that would fall below already-committed
  /// usage — that rejection is authoritative business logic and is not
  /// re-implemented here.
  int get effectiveAllowance {
    final total = baseAllowance + adjustmentTotal;
    return total < 0 ? 0 : total;
  }

  /// Whether this allowance has been administratively adjusted.
  bool get isAdjusted => adjustmentTotal != 0;

  @override
  bool operator ==(Object other) =>
      other is SubscriptionAllowance &&
      other.baseAllowance == baseAllowance &&
      other.adjustmentTotal == adjustmentTotal;

  @override
  int get hashCode => Object.hash(baseAllowance, adjustmentTotal);

  @override
  String toString() =>
      'SubscriptionAllowance(base: $baseAllowance, '
      'adjustment: $adjustmentTotal, effective: $effectiveAllowance)';
}
