import '../../../makeup_kit/domain/entities/makeup_kit_category.dart';
import '../entities/tutorial_category.dart';

/// The authoritative mapping between product/recommendation vocabularies and
/// the controlled [TutorialCategory] vocabulary.
///
/// This mapping is application-owned. It must be mirrored server-side (in the
/// Edge Function that validates AI output) and kept in sync by tests on both
/// sides. The AI never supplies a mapping and never names a tutorial category:
/// it names a product or a recommendation key, and this catalog decides which
/// tutorial step that belongs to.
///
/// The relationship is many-to-one by design. Lipstick and Lip Gloss both map
/// to [TutorialCategory.lips], so a single Lips step can legitimately present
/// two owned products.
abstract final class TutorialCategoryMapping {
  /// My Makeup Kit inventory category to tutorial category.
  ///
  /// Total over [MakeupKitCategory]: every inventory category the user can
  /// register has a tutorial home, so a valid kit product can never be
  /// unmappable.
  static const Map<MakeupKitCategory, TutorialCategory> _kitToTutorial = {
    MakeupKitCategory.foundation: TutorialCategory.foundation,
    MakeupKitCategory.concealer: TutorialCategory.concealer,
    MakeupKitCategory.contourBronzer: TutorialCategory.contourBronzer,
    MakeupKitCategory.blush: TutorialCategory.blush,
    MakeupKitCategory.highlighter: TutorialCategory.highlighter,
    MakeupKitCategory.eyebrow: TutorialCategory.eyebrows,
    MakeupKitCategory.eyeshadow: TutorialCategory.eyeshadow,
    MakeupKitCategory.eyeliner: TutorialCategory.eyeliner,
    MakeupKitCategory.lipstick: TutorialCategory.lips,
    MakeupKitCategory.lipGloss: TutorialCategory.lips,
  };

  /// Standard Mode recommendation plan keys to tutorial category.
  ///
  /// These are the keys of the frozen Standard Mode recommendation schema
  /// (`foundation, concealer, contour, highlight, blush, eyeshadow, eyebrow,
  /// eyeliner, lipstick, lipGloss`). They differ from the inventory vocabulary
  /// — `contour` vs `contour_bronzer`, `highlight` vs `highlighter`, camelCase
  /// `lipGloss` vs snake_case `lip_gloss` — which is precisely why the mapping
  /// is explicit here rather than assumed to be an identity transform.
  ///
  /// Mapping a recommendation key does **not** include that category in a
  /// tutorial. Inclusion is decided only by visual grounding in the canonical
  /// final preview; the recommendation can corroborate but never force.
  static const Map<String, TutorialCategory> _standardKeyToTutorial = {
    'foundation': TutorialCategory.foundation,
    'concealer': TutorialCategory.concealer,
    'contour': TutorialCategory.contourBronzer,
    'highlight': TutorialCategory.highlighter,
    'blush': TutorialCategory.blush,
    'eyeshadow': TutorialCategory.eyeshadow,
    'eyebrow': TutorialCategory.eyebrows,
    'eyeliner': TutorialCategory.eyeliner,
    'lipstick': TutorialCategory.lips,
    'lipGloss': TutorialCategory.lips,
  };

  /// The tutorial category a registered inventory [category] belongs to.
  static TutorialCategory fromKitCategory(MakeupKitCategory category) =>
      _kitToTutorial[category]!;

  /// Every inventory category that maps into [category], in inventory
  /// declaration order.
  ///
  /// Returns two entries for [TutorialCategory.lips] (Lipstick and Lip Gloss)
  /// and one for every other tutorial category.
  static List<MakeupKitCategory> kitCategoriesFor(TutorialCategory category) =>
      List<MakeupKitCategory>.unmodifiable(
        MakeupKitCategory.values.where(
          (kit) => _kitToTutorial[kit] == category,
        ),
      );

  /// The tutorial category for a Standard Mode recommendation plan [key], or
  /// `null` when [key] is outside the frozen recommendation vocabulary.
  static TutorialCategory? fromStandardRecommendationKey(String key) =>
      _standardKeyToTutorial[key];

  /// The Standard Mode recommendation keys that map into [category], in
  /// declaration order.
  static List<String> standardRecommendationKeysFor(
    TutorialCategory category,
  ) => List<String>.unmodifiable(
    _standardKeyToTutorial.entries
        .where((entry) => entry.value == category)
        .map((entry) => entry.key),
  );
}
