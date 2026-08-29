/// Which persisted recommendation a Tutorial V2 session teaches.
///
/// [code] is the stable identifier used across persistence and AI payload
/// boundaries. It deliberately matches the vocabulary the remote
/// `tutorial_sessions.source_mode` check constraint already uses, so V2 and
/// the frozen V1 rows describe the same two modes with the same strings.
enum TutorialV2SourceMode {
  standardRecommendation('standard_recommendation'),
  makeupKit('makeup_kit');

  const TutorialV2SourceMode(this.code);

  final String code;

  bool get isMakeupKit => this == TutorialV2SourceMode.makeupKit;

  static TutorialV2SourceMode? fromCode(String code) {
    for (final mode in values) {
      if (mode.code == code) return mode;
    }
    return null;
  }
}
