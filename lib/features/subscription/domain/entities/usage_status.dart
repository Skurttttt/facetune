/// The lifecycle state of one AI Look usage operation.
///
/// The full canonical lifecycle is:
///
/// ```text
/// CHECK ENTITLEMENT → CHECK CAPACITY → RESERVE → GENERATE → PERSIST → COMMIT
///
/// RESERVE → (no usable persisted canonical Final Preview) → RELEASE
/// ```
///
/// Vaguer states such as `used`, `done`, `finished`, `failed_charge`, or
/// `cancelled_usage` are forbidden without a contract revision. A technical
/// failure reason belongs in sanitized metadata on a released operation, not in
/// a new status.
enum UsageStatus {
  /// Capacity has been atomically held for an intended Final Makeup Preview.
  ///
  /// A reservation is *not* historical consumption — it is a hold that must
  /// still resolve to either [committed] or [released].
  reserved('reserved'),

  /// A usable canonical Final Makeup Preview exists and was persisted, so
  /// exactly one AI Look has been consumed.
  committed('committed'),

  /// The reservation definitively ended without a usable persisted canonical
  /// Final Preview, and the held capacity has been returned.
  ///
  /// A client timeout, app close, lost connection, or navigation away does not
  /// by itself justify this state — the server must reconcile the real
  /// persistence outcome first.
  released('released');

  const UsageStatus(this.code);

  /// The stable wire/persistence identifier.
  final String code;

  /// Whether an entry in this state reduces the capacity available for a *new*
  /// generation right now.
  ///
  /// Both [reserved] and [committed] do, which is what stops two concurrent
  /// requests from spending the same last AI Look. [released] does not.
  bool get consumesAvailableCapacity => this != UsageStatus.released;

  /// Returns the usage status for [code], or `null` when [code] is outside the
  /// controlled vocabulary.
  static UsageStatus? fromCode(String code) {
    for (final status in values) {
      if (status.code == code) return status;
    }
    return null;
  }
}
