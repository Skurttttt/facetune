import 'package:facetune/features/tutorial/domain/entities/look_product_snapshot.dart';
import 'package:facetune/features/tutorial/domain/entities/recommendation_source_mode.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_manifest.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_session.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_step.dart';
import 'package:facetune/features/tutorial/domain/entities/validated_look_plan.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 8, 30);

TutorialManifest acceptedManifest({
  String canonicalPreviewId = 'preview-1',
  TutorialManifestStatus status = TutorialManifestStatus.accepted,
  List<TutorialCategory> present = const <TutorialCategory>[
    TutorialCategory.foundation,
    TutorialCategory.blush,
    TutorialCategory.lips,
  ],
}) => TutorialManifest(
  canonicalPreviewId: canonicalPreviewId,
  sourceMode: RecommendationSourceMode.standard,
  status: status,
  items: <TutorialManifestItem>[
    for (final category in TutorialCategory.values)
      TutorialManifestItem(
        category: category,
        presence: present.contains(category)
            ? TutorialCategoryPresence.present
            : TutorialCategoryPresence.absent,
      ),
  ],
  modelId: 'server-reported-model',
  promptVersion: 'v1',
  schemaVersion: 'v1',
  createdAt: _now,
);

TutorialStep step(
  TutorialCategory category,
  int position,
  TutorialStepStatus status, {
  String? guidelineStoragePath,
}) => TutorialStep(
  id: 'step-${category.code}',
  sessionId: 'session-1',
  category: category,
  position: position,
  status: status,
  guidelineStoragePath: guidelineStoragePath,
  createdAt: _now,
  updatedAt: _now,
);

TutorialSession session({
  TutorialManifest? manifest,
  List<TutorialStep> steps = const <TutorialStep>[],
  String canonicalPreviewId = 'preview-1',
  TutorialSessionStatus status = TutorialSessionStatus.ready,
  LookPlanSource? source,
}) => TutorialSession(
  id: 'session-1',
  userId: 'user-1',
  analysisId: 'analysis-1',
  canonicalPreviewId: canonicalPreviewId,
  lookPlan: ValidatedLookPlan(
    id: 'plan-1',
    analysisId: 'analysis-1',
    styleCode: 'soft_glam',
    source: source ?? StandardLookPlanSource(recommendationId: 'rec-1'),
    modelId: 'server-reported-model',
    promptVersion: 'v1',
    createdAt: _now,
  ),
  status: status,
  manifest: manifest,
  steps: steps,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  group('session status vocabulary', () {
    test('covers the full lifecycle without ambiguous booleans', () {
      expect(
        TutorialSessionStatus.values.map((status) => status.code).toList(),
        <String>[
          'not_started',
          'creating_session',
          'analyzing_manifest',
          'manifest_ready',
          'manifest_failed',
          'ready',
          'generating_step',
          'step_ready',
          'step_failed',
          // Added in V4-5: a kit-preview inconsistency is a distinct terminal
          // state, never a generic failure and never a silent downgrade.
          'kit_preview_mismatch',
          'completed',
        ],
      );
      for (final status in TutorialSessionStatus.values) {
        expect(TutorialSessionStatus.fromCode(status.code), status);
      }
      expect(TutorialSessionStatus.fromCode('loading'), isNull);
    });

    test('step status vocabulary round-trips', () {
      expect(
        TutorialStepStatus.values.map((status) => status.code).toList(),
        <String>['pending', 'generating', 'ready', 'failed'],
      );
      for (final status in TutorialStepStatus.values) {
        expect(TutorialStepStatus.fromCode(status.code), status);
      }
      expect(TutorialStepStatus.fromCode('done'), isNull);
    });
  });

  group('manifest reuse', () {
    test('an accepted manifest for this preview is reusable', () {
      final subject = session(manifest: acceptedManifest());

      expect(subject.hasReusableManifest, isTrue);
      expect(subject.manifestStatus, TutorialManifestStatus.accepted);
    });

    test('a missing manifest reports pending and is not reusable', () {
      final subject = session();

      expect(subject.manifest, isNull);
      expect(subject.manifestStatus, TutorialManifestStatus.pending);
      expect(subject.hasReusableManifest, isFalse);
      expect(subject.includedCategories, isEmpty);
    });

    test('a failed manifest is not reusable', () {
      final subject = session(
        manifest: acceptedManifest(status: TutorialManifestStatus.failed),
      );

      expect(subject.hasReusableManifest, isFalse);
    });

    test('a manifest for a different preview is not reusable', () {
      final subject = session(
        canonicalPreviewId: 'preview-2',
        manifest: acceptedManifest(canonicalPreviewId: 'preview-1'),
      );

      expect(
        subject.hasReusableManifest,
        isFalse,
        reason: 'a regenerated preview is a new visual target',
      );
    });
  });

  group('steps', () {
    test('exposes included categories in deterministic order', () {
      final subject = session(manifest: acceptedManifest());

      expect(subject.includedCategories, const <TutorialCategory>[
        TutorialCategory.foundation,
        TutorialCategory.blush,
        TutorialCategory.lips,
      ]);
    });

    test('orders steps by presentation position', () {
      final subject = session(
        manifest: acceptedManifest(),
        steps: <TutorialStep>[
          step(TutorialCategory.lips, 3, TutorialStepStatus.pending),
          step(TutorialCategory.foundation, 1, TutorialStepStatus.pending),
          step(TutorialCategory.blush, 2, TutorialStepStatus.pending),
        ],
      );

      expect(
        subject.orderedSteps.map((s) => s.category).toList(),
        const <TutorialCategory>[
          TutorialCategory.foundation,
          TutorialCategory.blush,
          TutorialCategory.lips,
        ],
      );
    });

    test('presentation position is independent of vocabulary order', () {
      final subject = session(
        manifest: acceptedManifest(),
        steps: <TutorialStep>[
          step(TutorialCategory.foundation, 1, TutorialStepStatus.pending),
          step(TutorialCategory.blush, 2, TutorialStepStatus.pending),
          step(TutorialCategory.lips, 3, TutorialStepStatus.pending),
        ],
      );

      expect(subject.orderedSteps.map((s) => s.position).toList(), <int>[
        1,
        2,
        3,
      ]);
      expect(subject.orderedSteps.map((s) => s.category.order).toList(), <int>[
        1,
        4,
        9,
      ]);
    });

    test('excludes ready steps from pending work', () {
      final subject = session(
        manifest: acceptedManifest(),
        steps: <TutorialStep>[
          step(
            TutorialCategory.foundation,
            1,
            TutorialStepStatus.ready,
            guidelineStoragePath: 'user-1/tutorials/session-1/foundation.png',
          ),
          step(TutorialCategory.blush, 2, TutorialStepStatus.pending),
          step(TutorialCategory.lips, 3, TutorialStepStatus.pending),
        ],
      );

      expect(
        subject.pendingSteps.map((s) => s.category).toList(),
        const <TutorialCategory>[TutorialCategory.blush, TutorialCategory.lips],
      );
      expect(subject.stepFor(TutorialCategory.foundation)!.isReady, isTrue);
    });

    test('a ready status without a stored guideline is not ready', () {
      expect(
        step(TutorialCategory.blush, 1, TutorialStepStatus.ready).isReady,
        isFalse,
      );
    });

    test('returns null for a category the tutorial does not include', () {
      final subject = session(manifest: acceptedManifest());

      expect(subject.stepFor(TutorialCategory.eyeliner), isNull);
    });

    test('steps are immutable', () {
      final subject = session(
        steps: <TutorialStep>[
          step(TutorialCategory.blush, 1, TutorialStepStatus.pending),
        ],
      );

      expect(
        () => subject.steps.add(subject.steps.first),
        throwsUnsupportedError,
      );
    });
  });

  test('session reads its source mode from the look plan', () {
    final standard = session();
    final kit = session(
      source: MyMakeupKitLookPlanSource(
        kitRecommendationId: 'kit-rec-1',
        productSnapshot: LookProductSnapshot.empty,
      ),
    );

    expect(standard.sourceMode, RecommendationSourceMode.standard);
    expect(kit.sourceMode, RecommendationSourceMode.myMakeupKit);
  });
}
