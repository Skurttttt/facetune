import '../../domain/entities/tutorial_v3_guideline_status.dart';
import '../../domain/entities/tutorial_v3_plan.dart';
import '../../domain/entities/tutorial_v3_session_snapshot.dart';
import '../../domain/entities/tutorial_v3_session_status.dart';
import '../../domain/entities/tutorial_v3_step.dart';
import '../../domain/errors/tutorial_v3_failure.dart';
import '../../domain/repositories/tutorial_v3_repository.dart';
import '../../domain/services/tutorial_v3_retry_policy.dart';
import '../../domain/services/tutorial_v3_storage_paths.dart';
import '../../domain/validation/tutorial_v3_plan_validator.dart';
import '../../domain/value_objects/tutorial_v3_plan_version.dart';
import '../data_sources/tutorial_v3_remote_data_source.dart';
import '../models/tutorial_v3_session_dto.dart';
import '../models/tutorial_v3_step_spec_codec.dart';

/// Supabase-backed V3 tutorial persistence and session lifecycle.
///
/// Every write is owner-scoped twice over: RLS makes another user's rows
/// invisible, and this layer additionally refuses to attach a storage path
/// that is not this session's and this step's. Server-side checks are the
/// authority; these client checks exist so a bad path is never even sent.
///
/// Every mutation loads the session first and requires it to be readable, so
/// a session written by another plan version can be reported but never
/// modified, repaired or overwritten.
class SupabaseTutorialV3Repository implements TutorialV3Repository {
  const SupabaseTutorialV3Repository(this._remote);

  final TutorialV3RemoteDataSource _remote;

  @override
  Future<TutorialV3SessionSnapshot> getOrCreateSession(
    TutorialV3SessionRequest request,
  ) async {
    final userId = _requireUser();
    _validateRequest(request);

    final kit = request.sourceMode.isKit;
    final canonicalImageId = request.canonicalPreview.generatedImageId;

    // Look the tutorial up by its canonical target rather than by plan
    // version, so a session stored under a version this build cannot read is
    // still found and reported as incompatible instead of being duplicated.
    final existing = await _remote.findSessionByCanonicalImage(
      kit: kit,
      canonicalImageId: canonicalImageId,
    );
    if (existing != null) return _snapshotOf(existing);

    final inserted = await _remote.insertSession(<String, Object?>{
      'user_id': userId,
      'analysis_id': request.analysisId,
      'source_mode': request.sourceMode.code,
      'recommendation_id': kit ? null : request.recommendationId,
      'kit_recommendation_id': kit ? request.kitRecommendationId : null,
      'makeup_style': request.selectedStyleCode,
      'canonical_generated_image_id': kit ? null : canonicalImageId,
      'canonical_kit_generated_image_id': kit ? canonicalImageId : null,
      'canonical_image_path': request.canonicalPreview.storagePath,
      'total_steps': 0,
      'plan_version': TutorialV3PlanVersion.currentValue,
      'status': TutorialV3SessionStatus.planning.code,
    });
    return _snapshotOf(inserted);
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
              'guideline_status': spec.isFinalLook
                  ? TutorialV3GuidelineStatus.notRequired.code
                  : TutorialV3GuidelineStatus.pending.code,
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
  Future<TutorialV3GuidelinePreparation> prepareGuideline({
    required String sessionId,
    required int stepIndex,
  }) async {
    _requireUser();
    final loaded = await _requireLoaded(sessionId);
    final step = _requireStep(loaded, stepIndex);

    if (step.isFinalLook) {
      throw const TutorialV3Failure(
        'The final look reuses the canonical preview and generates nothing.',
        kind: TutorialV3FailureKind.validation,
        retryable: false,
      );
    }

    // Reuse before claim. A revisited step that already has a validated
    // guideline is returned as-is, so reopening a tutorial never re-spends
    // image quota on work that is already done.
    if (step.hasGuideline) {
      return TutorialV3GuidelinePreparation(
        session: loaded,
        stepIndex: stepIndex,
        outcome: TutorialV3GuidelineOutcome.reusedExisting,
      );
    }

    if (step.guidelineStatus == TutorialV3GuidelineStatus.generating) {
      throw TutorialV3Failure(
        'Step $stepIndex is already generating.',
        kind: TutorialV3FailureKind.validation,
        retryable: true,
      );
    }
    if (!TutorialV3RetryPolicy.canAttemptAgain(step.attemptCount)) {
      throw TutorialV3Failure(
        'Step $stepIndex has used all '
        '${TutorialV3RetryPolicy.maxGuidelineAttempts} generation attempts.',
        kind: TutorialV3FailureKind.generation,
        retryable: false,
      );
    }

    // Filtering on the current status inside the update is what makes two
    // concurrent callers unable to both start generating the same step.
    final claimed = await _remote.updateStep(
      sessionId: sessionId,
      stepIndex: stepIndex,
      values: <String, Object?>{
        'guideline_status': TutorialV3GuidelineStatus.generating.code,
        'guideline_error': null,
      },
      expectedStatuses: <String>[
        TutorialV3GuidelineStatus.pending.code,
        TutorialV3GuidelineStatus.failed.code,
      ],
    );
    if (claimed == null) {
      throw TutorialV3Failure(
        'Step $stepIndex is not ready to generate a guideline.',
        kind: TutorialV3FailureKind.validation,
        retryable: true,
      );
    }

    return TutorialV3GuidelinePreparation(
      session: await _reload(sessionId),
      stepIndex: stepIndex,
      outcome: TutorialV3GuidelineOutcome.claimedForGeneration,
    );
  }

  @override
  Future<TutorialV3LoadedSession> markGuidelineFailed({
    required String sessionId,
    required int stepIndex,
    required String error,
  }) async {
    _requireUser();
    final loaded = await _requireLoaded(sessionId);
    final step = _requireStep(loaded, stepIndex);

    // The Step Spec is untouched, so a retry reuses the same instruction and
    // never re-plans. No asset is attached: a missing guideline stays missing.
    await _remote.updateStep(
      sessionId: sessionId,
      stepIndex: stepIndex,
      values: <String, Object?>{
        'guideline_status': TutorialV3GuidelineStatus.failed.code,
        'guideline_error': error,
        'guideline_image_path': null,
        'attempt_count': step.attemptCount + 1,
      },
    );
    return _reload(sessionId);
  }

  @override
  Future<TutorialV3LoadedSession> persistGuideline({
    required String sessionId,
    required int stepIndex,
    required String storagePath,
    String? modelName,
    String? promptVersion,
  }) async {
    _requireUser();
    final loaded = await _requireLoaded(sessionId);
    final step = _requireStep(loaded, stepIndex);

    if (step.isFinalLook) {
      throw const TutorialV3Failure(
        'The final look reuses the canonical preview and generates nothing.',
        kind: TutorialV3FailureKind.validation,
        retryable: false,
      );
    }
    if (!TutorialV3StoragePaths.isOwnedAssetPath(
      storagePath,
      userId: loaded.session.userId,
      analysisId: loaded.session.analysisId,
      sessionId: sessionId,
      stepIndex: stepIndex,
    )) {
      throw const TutorialV3Failure(
        'That guideline path does not belong to this step.',
        kind: TutorialV3FailureKind.ownership,
        retryable: false,
      );
    }

    final persisted = await _remote.updateStep(
      sessionId: sessionId,
      stepIndex: stepIndex,
      values: <String, Object?>{
        'guideline_status': TutorialV3GuidelineStatus.ready.code,
        'guideline_image_path': storagePath,
        'guideline_error': null,
        'model_name': modelName,
        'prompt_version': promptVersion,
      },
      // A guideline is attached only to a step this caller claimed, which
      // keeps the claim meaningful.
      expectedStatuses: <String>[TutorialV3GuidelineStatus.generating.code],
    );
    if (persisted == null) {
      throw TutorialV3Failure(
        'Step $stepIndex was not claimed for generation.',
        kind: TutorialV3FailureKind.validation,
        retryable: false,
      );
    }
    return _reload(sessionId);
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

  void _validateRequest(TutorialV3SessionRequest request) {
    final errors = <String>[];
    if (request.canonicalPreview.sourceMode != request.sourceMode) {
      errors.add('The canonical preview belongs to a different source mode.');
    }
    if (request.sourceMode.isKit) {
      if (request.kitRecommendationId == null) {
        errors.add('A Kit tutorial needs a Kit recommendation.');
      }
      if (request.recommendationId != null) {
        errors.add('A Kit tutorial must not carry a standard recommendation.');
      }
    } else {
      if (request.recommendationId == null) {
        errors.add('A standard tutorial needs a standard recommendation.');
      }
      if (request.kitRecommendationId != null) {
        errors.add('A standard tutorial must not carry a Kit recommendation.');
      }
    }
    if (errors.isNotEmpty) {
      throw TutorialV3Failure(
        errors.join(' '),
        kind: TutorialV3FailureKind.validation,
        retryable: false,
      );
    }
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
    return TutorialV3SessionDto.fromRows(session: sessionRow, steps: steps);
  }
}
