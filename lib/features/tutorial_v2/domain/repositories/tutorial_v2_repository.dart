import '../entities/tutorial_v2_generation_status.dart';
import '../entities/tutorial_v2_plan.dart';
import '../entities/tutorial_v2_plan_context.dart';
import '../entities/tutorial_v2_session_snapshot.dart';

/// The V2 tutorial data layer.
///
/// Nothing here generates anything. The repository's job is to make a
/// revisited tutorial reuse what is already persisted: a reopened page loads
/// the stored plan and the stored assets, and only what is genuinely missing
/// is left for a generation phase to fill in.
abstract interface class TutorialV2Repository {
  /// Loads the tutorial for [context]'s canonical final preview, creating an
  /// empty session if none exists yet.
  ///
  /// Idempotent: the canonical preview plus the plan version is the natural
  /// key, so calling this twice returns the same session rather than starting
  /// a second tutorial for the same look.
  ///
  /// A session that is stale or version-incompatible is returned as-is with
  /// that readiness rather than being silently repaired or rewritten — the
  /// caller decides whether to replan.
  Future<TutorialV2SessionSnapshot> getOrCreateSession({
    required String analysisId,
    required TutorialV2PlanContext context,
  });

  /// Loads one session by id, or `null` when the caller does not own a
  /// session with that id.
  Future<TutorialV2SessionSnapshot?> findSessionById(String sessionId);

  /// Stores a validated plan against an existing session.
  ///
  /// Replaces any previously persisted steps for the session, so a replan
  /// after a failure cannot leave two generations of steps interleaved.
  Future<TutorialV2SessionSnapshot> persistPlan({
    required String sessionId,
    required TutorialV2Plan plan,
    String? plannerModel,
    String? plannerPromptVersion,
  });

  /// Records that planning failed, leaving the session resumable.
  Future<TutorialV2SessionSnapshot> markPlanFailed({
    required String sessionId,
    required String error,
  });

  /// Moves one asset of one step through its generation lifecycle.
  ///
  /// Passing [TutorialV2GenerationStatus.failed] records [error] and
  /// increments the step's retry count.
  Future<TutorialV2SessionSnapshot> updateAssetStatus({
    required String sessionId,
    required int stepIndex,
    required TutorialV2AssetKind asset,
    required TutorialV2GenerationStatus status,
    String? error,
  });

  /// Attaches a generated asset to a step and marks it ready.
  ///
  /// [storagePath] must be an owner-scoped path for exactly this session,
  /// step and asset kind; anything else is rejected rather than persisted.
  Future<TutorialV2SessionSnapshot> persistAsset({
    required String sessionId,
    required int stepIndex,
    required TutorialV2AssetKind asset,
    required String storagePath,
    String? modelName,
    String? promptVersion,
  });

  /// Generates the personalized guideline image for one step.
  ///
  /// Idempotent: a step whose guideline is already `ready` with a stored path
  /// is returned untouched rather than regenerated, so reopening a tutorial
  /// never re-spends image quota. The server holds the authoritative claim, so
  /// two concurrent callers cannot both generate the same asset.
  ///
  /// On failure the step's guideline is marked failed and the written Step
  /// Spec remains available — no placeholder graphic is ever produced.
  Future<TutorialV2SessionSnapshot> generateGuideline({
    required String sessionId,
    required int stepIndex,
  });

  /// A short-lived signed URL for a private asset.
  Future<String> createSignedUrl(String storagePath);
}
