import 'tutorial_generation_status.dart';
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

  final TutorialGenerationStatus generationStatus;
  final List<TutorialStep> steps;
  final DateTime createdAt;
  final DateTime updatedAt;
}
