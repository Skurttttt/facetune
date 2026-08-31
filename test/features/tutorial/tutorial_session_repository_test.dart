import 'package:facetune/features/tutorial/data/data_sources/tutorial_remote_data_source.dart';
import 'package:facetune/features/tutorial/data/models/tutorial_dtos.dart';
import 'package:facetune/features/tutorial/data/repositories/supabase_tutorial_repositories.dart';
import 'package:facetune/features/tutorial/domain/entities/canonical_preview_ref.dart';
import 'package:facetune/features/tutorial/domain/entities/recommendation_source_mode.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/tutorial/domain/errors/tutorial_failure.dart';
import 'package:facetune/features/tutorial/domain/usecases/resolve_tutorial_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

const _time = '2026-08-30T00:00:00Z';

Map<String, Object?> sessionRow({
  String manifestStatus = 'accepted',
  String status = 'manifest_ready',
  bool isKit = false,
}) => <String, Object?>{
  'id': 'session-1',
  'user_id': 'user-1',
  'analysis_id': 'analysis-1',
  'source_mode': isKit ? 'my_makeup_kit' : 'standard',
  'recommendation_id': isKit ? null : 'rec-1',
  'kit_recommendation_id': isKit ? 'kit-rec-1' : null,
  'canonical_generated_image_id': isKit ? null : 'preview-1',
  'canonical_kit_generated_image_id': isKit ? 'preview-1' : null,
  'status': status,
  'manifest_status': manifestStatus,
  'manifest_model': 'gemini-3.6-flash',
  'manifest_prompt_version': 'tutorial_manifest_v4_1',
  'manifest_schema_version': 'tutorial_manifest_schema_v1',
  'manifest_created_at': _time,
  'tutorial_resolution': '1K',
  'created_at': _time,
  'updated_at': _time,
  'completed_at': null,
};

List<Object?> manifestRows(List<String> present, {bool backed = false}) {
  const all = <String>[
    'foundation',
    'concealer',
    'contour_bronzer',
    'blush',
    'highlighter',
    'eyebrows',
    'eyeshadow',
    'eyeliner',
    'lips',
  ];
  return <Object?>[
    for (var index = 0; index < all.length; index += 1)
      <String, Object?>{
        'category': all[index],
        'position': index + 1,
        'presence': present.contains(all[index]) ? 'present' : 'absent',
        'visual_confidence': null,
        'product_backed': backed && present.contains(all[index]),
      },
  ];
}

Map<String, Object?> stepRow(
  String category,
  int position, {
  String status = 'pending',
  String? path,
}) => <String, Object?>{
  'id': 'step-$category',
  'tutorial_session_id': 'session-1',
  'category': category,
  'position': position,
  'status': status,
  'guideline_storage_path': path,
  'model_name': path == null ? null : 'gemini-3.1-flash-image',
  'output_resolution': path == null ? null : '1K',
  'prompt_version': path == null ? null : 'guideline_v1',
  'generation_attempt': path == null ? 0 : 1,
  'failure_code': null,
  'created_at': _time,
  'updated_at': _time,
};

class FakeTutorialRemote implements TutorialRemoteDataSource {
  FakeTutorialRemote({
    this.session,
    this.manifestItems = const <Object?>[],
    List<Object?> steps = const <Object?>[],
    this.userId = 'user-1',
    this.isKit = false,
  }) : steps = List<Object?>.from(steps);

  Map<String, Object?>? session;
  List<Object?> manifestItems;
  List<Object?> steps;
  String? userId;
  bool isKit;

  int analyzeCalls = 0;
  int insertCalls = 0;
  final List<Map<String, Object?>> insertedRows = <Map<String, Object?>>[];

  @override
  String? get currentUserId => userId;

  @override
  Future<Object?> analyzeManifest({
    required String previewId,
    required bool isMyMakeupKit,
  }) async {
    analyzeCalls += 1;
    session ??= sessionRow(isKit: isMyMakeupKit);
    if (manifestItems.isEmpty) {
      manifestItems = manifestRows(const <String>[
        'foundation',
        'lips',
      ], backed: isMyMakeupKit);
    }
    return <String, Object?>{'manifest': <String, Object?>{}};
  }

  @override
  Future<Map<String, Object?>?> fetchSession({
    required String previewId,
    required bool isMyMakeupKit,
  }) async => session;

  @override
  Future<Map<String, Object?>?> fetchSessionById(String sessionId) async =>
      session;

  @override
  Future<List<Object?>> fetchManifestItems(String sessionId) async =>
      manifestItems;

  @override
  Future<List<Object?>> fetchSteps(String sessionId) async => steps;

  @override
  Future<void> insertSteps(List<Map<String, Object?>> rows) async {
    insertCalls += 1;
    insertedRows.addAll(rows);
    final existing = steps
        .map((row) => (row! as Map)['category'].toString())
        .toSet();
    for (final row in rows) {
      // Mirrors the database's unique (session, category) constraint: a losing
      // concurrent insert is silently ignored, not an error.
      if (existing.contains(row['category'])) continue;
      steps.add(stepRow(row['category']!.toString(), row['position']! as int));
    }
  }

  @override
  Future<Map<String, Object?>?> fetchPreview({
    required String previewId,
    required bool isMyMakeupKit,
  }) async => <String, Object?>{
    'id': previewId,
    'analysis_id': 'analysis-1',
    if (isMyMakeupKit)
      'kit_recommendation_id': 'kit-rec-1'
    else
      'recommendation_id': 'rec-1',
  };

  @override
  Future<Map<String, Object?>?> fetchRecommendation({
    required String recommendationId,
    required bool isMyMakeupKit,
  }) async => <String, Object?>{
    'id': recommendationId,
    'analysis_id': 'analysis-1',
    'makeup_style': 'soft_glam',
    'model_name': 'gemini-3.6-flash',
    'prompt_version': 'v2',
    'created_at': _time,
    if (isMyMakeupKit)
      'product_snapshot_json': <Object?>[
        <String, Object?>{
          'productId': 'p1',
          'category': 'foundation',
          'colorHex': '#E3C4A8',
          'finish': 'natural',
          'productName': 'My Foundation',
        },
        <String, Object?>{
          'productId': 'p2',
          'category': 'lipstick',
          'colorHex': '#B86F72',
          'finish': 'cream',
          'productName': 'My Lipstick',
        },
      ]
    else
      'recommendation_json': <String, Object?>{
        'blush': <String, Object?>{
          'name': 'Warm Rose',
          'hex': '#B65A68',
          'placement': 'Across the upper cheek.',
          'technique': 'Blend toward the temple.',
          'finish': 'soft satin',
          'intensity': 'medium',
          'reasoning': 'Adds balanced warmth to this look.',
        },
        'overallIntensity': 'medium',
      },
  };

  @override
  Future<Object?> generateStep({
    required String tutorialSessionId,
    required String category,
  }) async => throw StateError('session tests never generate');

  @override
  Future<String> createSignedUrl(String storagePath) async =>
      'https://signed.example/$storagePath';

  @override
  Future<void> deleteSession(String sessionId) async => session = null;
}

({
  SupabaseTutorialSessionRepository sessions,
  SupabaseTutorialManifestRepository manifests,
})
build(FakeTutorialRemote remote) {
  final lookPlans = SupabaseLookPlanRepository(remote);
  return (
    sessions: SupabaseTutorialSessionRepository(remote, lookPlans),
    manifests: SupabaseTutorialManifestRepository(remote, lookPlans),
  );
}

void main() {
  group('session reuse', () {
    test('an existing session is loaded without analyzing', () async {
      final remote = FakeTutorialRemote(
        session: sessionRow(),
        manifestItems: manifestRows(const <String>['foundation', 'lips']),
      );
      final session = await build(remote).sessions.loadForCanonicalPreview(
        const CanonicalPreviewRef.standard('preview-1'),
      );

      expect(session, isNotNull);
      expect(session!.hasReusableManifest, isTrue);
      expect(session.includedCategories, const <TutorialCategory>[
        TutorialCategory.foundation,
        TutorialCategory.lips,
      ]);
      expect(remote.analyzeCalls, 0);
    });

    test('reopening never re-runs the accepted manifest', () async {
      final remote = FakeTutorialRemote(
        session: sessionRow(),
        manifestItems: manifestRows(const <String>['foundation', 'lips']),
      );
      final repositories = build(remote);
      final resolve = ResolveTutorialManifest(
        manifestRepository: repositories.manifests,
        sessionRepository: repositories.sessions,
      );

      for (var reopen = 0; reopen < 5; reopen += 1) {
        await resolve(const CanonicalPreviewRef.standard('preview-1'));
      }

      expect(
        remote.analyzeCalls,
        0,
        reason: 'a rebuild or reopen must never create paid work',
      );
    });

    test('analysis runs exactly once when no session exists', () async {
      final remote = FakeTutorialRemote();
      final repositories = build(remote);
      final resolve = ResolveTutorialManifest(
        manifestRepository: repositories.manifests,
        sessionRepository: repositories.sessions,
      );

      await resolve(const CanonicalPreviewRef.standard('preview-1'));
      await resolve(const CanonicalPreviewRef.standard('preview-1'));

      expect(remote.analyzeCalls, 1);
    });
  });

  group('step materialisation', () {
    test('creates a record only for each included category', () async {
      final remote = FakeTutorialRemote(
        session: sessionRow(),
        manifestItems: manifestRows(const <String>['foundation', 'lips']),
      );
      final repositories = build(remote);
      final session = await repositories.sessions.loadForCanonicalPreview(
        const CanonicalPreviewRef.standard('preview-1'),
      );
      final materialised = await repositories.sessions.ensureSteps(session!);

      expect(
        materialised.orderedSteps.map((step) => step.category).toList(),
        const <TutorialCategory>[
          TutorialCategory.foundation,
          TutorialCategory.lips,
        ],
      );
      expect(
        materialised.orderedSteps.map((step) => step.position).toList(),
        <int>[1, 2],
      );
      expect(remote.insertedRows, hasLength(2));
    });

    test('a second call inserts nothing', () async {
      final remote = FakeTutorialRemote(
        session: sessionRow(),
        manifestItems: manifestRows(const <String>['foundation', 'lips']),
      );
      final repositories = build(remote);
      final session = await repositories.sessions.loadForCanonicalPreview(
        const CanonicalPreviewRef.standard('preview-1'),
      );

      final once = await repositories.sessions.ensureSteps(session!);
      final twice = await repositories.sessions.ensureSteps(once);

      expect(remote.insertCalls, 1, reason: 'the second call had no work');
      expect(twice.steps, hasLength(2));
    });

    test(
      'a concurrent duplicate create converges on one set of rows',
      () async {
        final remote = FakeTutorialRemote(
          session: sessionRow(),
          manifestItems: manifestRows(const <String>['foundation', 'lips']),
        );
        final repositories = build(remote);
        final session = await repositories.sessions.loadForCanonicalPreview(
          const CanonicalPreviewRef.standard('preview-1'),
        );

        final results = await Future.wait(<Future<Object?>>[
          repositories.sessions.ensureSteps(session!),
          repositories.sessions.ensureSteps(session),
        ]);

        expect(results, hasLength(2));
        expect(
          remote.steps,
          hasLength(2),
          reason:
              'the unique constraint decides the winner; both calls succeed',
        );
      },
    );

    test('an already ready step is never recreated', () async {
      final remote = FakeTutorialRemote(
        session: sessionRow(),
        manifestItems: manifestRows(const <String>['foundation', 'lips']),
        steps: <Object?>[
          stepRow(
            'foundation',
            1,
            status: 'ready',
            path: 'user-1/analyses/analysis-1/tutorials/session-1/f_0001.png',
          ),
        ],
      );
      final repositories = build(remote);
      final session = await repositories.sessions.loadForCanonicalPreview(
        const CanonicalPreviewRef.standard('preview-1'),
      );
      final materialised = await repositories.sessions.ensureSteps(session!);

      expect(
        remote.insertedRows.map((row) => row['category']).toList(),
        <String>['lips'],
      );
      expect(
        materialised.stepFor(TutorialCategory.foundation)!.isReady,
        isTrue,
      );
      expect(
        materialised.pendingSteps.map((step) => step.category),
        <TutorialCategory>[TutorialCategory.lips],
      );
    });
  });

  group('My Makeup Kit linkage', () {
    test('steps carry the immutable snapshot items', () async {
      final remote = FakeTutorialRemote(
        session: sessionRow(isKit: true),
        manifestItems: manifestRows(const <String>[
          'foundation',
          'lips',
        ], backed: true),
        isKit: true,
      );
      final repositories = build(remote);
      final session = await repositories.sessions.loadForCanonicalPreview(
        const CanonicalPreviewRef.myMakeupKit('preview-1'),
      );
      final materialised = await repositories.sessions.ensureSteps(session!);

      final lips = materialised.stepFor(TutorialCategory.lips)!;
      expect(lips.productSnapshotItems.single.productName, 'My Lipstick');
      final foundation = materialised.stepFor(TutorialCategory.foundation)!;
      expect(
        foundation.productSnapshotItems.single.productName,
        'My Foundation',
      );
    });

    test('Standard Mode steps carry no product items', () async {
      final remote = FakeTutorialRemote(
        session: sessionRow(),
        manifestItems: manifestRows(const <String>['foundation', 'lips']),
      );
      final repositories = build(remote);
      final session = await repositories.sessions.loadForCanonicalPreview(
        const CanonicalPreviewRef.standard('preview-1'),
      );
      final materialised = await repositories.sessions.ensureSteps(session!);

      for (final step in materialised.steps) {
        expect(step.productSnapshotItems, isEmpty);
      }
    });
  });

  group('Standard recommendation metadata linkage', () {
    test(
      'repository rows carry validated metadata into the look plan',
      () async {
        final remote = FakeTutorialRemote(
          session: sessionRow(),
          manifestItems: manifestRows(const <String>['blush']),
        );

        final session = await build(remote).sessions.loadForCanonicalPreview(
          const CanonicalPreviewRef.standard('preview-1'),
        );
        final entry = session!.lookPlan
            .standardEntriesFor(TutorialCategory.blush)
            .single;

        expect(entry.shadeName, 'Warm Rose');
        expect(entry.colorHex, '#B65A68');
        expect(entry.finish, 'soft satin');
        expect(entry.intensity, 'medium');
        expect(entry.reasoning, 'Adds balanced warmth to this look.');
        expect(entry.planKey, 'blush');
      },
    );

    test('missing optional metadata stays absent rather than invented', () {
      final plan = LookPlanDto.fromRow(<String, Object?>{
        'id': 'rec-1',
        'analysis_id': 'analysis-1',
        'makeup_style': 'natural',
        'model_name': 'model',
        'prompt_version': 'v2',
        'created_at': _time,
        'recommendation_json': <String, Object?>{
          'blush': <String, Object?>{'name': 'Warm Rose', 'hex': '#B65A68'},
          // No name means there is no truthful Standard shade identity, so
          // this item is omitted rather than turned into a generic lip colour.
          'lipstick': <String, Object?>{'hex': '#AA6677'},
        },
      }, sourceMode: RecommendationSourceMode.standard);

      final blush = plan.standardEntriesFor(TutorialCategory.blush).single;
      expect(blush.placement, isEmpty);
      expect(blush.technique, isEmpty);
      expect(blush.finish, isEmpty);
      expect(blush.intensity, isEmpty);
      expect(blush.reasoning, isNull);
      expect(plan.standardEntriesFor(TutorialCategory.lips), isEmpty);
    });
  });

  group('safety', () {
    test('an unauthenticated caller is refused before any query', () async {
      final remote = FakeTutorialRemote(session: sessionRow(), userId: null);

      await expectLater(
        build(remote).sessions.loadForCanonicalPreview(
          const CanonicalPreviewRef.standard('preview-1'),
        ),
        throwsA(
          isA<TutorialFailure>().having(
            (failure) => failure.kind,
            'kind',
            TutorialFailureKind.sessionExpired,
          ),
        ),
      );
    });

    test('source mode cannot change inside an existing session', () async {
      // The stored row says my_makeup_kit while the caller asks for standard.
      final remote = FakeTutorialRemote(
        session: sessionRow(isKit: true),
        manifestItems: manifestRows(const <String>['lips']),
      );

      await expectLater(
        build(remote).sessions.loadForCanonicalPreview(
          const CanonicalPreviewRef.standard('preview-1'),
        ),
        throwsA(
          isA<TutorialFailure>().having(
            (failure) => failure.kind,
            'kind',
            TutorialFailureKind.validation,
          ),
        ),
      );
    });

    test(
      'a mismatched kit manifest is returned without building steps',
      () async {
        final remote = FakeTutorialRemote(
          session: sessionRow(
            isKit: true,
            manifestStatus: 'kit_preview_mismatch',
            status: 'kit_preview_mismatch',
          ),
          manifestItems: manifestRows(const <String>['foundation', 'eyeliner']),
          isKit: true,
        );
        final repositories = build(remote);
        final resolve = ResolveTutorialManifest(
          manifestRepository: repositories.manifests,
          sessionRepository: repositories.sessions,
        );

        final session = await resolve(
          const CanonicalPreviewRef.myMakeupKit('preview-1'),
        );

        expect(session.hasKitPreviewMismatch, isTrue);
        expect(session.hasReusableManifest, isFalse);
        expect(
          remote.insertCalls,
          0,
          reason: 'no steps for an unusable manifest',
        );
      },
    );
  });
}
