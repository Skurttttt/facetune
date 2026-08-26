import 'personalized_tutorial.dart';
import 'tutorial_face_geometry.dart';
import 'tutorial_step_category.dart';

/// Mirrors `plan-tutorial-geometry/schema.ts`'s zone shape vocabulary
/// exactly (`code` values), so a persisted `geometry_plan_json` round-trips
/// byte-for-byte through this codec.
enum TutorialGeometryZoneShape {
  ellipse('ellipse'),
  polygon('polygon'),
  softBand('soft_band'),
  region('region');

  const TutorialGeometryZoneShape(this.code);

  final String code;

  static TutorialGeometryZoneShape? fromCode(String code) {
    for (final value in values) {
      if (value.code == code) return value;
    }
    return null;
  }
}

class TutorialGeometryZone {
  TutorialGeometryZone({
    required this.shape,
    required List<TutorialNormalizedPoint> points,
    required this.confidence,
  }) : points = List.unmodifiable(points) {
    if (points.isEmpty) {
      throw ArgumentError.value(points, 'points', 'Cannot be empty.');
    }
    _requireConfidence(confidence);
  }

  final TutorialGeometryZoneShape shape;
  final List<TutorialNormalizedPoint> points;
  final double confidence;
}

class TutorialGeometryPath {
  TutorialGeometryPath({
    required List<TutorialNormalizedPoint> points,
    required this.confidence,
  }) : points = List.unmodifiable(points) {
    if (points.length < 2) {
      throw ArgumentError.value(
        points,
        'points',
        'A path needs at least two points.',
      );
    }
    _requireConfidence(confidence);
  }

  final List<TutorialNormalizedPoint> points;
  final double confidence;
}

class TutorialGeometryArrow {
  TutorialGeometryArrow({
    required this.from,
    required this.to,
    required this.confidence,
  }) {
    _requireConfidence(confidence);
  }

  final TutorialNormalizedPoint from;
  final TutorialNormalizedPoint to;
  final double confidence;
}

/// One canonical step category's validated, photo-grounded placement plan —
/// the persisted output of the tutorial-only Gemini geometry planning call
/// (`plan-tutorial-geometry`, TF-2).
///
/// Deliberately distinct from [PersonalizedTutorialStepSpec]: this is raw,
/// server-validated Gemini output, not FaceTune's own placement decision.
/// `TutorialGeometryActivation` (TF-3) projects it into placement metadata
/// for the overlay renderer; nothing here decides rendering.
class TutorialCategoryGeometryPlan {
  TutorialCategoryGeometryPlan({
    required this.category,
    required String placement,
    required this.direction,
    required this.intensity,
    required String technique,
    required this.confidence,
    this.colorHex,
    this.finish,
    List<TutorialGeometryZone> zones = const [],
    List<TutorialGeometryPath> paths = const [],
    List<TutorialGeometryArrow> arrows = const [],
  }) : placement = _requiredText(placement, 'placement'),
       technique = _requiredText(technique, 'technique'),
       zones = List.unmodifiable(zones),
       paths = List.unmodifiable(paths),
       arrows = List.unmodifiable(arrows) {
    if (category == TutorialStepCategory.finalLook) {
      throw ArgumentError.value(
        category,
        'category',
        'Final look is not an application placement step.',
      );
    }
    _requireConfidence(confidence);
    if (zones.isEmpty && paths.isEmpty && arrows.isEmpty) {
      throw ArgumentError(
        'At least one geometry primitive (zone/path/arrow) is required.',
      );
    }
  }

  final TutorialStepCategory category;
  final String placement;
  final TutorialDirection direction;
  final TutorialIntensity intensity;
  final String technique;
  final double confidence;
  final String? colorHex;
  final String? finish;
  final List<TutorialGeometryZone> zones;
  final List<TutorialGeometryPath> paths;
  final List<TutorialGeometryArrow> arrows;
}

/// The complete, validated output of one tutorial-only Gemini geometry
/// planning call — persisted once per tutorial session
/// (`tutorial_sessions.geometry_plan_json`) and reused, never re-derived on
/// reopen and never re-requested once present.
class TutorialGeometryPlan {
  TutorialGeometryPlan({required List<TutorialCategoryGeometryPlan> steps})
    : steps = List.unmodifiable(steps) {
    if (steps.isEmpty) {
      throw ArgumentError.value(
        steps,
        'steps',
        'A geometry plan must cover at least one category.',
      );
    }
    final categories = steps.map((step) => step.category).toList();
    if (categories.toSet().length != categories.length) {
      throw ArgumentError('Duplicate categories are not allowed.');
    }
  }

  final List<TutorialCategoryGeometryPlan> steps;

  TutorialCategoryGeometryPlan? forCategory(TutorialStepCategory category) {
    for (final step in steps) {
      if (step.category == category) return step;
    }
    return null;
  }
}

String _requiredText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be blank.');
  }
  return value;
}

void _requireConfidence(double value) {
  if (!value.isFinite || value < 0 || value > 1) {
    throw ArgumentError.value(
      value,
      'confidence',
      'Must be between 0.0 and 1.0.',
    );
  }
}
