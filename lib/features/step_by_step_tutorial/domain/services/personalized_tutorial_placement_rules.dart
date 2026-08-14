import '../../../analysis/domain/entities/facial_attributes.dart';
import '../entities/personalized_tutorial.dart';
import '../entities/tutorial_placement_metadata.dart';
import '../entities/tutorial_source_mode.dart';
import '../entities/tutorial_step_category.dart';

/// Pure, deterministic tutorial placement policy.
///
/// It combines semantic face attributes, selected style, and the actual
/// recommendation (or immutable owned-product snapshot). It emits domain
/// metadata only: no widgets, pixels, persistence, or AI calls.
abstract final class PersonalizedTutorialPlacementRules {
  static List<PersonalizedTutorialStepSpec> build(
    PersonalizedTutorialInput input,
  ) => List.unmodifiable([
    for (final (index, recommendation) in input.recommendations.indexed)
      _buildStep(input, recommendation, index + 1),
  ]);

  static PersonalizedTutorialStepSpec _buildStep(
    PersonalizedTutorialInput input,
    TutorialRecommendationData recommendation,
    int stepNumber,
  ) {
    if (recommendation.category == TutorialStepCategory.finalLook) {
      throw ArgumentError.value(
        recommendation.category,
        'recommendation.category',
        'Final look is not an application placement step.',
      );
    }
    final rule = _applyStylePlacement(
      _ruleFor(input.faceAttributes, recommendation.category),
      input.selectedStyle,
      recommendation.category,
    );
    final kitSnapshot = _kitSnapshot(input, recommendation.category);
    final style = _stylePolicy(input.selectedStyle, recommendation.category);
    final intensity = _intensity(recommendation.intensity, style.adjustment);
    final placementConfidence = _placementConfidence(
      input,
      recommendation.category,
    );
    final colorHex = kitSnapshot?.colorHex ?? recommendation.colorHex;

    return PersonalizedTutorialStepSpec(
      stepNumber: stepNumber,
      what: PersonalizedTutorialWhat(
        category: recommendation.category,
        productName: kitSnapshot == null
            ? recommendation.productName
            : kitSnapshot.productName,
        colorName: kitSnapshot == null
            ? recommendation.colorName
            : kitSnapshot.colorName,
        colorHex: colorHex,
        finish: kitSnapshot == null
            ? recommendation.finish
            : kitSnapshot.finish,
        kitSnapshot: kitSnapshot,
      ),
      where: PersonalizedTutorialWhere(
        description:
            '${rule.description} Recommendation: '
            '${recommendation.placement}',
        regions: rule.regions,
        side: rule.side,
        geometryConfidence: TutorialPlacementConfidence.unavailable,
        placementConfidence: placementConfidence,
        overlays: [
          for (final overlay in rule.overlays)
            PersonalizedTutorialOverlay(
              type: overlay.type,
              region: overlay.region,
              colorHex: overlay.productColored ? colorHex : null,
            ),
        ],
      ),
      how: PersonalizedTutorialHow(
        direction: rule.direction,
        intensity: intensity,
        technique: TutorialTechnique(
          '${recommendation.technique} ${rule.techniqueAdjustment}'.trim(),
        ),
        tip: recommendation.reasoning,
      ),
      faceAdjustment: rule.faceAdjustment,
      styleAdjustment: style.description,
    );
  }

  static TutorialKitProductSnapshot? _kitSnapshot(
    PersonalizedTutorialInput input,
    TutorialStepCategory category,
  ) {
    if (input.sourceMode == TutorialSourceMode.standardRecommendation) {
      return null;
    }
    final matches = input.kitSnapshots
        .where((snapshot) => snapshot.category == category)
        .toList(growable: false);
    if (matches.length != 1) {
      throw ArgumentError.value(
        matches,
        'kitSnapshots',
        'Kit placement requires exactly one owned snapshot for '
            '${category.code}.',
      );
    }
    return matches.single;
  }

  static _PlacementRule _ruleFor(
    FacialAttributes attributes,
    TutorialStepCategory category,
  ) => switch (category) {
    TutorialStepCategory.foundation => const _PlacementRule(
      description: 'Use broad, even coverage across the full face.',
      regions: {TutorialPlacementRegion.fullFace},
      side: TutorialPlacementSide.full,
      direction: TutorialDirection.outward,
      overlays: [
        _OverlayRule(
          TutorialPlacementOverlayType.zone,
          TutorialPlacementRegion.fullFace,
          productColored: true,
        ),
        _OverlayRule(
          TutorialPlacementOverlayType.arrow,
          TutorialPlacementRegion.fullFace,
        ),
      ],
      techniqueAdjustment: 'Work outward in thin layers.',
      faceAdjustment:
          'Preserve the detected face shape; coverage does not reshape it.',
    ),
    TutorialStepCategory.concealer => _concealer(attributes.eyeShape),
    TutorialStepCategory.contour => _contour(attributes.faceShape),
    TutorialStepCategory.blush => _blush(attributes.faceShape),
    TutorialStepCategory.highlighter => _highlighter(attributes.faceShape),
    TutorialStepCategory.eyeshadow => _eyeshadow(attributes.eyeShape),
    TutorialStepCategory.eyeliner => _eyeliner(attributes.eyeShape),
    TutorialStepCategory.eyebrow => _brows(attributes.eyeShape),
    TutorialStepCategory.lipstick => _lips(attributes.lipShape, false),
    TutorialStepCategory.lipGloss => _lips(attributes.lipShape, true),
    TutorialStepCategory.finalLook => throw StateError('Handled above.'),
  };

  static _PlacementRule _applyStylePlacement(
    _PlacementRule base,
    String style,
    TutorialStepCategory category,
  ) {
    final normalized = style.trim().toLowerCase();
    if (normalized == 'korean' && category == TutorialStepCategory.blush) {
      return base.copyWith(
        description:
            'Keep blush high on the upper cheeks with a soft, diffused edge.',
        regions: const {TutorialPlacementRegion.cheekbone},
        direction: TutorialDirection.upwardOutward,
        overlays: const [
          _OverlayRule(
            TutorialPlacementOverlayType.zone,
            TutorialPlacementRegion.cheekbone,
            productColored: true,
          ),
          _OverlayRule(
            TutorialPlacementOverlayType.arrow,
            TutorialPlacementRegion.cheekbone,
          ),
        ],
      );
    }
    if (normalized == 'korean' && category == TutorialStepCategory.eyeliner) {
      return base.copyWith(
        description:
            'Keep a thin lash-line path with a short, subtle outer extension.',
      );
    }
    return base;
  }

  static _PlacementRule _concealer(EyeShape shape) => _PlacementRule(
    description: shape == EyeShape.deepSet
        ? 'Target the inner under-eye and shadowed transition; avoid a heavy outer triangle.'
        : 'Target the under-eyes, nose center, forehead center, and chin only where needed.',
    regions: const {
      TutorialPlacementRegion.underEye,
      TutorialPlacementRegion.nose,
      TutorialPlacementRegion.forehead,
      TutorialPlacementRegion.chin,
    },
    side: TutorialPlacementSide.bilateral,
    direction: TutorialDirection.outward,
    overlays: const [
      _OverlayRule(
        TutorialPlacementOverlayType.zone,
        TutorialPlacementRegion.underEye,
        productColored: true,
      ),
      _OverlayRule(
        TutorialPlacementOverlayType.zone,
        TutorialPlacementRegion.nose,
        productColored: true,
      ),
      _OverlayRule(
        TutorialPlacementOverlayType.zone,
        TutorialPlacementRegion.forehead,
        productColored: true,
      ),
      _OverlayRule(
        TutorialPlacementOverlayType.zone,
        TutorialPlacementRegion.chin,
        productColored: true,
      ),
    ],
    techniqueAdjustment: 'Keep each correction localized and softly diffused.',
    faceAdjustment: 'Under-eye targeting accounts for ${shape.name} eyes.',
  );

  static _PlacementRule _contour(FaceShape shape) {
    final description = switch (shape) {
      FaceShape.round =>
        'Use narrow temple and under-cheekbone bands with light jaw definition to create lift.',
      FaceShape.oblong =>
        'Concentrate softly at the forehead edge and chin; keep cheek bands horizontal.',
      FaceShape.square =>
        'Soften the forehead corners and jaw angles with short diffused bands.',
      FaceShape.heart =>
        'Balance the temples and lightly define beneath the cheekbones; minimize the chin.',
      _ =>
        'Follow the natural temples, cheekbones, and jaw with narrow soft bands.',
    };
    return _PlacementRule(
      description: description,
      regions: const {
        TutorialPlacementRegion.temple,
        TutorialPlacementRegion.cheekbone,
        TutorialPlacementRegion.jaw,
      },
      side: TutorialPlacementSide.bilateral,
      direction: shape == FaceShape.oblong
          ? TutorialDirection.horizontal
          : TutorialDirection.upwardOutward,
      overlays: const [
        _OverlayRule(
          TutorialPlacementOverlayType.zone,
          TutorialPlacementRegion.temple,
          productColored: true,
        ),
        _OverlayRule(
          TutorialPlacementOverlayType.zone,
          TutorialPlacementRegion.cheekbone,
          productColored: true,
        ),
        _OverlayRule(
          TutorialPlacementOverlayType.line,
          TutorialPlacementRegion.jaw,
          productColored: true,
        ),
      ],
      techniqueAdjustment: 'Diffuse every edge without widening the bands.',
      faceAdjustment: 'Contour pattern is adjusted for a ${shape.name} face.',
    );
  }

  static _PlacementRule _blush(FaceShape shape) {
    final isRound = shape == FaceShape.round;
    return _PlacementRule(
      description: isRound
          ? 'Place color high on the outer cheekbones, away from the center, to emphasize lift.'
          : 'Place color across the upper cheeks and blend softly toward the temples.',
      regions: {
        isRound
            ? TutorialPlacementRegion.cheekbone
            : TutorialPlacementRegion.cheek,
      },
      side: TutorialPlacementSide.bilateral,
      direction: isRound
          ? TutorialDirection.upwardOutward
          : TutorialDirection.outward,
      overlays: [
        _OverlayRule(
          TutorialPlacementOverlayType.zone,
          isRound
              ? TutorialPlacementRegion.cheekbone
              : TutorialPlacementRegion.cheek,
          productColored: true,
        ),
        _OverlayRule(
          TutorialPlacementOverlayType.arrow,
          isRound
              ? TutorialPlacementRegion.cheekbone
              : TutorialPlacementRegion.cheek,
        ),
      ],
      techniqueAdjustment: 'Build the recommended color gradually.',
      faceAdjustment: 'Blush placement is adjusted for a ${shape.name} face.',
    );
  }

  static _PlacementRule _highlighter(FaceShape shape) => _PlacementRule(
    description: shape == FaceShape.round
        ? 'Keep highlight narrow on the upper cheekbones, nose, and chin for vertical definition.'
        : 'Use small highlight zones on the upper cheekbones, nose, forehead, and chin.',
    regions: const {
      TutorialPlacementRegion.cheekbone,
      TutorialPlacementRegion.nose,
      TutorialPlacementRegion.forehead,
      TutorialPlacementRegion.chin,
    },
    side: TutorialPlacementSide.bilateral,
    direction: TutorialDirection.upwardOutward,
    overlays: const [
      _OverlayRule(
        TutorialPlacementOverlayType.dot,
        TutorialPlacementRegion.cheekbone,
        productColored: true,
      ),
      _OverlayRule(
        TutorialPlacementOverlayType.line,
        TutorialPlacementRegion.nose,
        productColored: true,
      ),
      _OverlayRule(
        TutorialPlacementOverlayType.dot,
        TutorialPlacementRegion.forehead,
        productColored: true,
      ),
      _OverlayRule(
        TutorialPlacementOverlayType.dot,
        TutorialPlacementRegion.chin,
        productColored: true,
      ),
    ],
    techniqueAdjustment:
        'Keep reflective areas smaller than surrounding base coverage.',
    faceAdjustment: 'Highlight scale is adjusted for a ${shape.name} face.',
  );

  static _PlacementRule _eyeshadow(EyeShape shape) {
    final hooded = shape == EyeShape.hooded;
    return _PlacementRule(
      description: hooded
          ? 'Place the transition shade slightly above the natural crease and keep depth at the outer eye.'
          : 'Follow the visible lid and crease, concentrating depth at the outer eye.',
      regions: const {
        TutorialPlacementRegion.eyelid,
        TutorialPlacementRegion.crease,
        TutorialPlacementRegion.outerEye,
        TutorialPlacementRegion.innerEye,
      },
      side: TutorialPlacementSide.bilateral,
      direction: hooded
          ? TutorialDirection.upwardOutward
          : TutorialDirection.outward,
      overlays: const [
        _OverlayRule(
          TutorialPlacementOverlayType.zone,
          TutorialPlacementRegion.eyelid,
          productColored: true,
        ),
        _OverlayRule(
          TutorialPlacementOverlayType.line,
          TutorialPlacementRegion.crease,
          productColored: true,
        ),
        _OverlayRule(
          TutorialPlacementOverlayType.zone,
          TutorialPlacementRegion.outerEye,
          productColored: true,
        ),
        _OverlayRule(
          TutorialPlacementOverlayType.dot,
          TutorialPlacementRegion.innerEye,
          productColored: true,
        ),
      ],
      techniqueAdjustment: hooded
          ? 'Blend with the eye open so the transition remains visible.'
          : 'Blend along the natural eye contour.',
      faceAdjustment: 'Eye placement is adjusted for ${shape.name} eyes.',
    );
  }

  static _PlacementRule _eyeliner(EyeShape shape) {
    final hooded = shape == EyeShape.hooded;
    return _PlacementRule(
      description: hooded
          ? 'Keep the lash-line path thin and use a short lifted outer extension.'
          : 'Trace the upper lash line and extend its natural outer angle.',
      regions: const {
        TutorialPlacementRegion.lashLine,
        TutorialPlacementRegion.outerEye,
      },
      side: TutorialPlacementSide.bilateral,
      direction: TutorialDirection.upwardOutward,
      overlays: const [
        _OverlayRule(
          TutorialPlacementOverlayType.line,
          TutorialPlacementRegion.lashLine,
          productColored: true,
        ),
        _OverlayRule(
          TutorialPlacementOverlayType.arrow,
          TutorialPlacementRegion.outerEye,
        ),
      ],
      techniqueAdjustment: hooded
          ? 'Check the line with the eye open and avoid thickening the fold.'
          : 'Keep the line close to the lashes.',
      faceAdjustment: 'Liner path is adjusted for ${shape.name} eyes.',
    );
  }

  static _PlacementRule _brows(EyeShape shape) => _PlacementRule(
    description: 'Follow each natural brow boundary with directional fill.',
    regions: const {TutorialPlacementRegion.brow},
    side: TutorialPlacementSide.bilateral,
    direction: TutorialDirection.outward,
    overlays: const [
      _OverlayRule(
        TutorialPlacementOverlayType.arrow,
        TutorialPlacementRegion.brow,
        productColored: true,
      ),
    ],
    techniqueAdjustment:
        'Use hair-like strokes and preserve the natural front.',
    faceAdjustment: 'Brow definition is balanced with ${shape.name} eyes.',
  );

  static _PlacementRule _lips(LipShape shape, bool gloss) => _PlacementRule(
    description: gloss
        ? (shape == LipShape.thin
              ? 'Keep gloss within the lip boundary with emphasis at the center.'
              : 'Cover the lips lightly, concentrating shine at the center.')
        : 'Follow the natural lip boundary with even coverage.',
    regions: const {TutorialPlacementRegion.lips},
    side: TutorialPlacementSide.center,
    direction: TutorialDirection.followBoundary,
    overlays: [
      _OverlayRule(
        gloss
            ? TutorialPlacementOverlayType.zone
            : TutorialPlacementOverlayType.boundary,
        TutorialPlacementRegion.lips,
        productColored: true,
      ),
    ],
    techniqueAdjustment: gloss
        ? 'Keep the reflective layer controlled and centered.'
        : 'Refine the edge without changing the natural lip shape.',
    faceAdjustment: 'Coverage preserves the detected ${shape.name} lip shape.',
  );

  static _StylePolicy _stylePolicy(
    String style,
    TutorialStepCategory category,
  ) {
    final normalized = style.trim().toLowerCase();
    return switch (normalized) {
      'full_glam' => const _StylePolicy(
        _IntensityAdjustment.increase,
        'Full Glam uses more defined placement and stronger intensity.',
      ),
      'party' => const _StylePolicy(
        _IntensityAdjustment.increase,
        'Party uses bolder definition suitable for evening light.',
      ),
      'korean' => _StylePolicy(
        _IntensityAdjustment.decrease,
        category == TutorialStepCategory.blush
            ? 'Korean style keeps blush soft, high, and diffused.'
            : 'Korean style uses soft, delicate definition.',
      ),
      'natural' || 'no_makeup_makeup' || 'clean_girl' => const _StylePolicy(
        _IntensityAdjustment.decrease,
        'The selected style uses restrained, softly diffused intensity.',
      ),
      _ => const _StylePolicy(
        _IntensityAdjustment.keep,
        'The selected style preserves the recommendation intensity.',
      ),
    };
  }

  static TutorialIntensity _intensity(
    String recommendation,
    _IntensityAdjustment adjustment,
  ) {
    final normalized = recommendation.trim().toLowerCase();
    final base = switch (normalized) {
      'sheer' || 'barely there' => TutorialIntensity.sheer,
      'light' || 'soft' || 'subtle' => TutorialIntensity.light,
      'strong' || 'bold' || 'high' || 'intense' => TutorialIntensity.strong,
      _ => TutorialIntensity.medium,
    };
    final values = TutorialIntensity.values;
    final offset = switch (adjustment) {
      _IntensityAdjustment.decrease => -1,
      _IntensityAdjustment.keep => 0,
      _IntensityAdjustment.increase => 1,
    };
    return values[(base.index + offset).clamp(0, values.length - 1)];
  }

  static TutorialPlacementConfidence _placementConfidence(
    PersonalizedTutorialInput input,
    TutorialStepCategory category,
  ) {
    final confidence = switch (category) {
      TutorialStepCategory.contour ||
      TutorialStepCategory.blush ||
      TutorialStepCategory.highlighter => input.attributeConfidence.faceShape,
      TutorialStepCategory.concealer ||
      TutorialStepCategory.eyeshadow ||
      TutorialStepCategory.eyeliner ||
      TutorialStepCategory.eyebrow => input.attributeConfidence.eyeShape,
      TutorialStepCategory.lipstick ||
      TutorialStepCategory.lipGloss => input.attributeConfidence.lipShape,
      TutorialStepCategory.foundation => input.attributeConfidence.skinTone,
      TutorialStepCategory.finalLook => 0,
    };
    if (confidence >= 0.8) return TutorialPlacementConfidence.high;
    if (confidence >= 0.55) return TutorialPlacementConfidence.medium;
    return TutorialPlacementConfidence.low;
  }
}

class _PlacementRule {
  const _PlacementRule({
    required this.description,
    required this.regions,
    required this.side,
    required this.direction,
    required this.overlays,
    required this.techniqueAdjustment,
    required this.faceAdjustment,
  });

  final String description;
  final Set<TutorialPlacementRegion> regions;
  final TutorialPlacementSide side;
  final TutorialDirection direction;
  final List<_OverlayRule> overlays;
  final String techniqueAdjustment;
  final String faceAdjustment;

  _PlacementRule copyWith({
    String? description,
    Set<TutorialPlacementRegion>? regions,
    TutorialDirection? direction,
    List<_OverlayRule>? overlays,
  }) => _PlacementRule(
    description: description ?? this.description,
    regions: regions ?? this.regions,
    side: side,
    direction: direction ?? this.direction,
    overlays: overlays ?? this.overlays,
    techniqueAdjustment: techniqueAdjustment,
    faceAdjustment: faceAdjustment,
  );
}

class _OverlayRule {
  const _OverlayRule(this.type, this.region, {this.productColored = false});

  final TutorialPlacementOverlayType type;
  final TutorialPlacementRegion region;
  final bool productColored;
}

enum _IntensityAdjustment { decrease, keep, increase }

class _StylePolicy {
  const _StylePolicy(this.adjustment, this.description);

  final _IntensityAdjustment adjustment;
  final String description;
}
