import 'allowance_unit.dart';

/// Which bucket a reservation draws from.
///
/// Reported by the server so the surface can say, before the user spends
/// anything, whether the next Final Preview comes out of the plan's included
/// allowance or out of a purchased credit — and, through
/// [PurchasedCreditSummary.nextAllowanceUnit], whether it will carry the
/// Tutorial. The client never chooses; it reads.
enum AllowanceSource {
  subscription('subscription'),
  purchasedCredit('purchased_credit');

  const AllowanceSource(this.code);

  final String code;

  static AllowanceSource? fromCode(String code) {
    for (final source in values) {
      if (source.code == code) return source;
    }
    return null;
  }
}

/// The account's purchased top-up credits, as the server reports them.
///
/// Every number here is server-derived: granted minus committed per credit
/// class, with in-flight reservations already subtracted from what is
/// available. There is no way to decrement one locally, and none of these
/// figures is ever added to the subscription's own allowance — the two are
/// different money and stay different numbers.
///
/// Purchased credits belong to the account, not to a plan. They are reported
/// whatever the plan is, including when they cannot currently be spent;
/// [usable] says whether an eligible paid plan is in force to spend them.
class PurchasedCreditSummary {
  const PurchasedCreditSummary({
    required this.tutorialCapableRemaining,
    required this.previewOnlyRemaining,
    required this.usable,
    required this.availableCompatible,
    this.nextAllowanceSource,
    this.nextAllowanceUnit,
  }) : assert(
         tutorialCapableRemaining >= 0 &&
             previewOnlyRemaining >= 0 &&
             availableCompatible >= 0,
         'Purchased credit counts cannot be negative.',
       );

  /// No purchased credits at all, and nothing to spend them under. The value
  /// a summary carries when the server predates purchased credits.
  static const none = PurchasedCreditSummary(
    tutorialCapableRemaining: 0,
    previewOnlyRemaining: 0,
    usable: false,
    availableCompatible: 0,
  );

  /// Tutorial-capable credits not yet spent, including any held in flight.
  final int tutorialCapableRemaining;

  /// Preview-only credits not yet spent, including any held in flight.
  final int previewOnlyRemaining;

  /// Whether the governing plan may spend purchased credits right now: an
  /// active, eligible paid plan. False on Free, Salon Pilot, and any lapsed
  /// or blocked plan — the credits are kept, not spent.
  final bool usable;

  /// Credits that could be reserved this instant: compatible with the
  /// governing plan's capability, [usable], and not held by a reservation.
  final int availableCompatible;

  /// Which bucket the next reservation would draw from, or null when the
  /// server would refuse.
  final AllowanceSource? nextAllowanceSource;

  /// The unit the next reservation would be stamped with — so the surface can
  /// say whether the next look includes the Tutorial. Null when refused.
  final AllowanceUnit? nextAllowanceUnit;

  /// Credits stored on the account, of either class.
  int get totalRemaining => tutorialCapableRemaining + previewOnlyRemaining;

  /// Whether there is anything stored worth mentioning.
  bool get hasAny => totalRemaining > 0;

  /// Whether the next reservation would spend a purchased credit rather than
  /// the plan's included allowance.
  bool get nextDrawsFromPurchased =>
      nextAllowanceSource == AllowanceSource.purchasedCredit;

  @override
  bool operator ==(Object other) =>
      other is PurchasedCreditSummary &&
      other.tutorialCapableRemaining == tutorialCapableRemaining &&
      other.previewOnlyRemaining == previewOnlyRemaining &&
      other.usable == usable &&
      other.availableCompatible == availableCompatible &&
      other.nextAllowanceSource == nextAllowanceSource &&
      other.nextAllowanceUnit == nextAllowanceUnit;

  @override
  int get hashCode => Object.hash(
    tutorialCapableRemaining,
    previewOnlyRemaining,
    usable,
    availableCompatible,
    nextAllowanceSource,
    nextAllowanceUnit,
  );

  @override
  String toString() =>
      'PurchasedCreditSummary(tutorial: $tutorialCapableRemaining, '
      'preview: $previewOnlyRemaining, usable: $usable, '
      'available: $availableCompatible)';
}
