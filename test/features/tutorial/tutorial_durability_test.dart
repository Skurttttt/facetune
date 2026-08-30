import 'dart:io';

import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/tutorial/domain/catalog/look_plan_convergence.dart';
import 'package:facetune/features/tutorial/domain/entities/canonical_preview_ref.dart';
import 'package:facetune/features/tutorial/domain/entities/recommendation_source_mode.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_manifest.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_session.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_step.dart';
import 'package:facetune/features/tutorial/domain/entities/validated_look_plan.dart';
import 'package:facetune/features/tutorial/domain/errors/tutorial_failure.dart';
import 'package:facetune/features/tutorial/domain/repositories/tutorial_manifest_repository.dart';
import 'package:facetune/features/tutorial/domain/repositories/tutorial_session_repository.dart';
import 'package:facetune/features/tutorial/domain/repositories/tutorial_step_repository.dart';
import 'package:facetune/features/tutorial/domain/usecases/resolve_tutorial_manifest.dart';
import 'package:facetune/features/tutorial/presentation/controllers/tutorial_controller.dart';
import 'package:facetune/features/tutorial/presentation/controllers/tutorial_state.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 8, 30);
const _preview = CanonicalPreviewRef.myMakeupKit('preview-1');

/// The snapshot captured when the look was created. Everything historical is
/// read from this, never from live inventory.
const _originalSnapshots = <KitProductSnapshot>[
  KitProductSnapshot(
    productId: 'p1',
    category: 'blush',
    colorHex: '#B86F72',
    finish: 'matte',
    productName: 'Rose Glow',
    colorLabel: 'Dusty Rose',
  ),
  KitProductSnapshot(
    productId: 'p2',
    category: 'lipstick',
    colorHex: '#C04A5E',
    finish: 'cream',
    productName: 'Everyday Nude',
  ),
];

ValidatedLookPlan _kitPlan([
  List<KitProductSnapshot> snapshots = _originalSnapshots,
]) => LookPlanConvergence.fromMyMakeupKit(
  KitMakeupRecommendation(
    id: 'kit-rec-1',
    analysisId: 'analysis-1',
    styleCode: 'soft_glam',
    selections: const <KitMakeupSelection>[],
    productSnapshots: snapshots,
    overallIntensity: 'soft',
    summary: 'Owned products.',
    modelId: 'm',
    promptVersion: 'v1',
    createdAt: _now,
  ),
);

TutorialStep _step(
  TutorialCategory category,
  int position, {
  bool ready = true,
}) => TutorialStep(
  id: 'step-${category.code}',
  sessionId: 'session-1',
  category: category,
  position: position,
  status: ready ? TutorialStepStatus.ready : TutorialStepStatus.pending,
  guidelineStoragePath: ready
      ? 'user-1/analyses/analysis-1/tutorials/session-1/${category.code}_0001.png'
      : null,
  createdAt: _now,
  updatedAt: _now,
);

TutorialSession _session({
  required ValidatedLookPlan plan,
  List<TutorialStep> steps = const <TutorialStep>[],
  List<TutorialCategory> present = const <TutorialCategory>[
    TutorialCategory.blush,
    TutorialCategory.lips,
  ],
}) => TutorialSession(
  id: 'session-1',
  userId: 'user-1',
  analysisId: 'analysis-1',
  canonicalPreviewId: 'preview-1',
  lookPlan: plan,
  status: TutorialSessionStatus.ready,
  manifest: TutorialManifest(
    canonicalPreviewId: 'preview-1',
    sourceMode: RecommendationSourceMode.myMakeupKit,
    status: TutorialManifestStatus.accepted,
    items: <TutorialManifestItem>[
      for (final category in TutorialCategory.values)
        TutorialManifestItem(
          category: category,
          presence: present.contains(category)
              ? TutorialCategoryPresence.present
              : TutorialCategoryPresence.absent,
          productBacked: present.contains(category),
        ),
    ],
    modelId: 'm',
    promptVersion: 'v1',
    schemaVersion: 'v1',
    createdAt: _now,
  ),
  steps: steps,
  createdAt: _now,
  updatedAt: _now,
);

class Manifests implements TutorialManifestRepository {
  Manifests(this.session);
  TutorialSession? session;
  int analyzeCalls = 0;

  @override
  Future<TutorialSession?> loadAccepted(CanonicalPreviewRef preview) async =>
      session;

  @override
  Future<TutorialSession> analyze(CanonicalPreviewRef preview) async {
    analyzeCalls += 1;
    return session!;
  }
}

class _Sessions implements TutorialSessionRepository {
  _Sessions(this.session, {this.failure});
  TutorialSession? session;
  TutorialFailure? failure;

  @override
  Future<TutorialSession?> loadForCanonicalPreview(
    CanonicalPreviewRef preview,
  ) async {
    if (failure != null) throw failure!;
    return session;
  }

  @override
  Future<TutorialSession> loadById(String sessionId) async => session!;

  @override
  Future<TutorialSession> ensureSteps(TutorialSession value) async => value;

  @override
  Future<void> delete(String sessionId) async => session = null;
}

class Steps implements TutorialStepRepository {
  Steps({this.signFails = false});

  bool signFails;
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
    return _step(category, 1);
  }

  @override
  Future<String> resolveGuidelineUrl(TutorialStep step) async {
    if (signFails) {
      throw const TutorialFailure(
        'Missing asset.',
        kind: TutorialFailureKind.notFound,
        retryable: false,
      );
    }
    return 'https://example.invalid/${step.id}.png';
  }
}

({TutorialController controller, Steps steps, Manifests manifests}) build({
  required TutorialSession? session,
  Steps? stepRepository,
  TutorialFailure? sessionFailure,
}) {
  final manifests = Manifests(session);
  final sessions = _Sessions(session, failure: sessionFailure);
  final steps = stepRepository ?? Steps();
  final controller = TutorialController(
    resolveManifest: ResolveTutorialManifest(
      manifestRepository: manifests,
      sessionRepository: sessions,
    ),
    steps: steps,
  );
  addTearDown(controller.dispose);
  return (controller: controller, steps: steps, manifests: manifests);
}

void main() {
  group('reopen is free', () {
    test('a fully drawn tutorial reopens with no calls at all', () async {
      final harness = build(
        session: _session(
          plan: _kitPlan(),
          steps: <TutorialStep>[
            _step(TutorialCategory.blush, 1),
            _step(TutorialCategory.lips, 2),
          ],
        ),
      );

      await harness.controller.open(_preview);
      await harness.controller.generateCurrentStep();

      expect(harness.manifests.analyzeCalls, 0, reason: 'manifest reused');
      expect(harness.steps.generateCalls, 0, reason: 'ready steps reused');
    });

    test('reopening after navigating away still costs nothing', () async {
      final harness = build(
        session: _session(
          plan: _kitPlan(),
          steps: <TutorialStep>[
            _step(TutorialCategory.blush, 1),
            _step(TutorialCategory.lips, 2),
          ],
        ),
      );

      await harness.controller.open(_preview);
      await harness.controller.next();
      await harness.controller.previous();
      await harness.controller.open(_preview);

      expect(harness.manifests.analyzeCalls, 0);
      expect(harness.steps.generateCalls, 0);
    });

    test(
      'a fresh controller reopening the same tutorial costs nothing',
      () async {
        // Stands in for an app relaunch: a brand-new controller reading the same
        // persisted session must not redo any paid work.
        final session = _session(
          plan: _kitPlan(),
          steps: <TutorialStep>[
            _step(TutorialCategory.blush, 1),
            _step(TutorialCategory.lips, 2),
          ],
        );

        final first = build(session: session);
        await first.controller.open(_preview);

        final relaunched = build(session: session);
        await relaunched.controller.open(_preview);
        await relaunched.controller.generateCurrentStep();

        expect(relaunched.manifests.analyzeCalls, 0);
        expect(relaunched.steps.generateCalls, 0);
      },
    );
  });

  group('resume and completion', () {
    test('resumes on the first step that is not yet drawn', () async {
      final harness = build(
        session: _session(
          plan: _kitPlan(),
          steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
        ),
      );

      await harness.controller.open(_preview);

      expect(harness.controller.state.currentIndex, 1);
      expect(harness.controller.state.currentCategory, TutorialCategory.lips);
      expect(harness.controller.state.isComplete, isFalse);
    });

    test('a completed tutorial reopens on its last step', () async {
      final harness = build(
        session: _session(
          plan: _kitPlan(),
          steps: <TutorialStep>[
            _step(TutorialCategory.blush, 1),
            _step(TutorialCategory.lips, 2),
          ],
        ),
      );

      await harness.controller.open(_preview);

      expect(harness.controller.state.isComplete, isTrue);
      expect(harness.controller.state.isLastStep, isTrue);
    });

    test('an untouched tutorial starts at the beginning', () async {
      final harness = build(session: _session(plan: _kitPlan()));

      await harness.controller.open(_preview);

      expect(harness.controller.state.currentIndex, 0);
      expect(harness.controller.state.isComplete, isFalse);
    });
  });

  group('historical product details are immutable', () {
    test('renaming a product does not change an existing tutorial', () async {
      final harness = build(
        session: _session(
          plan: _kitPlan(),
          steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
        ),
      );
      await harness.controller.open(_preview);

      // The user renames and re-shades the product afterwards. The look plan is
      // built from the persisted snapshot, so the tutorial is unaffected.
      final liveInventoryNow = _kitPlan(const <KitProductSnapshot>[
        KitProductSnapshot(
          productId: 'p1',
          category: 'blush',
          colorHex: '#FFFFFF',
          finish: 'shimmer',
          productName: 'Renamed Later',
          colorLabel: 'Something Else',
        ),
      ]);

      final historical = harness
          .controller
          .state
          .session!
          .lookPlan
          .productSnapshot
          .itemsFor(TutorialCategory.blush)
          .single;

      expect(historical.productName, 'Rose Glow');
      expect(historical.colorLabel, 'Dusty Rose');
      expect(historical.color.value, '#B86F72');
      expect(
        liveInventoryNow.productSnapshot
            .itemsFor(TutorialCategory.blush)
            .single
            .productName,
        'Renamed Later',
        reason: 'the newer plan is a different object entirely',
      );
    });

    test('deleting a product leaves the tutorial intact', () async {
      final harness = build(
        session: _session(
          plan: _kitPlan(),
          steps: <TutorialStep>[
            _step(TutorialCategory.blush, 1),
            _step(TutorialCategory.lips, 2),
          ],
        ),
      );
      await harness.controller.open(_preview);

      // Nothing about the session consults live inventory, so a deletion
      // elsewhere cannot reach it.
      final snapshot =
          harness.controller.state.session!.lookPlan.productSnapshot;

      expect(snapshot.items, hasLength(2));
      expect(snapshot.covers(TutorialCategory.blush), isTrue);
      expect(snapshot.covers(TutorialCategory.lips), isTrue);
      expect(
        snapshot.itemsFor(TutorialCategory.lips).single.kitCategory,
        MakeupKitCategory.lipstick,
      );
    });

    test('the tutorial still shows every stored field', () async {
      final harness = build(
        session: _session(
          plan: _kitPlan(),
          steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
        ),
      );
      await harness.controller.open(_preview);

      final item = harness.controller.state.session!.lookPlan.productSnapshot
          .itemsFor(TutorialCategory.blush)
          .single;

      expect(item.productId, 'p1');
      expect(item.productName, 'Rose Glow');
      expect(item.colorLabel, 'Dusty Rose');
      expect(item.color.value, '#B86F72');
    });
  });

  group('missing assets fail safely', () {
    test('an unsignable guideline leaves no URL and no crash', () async {
      final harness = build(
        session: _session(
          plan: _kitPlan(),
          steps: <TutorialStep>[
            _step(TutorialCategory.blush, 1),
            _step(TutorialCategory.lips, 2),
          ],
        ),
        stepRepository: Steps(signFails: true),
      );

      await harness.controller.open(_preview);

      expect(harness.controller.state.guidelineUrls, isEmpty);
      expect(
        harness.controller.state.status,
        TutorialStatus.ready,
        reason: 'a missing image must not fail the whole tutorial',
      );
      expect(harness.controller.state.hasCurrentGuideline, isTrue);
      expect(harness.controller.state.currentGuidelineUrl, isNull);
    });

    test('a deleted canonical preview surfaces a clear failure', () async {
      final harness = build(
        session: null,
        sessionFailure: const TutorialFailure(
          'This look could not be found.',
          kind: TutorialFailureKind.notFound,
          retryable: false,
        ),
      );

      await harness.controller.open(_preview);

      expect(harness.controller.state.status, TutorialStatus.failed);
      expect(harness.controller.state.retryable, isFalse);
      expect(harness.controller.state.message, isNotNull);
    });

    test('an expired session is surfaced, not retried', () async {
      final harness = build(
        session: null,
        sessionFailure: const TutorialFailure(
          'Sign in to open this tutorial.',
          kind: TutorialFailureKind.sessionExpired,
          retryable: false,
        ),
      );

      await harness.controller.open(_preview);

      expect(harness.controller.state.sessionExpired, isTrue);
      expect(harness.steps.generateCalls, 0);
    });
  });

  group('deletion and retention', () {
    final root = Directory.current;
    String source(String relativePath) => File(
      '${root.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
    ).readAsStringSync();

    final deleteIndex = source(
      'supabase/functions/delete-history-item/index.ts',
    );
    final migration = source(
      'supabase/migrations/20260830000100_tutorial_persistence.sql',
    );

    test('storage cleanup sweeps the whole analysis prefix', () {
      // The cleanup lists recursively from `<uid>/analyses/<id>`, so the
      // `tutorials/` folder is included without naming it — guideline images
      // cannot be orphaned by an enumeration that forgot about them.
      expect(deleteIndex, contains('listFilesRecursively(client, prefix)'));
      expect(
        deleteIndex,
        contains('historyPrefix(authData.user.id, analysisId)'),
      );
      expect(deleteIndex, contains('await removeFiles(client, storedFiles)'));
    });

    test('cleanup is verified, not assumed', () {
      expect(
        deleteIndex,
        contains('const remaining = await listFilesRecursively'),
      );
      expect(deleteIndex, contains('storage_cleanup_incomplete'));
    });

    test('files are removed before records, never the reverse', () {
      final removeAt = deleteIndex.indexOf(
        'await removeFiles(client, storedFiles)',
      );
      // Privacy-first ordering: deleting the row first and then failing on
      // storage would orphan private images with nothing pointing at them.
      // This way a failure leaves a row whose files are already gone, which a
      // retry can finish.
      final deleteRowAt = deleteIndex.lastIndexOf('.delete()');
      expect(removeAt, greaterThan(-1));
      expect(deleteRowAt, greaterThan(removeAt));
    });

    test('deleting the analysis cascades every tutorial record away', () {
      expect(
        migration,
        contains(
          'constraint tutorial_v4_sessions_analysis_owner_fk\n'
          '    foreign key (analysis_id, user_id)\n'
          '    references public.analyses(id, user_id)\n'
          '    on delete cascade',
        ),
      );
      for (final child in <String>[
        'tutorial_v4_manifest_items_session_owner_fk',
        'tutorial_v4_steps_session_owner_fk',
        'tutorial_v4_step_products_step_owner_fk',
      ]) {
        expect(migration, contains(child));
      }
      expect(
        RegExp('on delete cascade').allMatches(migration).length,
        greaterThanOrEqualTo(9),
      );
    });

    test('an unsafe path aborts the whole deletion', () {
      expect(deleteIndex, contains('unsafe_storage_path'));
      expect(
        deleteIndex,
        contains('assertOwnedHistoryPaths(recordedPaths, prefix)'),
      );
    });
  });
}
