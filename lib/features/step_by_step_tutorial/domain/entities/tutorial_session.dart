import 'tutorial_generation_status.dart';
import 'tutorial_geometry_plan.dart';
import 'tutorial_source_mode.dart';
import 'tutorial_step.dart';

/// A generated, persisted Step-by-Step Tutorial for one look.
///
/// Exactly one of [sourceRecommendationId] / [sourceKitResultId] is set,
/// matching [sourceMode]. Both are nullable rather than modeled as a sealed
/// union because the current codebase's data layer (DTOs, Supabase rows)
/// represents optional foreign keys as nullable columns throughout — see
/// `KitGeneratedPreview` / `GeneratedPreview` for the precedent. A later
/// phase may promote this to a sealed type if presentation logic needs it.
class TutorialSession {
  const TutorialSession({
    required this.id,
    required this.userId,
    required this.sourceMode,
    required this.sourceAnalysisId,
    required this.styleCode,
    required this.generationNumber,
    required this.totalSteps,
    required this.generationStatus,
    required this.steps,
    required this.createdAt,
    required this.updatedAt,
    this.sourceRecommendationId,
    this.sourceKitResultId,
    this.promptVersion,
    this.tutorialModel,
    this.tutorialImageSize,
    this.geometryPlan,
    this.geometryPlanVersion,
    this.geometryModel,
  });

  final String id;
  final String userId;
  final TutorialSourceMode sourceMode;
  final String sourceAnalysisId;

  /// Set when [sourceMode] is [TutorialSourceMode.standardRecommendation].
  final String? sourceRecommendationId;

  /// Set when [sourceMode] is [TutorialSourceMode.makeupKit].
  final String? sourceKitResultId;

  final String styleCode;

  /// The source preview's generation number (matches
  /// `GeneratedPreview.generationNumber` / `KitGeneratedPreview.generationNumber`),
  /// so a regenerated source look does not silently reattach an unrelated
  /// tutorial (guide §12).
  final int generationNumber;

  final int totalSteps;

  /// Server-configured AI settings echoed for display/debugging only — see
  /// ARCHITECTURE_NOTES.md for why these must never be read as config by
  /// client code.
  final String? promptVersion;
  final String? tutorialModel;
  final int? tutorialImageSize;

  /// TF-2's validated, persisted tutorial-only Gemini geometry & placement
  /// plan — `null` until planned. [TutorialGeometryActivation] (TF-3) has
  /// already projected it onto [steps]' own [TutorialStep.placementMetadata]
  /// by the time this session is hydrated; this field is kept for
  /// display/debugging and so a caller can tell whether planning has
  /// happened yet without inspecting every step.
  final TutorialGeometryPlan? geometryPlan;

  /// Same display/debugging-only convention as [promptVersion]/
  /// [tutorialModel] — never read as client configuration.
  final String? geometryPlanVersion;
  final String? geometryModel;

  final TutorialGenerationStatus generationStatus;
  final List<TutorialStep> steps;
  final DateTime createdAt;
  final DateTime updatedAt;
}
