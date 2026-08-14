import '../entities/tutorial_generation_status.dart';
import '../entities/tutorial_instruction.dart';
import '../entities/tutorial_placement_metadata.dart';
import '../entities/tutorial_session.dart';
import '../entities/tutorial_source_mode.dart';
import '../entities/tutorial_step.dart';

/// Domain contract for loading, persisting, and resuming Step-by-Step
/// Tutorials, backed by `tutorial_sessions`/`tutorial_steps`
/// (supabase/migrations/20260814000300_tutorial_sessions_steps.sql).
///
/// No implementation here calls Gemini or any Edge Function — every method
/// is plain persistence. Planning (deciding step count/order/categories)
/// and image generation are later phases' responsibility; this interface
/// only gives them somewhere typed to write to and read from.
///
/// Ownership: no method accepts a `userId` parameter. Implementations must
/// derive the owner from the authenticated Supabase session (never from a
/// caller-supplied value), and Row Level Security enforces the same rule
/// server-side regardless — see ARCHITECTURE_NOTES.md.
abstract interface class TutorialRepository {
  /// Returns the existing tutorial session (with its steps, in step-number
  /// order) for the given source and generation number, or `null` if none
  /// has been generated yet. Callers must not create a new session when a
  /// valid one already exists (guide §12).
  ///
  /// Exactly one of [recommendationId] / [kitRecommendationId] must be
  /// provided, matching [sourceMode].
  Future<TutorialSession?> loadExisting({
    required TutorialSourceMode sourceMode,
    required String analysisId,
    String? recommendationId,
    String? kitRecommendationId,
    required int generationNumber,
  });

  /// Creates a new tutorial session row. Does not create any steps or start
  /// generation — see [createStep].
  Future<TutorialSession> createSession({
    required TutorialSourceMode sourceMode,
    required String analysisId,
    String? recommendationId,
    String? kitRecommendationId,
    required String styleCode,
    required int generationNumber,
    required int totalSteps,
    String? tutorialModel,
    int? tutorialImageSize,
    String? promptVersion,
  });

  /// Loads every step of [tutorialSessionId], ordered by step number.
  Future<List<TutorialStep>> loadSteps(String tutorialSessionId);

  /// Creates the row for one planned step, before any image exists for it.
  Future<TutorialStep> createStep({
    required String tutorialSessionId,
    required int stepNumber,
    required String title,
    required TutorialInstruction instruction,
    TutorialPlacementMetadata? placementMetadata,
  });

  /// Persists a step's placement/result image references and AI metadata
  /// once generation (a later phase) produces them. Only non-null
  /// arguments are written, so a caller can update one field (e.g. just
  /// `resultImagePath` after a Gemini call completes) without clobbering
  /// the others.
  Future<TutorialStep> updateStepImages({
    required String tutorialStepId,
    String? placementImagePath,
    String? resultImagePath,
    String? modelId,
    int? imageSize,
    String? promptVersion,
  });

  /// Updates the generation status of an entire session.
  Future<TutorialSession> updateSessionStatus({
    required String tutorialSessionId,
    required TutorialGenerationStatus status,
  });

  /// Updates the generation status of a single step, supporting per-step
  /// retry without regenerating the whole session (guide §14).
  Future<TutorialStep> updateStepStatus({
    required String tutorialStepId,
    required TutorialStepGenerationStatus status,
  });
}
