import 'package:facetune/features/analysis/domain/entities/analysis_confidence.dart';
import 'package:facetune/features/analysis/domain/entities/facial_attributes.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_generated_preview.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/preview/domain/entities/generated_preview.dart';
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/personalized_tutorial.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_instruction.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_plan.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step_category.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/services/tutorial_planning_engine.dart';
import 'package:flutter_test/flutter_test.dart';

const _recommendationId = 'recommendation-1';
const _analysisId = 'analysis-1';

/// Real, already-analyzed face attributes — the same shape
/// `PreviewResultPage`/`MakeupKitRecommendationEntryPage` already hold via
/// `FaceAnalysis.attributes` for this exact `analysisId` (TF-1 wires this
/// through to `PersonalizedTutorialPlacementRules`, which cannot run
/// without it).
FacialAttributes _faceAttributes({
  FaceShape faceShape = FaceShape.oval,
  SkinTone skinTone = SkinTone.medium,
  Undertone undertone = Undertone.warm,
  EyeShape eyeShape = EyeShape.almond,
  LipShape lipShape = LipShape.medium,
  HairColor hairColor = HairColor.brown,
  EyeColor eyeColor = EyeColor.brown,
}) => FacialAttributes(
  faceShape: faceShape,
  skinTone: skinTone,
  undertone: undertone,
  eyeShape: eyeShape,
  lipShape: lipShape,
  hairColor: hairColor,
  eyeColor: eyeColor,
);

/// Matches `_faceAttributes()` — `FaceAnalysis.confidence`'s real shape.
AnalysisConfidence _confidence({double value = 0.9}) => AnalysisConfidence(
  faceShape: value,
  skinTone: value,
  undertone: value,
  eyeShape: value,
  lipShape: value,
  hairColor: value,
  eyeColor: value,
);

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
  String? foundationDepth,
  String? foundationUndertone,
}) => KitProductSnapshot(
  productId: productId,
  category: category,
  productName: productName,
  colorHex: colorHex,
  colorLabel: colorLabel,
  finish: finish,
  foundationDepth: foundationDepth,
  foundationUndertone: foundationUndertone,
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
        faceAttributes: _faceAttributes(),
        attributeConfidence: _confidence(),
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
          faceAttributes: _faceAttributes(),
          attributeConfidence: _confidence(),
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
        faceAttributes: _faceAttributes(),
        attributeConfidence: _confidence(),
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
          faceAttributes: _faceAttributes(),
          attributeConfidence: _confidence(),
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
          faceAttributes: _faceAttributes(),
          attributeConfidence: _confidence(),
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
        faceAttributes: _faceAttributes(),
        attributeConfidence: _confidence(),
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
        faceAttributes: _faceAttributes(),
        attributeConfidence: _confidence(),
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
        faceAttributes: _faceAttributes(),
        attributeConfidence: _confidence(),
      );

      final step = plan.steps.first;
      expect(step.instruction.productName, 'My Everyday Lipstick');
      expect(step.instruction.colorName, 'Rosewood');
      expect(step.instruction.hex, '#A45B67');
      // Humanized for display — see the "written instruction" group below
      // for why kit-sourced finish/intensity are title-cased.
      expect(step.instruction.finish, 'Matte');
      expect(step.instruction.placement, 'Across the lips');
      expect(step.instruction.technique, 'Apply a thin, even layer.');
      expect(step.instruction.intensity, 'Soft');
    });

    test('never produces a step for a category with no owned selection', () {
      final plan = TutorialPlanningEngine.planFromKitRecommendation(
        recommendation: _kitRecommendation(
          selections: [_selection(productId: 'p1', category: 'lipstick')],
          snapshots: [_snapshot(productId: 'p1', category: 'lipstick')],
        ),
        preview: _kitPreview(),
        faceAttributes: _faceAttributes(),
        attributeConfidence: _confidence(),
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
        faceAttributes: _faceAttributes(),
        attributeConfidence: _confidence(),
      );

      expect(plan.reusesFinalPreview, isTrue);
      expect(
        plan.steps.last.reusableResultImagePath,
        preview.generatedImagePath,
      );
      expect(plan.steps.last.reusableResultImageUrl, preview.generatedImageUrl);
      // The final step's model/prompt version are echoed from the actual
      // preview that generated it, not invented — see ST-8's
      // ARCHITECTURE_NOTES.md section on snapshot honesty.
      expect(plan.steps.last.reusableModelId, preview.modelId);
      expect(plan.steps.last.reusablePromptVersion, preview.promptVersion);
      // Non-final steps never get a reusable result — they still need
      // their own generation.
      expect(plan.steps.first.reusableResultImagePath, isNull);
      expect(plan.steps.first.reusableModelId, isNull);
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
          faceAttributes: _faceAttributes(),
          attributeConfidence: _confidence(),
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
        faceAttributes: _faceAttributes(),
        attributeConfidence: _confidence(),
      );

      expect(plan.reusesFinalPreview, isTrue);
      expect(
        plan.steps.last.reusableResultImagePath,
        kitPreview.generatedImagePath,
      );
    });
  });

  group('written instruction — terminology and structured facts (ST-11)', () {
    test('kit-sourced finish/intensity are humanized, matching the kit '
        'result card\'s own display convention', () {
      final plan = TutorialPlanningEngine.planFromKitRecommendation(
        recommendation: _kitRecommendation(
          selections: [
            _selection(
              productId: 'p1',
              category: 'blush',
              finish: 'long_wear',
              intensity: 'medium',
            ),
          ],
          snapshots: [_snapshot(productId: 'p1', category: 'blush')],
        ),
        preview: _kitPreview(),
        faceAttributes: _faceAttributes(),
        attributeConfidence: _confidence(),
      );

      final step = plan.steps.first;
      expect(step.instruction.finish, 'Long Wear');
      expect(step.instruction.intensity, 'Medium');
    });

    test(
      'standard-recommendation finish/intensity are left as the AI wrote '
      'them, matching recommendation_item_card\'s own display convention',
      () {
        final plan = TutorialPlanningEngine.planFromRecommendation(
          recommendation: _recommendation({
            'blush': _item(finish: 'satin', intensity: 'light'),
          }),
          preview: _preview(),
          faceAttributes: _faceAttributes(),
          attributeConfidence: _confidence(),
        );

        final step = plan.steps.first;
        expect(step.instruction.finish, 'satin');
        expect(step.instruction.intensity, 'light');
      },
    );

    test('a foundation step folds real registered depth/undertone facts into '
        'the tip, never fabricating a placeholder', () {
      final plan = TutorialPlanningEngine.planFromKitRecommendation(
        recommendation: _kitRecommendation(
          selections: [_selection(productId: 'p1', category: 'foundation')],
          snapshots: [
            _snapshot(
              productId: 'p1',
              category: 'foundation',
              foundationDepth: 'medium',
              foundationUndertone: 'warm',
            ),
          ],
        ),
        preview: _kitPreview(),
        faceAttributes: _faceAttributes(),
        attributeConfidence: _confidence(),
      );

      expect(
        plan.steps.first.instruction.tip,
        'Registered in your kit as Medium depth, Warm undertone.',
      );
    });

    test('folds a single available depth/undertone fact, not both', () {
      final plan = TutorialPlanningEngine.planFromKitRecommendation(
        recommendation: _kitRecommendation(
          selections: [_selection(productId: 'p1', category: 'foundation')],
          snapshots: [
            _snapshot(
              productId: 'p1',
              category: 'foundation',
              foundationUndertone: 'cool',
            ),
          ],
        ),
        preview: _kitPreview(),
        faceAttributes: _faceAttributes(),
        attributeConfidence: _confidence(),
      );

      expect(
        plan.steps.first.instruction.tip,
        'Registered in your kit as Cool undertone.',
      );
    });

    test('no tip is fabricated for a foundation product with no registered '
        'depth/undertone, or for any non-foundation category', () {
      final plan = TutorialPlanningEngine.planFromKitRecommendation(
        recommendation: _kitRecommendation(
          selections: [
            _selection(productId: 'p1', category: 'foundation'),
            _selection(productId: 'p2', category: 'blush'),
          ],
          snapshots: [
            _snapshot(productId: 'p1', category: 'foundation'),
            _snapshot(productId: 'p2', category: 'blush'),
          ],
        ),
        preview: _kitPreview(),
        faceAttributes: _faceAttributes(),
        attributeConfidence: _confidence(),
      );

      for (final step in plan.steps) {
        if (step.category == TutorialStepCategory.finalLook) continue;
        expect(step.instruction.tip, isNull, reason: step.category.code);
      }
    });

    test('every planned step\'s instruction category matches the step\'s own '
        'category, so overlay/instruction/generation intent never diverge', () {
      final plan = TutorialPlanningEngine.planFromRecommendation(
        recommendation: _recommendation(_fullGlamItems()),
        preview: _preview(),
        faceAttributes: _faceAttributes(),
        attributeConfidence: _confidence(),
      );

      for (final step in plan.steps) {
        expect(step.instruction.category, step.category, reason: step.title);
      }
    });
  });

  group('TF-1 — production planner invokes the personalized pipeline', () {
    test('every non-final step carries a real personalized spec and placement '
        'metadata, keyed to the step\'s own category', () {
      final plan = TutorialPlanningEngine.planFromRecommendation(
        recommendation: _recommendation(_fullGlamItems()),
        preview: _preview(),
        faceAttributes: _faceAttributes(),
        attributeConfidence: _confidence(),
      );

      for (final step in plan.steps) {
        if (step.category == TutorialStepCategory.finalLook) continue;
        final spec = step.personalizedSpec;
        expect(spec, isNotNull, reason: step.title);
        expect(spec!.stepNumber, step.stepNumber, reason: step.title);
        expect(spec.what.category, step.category, reason: step.title);
        expect(step.placementMetadata, isNotNull, reason: step.title);
        // The overlay *structure* is real (TF-1), but its overlay list is
        // legitimately empty for every step: `PersonalizedTutorialOverlayMetadataRenderer`
        // only emits a primitive for a region that has a matching
        // `geometryAnchor`, and no anchors exist yet because TF-2 (the
        // tutorial-only geometry planner) has not been built — see the
        // "no fake geometry fallback" group below. This is the honest
        // state, not a bug: visible guideline *drawing* is TF-2/TF-3's
        // job, not TF-1's.
        expect(
          step.placementMetadata!.overlays,
          isEmpty,
          reason:
              '${step.title}: overlays must stay empty rather than '
              'fabricated while no real geometry anchors exist',
        );
      }
    });

    test('kit mode also invokes the personalized pipeline, using the owned '
        'snapshot as the spec\'s product facts', () {
      final plan = TutorialPlanningEngine.planFromKitRecommendation(
        recommendation: _kitRecommendation(
          selections: [_selection(productId: 'p1', category: 'lipstick')],
          snapshots: [
            _snapshot(
              productId: 'p1',
              category: 'lipstick',
              productName: 'My Everyday Lipstick',
              colorLabel: 'Rosewood',
            ),
          ],
        ),
        preview: _kitPreview(),
        faceAttributes: _faceAttributes(),
        attributeConfidence: _confidence(),
      );

      final lipstickStep = plan.steps.first;
      expect(lipstickStep.personalizedSpec, isNotNull);
      expect(lipstickStep.personalizedSpec!.what.kitSnapshot?.productId, 'p1');
      expect(
        lipstickStep.personalizedSpec!.what.productName,
        'My Everyday Lipstick',
      );
    });

    test('the final "complete look" step never gets a personalized spec — it '
        'is a reused image reference, not an application placement step', () {
      final plan = TutorialPlanningEngine.planFromRecommendation(
        recommendation: _recommendation({'foundation': _item()}),
        preview: _preview(),
        faceAttributes: _faceAttributes(),
        attributeConfidence: _confidence(),
      );

      expect(plan.steps.last.category, TutorialStepCategory.finalLook);
      expect(plan.steps.last.personalizedSpec, isNull);
      expect(plan.steps.last.placementMetadata, isNull);
    });

    test('an entirely inapplicable recommendation never calls the personalized '
        'pipeline (no steps to build a spec for)', () {
      // Regression guard: `PersonalizedTutorialInput` throws on an empty
      // `recommendations` list, so the empty-plan early return must stay
      // ahead of the pipeline call — this must not throw.
      final plan = TutorialPlanningEngine.planFromRecommendation(
        recommendation: _recommendation({
          'foundation': _item(intensity: 'none'),
        }),
        preview: _preview(),
        faceAttributes: _faceAttributes(),
        attributeConfidence: _confidence(),
      );

      expect(plan.steps, isEmpty);
    });
  });

  group('TF-1 — no fake geometry fallback', () {
    test('geometry confidence is honestly unavailable and no anchors are '
        'fabricated, since TF-2\'s geometry planner does not exist yet', () {
      final plan = TutorialPlanningEngine.planFromRecommendation(
        recommendation: _recommendation(_fullGlamItems()),
        preview: _preview(),
        faceAttributes: _faceAttributes(),
        attributeConfidence: _confidence(),
      );

      for (final step in plan.steps) {
        final spec = step.personalizedSpec;
        if (spec == null) continue;
        expect(
          spec.where.geometryConfidence,
          TutorialPlacementConfidence.unavailable,
          reason:
              '${step.title}: geometry must be an explicit, honest '
              'dependency gap, never a guessed confidence level',
        );
        expect(
          spec.where.geometryAnchors,
          isEmpty,
          reason:
              '${step.title}: no anchor points may be invented while '
              'TutorialFaceGeometryProvider has no implementation',
        );
      }
    });
  });

  group('TF-1 — stale/legacy input remains detectable', () {
    test('a freshly planned step always carries a personalized spec, unlike a '
        'pre-TF-1 legacy step, which stays honestly distinguishable', () {
      final plan = TutorialPlanningEngine.planFromRecommendation(
        recommendation: _recommendation({'foundation': _item()}),
        preview: _preview(),
        faceAttributes: _faceAttributes(),
        attributeConfidence: _confidence(),
      );
      final freshStep = plan.steps.first;
      expect(freshStep.personalizedSpec, isNotNull);

      // This is exactly the shape production created before this phase
      // (and what a stale persisted `tutorial_steps` row still looks
      // like today): a step with no personalized spec at all. Nothing
      // in this phase backfills, coerces, or hides that gap — the field
      // stays nullable and a legacy/stale step remains identifiable by
      // its absence, which is what TF-4's stale-session handling acts
      // on.
      const legacyStep = PlannedTutorialStep(
        stepNumber: 1,
        category: TutorialStepCategory.foundation,
        title: 'Foundation',
        instruction: TutorialInstruction(
          category: TutorialStepCategory.foundation,
          placement: 'All over',
          intensity: 'light',
          technique: 'Blend with a sponge.',
        ),
      );
      expect(legacyStep.personalizedSpec, isNull);
      expect(legacyStep.placementMetadata, isNull);
    });
  });
}
