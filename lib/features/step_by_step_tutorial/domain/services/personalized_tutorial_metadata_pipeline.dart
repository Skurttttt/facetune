import '../entities/personalized_tutorial.dart';
import '../entities/tutorial_face_geometry.dart';
import '../entities/tutorial_instruction.dart';
import '../entities/tutorial_placement_metadata.dart';
import 'personalized_tutorial_placement_rules.dart';
import 'personalized_tutorial_overlay_metadata_renderer.dart';

class PersonalizedTutorialStepMetadata {
  const PersonalizedTutorialStepMetadata({
    required this.spec,
    required this.writtenInstruction,
    required this.overlayMetadata,
    required this.geminiPromptInput,
  });

  final PersonalizedTutorialStepSpec spec;
  final TutorialInstruction writtenInstruction;
  final TutorialPlacementMetadata overlayMetadata;
  final Map<String, Object?> geminiPromptInput;
}

/// Canonical recommendation-to-placement pipeline.
///
/// The step spec is the sole interpretation point. Written text, FaceTune
/// overlays, and Gemini input below are projections; none independently decide
/// product, placement, direction, intensity, or adjustments.
abstract final class PersonalizedTutorialMetadataPipeline {
  static List<PersonalizedTutorialStepMetadata> build({
    required PersonalizedTutorialInput input,
    TutorialFaceGeometry? geometry,
  }) => List.unmodifiable([
    for (final baseSpec in PersonalizedTutorialPlacementRules.build(input))
      _project(_withGeometry(baseSpec, geometry)),
  ]);

  static PersonalizedTutorialStepMetadata _project(
    PersonalizedTutorialStepSpec spec,
  ) => PersonalizedTutorialStepMetadata(
    spec: spec,
    writtenInstruction: _instruction(spec),
    overlayMetadata: PersonalizedTutorialOverlayMetadataRenderer.build(spec),
    geminiPromptInput: Map.unmodifiable(_geminiInput(spec)),
  );

  static PersonalizedTutorialStepSpec _withGeometry(
    PersonalizedTutorialStepSpec spec,
    TutorialFaceGeometry? geometry,
  ) {
    if (geometry == null) return spec;
    final anchors = <PersonalizedTutorialGeometryAnchor>[
      for (final region in spec.where.regions) ..._anchorsFor(region, geometry),
    ];
    return PersonalizedTutorialStepSpec(
      stepNumber: spec.stepNumber,
      what: spec.what,
      where: PersonalizedTutorialWhere(
        description: spec.where.description,
        regions: spec.where.regions,
        side: spec.where.side,
        geometryConfidence: _confidence(geometry.confidence.score),
        placementConfidence: spec.where.placementConfidence,
        overlays: spec.where.overlays,
        geometryAnchors: anchors,
      ),
      how: spec.how,
      faceAdjustment: spec.faceAdjustment,
      styleAdjustment: spec.styleAdjustment,
    );
  }

  static TutorialInstruction _instruction(PersonalizedTutorialStepSpec spec) =>
      TutorialInstruction(
        category: spec.what.category,
        productName: spec.what.productName,
        colorName: spec.what.colorName,
        hex: spec.what.colorHex,
        finish: spec.what.finish,
        placement: spec.where.description,
        direction: spec.how.direction.name,
        intensity: spec.how.intensity.name,
        technique: spec.how.technique.value,
        tip: _combinedTip(spec),
      );

  static String? _combinedTip(PersonalizedTutorialStepSpec spec) {
    final parts = [
      spec.how.tip,
      spec.faceAdjustment,
      spec.styleAdjustment,
    ].whereType<String>().toList(growable: false);
    return parts.isEmpty ? null : parts.join(' ');
  }

  static Map<String, Object?> _geminiInput(PersonalizedTutorialStepSpec spec) =>
      {
        'stepNumber': spec.stepNumber,
        'category': spec.what.category.code,
        'product': spec.what.productName,
        'kitProductId': spec.what.kitSnapshot?.productId,
        'colorName': spec.what.colorName,
        'colorHex': spec.what.colorHex,
        'finish': spec.what.finish,
        'placement': spec.where.description,
        'regions': spec.where.regions.map((region) => region.name).toList(),
        'side': spec.where.side.name,
        'direction': spec.how.direction.name,
        'intensity': spec.how.intensity.name,
        'technique': spec.how.technique.value,
        'tip': spec.how.tip,
        'faceAdjustment': spec.faceAdjustment,
        'styleAdjustment': spec.styleAdjustment,
        'geometryConfidence': spec.where.geometryConfidence.name,
        'placementConfidence': spec.where.placementConfidence.name,
        'geometryAnchors': [
          for (final anchor in spec.where.geometryAnchors)
            {
              'region': anchor.region.name,
              'side': anchor.side.name,
              'points': [
                for (final point in anchor.points) {'x': point.x, 'y': point.y},
              ],
            },
        ],
      };

  static List<PersonalizedTutorialGeometryAnchor> _anchorsFor(
    TutorialPlacementRegion region,
    TutorialFaceGeometry geometry,
  ) {
    if (region == TutorialPlacementRegion.temple) {
      final left = geometry.faceBoundary.boundary
          .where((point) => point.x < 0.5 && point.y <= 0.6)
          .toList(growable: false);
      final right = geometry.faceBoundary.boundary
          .where((point) => point.x > 0.5 && point.y <= 0.6)
          .toList(growable: false);
      return [
        if (left.isNotEmpty)
          PersonalizedTutorialGeometryAnchor(
            region: region,
            side: TutorialGeometrySide.left,
            points: left,
          ),
        if (right.isNotEmpty)
          PersonalizedTutorialGeometryAnchor(
            region: region,
            side: TutorialGeometrySide.right,
            points: right,
          ),
      ];
    }
    final source = switch (region) {
      TutorialPlacementRegion.fullFace => [geometry.faceBoundary],
      TutorialPlacementRegion.forehead => [geometry.forehead],
      TutorialPlacementRegion.underEye ||
      TutorialPlacementRegion.eyelid ||
      TutorialPlacementRegion.crease ||
      TutorialPlacementRegion.innerEye ||
      TutorialPlacementRegion.outerEye ||
      TutorialPlacementRegion.lashLine => [
        geometry.eyes.left,
        geometry.eyes.right,
      ],
      TutorialPlacementRegion.brow => [
        geometry.brows.left,
        geometry.brows.right,
      ],
      TutorialPlacementRegion.temple => throw StateError('Handled above.'),
      TutorialPlacementRegion.cheek || TutorialPlacementRegion.cheekbone => [
        geometry.cheeks.left,
        geometry.cheeks.right,
      ],
      TutorialPlacementRegion.nose => [geometry.nose],
      TutorialPlacementRegion.jaw => [geometry.jaw],
      TutorialPlacementRegion.chin => [geometry.chin],
      TutorialPlacementRegion.lips => [geometry.lips],
    };
    return [
      for (final item in source)
        PersonalizedTutorialGeometryAnchor(
          region: region,
          side: item.side,
          points: item.boundary,
        ),
    ];
  }

  static TutorialPlacementConfidence _confidence(double score) {
    if (score >= 0.8) return TutorialPlacementConfidence.high;
    if (score >= 0.55) return TutorialPlacementConfidence.medium;
    return TutorialPlacementConfidence.low;
  }
}
