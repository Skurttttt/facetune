/// The controlled vocabulary of guide markings a tutorial step may reference.
///
/// This is the shared language between two things that are generated
/// separately and must still read as one teaching system: the guideline image
/// drawn over the original selfie, and the instruction text rendered beside it
/// by Flutter. An instruction that says only "blend upward" leaves the user
/// hunting for which marking it means; one that says "follow the arrows →"
/// points at something visible.
///
/// The set is deliberately tiny and closed. Four meanings cover every category
/// in the vocabulary, and a fifth would have to earn its place by being
/// genuinely un-expressible as one of these — twenty ad-hoc symbols would make
/// the key unreadable and defeat the purpose.
///
/// [fromCode] rejects anything outside the enum, so an unrecognised guide type
/// can never reach presentation as an unnamed symbol.
enum TutorialGuideType {
  /// Where to begin — the anchor the user places first.
  startAnchor('start_anchor', '●'),

  /// A target boundary or path the marking follows.
  placementBoundary('placement_boundary', '━'),

  /// A soft edge: where colour must fade out rather than stop.
  blendZone('blend_zone', '- -'),

  /// Which way to apply, blend, or extend.
  direction('direction', '→');

  const TutorialGuideType(this.code, this.symbol);

  /// The stable wire/persistence identifier.
  ///
  /// Nothing persists a guide type today — these contracts are built entirely
  /// from data the system already stores — but the code exists so that if one
  /// ever is persisted or sent over the wire, it is this value and not an enum
  /// index that would shift the moment a case is reordered.
  final String code;

  /// The glyph shown in the guide key and inline in instruction text.
  ///
  /// Lives in the domain rather than with the display strings because it is
  /// the identity of the guide, not a translation of it: the arrow is the same
  /// arrow in every language, and it has to match between the key and the
  /// instruction that references it. The human-readable *name* is display copy
  /// and belongs with the other labels.
  final String symbol;

  /// Returns the guide type for [code], or `null` when [code] is outside the
  /// controlled vocabulary.
  static TutorialGuideType? fromCode(String code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }

  /// The full vocabulary, in the order a guide key should list it.
  ///
  /// Start, then the two kinds of line, then direction — the order a user
  /// actually applies makeup in, which makes the key readable top to bottom
  /// rather than alphabetically arbitrary.
  static List<TutorialGuideType> get orderedVocabulary =>
      List<TutorialGuideType>.unmodifiable(values);
}
