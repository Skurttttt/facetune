import '../../../makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import '../../../recommendation/domain/entities/makeup_recommendation.dart';
import '../entities/look_product_snapshot.dart';
import '../entities/standard_look_entry.dart';
import '../entities/tutorial_category.dart';
import '../entities/validated_look_plan.dart';
import 'tutorial_category_mapping.dart';

/// Converges the two recommendation modes into the single
/// [ValidatedLookPlan] contract everything downstream consumes.
///
/// This is the only place either mode's entity is turned into a look plan, so
/// there is exactly one definition of what "the look was decided" means. Both
/// inputs are already validated: Standard Mode output passed the frozen
/// recommendation schema server-side, and My Makeup Kit output passed
/// server-side ownership, category, and colour/finish validation before its row
/// was written. Nothing here re-derives, re-requests, or second-guesses that.
///
/// Conversion is deliberately total and lossless in the direction that matters:
/// every field the tutorial needs is carried across, and the source mode is set
/// from which factory was called rather than inferred from the data.
abstract final class LookPlanConvergence {
  /// Converges a brand-neutral Standard Mode recommendation.
  ///
  /// Standard Mode has no owned-product selection at all, so the resulting plan
  /// carries [LookProductSnapshot.empty]. That is a real absence, not missing
  /// data: the user never told us what they own in this mode, and nothing may
  /// invent it for them.
  ///
  /// The recommendation's shade names travel no further than this — they are
  /// colour descriptions like "warm peach", never brands, because the Standard
  /// Mode prompt forbids naming a brand, product line, retailer, or sponsored
  /// product.
  static ValidatedLookPlan fromStandard(MakeupRecommendation recommendation) =>
      ValidatedLookPlan(
        id: recommendation.id,
        analysisId: recommendation.analysisId,
        styleCode: recommendation.styleCode,
        source: StandardLookPlanSource(
          recommendationId: recommendation.id,
          entries: _standardEntries(recommendation),
        ),
        modelId: recommendation.modelId,
        promptVersion: recommendation.promptVersion,
        createdAt: recommendation.createdAt,
      );

  /// Converges a My Makeup Kit recommendation together with its immutable
  /// owned-product snapshot.
  ///
  /// The snapshot is taken from the recommendation's persisted
  /// `productSnapshots` — the server-side capture of the inventory rows as they
  /// were when the look was validated — never from live inventory. Reopening an
  /// old look therefore shows the products as they were, even if the user has
  /// since edited or deleted them.
  ///
  /// An empty or partial snapshot converts normally and still reports
  /// `my_makeup_kit`. There is no path here that downgrades a kit look to
  /// Standard Mode, however little the user owns.
  ///
  /// Throws a [TutorialFailure] (from [LookProductSnapshot.fromKitSnapshots])
  /// if a persisted snapshot item carries a category, finish, or colour outside
  /// the controlled vocabulary, rather than silently dropping it.
  static ValidatedLookPlan fromMyMakeupKit(
    KitMakeupRecommendation recommendation,
  ) => ValidatedLookPlan(
    id: recommendation.id,
    analysisId: recommendation.analysisId,
    styleCode: recommendation.styleCode,
    source: MyMakeupKitLookPlanSource(
      kitRecommendationId: recommendation.id,
      productSnapshot: LookProductSnapshot.fromKitSnapshots(
        recommendation.productSnapshots,
      ),
    ),
    modelId: recommendation.modelId,
    promptVersion: recommendation.promptVersion,
    createdAt: recommendation.createdAt,
  );
}

/// Groups the frozen recommendation's plan items by tutorial category.
///
/// Uses the same server-owned mapping as everything else, so `lipstick` and
/// `lipGloss` land together under Lips. An item whose key is outside the frozen
/// vocabulary is skipped rather than guessed at — it cannot belong to a step.
StandardLookEntries _standardEntries(MakeupRecommendation recommendation) {
  final grouped = <TutorialCategory, List<StandardLookEntry>>{};
  recommendation.items.forEach((key, item) {
    final category = TutorialCategoryMapping.fromStandardRecommendationKey(key);
    if (category == null) return;
    grouped
        .putIfAbsent(category, () => <StandardLookEntry>[])
        .add(
          StandardLookEntry(
            planKey: key,
            shadeName: item.name,
            colorHex: item.hex,
            placement: item.placement,
            technique: item.technique,
            finish: item.finish,
            intensity: item.intensity,
            reasoning: item.reasoning,
          ),
        );
  });
  return StandardLookEntries(byCategory: grouped);
}
