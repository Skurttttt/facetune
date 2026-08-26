import 'tutorial_v3_canonical_preview.dart';
import 'tutorial_v3_session_status.dart';
import 'tutorial_v3_source_mode.dart';
import '../value_objects/tutorial_v3_plan_version.dart';

/// One user's tutorial for one analysis and one selected look.
///
/// The session binds together everything a plan was built from: the owner,
/// the analysis whose original selfie every guideline starts from, the
/// persisted recommendation that fixed the selected look, and the canonical
/// premium preview the tutorial drives toward.
///
/// Exactly one recommendation identifier is set, chosen by [sourceMode]:
/// standard sessions carry [recommendationId] and Kit sessions carry
/// [kitRecommendationId], because those are separate tables.
class TutorialV3Session {
  const TutorialV3Session({
    required this.id,
    required this.userId,
    required this.analysisId,
    required this.sourceMode,
    required this.selectedStyleCode,
    required this.canonicalPreview,
    required this.totalSteps,
    required this.planVersion,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.recommendationId,
    this.kitRecommendationId,
  });

  final String id;

  /// The owner. Every guideline asset path for this session begins with it.
  final String userId;

  /// The analysis whose original selfie is the base image for every
  /// non-final step.
  final String analysisId;

  final TutorialV3SourceMode sourceMode;

  /// The `recommendations` row, set only in standard mode.
  final String? recommendationId;

  /// The `kit_makeup_recommendations` row, set only in Kit mode.
  final String? kitRecommendationId;

  /// The persisted `makeup_style` code of that recommendation.
  final String selectedStyleCode;

  /// The existing premium preview this tutorial targets.
  final TutorialV3CanonicalPreview canonicalPreview;

  /// The persisted plan length. Must equal the number of persisted steps.
  final int totalSteps;

  final TutorialV3PlanVersion planVersion;
  final TutorialV3SessionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The recommendation identifier for this session's mode.
  String? get activeRecommendationId =>
      sourceMode.isKit ? kitRecommendationId : recommendationId;
}
