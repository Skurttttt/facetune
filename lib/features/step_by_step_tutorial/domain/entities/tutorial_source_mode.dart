/// The two makeup journeys a Step-by-Step Tutorial can be generated from.
///
/// Mirrors [MakeupRecommendationMode] in the makeup_kit feature, which
/// distinguishes the same two mutually exclusive strategies at the
/// recommendation stage. Kept as a separate type because a tutorial's source
/// linkage is broader than a recommendation's (it also carries a preview /
/// kit result reference), not because the concept differs.
///
/// [code] is the stable identifier persisted in
/// `tutorial_sessions.source_mode` (see
/// supabase/migrations/20260814000300_tutorial_sessions_steps.sql), not a
/// derivation of the Dart member name.
enum TutorialSourceMode {
  standardRecommendation('standard_recommendation'),
  makeupKit('makeup_kit');

  const TutorialSourceMode(this.code);

  final String code;

  static TutorialSourceMode? fromCode(String code) {
    for (final mode in values) {
      if (mode.code == code) return mode;
    }
    return null;
  }
}
