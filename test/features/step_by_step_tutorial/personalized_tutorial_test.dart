import 'package:facetune/features/analysis/domain/entities/analysis_confidence.dart';
import 'package:facetune/features/analysis/domain/entities/facial_attributes.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/personalized_tutorial.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_placement_metadata.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_source_mode.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step_category.dart';
import 'package:flutter_test/flutter_test.dart';

const _attributes = FacialAttributes(
  faceShape: FaceShape.round,
  skinTone: SkinTone.medium,
  undertone: Undertone.warm,
  eyeShape: EyeShape.hooded,
  lipShape: LipShape.full,
  hairColor: HairColor.darkBrown,
  eyeColor: EyeColor.brown,
);

const _confidence = AnalysisConfidence(
  faceShape: 0.9,
  skinTone: 0.8,
  undertone: 0.7,
  eyeShape: 0.85,
  lipShape: 0.75,
  hairColor: 0.95,
  eyeColor: 0.88,
);

TutorialRecommendationData _recommendation() => TutorialRecommendationData(
  category: TutorialStepCategory.blush,
  placement: 'Upper outer cheekbones',
  intensity: 'medium',
  technique: 'Blend upward toward the temples.',
  colorName: 'Peach Rose',
  colorHex: '#E58C87',
  finish: 'Satin',
);

void main() {
  group('PersonalizedTutorialInput', () {
    test('represents all face attributes, style, and recommendation data', () {
      final input = PersonalizedTutorialInput(
        sourceMode: TutorialSourceMode.standardRecommendation,
        faceAttributes: _attributes,
        attributeConfidence: _confidence,
        selectedStyle: 'full_glam',
        recommendations: [_recommendation()],
      );

      expect(input.faceAttributes.faceShape, FaceShape.round);
      expect(input.faceAttributes.skinTone, SkinTone.medium);
      expect(input.faceAttributes.undertone, Undertone.warm);
      expect(input.faceAttributes.eyeShape, EyeShape.hooded);
      expect(input.faceAttributes.lipShape, LipShape.full);
      expect(input.faceAttributes.hairColor, HairColor.darkBrown);
      expect(input.faceAttributes.eyeColor, EyeColor.brown);
      expect(input.selectedStyle, 'full_glam');
      expect(input.kitSnapshots, isEmpty);
    });

    test('kit mode requires and retains an immutable product snapshot', () {
      final snapshot = TutorialKitProductSnapshot(
        productId: 'product-1',
        category: TutorialStepCategory.blush,
        productName: 'My Blush',
        colorName: 'Peach Rose',
        colorHex: '#E58C87',
        finish: 'Satin',
      );
      final input = PersonalizedTutorialInput(
        sourceMode: TutorialSourceMode.makeupKit,
        faceAttributes: _attributes,
        attributeConfidence: _confidence,
        selectedStyle: 'natural',
        recommendations: [_recommendation()],
        kitSnapshots: [snapshot],
      );

      expect(input.kitSnapshots.single.productId, 'product-1');
      expect(() => input.kitSnapshots.add(snapshot), throwsUnsupportedError);
    });

    test(
      'rejects blank style, empty recommendations, and invalid source data',
      () {
        expect(
          () => PersonalizedTutorialInput(
            sourceMode: TutorialSourceMode.standardRecommendation,
            faceAttributes: _attributes,
            attributeConfidence: _confidence,
            selectedStyle: ' ',
            recommendations: [_recommendation()],
          ),
          throwsArgumentError,
        );
        expect(
          () => PersonalizedTutorialInput(
            sourceMode: TutorialSourceMode.makeupKit,
            faceAttributes: _attributes,
            attributeConfidence: _confidence,
            selectedStyle: 'natural',
            recommendations: const [],
          ),
          throwsArgumentError,
        );
        expect(
          () => PersonalizedTutorialInput(
            sourceMode: TutorialSourceMode.makeupKit,
            faceAttributes: _attributes,
            attributeConfidence: _confidence,
            selectedStyle: 'natural',
            recommendations: [_recommendation()],
          ),
          throwsArgumentError,
        );
      },
    );

    test('rejects facial-attribute confidence outside normalized bounds', () {
      const invalidConfidence = AnalysisConfidence(
        faceShape: 1.1,
        skinTone: 0.8,
        undertone: 0.7,
        eyeShape: 0.85,
        lipShape: 0.75,
        hairColor: 0.95,
        eyeColor: 0.88,
      );

      expect(
        () => PersonalizedTutorialInput(
          sourceMode: TutorialSourceMode.standardRecommendation,
          faceAttributes: _attributes,
          attributeConfidence: invalidConfidence,
          selectedStyle: 'natural',
          recommendations: [_recommendation()],
        ),
        throwsArgumentError,
      );
    });
  });

  group('PersonalizedTutorialStepSpec', () {
    test('separates WHAT, WHERE, HOW, and adjustments', () {
      final spec = PersonalizedTutorialStepSpec(
        stepNumber: 4,
        what: PersonalizedTutorialWhat(
          category: TutorialStepCategory.blush,
          colorName: 'Peach Rose',
          colorHex: '#E58C87',
          finish: 'Satin',
        ),
        where: PersonalizedTutorialWhere(
          description: 'Upper outer cheekbones',
          regions: const {TutorialPlacementRegion.cheekbone},
          side: TutorialPlacementSide.bilateral,
          geometryConfidence: TutorialPlacementConfidence.unavailable,
          placementConfidence: TutorialPlacementConfidence.high,
          overlays: [
            PersonalizedTutorialOverlay(
              type: TutorialPlacementOverlayType.zone,
              region: TutorialPlacementRegion.cheekbone,
              colorHex: '#E58C87',
            ),
          ],
        ),
        how: PersonalizedTutorialHow(
          direction: TutorialDirection.upwardOutward,
          intensity: TutorialIntensity.medium,
          technique: TutorialTechnique('Blend with a soft brush.'),
        ),
        faceAdjustment: 'Lift placement for a round face.',
        styleAdjustment: 'Use stronger color for Full Glam.',
      );

      expect(spec.what.category, TutorialStepCategory.blush);
      expect(spec.where.side, TutorialPlacementSide.bilateral);
      expect(spec.how.direction, TutorialDirection.upwardOutward);
      expect(spec.where.overlays.single.colorHex, '#E58C87');
    });

    test('allows genuinely unavailable optional product values', () {
      final what = PersonalizedTutorialWhat(
        category: TutorialStepCategory.eyeliner,
      );

      expect(what.productName, isNull);
      expect(what.colorName, isNull);
      expect(what.colorHex, isNull);
      expect(what.finish, isNull);
      expect(what.kitSnapshot, isNull);
    });

    test('rejects invalid HEX, step number, and undeclared overlay region', () {
      expect(
        () => PersonalizedTutorialWhat(
          category: TutorialStepCategory.blush,
          colorHex: '#e58c87',
        ),
        throwsArgumentError,
      );
      expect(
        () => PersonalizedTutorialWhere(
          description: 'Cheeks',
          regions: const {TutorialPlacementRegion.cheek},
          side: TutorialPlacementSide.bilateral,
          geometryConfidence: TutorialPlacementConfidence.unavailable,
          placementConfidence: TutorialPlacementConfidence.high,
          overlays: [
            PersonalizedTutorialOverlay(
              type: TutorialPlacementOverlayType.line,
              region: TutorialPlacementRegion.lips,
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => PersonalizedTutorialStepSpec(
          stepNumber: 0,
          what: PersonalizedTutorialWhat(category: TutorialStepCategory.blush),
          where: PersonalizedTutorialWhere(
            description: 'Cheeks',
            regions: const {TutorialPlacementRegion.cheek},
            side: TutorialPlacementSide.bilateral,
            geometryConfidence: TutorialPlacementConfidence.unavailable,
            placementConfidence: TutorialPlacementConfidence.low,
            overlays: [
              PersonalizedTutorialOverlay(
                type: TutorialPlacementOverlayType.zone,
                region: TutorialPlacementRegion.cheek,
              ),
            ],
          ),
          how: PersonalizedTutorialHow(
            direction: TutorialDirection.outward,
            intensity: TutorialIntensity.light,
            technique: TutorialTechnique('Blend.'),
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}
