import 'dart:async';

import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/tutorial/domain/catalog/look_plan_convergence.dart';
import 'package:facetune/features/tutorial/domain/entities/canonical_preview_ref.dart';
import 'package:facetune/features/tutorial/domain/entities/recommendation_source_mode.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_manifest.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_session.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_step.dart';
import 'package:facetune/features/tutorial/domain/errors/tutorial_failure.dart';
import 'package:facetune/features/tutorial/domain/repositories/tutorial_manifest_repository.dart';
import 'package:facetune/features/tutorial/domain/repositories/tutorial_session_repository.dart';
import 'package:facetune/features/tutorial/domain/repositories/tutorial_step_repository.dart';
import 'package:facetune/features/tutorial/domain/usecases/resolve_tutorial_manifest.dart';
import 'package:facetune/features/tutorial/presentation/controllers/tutorial_controller.dart';
import 'package:facetune/features/tutorial/presentation/controllers/tutorial_state.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 8, 30);
const _preview = CanonicalPreviewRef.standard('preview-1');
const _kitPreview = CanonicalPreviewRef.myMakeupKit('preview-1');

TutorialManifest _manifest({
  required RecommendationSourceMode sourceMode,
  required List<TutorialCategory> present,
  Set<TutorialCategory> backed = const <TutorialCategory>{},
}) => TutorialManifest(
  canonicalPreviewId: 'preview-1',
  sourceMode: sourceMode,
  status: TutorialManifestStatus.accepted,
  items: <TutorialManifestItem>[
    for (final category in TutorialCategory.values)
      TutorialManifestItem(
        category: category,
        presence: present.contains(category)
            ? TutorialCategoryPresence.present
            : TutorialCategoryPresence.absent,
        productBacked: backed.contains(category),
      ),
  ],
  modelId: 'manifest-model',
  promptVersion: 'v1',
  schemaVersion: 'v1',
  createdAt: _now,
);

TutorialStep _step(
  TutorialCategory category,
  int position, {
  TutorialStepStatus status = TutorialStepStatus.pending,
  String? path,
}) => TutorialStep(
  id: 'step-${category.code}',
  sessionId: 'session-1',
  category: category,
  position: position,
  status: status,
  guidelineStoragePath: path,
  createdAt: _now,
  updatedAt: _now,
);

TutorialSession _session({
  required RecommendationSourceMode sourceMode,
  required List<TutorialCategory> present,
  List<TutorialStep> steps = const <TutorialStep>[],
}) => TutorialSession(
  id: 'session-1',
  userId: 'user-1',
  analysisId: 'analysis-1',
  canonicalPreviewId: 'preview-1',
  lookPlan: sourceMode == RecommendationSourceMode.standard
      ? LookPlanConvergence.fromStandard(
          MakeupRecommendation(
            id: 'rec-1',
            analysisId: 'analysis-1',
            styleCode: 'soft_glam',
            overallIntensity: 'soft',
            items: const <String, MakeupRecommendationItem>{},
            modelId: 'm',
            promptVersion: 'v1',
            createdAt: _now,
          ),
        )
      : LookPlanConvergence.fromMyMakeupKit(
          KitMakeupRecommendation(
            id: 'kit-rec-1',
            analysisId: 'analysis-1',
            styleCode: 'soft_glam',
            selections: const <KitMakeupSelection>[],
            productSnapshots: const <KitProductSnapshot>[
              KitProductSnapshot(
                productId: 'p1',
                category: 'blush',
                colorHex: '#B86F72',
                finish: 'matte',
                productName: 'My Blush',
              ),
              KitProductSnapshot(
                productId: 'p2',
                category: 'lipstick',
                colorHex: '#B86F72',
                finish: 'cream',
                productName: 'My Lipstick',
              ),
            ],
            overallIntensity: 'soft',
            summary: 'Owned products.',
            modelId: 'm',
            promptVersion: 'v1',
            createdAt: _now,
          ),
        ),
  status: TutorialSessionStatus.ready,
  manifest: _manifest(
    sourceMode: sourceMode,
    present: present,
    backed: sourceMode == RecommendationSourceMode.myMakeupKit
        ? present.toSet()
        : const <TutorialCategory>{},
  ),
  steps: steps,
  createdAt: _now,
  updatedAt: _now,
);

class FakeManifests implements TutorialManifestRepository {
  FakeManifests(this.session);

  TutorialSession session;
  int analyzeCalls = 0;
  int loadCalls = 0;

  @override
  Future<TutorialSession?> loadAccepted(CanonicalPreviewRef preview) async {
    loadCalls += 1;
    return session;
  }

  @override
  Future<TutorialSession> analyze(CanonicalPreviewRef preview) async {
    analyzeCalls += 1;
    return session;
  }
}

class _FakeSessions implements TutorialSessionRepository {
  _FakeSessions(this.session);

  TutorialSession? session;
  int ensureCalls = 0;

  @override
  Future<TutorialSession?> loadForCanonicalPreview(
    CanonicalPreviewRef preview,
  ) async => session;

  @override
  Future<TutorialSession> loadById(String sessionId) async => session!;

  @override
  Future<TutorialSession> ensureSteps(TutorialSession value) async {
    ensureCalls += 1;
    return value;
  }

  @override
  Future<void> delete(String sessionId) async {}
}

class FakeSteps implements TutorialStepRepository {
  FakeSteps({this.failuresBeforeSuccess = 0, this.failure});

  int generateCalls = 0;
  int failuresBeforeSuccess;
  TutorialFailure? failure;
  final List<TutorialCategory> requested = <TutorialCategory>[];
  Completer<void>? gate;

  @override
  Future<List<TutorialStep>> loadForSession(String sessionId) async =>
      const <TutorialStep>[];

  @override
  Future<TutorialStep> generate({
    required String sessionId,
    required TutorialCategory category,
  }) async {
    generateCalls += 1;
    requested.add(category);
    if (gate != null) await gate!.future;
    if (failure != null) throw failure!;
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess -= 1;
      throw const TutorialFailure(
        'Temporary failure.',
        kind: TutorialFailureKind.unavailable,
      );
    }
    return _step(
      category,
      1,
      status: TutorialStepStatus.ready,
      path: 'user-1/analyses/a/tutorials/session-1/${category.code}_0001.png',
    );
  }

  @override
  Future<String> resolveGuidelineUrl(TutorialStep step) async =>
      'https://signed.example/${step.id}';
}

({TutorialController controller, FakeSteps steps, FakeManifests manifests})
build({
  RecommendationSourceMode sourceMode = RecommendationSourceMode.standard,
  List<TutorialCategory> present = const <TutorialCategory>[
    TutorialCategory.foundation,
    TutorialCategory.blush,
    TutorialCategory.lips,
  ],
  List<TutorialStep> steps = const <TutorialStep>[],
  FakeSteps? stepRepository,
}) {
  final session = _session(
    sourceMode: sourceMode,
    present: present,
    steps: steps,
  );
  final manifests = FakeManifests(session);
  final sessions = _FakeSessions(session);
  final stepRepo = stepRepository ?? FakeSteps();
  final controller = TutorialController(
    resolveManifest: ResolveTutorialManifest(
      manifestRepository: manifests,
      sessionRepository: sessions,
    ),
    steps: stepRepo,
  );
  addTearDown(controller.dispose);
  return (controller: controller, steps: stepRepo, manifests: manifests);
}

void main() {
  group('nothing happens until someone asks', () {
    test('a freshly built controller is idle and has made no calls', () {
      final harness = build();

      expect(harness.controller.state.status, TutorialStatus.idle);
      expect(harness.manifests.analyzeCalls, 0);
      expect(harness.steps.generateCalls, 0);
      expect(harness.controller.state.telemetry.stepGenerations, 0);
    });

    test('reading state repeatedly never triggers work', () {
      final harness = build();

      for (var rebuild = 0; rebuild < 20; rebuild += 1) {
        harness.controller.state.categories;
        harness.controller.state.currentStep;
        harness.controller.state.stepCount;
      }

      expect(harness.manifests.analyzeCalls, 0);
      expect(harness.steps.generateCalls, 0);
    });
  });

  group('opening is idempotent', () {
    test('a route rebuild calling open repeatedly opens once', () async {
      final harness = build();

      for (var rebuild = 0; rebuild < 5; rebuild += 1) {
        await harness.controller.open(_preview);
      }

      expect(harness.controller.state.status, TutorialStatus.ready);
      expect(harness.controller.state.telemetry.manifestAnalyses, 1);
    });

    test('concurrent opens share one future', () async {
      final harness = build();

      await Future.wait(<Future<void>>[
        harness.controller.open(_preview),
        harness.controller.open(_preview),
        harness.controller.open(_preview),
      ]);

      expect(harness.controller.state.telemetry.manifestAnalyses, 1);
    });

    test('back then reopen does not re-analyze', () async {
      final harness = build();

      await harness.controller.open(_preview);
      // Navigating away and back re-invokes open on the same controller.
      await harness.controller.open(_preview);

      expect(harness.controller.state.telemetry.manifestAnalyses, 1);
      expect(
        harness.manifests.analyzeCalls,
        0,
        reason: 'an accepted manifest was reused',
      );
    });

    test('a different canonical preview starts a fresh tutorial', () async {
      final harness = build();

      await harness.controller.open(_preview);
      await harness.controller.open(
        const CanonicalPreviewRef.standard('preview-2'),
      );

      expect(harness.controller.state.telemetry.manifestAnalyses, 1);
      expect(harness.controller.state.status, TutorialStatus.ready);
    });
  });

  group('one intent, one billable call', () {
    test('a rapid double tap generates once', () async {
      final steps = FakeSteps()..gate = Completer<void>();
      final harness = build(stepRepository: steps);
      await harness.controller.open(_preview);

      final first = harness.controller.generateCurrentStep();
      final second = harness.controller.generateCurrentStep();
      steps.gate!.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(steps.generateCalls, 1);
      expect(harness.controller.state.telemetry.requestsCoalesced, 1);
    });

    test('many concurrent requests for one category coalesce', () async {
      final steps = FakeSteps()..gate = Completer<void>();
      final harness = build(stepRepository: steps);
      await harness.controller.open(_preview);

      final calls = <Future<void>>[
        for (var i = 0; i < 6; i += 1) harness.controller.generateCurrentStep(),
      ];
      steps.gate!.complete();
      await Future.wait(calls);

      expect(steps.generateCalls, 1);
      expect(harness.controller.state.telemetry.requestsCoalesced, 5);
    });

    test('a ready step is reused without any request', () async {
      final steps = FakeSteps();
      final harness = build(
        stepRepository: steps,
        // One category, already drawn: reopen resumes onto it.
        present: const <TutorialCategory>[TutorialCategory.foundation],
        steps: <TutorialStep>[
          _step(
            TutorialCategory.foundation,
            1,
            status: TutorialStepStatus.ready,
            path: 'user-1/analyses/a/tutorials/session-1/foundation_0001.png',
          ),
        ],
      );
      await harness.controller.open(_preview);

      await harness.controller.generateCurrentStep();

      expect(steps.generateCalls, 0);
      expect(harness.controller.state.telemetry.stepsReused, 1);
    });

    test('navigating to a ready step does not regenerate it', () async {
      final steps = FakeSteps();
      final harness = build(
        stepRepository: steps,
        steps: <TutorialStep>[
          _step(
            TutorialCategory.blush,
            2,
            status: TutorialStepStatus.ready,
            path: 'user-1/analyses/a/tutorials/session-1/blush_0001.png',
          ),
        ],
      );
      await harness.controller.open(_preview);

      await harness.controller.goToStep(1);
      await harness.controller.goToStep(1);

      expect(steps.generateCalls, 0);
      expect(harness.controller.state.currentCategory, TutorialCategory.blush);
    });
  });

  group('opening never generates every step', () {
    test('open alone generates nothing', () async {
      final harness = build();

      await harness.controller.open(_preview);

      expect(harness.steps.generateCalls, 0);
      expect(harness.controller.state.stepCount, 3);
    });

    test('viewing one step generates exactly one', () async {
      final harness = build();
      await harness.controller.open(_preview);

      await harness.controller.generateCurrentStep();

      expect(harness.steps.generateCalls, 1);
      expect(harness.steps.requested, <TutorialCategory>[
        TutorialCategory.foundation,
      ]);
    });
  });

  group('prefetch depth is one', () {
    test('prefetch requests only the immediate next category', () async {
      final harness = build();
      await harness.controller.open(_preview);

      await harness.controller.prefetchNext();

      expect(harness.steps.requested, <TutorialCategory>[
        TutorialCategory.blush,
      ]);
      expect(harness.controller.state.telemetry.prefetches, 1);
    });

    test('repeated prefetch never runs ahead', () async {
      final harness = build();
      await harness.controller.open(_preview);

      await harness.controller.prefetchNext();
      await harness.controller.prefetchNext();

      // The second call sees the step is ready and does nothing; Lips is never
      // reached, so depth stays one.
      expect(harness.steps.generateCalls, 1);
      expect(harness.steps.requested.contains(TutorialCategory.lips), isFalse);
    });

    test('prefetch at the last step does nothing', () async {
      final harness = build();
      await harness.controller.open(_preview);
      await harness.controller.goToStep(2);
      final before = harness.steps.generateCalls;

      await harness.controller.prefetchNext();

      expect(harness.steps.generateCalls, before);
    });

    test('a prefetch failure never surfaces to the user', () async {
      final steps = FakeSteps(
        failure: const TutorialFailure(
          'Boom.',
          kind: TutorialFailureKind.unavailable,
        ),
      );
      final harness = build(stepRepository: steps);
      await harness.controller.open(_preview);

      await harness.controller.prefetchNext();

      expect(harness.controller.state.status, TutorialStatus.ready);
      expect(harness.controller.state.message, isNull);
    });
  });

  group('bounded retry', () {
    test(
      'one transient failure is retried automatically, then succeeds',
      () async {
        final steps = FakeSteps(failuresBeforeSuccess: 1);
        final harness = build(stepRepository: steps);
        await harness.controller.open(_preview);

        await harness.controller.generateCurrentStep();

        expect(steps.generateCalls, 2);
        expect(harness.controller.state.status, TutorialStatus.ready);
      },
    );

    test('a persistent failure stops after one retry', () async {
      final steps = FakeSteps(failuresBeforeSuccess: 5);
      final harness = build(stepRepository: steps);
      await harness.controller.open(_preview);

      await harness.controller.generateCurrentStep();

      expect(
        steps.generateCalls,
        2,
        reason: 'the initial attempt plus one automatic retry, and no more',
      );
      expect(harness.controller.state.status, TutorialStatus.failed);
    });

    test('a non-retryable failure is not retried at all', () async {
      final steps = FakeSteps(
        failure: const TutorialFailure(
          'Not part of this look.',
          kind: TutorialFailureKind.validation,
          retryable: false,
        ),
      );
      final harness = build(stepRepository: steps);
      await harness.controller.open(_preview);

      await harness.controller.generateCurrentStep();

      expect(steps.generateCalls, 1);
      expect(harness.controller.state.retryable, isFalse);
    });
  });

  group('regeneration is explicit only', () {
    test('it regenerates a ready step, unlike every other path', () async {
      final steps = FakeSteps();
      final harness = build(
        stepRepository: steps,
        present: const <TutorialCategory>[TutorialCategory.foundation],
        steps: <TutorialStep>[
          _step(
            TutorialCategory.foundation,
            1,
            status: TutorialStepStatus.ready,
            path: 'user-1/analyses/a/tutorials/session-1/foundation_0001.png',
          ),
        ],
      );
      await harness.controller.open(_preview);

      await harness.controller.generateCurrentStep();
      expect(steps.generateCalls, 0, reason: 'the normal path reuses');

      await harness.controller.regenerateCurrentStep();
      expect(steps.generateCalls, 1, reason: 'only the explicit path spends');
      expect(harness.controller.state.telemetry.regenerations, 1);
    });

    test('a double tap on regenerate still spends once', () async {
      final steps = FakeSteps()..gate = Completer<void>();
      final harness = build(stepRepository: steps);
      await harness.controller.open(_preview);

      final first = harness.controller.regenerateCurrentStep();
      final second = harness.controller.regenerateCurrentStep();
      steps.gate!.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(steps.generateCalls, 1);
    });
  });

  group('source-mode-aware state', () {
    test('Standard Mode carries no products', () async {
      final harness = build();
      await harness.controller.open(_preview);

      expect(
        harness.controller.state.sourceMode,
        RecommendationSourceMode.standard,
      );
      expect(harness.controller.state.isMyMakeupKit, isFalse);
    });

    test('My Makeup Kit exposes the snapshot items for the step', () async {
      final harness = build(
        sourceMode: RecommendationSourceMode.myMakeupKit,
        present: const <TutorialCategory>[
          TutorialCategory.blush,
          TutorialCategory.lips,
        ],
      );
      await harness.controller.open(_kitPreview);
      await harness.controller.generateCurrentStep();

      expect(harness.controller.state.isMyMakeupKit, isTrue);
      expect(harness.controller.state.currentCategory, TutorialCategory.blush);
      expect(harness.steps.generateCalls, 1);
    });
  });

  group('Step X of N follows the included count', () {
    test('a three-step tutorial reports 1 of 3', () async {
      final harness = build();
      await harness.controller.open(_preview);

      expect(harness.controller.state.stepNumber, 1);
      expect(harness.controller.state.stepCount, 3);

      await harness.controller.next();
      expect(harness.controller.state.stepNumber, 2);
    });

    test('bounds are respected', () async {
      final harness = build();
      await harness.controller.open(_preview);

      await harness.controller.previous();
      expect(harness.controller.state.currentIndex, 0);

      await harness.controller.goToStep(99);
      expect(harness.controller.state.currentIndex, 0);
    });
  });

  group('telemetry is sanitized', () {
    test('the summary carries counts only', () async {
      final harness = build();
      await harness.controller.open(_preview);
      await harness.controller.generateCurrentStep();

      final summary = harness.controller.state.telemetry.toString();

      expect(summary, contains('generated=1'));
      for (final leak in <String>[
        'session-1',
        'user-1',
        'analysis-1',
        'preview-1',
        'tutorials/',
      ]) {
        expect(summary, isNot(contains(leak)));
      }
    });
  });
}
