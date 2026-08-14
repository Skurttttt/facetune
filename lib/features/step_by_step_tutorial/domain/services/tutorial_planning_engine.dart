import '../../../makeup_kit/domain/entities/kit_generated_preview.dart';
import '../../../makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import '../../../makeup_kit/domain/entities/makeup_kit_category.dart';
import '../../../preview/domain/entities/generated_preview.dart';
import '../../../recommendation/domain/entities/makeup_recommendation.dart';
import '../catalog/tutorial_placement_overlay_catalog.dart';
import '../entities/tutorial_instruction.dart';
import '../entities/tutorial_plan.dart';
import '../entities/tutorial_step_category.dart';

/// Turns an already-generated look — a standard [MakeupRecommendation] or a
/// My Makeup Kit [KitMakeupRecommendation] — into an ordered, dynamically
/// sized [TutorialPlan].
///
/// Pure and synchronous: no Gemini call, no repository call, no Supabase
/// access. Both entry points only read data already present on the
/// objects they're given — this is deliberate, not an oversight:
///
/// - Standard mode reads only `recommendation.items` (guide §10 — "derive
///   steps only from the actual recommendation"). It never re-derives
///   anything from the face analysis or style catalog.
/// - Kit mode reads only `recommendation.selections` /
///   `recommendation.productSnapshots` (guide §11 — "derive steps only
///   from products actually selected... never invent missing products").
///   It never queries `makeup_kit_products` (live inventory), which is
///   exactly what preserves the snapshot semantics ST-2's schema already
///   established for `kit_makeup_recommendations.product_snapshot_json` —
///   an edit or deletion in the user's current kit cannot change a plan
///   built from a past recommendation, because this engine never looks at
///   current inventory in the first place.
///
/// Whatever calls this (ST-8) is expected to turn each [PlannedTutorialStep]
/// into a `TutorialRepository.createStep` call and each [TutorialPlan] into
/// one `TutorialRepository.createSession` call; this class does not persist
/// anything itself.
abstract final class TutorialPlanningEngine {
  /// Version stamp for the planning algorithm itself (category set,
  /// ordering policy, exclusion rule, final-step logic) — stored as
  /// `tutorial_sessions.prompt_version` (ST-8) so a future change to this
  /// algorithm doesn't make an already-planned session's step set
  /// ambiguous about which rules produced it. Distinct from any Gemini
  /// prompt version: no AI call happens in this class.
  static const planVersion = 'tutorial_plan_v1';

  /// Canonical application order (guide §9's Full Glam example): base,
  /// then color, then eyes, then lips. Categories with no applicable step
  /// are simply omitted from the result — this list is a priority order,
  /// not a required set.
  static const _canonicalOrder = [
    TutorialStepCategory.foundation,
    TutorialStepCategory.concealer,
    TutorialStepCategory.contour,
    TutorialStepCategory.blush,
    TutorialStepCategory.highlighter,
    TutorialStepCategory.eyebrow,
    TutorialStepCategory.eyeshadow,
    TutorialStepCategory.eyeliner,
    TutorialStepCategory.lipstick,
    TutorialStepCategory.lipGloss,
  ];

  static const _recommendationKeyToCategory = {
    'foundation': TutorialStepCategory.foundation,
    'concealer': TutorialStepCategory.concealer,
    'contour': TutorialStepCategory.contour,
    'highlight': TutorialStepCategory.highlighter,
    'blush': TutorialStepCategory.blush,
    'eyeshadow': TutorialStepCategory.eyeshadow,
    'eyebrow': TutorialStepCategory.eyebrow,
    'eyeliner': TutorialStepCategory.eyeliner,
    'lipstick': TutorialStepCategory.lipstick,
    'lipGloss': TutorialStepCategory.lipGloss,
  };

  static const _kitCategoryToTutorialCategory = {
    MakeupKitCategory.foundation: TutorialStepCategory.foundation,
    MakeupKitCategory.concealer: TutorialStepCategory.concealer,
    MakeupKitCategory.blush: TutorialStepCategory.blush,
    MakeupKitCategory.highlighter: TutorialStepCategory.highlighter,
    MakeupKitCategory.eyeshadow: TutorialStepCategory.eyeshadow,
    MakeupKitCategory.lipstick: TutorialStepCategory.lipstick,
    MakeupKitCategory.lipGloss: TutorialStepCategory.lipGloss,
    MakeupKitCategory.contourBronzer: TutorialStepCategory.contour,
    MakeupKitCategory.eyebrow: TutorialStepCategory.eyebrow,
    MakeupKitCategory.eyeliner: TutorialStepCategory.eyeliner,
  };

  /// Recommendation items whose `intensity` matches one of these (case-
  /// insensitively) are treated as "not part of this look" rather than a
  /// step. The Edge Function contract does not guarantee any category is
  /// ever actually omitted this way today (every response currently fills
  /// all ten keys — see `makeup_recommendation_dto.dart`), but the planner
  /// must not force a fixed step count (roadmap ST-7 task 7), so this
  /// check exists to honor an explicit "not applicable" signal the moment
  /// the backend starts sending one, rather than silently ignoring it.
  static const _notApplicableIntensities = {
    'none',
    'skip',
    'n/a',
    'not applicable',
    '',
  };

  static TutorialPlan planFromRecommendation({
    required MakeupRecommendation recommendation,
    required GeneratedPreview preview,
  }) {
    final byCategory = <TutorialStepCategory, TutorialInstruction>{};
    for (final entry in recommendation.items.entries) {
      final category = _recommendationKeyToCategory[entry.key];
      if (category == null) continue;
      final item = entry.value;
      if (_notApplicableIntensities.contains(
        item.intensity.trim().toLowerCase(),
      )) {
        continue;
      }
      byCategory[category] = TutorialInstruction(
        category: category,
        placement: item.placement,
        intensity: item.intensity,
        technique: item.technique,
        colorName: item.name,
        hex: item.hex,
        finish: item.finish,
        tip: item.reasoning,
      );
    }
    return _buildPlan(
      byCategory,
      reusableResultImagePath: preview.generatedImagePath,
      reusableResultImageUrl: preview.generatedImageUrl,
      reusableModelId: preview.modelId,
      reusablePromptVersion: preview.promptVersion,
    );
  }

  static TutorialPlan planFromKitRecommendation({
    required KitMakeupRecommendation recommendation,
    required KitGeneratedPreview preview,
  }) {
    final byCategory = <TutorialStepCategory, TutorialInstruction>{};
    for (final selection in recommendation.selections) {
      final kitCategory = MakeupKitCategory.fromCode(selection.category);
      if (kitCategory == null) continue;
      final category = _kitCategoryToTutorialCategory[kitCategory];
      if (category == null) continue;
      final snapshot = recommendation.snapshotFor(selection.productId);
      byCategory[category] = TutorialInstruction(
        category: category,
        placement: selection.placement,
        // Kit mode's finish/intensity are copied verbatim from a real
        // product's inventory fields (validated server-side to match —
        // see generate-kit-makeup-recommendation/validation.ts), i.e. a
        // small, controlled lowercase vocabulary ("satin", "soft"), not
        // free AI prose. Humanized here to match the display convention
        // this same data already has in `kit_result_product_card.dart`
        // (task 7). Standard mode's finish/intensity are left as-is below
        // — they're free-text AI output, and `recommendation_item_card.dart`
        // never humanizes them either, so matching that source's own
        // existing convention means *not* transforming them.
        intensity: _humanize(selection.intensity),
        technique: selection.technique,
        productName: snapshot.productName,
        colorName: snapshot.colorLabel,
        hex: selection.colorHex,
        finish: _humanize(selection.finish),
        // Foundation depth/undertone are real snapshot facts already
        // surfaced in the kit's own result UI (`kit_result_product_card.dart`)
        // but had no home in `TutorialInstruction`'s structured fields —
        // folded into `tip` rather than fabricating a new field, and only
        // when the snapshot actually carries them (task 5/8: real
        // structured data, never invented for categories that don't have it).
        tip: _foundationTip(snapshot),
      );
    }
    return _buildPlan(
      byCategory,
      reusableResultImagePath: preview.generatedImagePath,
      reusableResultImageUrl: preview.generatedImageUrl,
      reusableModelId: preview.modelId,
      reusablePromptVersion: preview.promptVersion,
    );
  }

  static TutorialPlan _buildPlan(
    Map<TutorialStepCategory, TutorialInstruction> byCategory, {
    required String reusableResultImagePath,
    required String reusableResultImageUrl,
    required String reusableModelId,
    required String reusablePromptVersion,
  }) {
    final orderedCategories = _canonicalOrder
        .where(byCategory.containsKey)
        .toList(growable: false);

    if (orderedCategories.isEmpty) {
      return const TutorialPlan(steps: [], reusesFinalPreview: false);
    }

    final steps = <PlannedTutorialStep>[
      for (final (index, category) in orderedCategories.indexed)
        PlannedTutorialStep(
          stepNumber: index + 1,
          category: category,
          title: _title(category),
          instruction: byCategory[category]!,
          placementMetadata: TutorialPlacementOverlayCatalog.defaultFor(
            category,
          ),
        ),
      PlannedTutorialStep(
        stepNumber: orderedCategories.length + 1,
        category: TutorialStepCategory.finalLook,
        title: _title(TutorialStepCategory.finalLook),
        instruction: TutorialInstruction(
          category: TutorialStepCategory.finalLook,
          placement: 'Complete look',
          intensity: 'as applied',
          technique: 'Review the finished, fully blended result.',
        ),
        placementMetadata: TutorialPlacementOverlayCatalog.defaultFor(
          TutorialStepCategory.finalLook,
        ),
        reusableResultImagePath: reusableResultImagePath,
        reusableResultImageUrl: reusableResultImageUrl,
        reusableModelId: reusableModelId,
        reusablePromptVersion: reusablePromptVersion,
      ),
    ];

    return TutorialPlan(steps: steps, reusesFinalPreview: true);
  }

  static String _title(TutorialStepCategory category) =>
      _humanize(category.code);

  /// Title-cases an underscore/lowercase code (`'contour_bronzer'` →
  /// `'Contour Bronzer'`). Only ever applied to *codes* — small, controlled
  /// vocabularies (category codes, kit finish/intensity, foundation
  /// depth/undertone) — never to free AI-generated prose, which is passed
  /// through unchanged so nothing here rewrites the model's own wording.
  static String _humanize(String code) => code
      .split('_')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');

  /// Surfaces [KitProductSnapshot.foundationDepth]/[foundationUndertone] —
  /// real owned-product facts with no dedicated [TutorialInstruction]
  /// field — as a short, honest tip. Returns null (never a placeholder
  /// string) when the snapshot carries neither, which is the normal case
  /// for every category except foundation.
  static String? _foundationTip(KitProductSnapshot snapshot) {
    final parts = [
      if (snapshot.foundationDepth != null)
        '${_humanize(snapshot.foundationDepth!)} depth',
      if (snapshot.foundationUndertone != null)
        '${_humanize(snapshot.foundationUndertone!)} undertone',
    ];
    if (parts.isEmpty) return null;
    return 'Registered in your kit as ${parts.join(', ')}.';
  }
}
