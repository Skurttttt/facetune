import 'package:facetune/features/step_by_step_tutorial/domain/entities/personalized_tutorial.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_face_geometry.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_placement_metadata.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step_category.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/services/personalized_tutorial_overlay_accuracy_validator.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/services/personalized_tutorial_overlay_metadata_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

PersonalizedTutorialGeometryAnchor _anchor({
  required TutorialGeometrySide side,
  required double x,
  double y = 0.52,
  TutorialPlacementRegion region = TutorialPlacementRegion.cheekbone,
  double halfWidth = 0.04,
}) => PersonalizedTutorialGeometryAnchor(
  region: region,
  side: side,
  points: [
    TutorialNormalizedPoint(x: x - halfWidth, y: y),
    TutorialNormalizedPoint(x: x + halfWidth, y: y),
  ],
);

PersonalizedTutorialStepSpec _spec({
  TutorialStepCategory category = TutorialStepCategory.blush,
  TutorialPlacementRegion region = TutorialPlacementRegion.cheekbone,
  TutorialPlacementConfidence confidence = TutorialPlacementConfidence.high,
  TutorialDirection direction = TutorialDirection.upwardOutward,
  TutorialPlacementOverlayType type = TutorialPlacementOverlayType.zone,
  List<PersonalizedTutorialGeometryAnchor>? anchors,
}) => PersonalizedTutorialStepSpec(
  stepNumber: 1,
  what: PersonalizedTutorialWhat(category: category, colorHex: '#E58C87'),
  where: PersonalizedTutorialWhere(
    description: 'Personalized placement',
    regions: {region},
    side: TutorialPlacementSide.bilateral,
    geometryConfidence: confidence,
    placementConfidence: TutorialPlacementConfidence.high,
    overlays: [
      PersonalizedTutorialOverlay(
        type: type,
        region: region,
        colorHex: '#E58C87',
      ),
    ],
    geometryAnchors:
        anchors ??
        [
          _anchor(side: TutorialGeometrySide.left, x: 0.35, region: region),
          _anchor(side: TutorialGeometrySide.right, x: 0.65, region: region),
        ],
  ),
  how: PersonalizedTutorialHow(
    direction: direction,
    intensity: TutorialIntensity.medium,
    technique: TutorialTechnique('Blend softly.'),
  ),
);

void main() {
  test('high confidence preserves precise validated overlays', () {
    final spec = _spec(type: TutorialPlacementOverlayType.line);
    final result = PersonalizedTutorialOverlayAccuracyValidator.validate(spec);

    expect(result.canRender, isTrue);
    expect(result.renderableSpec, same(spec));
    expect(result.usedMediumConfidenceFallback, isFalse);
    expect(
      PersonalizedTutorialOverlayMetadataRenderer.build(spec).overlays.every(
        (overlay) => overlay.type == TutorialPlacementOverlayType.line,
      ),
      isTrue,
    );
  });

  test(
    'medium confidence broadens anchors and replaces precise line with zone',
    () {
      final spec = _spec(
        confidence: TutorialPlacementConfidence.medium,
        type: TutorialPlacementOverlayType.line,
      );
      final original = spec.where.geometryAnchors.first;
      final result = PersonalizedTutorialOverlayAccuracyValidator.validate(
        spec,
      );
      final fallback = result.renderableSpec!;
      final broadened = fallback.where.geometryAnchors.first;

      expect(result.usedMediumConfidenceFallback, isTrue);
      expect(
        fallback.where.overlays.single.type,
        TutorialPlacementOverlayType.zone,
      );
      expect(
        broadened.points.last.x - broadened.points.first.x,
        greaterThan(original.points.last.x - original.points.first.x),
      );
      expect(
        PersonalizedTutorialOverlayMetadataRenderer.build(spec).overlays.every(
          (overlay) => overlay.type == TutorialPlacementOverlayType.zone,
        ),
        isTrue,
      );
    },
  );

  test('low confidence draws nothing and prioritizes written guidance', () {
    final spec = _spec(confidence: TutorialPlacementConfidence.low);
    final result = PersonalizedTutorialOverlayAccuracyValidator.validate(spec);

    expect(result.canRender, isFalse);
    expect(
      result.issues,
      contains(TutorialOverlayValidationIssue.confidenceTooLow),
    );
    expect(
      PersonalizedTutorialOverlayMetadataRenderer.build(spec).overlays,
      isEmpty,
    );
    expect(spec.where.description, isNotEmpty);
  });

  test('rejects category-region incompatibility', () {
    final spec = _spec(
      region: TutorialPlacementRegion.lips,
      anchors: [
        _anchor(
          side: TutorialGeometrySide.center,
          x: 0.5,
          y: 0.68,
          region: TutorialPlacementRegion.lips,
        ),
      ],
    );
    final result = PersonalizedTutorialOverlayAccuracyValidator.validate(spec);

    expect(result.canRender, isFalse);
    expect(
      result.issues,
      contains(TutorialOverlayValidationIssue.incompatibleRegion),
    );
  });

  test('rejects incorrect side and cheek geometry outside cheek proximity', () {
    final result = PersonalizedTutorialOverlayAccuracyValidator.validate(
      _spec(
        anchors: [
          _anchor(side: TutorialGeometrySide.left, x: 0.7, y: 0.2),
          _anchor(side: TutorialGeometrySide.right, x: 0.8, y: 0.2),
        ],
      ),
    );

    expect(result.canRender, isFalse);
    expect(
      result.issues,
      contains(TutorialOverlayValidationIssue.incorrectSide),
    );
    expect(
      result.issues,
      contains(TutorialOverlayValidationIssue.implausibleProximity),
    );
  });

  test('rejects oversized and incomplete bilateral geometry', () {
    final result = PersonalizedTutorialOverlayAccuracyValidator.validate(
      _spec(
        anchors: [
          _anchor(side: TutorialGeometrySide.left, x: 0.3, halfWidth: 0.3),
        ],
      ),
    );

    expect(result.canRender, isFalse);
    expect(
      result.issues,
      contains(TutorialOverlayValidationIssue.implausibleSize),
    );
    expect(
      result.issues,
      contains(TutorialOverlayValidationIssue.inconsistentBilateralGeometry),
    );
  });

  test('rejects an arrow without a plausible direction', () {
    final result = PersonalizedTutorialOverlayAccuracyValidator.validate(
      _spec(
        type: TutorialPlacementOverlayType.arrow,
        direction: TutorialDirection.none,
      ),
    );

    expect(result.canRender, isFalse);
    expect(
      result.issues,
      contains(TutorialOverlayValidationIssue.implausibleArrow),
    );
  });

  test('normalized point model rejects malformed bounds before validation', () {
    expect(() => TutorialNormalizedPoint(x: 1.01, y: 0.5), throwsArgumentError);
    expect(
      () => TutorialNormalizedPoint(x: 0.5, y: double.nan),
      throwsArgumentError,
    );
  });
}
