import '../../../makeup_kit/domain/entities/makeup_kit_category.dart';

/// The makeup categories a Tutorial V2 step can teach, plus the terminal
/// [finalLook] step.
///
/// [code] is the stable identity contract across persistence and AI payload
/// boundaries; [label] is display-only. The makeup codes are intentionally
/// identical to [MakeupKitCategory.code] so a Kit recommendation maps onto a
/// tutorial category without a translation table that could drift.
///
/// [canonicalRank] encodes the canonical progression documented in the V2
/// Source of Truth (§5): Foundation → Concealer → Contour/Bronzer → Blush →
/// Highlighter → Brows → Eyeshadow → Eyeliner → Lip Color → Lip Gloss →
/// Final Look. Ranks are spaced so a future category can be inserted without
/// renumbering. The rank is an *ordering* rule only — it never implies a
/// category is required, and it never implies a fixed step count.
enum TutorialV2Category {
  foundation('foundation', 'Foundation', 10),
  concealer('concealer', 'Concealer', 20),
  contourBronzer('contour_bronzer', 'Contour & Bronzer', 30),
  blush('blush', 'Blush', 40),
  highlighter('highlighter', 'Highlighter', 50),
  eyebrow('eyebrow', 'Brows', 60),
  eyeshadow('eyeshadow', 'Eyeshadow', 70),
  eyeliner('eyeliner', 'Eyeliner', 80),
  lipstick('lipstick', 'Lip Color', 90),
  lipGloss('lip_gloss', 'Lip Gloss', 100),
  finalLook('final_look', 'Final Look', 1000);

  const TutorialV2Category(this.code, this.label, this.canonicalRank);

  final String code;
  final String label;
  final int canonicalRank;

  /// Whether this is the terminal step, which reuses the canonical final
  /// preview instead of generating a new result.
  bool get isFinalLook => this == TutorialV2Category.finalLook;

  static TutorialV2Category? fromCode(String code) {
    for (final category in values) {
      if (category.code == code) return category;
    }
    return null;
  }

  /// Maps a My Makeup Kit category onto its tutorial category.
  ///
  /// Every [MakeupKitCategory] has an exact counterpart, so this never
  /// returns `null` for a valid Kit category — the nullable return exists
  /// only so an unrecognised code fails closed rather than throwing.
  static TutorialV2Category? fromKitCategory(MakeupKitCategory category) =>
      fromCode(category.code);

  /// Every category except [finalLook], in canonical order.
  static List<TutorialV2Category> get makeupCategories => List.unmodifiable(
    values.where((category) => !category.isFinalLook).toList()
      ..sort((a, b) => a.canonicalRank.compareTo(b.canonicalRank)),
  );
}
