import 'package:facetune/features/tutorial_v2/data/data_sources/tutorial_v2_remote_data_source.dart';
import 'package:facetune/features/tutorial_v2/data/models/tutorial_v2_session_dto.dart';
import 'package:facetune/features/tutorial_v2/data/repositories/supabase_tutorial_v2_repository.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_category.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_generation_status.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_plan.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_session.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_session_snapshot.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_source_mode.dart';
import 'package:facetune/features/tutorial_v2/domain/errors/tutorial_v2_failure.dart';
import 'package:facetune/features/tutorial_v2/domain/services/tutorial_v2_storage_paths.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/tutorial_v2_fixtures.dart';

class _FakeRemote implements TutorialV2RemoteDataSource {
  String? userId = tutorialV2UserId;
  Map<String, Object?>? analysis = tutorialV2AnalysisRow();

  final sessions = <String, Map<String, Object?>>{};
  final steps = <String, Map<String, Object?>>{};

  int insertSessionCalls = 0;
  int deleteStepsCalls = 0;
  int insertStepsCalls = 0;
  final signedUrls = <String>[];

  @override
  String? get currentUserId => userId;

  @override
  Future<Map<String, Object?>?> findSessionByCanonical({
    required String canonicalImageId,
    required bool isKit,
    required int planVersion,
  }) async {
    final column = isKit
        ? 'canonical_kit_generated_image_id'
        : 'canonical_generated_image_id';
    for (final session in sessions.values) {
      if (session[column] == canonicalImageId &&
          session['plan_version'] == planVersion) {
        return {...session};
      }
    }
    return null;
  }

  @override
  Future<Map<String, Object?>?> findSessionById(String sessionId) async {
    final session = sessions[sessionId];
    return session == null ? null : {...session};
  }

  @override
  Future<Map<String, Object?>> insertSession(
    Map<String, Object?> values,
  ) async {
    insertSessionCalls++;
    final id = 'session-${sessions.length + 1}';
    final row = {
      ...values,
      'id': id,
      'planner_model': null,
      'planner_prompt_version': null,
      'plan_error': null,
      'created_at': '2026-08-26T00:00:00Z',
      'updated_at': '2026-08-26T00:00:00Z',
    };
    sessions[id] = row;
    return {...row};
  }

  @override
  Future<Map<String, Object?>> updateSession({
    required String sessionId,
    required Map<String, Object?> values,
  }) async {
    final row = {...sessions[sessionId]!, ...values};
    sessions[sessionId] = row;
    return {...row};
  }

  @override
  Future<Map<String, Object?>?> findAnalysis(String analysisId) async =>
      analysis == null ? null : {...analysis!};

  @override
  Future<List<Map<String, Object?>>> selectSteps(String sessionId) async =>
      (steps.values
              .where((row) => row['tutorial_v2_session_id'] == sessionId)
              .map((row) => {...row})
              .toList()
            ..sort(
              (a, b) =>
                  (a['step_index']! as int).compareTo(b['step_index']! as int),
            ))
          .toList();

  @override
  Future<void> deleteSteps(String sessionId) async {
    deleteStepsCalls++;
    steps.removeWhere(
      (_, row) => row['tutorial_v2_session_id'] == sessionId,
    );
  }

  @override
  Future<List<Map<String, Object?>>> insertSteps(
    List<Map<String, Object?>> rows,
  ) async {
    insertStepsCalls++;
    final inserted = <Map<String, Object?>>[];
    for (final values in rows) {
      final id = 'step-${steps.length + 1}';
      final row = {
        'guideline_image_path': null,
        'result_image_path': null,
        'guideline_error': null,
        'result_error': null,
        'retry_count': 0,
        'model_name': null,
        'prompt_version': null,
        ...values,
        'id': id,
        'created_at': '2026-08-26T00:00:00Z',
        'updated_at': '2026-08-26T00:00:00Z',
      };
      steps[id] = row;
      inserted.add({...row});
    }
    return inserted;
  }

  @override
  Future<Map<String, Object?>> updateStep({
    required String stepId,
    required Map<String, Object?> values,
  }) async {
    final row = {...steps[stepId]!, ...values};
    steps[stepId] = row;
    return {...row};
  }

  @override
  Future<String> createSignedUrl(String storagePath) async {
    signedUrls.add(storagePath);
    return 'https://signed.example/$storagePath';
  }

  int invokeGuidelineCalls = 0;
  final invokedGuidelines = <String>[];
  TutorialV2RemoteFailure? guidelineFailure;

  @override
  Future<Object?> invokeGuideline({
    required String sessionId,
    required int stepIndex,
  }) async {
    invokeGuidelineCalls++;
    invokedGuidelines.add('$sessionId#$stepIndex');
    if (guidelineFailure != null) {
      // The server marks the step failed before returning the error.
      final failed = steps.values.firstWhere(
        (row) =>
            row['tutorial_v2_session_id'] == sessionId &&
            row['step_index'] == stepIndex,
      );
      steps[failed['id']! as String] = {
        ...failed,
        'guideline_status': 'failed',
        'guideline_error': 'GEMINI_NO_IMAGE_OUTPUT',
        'retry_count': (failed['retry_count']! as int) + 1,
      };
      throw guidelineFailure!;
    }
    // Stands in for the server storing the asset and linking it to the step.
    final row = steps.values.firstWhere(
      (item) =>
          item['tutorial_v2_session_id'] == sessionId &&
          item['step_index'] == stepIndex,
    );
    final path = TutorialV2StoragePaths.guideline(
      userId: tutorialV2UserId,
      analysisId: tutorialV2AnalysisId,
      sessionId: sessionId,
      stepIndex: stepIndex,
    );
    steps[row['id']! as String] = {
      ...row,
      'guideline_status': 'ready',
      'guideline_image_path': path,
      'guideline_error': null,
    };
    return {
      'guideline': {'status': 'ready', 'storagePath': path},
    };
  }
}

TutorialV2Plan _plan({
  TutorialV2SourceMode sourceMode = TutorialV2SourceMode.standardRecommendation,
  String styleCode = 'soft_glam',
  List<TutorialV2Category> categories = const [
    TutorialV2Category.foundation,
    TutorialV2Category.blush,
  ],
}) {
  final context = tutorialV2Context(
    sourceMode: sourceMode,
    styleCode: styleCode,
  );
  if (sourceMode.isMakeupKit) {
    final drafts = [
      for (final category in categories)
        tutorialV2Draft(
          category,
          productSnapshot: tutorialV2Product(
            category: category,
            productId: 'product-${category.code}',
          ),
        ),
      tutorialV2Draft(TutorialV2Category.finalLook),
    ];
    return TutorialV2Plan.fromDrafts(
      context: context,
      drafts: drafts,
      ownedProductIds: {
        for (final category in categories) 'product-${category.code}',
      },
    );
  }
  return TutorialV2Plan.fromDrafts(
    context: context,
    drafts: tutorialV2Drafts(categories),
  );
}

void main() {
  late _FakeRemote remote;
  late SupabaseTutorialV2Repository repository;

  setUp(() {
    remote = _FakeRemote();
    repository = SupabaseTutorialV2Repository(remote);
  });

  Future<TutorialV2SessionSnapshot> create() =>
      repository.getOrCreateSession(
        analysisId: tutorialV2AnalysisId,
        context: tutorialV2Context(),
      );

  group('authentication', () {
    test('every entry point requires a signed-in user', () async {
      remote.userId = null;

      Matcher expired() => throwsA(
        isA<TutorialV2Failure>().having(
          (failure) => failure.kind,
          'kind',
          TutorialV2FailureKind.sessionExpired,
        ),
      );

      await expectLater(create(), expired());
      await expectLater(repository.findSessionById('session-1'), expired());
      await expectLater(
        repository.createSignedUrl('user-1/analyses/a/x.png'),
        expired(),
      );
    });
  });

  group('create session', () {
    test('creates a pending session when none exists', () async {
      final snapshot = await create();

      expect(remote.insertSessionCalls, 1);
      expect(snapshot.status, TutorialV2SessionStatus.pending);
      expect(snapshot.readiness, TutorialV2Readiness.planning);
      expect(snapshot.totalSteps, 0);
      expect(snapshot.plan, isNull);
      expect(snapshot.userId, tutorialV2UserId);
    });

    test('is idempotent — a revisit reuses the same session', () async {
      final first = await create();
      final second = await create();

      expect(remote.insertSessionCalls, 1);
      expect(second.id, first.id);
      expect(remote.sessions.length, 1);
    });

    test('a different canonical target gets its own session', () async {
      await create();
      await repository.getOrCreateSession(
        analysisId: tutorialV2AnalysisId,
        context: tutorialV2Context(canonicalImageId: 'generated-2'),
      );

      expect(remote.insertSessionCalls, 2);
    });

    test('Kit and standard targets do not collide', () async {
      await create();
      await repository.getOrCreateSession(
        analysisId: tutorialV2AnalysisId,
        context: tutorialV2Context(
          sourceMode: TutorialV2SourceMode.makeupKit,
        ),
      );

      expect(remote.insertSessionCalls, 2);
    });

    test('an invalid context never reaches the database', () async {
      await expectLater(
        repository.getOrCreateSession(
          analysisId: tutorialV2AnalysisId,
          context: tutorialV2Context(styleCode: 'disco_glam'),
        ),
        throwsA(
          isA<TutorialV2Failure>().having(
            (failure) => failure.kind,
            'kind',
            TutorialV2FailureKind.planValidation,
          ),
        ),
      );
      expect(remote.insertSessionCalls, 0);
    });

    test('a missing analysis is reported as not found', () async {
      remote.analysis = null;

      await expectLater(
        create(),
        throwsA(
          isA<TutorialV2Failure>().having(
            (failure) => failure.kind,
            'kind',
            TutorialV2FailureKind.notFound,
          ),
        ),
      );
    });
  });

  group('find session', () {
    test('returns null when the session does not exist', () async {
      expect(await repository.findSessionById('nope'), isNull);
    });

    test('loads a persisted session', () async {
      final created = await create();
      final found = await repository.findSessionById(created.id);

      expect(found, isNotNull);
      expect(found!.id, created.id);
    });
  });

  group('persist plan', () {
    test('stores steps and marks the session ready', () async {
      final session = await create();
      final snapshot = await repository.persistPlan(
        sessionId: session.id,
        plan: _plan(),
        plannerModel: 'gemini-test',
        plannerPromptVersion: 'p1',
      );

      expect(snapshot.status, TutorialV2SessionStatus.planReady);
      expect(snapshot.totalSteps, 3);
      expect(snapshot.steps.length, 3);
      expect(snapshot.integrity, TutorialV2SessionIntegrity.intact);
      expect(snapshot.readiness, TutorialV2Readiness.planReady);
      expect(remote.sessions[session.id]!['planner_model'], 'gemini-test');
    });

    test('total_steps always equals the persisted step count', () async {
      final session = await create();

      for (final categories in [
        [TutorialV2Category.lipstick],
        TutorialV2Category.makeupCategories,
        [TutorialV2Category.foundation, TutorialV2Category.eyeliner],
      ]) {
        final snapshot = await repository.persistPlan(
          sessionId: session.id,
          plan: _plan(categories: categories),
        );
        expect(snapshot.totalSteps, snapshot.steps.length);
        expect(snapshot.totalSteps, categories.length + 1);
      }
    });

    test('replanning replaces steps rather than appending', () async {
      final session = await create();
      await repository.persistPlan(sessionId: session.id, plan: _plan());
      final snapshot = await repository.persistPlan(
        sessionId: session.id,
        plan: _plan(categories: const [TutorialV2Category.lipstick]),
      );

      expect(remote.deleteStepsCalls, 2);
      expect(snapshot.steps.length, 2);
      expect(remote.steps.length, 2);
    });

    test('rejects a plan built for a different look', () async {
      final session = await create();

      await expectLater(
        repository.persistPlan(
          sessionId: session.id,
          plan: _plan(styleCode: 'bridal'),
        ),
        throwsA(
          isA<TutorialV2Failure>().having(
            (failure) => failure.message,
            'message',
            contains('different tutorial'),
          ),
        ),
      );
      expect(remote.insertStepsCalls, 0);
    });

    test('rejects a plan for a session that does not exist', () async {
      await expectLater(
        repository.persistPlan(sessionId: 'ghost', plan: _plan()),
        throwsA(
          isA<TutorialV2Failure>().having(
            (failure) => failure.kind,
            'kind',
            TutorialV2FailureKind.notFound,
          ),
        ),
      );
    });

    test('clears a previous planning error', () async {
      final session = await create();
      await repository.markPlanFailed(
        sessionId: session.id,
        error: 'planner_invalid_json',
      );
      final snapshot = await repository.persistPlan(
        sessionId: session.id,
        plan: _plan(),
      );

      expect(snapshot.planError, isNull);
      expect(snapshot.readiness, TutorialV2Readiness.planReady);
    });
  });

  group('plan failure', () {
    test('records the error and stays resumable', () async {
      final session = await create();
      final snapshot = await repository.markPlanFailed(
        sessionId: session.id,
        error: 'planner_invalid_json',
      );

      expect(snapshot.status, TutorialV2SessionStatus.planFailed);
      expect(snapshot.readiness, TutorialV2Readiness.failed);
      expect(snapshot.planError, 'planner_invalid_json');
      expect(snapshot.totalSteps, 0);
      expect(snapshot.isReusable, isTrue);
    });
  });

  group('asset lifecycle', () {
    late TutorialV2SessionSnapshot session;

    setUp(() async {
      final created = await create();
      session = await repository.persistPlan(
        sessionId: created.id,
        plan: _plan(),
      );
    });

    test('moves an asset to generating', () async {
      final snapshot = await repository.updateAssetStatus(
        sessionId: session.id,
        stepIndex: 0,
        asset: TutorialV2AssetKind.guideline,
        status: TutorialV2GenerationStatus.generating,
      );

      expect(
        snapshot.stepAt(0)!.assets.guidelineStatus,
        TutorialV2GenerationStatus.generating,
      );
      expect(snapshot.readiness, TutorialV2Readiness.generating);
    });

    test('a failure records the error and increments the retry count', () async {
      await repository.updateAssetStatus(
        sessionId: session.id,
        stepIndex: 0,
        asset: TutorialV2AssetKind.result,
        status: TutorialV2GenerationStatus.failed,
        error: 'unchanged_generated_image',
      );
      final snapshot = await repository.updateAssetStatus(
        sessionId: session.id,
        stepIndex: 0,
        asset: TutorialV2AssetKind.result,
        status: TutorialV2GenerationStatus.failed,
        error: 'unchanged_generated_image',
      );

      final step = snapshot.stepAt(0)!;
      expect(step.assets.resultError, 'unchanged_generated_image');
      expect(step.assets.retryCount, 2);
      expect(snapshot.readiness, TutorialV2Readiness.failed);
    });

    test('persists an asset reference and marks it ready', () async {
      final path = TutorialV2StoragePaths.guideline(
        userId: tutorialV2UserId,
        analysisId: tutorialV2AnalysisId,
        sessionId: session.id,
        stepIndex: 0,
      );

      final snapshot = await repository.persistAsset(
        sessionId: session.id,
        stepIndex: 0,
        asset: TutorialV2AssetKind.guideline,
        storagePath: path,
        modelName: 'gemini-test',
        promptVersion: 'g1',
      );

      final step = snapshot.stepAt(0)!;
      expect(step.assets.guidelineStatus, TutorialV2GenerationStatus.ready);
      expect(step.assets.guidelinePath, path);
      expect(step.assets.guidelineError, isNull);
    });

    test('reaches ready once every required asset is stored', () async {
      for (var index = 0; index < 2; index++) {
        for (final asset in TutorialV2AssetKind.values) {
          await repository.persistAsset(
            sessionId: session.id,
            stepIndex: index,
            asset: asset,
            storagePath: asset == TutorialV2AssetKind.guideline
                ? TutorialV2StoragePaths.guideline(
                    userId: tutorialV2UserId,
                    analysisId: tutorialV2AnalysisId,
                    sessionId: session.id,
                    stepIndex: index,
                  )
                : TutorialV2StoragePaths.result(
                    userId: tutorialV2UserId,
                    analysisId: tutorialV2AnalysisId,
                    sessionId: session.id,
                    stepIndex: index,
                  ),
          );
        }
      }

      final snapshot = (await repository.findSessionById(session.id))!;
      expect(snapshot.readiness, TutorialV2Readiness.ready);
      expect(snapshot.firstIncompleteStepIndex, isNull);
    });

    test('rejects a path belonging to another step', () async {
      await expectLater(
        repository.persistAsset(
          sessionId: session.id,
          stepIndex: 0,
          asset: TutorialV2AssetKind.result,
          storagePath: TutorialV2StoragePaths.result(
            userId: tutorialV2UserId,
            analysisId: tutorialV2AnalysisId,
            sessionId: session.id,
            stepIndex: 1,
          ),
        ),
        throwsA(isA<TutorialV2Failure>()),
      );
    });

    test('rejects a path belonging to another user', () async {
      await expectLater(
        repository.persistAsset(
          sessionId: session.id,
          stepIndex: 0,
          asset: TutorialV2AssetKind.result,
          storagePath: TutorialV2StoragePaths.result(
            userId: 'user-2',
            analysisId: tutorialV2AnalysisId,
            sessionId: session.id,
            stepIndex: 0,
          ),
        ),
        throwsA(isA<TutorialV2Failure>()),
      );
    });

    test('rejects an original selfie path', () async {
      await expectLater(
        repository.persistAsset(
          sessionId: session.id,
          stepIndex: 0,
          asset: TutorialV2AssetKind.result,
          storagePath:
              '$tutorialV2UserId/analyses/$tutorialV2AnalysisId/original/abcd.jpg',
        ),
        throwsA(isA<TutorialV2Failure>()),
      );
    });

    test('rejects the wrong asset kind for the path', () async {
      await expectLater(
        repository.persistAsset(
          sessionId: session.id,
          stepIndex: 0,
          asset: TutorialV2AssetKind.result,
          storagePath: TutorialV2StoragePaths.guideline(
            userId: tutorialV2UserId,
            analysisId: tutorialV2AnalysisId,
            sessionId: session.id,
            stepIndex: 0,
          ),
        ),
        throwsA(isA<TutorialV2Failure>()),
      );
    });

    test('a rejected path is never written', () async {
      final before = {...remote.steps};
      try {
        await repository.persistAsset(
          sessionId: session.id,
          stepIndex: 0,
          asset: TutorialV2AssetKind.result,
          storagePath: 'user-2/analyses/x/tutorial-v2/y/step_0001_result.png',
        );
      } catch (_) {
        // expected
      }
      expect(remote.steps.toString(), before.toString());
    });

    test('rejects a step the plan does not contain', () async {
      await expectLater(
        repository.updateAssetStatus(
          sessionId: session.id,
          stepIndex: 99,
          asset: TutorialV2AssetKind.result,
          status: TutorialV2GenerationStatus.generating,
        ),
        throwsA(
          isA<TutorialV2Failure>().having(
            (failure) => failure.kind,
            'kind',
            TutorialV2FailureKind.notFound,
          ),
        ),
      );
    });
  });

  group('idempotent reload', () {
    test('reopening a ready tutorial changes nothing', () async {
      final created = await create();
      await repository.persistPlan(sessionId: created.id, plan: _plan());
      final insertsAfterPlan = remote.insertStepsCalls;
      final deletesAfterPlan = remote.deleteStepsCalls;

      final reopened = await repository.getOrCreateSession(
        analysisId: tutorialV2AnalysisId,
        context: tutorialV2Context(),
      );

      expect(reopened.id, created.id);
      expect(remote.insertSessionCalls, 1);
      expect(remote.insertStepsCalls, insertsAfterPlan);
      expect(remote.deleteStepsCalls, deletesAfterPlan);
      expect(reopened.steps.length, 3);
      expect(reopened.plan, isNotNull);
    });

    test('a reopened tutorial keeps its stored assets', () async {
      final created = await create();
      await repository.persistPlan(sessionId: created.id, plan: _plan());
      final path = TutorialV2StoragePaths.result(
        userId: tutorialV2UserId,
        analysisId: tutorialV2AnalysisId,
        sessionId: created.id,
        stepIndex: 0,
      );
      await repository.persistAsset(
        sessionId: created.id,
        stepIndex: 0,
        asset: TutorialV2AssetKind.result,
        storagePath: path,
      );

      final reopened = await repository.getOrCreateSession(
        analysisId: tutorialV2AnalysisId,
        context: tutorialV2Context(),
      );

      expect(reopened.stepAt(0)!.assets.resultPath, path);
      expect(
        reopened.stepAt(0)!.assets.resultStatus,
        TutorialV2GenerationStatus.ready,
      );
    });
  });

  group('stale and incompatible reloads', () {
    test('a V1 session is surfaced as incompatible, not repaired', () async {
      final created = await create();
      remote.sessions[created.id] = {
        ...remote.sessions[created.id]!,
        'plan_version': 1,
      };

      final reopened = (await repository.findSessionById(created.id))!;

      expect(reopened.readiness, TutorialV2Readiness.incompatible);
      expect(reopened.isReusable, isFalse);
      // The row is left exactly as it was found.
      expect(remote.sessions[created.id]!['plan_version'], 1);
    });

    test('a session whose steps vanished is stale, not silently replanned', () async {
      final created = await create();
      await repository.persistPlan(sessionId: created.id, plan: _plan());
      remote.steps.clear();

      final reopened = await repository.getOrCreateSession(
        analysisId: tutorialV2AnalysisId,
        context: tutorialV2Context(),
      );

      expect(reopened.integrity, TutorialV2SessionIntegrity.missingSteps);
      expect(reopened.readiness, TutorialV2Readiness.stale);
      expect(reopened.isReusable, isFalse);
      // Recovery is the caller's decision; the repository does not replan.
      expect(remote.insertStepsCalls, 1);
    });

    test('a stale session can be recovered by replanning', () async {
      final created = await create();
      await repository.persistPlan(sessionId: created.id, plan: _plan());
      remote.steps.clear();

      final recovered = await repository.persistPlan(
        sessionId: created.id,
        plan: _plan(),
      );

      expect(recovered.integrity, TutorialV2SessionIntegrity.intact);
      expect(recovered.readiness, TutorialV2Readiness.planReady);
    });
  });

  group('Kit mode', () {
    test('persists and reloads owned product snapshots', () async {
      final created = await repository.getOrCreateSession(
        analysisId: tutorialV2AnalysisId,
        context: tutorialV2Context(
          sourceMode: TutorialV2SourceMode.makeupKit,
        ),
      );
      final snapshot = await repository.persistPlan(
        sessionId: created.id,
        plan: _plan(sourceMode: TutorialV2SourceMode.makeupKit),
      );

      expect(
        snapshot.stepAt(0)!.spec.productSnapshot!.productId,
        'product-foundation',
      );
      expect(snapshot.stepAt(2)!.spec.productSnapshot, isNull);
      expect(snapshot.integrity, TutorialV2SessionIntegrity.intact);
    });
  });

  group('guideline generation', () {
    late TutorialV2SessionSnapshot session;

    setUp(() async {
      final created = await create();
      session = await repository.persistPlan(
        sessionId: created.id,
        plan: _plan(),
      );
    });

    test('generates and attaches the guideline asset', () async {
      final snapshot = await repository.generateGuideline(
        sessionId: session.id,
        stepIndex: 0,
      );

      final step = snapshot.stepAt(0)!;
      expect(step.assets.guidelineStatus, TutorialV2GenerationStatus.ready);
      expect(step.assets.guidelinePath, contains('step_0001_guideline.png'));
      expect(remote.invokeGuidelineCalls, 1);
    });

    test('the stored path is owner-scoped for this session and step', () async {
      final snapshot = await repository.generateGuideline(
        sessionId: session.id,
        stepIndex: 1,
      );

      expect(
        TutorialV2StoragePaths.isOwnedAssetPath(
          snapshot.stepAt(1)!.assets.guidelinePath!,
          userId: tutorialV2UserId,
          analysisId: tutorialV2AnalysisId,
          sessionId: session.id,
          stepIndex: 1,
          asset: 'guideline',
        ),
        isTrue,
      );
    });

    test('is idempotent — a ready guideline is reused, not regenerated', () async {
      await repository.generateGuideline(sessionId: session.id, stepIndex: 0);
      final second = await repository.generateGuideline(
        sessionId: session.id,
        stepIndex: 0,
      );

      expect(remote.invokeGuidelineCalls, 1);
      expect(
        second.stepAt(0)!.assets.guidelineStatus,
        TutorialV2GenerationStatus.ready,
      );
    });

    test('each step is generated independently', () async {
      await repository.generateGuideline(sessionId: session.id, stepIndex: 0);
      await repository.generateGuideline(sessionId: session.id, stepIndex: 1);

      expect(remote.invokeGuidelineCalls, 2);
      expect(remote.invokedGuidelines, [
        '${session.id}#0',
        '${session.id}#1',
      ]);
    });

    test('a failure surfaces and leaves the written step spec intact', () async {
      remote.guidelineFailure = const TutorialV2RemoteFailure(
        status: 502,
        message: 'no image',
        retryable: true,
      );

      await expectLater(
        repository.generateGuideline(sessionId: session.id, stepIndex: 0),
        throwsA(isA<TutorialV2Failure>()),
      );

      final snapshot = (await repository.findSessionById(session.id))!;
      final step = snapshot.stepAt(0)!;
      expect(step.assets.guidelineStatus, TutorialV2GenerationStatus.failed);
      expect(step.assets.guidelinePath, isNull);
      expect(step.assets.retryCount, 1);
      // The instruction the user reads is untouched by a failed image.
      expect(step.spec.whereToApply, isNotEmpty);
      expect(step.spec.direction, isNotEmpty);
      expect(snapshot.readiness, TutorialV2Readiness.failed);
    });

    test('a failed guideline can be retried', () async {
      remote.guidelineFailure = const TutorialV2RemoteFailure(
        status: 502,
        message: 'no image',
        retryable: true,
      );
      await expectLater(
        repository.generateGuideline(sessionId: session.id, stepIndex: 0),
        throwsA(isA<TutorialV2Failure>()),
      );

      remote.guidelineFailure = null;
      final recovered = await repository.generateGuideline(
        sessionId: session.id,
        stepIndex: 0,
      );

      expect(
        recovered.stepAt(0)!.assets.guidelineStatus,
        TutorialV2GenerationStatus.ready,
      );
      expect(remote.invokeGuidelineCalls, 2);
    });

    test('rejects a step the plan does not contain', () async {
      await expectLater(
        repository.generateGuideline(sessionId: session.id, stepIndex: 99),
        throwsA(
          isA<TutorialV2Failure>().having(
            (failure) => failure.kind,
            'kind',
            TutorialV2FailureKind.notFound,
          ),
        ),
      );
      expect(remote.invokeGuidelineCalls, 0);
    });

    test('rejects an unknown session', () async {
      await expectLater(
        repository.generateGuideline(sessionId: 'ghost', stepIndex: 0),
        throwsA(isA<TutorialV2Failure>()),
      );
      expect(remote.invokeGuidelineCalls, 0);
    });

    test('requires authentication', () async {
      remote.userId = null;
      await expectLater(
        repository.generateGuideline(sessionId: session.id, stepIndex: 0),
        throwsA(
          isA<TutorialV2Failure>().having(
            (failure) => failure.kind,
            'kind',
            TutorialV2FailureKind.sessionExpired,
          ),
        ),
      );
      expect(remote.invokeGuidelineCalls, 0);
    });

    test('the final step never requests a guideline', () async {
      // The canonical-reuse step needs no guideline asset at all.
      final finalStep = session.steps.last;
      expect(finalStep.spec.isCanonicalReuse, isTrue);
      expect(finalStep.spec.requiresGuidelineAsset, isFalse);
      expect(finalStep.isSatisfied, isTrue);
    });
  });

  group('signed urls', () {
    test('delegates to storage', () async {
      final url = await repository.createSignedUrl('user-1/analyses/a/x.png');

      expect(url, contains('user-1/analyses/a/x.png'));
      expect(remote.signedUrls, ['user-1/analyses/a/x.png']);
    });
  });

  group('column contracts', () {
    test('selected columns cover what the DTO reads', () {
      for (final column in [
        'source_mode',
        'makeup_style',
        'canonical_generated_image_id',
        'canonical_kit_generated_image_id',
        'plan_version',
        'total_steps',
        'status',
      ]) {
        expect(TutorialV2SessionDto.sessionColumns, contains(column));
      }
      for (final column in [
        'step_index',
        'category',
        'step_spec_json',
        'product_snapshot_json',
        'guideline_status',
        'result_status',
        'retry_count',
      ]) {
        expect(TutorialV2SessionDto.stepColumns, contains(column));
      }
      for (final column in ['face_shape', 'undertone', 'eye_color']) {
        expect(TutorialV2SessionDto.analysisColumns, contains(column));
      }
    });
  });
}
