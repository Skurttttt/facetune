/// A server-derived snapshot of how much of an entitlement has been used.
///
/// Every field here is *reported by the server*. This type deliberately offers
/// no way to decrement a counter locally: the authoritative remaining and
/// available counts come from server-side entitlement plus usage state, and a
/// client that decrements its own copy becomes a second, wrong answer.
///
/// Two different numbers matter, and conflating them is the classic mistake:
///
/// ```text
/// availableAiLooks  = effective − committed − reserved   ← may I generate NOW?
/// remainingAiLooks  = effective − committed              ← what do I SHOW?
/// ```
///
/// Active reservations must reduce [availableAiLooks], which is what stops two
/// concurrent requests from spending the same last AI Look. They must *not*
/// reduce [remainingAiLooks], because an in-progress generation has not been
/// consumed yet — showing it as permanently used would be a misleading "used"
/// count, and a failed generation releases it again.
class SubscriptionUsageSummary {
  const SubscriptionUsageSummary({
    required this.effectiveAllowance,
    required this.committedUsage,
    this.reservedUsage = 0,
  }) : assert(
         effectiveAllowance >= 0,
         'An effective allowance cannot be negative.',
       ),
       assert(committedUsage >= 0, 'Committed usage cannot be negative.'),
       assert(reservedUsage >= 0, 'Reserved usage cannot be negative.');

  /// The allowance in force for the current period or grant.
  final int effectiveAllowance;

  /// AI Looks already consumed — each one backed by a usable persisted
  /// canonical Final Makeup Preview.
  final int committedUsage;

  /// AI Looks currently held by in-flight reservations that have resolved to
  /// neither a commit nor a release yet.
  final int reservedUsage;

  /// Capacity available for a *new* generation at this moment.
  ///
  /// Clamped at zero. Negative capacity is prohibited outright, and a clamp is
  /// the safe direction: if server and client ever disagree, the client under-
  /// reports availability rather than inviting a generation that will be
  /// rejected.
  int get availableAiLooks {
    final available = effectiveAllowance - committedUsage - reservedUsage;
    return available < 0 ? 0 : available;
  }

  /// The user-facing "N of M remaining" figure, ignoring in-flight holds.
  ///
  /// Clamped at zero for the same reason as [availableAiLooks]: a user must
  /// never be shown a negative number of AI Looks.
  int get remainingAiLooks {
    final remaining = effectiveAllowance - committedUsage;
    return remaining < 0 ? 0 : remaining;
  }

  /// Whether a new generation would currently be refused for lack of capacity.
  ///
  /// This describes capacity only. An entitlement can be non-exhausted and
  /// still unusable — expired, suspended, or revoked — so this is never on its
  /// own a permission to generate.
  bool get isExhausted => availableAiLooks == 0;

  /// Whether capacity is being held by at least one in-flight generation.
  bool get hasActiveReservations => reservedUsage > 0;

  @override
  bool operator ==(Object other) =>
      other is SubscriptionUsageSummary &&
      other.effectiveAllowance == effectiveAllowance &&
      other.committedUsage == committedUsage &&
      other.reservedUsage == reservedUsage;

  @override
  int get hashCode =>
      Object.hash(effectiveAllowance, committedUsage, reservedUsage);

  @override
  String toString() =>
      'SubscriptionUsageSummary(allowance: $effectiveAllowance, '
      'committed: $committedUsage, reserved: $reservedUsage, '
      'available: $availableAiLooks)';
}
