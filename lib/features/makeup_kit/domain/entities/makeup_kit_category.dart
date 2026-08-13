/// The makeup product categories My Makeup Kit supports.
///
/// [code] is the stable identifier used across persistence and AI payload
/// boundaries. UI display labels must never be used as the identity
/// contract for a category.
enum MakeupKitCategory {
  foundation('foundation'),
  concealer('concealer'),
  blush('blush'),
  highlighter('highlighter'),
  eyeshadow('eyeshadow'),
  lipstick('lipstick'),
  lipGloss('lip_gloss'),
  contourBronzer('contour_bronzer'),
  eyebrow('eyebrow'),
  eyeliner('eyeliner');

  const MakeupKitCategory(this.code);

  final String code;

  static MakeupKitCategory? fromCode(String code) {
    for (final category in values) {
      if (category.code == code) return category;
    }
    return null;
  }
}
