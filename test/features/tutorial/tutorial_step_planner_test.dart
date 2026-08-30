import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/tutorial/domain/catalog/look_plan_convergence.dart';
import 'package:facetune/features/tutorial/domain/catalog/tutorial_step_planner.dart';
import 'package:facetune/features/tutorial/domain/entities/recommendation_source_mode.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_manifest.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_step.dart';
import 'package:facetune/features/tutorial/domain/entities/validated_look_plan.dart';
import 'package:facetune/features/tutorial/domain/errors/tutorial_failure.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 8, 30);

ValidatedLookPlan standardPlan() => LookPlanConvergence.fromStandard(
  MakeupRecommendation(
    id: 'rec-1',
    analysisId: 'analysis-1',
    styleCode: 'soft_glam',
    overallIntensity: 'soft',
    items: const <String, MakeupRecommendationItem>{},
    modelId: 'model',
    promptVersion: 'v1',
    createdAt: _now,
  ),
);

ValidatedLookPlan kitPlan(List<(String, String)> products) =>
    LookPlanConvergence.fromMyMakeupKit(
      KitMakeupRecommendation(
        id: 'kit-rec-1',
        analysisId: 'analysis-1',
        styleCode: 'soft_glam',
        selections: const <KitMakeupSelection>[],
        productSnapshots: <KitProductSnapshot>[
          for (final (id, category) in products)
            KitProductSnapshot(
              productId: id,
              category: category,
              colorHex: '#B86F72',
              finish: 'matte',
              productName: 'Product $id',
            ),
        ],
        overallIntensity: 'soft',
        summary: 'Owned products only.',
        modelId: 'model',
        promptVersion: 'v1',
        createdAt: _now,
      ),
    );

TutorialManifest manifest({
  required RecommendationSourceMode sourceMode,
  required List<TutorialCategory> present,
  List<TutorialCategory> uncertain = const <TutorialCategory>[],
  Set<TutorialCategory> backed = const <TutorialCategory>{},
  TutorialManifestStatus status = TutorialManifestStatus.accepted,
}) => TutorialManifest(
  canonicalPreviewId: 'preview-1',
  sourceMode: sourceMode,
  status: status,
  items: <TutorialManifestItem>[
    for (final category in TutorialCategory.values)
      TutorialManifestItem(
        category: category,
        presence: present.contains(category)
            ? TutorialCategoryPresence.present
            : uncertain.contains(category)
            ? TutorialCategoryPresence.uncertain
            : TutorialCategoryPresence.absent,
        productBacked: backed.contains(category),
      ),
  ],
  modelId: 'manifest-model',
  promptVersion: 'tutorial_manifest_v4_1',
  schemaVersion: 'tutorial_manifest_schema_v1',
  createdAt: _now,
);

TutorialStep existingStep(
  TutorialCategory category,
  int position,
  TutorialStepStatus status, {
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

void main() {
  group('a subset manifest creates a subset of steps', () {
    test('only visually present categories become steps', () {
      final planned = TutorialStepPlanner.plan(
        manifest: manifest(
          sourceMode: RecommendationSourceMode.standard,
          present: const <TutorialCategory>[
            TutorialCategory.foundation,
            TutorialCategory.blush,
            TutorialCategory.lips,
          ],
        ),
        lookPlan: standardPlan(),
      );

      expect(
        planned.map((step) => step.category).toList(),
        const <TutorialCategory>[
          TutorialCategory.foundation,
          TutorialCategory.blush,
          TutorialCategory.lips,
        ],
      );
    });

    test('nothing present yields no steps rather than a default nine', () {
      final planned = TutorialStepPlanner.plan(
        manifest: manifest(
          sourceMode: RecommendationSourceMode.standard,
          present: const <TutorialCategory>[],
        ),
        lookPlan: standardPlan(),
      );

      expect(planned, isEmpty);
    });

    test('uncertain categories never become steps', () {
      final planned = TutorialStepPlanner.plan(
        manifest: manifest(
          sourceMode: RecommendationSourceMode.standard,
          present: const <TutorialCategory>[TutorialCategory.lips],
          uncertain: const <TutorialCategory>[
            TutorialCategory.foundation,
            TutorialCategory.blush,
          ],
        ),
        lookPlan: standardPlan(),
      );

      expect(
        planned.map((step) => step.category).toList(),
        const <TutorialCategory>[TutorialCategory.lips],
      );
    });
  });

  group('Step X of N depends on the included count', () {
    test('a three-step tutorial numbers 1..3, not by vocabulary rank', () {
      final planned = TutorialStepPlanner.plan(
        manifest: manifest(
          sourceMode: RecommendationSourceMode.standard,
          present: const <TutorialCategory>[
            TutorialCategory.foundation,
            TutorialCategory.blush,
            TutorialCategory.lips,
          ],
        ),
        lookPlan: standardPlan(),
      );

      expect(planned.map((step) => step.position).toList(), <int>[1, 2, 3]);
      expect(
        planned.map((step) => step.category.order).toList(),
        <int>[1, 4, 9],
        reason: 'vocabulary rank is unchanged and separate from position',
      );
      expect(planned.length, 3, reason: 'N is the included count');
    });

    test('a nine-step tutorial numbers 1..9', () {
      final planned = TutorialStepPlanner.plan(
        manifest: manifest(
          sourceMode: RecommendationSourceMode.standard,
          present: TutorialCategory.values,
        ),
        lookPlan: standardPlan(),
      );

      expect(planned.length, 9);
      expect(
        planned.map((step) => step.position).toList(),
        List<int>.generate(9, (index) => index + 1),
      );
    });

    test('positions are contiguous with no gaps after filtering', () {
      final planned = TutorialStepPlanner.plan(
        manifest: manifest(
          sourceMode: RecommendationSourceMode.standard,
          present: const <TutorialCategory>[
            TutorialCategory.concealer,
            TutorialCategory.eyeliner,
          ],
        ),
        lookPlan: standardPlan(),
      );

      expect(planned.map((step) => step.position).toList(), <int>[1, 2]);
    });
  });

  group('order stays deterministic', () {
    test('dropping contour and highlighter preserves relative order', () {
      final planned = TutorialStepPlanner.plan(
        manifest: manifest(
          sourceMode: RecommendationSourceMode.standard,
          present: TutorialCategory.values
              .where(
                (category) =>
                    category != TutorialCategory.contourBronzer &&
                    category != TutorialCategory.highlighter,
              )
              .toList(),
        ),
        lookPlan: standardPlan(),
      );

      expect(planned.map((step) => step.category.code).toList(), <String>[
        'foundation',
        'concealer',
        'blush',
        'eyebrows',
        'eyeshadow',
        'eyeliner',
        'lips',
      ]);
    });

    test('planning is repeatable', () {
      final subject = manifest(
        sourceMode: RecommendationSourceMode.standard,
        present: const <TutorialCategory>[
          TutorialCategory.lips,
          TutorialCategory.foundation,
        ],
      );
      final first = TutorialStepPlanner.plan(
        manifest: subject,
        lookPlan: standardPlan(),
      );
      final second = TutorialStepPlanner.plan(
        manifest: subject,
        lookPlan: standardPlan(),
      );

      expect(
        first.map((step) => '${step.category.code}:${step.position}').toList(),
        second.map((step) => '${step.category.code}:${step.position}').toList(),
      );
    });
  });

  group('My Makeup Kit snapshot linkage', () {
    test('a step carries the exact snapshot item for its category', () {
      final planned = TutorialStepPlanner.plan(
        manifest: manifest(
          sourceMode: RecommendationSourceMode.myMakeupKit,
          present: const <TutorialCategory>[
            TutorialCategory.foundation,
            TutorialCategory.lips,
          ],
          backed: const <TutorialCategory>{
            TutorialCategory.foundation,
            TutorialCategory.lips,
          },
        ),
        lookPlan: kitPlan(const <(String, String)>[
          ('p1', 'foundation'),
          ('p2', 'lipstick'),
        ]),
      );

      expect(planned.first.productSnapshotItems.single.productId, 'p1');
      expect(planned.last.productSnapshotItems.single.productId, 'p2');
    });

    test('one step can carry several owned products', () {
      final planned = TutorialStepPlanner.plan(
        manifest: manifest(
          sourceMode: RecommendationSourceMode.myMakeupKit,
          present: const <TutorialCategory>[TutorialCategory.lips],
          backed: const <TutorialCategory>{TutorialCategory.lips},
        ),
        lookPlan: kitPlan(const <(String, String)>[
          ('p1', 'lipstick'),
          ('p2', 'lip_gloss'),
        ]),
      );

      expect(planned.single.category, TutorialCategory.lips);
      expect(
        planned.single.productSnapshotItems.map((item) => item.productId),
        <String>['p1', 'p2'],
      );
    });

    test('an unbacked visible category refuses to plan at all', () {
      expect(
        () => TutorialStepPlanner.plan(
          manifest: manifest(
            sourceMode: RecommendationSourceMode.myMakeupKit,
            present: const <TutorialCategory>[
              TutorialCategory.foundation,
              TutorialCategory.eyeliner,
            ],
            backed: const <TutorialCategory>{TutorialCategory.foundation},
          ),
          lookPlan: kitPlan(const <(String, String)>[('p1', 'foundation')]),
        ),
        throwsA(
          isA<TutorialFailure>().having(
            (failure) => failure.kind,
            'kind',
            TutorialFailureKind.kitPreviewMismatch,
          ),
        ),
      );
    });

    test('an owned but invisible category is not made into a step', () {
      final planned = TutorialStepPlanner.plan(
        manifest: manifest(
          sourceMode: RecommendationSourceMode.myMakeupKit,
          present: const <TutorialCategory>[TutorialCategory.lips],
          backed: const <TutorialCategory>{
            TutorialCategory.lips,
            TutorialCategory.eyeliner,
          },
        ),
        lookPlan: kitPlan(const <(String, String)>[
          ('p1', 'lipstick'),
          ('p2', 'eyeliner'),
        ]),
      );

      expect(
        planned.map((step) => step.category).toList(),
        const <TutorialCategory>[TutorialCategory.lips],
      );
    });
  });

  group('Standard Mode carries no kit snapshot', () {
    test('steps have no product items', () {
      final planned = TutorialStepPlanner.plan(
        manifest: manifest(
          sourceMode: RecommendationSourceMode.standard,
          present: const <TutorialCategory>[
            TutorialCategory.foundation,
            TutorialCategory.lips,
          ],
        ),
        lookPlan: standardPlan(),
      );

      for (final step in planned) {
        expect(step.productSnapshotItems, isEmpty);
      }
    });
  });

  group('safe state transitions', () {
    test('an unaccepted manifest cannot be planned', () {
      expect(
        () => TutorialStepPlanner.plan(
          manifest: manifest(
            sourceMode: RecommendationSourceMode.standard,
            present: const <TutorialCategory>[TutorialCategory.lips],
            status: TutorialManifestStatus.failed,
          ),
          lookPlan: standardPlan(),
        ),
        throwsA(
          isA<TutorialFailure>().having(
            (failure) => failure.kind,
            'kind',
            TutorialFailureKind.manifestUnavailable,
          ),
        ),
      );
    });

    test('a manifest and plan in different modes cannot be planned', () {
      expect(
        () => TutorialStepPlanner.plan(
          manifest: manifest(
            sourceMode: RecommendationSourceMode.standard,
            present: const <TutorialCategory>[TutorialCategory.lips],
          ),
          lookPlan: kitPlan(const <(String, String)>[('p1', 'lipstick')]),
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
  });

  group('existing steps are reused, never rebuilt', () {
    List<PlannedTutorialStep> planned() => TutorialStepPlanner.plan(
      manifest: manifest(
        sourceMode: RecommendationSourceMode.standard,
        present: const <TutorialCategory>[
          TutorialCategory.foundation,
          TutorialCategory.blush,
          TutorialCategory.lips,
        ],
      ),
      lookPlan: standardPlan(),
    );

    test('a ready step is not reported as missing', () {
      final missing = TutorialStepPlanner.missingSteps(
        planned: planned(),
        existing: <TutorialStep>[
          existingStep(
            TutorialCategory.foundation,
            1,
            TutorialStepStatus.ready,
            path: 'user-1/analyses/a/tutorials/s/foundation.png',
          ),
        ],
      );

      expect(
        missing.map((step) => step.category).toList(),
        const <TutorialCategory>[TutorialCategory.blush, TutorialCategory.lips],
      );
    });

    test('a pending or failed step is also not recreated', () {
      final missing = TutorialStepPlanner.missingSteps(
        planned: planned(),
        existing: <TutorialStep>[
          existingStep(TutorialCategory.blush, 2, TutorialStepStatus.pending),
          existingStep(TutorialCategory.lips, 3, TutorialStepStatus.failed),
        ],
      );

      expect(
        missing.map((step) => step.category).toList(),
        const <TutorialCategory>[TutorialCategory.foundation],
      );
    });

    test('a fully materialised session needs no work', () {
      final existing = <TutorialStep>[
        existingStep(TutorialCategory.foundation, 1, TutorialStepStatus.ready),
        existingStep(TutorialCategory.blush, 2, TutorialStepStatus.ready),
        existingStep(TutorialCategory.lips, 3, TutorialStepStatus.ready),
      ];

      expect(
        TutorialStepPlanner.missingSteps(
          planned: planned(),
          existing: existing,
        ),
        isEmpty,
      );
      expect(
        TutorialStepPlanner.isComplete(planned: planned(), existing: existing),
        isTrue,
      );
    });

    test('repeating the reconciliation is idempotent', () {
      final first = TutorialStepPlanner.missingSteps(
        planned: planned(),
        existing: const <TutorialStep>[],
      );
      final second = TutorialStepPlanner.missingSteps(
        planned: planned(),
        existing: const <TutorialStep>[],
      );

      expect(first.length, second.length);
      expect(first.length, 3);
    });
  });
}
