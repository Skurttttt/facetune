import '../entities/tutorial_v3_geometry.dart';
import '../entities/tutorial_v3_plan.dart';
import '../entities/tutorial_v3_session.dart';
import '../entities/tutorial_v3_session_images.dart';
import '../entities/tutorial_v3_session_snapshot.dart';
import '../entities/tutorial_v3_source_mode.dart';
import '../entities/tutorial_v3_step.dart';

/// Where a tutorial is being started from.
///
/// **One identifier, and nothing else.** The premium final preview is the
/// tutorial's destination and its natural key, so naming it is enough: the
/// analysis, the recommendation, the selected style and the preview's storage
/// path are all resolved server-side from rows RLS has already scoped to the
/// caller.
///
/// This replaced a client-assembled request that carried all of those. A
/// caller that can choose a tutorial's analysis or its canonical image path
/// can point a tutorial at something it was never meant to teach, and no
/// amount of client-side validation makes that safe.
class TutorialV3EntryPoint {
  const TutorialV3EntryPoint({
    required this.canonicalImageId,
    required this.sourceMode,
  });

  /// The `generated_images` row id (standard) or `kit_generated_images` row id
  /// (Kit), chosen by [sourceMode].
  final String canonicalImageId;

  final TutorialV3SourceMode sourceMode;

  bool get isKit => sourceMode.isKit;
}

/// What happened when a step was prepared for geometry mapping.
enum TutorialV3GeometryOutcome {
  /// The step already held validated geometry, returned untouched. No mapping
  /// should run and no quota should be spent.
  reusedExisting('reused_existing'),

  /// The step was claimed and is now `generating`. The caller owns that claim
  /// and must finish it with a success or a failure.
  claimedForGeneration('claimed_for_mapping'),

  /// The step held geometry written under a different schema version. It was
  /// discarded and claimed for fresh mapping — never reused and never
  /// rendered, because this build cannot interpret that vocabulary.
  claimedAfterStaleGeometry('claimed_after_stale_geometry');

  const TutorialV3GeometryOutcome(this.code);

  final String code;
}

/// The result of preparing one step.
class TutorialV3GeometryPreparation {
  const TutorialV3GeometryPreparation({
    required this.session,
    required this.stepIndex,
    required this.outcome,
  });

  final TutorialV3LoadedSession session;
  final int stepIndex;
  final TutorialV3GeometryOutcome outcome;

  TutorialV3Step get step => session.stepAt(stepIndex)!;

  /// Whether the caller must actually run the mapper.
  bool get requiresMapping =>
      outcome != TutorialV3GeometryOutcome.reusedExisting;

  /// Whether a document from an incompatible schema version was discarded to
  /// get here. Worth surfacing: it is the one case where a step that looked
  /// complete has to be mapped again.
  bool get replacedStaleGeometry =>
      outcome == TutorialV3GeometryOutcome.claimedAfterStaleGeometry;
}

/// The V3 tutorial persistence and session lifecycle.
///
/// This layer's job is to make a revisited tutorial reuse what is already
/// persisted: a reopened tutorial loads the stored plan and the stored
/// geometry, and only what is genuinely missing is mapped again.
///
/// V3 stores coordinates, not pixels. There is no image path, no storage
/// object per step, and no cumulative-result machinery — no per-step makeup
/// appearance exists to advance, carry forward, or depend on.
abstract interface class TutorialV3Repository {
  /// Opens the tutorial for [entry]'s canonical preview, creating an empty
  /// session if none exists yet.
  ///
  /// The only supported way to start a V3 tutorial. Resolution happens
  /// server-side, so the caller cannot choose the analysis, the recommendation,
  /// the selected style or the preview's storage path.
  ///
  /// Idempotent: the canonical preview is the natural key, so calling this
  /// twice returns the same session rather than starting a second tutorial for
  /// the same look.
  ///
  /// A session this build cannot interpret comes back as
  /// [TutorialV3IncompatibleSession] rather than throwing, so a reopened
  /// tutorial can report that state instead of failing to load.
  Future<TutorialV3SessionSnapshot> openSession(TutorialV3EntryPoint entry);

  /// Loads one session by id, or `null` when the caller does not own a
  /// session with that id.
  Future<TutorialV3SessionSnapshot?> findSessionById(String sessionId);

  /// Stores a validated plan against an existing session.
  ///
  /// The plan is validated again before it is written, and the whole write is
  /// atomic: a replan cannot leave a session claiming a plan with a partial or
  /// interleaved step set.
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

  /// Prepares one step for geometry mapping.
  ///
  /// A step that already holds compatible geometry is returned untouched with
  /// [TutorialV3GeometryOutcome.reusedExisting], so revisiting a tutorial
  /// never re-spends quota. Otherwise the step is claimed atomically, which is
  /// what prevents two concurrent callers mapping the same
  /// `(sessionId, stepIndex)`.
  ///
  /// Refuses a step already in flight, a step that has exhausted its bounded
  /// retries, and the final-look step, which maps nothing.
  Future<TutorialV3GeometryPreparation> prepareGeometry({
    required String sessionId,
    required int stepIndex,
  });

  /// Records that a step's geometry mapping failed.
  ///
  /// The Step Spec is left intact and the attempt count is incremented so a
  /// bounded retry is possible. No partial or placeholder geometry is stored:
  /// a missing overlay shows as missing.
  Future<TutorialV3LoadedSession> markGeometryFailed({
    required String sessionId,
    required int stepIndex,
    required String error,
  });

  /// Attaches validated geometry to a step and marks it ready.
  ///
  /// [geometry] must already have passed `TutorialV3GeometryValidator`, and
  /// its category must match the step's persisted Step Spec — geometry
  /// describing a different category is rejected rather than stored.
  Future<TutorialV3LoadedSession> persistGeometry({
    required String sessionId,
    required int stepIndex,
    required TutorialV3Geometry geometry,
    String? modelName,
    String? promptVersion,
  });

  /// Signed URLs for the two images the tutorial screen displays.
  ///
  /// The original selfie's path is resolved from the session's analysis
  /// rather than accepted from the caller, so a tutorial can only ever show
  /// the photograph its own plan was built from.
  Future<TutorialV3SessionImages> loadImages(TutorialV3Session session);

  /// A short-lived signed URL for a private asset.
  ///
  /// Still used for the original selfie and the canonical preview, which are
  /// real stored images. Geometry itself is never a stored object.
  Future<String> createSignedUrl(String storagePath);
}
