import '../../../analysis/domain/entities/analysis_confidence.dart';
import '../../../analysis/domain/entities/facial_attributes.dart';
import 'tutorial_face_geometry.dart';
import 'tutorial_placement_metadata.dart';
import 'tutorial_source_mode.dart';
import 'tutorial_step_category.dart';

enum TutorialPlacementRegion {
  fullFace,
  forehead,
  underEye,
  eyelid,
  crease,
  innerEye,
  outerEye,
  lashLine,
  brow,
  temple,
  cheek,
  cheekbone,
  nose,
  jaw,
  chin,
  lips,
}

enum TutorialPlacementSide { center, left, right, bilateral, full }

enum TutorialDirection {
  none,
  outward,
  upward,
  upwardOutward,
  inward,
  downward,
  horizontal,
  followBoundary,
}

enum TutorialIntensity { sheer, light, medium, strong }

enum TutorialPlacementConfidence { high, medium, low, unavailable }

/// Product/recommendation facts copied into the tutorial planning boundary.
/// This is a snapshot: later recommendation mutations must not alter a plan.
class TutorialRecommendationData {
  TutorialRecommendationData({
    required this.category,
    required String placement,
    required String intensity,
    required String technique,
    String? productName,
    String? colorName,
    String? colorHex,
    String? finish,
    String? reasoning,
  }) : placement = _required(placement, 'placement'),
       intensity = _required(intensity, 'intensity'),
       technique = _required(technique, 'technique'),
       productName = _optional(productName, 'productName'),
       colorName = _optional(colorName, 'colorName'),
       colorHex = _optionalHex(colorHex),
       finish = _optional(finish, 'finish'),
       reasoning = _optional(reasoning, 'reasoning');

  final TutorialStepCategory category;
  final String? productName;
  final String? colorName;
  final String? colorHex;
  final String? finish;
  final String placement;
  final String intensity;
  final String technique;
  final String? reasoning;
}

/// Immutable owned-product facts used only by a kit tutorial.
class TutorialKitProductSnapshot {
  TutorialKitProductSnapshot({
    required String productId,
    required this.category,
    required String colorHex,
    required String finish,
    String? productName,
    String? colorName,
    String? foundationDepth,
    String? foundationUndertone,
  }) : productId = _required(productId, 'productId'),
       colorHex = _requiredHex(colorHex),
       finish = _required(finish, 'finish'),
       productName = _optional(productName, 'productName'),
       colorName = _optional(colorName, 'colorName'),
       foundationDepth = _optional(foundationDepth, 'foundationDepth'),
       foundationUndertone = _optional(
         foundationUndertone,
         'foundationUndertone',
       );

  final String productId;
  final TutorialStepCategory category;
  final String? productName;
  final String? colorName;
  final String colorHex;
  final String finish;
  final String? foundationDepth;
  final String? foundationUndertone;
}

/// Complete, UI-independent input needed to personalize a tutorial plan.
class PersonalizedTutorialInput {
  PersonalizedTutorialInput({
    required this.sourceMode,
    required this.faceAttributes,
    required this.attributeConfidence,
    required String selectedStyle,
    required List<TutorialRecommendationData> recommendations,
    List<TutorialKitProductSnapshot> kitSnapshots = const [],
  }) : selectedStyle = _required(selectedStyle, 'selectedStyle'),
       recommendations = List.unmodifiable(recommendations),
       kitSnapshots = List.unmodifiable(kitSnapshots) {
    _validateConfidence(attributeConfidence);
    if (recommendations.isEmpty) {
      throw ArgumentError.value(
        recommendations,
        'recommendations',
        'At least one recommendation is required.',
      );
    }
    if (sourceMode == TutorialSourceMode.standardRecommendation &&
        kitSnapshots.isNotEmpty) {
      throw ArgumentError.value(
        kitSnapshots,
        'kitSnapshots',
        'Standard tutorials cannot contain kit snapshots.',
      );
    }
    if (sourceMode == TutorialSourceMode.makeupKit && kitSnapshots.isEmpty) {
      throw ArgumentError.value(
        kitSnapshots,
        'kitSnapshots',
        'Kit tutorials require immutable product snapshots.',
      );
    }
  }

  final TutorialSourceMode sourceMode;
  final FacialAttributes faceAttributes;
  final AnalysisConfidence attributeConfidence;
  final String selectedStyle;
  final List<TutorialRecommendationData> recommendations;
  final List<TutorialKitProductSnapshot> kitSnapshots;
}

/// WHAT to apply. All fields except category are optional because a valid
/// recommendation may omit product/color details rather than fabricate them.
class PersonalizedTutorialWhat {
  PersonalizedTutorialWhat({
    required this.category,
    String? productName,
    String? colorName,
    String? colorHex,
    String? finish,
    this.kitSnapshot,
  }) : productName = _optional(productName, 'productName'),
       colorName = _optional(colorName, 'colorName'),
       colorHex = _optionalHex(colorHex),
       finish = _optional(finish, 'finish') {
    if (kitSnapshot != null && kitSnapshot!.category != category) {
      throw ArgumentError.value(
        kitSnapshot,
        'kitSnapshot',
        'Kit snapshot category must match the step category.',
      );
    }
  }

  final TutorialStepCategory category;
  final String? productName;
  final String? colorName;
  final String? colorHex;
  final String? finish;
  final TutorialKitProductSnapshot? kitSnapshot;
}

class PersonalizedTutorialOverlay {
  PersonalizedTutorialOverlay({
    required this.type,
    required this.region,
    String? colorHex,
  }) : colorHex = _optionalHex(colorHex);

  final TutorialPlacementOverlayType type;
  final TutorialPlacementRegion region;
  final String? colorHex;
}

class PersonalizedTutorialGeometryAnchor {
  PersonalizedTutorialGeometryAnchor({
    required this.region,
    required this.side,
    required List<TutorialNormalizedPoint> points,
  }) : points = List.unmodifiable(points) {
    if (points.isEmpty) {
      throw ArgumentError.value(points, 'points', 'Cannot be empty.');
    }
  }

  final TutorialPlacementRegion region;
  final TutorialGeometrySide side;
  final List<TutorialNormalizedPoint> points;
}

/// WHERE to apply. Geometry anchors are deliberately absent until MO-3.
class PersonalizedTutorialWhere {
  PersonalizedTutorialWhere({
    required String description,
    required Set<TutorialPlacementRegion> regions,
    required this.side,
    required this.geometryConfidence,
    required this.placementConfidence,
    required List<PersonalizedTutorialOverlay> overlays,
    List<PersonalizedTutorialGeometryAnchor> geometryAnchors = const [],
  }) : description = _required(description, 'description'),
       regions = Set.unmodifiable(regions),
       overlays = List.unmodifiable(overlays),
       geometryAnchors = List.unmodifiable(geometryAnchors) {
    if (regions.isEmpty) {
      throw ArgumentError.value(regions, 'regions', 'Cannot be empty.');
    }
    if (overlays.isEmpty) {
      throw ArgumentError.value(overlays, 'overlays', 'Cannot be empty.');
    }
    if (overlays.any((overlay) => !regions.contains(overlay.region))) {
      throw ArgumentError.value(
        overlays,
        'overlays',
        'Every overlay region must be declared by WHERE.',
      );
    }
    if (geometryAnchors.any((anchor) => !regions.contains(anchor.region))) {
      throw ArgumentError.value(
        geometryAnchors,
        'geometryAnchors',
        'Every geometry anchor region must be declared by WHERE.',
      );
    }
    if (geometryAnchors.isEmpty &&
        geometryConfidence != TutorialPlacementConfidence.unavailable) {
      throw ArgumentError(
        'Geometry confidence must be unavailable when anchors are absent.',
      );
    }
    if (geometryAnchors.isNotEmpty &&
        geometryConfidence == TutorialPlacementConfidence.unavailable) {
      throw ArgumentError(
        'Geometry confidence is required when anchors are present.',
      );
    }
  }

  final String description;
  final Set<TutorialPlacementRegion> regions;
  final TutorialPlacementSide side;
  final TutorialPlacementConfidence geometryConfidence;
  final TutorialPlacementConfidence placementConfidence;
  final List<PersonalizedTutorialOverlay> overlays;
  final List<PersonalizedTutorialGeometryAnchor> geometryAnchors;
}

class TutorialTechnique {
  TutorialTechnique(String value) : value = _required(value, 'technique');

  final String value;
}

/// HOW to apply the product.
class PersonalizedTutorialHow {
  const PersonalizedTutorialHow({
    required this.direction,
    required this.intensity,
    required this.technique,
    this.tip,
  });

  final TutorialDirection direction;
  final TutorialIntensity intensity;
  final TutorialTechnique technique;
  final String? tip;
}

/// Canonical tutorial step contract. Text, overlays, persistence, and Gemini
/// will consume projections of this single specification in later phases.
class PersonalizedTutorialStepSpec {
  PersonalizedTutorialStepSpec({
    required this.stepNumber,
    required this.what,
    required this.where,
    required this.how,
    this.faceAdjustment,
    this.styleAdjustment,
  }) {
    if (stepNumber < 1) {
      throw ArgumentError.value(stepNumber, 'stepNumber', 'Must be positive.');
    }
  }

  final int stepNumber;
  final PersonalizedTutorialWhat what;
  final PersonalizedTutorialWhere where;
  final PersonalizedTutorialHow how;
  final String? faceAdjustment;
  final String? styleAdjustment;
}

String _required(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be blank.');
  }
  return value;
}

String? _optional(String? value, String name) {
  if (value == null) return null;
  return _required(value, name);
}

void _validateConfidence(AnalysisConfidence confidence) {
  final values = <String, double>{
    'faceShape': confidence.faceShape,
    'skinTone': confidence.skinTone,
    'undertone': confidence.undertone,
    'eyeShape': confidence.eyeShape,
    'lipShape': confidence.lipShape,
    'hairColor': confidence.hairColor,
    'eyeColor': confidence.eyeColor,
  };
  for (final entry in values.entries) {
    if (!entry.value.isFinite || entry.value < 0 || entry.value > 1) {
      throw ArgumentError.value(
        entry.value,
        'attributeConfidence.${entry.key}',
        'Must be between 0.0 and 1.0.',
      );
    }
  }
}

String _requiredHex(String value) =>
    _optionalHex(value) ?? (throw ArgumentError.value(value, 'colorHex'));

String? _optionalHex(String? value) {
  if (value == null) return null;
  if (!RegExp(r'^#[0-9A-F]{6}$').hasMatch(value)) {
    throw ArgumentError.value(
      value,
      'colorHex',
      'Must use uppercase #RRGGBB format.',
    );
  }
  return value;
}
