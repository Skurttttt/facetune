/// Where a V3 tutorial's persisted recommendation came from.
///
/// A session is bound to exactly one mode for its whole lifetime: the
/// standard recommendation chain (`recommendations`) or the My Makeup Kit
/// chain (`kit_makeup_recommendations`). These are separate tables, not a
/// discriminator column, so the mode also decides which recommendation
/// identifier a session carries.
enum TutorialV3SourceMode {
  standard('standard'),
  makeupKit('makeup_kit');

  const TutorialV3SourceMode(this.code);

  final String code;

  bool get isKit => this == TutorialV3SourceMode.makeupKit;

  /// The storage folder the mode's premium previews are written into by
  /// `generate-makeup-preview` and `generate-kit-makeup-preview`.
  ///
  /// The two chains produce different looks for the same analysis, so the
  /// folder is what distinguishes a Kit target from a standard one on disk.
  String get canonicalPreviewFolder => isKit ? 'kit-generated' : 'generated';

  static TutorialV3SourceMode? fromCode(String code) {
    for (final mode in values) {
      if (mode.code == code) return mode;
    }
    return null;
  }
}
