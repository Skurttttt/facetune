import 'package:facetune/features/makeup_kit/domain/entities/kit_generated_preview.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/preview/domain/entities/generated_preview.dart';
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step_category.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/services/tutorial_planning_engine.dart';
import 'package:flutter_test/flutter_test.dart';

const _recommendationId = 'recommendation-1';
const _analysisId = 'analysis-1';

MakeupRecommendationItem _item({
  String name = 'Warm peach',
  String? hex = '#E69A7A',
  String placement = 'Upper cheekbones',
  String technique = 'Blend upward toward temples.',
  String finish = 'satin',
  String intensity = 'light',
  String reasoning = 'Complements the detected warm undertone.',
}) => MakeupRecommendationItem(
  name: name,
  hex: hex,
  placement: placement,
  technique: technique,
  finish: finish,
  intensity: intensity,
  reasoning: reasoning,
);

MakeupRecommendation _recommendation(
  Map<String, MakeupRecommendationItem> items,
) => MakeupRecommendation(
  id: _recommendationId,
  analysisId: _analysisId,
  styleCode: 'natural',
  overallIntensity: 'light',
  items: items,
  modelId: 'gemini-3.6-flash',
  promptVersion: 'makeup_recommendation_v3',
  createdAt: DateTime.utc(2026, 8, 14),
);

GeneratedPreview _preview({int generationNumber = 1}) => GeneratedPreview(
  id: 'preview-1',
  analysisId: _analysisId,
  recommendationId: _recommendationId,
  originalImagePath: 'user-1/analyses/$_analysisId/original/img.jpg',
  generatedImagePath:
      'user-1/analyses/$_analysisId/generated/$_recommendationId/preview_0001.png',
  originalImageUrl: 'https://signed.example/original',
  generatedImageUrl: 'https://signed.example/generated',
  generationNumber: generationNumber,
  modelId: 'gemini-3-pro-image',
  promptVersion: 'makeup_preview_v4',
  createdAt: DateTime.utc(2026, 8, 14),
);

/// A full ten-category recommendation, matching what the Edge Function
/// actually returns today (every response fills all ten keys).
Map<String, MakeupRecommendationItem> _fullGlamItems() => {
  'foundation': _item(name: 'Medium warm beige'),
  'concealer': _item(name: 'Light warm beige'),
  'contour': _item(name: 'Cool taupe'),
  'highlight': _item(name: 'Champagne'),
  'blush': _item(name: 'Warm peach'),
  'eyeshadow': _item(name: 'Bronze smoke'),
  'eyebrow': _item(name: 'Soft brown'),
  'eyeliner': _item(name: 'Espresso'),
  'lipstick': _item(name: 'Brick rose'),
  'lipGloss': _item(name: 'Clear shine'),
};

KitMakeupSelection _selection({
  required String productId,
  required String category,
  String colorHex = '#A45B67',
  String finish = 'matte',
  String placement = 'Across the lips',
  String technique = 'Apply a thin, even layer.',
  String intensity = 'soft',
}) => KitMakeupSelection(
  productId: productId,
  category: category,
  colorHex: colorHex,
  finish: finish,
  placement: placement,
  technique: technique,
  intensity: intensity,
);

KitProductSnapshot _snapshot({
  required String productId,
  required String category,
  String? productName,
  String colorHex = '#A45B67',
  String? colorLabel,
  String finish = 'matte',
}) => KitProductSnapshot(
  productId: productId,
  category: category,
  productName: productName,
  colorHex: colorHex,
  colorLabel: colorLabel,
  finish: finish,
);

KitMakeupRecommendation _kitRecommendation({
  required List<KitMakeupSelection> selections,
  required List<KitProductSnapshot> snapshots,
}) => KitMakeupRecommendation(
  id: 'kit-recommendation-1',
  analysisId: _analysisId,
  styleCode: 'everyday',
  selections: selections,
  productSnapshots: snapshots,
  overallIntensity: 'light',
  summary: 'A soft everyday look from your kit.',
  modelId: 'gemini-3.6-flash',
  promptVersion: 'kit_makeup_recommendation_v2',
  createdAt: DateTime.utc(2026, 8, 14),
);

KitGeneratedPreview _kitPreview({
  int generationNumber = 1,
}) => KitGeneratedPreview(
  id: 'kit-preview-1',
  analysisId: _analysisId,
  kitRecommendationId: 'kit-recommendation-1',
  originalImagePath: 'user-1/analyses/$_analysisId/original/img.jpg',
  generatedImagePath:
      'user-1/analyses/$_analysisId/kit-generated/kit-recommendation-1/preview_0001.png',
  originalImageUrl: 'https://signed.example/original',
  generatedImageUrl: 'https://signed.example/kit-generated',
  generationNumber: generationNumber,
  modelId: 'gemini-3.1-flash-image',
  promptVersion: 'kit_makeup_preview_v1',
  createdAt: DateTime.utc(2026, 8, 14),
);

void main() {
  group('standard recommendation — natural/simple look', () {
    test('excludes items explicitly marked not applicable', () {
      final plan = TutorialPlanningEngine.planFromRecommendation(
        recommendation: _recommendation({
          'foundation': _item(),
          'concealer': _item(),
          'blush': _item(),
          'eyebrow': _item(),
          'eyeshadow': _item(intensity: 'none'),
          'eyeliner': _item(intensity: 'skip'),
          'contour': _item(intensity: 'N/A'),
          'highlight': _item(intensity: ''),
          'lipstick': _item(),
          'lipGloss': _item(intensity: 'not applicable'),
        }),
        preview: _preview(),
      );

      final categories = plan.steps.map((step) => step.category).toList();
      expect(
        categories,
        containsAllInOrder([
          TutorialStepCategory.foundation,
          TutorialStepCategory.concealer,
          TutorialStepCategory.blush,
          TutorialStepCategory.eyebrow,
          TutorialStepCategory.lipstick,
          TutorialStepCategory.finalLook,
        ]),
      );
      expect(categories, hasLength(6));
      expect(categories, isNot(contains(TutorialStepCategory.eyeshadow)));
      expect(categories, isNot(contains(TutorialStepCategory.contour)));
      expect(plan.totalSteps, 6);
    });
  });

  group('standard recommendation — fuller/glam look', () {
    test(
      'includes a step for every applicable category plus the final step',
      () {
        final plan = TutorialPlanningEngine.planFromRecommendation(
          recommendation: _recommendation(_fullGlamItems()),
          preview: _preview(),
        );

        expect(plan.totalSteps, 11);
        expect(plan.steps.last.category, TutorialStepCategory.finalLook);
        expect(plan.steps.last.title, 'Final Look');
      },
    );

    test('carries the recommendation item fields into the instruction', () {
      final plan = TutorialPlanningEngine.planFromRecommendation(
        recommendation: _recommendation(_fullGlamItems()),
        preview: _preview(),
      );

      final blush = plan.steps.firstWhere(
        (step) => step.category == TutorialStepCategory.blush,
      );
      expect(blush.instruction.colorName, 'Warm peach');
      expect(blush.instruction.hex, '#E69A7A');
      expect(blush.instruction.finish, 'satin');
      expect(blush.instruction.placement, 'Upper cheekbones');
      expect(blush.instruction.intensity, 'light');
      expect(blush.instruction.tip, 'Complements the detected warm undertone.');
      // Standard recommendations are brand-neutral: no product name.
      expect(blush.instruction.productName, isNull);
    });
  });

  group('ordering', () {
    test(
      'output order follows the canonical application order regardless of input map order',
      () {
        final scrambled = <String, MakeupRecommendationItem>{
          'lipGloss': _item(),
          'foundation': _item(),
          'eyeliner': _item(),
          'blush': _item(),
          'eyebrow': _item(),
        };
        final plan = TutorialPlanningEngine.planFromRecommendation(
          recommendation: _recommendation(scrambled),
          preview: _preview(),
        );

        expect(plan.steps.map((step) => step.category).toList(), [
          TutorialStepCategory.foundation,
          TutorialStepCategory.blush,
          TutorialStepCategory.eyebrow,
          TutorialStepCategory.eyeliner,
          TutorialStepCategory.lipGloss,
          TutorialStepCategory.finalLook,
        ]);
        expect(plan.steps.map((step) => step.stepNumber).toList(), [
          1,
          2,
          3,
          4,
          5,
          6,
        ]);
      },
    );

    test(
      'kit steps also follow the canonical order regardless of selection order',
      () {
        final plan = TutorialPlanningEngine.planFromKitRecommendation(
          recommendation: _kitRecommendation(
            selections: [
              _selection(productId: 'p-lip', category: 'lipstick'),
              _selection(productId: 'p-found', category: 'foundation'),
              _selection(productId: 'p-blush', category: 'blush'),
            ],
            snapshots: [
              _snapshot(productId: 'p-lip', category: 'lipstick'),
              _snapshot(productId: 'p-found', category: 'foundation'),
              _snapshot(productId: 'p-blush', category: 'blush'),
            ],
          ),
          preview: _kitPreview(),
        );

        expect(plan.steps.map((step) => step.category).toList(), [
          TutorialStepCategory.foundation,
          TutorialStepCategory.blush,
          TutorialStepCategory.lipstick,
          TutorialStepCategory.finalLook,
        ]);
      },
    );
  });

  group('My Makeup Kit — incomplete kit', () {
    test('produces exactly one step per owned selection, no more', () {
      final plan = TutorialPlanningEngine.planFromKitRecommendation(
        recommendation: _kitRecommendation(
          selections: [
            _selection(productId: 'p1', category: 'foundation'),
            _selection(productId: 'p2', category: 'blush'),
            _selection(productId: 'p3', category: 'lip_gloss'),
          ],
          snapshots: [
            _snapshot(productId: 'p1', category: 'foundation'),
            _snapshot(productId: 'p2', category: 'blush'),
            _snapshot(productId: 'p3', category: 'lip_gloss'),
          ],
        ),
        preview: _kitPreview(),
      );

      // 3 owned-product steps + 1 final step, not 10 + 1.
      expect(plan.totalSteps, 4);
      final categories = plan.steps.map((step) => step.category).toSet();
      expect(categories, {
        TutorialStepCategory.foundation,
        TutorialStepCategory.blush,
        TutorialStepCategory.lipGloss,
        TutorialStepCategory.finalLook,
      });
    });
  });

  group('My Makeup Kit — kit with only a few categories', () {
    test('a single-product kit produces a single-step-plus-final plan', () {
      final plan = TutorialPlanningEngine.planFromKitRecommendation(
        recommendation: _kitRecommendation(
          selections: [_selection(productId: 'p1', category: 'lipstick')],
          snapshots: [_snapshot(productId: 'p1', category: 'lipstick')],
        ),
        preview: _kitPreview(),
      );

      expect(plan.totalSteps, 2);
      expect(plan.steps.first.category, TutorialStepCategory.lipstick);
      expect(plan.steps.last.category, TutorialStepCategory.finalLook);
    });
  });

  group('My Makeup Kit — no fabricated products', () {
    test('carries only the owned product snapshot data, nothing invented', () {
      final plan = TutorialPlanningEngine.planFromKitRecommendation(
        recommendation: _kitRecommendation(
          selections: [
            _selection(
              productId: 'p1',
              category: 'lipstick',
              colorHex: '#A45B67',
              finish: 'matte',
              placement: 'Across the lips',
              technique: 'Apply a thin, even layer.',
              intensity: 'soft',
            ),
          ],
          snapshots: [
            _snapshot(
              productId: 'p1',
              category: 'lipstick',
              productName: 'My Everyday Lipstick',
              colorHex: '#A45B67',
              colorLabel: 'Rosewood',
              finish: 'matte',
            ),
          ],
        ),
        preview: _kitPreview(),
      );

      final step = plan.steps.first;
      expect(step.instruction.productName, 'My Everyday Lipstick');
      expect(step.instruction.colorName, 'Rosewood');
      expect(step.instruction.hex, '#A45B67');
      expect(step.instruction.finish, 'matte');
      expect(step.instruction.placement, 'Across the lips');
      expect(step.instruction.technique, 'Apply a thin, even layer.');
      expect(step.instruction.intensity, 'soft');
    });

    test('never produces a step for a category with no owned selection', () {
      final plan = TutorialPlanningEngine.planFromKitRecommendation(
        recommendation: _kitRecommendation(
          selections: [_selection(productId: 'p1', category: 'lipstick')],
          snapshots: [_snapshot(productId: 'p1', category: 'lipstick')],
        ),
        preview: _kitPreview(),
      );

      final categories = plan.steps.map((step) => step.category);
      expect(categories, isNot(contains(TutorialStepCategory.foundation)));
      expect(categories, isNot(contains(TutorialStepCategory.eyeshadow)));
      expect(categories, isNot(contains(TutorialStepCategory.contour)));
    });
  });

  group('final-preview reuse decision', () {
    test('a plan with at least one step reuses the existing final preview', () {
      final preview = _preview();
      final plan = TutorialPlanningEngine.planFromRecommendation(
        recommendation: _recommendation({'foundation': _item()}),
        preview: preview,
      );

      expect(plan.reusesFinalPreview, isTrue);
      expect(
        plan.steps.last.reusableResultImagePath,
        preview.generatedImagePath,
      );
      expect(plan.steps.last.reusableResultImageUrl, preview.generatedImageUrl);
      // Non-final steps never get a reusable result — they still need
      // their own generation.
      expect(plan.steps.first.reusableResultImagePath, isNull);
    });

    test(
      'an entirely inapplicable recommendation produces no plan and no reuse',
      () {
        final plan = TutorialPlanningEngine.planFromRecommendation(
          recommendation: _recommendation({
            'foundation': _item(intensity: 'none'),
            'blush': _item(intensity: 'skip'),
          }),
          preview: _preview(),
        );

        expect(plan.steps, isEmpty);
        expect(plan.totalSteps, 0);
        expect(plan.reusesFinalPreview, isFalse);
      },
    );

    test('kit mode also reuses its own kit preview, not the standard one', () {
      final kitPreview = _kitPreview();
      final plan = TutorialPlanningEngine.planFromKitRecommendation(
        recommendation: _kitRecommendation(
          selections: [_selection(productId: 'p1', category: 'foundation')],
          snapshots: [_snapshot(productId: 'p1', category: 'foundation')],
        ),
        preview: kitPreview,
      );

      expect(plan.reusesFinalPreview, isTrue);
      expect(
        plan.steps.last.reusableResultImagePath,
        kitPreview.generatedImagePath,
      );
    });
  });
}
