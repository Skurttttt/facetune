import '../../../makeup_kit/domain/entities/makeup_recommendation_mode.dart';

/// Which recommendation system produced the look a tutorial is built from.
///
/// This is the single discriminator for dual-mode behaviour across the whole
/// tutorial architecture. It is always carried explicitly.
///
/// It must never be inferred from the presence or absence of a nullable field
/// (for example "a kit recommendation id is set, therefore this is kit mode"),
/// and it must never be reduced to a `useKit` boolean. A boolean cannot be
/// extended, cannot be persisted with a stable identity, and gives no compiler
/// help when a third source mode is added later. [code] is the stable
/// identifier used at persistence and AI payload boundaries; UI labels are
/// never the identity contract.
enum RecommendationSourceMode {
  standard('standard'),
  myMakeupKit('my_makeup_kit');

  const RecommendationSourceMode(this.code);

  /// The stable wire/persistence identifier.
  final String code;

  /// Returns the mode for [code], or `null` when [code] is outside the
  /// controlled vocabulary.
  static RecommendationSourceMode? fromCode(String code) {
    for (final mode in values) {
      if (mode.code == code) return mode;
    }
    return null;
  }

  /// Bridges the existing pre-V4 selection enum into the tutorial domain.
  ///
  /// [MakeupRecommendationMode] is the user-facing choice made on the
  /// recommendation-mode screen and already exists in the shipped app. The
  /// tutorial architecture keeps its own type because it needs a stable
  /// persisted [code], while the existing enum is a plain UI selection with no
  /// wire identity. Converting here — rather than reusing one enum for both
  /// jobs — keeps the shipped feature untouched.
  static RecommendationSourceMode fromRecommendationMode(
    MakeupRecommendationMode mode,
  ) => switch (mode) {
    MakeupRecommendationMode.standard => RecommendationSourceMode.standard,
    MakeupRecommendationMode.makeupKit => RecommendationSourceMode.myMakeupKit,
  };

  /// The inverse of [fromRecommendationMode].
  MakeupRecommendationMode toRecommendationMode() => switch (this) {
    RecommendationSourceMode.standard => MakeupRecommendationMode.standard,
    RecommendationSourceMode.myMakeupKit => MakeupRecommendationMode.makeupKit,
  };
}
