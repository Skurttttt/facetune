import 'tutorial_category.dart';

/// One brand-neutral colour instruction from a Standard Mode recommendation,
/// scoped to a tutorial category.
///
/// The mirror of [LookProductSnapshotItem] for the mode that has no owned
/// products: it carries a shade *description* such as "warm peach" rather than
/// anything purchasable. The upstream recommendation schema has no brand,
/// retailer, or price field, and nothing here invents one.
class StandardLookEntry {
  const StandardLookEntry({
    required this.planKey,
    required this.shadeName,
    required this.placement,
    required this.technique,
    required this.finish,
    required this.intensity,
    this.colorHex,
    this.reasoning,
  });

  /// The recommendation plan key this came from — `lipstick`, `lipGloss`, and
  /// so on. Preserved so a Lips step can distinguish its two entries.
  final String planKey;

  /// A colour description, never a product to buy.
  final String shadeName;

  /// Null when the category genuinely has no colour.
  final String? colorHex;

  final String placement;
  final String technique;
  final String finish;
  final String intensity;

  /// The recommendation's own one-sentence account of what this category is
  /// for in this look.
  ///
  /// Carried through so the tutorial can state a goal without composing one.
  /// The upstream schema validates it as a short single sentence, and it is the
  /// only authoritative "what this achieves" text the system holds — My Makeup
  /// Kit has no equivalent, so a kit step shows no goal rather than a
  /// manufactured one.
  final String? reasoning;
}

/// The Standard Mode entries for a look, grouped by tutorial category.
///
/// Grouping happens once, at the boundary, so the UI never has to know that
/// `lipstick` and `lipGloss` both belong to Lips.
class StandardLookEntries {
  StandardLookEntries({
    required Map<TutorialCategory, List<StandardLookEntry>> byCategory,
  }) : _byCategory =
           Map<TutorialCategory, List<StandardLookEntry>>.unmodifiable(
             byCategory.map(
               (category, entries) => MapEntry(
                 category,
                 List<StandardLookEntry>.unmodifiable(entries),
               ),
             ),
           );

  static final StandardLookEntries empty = StandardLookEntries(
    byCategory: const <TutorialCategory, List<StandardLookEntry>>{},
  );

  final Map<TutorialCategory, List<StandardLookEntry>> _byCategory;

  /// The entries for [category], in plan-key order. Empty when the
  /// recommendation said nothing about this category.
  List<StandardLookEntry> forCategory(TutorialCategory category) =>
      _byCategory[category] ?? const <StandardLookEntry>[];

  bool get isEmpty => _byCategory.isEmpty;
}
