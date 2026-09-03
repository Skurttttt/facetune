import 'package:facetune/features/tutorial/domain/catalog/look_plan_convergence.dart';
import 'package:facetune/features/tutorial/domain/entities/canonical_preview_ref.dart';
import 'package:facetune/features/tutorial/domain/entities/recommendation_source_mode.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_manifest.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_session.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_step.dart';
import 'package:facetune/features/tutorial/domain/repositories/tutorial_manifest_repository.dart';
import 'package:facetune/features/tutorial/domain/repositories/tutorial_session_repository.dart';
import 'package:facetune/features/tutorial/domain/repositories/tutorial_step_repository.dart';
import 'package:facetune/features/tutorial/domain/usecases/resolve_tutorial_manifest.dart';
import 'package:facetune/features/tutorial/presentation/controllers/realized_look_controller.dart';
import 'package:facetune/features/tutorial/presentation/controllers/tutorial_controller.dart';
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:flutter_test/flutter_test.dart';

/// V4-QA-6B cost lock: moving manifest analysis earlier must not make it happen
/// twice.
///
/// The Makeup Breakdown now ensures an accepted manifest so it can filter
/// truthfully. The risk that introduces is a second paid analysis when the user
/// then opens the tutorial — the exact failure the phase forbids. These tests
/// drive both consumers through one shared [ResolveTutorialManifest] against a
/// repository that counts analyses, and assert the count never exceeds one.
///
/// The fake persists what it analysed, because that is what the real repository
/// does: the guarantee does not come from the controllers being careful, it
/// comes from resolution being reuse-first over persisted state.

final _now = DateTime.utc(2026, 9, 1);

const _preview = CanonicalPreviewRef.standard('preview-1');

TutorialSession _session() => TutorialSession(
  id: 'session-1',
  userId: 'user-1',
  analysisId: 'analysis-1',
  canonicalPreviewId: 'preview-1',
  lookPlan: LookPlanConvergence.fromStandard(
    MakeupRecommendation(
      id: 'rec-1',
      analysisId: 'analysis-1',
      styleCode: 'natural',
      overallIntensity: 'soft',
      items: <String, MakeupRecommendationItem>{
        'blush': const MakeupRecommendationItem(
          name: 'Warm peach',
          hex: '#E8A08C',
          placement: 'Cheeks.',
          technique: 'Blend outward.',
          finish: 'satin',
          intensity: 'soft',
          reasoning: 'Suits the undertone.',
        ),
      },
      modelId: 'm',
      promptVersion: 'v1',
      createdAt: _now,
    ),
  ),
  status: TutorialSessionStatus.ready,
  manifest: TutorialManifest(
    canonicalPreviewId: 'preview-1',
    sourceMode: RecommendationSourceMode.standard,
    status: TutorialManifestStatus.accepted,
    items: <TutorialManifestItem>[
      for (final category in TutorialCategory.values)
        TutorialManifestItem(
          category: category,
          presence: category == TutorialCategory.blush
              ? TutorialCategoryPresence.present
              : TutorialCategoryPresence.absent,
        ),
    ],
    modelId: 'm',
    promptVersion: 'tutorial_manifest_v4_1',
    schemaVersion: 'manifest_schema_v1',
    createdAt: _now,
  ),
  steps: const <TutorialStep>[],
  createdAt: _now,
  updatedAt: _now,
);

/// Counts analyses and, like the real repository, persists what it produced.
class _CountingManifests implements TutorialManifestRepository {
  int analyzeCalls = 0;
  int loadAcceptedCalls = 0;
  TutorialSession? _persisted;

  @override
  Future<TutorialSession?> loadAccepted(CanonicalPreviewRef preview) async {
    loadAcceptedCalls += 1;
    return _persisted;
  }

  @override
  Future<TutorialSession> analyze(CanonicalPreviewRef preview) async {
    analyzeCalls += 1;
    return _persisted = _session();
  }
}

class _Sessions implements TutorialSessionRepository {
  _Sessions(this._manifests);

  final _CountingManifests _manifests;
  int ensureStepsCalls = 0;

  /// Mirrors the real repository: a session exists only once a manifest has
  /// been analysed and persisted for the preview.
  @override
  Future<TutorialSession?> loadForCanonicalPreview(
    CanonicalPreviewRef preview,
  ) async => _manifests._persisted;

  @override
  Future<TutorialSession> loadById(String sessionId) async => _session();

  @override
  Future<TutorialSession> ensureSteps(TutorialSession value) async {
    ensureStepsCalls += 1;
    return value;
  }

  @override
  Future<void> delete(String sessionId) async {}
}

class _Steps implements TutorialStepRepository {
  int generateCalls = 0;

  @override
  Future<List<TutorialStep>> loadForSession(String sessionId) async =>
      const <TutorialStep>[];

  @override
  Future<TutorialStep> generate({
    required String sessionId,
    required TutorialCategory category,
  }) async {
    generateCalls += 1;
    return TutorialStep(
      id: 'step-${category.code}',
      sessionId: sessionId,
      category: category,
      position: 1,
      status: TutorialStepStatus.ready,
      guidelineStoragePath:
          'user-1/analyses/a/tutorials/s/${category.code}.png',
      productSnapshotItems: const [],
      createdAt: _now,
      updatedAt: _now,
    );
  }

  @override
  Future<String> resolveGuidelineUrl(TutorialStep step) async =>
      'https://example.invalid/${step.id}.png';
}

({
  _CountingManifests manifests,
  _Sessions sessions,
  ResolveTutorialManifest resolve,
})
_harness() {
  final manifests = _CountingManifests();
  final sessions = _Sessions(manifests);
  return (
    manifests: manifests,
    sessions: sessions,
    resolve: ResolveTutorialManifest(
      manifestRepository: manifests,
      sessionRepository: sessions,
    ),
  );
}

void main() {
  group('one accepted manifest per canonical preview', () {
    test(
      'the breakdown analyses once; the tutorial then analyses none',
      () async {
        // The whole point of the phase: the cost does not double when the
        // manifest moves earlier.
        final harness = _harness();
        final realized = RealizedLookController(
          resolveManifest: harness.resolve,
        );
        addTearDown(realized.dispose);

        await realized.ensure(_preview);
        expect(harness.manifests.analyzeCalls, 1);
        expect(realized.state.isReady, isTrue);

        final tutorial = TutorialController(
          resolveManifest: harness.resolve,
          steps: _Steps(),
        );
        addTearDown(tutorial.dispose);
        await tutorial.open(_preview);

        expect(
          harness.manifests.analyzeCalls,
          1,
          reason: 'opening the tutorial must reuse, never re-analyse',
        );
      },
    );

    test('the tutorial first, then the breakdown, is also one', () async {
      final harness = _harness();
      final tutorial = TutorialController(
        resolveManifest: harness.resolve,
        steps: _Steps(),
      );
      addTearDown(tutorial.dispose);
      await tutorial.open(_preview);
      expect(harness.manifests.analyzeCalls, 1);

      final realized = RealizedLookController(resolveManifest: harness.resolve);
      addTearDown(realized.dispose);
      await realized.ensure(_preview);

      expect(harness.manifests.analyzeCalls, 1);
      expect(realized.state.isReady, isTrue);
    });

    test('reopening from History analyses nothing', () async {
      final harness = _harness();
      final first = RealizedLookController(resolveManifest: harness.resolve);
      await first.ensure(_preview);
      first.dispose();
      expect(harness.manifests.analyzeCalls, 1);

      // A fresh controller is what a reopened page gets.
      final reopened = RealizedLookController(resolveManifest: harness.resolve);
      addTearDown(reopened.dispose);
      await reopened.ensure(_preview);

      expect(harness.manifests.analyzeCalls, 1);
      expect(reopened.state.includedCategories, <TutorialCategory>[
        TutorialCategory.blush,
      ]);
    });

    test('repeated ensures from rebuilds cost nothing', () async {
      final harness = _harness();
      final realized = RealizedLookController(resolveManifest: harness.resolve);
      addTearDown(realized.dispose);

      for (var i = 0; i < 5; i += 1) {
        await realized.ensure(_preview);
      }
      expect(harness.manifests.analyzeCalls, 1);
    });

    test('concurrent ensures share one analysis', () async {
      final harness = _harness();
      final realized = RealizedLookController(resolveManifest: harness.resolve);
      addTearDown(realized.dispose);

      await Future.wait<void>(<Future<void>>[
        realized.ensure(_preview),
        realized.ensure(_preview),
        realized.ensure(_preview),
      ]);
      expect(harness.manifests.analyzeCalls, 1);
    });
  });

  group('a different preview is a different manifest', () {
    test(
      'a regenerated preview does not inherit the previous manifest',
      () async {
        final harness = _harness();
        final realized = RealizedLookController(
          resolveManifest: harness.resolve,
        );
        addTearDown(realized.dispose);

        await realized.ensure(_preview);
        expect(realized.state.preview, _preview);

        // The fake persists under one key, so the second preview resolves to a
        // session whose canonicalPreviewId does not match — which is exactly what
        // must not be presented as authoritative for it.
        const other = CanonicalPreviewRef.standard('preview-2');
        await realized.ensure(other);

        expect(realized.state.preview, other);
        expect(
          realized.state.isReady,
          isFalse,
          reason:
              'a manifest for another preview is not evidence about this one, '
              'so it must not be treated as ready',
        );
        expect(realized.state.includedCategories, isEmpty);
      },
    );

    test('a kit preview and a standard preview are distinct references', () {
      expect(
        const CanonicalPreviewRef.standard('p'),
        isNot(const CanonicalPreviewRef.myMakeupKit('p')),
      );
    });
  });

  group('the included set is only exposed once ready', () {
    test('an idle controller reports no categories, not an empty look', () {
      final harness = _harness();
      final realized = RealizedLookController(resolveManifest: harness.resolve);
      addTearDown(realized.dispose);
      expect(realized.state.status, RealizedLookStatus.idle);
      expect(realized.state.isReady, isFalse);
      expect(realized.state.includedCategories, isEmpty);
      expect(harness.manifests.analyzeCalls, 0);
      expect(
        harness.manifests.loadAcceptedCalls,
        0,
        reason: 'constructing the controller must touch nothing',
      );
    });
  });
}
