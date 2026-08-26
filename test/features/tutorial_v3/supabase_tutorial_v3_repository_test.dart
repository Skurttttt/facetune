import 'package:facetune/features/tutorial_v3/data/data_sources/tutorial_v3_remote_data_source.dart';
import 'package:facetune/features/tutorial_v3/data/repositories/supabase_tutorial_v3_repository.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_canonical_preview.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_category.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_guideline_status.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_session_readiness.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_session_snapshot.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_session_status.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_source_mode.dart';
import 'package:facetune/features/tutorial_v3/domain/errors/tutorial_v3_failure.dart';
import 'package:facetune/features/tutorial_v3/domain/repositories/tutorial_v3_repository.dart';
import 'package:facetune/features/tutorial_v3/domain/services/tutorial_v3_retry_policy.dart';
import 'package:facetune/features/tutorial_v3/domain/services/tutorial_v3_storage_paths.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_v3_fixtures.dart';

const _user = 'user-1';
const _analysis = 'analysis-1';

/// An in-memory stand-in for the Postgres tables.
///
/// It reproduces the behaviour the repository depends on — conditional
/// updates, the canonical-preview natural key, and the atomic plan write —
/// without reproducing the check constraints, so the repository's own guards
/// are what the tests exercise.
class _FakeRemote implements TutorialV3RemoteDataSource {
  String? userId = _user;
  final Map<String, Map<String, Object?>> sessions = {};
  final Map<String, List<Map<String, Object?>>> steps = {};
  int insertCount = 0;
  final List<String> signedPaths = [];
  int planWrites = 0;

  /// Seeds a session written by a different build of the tutorial feature.
  String seedSessionAtPlanVersion(int planVersion) {
    final id = 'legacy-session';
    sessions[id] = <String, Object?>{
      'id': id,
      'user_id': _user,
      'analysis_id': _analysis,
      'source_mode': TutorialV3SourceMode.standard.code,
      'recommendation_id': 'recommendation-1',
      'kit_recommendation_id': null,
      'makeup_style': testStyleCode,
      'canonical_generated_image_id': 'generated-1',
      'canonical_kit_generated_image_id': null,
      'canonical_image_path':
          '$_user/analyses/$_analysis/generated/r/preview_0001.png',
      'total_steps': 4,
      'plan_version': planVersion,
      'status': TutorialV3SessionStatus.ready.code,
      'created_at': DateTime.utc(2026, 8, 27),
      'updated_at': DateTime.utc(2026, 8, 27),
    };
    // Steps in a schema this build does not know. They must never be decoded.
    steps[id] = [
      <String, Object?>{
        'step_index': 1,
        'category': 'foundation_result',
        'step_spec_json': <String, Object?>{'unknown_shape': true},
        'guideline_status': 'pending',
      },
    ];
    return id;
  }

  @override
  String? get currentUserId => userId;

  @override
  Future<Map<String, Object?>?> findSessionByCanonicalImage({
    required bool kit,
    required String canonicalImageId,
  }) async {
    final column = kit
        ? 'canonical_kit_generated_image_id'
        : 'canonical_generated_image_id';
    for (final row in sessions.values) {
      if (row[column] == canonicalImageId) return {...row};
    }
    return null;
  }

  @override
  Future<Map<String, Object?>?> findSessionById(String sessionId) async {
    final row = sessions[sessionId];
    return row == null ? null : {...row};
  }

  @override
  Future<Map<String, Object?>> insertSession(
    Map<String, Object?> values,
  ) async {
    insertCount++;
    final id = 'session-$insertCount';
    final now = DateTime.utc(2026, 8, 27);
    final row = <String, Object?>{
      ...values,
      'id': id,
      'created_at': now,
      'updated_at': now,
    };
    sessions[id] = row;
    steps[id] = [];
    return {...row};
  }

  @override
  Future<Map<String, Object?>> updateSession(
    String sessionId,
    Map<String, Object?> values,
  ) async {
    final row = sessions[sessionId]!..addAll(values);
    return {...row};
  }

  @override
  Future<List<Map<String, Object?>>> selectSteps(String sessionId) async =>
      (steps[sessionId] ?? const []).map((row) => {...row}).toList();

  @override
  Future<int> persistPlan({
    required String sessionId,
    required String? plannerModel,
    required String? plannerPromptVersion,
    required List<Map<String, Object?>> steps,
  }) async {
    planWrites++;
    this.steps[sessionId] = steps
        .map((step) => <String, Object?>{...step, 'attempt_count': 0})
        .toList();
    sessions[sessionId]!.addAll(<String, Object?>{
      'total_steps': steps.length,
      'status': TutorialV3SessionStatus.ready.code,
      'plan_error': null,
      'planner_model': plannerModel,
      'planner_prompt_version': plannerPromptVersion,
    });
    return steps.length;
  }

  @override
  Future<Map<String, Object?>?> updateStep({
    required String sessionId,
    required int stepIndex,
    required Map<String, Object?> values,
    List<String>? expectedStatuses,
  }) async {
    for (final row in steps[sessionId] ?? const <Map<String, Object?>>[]) {
      if (row['step_index'] != stepIndex) continue;
      if (expectedStatuses != null &&
          !expectedStatuses.contains(row['guideline_status'])) {
        return null;
      }
      row.addAll(values);
      return {...row};
    }
    return null;
  }

  @override
  Future<String> createSignedUrl(String storagePath) async {
    signedPaths.add(storagePath);
    return 'https://signed.example/$storagePath';
  }
}

TutorialV3SessionRequest _request({
  TutorialV3SourceMode sourceMode = TutorialV3SourceMode.standard,
  String canonicalImageId = 'generated-1',
}) => TutorialV3SessionRequest(
  analysisId: _analysis,
  sourceMode: sourceMode,
  selectedStyleCode: testStyleCode,
  canonicalPreview: TutorialV3CanonicalPreview(
    generatedImageId: canonicalImageId,
    storagePath: sourceMode.isKit
        ? '$_user/analyses/$_analysis/kit-generated/k/preview_0001.png'
        : '$_user/analyses/$_analysis/generated/r/preview_0001.png',
    sourceMode: sourceMode,
  ),
  recommendationId: sourceMode.isKit ? null : 'recommendation-1',
  kitRecommendationId: sourceMode.isKit ? 'kit-recommendation-1' : null,
);

Matcher throwsFailure(TutorialV3FailureKind kind, String messagePart) =>
    throwsA(
      isA<TutorialV3Failure>()
          .having((f) => f.kind, 'kind', kind)
          .having((f) => f.message, 'message', contains(messagePart)),
    );

void main() {
  late _FakeRemote remote;
  late SupabaseTutorialV3Repository repository;

  setUp(() {
    remote = _FakeRemote();
    repository = SupabaseTutorialV3Repository(remote);
  });

  Future<String> readySession({
    TutorialV3SourceMode sourceMode = TutorialV3SourceMode.standard,
    List<TutorialV3Category> categories = const [TutorialV3Category.blush],
  }) async {
    final created = await repository.getOrCreateSession(
      _request(sourceMode: sourceMode),
    );
    final sessionId = created.sessionId;
    await repository.persistPlan(
      sessionId: sessionId,
      plan: planTeaching(categories, sourceMode: sourceMode),
    );
    return sessionId;
  }

  String guidelinePath(String sessionId, int stepIndex) =>
      TutorialV3StoragePaths.guideline(
        userId: _user,
        analysisId: _analysis,
        sessionId: sessionId,
        stepIndex: stepIndex,
      );

  Future<void> completeGuideline(String sessionId, int stepIndex) async {
    await repository.prepareGuideline(
      sessionId: sessionId,
      stepIndex: stepIndex,
    );
    await repository.persistGuideline(
      sessionId: sessionId,
      stepIndex: stepIndex,
      storagePath: guidelinePath(sessionId, stepIndex),
    );
  }

  group('create and load', () {
    test('creates a planning session with no steps', () async {
      final snapshot = (await repository.getOrCreateSession(
        _request(),
      )).requireLoaded;

      expect(snapshot.session.userId, _user);
      expect(snapshot.session.analysisId, _analysis);
      expect(snapshot.session.status, TutorialV3SessionStatus.planning);
      expect(snapshot.session.totalSteps, 0);
      expect(snapshot.steps, isEmpty);
      expect(snapshot.hasPlan, isFalse);
      expect(snapshot.readiness, TutorialV3SessionReadiness.planning);
      expect(snapshot.readiness.needsPlan, isTrue);
      expect(snapshot.session.planVersion.value, 3);
    });

    test('is idempotent for the same canonical preview', () async {
      final first = await repository.getOrCreateSession(_request());
      final second = await repository.getOrCreateSession(_request());

      expect(second.sessionId, first.sessionId);
      expect(remote.insertCount, 1);
    });

    test('a different canonical preview starts a different tutorial', () async {
      final first = await repository.getOrCreateSession(_request());
      final second = await repository.getOrCreateSession(
        _request(canonicalImageId: 'generated-2'),
      );

      expect(second.sessionId, isNot(first.sessionId));
      expect(remote.insertCount, 2);
    });

    test('a Kit session carries only the Kit recommendation', () async {
      final snapshot = (await repository.getOrCreateSession(
        _request(sourceMode: TutorialV3SourceMode.makeupKit),
      )).requireLoaded;

      expect(snapshot.session.sourceMode, TutorialV3SourceMode.makeupKit);
      expect(snapshot.session.kitRecommendationId, 'kit-recommendation-1');
      expect(snapshot.session.recommendationId, isNull);
      expect(snapshot.session.activeRecommendationId, 'kit-recommendation-1');
    });

    test('rejects a recommendation that does not match the mode', () async {
      await expectLater(
        repository.getOrCreateSession(
          TutorialV3SessionRequest(
            analysisId: _analysis,
            sourceMode: TutorialV3SourceMode.makeupKit,
            selectedStyleCode: testStyleCode,
            canonicalPreview: _request(
              sourceMode: TutorialV3SourceMode.makeupKit,
            ).canonicalPreview,
            recommendationId: 'recommendation-1',
          ),
        ),
        throwsFailure(TutorialV3FailureKind.validation, 'Kit recommendation'),
      );
      expect(remote.insertCount, 0);
    });

    test('rejects a canonical preview from the other mode', () async {
      await expectLater(
        repository.getOrCreateSession(
          TutorialV3SessionRequest(
            analysisId: _analysis,
            sourceMode: TutorialV3SourceMode.standard,
            selectedStyleCode: testStyleCode,
            canonicalPreview: _request(
              sourceMode: TutorialV3SourceMode.makeupKit,
            ).canonicalPreview,
            recommendationId: 'recommendation-1',
          ),
        ),
        throwsFailure(
          TutorialV3FailureKind.validation,
          'different source mode',
        ),
      );
    });

    test('requires an authenticated caller', () async {
      remote.userId = null;
      await expectLater(
        repository.getOrCreateSession(_request()),
        throwsFailure(TutorialV3FailureKind.sessionExpired, 'Sign in'),
      );
    });

    test('an unknown session id reads as null, not as an error', () async {
      expect(await repository.findSessionById('nope'), isNull);
    });

    test('operating on an unknown session fails as not found', () async {
      await expectLater(
        repository.prepareGuideline(sessionId: 'nope', stepIndex: 1),
        throwsFailure(TutorialV3FailureKind.notFound, 'could not be found'),
      );
    });
  });

  group('incompatible plan versions', () {
    test('a V1 or V2 row is surfaced, not decoded', () async {
      for (final legacy in [1, 2]) {
        remote = _FakeRemote();
        repository = SupabaseTutorialV3Repository(remote);
        final id = remote.seedSessionAtPlanVersion(legacy);

        final snapshot = await repository.findSessionById(id);

        expect(snapshot, isA<TutorialV3IncompatibleSession>());
        expect(snapshot!.readiness, TutorialV3SessionReadiness.incompatible);
        expect(
          (snapshot as TutorialV3IncompatibleSession).persistedPlanVersion,
          legacy,
        );
      }
    });

    test('a newer build\'s row is refused rather than reinterpreted', () async {
      final id = remote.seedSessionAtPlanVersion(4);
      final snapshot = await repository.findSessionById(id);

      expect(snapshot, isA<TutorialV3IncompatibleSession>());
      expect(snapshot!.readiness.hasUsablePlan, isFalse);
      expect(snapshot.readiness.needsPlan, isFalse);
    });

    test('its steps are never fetched or decoded', () async {
      // The seeded row carries a `foundation_result` step in an unknown
      // shape. Decoding it would throw; the snapshot must not try.
      final id = remote.seedSessionAtPlanVersion(2);
      expect(await repository.findSessionById(id), isNotNull);
    });

    test('get-or-create returns it instead of duplicating the tutorial',
        () async {
      remote.seedSessionAtPlanVersion(4);

      final snapshot = await repository.getOrCreateSession(_request());

      expect(snapshot, isA<TutorialV3IncompatibleSession>());
      expect(remote.insertCount, 0, reason: 'must not start a second tutorial');
    });

    test('requireLoaded explains why it cannot be opened', () async {
      final id = remote.seedSessionAtPlanVersion(9);
      final snapshot = (await repository.findSessionById(id))!;

      expect(
        () => snapshot.requireLoaded,
        throwsFailure(
          TutorialV3FailureKind.validation,
          'plan version 9',
        ),
      );
    });

    test('no mutation may touch it', () async {
      final id = remote.seedSessionAtPlanVersion(4);

      for (final operation in <Future<Object?> Function()>[
        () => repository.persistPlan(
          sessionId: id,
          plan: planTeaching([TutorialV3Category.blush]),
        ),
        () => repository.markPlanFailed(sessionId: id, error: 'x'),
        () => repository.prepareGuideline(sessionId: id, stepIndex: 1),
        () => repository.markGuidelineFailed(
          sessionId: id,
          stepIndex: 1,
          error: 'x',
        ),
        () => repository.persistGuideline(
          sessionId: id,
          stepIndex: 1,
          storagePath: guidelinePath(id, 1),
        ),
      ]) {
        await expectLater(
          operation(),
          throwsFailure(TutorialV3FailureKind.validation, 'plan version 4'),
        );
      }
      expect(remote.planWrites, 0);
    });
  });

  group('persistPlan', () {
    test('stores the plan and marks the session ready', () async {
      final created = await repository.getOrCreateSession(_request());
      final snapshot = await repository.persistPlan(
        sessionId: created.sessionId,
        plan: planTeaching([
          TutorialV3Category.foundation,
          TutorialV3Category.blush,
        ]),
        plannerModel: 'planner-model',
        plannerPromptVersion: 'v1',
      );

      expect(snapshot.session.status, TutorialV3SessionStatus.ready);
      expect(snapshot.session.totalSteps, 3);
      expect(snapshot.steps, hasLength(3));
      expect(snapshot.hasPlan, isTrue);
      expect(snapshot.readiness, TutorialV3SessionReadiness.planReady);
      expect(snapshot.steps.map((s) => s.stepIndex), [1, 2, 3]);
      expect(snapshot.steps.map((s) => s.spec.category), [
        TutorialV3Category.foundation,
        TutorialV3Category.blush,
        TutorialV3Category.finalLook,
      ]);
    });

    test('the final look is persisted as needing no generation', () async {
      final sessionId = await readySession();
      final snapshot = (await repository.findSessionById(
        sessionId,
      ))!.requireLoaded;

      expect(
        snapshot.finalStep!.guidelineStatus,
        TutorialV3GuidelineStatus.notRequired,
      );
      expect(
        snapshot.stepAt(1)!.guidelineStatus,
        TutorialV3GuidelineStatus.pending,
      );
    });

    test('rejects an invalid plan before writing anything', () async {
      final created = await repository.getOrCreateSession(_request());

      await expectLater(
        repository.persistPlan(
          sessionId: created.sessionId,
          plan: planOf(
            steps: [
              guidelineStep(stepIndex: 1, category: TutorialV3Category.blush),
              guidelineStep(
                stepIndex: 2,
                category: TutorialV3Category.foundation,
              ),
              finalLookStep(stepIndex: 3),
            ],
          ),
        ),
        throwsA(isA<TutorialV3Failure>()),
      );
      expect(remote.planWrites, 0);
    });

    test('rejects a plan built for a different look', () async {
      final created = await repository.getOrCreateSession(_request());

      await expectLater(
        repository.persistPlan(
          sessionId: created.sessionId,
          plan: planOf(
            selectedStyleCode: 'natural',
            steps: [
              guidelineStep(stepIndex: 1, selectedStyleCode: 'natural'),
              finalLookStep(stepIndex: 2, selectedStyleCode: 'natural'),
            ],
          ),
        ),
        throwsFailure(
          TutorialV3FailureKind.validation,
          'different selected look',
        ),
      );
      expect(remote.planWrites, 0);
    });

    test('rejects a plan built for a different source mode', () async {
      final created = await repository.getOrCreateSession(_request());

      await expectLater(
        repository.persistPlan(
          sessionId: created.sessionId,
          plan: planTeaching(
            [TutorialV3Category.blush],
            sourceMode: TutorialV3SourceMode.makeupKit,
          ),
        ),
        throwsFailure(
          TutorialV3FailureKind.validation,
          'different recommendation source',
        ),
      );
    });

    test('a replan replaces the previous steps', () async {
      final sessionId = await readySession();
      final replanned = await repository.persistPlan(
        sessionId: sessionId,
        plan: planTeaching([
          TutorialV3Category.foundation,
          TutorialV3Category.blush,
          TutorialV3Category.lipstick,
        ]),
      );

      expect(replanned.steps, hasLength(4));
      expect(replanned.session.totalSteps, 4);
      expect(replanned.hasPlan, isTrue);
    });
  });

  group('markPlanFailed', () {
    test('leaves the session resumable with no steps', () async {
      final created = await repository.getOrCreateSession(_request());
      final snapshot = await repository.markPlanFailed(
        sessionId: created.sessionId,
        error: 'planner_unavailable',
      );

      expect(snapshot.session.status, TutorialV3SessionStatus.failed);
      expect(snapshot.session.totalSteps, 0);
      expect(snapshot.readiness, TutorialV3SessionReadiness.failed);
      expect(snapshot.readiness.needsPlan, isTrue);
    });
  });

  group('guideline lifecycle', () {
    test('preparing a pending step claims it for generation', () async {
      final sessionId = await readySession();
      final prepared = await repository.prepareGuideline(
        sessionId: sessionId,
        stepIndex: 1,
      );

      expect(prepared.outcome, TutorialV3GuidelineOutcome.claimedForGeneration);
      expect(prepared.requiresGeneration, isTrue);
      expect(
        prepared.step.guidelineStatus,
        TutorialV3GuidelineStatus.generating,
      );
      expect(prepared.session.readiness, TutorialV3SessionReadiness.generating);
    });

    test('a second concurrent claim is refused', () async {
      final sessionId = await readySession();
      await repository.prepareGuideline(sessionId: sessionId, stepIndex: 1);

      await expectLater(
        repository.prepareGuideline(sessionId: sessionId, stepIndex: 1),
        throwsFailure(
          TutorialV3FailureKind.validation,
          'already generating',
        ),
      );
    });

    test('the final look can never be prepared', () async {
      final sessionId = await readySession();

      await expectLater(
        repository.prepareGuideline(sessionId: sessionId, stepIndex: 2),
        throwsFailure(
          TutorialV3FailureKind.validation,
          'reuses the canonical preview',
        ),
      );
    });

    test('a claimed step accepts its own guideline', () async {
      final sessionId = await readySession();
      await repository.prepareGuideline(sessionId: sessionId, stepIndex: 1);

      final path = guidelinePath(sessionId, 1);
      final snapshot = await repository.persistGuideline(
        sessionId: sessionId,
        stepIndex: 1,
        storagePath: path,
        modelName: 'guideline-model',
        promptVersion: 'v1',
      );

      final step = snapshot.stepAt(1)!;
      expect(step.guidelineStatus, TutorialV3GuidelineStatus.ready);
      expect(step.guidelineStoragePath, path);
      expect(step.hasGuideline, isTrue);
      expect(snapshot.readiness, TutorialV3SessionReadiness.ready);
    });

    test('an unclaimed step cannot be given a guideline', () async {
      final sessionId = await readySession();

      await expectLater(
        repository.persistGuideline(
          sessionId: sessionId,
          stepIndex: 1,
          storagePath: guidelinePath(sessionId, 1),
        ),
        throwsFailure(TutorialV3FailureKind.validation, 'was not claimed'),
      );
    });

    test('another step, session or user asset is refused', () async {
      final sessionId = await readySession(
        categories: [TutorialV3Category.foundation, TutorialV3Category.blush],
      );
      await repository.prepareGuideline(sessionId: sessionId, stepIndex: 1);

      final foreign = <String>[
        guidelinePath(sessionId, 2),
        TutorialV3StoragePaths.guideline(
          userId: 'user-2',
          analysisId: _analysis,
          sessionId: sessionId,
          stepIndex: 1,
        ),
        TutorialV3StoragePaths.guideline(
          userId: _user,
          analysisId: _analysis,
          sessionId: 'session-999',
          stepIndex: 1,
        ),
        '$_user/analyses/$_analysis/original/abc.jpg',
        '$_user/analyses/$_analysis/generated/r/preview_0001.png',
      ];

      for (final path in foreign) {
        await expectLater(
          repository.persistGuideline(
            sessionId: sessionId,
            stepIndex: 1,
            storagePath: path,
          ),
          throwsFailure(
            TutorialV3FailureKind.ownership,
            'does not belong to this step',
          ),
          reason: 'accepted $path',
        );
      }
    });

    test('the final look never accepts a generated asset', () async {
      final sessionId = await readySession();

      await expectLater(
        repository.persistGuideline(
          sessionId: sessionId,
          stepIndex: 2,
          storagePath: guidelinePath(sessionId, 2),
        ),
        throwsFailure(
          TutorialV3FailureKind.validation,
          'reuses the canonical preview',
        ),
      );
    });

    test('an unknown step index is rejected', () async {
      final sessionId = await readySession();

      await expectLater(
        repository.markGuidelineFailed(
          sessionId: sessionId,
          stepIndex: 99,
          error: 'x',
        ),
        throwsFailure(TutorialV3FailureKind.notFound, 'does not belong'),
      );
    });
  });

  group('ready-asset reuse', () {
    test('a completed step is reused, never regenerated', () async {
      final sessionId = await readySession();
      await completeGuideline(sessionId, 1);

      final prepared = await repository.prepareGuideline(
        sessionId: sessionId,
        stepIndex: 1,
      );

      expect(prepared.outcome, TutorialV3GuidelineOutcome.reusedExisting);
      expect(prepared.requiresGeneration, isFalse);
      expect(prepared.step.guidelineStatus, TutorialV3GuidelineStatus.ready);
      expect(prepared.step.guidelineStoragePath, guidelinePath(sessionId, 1));
    });

    test('reuse does not disturb the stored asset or its status', () async {
      final sessionId = await readySession();
      await completeGuideline(sessionId, 1);

      await repository.prepareGuideline(sessionId: sessionId, stepIndex: 1);
      await repository.prepareGuideline(sessionId: sessionId, stepIndex: 1);

      final reopened = (await repository.findSessionById(
        sessionId,
      ))!.requireLoaded;
      expect(
        reopened.stepAt(1)!.guidelineStatus,
        TutorialV3GuidelineStatus.ready,
      );
      expect(reopened.stepAt(1)!.attemptCount, 0);
      expect(reopened.readiness, TutorialV3SessionReadiness.ready);
    });
  });

  group('failed state and bounded retry', () {
    test('a failure keeps the spec, counts the attempt and stores no asset',
        () async {
      final sessionId = await readySession();
      final before = (await repository.findSessionById(
        sessionId,
      ))!.requireLoaded.stepAt(1)!;

      await repository.prepareGuideline(sessionId: sessionId, stepIndex: 1);
      final snapshot = await repository.markGuidelineFailed(
        sessionId: sessionId,
        stepIndex: 1,
        error: 'gemini_no_image_output',
      );

      final step = snapshot.stepAt(1)!;
      expect(step.guidelineStatus, TutorialV3GuidelineStatus.failed);
      expect(step.guidelineStoragePath, isNull);
      expect(step.hasGuideline, isFalse);
      expect(step.attemptCount, before.attemptCount + 1);
      expect(step.lastErrorCode, 'gemini_no_image_output');
      expect(
        (step.spec as dynamic).whereToApply,
        (before.spec as dynamic).whereToApply,
      );
      expect(snapshot.readiness, TutorialV3SessionReadiness.planReady);
    });

    test('a failed step can be retried', () async {
      final sessionId = await readySession();
      await repository.prepareGuideline(sessionId: sessionId, stepIndex: 1);
      await repository.markGuidelineFailed(
        sessionId: sessionId,
        stepIndex: 1,
        error: 'timeout',
      );

      final retried = await repository.prepareGuideline(
        sessionId: sessionId,
        stepIndex: 1,
      );
      expect(
        retried.outcome,
        TutorialV3GuidelineOutcome.claimedForGeneration,
      );
      expect(
        retried.step.guidelineStatus,
        TutorialV3GuidelineStatus.generating,
      );
    });

    test('retries are bounded', () async {
      final sessionId = await readySession();

      for (var attempt = 0;
          attempt < TutorialV3RetryPolicy.maxGuidelineAttempts;
          attempt++) {
        await repository.prepareGuideline(sessionId: sessionId, stepIndex: 1);
        await repository.markGuidelineFailed(
          sessionId: sessionId,
          stepIndex: 1,
          error: 'timeout',
        );
      }

      await expectLater(
        repository.prepareGuideline(sessionId: sessionId, stepIndex: 1),
        throwsFailure(
          TutorialV3FailureKind.generation,
          'all ${TutorialV3RetryPolicy.maxGuidelineAttempts} generation '
              'attempts',
        ),
      );
    });

    test('an exhausted step does not block the rest of the tutorial',
        () async {
      final sessionId = await readySession(
        categories: [TutorialV3Category.foundation, TutorialV3Category.blush],
      );

      for (var attempt = 0;
          attempt < TutorialV3RetryPolicy.maxGuidelineAttempts;
          attempt++) {
        await repository.prepareGuideline(sessionId: sessionId, stepIndex: 1);
        await repository.markGuidelineFailed(
          sessionId: sessionId,
          stepIndex: 1,
          error: 'timeout',
        );
      }

      final snapshot = (await repository.findSessionById(
        sessionId,
      ))!.requireLoaded;
      final next = snapshot.nextGeneratableStep(
        maxAttempts: TutorialV3RetryPolicy.maxGuidelineAttempts,
      );

      expect(next, isNotNull);
      expect(next!.stepIndex, 2, reason: 'should skip the exhausted step');
    });
  });

  group('resume and reopen', () {
    test('reopening keeps completed work and resumes at the first gap',
        () async {
      final sessionId = await readySession(
        categories: [
          TutorialV3Category.foundation,
          TutorialV3Category.blush,
          TutorialV3Category.lipstick,
        ],
      );
      await completeGuideline(sessionId, 1);

      // A fresh repository over the same store, as if the app were reopened.
      final reopened = SupabaseTutorialV3Repository(remote);
      final snapshot = (await reopened.findSessionById(
        sessionId,
      ))!.requireLoaded;

      expect(snapshot.stepAt(1)!.hasGuideline, isTrue);
      expect(snapshot.readiness, TutorialV3SessionReadiness.planReady);
      expect(
        snapshot
            .nextGeneratableStep(
              maxAttempts: TutorialV3RetryPolicy.maxGuidelineAttempts,
            )!
            .stepIndex,
        2,
      );
    });

    test('readiness becomes ready once every guideline exists', () async {
      final sessionId = await readySession(
        categories: [TutorialV3Category.foundation, TutorialV3Category.blush],
      );

      await completeGuideline(sessionId, 1);
      expect(
        (await repository.findSessionById(sessionId))!.readiness,
        TutorialV3SessionReadiness.planReady,
      );

      await completeGuideline(sessionId, 2);
      final snapshot = (await repository.findSessionById(
        sessionId,
      ))!.requireLoaded;

      expect(snapshot.readiness, TutorialV3SessionReadiness.ready);
      expect(snapshot.readiness.hasUsablePlan, isTrue);
      expect(
        snapshot.nextGeneratableStep(
          maxAttempts: TutorialV3RetryPolicy.maxGuidelineAttempts,
        ),
        isNull,
      );
    });

    test('the final look never counts as outstanding work', () async {
      final sessionId = await readySession();
      await completeGuideline(sessionId, 1);

      final snapshot = (await repository.findSessionById(
        sessionId,
      ))!.requireLoaded;

      expect(snapshot.guidelineSteps, hasLength(1));
      expect(snapshot.finalStep!.isFinalLook, isTrue);
      expect(snapshot.readiness, TutorialV3SessionReadiness.ready);
    });
  });

  group('signing', () {
    test('signed URLs are delegated to storage', () async {
      final url = await repository.createSignedUrl('some/path.png');

      expect(url, 'https://signed.example/some/path.png');
      expect(remote.signedPaths, ['some/path.png']);
    });
  });
}
