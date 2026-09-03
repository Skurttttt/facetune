import '../../../makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import '../../../makeup_kit/domain/entities/makeup_kit_category.dart';
import '../../../recommendation/domain/entities/makeup_recommendation.dart';
import '../entities/tutorial_category.dart';
import 'tutorial_category_mapping.dart';

/// One entry of the realized look, in Standard Mode.
///
/// Carries both authorities side by side and keeps them separate: [category]
/// comes from the accepted manifest and answers *is this visibly here*, while
/// [item] comes from the validated recommendation and answers *what are the
/// truthful details*. Neither is derived from the other.
class RealizedStandardEntry {
  const RealizedStandardEntry({
    required this.category,
    required this.planKey,
    required this.item,
  });

  /// The tutorial category this entry belongs to. Two entries can share one
  /// category: a Lips step is fed by both `lipstick` and `lipGloss`.
  final TutorialCategory category;

  /// The recommendation plan key this entry was read from, kept so the card
  /// can still label itself the way it always has.
  final String planKey;

  final MakeupRecommendationItem item;
}

/// One entry of the realized look, in My Makeup Kit Mode.
class RealizedKitEntry {
  const RealizedKitEntry({required this.category, required this.selection});

  final TutorialCategory category;
  final KitMakeupSelection selection;
}

/// One manifest category and every entry that belongs to it.
///
/// The unit the Makeup Breakdown renders one section from, and the reason the
/// breakdown and the tutorial can be compared at all. A category is one section
/// however many products feed it: Lipstick and Lip Gloss are two entries inside
/// one Lips section, not two categories.
///
/// [entries] is never empty — a category with no authoritative metadata is
/// omitted rather than rendered as a heading with nothing under it, because the
/// alternative would be inventing a placeholder item.
class RealizedCategoryGroup<T> {
  const RealizedCategoryGroup({required this.category, required this.entries});

  final TutorialCategory category;

  /// The entries in this category, in the mapping's declaration order — so
  /// `lipstick` precedes `lipGloss` deterministically.
  final List<T> entries;

  /// Whether this category is fed by more than one product or plan key.
  ///
  /// Presentation uses it to decide between a single canonical-titled card and
  /// a category heading with items beneath. It is a count of *entries*, never
  /// of categories.
  bool get hasMultipleEntries => entries.length > 1;
}

/// Filters a look's presentation down to what the accepted manifest says is
/// visibly present.
///
/// This exists because the app had two answers to one question. The Makeup
/// Breakdown rendered the recommendation directly — the *intent*, formed before
/// the final preview existed — while the tutorial filtered through the accepted
/// manifest, the *realized look*. A Natural preview could therefore list
/// Contour in the breakdown and omit it from the tutorial, which is the defect
/// V4-QA-6B fixes.
///
/// There is no classification here and there never can be. The only input that
/// decides presence is [included], which is `manifest.includedCategories` — the
/// exact list `TutorialStepPlanner` builds steps from. Nothing in this file
/// looks at a style, an intensity, a step count, or a category name.
///
/// Ordering is taken from [included] rather than from the recommendation's own
/// key order, so the breakdown and the tutorial present the same categories in
/// the same sequence. Within one category the mapping's declaration order
/// applies, which keeps `lipstick` ahead of `lipGloss`.
abstract final class RealizedLookFilter {
  /// The Standard Mode breakdown entries for [included], in manifest order.
  ///
  /// A category the manifest includes but the recommendation never mentioned
  /// simply contributes nothing — the recommendation is the only source of
  /// metadata, and inventing an entry to fill the gap is exactly what the
  /// product rules forbid.
  static List<RealizedStandardEntry> standardEntries({
    required MakeupRecommendation recommendation,
    required List<TutorialCategory> included,
  }) => List<RealizedStandardEntry>.unmodifiable(<RealizedStandardEntry>[
    for (final category in included)
      for (final planKey
          in TutorialCategoryMapping.standardRecommendationKeysFor(category))
        if (recommendation.items[planKey] case final item?)
          RealizedStandardEntry(
            category: category,
            planKey: planKey,
            item: item,
          ),
  ]);

  /// The My Makeup Kit breakdown entries for [included], in manifest order.
  ///
  /// Reads the immutable snapshot carried on the recommendation, never live
  /// inventory: a product edited or deleted since the look was validated must
  /// still present as it was used.
  ///
  /// A selection whose stored category is outside the inventory vocabulary is
  /// dropped rather than guessed at. It cannot occur through a validated
  /// snapshot — the server rejects an unmappable category outright — so this is
  /// a total function over real data rather than a silent fallback.
  static List<RealizedKitEntry> kitEntries({
    required KitMakeupRecommendation recommendation,
    required List<TutorialCategory> included,
  }) {
    final byCategory = <TutorialCategory, List<KitMakeupSelection>>{};
    for (final selection in recommendation.selections) {
      final kitCategory = MakeupKitCategory.fromCode(selection.category);
      if (kitCategory == null) continue;
      byCategory
          .putIfAbsent(
            TutorialCategoryMapping.fromKitCategory(kitCategory),
            () => <KitMakeupSelection>[],
          )
          .add(selection);
    }
    return List<RealizedKitEntry>.unmodifiable(<RealizedKitEntry>[
      for (final category in included)
        for (final selection in byCategory[category] ?? const [])
          RealizedKitEntry(category: category, selection: selection),
    ]);
  }

  /// The Standard breakdown grouped into one section per manifest category.
  ///
  /// The grouping is entirely generic: entries are bucketed by the category the
  /// canonical mapping already assigns them, so nothing here knows that Lips is
  /// the category that currently has two plan keys. A future category that
  /// gains a second key groups correctly without this code changing.
  static List<RealizedCategoryGroup<RealizedStandardEntry>> standardGroups({
    required MakeupRecommendation recommendation,
    required List<TutorialCategory> included,
  }) => _group(
    standardEntries(recommendation: recommendation, included: included),
    (entry) => entry.category,
    included,
  );

  /// The My Makeup Kit breakdown grouped into one section per manifest
  /// category.
  static List<RealizedCategoryGroup<RealizedKitEntry>> kitGroups({
    required KitMakeupRecommendation recommendation,
    required List<TutorialCategory> included,
  }) => _group(
    kitEntries(recommendation: recommendation, included: included),
    (entry) => entry.category,
    included,
  );

  /// Buckets [entries] by category and emits them in [included] order.
  ///
  /// Order comes from the manifest rather than from the order entries happen to
  /// arrive in, which is what keeps the breakdown's sequence identical to the
  /// tutorial's. A category with no entries is skipped rather than emitted
  /// empty.
  static List<RealizedCategoryGroup<T>> _group<T>(
    List<T> entries,
    TutorialCategory Function(T) categoryOf,
    List<TutorialCategory> included,
  ) {
    final buckets = <TutorialCategory, List<T>>{};
    for (final entry in entries) {
      buckets.putIfAbsent(categoryOf(entry), () => <T>[]).add(entry);
    }
    return List<RealizedCategoryGroup<T>>.unmodifiable(
      <RealizedCategoryGroup<T>>[
        for (final category in included)
          if (buckets[category] case final bucket? when bucket.isNotEmpty)
            RealizedCategoryGroup<T>(
              category: category,
              entries: List<T>.unmodifiable(bucket),
            ),
      ],
    );
  }

  /// The categories a grouped breakdown presents, in order.
  ///
  /// This is the value compared against the tutorial's step categories. One
  /// group is one category no matter how many entries it holds, which is the
  /// whole point of grouping.
  static List<TutorialCategory> groupCategories(
    List<RealizedCategoryGroup<Object?>> groups,
  ) => List<TutorialCategory>.unmodifiable(
    groups.map((group) => group.category),
  );

  /// The distinct categories in [categories], in the order they first appear.
  ///
  /// This is the value the consistency invariant is stated over, and it is
  /// deliberately not the number of cards. Two recommendation keys can map to
  /// one category, so a look containing both a lipstick and a lip gloss shows
  /// two Lips cards for one Lips step. The *category* sets still match exactly,
  /// which is what makes the two screens agree.
  static List<TutorialCategory> distinctCategories(
    Iterable<TutorialCategory> categories,
  ) {
    final seen = <TutorialCategory>[];
    for (final category in categories) {
      if (!seen.contains(category)) seen.add(category);
    }
    return List<TutorialCategory>.unmodifiable(seen);
  }

  /// The categories covered by Standard [entries], in order.
  static List<TutorialCategory> standardCategories(
    List<RealizedStandardEntry> entries,
  ) => distinctCategories(entries.map((entry) => entry.category));

  /// The categories covered by kit [entries], in order.
  static List<TutorialCategory> kitCategories(List<RealizedKitEntry> entries) =>
      distinctCategories(entries.map((entry) => entry.category));
}
