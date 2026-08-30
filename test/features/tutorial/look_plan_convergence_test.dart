import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/tutorial/domain/catalog/look_plan_convergence.dart';
import 'package:facetune/features/tutorial/domain/entities/recommendation_source_mode.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/tutorial/domain/entities/validated_look_plan.dart';
import 'package:facetune/features/tutorial/domain/errors/tutorial_failure.dart';
import 'package:flutter_test/flutter_test.dart';

final _createdAt = DateTime.utc(2026, 8, 30);

MakeupRecommendationItem _item(String name, String hex) =>
    MakeupRecommendationItem(
      name: name,
      hex: hex,
      placement: 'Across the cheeks.',
      technique: 'Blend outward.',
      finish: 'satin',
      intensity: 'soft',
      reasoning: 'Suits the supplied undertone.',
    );

MakeupRecommendation _standard() => MakeupRecommendation(
  id: 'rec-1',
  analysisId: 'analysis-1',
  styleCode: 'soft_glam',
  overallIntensity: 'soft',
  items: <String, MakeupRecommendationItem>{
    'foundation': _item('Warm beige', '#E3C4A8'),
    'blush': _item('Warm peach', '#E8A08C'),
    'lipstick': _item('Rosewood', '#B86F72'),
  },
  modelId: 'server-reported-model',
  promptVersion: 'makeup_recommendation_v2',
  createdAt: _createdAt,
);

KitProductSnapshot _snapshot(
  String productId,
  String category, {
  String colorHex = '#B86F72',
  String finish = 'matte',
  String? productName,
}) => KitProductSnapshot(
  productId: productId,
  category: category,
  colorHex: colorHex,
  finish: finish,
  productName: productName,
);

KitMakeupRecommendation _kit({required List<KitProductSnapshot> snapshots}) =>
    KitMakeupRecommendation(
      id: 'kit-rec-1',
      analysisId: 'analysis-1',
      styleCode: 'soft_glam',
      selections: <KitMakeupSelection>[
        for (final snapshot in snapshots)
          KitMakeupSelection(
            productId: snapshot.productId,
            category: snapshot.category,
            colorHex: snapshot.colorHex,
            finish: snapshot.finish,
            placement: 'As appropriate.',
            technique: 'Blend well.',
            intensity: 'soft',
          ),
      ],
      productSnapshots: snapshots,
      overallIntensity: 'soft',
      summary: 'A look built from products you own.',
      modelId: 'server-reported-model',
      promptVersion: 'kit_makeup_recommendation_v2',
      createdAt: _createdAt,
    );

void main() {
  group('Standard Mode converges', () {
    test('produces a validated look plan carrying its lineage', () {
      final plan = LookPlanConvergence.fromStandard(_standard());

      expect(plan.id, 'rec-1');
      expect(plan.analysisId, 'analysis-1');
      expect(plan.styleCode, 'soft_glam');
      expect(plan.modelId, 'server-reported-model');
      expect(plan.promptVersion, 'makeup_recommendation_v2');
      expect(plan.createdAt, _createdAt);
    });

    test('reports standard mode through the sealed source', () {
      final plan = LookPlanConvergence.fromStandard(_standard());

      expect(plan.sourceMode, RecommendationSourceMode.standard);
      expect(plan.source, isA<StandardLookPlanSource>());
      expect((plan.source as StandardLookPlanSource).recommendationId, 'rec-1');
    });

    test('carries no owned-product selection', () {
      final plan = LookPlanConvergence.fromStandard(_standard());

      expect(plan.productSnapshot.items, isEmpty);
      expect(plan.productBackedCategories, isEmpty);
      for (final category in TutorialCategory.values) {
        expect(plan.productSnapshot.covers(category), isFalse);
      }
    });
  });

  group('My Makeup Kit Mode converges', () {
    test('produces a validated look plan carrying its lineage', () {
      final plan = LookPlanConvergence.fromMyMakeupKit(
        _kit(snapshots: <KitProductSnapshot>[_snapshot('p1', 'blush')]),
      );

      expect(plan.id, 'kit-rec-1');
      expect(plan.analysisId, 'analysis-1');
      expect(plan.promptVersion, 'kit_makeup_recommendation_v2');
      expect(plan.sourceMode, RecommendationSourceMode.myMakeupKit);
      expect(
        (plan.source as MyMakeupKitLookPlanSource).kitRecommendationId,
        'kit-rec-1',
      );
    });

    test('a complete kit maps every selected product', () {
      final plan = LookPlanConvergence.fromMyMakeupKit(
        _kit(
          snapshots: <KitProductSnapshot>[
            _snapshot(
              'p1',
              'foundation',
              colorHex: '#E3C4A8',
              finish: 'natural',
            ),
            _snapshot('p2', 'concealer', finish: 'radiant'),
            _snapshot('p3', 'contour_bronzer', finish: 'matte'),
            _snapshot('p4', 'blush', finish: 'satin'),
            _snapshot('p5', 'highlighter', finish: 'shimmer'),
            _snapshot('p6', 'eyebrow', finish: 'natural'),
            _snapshot('p7', 'eyeshadow', finish: 'matte'),
            _snapshot('p8', 'eyeliner', finish: 'matte'),
            _snapshot('p9', 'lipstick', finish: 'cream'),
          ],
        ),
      );

      expect(plan.productSnapshot.items, hasLength(9));
      expect(
        plan.productBackedCategories,
        TutorialCategory.orderedVocabulary,
        reason: 'a complete kit backs all nine tutorial categories',
      );
    });

    test('an incomplete kit converges without inventing categories', () {
      final plan = LookPlanConvergence.fromMyMakeupKit(
        _kit(
          snapshots: <KitProductSnapshot>[
            _snapshot('p1', 'foundation', finish: 'natural'),
            _snapshot('p2', 'lipstick', finish: 'cream'),
          ],
        ),
      );

      expect(plan.productBackedCategories, const <TutorialCategory>[
        TutorialCategory.foundation,
        TutorialCategory.lips,
      ]);
      expect(plan.productSnapshot.covers(TutorialCategory.eyeliner), isFalse);
      expect(plan.productSnapshot.itemsFor(TutorialCategory.eyeliner), isEmpty);
    });

    test('several products in one category all reach that category', () {
      final plan = LookPlanConvergence.fromMyMakeupKit(
        _kit(
          snapshots: <KitProductSnapshot>[
            _snapshot(
              'p1',
              'lipstick',
              finish: 'cream',
              productName: 'Everyday Nude',
            ),
            _snapshot(
              'p2',
              'lip_gloss',
              finish: 'glossy',
              productName: 'Clear Shine',
            ),
          ],
        ),
      );

      final lips = plan.productSnapshot.itemsFor(TutorialCategory.lips);
      expect(lips, hasLength(2));
      expect(lips.map((item) => item.productName).toList(), <String>[
        'Everyday Nude',
        'Clear Shine',
      ]);
      expect(
        plan.productBackedCategories,
        const <TutorialCategory>[TutorialCategory.lips],
        reason: 'two products still describe one tutorial step',
      );
    });

    test('preserves the user-entered product name for display', () {
      final plan = LookPlanConvergence.fromMyMakeupKit(
        _kit(
          snapshots: <KitProductSnapshot>[
            _snapshot('p1', 'blush', productName: 'Rose Glow by SomeBrand'),
          ],
        ),
      );

      expect(
        plan.productSnapshot.items.single.productName,
        'Rose Glow by SomeBrand',
      );
    });

    test('an unnamed owned product stays unnamed', () {
      final plan = LookPlanConvergence.fromMyMakeupKit(
        _kit(snapshots: <KitProductSnapshot>[_snapshot('p1', 'blush')]),
      );

      expect(plan.productSnapshot.items.single.productName, isNull);
    });

    test('never falls back to Standard Mode on an empty selection', () {
      final plan = LookPlanConvergence.fromMyMakeupKit(
        _kit(snapshots: const <KitProductSnapshot>[]),
      );

      expect(plan.productSnapshot.items, isEmpty);
      expect(plan.sourceMode, RecommendationSourceMode.myMakeupKit);
      expect(plan.source, isA<MyMakeupKitLookPlanSource>());
      expect(plan.source, isNot(isA<StandardLookPlanSource>()));
    });

    test('rejects a persisted snapshot outside the controlled vocabulary', () {
      expect(
        () => LookPlanConvergence.fromMyMakeupKit(
          _kit(
            snapshots: <KitProductSnapshot>[_snapshot('p1', 'setting_spray')],
          ),
        ),
        throwsA(
          isA<TutorialFailure>().having(
            (failure) => failure.kind,
            'kind',
            TutorialFailureKind.unsupportedCategory,
          ),
        ),
      );
    });
  });

  group('the two modes share one contract', () {
    test('both produce a ValidatedLookPlan distinguishable only by source', () {
      final standard = LookPlanConvergence.fromStandard(_standard());
      final kit = LookPlanConvergence.fromMyMakeupKit(
        _kit(snapshots: <KitProductSnapshot>[_snapshot('p1', 'blush')]),
      );

      for (final plan in <ValidatedLookPlan>[standard, kit]) {
        expect(plan.analysisId, 'analysis-1');
        expect(plan.styleCode, 'soft_glam');
        expect(plan.modelId, isNotEmpty);
        expect(plan.promptVersion, isNotEmpty);
      }
      expect(standard.sourceMode, isNot(kit.sourceMode));
    });

    test('a consumer can branch exhaustively without a null check', () {
      for (final plan in <ValidatedLookPlan>[
        LookPlanConvergence.fromStandard(_standard()),
        LookPlanConvergence.fromMyMakeupKit(
          _kit(snapshots: <KitProductSnapshot>[_snapshot('p1', 'blush')]),
        ),
      ]) {
        final described = switch (plan.source) {
          StandardLookPlanSource(:final recommendationId) =>
            'standard:$recommendationId',
          MyMakeupKitLookPlanSource(:final kitRecommendationId) =>
            'kit:$kitRecommendationId',
        };
        expect(described, contains(plan.id));
      }
    });
  });
}
