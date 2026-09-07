/// The time span an entitlement is valid for, and the *kind* of span it is.
///
/// This is a sealed hierarchy rather than one class carrying four nullable
/// dates, because the two date pairs are not interchangeable:
///
/// ```text
/// recurring provider-backed plans  →  period_start / period_end
/// admin-granted temporary grants   →  starts_at   / expires_at
/// ```
///
/// Flattening both into `{periodStart?, periodEnd?, startsAt?, expiresAt?}`
/// would force every reader to guess which pair is meaningful from which
/// happens to be non-null — the same "infer the mode from a nullable field"
/// mistake the tutorial architecture already refuses to make. Matching on the
/// variant is a real test; a null check is not. The compiler also enforces
/// exhaustiveness, so a future period kind surfaces every site that must handle
/// it instead of silently taking an else-branch.
///
/// **No expiry is computed here.** There is deliberately no `isExpired` getter.
/// Expiration is derived from authoritative provider or admin state and arrives
/// as an `EntitlementStatus`; re-deriving it on the client from these dates
/// would create a second, competing entitlement calculator and would let a
/// wrong device clock grant or deny access.
sealed class SubscriptionPeriod {
  const SubscriptionPeriod();

  /// When this entitlement began.
  DateTime get startedAt;
}

/// A recurring billing period from a verified provider subscription.
///
/// Used by Plus, Pro, and Salon Pro. A new verified period receives the plan's
/// configured allowance; unused allowance from [periodStart]–[periodEnd] does
/// not roll over into the next one, and usage stays linked to the period it
/// happened in.
///
/// Cancellation does not rewrite [periodEnd] — a cancelled subscription
/// normally stays entitled until the paid period actually ends.
final class RecurringBillingPeriod extends SubscriptionPeriod {
  const RecurringBillingPeriod({
    required this.periodStart,
    required this.periodEnd,
  });

  /// Start of the current verified billing period.
  final DateTime periodStart;

  /// End of the current verified billing period, from verified provider state.
  final DateTime periodEnd;

  @override
  DateTime get startedAt => periodStart;

  @override
  bool operator ==(Object other) =>
      other is RecurringBillingPeriod &&
      other.periodStart == periodStart &&
      other.periodEnd == periodEnd;

  @override
  int get hashCode => Object.hash(periodStart, periodEnd);

  @override
  String toString() => 'RecurringBillingPeriod($periodStart → $periodEnd)';
}

/// A temporary entitlement created by an authorized administrative grant.
///
/// Used by Salon Pilot, which is complimentary, non-public, non-renewing, and
/// carries a required expiration. [expiresAt] is non-nullable precisely because
/// an admin grant without an end date is an unbounded free entitlement.
final class AdminGrantedPeriod extends SubscriptionPeriod {
  const AdminGrantedPeriod({required this.startsAt, required this.expiresAt});

  /// When the grant becomes usable.
  final DateTime startsAt;

  /// When the grant ends. Administratively controlled and extendable through an
  /// authorized admin operation — never by the app.
  final DateTime expiresAt;

  @override
  DateTime get startedAt => startsAt;

  @override
  bool operator ==(Object other) =>
      other is AdminGrantedPeriod &&
      other.startsAt == startsAt &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(startsAt, expiresAt);

  @override
  String toString() => 'AdminGrantedPeriod($startsAt → $expiresAt)';
}

/// An entitlement with no end and no reset.
///
/// This is the Free plan: one complimentary AI Look that never replenishes and
/// never lapses. Modelling it as a zero-length or far-future billing period
/// would misrepresent it — there is no period to renew and nothing to reset, so
/// there is no end date to carry.
final class PerpetualPeriod extends SubscriptionPeriod {
  const PerpetualPeriod({required this.startsAt});

  /// When the entitlement was created for this account.
  final DateTime startsAt;

  @override
  DateTime get startedAt => startsAt;

  @override
  bool operator ==(Object other) =>
      other is PerpetualPeriod && other.startsAt == startsAt;

  @override
  int get hashCode => startsAt.hashCode;

  @override
  String toString() => 'PerpetualPeriod(from $startsAt)';
}
