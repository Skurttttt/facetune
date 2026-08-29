import '../../../analysis/domain/entities/facial_attributes.dart';
import 'tutorial_v2_plan_version.dart';
import 'tutorial_v2_source_mode.dart';

/// Which persisted recommendation a tutorial teaches.
///
/// Exactly one id is set, and it must match [sourceMode]. This mirrors the
/// exactly-one-source check the remote `tutorial_sessions` table already
/// enforces (see `docs/tutorial_v2/V2-0_BASELINE_AUDIT.md` §5.1), so the
/// domain cannot construct a shape persistence would reject.
class TutorialV2RecommendationRef {
  const TutorialV2RecommendationRef.standard(this.recommendationId)
    : kitRecommendationId = null,
      assert(recommendationId != null, 'A standard reference needs an id.');

  const TutorialV2RecommendationRef.kit(this.kitRecommendationId)
    : recommendationId = null,
      assert(kitRecommendationId != null, 'A Kit reference needs an id.');

  final String? recommendationId;
  final String? kitRecommendationId;

  TutorialV2SourceMode get sourceMode => kitRecommendationId != null
      ? TutorialV2SourceMode.makeupKit
      : TutorialV2SourceMode.standardRecommendation;

  /// The id that is actually set, whichever mode this is.
  String get id => (kitRecommendationId ?? recommendationId)!;

  @override
  bool operator ==(Object other) =>
      other is TutorialV2RecommendationRef &&
      other.recommendationId == recommendationId &&
      other.kitRecommendationId == kitRecommendationId;

  @override
  int get hashCode => Object.hash(recommendationId, kitRecommendationId);
}

/// A pointer to the already-generated premium final preview the tutorial
/// converges on.
///
/// The canonical preview is a persisted row, not a bare file: standard looks
/// live in `generated_images`, Kit looks in `kit_generated_images`. Both the
/// row id and its storage path are carried so the final step can reuse the
/// existing asset without regenerating anything (Source of Truth §6).
class TutorialV2CanonicalFinalPreview {
  const TutorialV2CanonicalFinalPreview({
    required this.generatedImageId,
    required this.storagePath,
    required this.sourceMode,
  });

  /// `generated_images.id` in standard mode, `kit_generated_images.id` in
  /// Kit mode.
  final String generatedImageId;

  final String storagePath;
  final TutorialV2SourceMode sourceMode;

  @override
  bool operator ==(Object other) =>
      other is TutorialV2CanonicalFinalPreview &&
      other.generatedImageId == generatedImageId &&
      other.storagePath == storagePath &&
      other.sourceMode == sourceMode;

  @override
  int get hashCode => Object.hash(generatedImageId, storagePath, sourceMode);
}

/// The session-level context every step of one tutorial shares.
///
/// These values are held once per plan rather than copied onto each step.
/// Denormalising them per step would create a real drift vector — a step
/// claiming a different style or a different canonical target than its own
/// session — which is exactly what the single-source-per-step rule exists to
/// prevent. Generation code consumes a `TutorialV2ResolvedStep`, which binds
/// this context to one step spec, so a step still carries everything needed
/// to drive text, guideline and result.
class TutorialV2PlanContext {
  const TutorialV2PlanContext({
    required this.sourceMode,
    required this.styleCode,
    required this.faceAttributes,
    required this.recommendation,
    required this.canonicalFinalPreview,
    this.planVersion = TutorialV2PlanVersion.current,
  });

  final TutorialV2SourceMode sourceMode;

  /// The persisted style code — `MakeupStyle.code`, the same snake_case value
  /// stored in `recommendations.makeup_style`. Never a parallel style source.
  final String styleCode;

  final FacialAttributes faceAttributes;
  final TutorialV2RecommendationRef recommendation;
  final TutorialV2CanonicalFinalPreview canonicalFinalPreview;
  final TutorialV2PlanVersion planVersion;
}
