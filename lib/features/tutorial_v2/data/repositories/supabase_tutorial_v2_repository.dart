import 'dart:async';
import 'dart:io';

import '../../domain/entities/tutorial_v2_generation_status.dart';
import '../../domain/entities/tutorial_v2_plan.dart';
import '../../domain/entities/tutorial_v2_plan_context.dart';
import '../../domain/entities/tutorial_v2_session.dart';
import '../../domain/entities/tutorial_v2_session_snapshot.dart';
import '../../domain/errors/tutorial_v2_failure.dart';
import '../../domain/repositories/tutorial_v2_repository.dart';
import '../../domain/services/tutorial_v2_storage_paths.dart';
import '../../domain/validation/tutorial_v2_plan_validator.dart';
import '../data_sources/tutorial_v2_remote_data_source.dart';
import '../models/tutorial_v2_session_dto.dart';

class SupabaseTutorialV2Repository implements TutorialV2Repository {
  const SupabaseTutorialV2Repository(
    this._remote, {
    Duration timeout = const Duration(seconds: 30),
  }) : _timeout = timeout;

  final TutorialV2RemoteDataSource _remote;
  final Duration _timeout;

  @override
  Future<TutorialV2SessionSnapshot> getOrCreateSession({
    required String analysisId,
    required TutorialV2PlanContext context,
  }) async {
    final userId = _requireAuthentication();
    // Fail before touching the database: a context that cannot produce a
    // valid plan should never become a session row.
    TutorialV2PlanValidator.validateContext(context);
    return _run(() async {
      final existing = await _remote.findSessionByCanonical(
        canonicalImageId: context.canonicalFinalPreview.generatedImageId,
        isKit: context.sourceMode.isMakeupKit,
        planVersion: context.planVersion.value,
      );
      if (existing != null) return _load(existing);

      final created = await _remote.insertSession(
        TutorialV2SessionDto.insertValues(
          userId: userId,
          analysisId: analysisId,
          context: context,
        ),
      );
      return _load(created);
    });
  }

  @override
  Future<TutorialV2SessionSnapshot?> findSessionById(String sessionId) async {
    _requireAuthentication();
    return _run(() async {
      final row = await _remote.findSessionById(sessionId);
      return row == null ? null : _load(row);
    });
  }

  @override
  Future<TutorialV2SessionSnapshot> persistPlan({
    required String sessionId,
    required TutorialV2Plan plan,
    String? plannerModel,
    String? plannerPromptVersion,
  }) async {
    final userId = _requireAuthentication();
    return _run(() async {
      final sessionRow = await _requireSession(sessionId);
      _requirePlanMatchesSession(sessionRow, plan);

      // Replacing rather than appending: a replan after a failure must not
      // leave two generations of steps interleaved under one session.
      await _remote.deleteSteps(sessionId);
      await _remote.insertSteps([
        for (final step in plan.steps)
          TutorialV2SessionDto.stepInsertValues(
            userId: userId,
            sessionId: sessionId,
            step: step,
          ),
      ]);

      final updated = await _remote.updateSession(
        sessionId: sessionId,
        values: {
          'total_steps': plan.totalSteps,
          'status': TutorialV2SessionStatus.planReady.code,
          'plan_error': null,
          'planner_model': ?plannerModel,
          'planner_prompt_version': ?plannerPromptVersion,
        },
      );
      return _load(updated);
    });
  }

  @override
  Future<TutorialV2SessionSnapshot> markPlanFailed({
    required String sessionId,
    required String error,
  }) async {
    _requireAuthentication();
    return _run(() async {
      final updated = await _remote.updateSession(
        sessionId: sessionId,
        values: {
          'status': TutorialV2SessionStatus.planFailed.code,
          'plan_error': error,
          'total_steps': 0,
        },
      );
      return _load(updated);
    });
  }

  @override
  Future<TutorialV2SessionSnapshot> updateAssetStatus({
    required String sessionId,
    required int stepIndex,
    required TutorialV2AssetKind asset,
    required TutorialV2GenerationStatus status,
    String? error,
  }) async {
    _requireAuthentication();
    return _run(() async {
      final sessionRow = await _requireSession(sessionId);
      final stepRow = await _requireStep(sessionId, stepIndex);

      final failed = status == TutorialV2GenerationStatus.failed;
      final retryCount = stepRow['retry_count'] is int
          ? stepRow['retry_count'] as int
          : 0;

      await _remote.updateStep(
        stepId: stepRow['id'] as String,
        values: {
          '${asset.code}_status': status.code,
          '${asset.code}_error': failed ? error : null,
          if (failed) 'retry_count': retryCount + 1,
        },
      );
      return _load(sessionRow);
    });
  }

  @override
  Future<TutorialV2SessionSnapshot> persistAsset({
    required String sessionId,
    required int stepIndex,
    required TutorialV2AssetKind asset,
    required String storagePath,
    String? modelName,
    String? promptVersion,
  }) async {
    _requireAuthentication();
    return _run(() async {
      final sessionRow = await _requireSession(sessionId);
      final stepRow = await _requireStep(sessionId, stepIndex);

      // The path is re-validated here even though this repository built it:
      // a path that does not belong to exactly this session, step and asset
      // kind must never be written, whatever produced it.
      final owned = TutorialV2StoragePaths.isOwnedAssetPath(
        storagePath,
        userId: sessionRow['user_id']! as String,
        analysisId: sessionRow['analysis_id']! as String,
        sessionId: sessionId,
        stepIndex: stepIndex,
        asset: asset.code,
      );
      if (!owned) {
        throw TutorialV2Failure(
          'A generated asset was rejected because its storage path does not '
          'belong to this tutorial step.',
          kind: TutorialV2FailureKind.planValidation,
          retryable: false,
        );
      }

      await _remote.updateStep(
        stepId: stepRow['id'] as String,
        values: {
          '${asset.code}_image_path': storagePath,
          '${asset.code}_status': TutorialV2GenerationStatus.ready.code,
          '${asset.code}_error': null,
          'model_name': ?modelName,
          'prompt_version': ?promptVersion,
        },
      );
      return _load(sessionRow);
    });
  }

  @override
  Future<TutorialV2SessionSnapshot> generateGuideline({
    required String sessionId,
    required int stepIndex,
  }) async {
    _requireAuthentication();
    return _run(() async {
      final sessionRow = await _requireSession(sessionId);
      final stepRow = await _requireStep(sessionId, stepIndex);

      // Reuse rather than regenerate. Reopening a tutorial must never re-spend
      // image quota on an asset that already exists; the server enforces the
      // same rule authoritatively, this just avoids the round trip.
      final ready =
          stepRow['guideline_status'] ==
              TutorialV2GenerationStatus.ready.code &&
          stepRow['guideline_image_path'] != null;
      if (ready) return _load(sessionRow);

      await _remote.invokeGuideline(
        sessionId: sessionId,
        stepIndex: stepIndex,
      );
      return _load(sessionRow);
    });
  }

  @override
  Future<String> createSignedUrl(String storagePath) async {
    _requireAuthentication();
    return _run(() => _remote.createSignedUrl(storagePath));
  }

  Future<TutorialV2SessionSnapshot> _load(Map<String, Object?> sessionRow) async {
    final analysisId = sessionRow['analysis_id']! as String;
    final analysis = await _remote.findAnalysis(analysisId);
    if (analysis == null) {
      throw const TutorialV2Failure(
        'The face analysis behind this tutorial is no longer available.',
        kind: TutorialV2FailureKind.notFound,
        retryable: false,
      );
    }
    final steps = await _remote.selectSteps(sessionRow['id']! as String);
    return TutorialV2SessionDto.fromRows(
      sessionRow: sessionRow,
      stepRows: steps,
      attributes: TutorialV2FacialAttributesCodec.fromAnalysisRow(analysis),
    );
  }

  Future<Map<String, Object?>> _requireSession(String sessionId) async {
    final row = await _remote.findSessionById(sessionId);
    if (row == null) {
      throw const TutorialV2Failure(
        'This tutorial is no longer available.',
        kind: TutorialV2FailureKind.notFound,
        retryable: false,
      );
    }
    return row;
  }

  Future<Map<String, Object?>> _requireStep(
    String sessionId,
    int stepIndex,
  ) async {
    final steps = await _remote.selectSteps(sessionId);
    for (final row in steps) {
      if (row['step_index'] == stepIndex) return row;
    }
    throw TutorialV2Failure(
      'Step ${stepIndex + 1} of this tutorial has not been planned yet.',
      kind: TutorialV2FailureKind.notFound,
      retryable: false,
    );
  }

  /// A plan may only be written against the session it was planned for.
  void _requirePlanMatchesSession(
    Map<String, Object?> sessionRow,
    TutorialV2Plan plan,
  ) {
    final context = plan.context;
    final isKit = context.sourceMode.isMakeupKit;
    final canonicalColumn = isKit
        ? 'canonical_kit_generated_image_id'
        : 'canonical_generated_image_id';

    final mismatched =
        sessionRow['source_mode'] != context.sourceMode.code ||
        sessionRow['makeup_style'] != context.styleCode ||
        sessionRow[canonicalColumn] !=
            context.canonicalFinalPreview.generatedImageId ||
        sessionRow['plan_version'] != context.planVersion.value;

    if (mismatched) {
      throw const TutorialV2Failure(
        'This plan was built for a different tutorial.',
        kind: TutorialV2FailureKind.planValidation,
        retryable: false,
      );
    }
  }

  String _requireAuthentication() {
    final userId = _remote.currentUserId;
    if (userId == null) {
      throw const TutorialV2Failure(
        'Sign in to open your tutorial.',
        kind: TutorialV2FailureKind.sessionExpired,
        retryable: false,
      );
    }
    return userId;
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(_timeout);
    } catch (error) {
      throw _map(error);
    }
  }

  TutorialV2Failure _map(Object error) {
    if (error is TutorialV2Failure) return error;
    if (error is TimeoutException) {
      return const TutorialV2Failure(
        'Your tutorial took too long to load. Please try again.',
        kind: TutorialV2FailureKind.timeout,
      );
    }
    if (error is SocketException) {
      return const TutorialV2Failure(
        'Check your connection and try again.',
        kind: TutorialV2FailureKind.offline,
      );
    }
    if (error is TutorialV2RemoteFailure) {
      if (error.status == 401 || error.status == 403) {
        return const TutorialV2Failure(
          'Your session expired. Sign in again.',
          kind: TutorialV2FailureKind.sessionExpired,
          retryable: false,
        );
      }
      if (error.status == 404) {
        return const TutorialV2Failure(
          'This tutorial is no longer available.',
          kind: TutorialV2FailureKind.notFound,
          retryable: false,
        );
      }
      return TutorialV2Failure(
        'Your tutorial could not be loaded right now.',
        kind: TutorialV2FailureKind.unavailable,
        retryable: error.retryable,
      );
    }
    if (error is FormatException) {
      return const TutorialV2Failure(
        'This tutorial could not be read. Start a new one.',
        kind: TutorialV2FailureKind.planValidation,
        retryable: false,
      );
    }
    return const TutorialV2Failure(
      'Your tutorial could not be loaded right now.',
    );
  }
}
