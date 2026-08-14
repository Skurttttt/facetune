import 'package:facetune/features/analysis/domain/entities/analysis_confidence.dart';
import 'package:facetune/features/analysis/domain/entities/facial_attributes.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/personalized_tutorial.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_face_geometry.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_placement_metadata.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_source_mode.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step_category.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/services/personalized_tutorial_metadata_pipeline.dart';
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

const _attributeConfidence = AnalysisConfidence(
  faceShape: 0.91,
  skinTone: 0.88,
  undertone: 0.81,
  eyeShape: 0.89,
  lipShape: 0.86,
  hairColor: 0.94,
  eyeColor: 0.9,
);

TutorialGeometryRegion _region(
  TutorialGeometrySide side,
  List<(double, double)> points,
) => TutorialGeometryRegion(
  side: side,
  boundary: [
    for (final point in points)
      TutorialNormalizedPoint(x: point.$1, y: point.$2),
  ],
);

TutorialBilateralGeometry _pair(double y) => TutorialBilateralGeometry(
  left: _region(TutorialGeometrySide.left, [(0.3, y), (0.4, y)]),
  right: _region(TutorialGeometrySide.right, [(0.6, y), (0.7, y)]),
);

TutorialFaceGeometry _geometry() => TutorialFaceGeometry(
  eyes: _pair(0.38),
  brows: _pair(0.31),
  nose: _region(TutorialGeometrySide.center, [(0.5, 0.42), (0.5, 0.6)]),
  lips: _region(TutorialGeometrySide.center, [(0.42, 0.67), (0.58, 0.67)]),
  forehead: _region(TutorialGeometrySide.center, [(0.4, 0.2), (0.6, 0.2)]),
  cheeks: _pair(0.53),
  jaw: _region(TutorialGeometrySide.center, [(0.3, 0.75), (0.7, 0.75)]),
  chin: _region(TutorialGeometrySide.center, [(0.45, 0.82), (0.55, 0.82)]),
  faceBoundary: _region(TutorialGeometrySide.center, [
    (0.2, 0.15),
    (0.8, 0.15),
    (0.75, 0.85),
    (0.25, 0.85),
  ]),
  confidence: TutorialGeometryConfidence(
    score: 0.87,
    source: TutorialGeometrySource.existingFaceTuneData,
  ),
);

PersonalizedTutorialInput _input() => PersonalizedTutorialInput(
  sourceMode: TutorialSourceMode.standardRecommendation,
  faceAttributes: _attributes,
  attributeConfidence: _attributeConfidence,
  selectedStyle: 'full_glam',
  recommendations: [
    TutorialRecommendationData(
      category: TutorialStepCategory.blush,
      placement: 'Upper outer cheekbones',
      intensity: 'medium',
      technique: 'Tap on and blend.',
      productName: 'Blush',
      colorName: 'Peach Rose',
      colorHex: '#E58C87',
      finish: 'Satin',
      reasoning: 'Complements the warm undertone.',
    ),
  ],
);

void main() {
  test('renders category-specific primitives for every makeup category', () {
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
    final base = _input();
    final input = PersonalizedTutorialInput(
      sourceMode: base.sourceMode,
      faceAttributes: base.faceAttributes,
      attributeConfidence: base.attributeConfidence,
      selectedStyle: base.selectedStyle,
      recommendations: [
        for (final category in categories)
          TutorialRecommendationData(
            category: category,
            placement: 'Personalized ${category.code} placement',
            intensity: 'medium',
            technique: 'Apply precisely.',
            colorHex: '#E58C87',
          ),
      ],
    );
    final output = PersonalizedTutorialMetadataPipeline.build(
      input: input,
      geometry: _geometry(),
    );
    final byCategory = {
      for (final item in output) item.spec.what.category: item.overlayMetadata,
    };

    expect(
      byCategory[TutorialStepCategory.foundation]!.overlays.map((o) => o.type),
      containsAll([
        TutorialPlacementOverlayType.zone,
        TutorialPlacementOverlayType.arrow,
      ]),
    );
    expect(
      byCategory[TutorialStepCategory.concealer]!.overlays.map((o) => o.label),
      containsAll(['underEye', 'nose', 'forehead', 'chin']),
    );
    expect(
      byCategory[TutorialStepCategory.contour]!.overlays.map((o) => o.type),
      containsAll([
        TutorialPlacementOverlayType.zone,
        TutorialPlacementOverlayType.line,
      ]),
    );
    expect(
      byCategory[TutorialStepCategory.blush]!.overlays.map((o) => o.type),
      containsAll([
        TutorialPlacementOverlayType.zone,
        TutorialPlacementOverlayType.arrow,
      ]),
    );
    expect(
      byCategory[TutorialStepCategory.highlighter]!.overlays
          .where((o) => o.label == 'cheekbone')
          .every((o) => o.type == TutorialPlacementOverlayType.dot),
      isTrue,
    );
    expect(
      byCategory[TutorialStepCategory.eyeshadow]!.overlays.map((o) => o.label),
      containsAll(['eyelid', 'crease', 'outerEye', 'innerEye']),
    );
    expect(
      byCategory[TutorialStepCategory.eyeliner]!.overlays.map((o) => o.label),
      containsAll(['lashLine', 'outerEye']),
    );
    expect(
      byCategory[TutorialStepCategory.eyebrow]!.overlays.every(
        (o) => o.type == TutorialPlacementOverlayType.arrow,
      ),
      isTrue,
    );
    expect(
      byCategory[TutorialStepCategory.lipstick]!.overlays.single.type,
      TutorialPlacementOverlayType.boundary,
    );
    expect(
      byCategory[TutorialStepCategory.lipGloss]!.overlays.single.type,
      TutorialPlacementOverlayType.zone,
    );
    for (final metadata in byCategory.values) {
      expect(metadata.overlays, isNotEmpty);
      expect(
        metadata.overlays
            .where((overlay) => overlay.colorHex != null)
            .every((overlay) => overlay.colorHex == '#E58C87'),
        isTrue,
      );
    }
  });

  test('projects text, overlay, and Gemini input from the same step spec', () {
    final output = PersonalizedTutorialMetadataPipeline.build(
      input: _input(),
      geometry: _geometry(),
    ).single;
    final spec = output.spec;
    final text = output.writtenInstruction;
    final overlay = output.overlayMetadata;
    final gemini = output.geminiPromptInput;

    expect(text.category, spec.what.category);
    expect(text.productName, spec.what.productName);
    expect(text.colorName, spec.what.colorName);
    expect(text.hex, spec.what.colorHex);
    expect(text.finish, spec.what.finish);
    expect(text.placement, spec.where.description);
    expect(text.direction, spec.how.direction.name);
    expect(text.intensity, spec.how.intensity.name);
    expect(text.technique, spec.how.technique.value);
    expect(text.tip, contains(spec.faceAdjustment!));
    expect(text.tip, contains(spec.styleAdjustment!));

    expect(gemini['category'], spec.what.category.code);
    expect(gemini['product'], spec.what.productName);
    expect(gemini['colorHex'], spec.what.colorHex);
    expect(gemini['finish'], spec.what.finish);
    expect(gemini['placement'], spec.where.description);
    expect(gemini['side'], spec.where.side.name);
    expect(gemini['direction'], spec.how.direction.name);
    expect(gemini['intensity'], spec.how.intensity.name);
    expect(gemini['technique'], spec.how.technique.value);
    expect(gemini['faceAdjustment'], spec.faceAdjustment);
    expect(gemini['styleAdjustment'], spec.styleAdjustment);
    expect(gemini['placementConfidence'], spec.where.placementConfidence.name);

    expect(spec.where.geometryAnchors, isNotEmpty);
    expect(spec.where.geometryConfidence, TutorialPlacementConfidence.high);
    expect(gemini['geometryConfidence'], 'high');
    expect(gemini['geometryAnchors'], isNotEmpty);
    expect(overlay.overlays, isNotEmpty);
    expect(overlay.overlays.any((item) => item.colorHex == '#E58C87'), isTrue);
    expect(overlay.overlays.any((item) => item.colorHex == null), isTrue);
    expect(
      overlay.overlays
          .expand((item) => item.points)
          .every(
            (point) =>
                point.x >= 0 && point.x <= 1 && point.y >= 0 && point.y <= 1,
          ),
      isTrue,
    );
  });

  test('without real geometry emits no fabricated anchors or overlays', () {
    final output = PersonalizedTutorialMetadataPipeline.build(
      input: _input(),
    ).single;

    expect(output.spec.where.geometryAnchors, isEmpty);
    expect(
      output.spec.where.geometryConfidence,
      TutorialPlacementConfidence.unavailable,
    );
    expect(output.overlayMetadata.overlays, isEmpty);
    expect(output.geminiPromptInput['geometryAnchors'], isEmpty);
  });

  test('kit prompt projection contains only owned snapshot product facts', () {
    final snapshot = TutorialKitProductSnapshot(
      productId: 'owned-1',
      category: TutorialStepCategory.blush,
      productName: 'My Blush',
      colorName: 'Owned Rose',
      colorHex: '#A45B67',
      finish: 'Matte',
    );
    final standard = _input();
    final input = PersonalizedTutorialInput(
      sourceMode: TutorialSourceMode.makeupKit,
      faceAttributes: standard.faceAttributes,
      attributeConfidence: standard.attributeConfidence,
      selectedStyle: standard.selectedStyle,
      recommendations: standard.recommendations,
      kitSnapshots: [snapshot],
    );
    final output = PersonalizedTutorialMetadataPipeline.build(
      input: input,
      geometry: _geometry(),
    ).single;

    expect(output.writtenInstruction.productName, 'My Blush');
    expect(output.writtenInstruction.hex, '#A45B67');
    expect(output.geminiPromptInput['kitProductId'], 'owned-1');
    expect(output.geminiPromptInput['product'], 'My Blush');
    expect(output.geminiPromptInput['colorHex'], '#A45B67');
    expect(output.geminiPromptInput['finish'], 'Matte');
  });
}
