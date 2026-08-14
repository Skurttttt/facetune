import '../entities/tutorial_generation_status.dart';
import '../entities/tutorial_instruction.dart';
import '../entities/personalized_tutorial.dart';
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
    PersonalizedTutorialStepSpec? personalizedSpec,
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

  /// Calls the secure backend (`generate-tutorial-step`, ST-9) to generate
  /// [tutorialStepId]'s Result image via Gemini, then returns the updated
  /// step with fresh signed URLs.
  ///
  /// The backend already no-ops safely and cheaply for a step that already
  /// has a result (it returns the existing row without calling Gemini
  /// again), so this is not itself unsafe to call twice — but callers
  /// should still avoid calling it for an already-completed step, as a
  /// network-cost optimization (roadmap ST-10 task 3), not a correctness
  /// requirement. Similarly, the backend rejects generating a step out of
  /// cumulative order (its previous step's result must exist first); this
  /// method surfaces that as a normal [TutorialFailure], it does not
  /// pre-validate ordering client-side.
  Future<TutorialStep> generateStepResult({required String tutorialStepId});

  /// Resets every non-final step of [tutorialSessionId] back to its
  /// pre-generation state — clears `placementImagePath`/`resultImagePath`/
  /// AI metadata and returns `generationStatus` to `notStarted` — and
  /// resets the session's own status the same way, so the user can
  /// regenerate every step from scratch via the same explicit per-step
  /// "Generate this step" flow a brand-new tutorial uses (roadmap ST-12).
  ///
  /// The final "complete look" step is left untouched: it reuses the
  /// existing final preview and was never generated by this feature in
  /// the first place (see `TutorialPlan.reusesFinalPreview`), so there is
  /// nothing about it to regenerate.
  ///
  /// This replaces the session's own generated content in place — it does
  /// not create a second session. See ARCHITECTURE_NOTES.md's ST-12
  /// section for why: `tutorial_sessions` has at most one row per
  /// `(recommendation, generationNumber)` pair, so a genuinely separate
  /// "new version" is only possible by generating a new source-look
  /// variation first (which already gets its own, independent tutorial
  /// session once requested).
  Future<TutorialSession> resetForRegeneration({
    required String tutorialSessionId,
  });
}
