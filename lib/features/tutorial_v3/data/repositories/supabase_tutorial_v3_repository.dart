import '../../domain/entities/tutorial_v3_geometry.dart';
import '../../domain/entities/tutorial_v3_geometry_status.dart';
import '../../domain/entities/tutorial_v3_plan.dart';
import '../../domain/entities/tutorial_v3_session.dart';
import '../../domain/entities/tutorial_v3_session_images.dart';
import '../../domain/entities/tutorial_v3_session_snapshot.dart';
import '../../domain/entities/tutorial_v3_session_status.dart';
import '../../domain/entities/tutorial_v3_step.dart';
import '../../domain/errors/tutorial_v3_failure.dart';
import '../../domain/repositories/tutorial_v3_repository.dart';
import '../../domain/services/tutorial_v3_retry_policy.dart';
import '../../domain/validation/tutorial_v3_plan_validator.dart';
import '../../domain/value_objects/tutorial_v3_plan_version.dart';
import '../data_sources/tutorial_v3_remote_data_source.dart';
import '../models/tutorial_v3_geometry_codec.dart';
import '../models/tutorial_v3_session_dto.dart';
import '../models/tutorial_v3_step_spec_codec.dart';

/// Supabase-backed V3 tutorial persistence and geometry lifecycle.
///
/// Ownership is enforced twice over: RLS makes another user's rows invisible,
/// and every mutation loads the session first and requires it to be readable,
/// so a session written by another plan version can be reported but never
/// modified.
///
/// V3 stores coordinates, not pixels. Nothing here writes to storage.
class SupabaseTutorialV3Repository implements TutorialV3Repository {
  const SupabaseTutorialV3Repository(this._remote);

  final TutorialV3RemoteDataSource _remote;

  @override
  Future<TutorialV3SessionSnapshot> openSession(
    TutorialV3EntryPoint entry,
  ) async {
    _requireUser();

    // One round trip, one statement. `open_tutorial_v3_session` derives the
    // analysis, the recommendation, the selected look and the canonical path
    // from rows RLS has already scoped to this caller, then reuses or creates
    // the session. Nothing about the tutorial is assembled on this side.
    final sessionId = await _remote.openSession(
      canonicalImageId: entry.canonicalImageId,
      kit: entry.isKit,
    );
    final row = await _remote.findSessionById(sessionId);
    if (row == null) {
      throw const TutorialV3Failure(
        'This tutorial could not be opened.',
        kind: TutorialV3FailureKind.notFound,
        retryable: false,
      );
    }
    return _snapshotOf(row);
  }

  @override
  Future<TutorialV3SessionSnapshot?> findSessionById(String sessionId) async {
    _requireUser();
    final row = await _remote.findSessionById(sessionId);
    if (row == null) return null;
    return _snapshotOf(row);
  }

  @override
  Future<TutorialV3LoadedSession> persistPlan({
    required String sessionId,
    required TutorialV3Plan plan,
    String? plannerModel,
    String? plannerPromptVersion,
  }) async {
    _requireUser();
    final loaded = await _requireLoaded(sessionId);

    // Re-validate rather than trusting the caller: this is the last point
    // before a plan becomes persisted truth.
    TutorialV3PlanValidator.validate(plan);

    if (plan.planVersion != loaded.session.planVersion) {
      throw const TutorialV3Failure(
        'This plan was built for a different tutorial version.',
        kind: TutorialV3FailureKind.validation,
        retryable: false,
      );
    }
    if (plan.selectedStyleCode != loaded.session.selectedStyleCode) {
      throw const TutorialV3Failure(
        'This plan was built for a different selected look.',
        kind: TutorialV3FailureKind.validation,
        retryable: false,
      );
    }
    if (plan.sourceMode != loaded.session.sourceMode) {
      throw const TutorialV3Failure(
        'This plan was built for a different recommendation source.',
        kind: TutorialV3FailureKind.validation,
        retryable: false,
      );
    }

    await _remote.persistPlan(
      sessionId: sessionId,
      plannerModel: plannerModel,
      plannerPromptVersion: plannerPromptVersion,
      steps: plan.steps
          .map(
            (spec) => <String, Object?>{
              'step_index': spec.stepIndex,
              'category': spec.category.code,
              'step_spec_json': TutorialV3StepSpecCodec.encodeSpec(spec),
              'product_snapshot_json':
                  TutorialV3StepSpecCodec.encodeProductSnapshot(spec),
              'geometry_status': spec.isFinalLook
                  ? TutorialV3GeometryStatus.notRequired.code
                  : TutorialV3GeometryStatus.pending.code,
            },
          )
          .toList(growable: false),
    );

    return _reload(sessionId);
  }

  @override
  Future<TutorialV3LoadedSession> markPlanFailed({
    required String sessionId,
    required String error,
  }) async {
    _requireUser();
    await _requireLoaded(sessionId);
    await _remote.updateSession(sessionId, <String, Object?>{
      'status': TutorialV3SessionStatus.failed.code,
      'plan_error': error,
      'total_steps': 0,
    });
    return _reload(sessionId);
  }

  @override
  Future<TutorialV3GeometryPreparation> prepareGeometry({
    required String sessionId,
    required int stepIndex,
  }) async {
    _requireUser();
    await _requireLoaded(sessionId);

    // One statement decides reuse / in-flight / exhausted / claim, so two
    // concurrent callers cannot both start mapping the same step.
    final result = await _remote.claimGeometry(
      sessionId: sessionId,
      stepIndex: stepIndex,
      maxAttempts: TutorialV3RetryPolicy.maxGuidelineAttempts,
      // The build declares what it can read; the RPC reuses a stored document
      // only at this exact version.
      schemaVersion: tutorialV3GeometrySchemaVersion,
    );

    switch (result['outcome']) {
      case 'reused':
        return TutorialV3GeometryPreparation(
          session: await _reload(sessionId),
          stepIndex: stepIndex,
          outcome: TutorialV3GeometryOutcome.reusedExisting,
        );
      case 'claimed':
        return TutorialV3GeometryPreparation(
          session: await _reload(sessionId),
          stepIndex: stepIndex,
          // The RPC reports the version it discarded, which is the only
          // signal that a step which looked complete had to be re-mapped.
          outcome: result['replaced_schema_version'] == null
              ? TutorialV3GeometryOutcome.claimedForGeneration
              : TutorialV3GeometryOutcome.claimedAfterStaleGeometry,
        );
      case 'not_found':
        throw TutorialV3Failure(
          'Step $stepIndex does not belong to this tutorial.',
          kind: TutorialV3FailureKind.notFound,
          retryable: false,
        );
      case 'final_look':
        throw const TutorialV3Failure(
          'The final look reuses the canonical preview and maps no geometry.',
          kind: TutorialV3FailureKind.validation,
          retryable: false,
        );
      case 'in_flight':
        throw TutorialV3Failure(
          'Step $stepIndex is already being mapped.',
          kind: TutorialV3FailureKind.validation,
          retryable: true,
        );
      case 'exhausted':
        throw TutorialV3Failure(
          'Step $stepIndex has used all '
          '${TutorialV3RetryPolicy.maxGuidelineAttempts} mapping attempts.',
          kind: TutorialV3FailureKind.generation,
          retryable: false,
        );
      default:
        throw TutorialV3Failure(
          'Step $stepIndex could not be prepared.',
          kind: TutorialV3FailureKind.unknown,
          retryable: true,
        );
    }
  }

  @override
  Future<TutorialV3LoadedSession> markGeometryFailed({
    required String sessionId,
    required int stepIndex,
    required String error,
  }) async {
    _requireUser();
    final loaded = await _requireLoaded(sessionId);
    final step = _requireStep(loaded, stepIndex);

    // The Step Spec is untouched, so a retry reuses the same instruction and
    // never re-plans. No geometry is stored: missing stays missing.
    await _remote.updateStep(
      sessionId: sessionId,
      stepIndex: stepIndex,
      values: <String, Object?>{
        'geometry_status': TutorialV3GeometryStatus.failed.code,
        'geometry_error': error,
        'geometry_json': null,
        'geometry_schema_version': null,
        'attempt_count': step.attemptCount + 1,
      },
    );
    return _reload(sessionId);
  }

  @override
  Future<TutorialV3LoadedSession> persistGeometry({
    required String sessionId,
    required int stepIndex,
    required TutorialV3Geometry geometry,
    String? modelName,
    String? promptVersion,
  }) async {
    _requireUser();
    final loaded = await _requireLoaded(sessionId);
    final step = _requireStep(loaded, stepIndex);

    if (step.isFinalLook) {
      throw const TutorialV3Failure(
        'The final look reuses the canonical preview and maps no geometry.',
        kind: TutorialV3FailureKind.validation,
        retryable: false,
      );
    }
    if (geometry.category != step.spec.category) {
      throw TutorialV3Failure(
        'Step $stepIndex teaches "${step.spec.category.code}" but this '
        'geometry describes "${geometry.category.code}".',
        kind: TutorialV3FailureKind.validation,
        retryable: false,
      );
    }
    if (!geometry.isCurrentSchema) {
      throw TutorialV3Failure(
        'Geometry schema version ${geometry.schemaVersion} cannot be stored '
        'by this build.',
        kind: TutorialV3FailureKind.validation,
        retryable: false,
      );
    }

    final persisted = await _remote.updateStep(
      sessionId: sessionId,
      stepIndex: stepIndex,
      values: <String, Object?>{
        'geometry_status': TutorialV3GeometryStatus.ready.code,
        'geometry_json': TutorialV3GeometryCodec.encode(geometry),
        'geometry_schema_version': geometry.schemaVersion,
        'geometry_error': null,
        'model_name': modelName,
        'prompt_version': promptVersion,
      },
      // Geometry attaches only to a step this caller claimed, which keeps the
      // claim meaningful.
      expectedStatuses: <String>[TutorialV3GeometryStatus.generating.code],
    );
    if (persisted == null) {
      throw TutorialV3Failure(
        'Step $stepIndex was not claimed for mapping.',
        kind: TutorialV3FailureKind.validation,
        retryable: false,
      );
    }
    return _reload(sessionId);
  }

  @override
  Future<TutorialV3SessionImages> loadImages(TutorialV3Session session) async {
    _requireUser();

    // The selfie path comes from the session's own analysis, never from the
    // caller, so a tutorial cannot be pointed at another photograph. RLS makes
    // an analysis that is not the caller's invisible.
    final originalPath = await _remote.findOriginalImagePath(
      session.analysisId,
    );
    if (originalPath == null) {
      throw const TutorialV3Failure(
        'The original photo for this tutorial is no longer available.',
        kind: TutorialV3FailureKind.notFound,
        retryable: false,
      );
    }

    final urls = await Future.wait(<Future<String>>[
      _remote.createSignedUrl(originalPath),
      _remote.createSignedUrl(session.canonicalPreview.storagePath),
    ]);
    return TutorialV3SessionImages(
      originalSelfieUrl: urls.first,
      canonicalPreviewUrl: urls.last,
    );
  }

  @override
  Future<String> createSignedUrl(String storagePath) =>
      _remote.createSignedUrl(storagePath);

  String _requireUser() {
    final userId = _remote.currentUserId;
    if (userId == null) {
      throw const TutorialV3Failure(
        'Sign in to open your tutorial.',
        kind: TutorialV3FailureKind.sessionExpired,
        retryable: false,
      );
    }
    return userId;
  }

  TutorialV3Step _requireStep(TutorialV3LoadedSession loaded, int stepIndex) {
    final step = loaded.stepAt(stepIndex);
    if (step == null) {
      throw TutorialV3Failure(
        'Step $stepIndex does not belong to this tutorial.',
        kind: TutorialV3FailureKind.notFound,
        retryable: false,
      );
    }
    return step;
  }

  Future<TutorialV3LoadedSession> _requireLoaded(String sessionId) async {
    final row = await _remote.findSessionById(sessionId);
    if (row == null) {
      throw const TutorialV3Failure(
        'This tutorial could not be found.',
        kind: TutorialV3FailureKind.notFound,
        retryable: false,
      );
    }
    return (await _snapshotOf(row)).requireLoaded;
  }

  Future<TutorialV3LoadedSession> _reload(String sessionId) async {
    final row = await _remote.findSessionById(sessionId);
    if (row == null) {
      throw const TutorialV3Failure(
        'This tutorial could not be reloaded.',
        kind: TutorialV3FailureKind.notFound,
        retryable: true,
      );
    }
    return (await _snapshotOf(row)).requireLoaded;
  }

  Future<TutorialV3SessionSnapshot> _snapshotOf(
    Map<String, Object?> sessionRow,
  ) async {
    final sessionId = sessionRow['id'];
    // Steps are only worth fetching for a session this build can read; an
    // incompatible one never exposes them.
    final readable =
        sessionRow['plan_version'] is int &&
        TutorialV3PlanVersion.isSupported(sessionRow['plan_version']! as int);
    final steps = readable && sessionId is String
        ? await _remote.selectSteps(sessionId)
        : const <Map<String, Object?>>[];
    final snapshot = TutorialV3SessionDto.fromRows(
      session: sessionRow,
      steps: steps,
    );
    if (snapshot is TutorialV3LoadedSession &&
        !snapshot.session.canonicalPreview.matchesSourceModeFolder) {
      // A row written before the entry resolver existed could point a Kit
      // session at a standard preview, or the reverse. Rendering it would
      // teach toward the wrong look for the same face, so it is refused
      // rather than opened.
      throw const TutorialV3Failure(
        'This tutorial points at the wrong final look. Start a new one.',
        kind: TutorialV3FailureKind.validation,
        retryable: false,
      );
    }
    return snapshot;
  }
}
