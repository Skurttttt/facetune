import 'package:facetune/features/tutorial_v3/data/data_sources/tutorial_v3_remote_data_source.dart';
import 'package:facetune/features/tutorial_v3/data/repositories/supabase_tutorial_v3_repository.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_category.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_geometry.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_geometry_status.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_session_readiness.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_session_snapshot.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_session_status.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_source_mode.dart';
import 'package:facetune/features/tutorial_v3/domain/errors/tutorial_v3_failure.dart';
import 'package:facetune/features/tutorial_v3/domain/repositories/tutorial_v3_repository.dart';
import 'package:facetune/features/tutorial_v3/domain/services/tutorial_v3_retry_policy.dart';
import 'package:facetune/features/tutorial_v3/domain/value_objects/tutorial_v3_plan_version.dart';
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
  int claimCalls = 0;
  int openCalls = 0;

  /// Stands in for `generated_images` and `kit_generated_images`.
  final Map<String, _Preview> previews = <String, _Preview>{
    'generated-1': const _Preview(kit: false),
    'generated-2': const _Preview(kit: false),
    'kit-generated-1': const _Preview(kit: true),
  };

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
        'geometry_status': 'pending',
      },
    ];
    return id;
  }

  @override
  String? get currentUserId => userId;

  /// Stands in for `open_tutorial_v3_session`: resolve the preview, then reuse
  /// or create, all from rows the caller owns.
  @override
  Future<String> openSession({
    required String canonicalImageId,
    required bool kit,
  }) async {
    openCalls++;
    final preview = previews[canonicalImageId];
    if (preview == null || preview.kit != kit) {
      throw const TutorialV3Failure(
        'The final look for this tutorial is no longer available.',
        kind: TutorialV3FailureKind.notFound,
        retryable: false,
      );
    }
    final existing = await findSessionByCanonicalImage(
      kit: kit,
      canonicalImageId: canonicalImageId,
    );
    if (existing != null) return existing['id']! as String;

    final row = await insertSession(<String, Object?>{
      'user_id': userId,
      'analysis_id': preview.analysisId,
      'source_mode': kit ? 'makeup_kit' : 'standard',
      'recommendation_id': kit ? null : preview.recommendationId,
      'kit_recommendation_id': kit ? preview.recommendationId : null,
      'makeup_style': testStyleCode,
      'canonical_generated_image_id': kit ? null : canonicalImageId,
      'canonical_kit_generated_image_id': kit ? canonicalImageId : null,
      'canonical_image_path': preview.path,
      'total_steps': 0,
      'plan_version': TutorialV3PlanVersion.currentValue,
      'status': TutorialV3SessionStatus.planning.code,
    });
    return row['id']! as String;
  }

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

  /// Mirrors `claim_tutorial_v3_geometry`: one decision, no read-then-write
  /// the caller could interleave.
  @override
  Future<Map<String, Object?>> claimGeometry({
    required String sessionId,
    required int stepIndex,
    required int maxAttempts,
    required int schemaVersion,
  }) async {
    claimCalls++;
    for (final row in steps[sessionId] ?? const <Map<String, Object?>>[]) {
      if (row['step_index'] != stepIndex) continue;
      if (row['category'] == TutorialV3Category.finalLook.code) {
        return <String, Object?>{'outcome': 'final_look'};
      }
      var stale = false;
      if (row['geometry_status'] == TutorialV3GeometryStatus.ready.code &&
          row['geometry_json'] != null) {
        if (row['geometry_schema_version'] == schemaVersion) {
          return <String, Object?>{
            'outcome': 'reused',
            'schema_version': row['geometry_schema_version'],
          };
        }
        stale = true;
      }
      if (!stale &&
          row['geometry_status'] == TutorialV3GeometryStatus.generating.code) {
        return <String, Object?>{'outcome': 'in_flight'};
      }
      final attempts = (row['attempt_count'] as int?) ?? 0;
      if (attempts >= maxAttempts) {
        return <String, Object?>{
          'outcome': 'exhausted',
          'attempt_count': attempts,
        };
      }
      final replaced = row['geometry_schema_version'];
      row['geometry_status'] = TutorialV3GeometryStatus.generating.code;
      row['geometry_error'] = null;
      row['geometry_json'] = null;
      row['geometry_schema_version'] = null;
      return <String, Object?>{
        'outcome': 'claimed',
        'replaced_schema_version': stale ? replaced : null,
      };
    }
    return <String, Object?>{'outcome': 'not_found'};
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
          !expectedStatuses.contains(row['geometry_status'])) {
        return null;
      }
      row.addAll(values);
      return {...row};
    }
    return null;
  }

  @override
  Future<String?> findOriginalImagePath(String analysisId) async =>
      analysisId == _analysis
      ? '$_user/analyses/$_analysis/original/a.jpg'
      : null;

  @override
  Future<String> createSignedUrl(String storagePath) async {
    signedPaths.add(storagePath);
    return 'https://signed.example/$storagePath';
  }
}

/// A tutorial entry. The preview id defaults to one that exists in the mode
/// being asked for, since a mismatch is now simply "not found".
TutorialV3EntryPoint _entry({
  TutorialV3SourceMode sourceMode = TutorialV3SourceMode.standard,
  String? canonicalImageId,
}) => TutorialV3EntryPoint(
  canonicalImageId:
      canonicalImageId ??
      (sourceMode.isKit ? 'kit-generated-1' : 'generated-1'),
  sourceMode: sourceMode,
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
    final created = await repository.openSession(
      _entry(sourceMode: sourceMode),
    );
    final sessionId = created.sessionId;
    await repository.persistPlan(
      sessionId: sessionId,
      plan: planTeaching(categories, sourceMode: sourceMode),
    );
    return sessionId;
  }

  /// The category the seeded plan teaches at [stepIndex], so geometry written
  /// in a test always agrees with the persisted Step Spec.
  Future<TutorialV3Category> categoryAt(String sessionId, int stepIndex) async {
    final loaded = (await repository.findSessionById(sessionId))!.requireLoaded;
    return loaded.stepAt(stepIndex)!.spec.category;
  }

  Future<void> completeGuideline(String sessionId, int stepIndex) async {
    await repository.prepareGeometry(
      sessionId: sessionId,
      stepIndex: stepIndex,
    );
    await repository.persistGeometry(
      sessionId: sessionId,
      stepIndex: stepIndex,
      geometry: testGeometry(category: await categoryAt(sessionId, stepIndex)),
    );
  }

  group('create and load', () {
    test('creates a planning session with no steps', () async {
      final snapshot = (await repository.openSession(_entry())).requireLoaded;

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
      final first = await repository.openSession(_entry());
      final second = await repository.openSession(_entry());

      expect(second.sessionId, first.sessionId);
      expect(remote.insertCount, 1);
    });

    test('a different canonical preview starts a different tutorial', () async {
      final first = await repository.openSession(_entry());
      final second = await repository.openSession(
        _entry(canonicalImageId: 'generated-2'),
      );

      expect(second.sessionId, isNot(first.sessionId));
      expect(remote.insertCount, 2);
    });

    test('a Kit session is keyed on the Kit preview column', () async {
      await repository.openSession(
        _entry(sourceMode: TutorialV3SourceMode.makeupKit),
      );
      final row = remote.sessions.values.single;

      // The two chains are separate tables and separate columns. A Kit
      // tutorial keyed on the standard column would collide with the standard
      // tutorial for the same analysis.
      expect(row['canonical_kit_generated_image_id'], 'kit-generated-1');
      expect(row['canonical_generated_image_id'], isNull);
    });

    test('the same analysis can have one tutorial per mode', () async {
      final standard = await repository.openSession(_entry());
      final kit = await repository.openSession(
        _entry(sourceMode: TutorialV3SourceMode.makeupKit),
      );

      expect(kit.sessionId, isNot(standard.sessionId));
      expect(remote.insertCount, 2);
    });
    test('the client names a preview and nothing else', () async {
      // The analysis, the recommendation, the selected look and the canonical
      // path are all derived server-side. There is no parameter through which
      // a caller could supply any of them.
      await repository.openSession(_entry());
      final row = remote.sessions.values.single;

      expect(remote.openCalls, 1);
      expect(row['analysis_id'], _analysis);
      expect(row['recommendation_id'], 'recommendation-1');
      expect(row['makeup_style'], testStyleCode);
      expect(
        row['canonical_image_path'],
        '$_user/analyses/$_analysis/generated/r/preview_0001.png',
      );
    });

    test('a Kit entry resolves the Kit chain', () async {
      await repository.openSession(
        _entry(
          sourceMode: TutorialV3SourceMode.makeupKit,
          canonicalImageId: 'kit-generated-1',
        ),
      );
      final row = remote.sessions.values.single;

      expect(row['source_mode'], 'makeup_kit');
      expect(row['kit_recommendation_id'], 'kit-recommendation-1');
      expect(row['recommendation_id'], isNull);
      expect(
        row['canonical_image_path'],
        '$_user/analyses/$_analysis/kit-generated/k/preview_0001.png',
      );
    });

    test('a preview from the other chain is not found', () async {
      // Asking for a standard preview in Kit mode reads the Kit table, where
      // that id does not exist. The mode cannot be mismatched because it
      // selects which table is read.
      await expectLater(
        repository.openSession(
          _entry(
            sourceMode: TutorialV3SourceMode.makeupKit,
            canonicalImageId: 'generated-1',
          ),
        ),
        throwsFailure(TutorialV3FailureKind.notFound, 'no longer available'),
      );
      expect(remote.insertCount, 0);
    });

    test('a preview that does not exist is not found', () async {
      await expectLater(
        repository.openSession(_entry(canonicalImageId: 'generated-missing')),
        throwsFailure(TutorialV3FailureKind.notFound, 'no longer available'),
      );
      expect(remote.insertCount, 0);
    });

    test('a stored session pointing at the other chain is refused', () async {
      // A row written before the entry resolver existed. Opening it would
      // teach toward the wrong look for the same face.
      await repository.openSession(_entry());
      remote.sessions.values.single['canonical_image_path'] =
          '$_user/analyses/$_analysis/kit-generated/k/preview_0001.png';

      await expectLater(
        repository.openSession(_entry()),
        throwsFailure(
          TutorialV3FailureKind.validation,
          'points at the wrong final look',
        ),
      );
    });

    test('requires an authenticated caller', () async {
      remote.userId = null;
      await expectLater(
        repository.openSession(_entry()),
        throwsFailure(TutorialV3FailureKind.sessionExpired, 'Sign in'),
      );
    });

    test('an unknown session id reads as null, not as an error', () async {
      expect(await repository.findSessionById('nope'), isNull);
    });

    test('operating on an unknown session fails as not found', () async {
      await expectLater(
        repository.prepareGeometry(sessionId: 'nope', stepIndex: 1),
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

    test(
      'get-or-create returns it instead of duplicating the tutorial',
      () async {
        remote.seedSessionAtPlanVersion(4);

        final snapshot = await repository.openSession(_entry());

        expect(snapshot, isA<TutorialV3IncompatibleSession>());
        expect(
          remote.insertCount,
          0,
          reason: 'must not start a second tutorial',
        );
      },
    );

    test('requireLoaded explains why it cannot be opened', () async {
      final id = remote.seedSessionAtPlanVersion(9);
      final snapshot = (await repository.findSessionById(id))!;

      expect(
        () => snapshot.requireLoaded,
        throwsFailure(TutorialV3FailureKind.validation, 'plan version 9'),
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
        () => repository.prepareGeometry(sessionId: id, stepIndex: 1),
        () => repository.markGeometryFailed(
          sessionId: id,
          stepIndex: 1,
          error: 'x',
        ),
        () => repository.persistGeometry(
          sessionId: id,
          stepIndex: 1,
          geometry: testGeometry(),
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
      final created = await repository.openSession(_entry());
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
        snapshot.finalStep!.geometryStatus,
        TutorialV3GeometryStatus.notRequired,
      );
      expect(
        snapshot.stepAt(1)!.geometryStatus,
        TutorialV3GeometryStatus.pending,
      );
    });

    test('rejects an invalid plan before writing anything', () async {
      final created = await repository.openSession(_entry());

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
      final created = await repository.openSession(_entry());

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
      final created = await repository.openSession(_entry());

      await expectLater(
        repository.persistPlan(
          sessionId: created.sessionId,
          plan: planTeaching([
            TutorialV3Category.blush,
          ], sourceMode: TutorialV3SourceMode.makeupKit),
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
      final created = await repository.openSession(_entry());
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
  group('geometry lifecycle', () {
    test('preparing a pending step claims it for mapping', () async {
      final sessionId = await readySession();
      final prepared = await repository.prepareGeometry(
        sessionId: sessionId,
        stepIndex: 1,
      );

      expect(prepared.outcome, TutorialV3GeometryOutcome.claimedForGeneration);
      expect(prepared.requiresMapping, isTrue);
      expect(prepared.replacedStaleGeometry, isFalse);
      expect(prepared.step.geometryStatus, TutorialV3GeometryStatus.generating);
      expect(prepared.session.readiness, TutorialV3SessionReadiness.generating);
    });

    test('a second concurrent claim is refused', () async {
      final sessionId = await readySession();
      await repository.prepareGeometry(sessionId: sessionId, stepIndex: 1);

      await expectLater(
        repository.prepareGeometry(sessionId: sessionId, stepIndex: 1),
        throwsFailure(TutorialV3FailureKind.validation, 'already being mapped'),
      );
    });

    test('the final look can never be prepared', () async {
      final sessionId = await readySession();

      await expectLater(
        repository.prepareGeometry(sessionId: sessionId, stepIndex: 2),
        throwsFailure(
          TutorialV3FailureKind.validation,
          'reuses the canonical preview',
        ),
      );
    });

    test('a claimed step accepts its own geometry', () async {
      final sessionId = await readySession();
      await repository.prepareGeometry(sessionId: sessionId, stepIndex: 1);

      final geometry = testGeometry();
      final snapshot = await repository.persistGeometry(
        sessionId: sessionId,
        stepIndex: 1,
        geometry: geometry,
        modelName: 'geometry-model',
        promptVersion: 'v3-geometry-mapper-1',
      );

      final step = snapshot.stepAt(1)!;
      expect(step.geometryStatus, TutorialV3GeometryStatus.ready);
      expect(step.hasGeometry, isTrue);
      expect(step.hasStaleGeometry, isFalse);
      expect(step.geometrySchemaVersion, tutorialV3GeometrySchemaVersion);
      expect(step.geometry!.primitives, hasLength(1));
      expect(snapshot.readiness, TutorialV3SessionReadiness.ready);
    });

    test('an unclaimed step cannot be given geometry', () async {
      final sessionId = await readySession();

      await expectLater(
        repository.persistGeometry(
          sessionId: sessionId,
          stepIndex: 1,
          geometry: testGeometry(),
        ),
        throwsFailure(TutorialV3FailureKind.validation, 'was not claimed'),
      );
    });

    test('geometry for another category is refused', () async {
      // The step's persisted Step Spec is the authority on what it teaches.
      // A document for a different category would render a confidently wrong
      // overlay, so it is rejected rather than stored.
      final sessionId = await readySession(
        categories: [TutorialV3Category.blush],
      );
      await repository.prepareGeometry(sessionId: sessionId, stepIndex: 1);

      await expectLater(
        repository.persistGeometry(
          sessionId: sessionId,
          stepIndex: 1,
          geometry: testGeometry(category: TutorialV3Category.eyeliner),
        ),
        throwsFailure(
          TutorialV3FailureKind.validation,
          'teaches "blush" but this geometry describes "eyeliner"',
        ),
      );

      final step = (await repository.findSessionById(
        sessionId,
      ))!.requireLoaded.stepAt(1)!;
      expect(step.geometry, isNull, reason: 'a refused document was stored');
    });

    test('geometry from another schema version cannot be stored', () async {
      final sessionId = await readySession();
      await repository.prepareGeometry(sessionId: sessionId, stepIndex: 1);

      await expectLater(
        repository.persistGeometry(
          sessionId: sessionId,
          stepIndex: 1,
          geometry: testGeometry(
            schemaVersion: tutorialV3GeometrySchemaVersion + 1,
          ),
        ),
        throwsFailure(
          TutorialV3FailureKind.validation,
          'cannot be stored by this build',
        ),
      );
    });

    test('a step is only reachable through its own session', () async {
      // updateStep matches on the session AND the index, so the same index in
      // a second tutorial is a different row.
      final first = await readySession();
      final second = await repository.openSession(
        _entry(canonicalImageId: 'generated-2'),
      );
      await repository.persistPlan(
        sessionId: second.sessionId,
        plan: planTeaching([TutorialV3Category.blush]),
      );
      await repository.prepareGeometry(sessionId: first, stepIndex: 1);

      await expectLater(
        repository.persistGeometry(
          sessionId: second.sessionId,
          stepIndex: 1,
          geometry: testGeometry(),
        ),
        throwsFailure(TutorialV3FailureKind.validation, 'was not claimed'),
      );
    });

    test('the final look never accepts geometry', () async {
      final sessionId = await readySession();

      await expectLater(
        repository.persistGeometry(
          sessionId: sessionId,
          stepIndex: 2,
          geometry: testGeometry(),
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
        repository.markGeometryFailed(
          sessionId: sessionId,
          stepIndex: 99,
          error: 'x',
        ),
        throwsFailure(TutorialV3FailureKind.notFound, 'does not belong'),
      );
    });
  });

  group('geometry reuse', () {
    test('a completed step is reused, never regenerated', () async {
      final sessionId = await readySession();
      await completeGuideline(sessionId, 1);

      final prepared = await repository.prepareGeometry(
        sessionId: sessionId,
        stepIndex: 1,
      );

      expect(prepared.outcome, TutorialV3GeometryOutcome.reusedExisting);
      expect(prepared.requiresMapping, isFalse);
      expect(prepared.step.geometryStatus, TutorialV3GeometryStatus.ready);
      expect(prepared.step.hasGeometry, isTrue);
      expect(
        remote.claimCalls,
        2,
        reason: 'reuse must still go through the claim',
      );
    });

    test('geometry from an older schema is replaced, never reused', () async {
      // A document this build cannot interpret is discarded and re-mapped.
      // Reusing it would render a vocabulary the painter does not know.
      final sessionId = await readySession();
      await completeGuideline(sessionId, 1);
      remote.steps[sessionId]!.firstWhere(
        (row) => row['step_index'] == 1,
      )['geometry_schema_version'] = tutorialV3GeometrySchemaVersion - 1;

      final prepared = await repository.prepareGeometry(
        sessionId: sessionId,
        stepIndex: 1,
      );

      expect(
        prepared.outcome,
        TutorialV3GeometryOutcome.claimedAfterStaleGeometry,
      );
      expect(prepared.requiresMapping, isTrue);
      expect(prepared.replacedStaleGeometry, isTrue);
      expect(prepared.step.geometryStatus, TutorialV3GeometryStatus.generating);
      expect(prepared.step.geometry, isNull);
    });

    test('reuse does not disturb the stored geometry or its status', () async {
      final sessionId = await readySession();
      await completeGuideline(sessionId, 1);

      await repository.prepareGeometry(sessionId: sessionId, stepIndex: 1);
      await repository.prepareGeometry(sessionId: sessionId, stepIndex: 1);

      final reopened = (await repository.findSessionById(
        sessionId,
      ))!.requireLoaded;
      expect(
        reopened.stepAt(1)!.geometryStatus,
        TutorialV3GeometryStatus.ready,
      );
      expect(reopened.stepAt(1)!.attemptCount, 0);
      expect(reopened.readiness, TutorialV3SessionReadiness.ready);
    });
  });

  group('failed state and bounded retry', () {
    test(
      'a failure keeps the spec, counts the attempt and stores no asset',
      () async {
        final sessionId = await readySession();
        final before = (await repository.findSessionById(
          sessionId,
        ))!.requireLoaded.stepAt(1)!;

        await repository.prepareGeometry(sessionId: sessionId, stepIndex: 1);
        final snapshot = await repository.markGeometryFailed(
          sessionId: sessionId,
          stepIndex: 1,
          error: 'gemini_no_image_output',
        );

        final step = snapshot.stepAt(1)!;
        expect(step.geometryStatus, TutorialV3GeometryStatus.failed);
        expect(step.geometry, isNull);
        expect(step.geometrySchemaVersion, isNull);
        expect(step.hasGeometry, isFalse);
        expect(step.attemptCount, before.attemptCount + 1);
        expect(step.lastErrorCode, 'gemini_no_image_output');
        expect(
          (step.spec as dynamic).whereToApply,
          (before.spec as dynamic).whereToApply,
        );
        expect(snapshot.readiness, TutorialV3SessionReadiness.planReady);
      },
    );

    test('a failed step can be retried', () async {
      final sessionId = await readySession();
      await repository.prepareGeometry(sessionId: sessionId, stepIndex: 1);
      await repository.markGeometryFailed(
        sessionId: sessionId,
        stepIndex: 1,
        error: 'timeout',
      );

      final retried = await repository.prepareGeometry(
        sessionId: sessionId,
        stepIndex: 1,
      );
      expect(retried.outcome, TutorialV3GeometryOutcome.claimedForGeneration);
      expect(retried.step.geometryStatus, TutorialV3GeometryStatus.generating);
    });

    test('retries are bounded', () async {
      final sessionId = await readySession();

      for (
        var attempt = 0;
        attempt < TutorialV3RetryPolicy.maxGuidelineAttempts;
        attempt++
      ) {
        await repository.prepareGeometry(sessionId: sessionId, stepIndex: 1);
        await repository.markGeometryFailed(
          sessionId: sessionId,
          stepIndex: 1,
          error: 'timeout',
        );
      }

      await expectLater(
        repository.prepareGeometry(sessionId: sessionId, stepIndex: 1),
        throwsFailure(
          TutorialV3FailureKind.generation,
          'all ${TutorialV3RetryPolicy.maxGuidelineAttempts} mapping '
          'attempts',
        ),
      );
    });

    test('an exhausted step does not block the rest of the tutorial', () async {
      final sessionId = await readySession(
        categories: [TutorialV3Category.foundation, TutorialV3Category.blush],
      );

      for (
        var attempt = 0;
        attempt < TutorialV3RetryPolicy.maxGuidelineAttempts;
        attempt++
      ) {
        await repository.prepareGeometry(sessionId: sessionId, stepIndex: 1);
        await repository.markGeometryFailed(
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
    test(
      'reopening keeps completed work and resumes at the first gap',
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

        expect(snapshot.stepAt(1)!.hasGeometry, isTrue);
        expect(snapshot.readiness, TutorialV3SessionReadiness.planReady);
        expect(
          snapshot
              .nextGeneratableStep(
                maxAttempts: TutorialV3RetryPolicy.maxGuidelineAttempts,
              )!
              .stepIndex,
          2,
        );
      },
    );

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

      expect(snapshot.geometrySteps, hasLength(1));
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

/// A row from `generated_images` or `kit_generated_images`, reduced to what
/// the entry resolver reads.
class _Preview {
  const _Preview({required this.kit});

  final bool kit;

  String get analysisId => _analysis;
  String get recommendationId =>
      kit ? 'kit-recommendation-1' : 'recommendation-1';

  String get path => kit
      ? '$_user/analyses/$_analysis/kit-generated/k/preview_0001.png'
      : '$_user/analyses/$_analysis/generated/r/preview_0001.png';
}
