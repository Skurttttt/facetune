import 'package:facetune/features/analysis/domain/entities/analysis_confidence.dart';
import 'package:facetune/features/analysis/domain/entities/facial_attributes.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/personalized_tutorial.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_source_mode.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step_category.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/services/personalized_tutorial_placement_rules.dart';
import 'package:flutter_test/flutter_test.dart';

const _confidence = AnalysisConfidence(
  faceShape: 0.9,
  skinTone: 0.85,
  undertone: 0.8,
  eyeShape: 0.88,
  lipShape: 0.82,
  hairColor: 0.9,
  eyeColor: 0.86,
);

FacialAttributes _attributes({
  FaceShape faceShape = FaceShape.oval,
  EyeShape eyeShape = EyeShape.almond,
  LipShape lipShape = LipShape.full,
}) => FacialAttributes(
  faceShape: faceShape,
  skinTone: SkinTone.medium,
  undertone: Undertone.warm,
  eyeShape: eyeShape,
  lipShape: lipShape,
  hairColor: HairColor.darkBrown,
  eyeColor: EyeColor.brown,
);

TutorialRecommendationData _recommendation(TutorialStepCategory category) =>
    TutorialRecommendationData(
      category: category,
      placement: 'Recommendation placement for ${category.code}',
      intensity: 'medium',
      technique: 'Use the recommended technique.',
      productName: 'Recommended product',
      colorName: 'Peach Rose',
      colorHex: '#E58C87',
      finish: 'Satin',
    );

PersonalizedTutorialInput _input({
  FaceShape faceShape = FaceShape.oval,
  EyeShape eyeShape = EyeShape.almond,
  LipShape lipShape = LipShape.full,
  String style = 'everyday',
  List<TutorialRecommendationData>? recommendations,
  TutorialSourceMode sourceMode = TutorialSourceMode.standardRecommendation,
  List<TutorialKitProductSnapshot> kitSnapshots = const [],
}) => PersonalizedTutorialInput(
  sourceMode: sourceMode,
  faceAttributes: _attributes(
    faceShape: faceShape,
    eyeShape: eyeShape,
    lipShape: lipShape,
  ),
  attributeConfidence: _confidence,
  selectedStyle: style,
  recommendations:
      recommendations ?? [_recommendation(TutorialStepCategory.blush)],
  kitSnapshots: kitSnapshots,
);

void main() {
  test('emits structured rules for every application category', () {
    const categories = [
      TutorialStepCategory.foundation,
      TutorialStepCategory.concealer,
      TutorialStepCategory.contour,
      TutorialStepCategory.blush,
      TutorialStepCategory.highlighter,
      TutorialStepCategory.eyeshadow,
      TutorialStepCategory.eyeliner,
      TutorialStepCategory.eyebrow,
      TutorialStepCategory.lipstick,
      TutorialStepCategory.lipGloss,
    ];
    final steps = PersonalizedTutorialPlacementRules.build(
      _input(recommendations: categories.map(_recommendation).toList()),
    );

    expect(steps, hasLength(categories.length));
    for (final (index, step) in steps.indexed) {
      expect(step.stepNumber, index + 1);
      expect(step.what.category, categories[index]);
      expect(step.where.regions, isNotEmpty);
      expect(step.where.overlays, isNotEmpty);
      expect(
        step.where.geometryConfidence,
        TutorialPlacementConfidence.unavailable,
      );
    }
  });

  test('round-face blush differs from oval-face blush', () {
    final round = PersonalizedTutorialPlacementRules.build(
      _input(faceShape: FaceShape.round),
    ).single;
    final oval = PersonalizedTutorialPlacementRules.build(
      _input(faceShape: FaceShape.oval),
    ).single;

    expect(round.where.regions, {TutorialPlacementRegion.cheekbone});
    expect(oval.where.regions, {TutorialPlacementRegion.cheek});
    expect(round.how.direction, TutorialDirection.upwardOutward);
    expect(oval.how.direction, TutorialDirection.outward);
    expect(round.faceAdjustment, isNot(oval.faceAdjustment));
  });

  test('hooded-eye guidance differs from almond-eye guidance', () {
    final recommendation = _recommendation(TutorialStepCategory.eyeshadow);
    final hooded = PersonalizedTutorialPlacementRules.build(
      _input(eyeShape: EyeShape.hooded, recommendations: [recommendation]),
    ).single;
    final almond = PersonalizedTutorialPlacementRules.build(
      _input(eyeShape: EyeShape.almond, recommendations: [recommendation]),
    ).single;

    expect(hooded.where.description, contains('above the natural crease'));
    expect(almond.where.description, contains('visible lid and crease'));
    expect(hooded.how.technique.value, contains('eye open'));
    expect(hooded.faceAdjustment, isNot(almond.faceAdjustment));
  });

  test(
    'Korean and Full Glam produce different style guidance and intensity',
    () {
      final korean = PersonalizedTutorialPlacementRules.build(
        _input(style: 'korean'),
      ).single;
      final fullGlam = PersonalizedTutorialPlacementRules.build(
        _input(style: 'full_glam'),
      ).single;

      expect(korean.how.intensity, TutorialIntensity.light);
      expect(fullGlam.how.intensity, TutorialIntensity.strong);
      expect(korean.where.regions, {TutorialPlacementRegion.cheekbone});
      expect(fullGlam.where.regions, {TutorialPlacementRegion.cheek});
      expect(korean.where.description, isNot(fullGlam.where.description));
      expect(korean.styleAdjustment, contains('soft, high, and diffused'));
      expect(fullGlam.styleAdjustment, contains('more defined'));
    },
  );

  test(
    'actual recommendation fields drive WHAT, placement text, and color',
    () {
      final step = PersonalizedTutorialPlacementRules.build(_input()).single;

      expect(step.what.productName, 'Recommended product');
      expect(step.what.colorName, 'Peach Rose');
      expect(step.what.colorHex, '#E58C87');
      expect(step.what.finish, 'Satin');
      expect(step.where.description, contains('Recommendation placement'));
      expect(step.where.overlays.first.colorHex, '#E58C87');
    },
  );

  test('kit mode uses owned snapshot product facts only', () {
    final snapshot = TutorialKitProductSnapshot(
      productId: 'owned-1',
      category: TutorialStepCategory.blush,
      productName: 'My Owned Blush',
      colorName: 'Owned Rose',
      colorHex: '#A45B67',
      finish: 'Matte',
    );
    final step = PersonalizedTutorialPlacementRules.build(
      _input(
        sourceMode: TutorialSourceMode.makeupKit,
        kitSnapshots: [snapshot],
      ),
    ).single;

    expect(step.what.kitSnapshot, same(snapshot));
    expect(step.what.productName, 'My Owned Blush');
    expect(step.what.colorName, 'Owned Rose');
    expect(step.what.colorHex, '#A45B67');
    expect(step.what.finish, 'Matte');
    expect(step.where.overlays.first.colorHex, '#A45B67');
  });

  test('kit mode rejects a recommendation without its owned snapshot', () {
    final lipstickSnapshot = TutorialKitProductSnapshot(
      productId: 'owned-lip',
      category: TutorialStepCategory.lipstick,
      colorHex: '#A45B67',
      finish: 'Matte',
    );

    expect(
      () => PersonalizedTutorialPlacementRules.build(
        _input(
          sourceMode: TutorialSourceMode.makeupKit,
          kitSnapshots: [lipstickSnapshot],
        ),
      ),
      throwsArgumentError,
    );
  });
}
