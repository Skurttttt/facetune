import '../entities/personalized_tutorial.dart';
import '../entities/tutorial_face_geometry.dart';
import '../entities/tutorial_geometry_plan.dart';
import '../entities/tutorial_placement_metadata.dart';
import '../entities/tutorial_step.dart';
import '../entities/tutorial_step_category.dart';

/// Maps a session's persisted TF-2 Gemini geometry & placement plan onto its
/// already-planned steps' placement metadata (TF-3 — "Production
/// Personalized Guideline Activation").
///
/// Pure and synchronous: no AI call, no persistence of its own, and nothing
/// here decides *what* to draw for a category — that was Gemini's real,
/// photo-grounded decision, already strictly validated server-side
/// (`plan-tutorial-geometry`). This only projects it into
/// [TutorialPlacementOverlay] primitives the existing, unchanged renderer
/// (`TutorialPlacementOverlayLayer`, ST-6) already knows how to draw.
///
/// Applied every time a session is hydrated from a row
/// (`TutorialSessionDto.fromRow`) rather than persisted back to
/// `tutorial_steps.placement_metadata_json` — the two inputs (a step's own
/// category, and the session's geometry plan) are already both persisted,
/// so re-deriving this on every load is free and can never drift out of
/// sync with a stale cached value.
abstract final class TutorialGeometryActivation {
  /// A primitive below this confidence is dropped even when its category
  /// overall clears the render threshold — the same floor as the
  /// medium-confidence bucket, so no single primitive is ever trusted more
  /// than the category-level bucket it belongs to.
  static const _minimumPrimitiveConfidence = 0.55;

  static List<TutorialStep> applyToSteps(
    List<TutorialStep> steps,
    TutorialGeometryPlan? geometryPlan,
  ) {
    if (geometryPlan == null) return steps;
    return [for (final step in steps) applyToStep(step, geometryPlan)];
  }

  static TutorialStep applyToStep(
    TutorialStep step,
    TutorialGeometryPlan geometryPlan,
  ) {
    if (step.category == TutorialStepCategory.finalLook) return step;
    final categoryPlan = geometryPlan.forCategory(step.category);
    if (categoryPlan == null) return step;
    final overlays = _overlaysFor(categoryPlan);
    // No fake guides (TF-3's explicit rule): when the real plan for this
    // category is too low-confidence, or every one of its primitives is
    // individually too weak, the step's existing placement metadata is
    // left untouched rather than being replaced with something empty and
    // worse than what it already had.
    if (overlays.isEmpty) return step;
    return _withPlacementMetadata(
      step,
      TutorialPlacementMetadata(overlays: overlays),
    );
  }

  static List<TutorialPlacementOverlay> _overlaysFor(
    TutorialCategoryGeometryPlan plan,
  ) {
    final bucket = _confidenceBucket(plan.confidence);
    if (bucket == TutorialPlacementConfidence.low) return const [];
    // Medium confidence: broader/simpler guidance only, matching the
    // source of truth's "MEDIUM → broader/simpler overlays" rule and
    // mirroring `PersonalizedTutorialOverlayAccuracyValidator`'s own
    // medium-confidence de-duplication — at most one arrow per category,
    // so a moderately-confident plan never shows conflicting directions.
    final simplify = bucket == TutorialPlacementConfidence.medium;
    final overlays = <TutorialPlacementOverlay>[];
    for (final zone in plan.zones) {
      if (zone.confidence < _minimumPrimitiveConfidence) continue;
      overlays.add(
        TutorialPlacementOverlay(
          type: TutorialPlacementOverlayType.zone,
          points: _points(zone.points),
          colorHex: plan.colorHex,
        ),
      );
    }
    for (final path in plan.paths) {
      if (path.confidence < _minimumPrimitiveConfidence) continue;
      overlays.add(
        TutorialPlacementOverlay(
          type: TutorialPlacementOverlayType.line,
          points: _points(path.points),
          colorHex: plan.colorHex,
        ),
      );
    }
    var arrowsAdded = 0;
    for (final arrow in plan.arrows) {
      if (arrow.confidence < _minimumPrimitiveConfidence) continue;
      if (simplify && arrowsAdded >= 1) continue;
      overlays.add(
        TutorialPlacementOverlay(
          type: TutorialPlacementOverlayType.arrow,
          points: [
            TutorialPlacementPoint(arrow.from.x, arrow.from.y),
            TutorialPlacementPoint(arrow.to.x, arrow.to.y),
          ],
        ),
      );
      arrowsAdded += 1;
    }
    return overlays;
  }

  static List<TutorialPlacementPoint> _points(
    List<TutorialNormalizedPoint> points,
  ) => [for (final point in points) TutorialPlacementPoint(point.x, point.y)];

  static TutorialPlacementConfidence _confidenceBucket(double score) {
    if (score >= 0.8) return TutorialPlacementConfidence.high;
    if (score >= 0.55) return TutorialPlacementConfidence.medium;
    return TutorialPlacementConfidence.low;
  }

  static TutorialStep _withPlacementMetadata(
    TutorialStep step,
    TutorialPlacementMetadata placementMetadata,
  ) => TutorialStep(
    id: step.id,
    tutorialSessionId: step.tutorialSessionId,
    stepNumber: step.stepNumber,
    category: step.category,
    title: step.title,
    instruction: step.instruction,
    placementMetadata: placementMetadata,
    personalizedSpec: step.personalizedSpec,
    placementImagePath: step.placementImagePath,
    placementImageUrl: step.placementImageUrl,
    resultImagePath: step.resultImagePath,
    resultImageUrl: step.resultImageUrl,
    modelId: step.modelId,
    imageSize: step.imageSize,
    promptVersion: step.promptVersion,
    generationStatus: step.generationStatus,
    createdAt: step.createdAt,
    updatedAt: step.updatedAt,
  );
}
