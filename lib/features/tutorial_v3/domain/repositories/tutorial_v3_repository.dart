import '../entities/tutorial_v3_canonical_preview.dart';
import '../entities/tutorial_v3_plan.dart';
import '../entities/tutorial_v3_session_snapshot.dart';
import '../entities/tutorial_v3_source_mode.dart';
import '../entities/tutorial_v3_step.dart';

/// Everything needed to identify the tutorial for one selected look.
///
/// The canonical premium preview is the natural key: it *is* the tutorial's
/// destination, so two requests for the same preview describe the same
/// tutorial.
class TutorialV3SessionRequest {
  const TutorialV3SessionRequest({
    required this.analysisId,
    required this.sourceMode,
    required this.selectedStyleCode,
    required this.canonicalPreview,
    this.recommendationId,
    this.kitRecommendationId,
  });

  final String analysisId;
  final TutorialV3SourceMode sourceMode;

  /// The persisted `makeup_style` of the recommendation, never client UI
  /// state.
  final String selectedStyleCode;

  final TutorialV3CanonicalPreview canonicalPreview;

  /// Set in standard mode only.
  final String? recommendationId;

  /// Set in Kit mode only.
  final String? kitRecommendationId;
}

/// What happened when a step was prepared for guideline generation.
enum TutorialV3GuidelineOutcome {
  /// The step already had a validated guideline, which was returned
  /// untouched. No generation should run and no quota should be spent.
  reusedExisting('reused_existing'),

  /// The step was claimed and is now `generating`. The caller owns that
  /// claim and must finish it with a success or a failure.
  claimedForGeneration('claimed_for_generation');

  const TutorialV3GuidelineOutcome(this.code);

  final String code;
}

/// The result of preparing one step.
class TutorialV3GuidelinePreparation {
  const TutorialV3GuidelinePreparation({
    required this.session,
    required this.stepIndex,
    required this.outcome,
  });

  final TutorialV3LoadedSession session;
  final int stepIndex;
  final TutorialV3GuidelineOutcome outcome;

  TutorialV3Step get step => session.stepAt(stepIndex)!;

  /// Whether the caller must actually generate an image.
  bool get requiresGeneration =>
      outcome == TutorialV3GuidelineOutcome.claimedForGeneration;
}

/// The V3 tutorial persistence and session lifecycle.
///
/// Nothing here generates anything — planning and image generation belong to
/// later phases. This layer's job is to make a revisited tutorial reuse what
/// is already persisted: a reopened tutorial loads the stored plan and the
/// stored guidelines, and only what is genuinely missing is left for a
/// generation phase to fill in.
///
/// There is deliberately no cumulative-result machinery. V3 has one asset per
/// step and no per-step makeup appearance, so there is no result lifecycle to
/// advance, no "previous result" to carry forward, and no dependency between
/// one step's state and the next.
abstract interface class TutorialV3Repository {
  /// Loads the tutorial for [request]'s canonical preview, creating an empty
  /// session if none exists yet.
  ///
  /// Idempotent: the canonical preview plus the plan version is the natural
  /// key, so calling this twice returns the same session rather than starting
  /// a second tutorial for the same look.
  ///
  /// A session this build cannot interpret comes back as
  /// [TutorialV3IncompatibleSession] rather than throwing, so a reopened
  /// tutorial can report that state instead of failing to load.
  Future<TutorialV3SessionSnapshot> getOrCreateSession(
    TutorialV3SessionRequest request,
  );

  /// Loads one session by id, or `null` when the caller does not own a
  /// session with that id.
  Future<TutorialV3SessionSnapshot?> findSessionById(String sessionId);

  /// Stores a validated plan against an existing session.
  ///
  /// The plan is validated again before it is written, and the whole write is
  /// atomic: a replan cannot leave a session claiming a plan with a partial
  /// or interleaved step set.
  Future<TutorialV3LoadedSession> persistPlan({
    required String sessionId,
    required TutorialV3Plan plan,
    String? plannerModel,
    String? plannerPromptVersion,
  });

  /// Records that planning failed, leaving the session resumable.
  Future<TutorialV3LoadedSession> markPlanFailed({
    required String sessionId,
    required String error,
  });

  /// Prepares one step for guideline generation.
  ///
  /// A step that is already `ready` is returned untouched with
  /// [TutorialV3GuidelineOutcome.reusedExisting], so revisiting a tutorial
  /// never regenerates work that already exists. Otherwise the step is
  /// claimed by moving it to `generating`, which is what prevents two
  /// concurrent callers generating the same `(sessionId, stepIndex)`.
  ///
  /// Refuses a step that is already in flight, a step that has exhausted its
  /// bounded retries, and the final-look step, which generates nothing.
  Future<TutorialV3GuidelinePreparation> prepareGuideline({
    required String sessionId,
    required int stepIndex,
  });

  /// Records that a step's guideline generation failed.
  ///
  /// The Step Spec is left intact and the attempt count is incremented so a
  /// bounded retry is possible. No placeholder asset is ever attached.
  Future<TutorialV3LoadedSession> markGuidelineFailed({
    required String sessionId,
    required int stepIndex,
    required String error,
  });

  /// Attaches a generated guideline to a step and marks it ready.
  ///
  /// [storagePath] must be an owner-scoped path for exactly this session and
  /// step; anything else is rejected rather than persisted, so one step can
  /// never be given another step's or another user's asset.
  Future<TutorialV3LoadedSession> persistGuideline({
    required String sessionId,
    required int stepIndex,
    required String storagePath,
    String? modelName,
    String? promptVersion,
  });

  /// A short-lived signed URL for a private asset.
  Future<String> createSignedUrl(String storagePath);
}
