import 'look_product_snapshot.dart';
import 'standard_look_entry.dart';
import 'recommendation_source_mode.dart';
import 'tutorial_category.dart';

/// Where a validated look plan came from, and the mode-specific references
/// that belong to that origin.
///
/// This is a sealed hierarchy rather than one class with two nullable id
/// fields, so the source mode can never be *inferred* from which field happens
/// to be populated. A `standardRecommendationId == null` check is not a mode
/// test; matching on the variant is. The compiler enforces exhaustiveness, so
/// adding a third source mode later surfaces every site that must handle it
/// instead of silently taking an else-branch.
sealed class LookPlanSource {
  const LookPlanSource();

  /// The explicit, persisted discriminator.
  RecommendationSourceMode get mode;
}

/// A look plan produced by the Standard Mode recommendation flow.
final class StandardLookPlanSource extends LookPlanSource {
  StandardLookPlanSource({
    required this.recommendationId,
    StandardLookEntries? entries,
  }) : entries = entries ?? StandardLookEntries.empty;

  /// The row in the frozen `recommendations` table this plan was validated
  /// from.
  final String recommendationId;

  /// The brand-neutral colour guidance, grouped by tutorial category.
  ///
  /// Empty when only the recommendation header was loaded — the tutorial still
  /// works, it just has no wording to show beside a step.
  final StandardLookEntries entries;

  @override
  RecommendationSourceMode get mode => RecommendationSourceMode.standard;
}

/// A look plan produced by the My Makeup Kit flow from products the user owns.
final class MyMakeupKitLookPlanSource extends LookPlanSource {
  const MyMakeupKitLookPlanSource({
    required this.kitRecommendationId,
    required this.productSnapshot,
  });

  /// The row in `kit_makeup_recommendations` this plan was validated from.
  final String kitRecommendationId;

  /// The immutable owned-product selection, validated server-side for
  /// ownership and category before it reached this contract.
  final LookProductSnapshot productSnapshot;

  @override
  RecommendationSourceMode get mode => RecommendationSourceMode.myMakeupKit;
}

/// The single convergence point both recommendation modes reduce to before a
/// canonical final preview or any tutorial work happens.
///
/// Tutorial code consumes this. It never re-derives, re-requests, or second-
/// guesses the upstream recommendation: by the time a plan exists, product
/// ownership and category validity have already been proven server-side.
class ValidatedLookPlan {
  ValidatedLookPlan({
    required this.id,
    required this.analysisId,
    required this.styleCode,
    required this.source,
    required this.modelId,
    required this.promptVersion,
    required this.createdAt,
  });

  /// Identifier of the underlying validated recommendation.
  final String id;

  /// The face analysis this look was built for. Also the lineage root for the
  /// original selfie, which the tutorial needs as its first image reference.
  final String analysisId;

  /// The makeup style the user selected.
  final String styleCode;

  /// The origin of this plan, carrying its mode-specific references.
  final LookPlanSource source;

  /// The model that produced the underlying recommendation, as reported by the
  /// server. Recorded for provenance; never selected by the client.
  final String modelId;

  /// The prompt version that produced the underlying recommendation, as
  /// reported by the server.
  final String promptVersion;

  final DateTime createdAt;

  /// The explicit source mode. Delegates to [source] so there is exactly one
  /// place the mode can come from.
  RecommendationSourceMode get sourceMode => source.mode;

  /// The immutable owned-product selection in My Makeup Kit mode.
  ///
  /// Standard Mode has no owned-product selection at all, so this is
  /// [LookProductSnapshot.empty] rather than null — an absent selection and an
  /// empty selection behave identically for every consumer, and returning a
  /// real object removes a null check from each of them.
  LookProductSnapshot get productSnapshot => switch (source) {
    StandardLookPlanSource() => LookProductSnapshot.empty,
    MyMakeupKitLookPlanSource(:final productSnapshot) => productSnapshot,
  };

  /// The brand-neutral entries for [category]. Empty in My Makeup Kit mode,
  /// which shows the user's own products instead.
  List<StandardLookEntry> standardEntriesFor(TutorialCategory category) =>
      switch (source) {
        StandardLookPlanSource(:final entries) => entries.forCategory(category),
        MyMakeupKitLookPlanSource() => const <StandardLookEntry>[],
      };

  /// Tutorial categories backed by a validated owned product, in deterministic
  /// logical order. Always empty in Standard Mode.
  ///
  /// This is product coverage, not tutorial inclusion. In My Makeup Kit mode a
  /// step requires both this coverage *and* visual grounding in the canonical
  /// final preview; neither alone is sufficient.
  List<TutorialCategory> get productBackedCategories =>
      productSnapshot.coveredCategories;
}
