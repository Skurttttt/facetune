/// What kind of entitled consumption a usage ledger entry represents.
///
/// V1 has exactly one user-facing billable type, by hard-lock:
///
/// > **1 AI Look = 1 successfully generated and successfully persisted Final
/// > Makeup Preview that becomes a usable canonical Final Preview for the
/// > authenticated user.**
///
/// This is an enum rather than a bare constant so the ledger contract does not
/// have to change shape when a second *type* is eventually authorized. It is
/// deliberately not a licence to add one: face analysis, makeup
/// recommendations, tutorial manifests, tutorial guideline steps, and My Makeup
/// Kit operations must not become user-facing AI Look deductions under V1.
/// Their provider cost is metered separately as technical cost.
enum UsageType {
  finalMakeupPreview('final_makeup_preview');

  const UsageType(this.code);

  /// The stable wire/persistence identifier.
  final String code;

  /// Returns the usage type for [code], or `null` when [code] is outside the
  /// controlled vocabulary.
  static UsageType? fromCode(String code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}
