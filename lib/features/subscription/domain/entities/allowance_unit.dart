/// What one unit of a plan's allowance authorizes.
///
/// Both units authorize exactly one new usable persisted Final Makeup Preview
/// through the same protected reserve → generate → persist → commit flow, on
/// the same model, prompt, and validator. They differ in one capability:
///
/// ```text
/// ai_look               Tutorial-capable — the Step-by-Step Tutorial for the
///                       result is included and consumes no further allowance.
/// final_preview_credit  Preview-only — new Tutorial generation is denied,
///                       server-side, for the plan and for the result.
/// ```
///
/// The unit is a fact of the plan's server-side product configuration and is
/// carried to the client on every resolved summary. Copy that names the unit
/// reads it from here; nothing infers it from a plan's name or its allowance.
///
/// Neither unit is a Salon Pilot administrative adjustment or a purchased
/// top-up credit. Those are distinct concepts with their own provenance, and
/// this vocabulary deliberately has no member for them.
enum AllowanceUnit {
  aiLook('ai_look', singular: 'AI Look', plural: 'AI Looks'),
  finalPreviewCredit(
    'final_preview_credit',
    singular: 'Final Preview Credit',
    plural: 'Final Preview Credits',
  );

  const AllowanceUnit(
    this.code, {
    required this.singular,
    required this.plural,
  });

  /// The stable wire/persistence identifier.
  final String code;

  /// User-facing unit names.
  final String singular;
  final String plural;

  /// The unit name for [count], e.g. "1 AI Look", "3 Final Preview Credits".
  String label(int count) => count == 1 ? singular : plural;

  /// Returns the unit for [code], or `null` when [code] is outside the
  /// controlled vocabulary. An unrecognised unit must never silently become
  /// the Tutorial-capable one.
  static AllowanceUnit? fromCode(String code) {
    for (final unit in values) {
      if (unit.code == code) return unit;
    }
    return null;
  }
}
