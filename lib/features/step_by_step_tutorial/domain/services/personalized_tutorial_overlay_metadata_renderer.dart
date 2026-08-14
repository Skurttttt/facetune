import '../entities/personalized_tutorial.dart';
import '../entities/tutorial_face_geometry.dart';
import '../entities/tutorial_placement_metadata.dart';
import 'personalized_tutorial_overlay_accuracy_validator.dart';

/// Converts a canonical personalized step specification into normalized
/// FaceTune drawing primitives. Category decisions remain in the spec; this
/// renderer only projects its regions, anchors, direction, and color.
abstract final class PersonalizedTutorialOverlayMetadataRenderer {
  static TutorialPlacementMetadata build(PersonalizedTutorialStepSpec spec) {
    final validated = PersonalizedTutorialOverlayAccuracyValidator.validate(
      spec,
    );
    final renderableSpec = validated.renderableSpec;
    if (renderableSpec == null) {
      return const TutorialPlacementMetadata(overlays: []);
    }
    final rendered = <TutorialPlacementOverlay>[];
    for (final overlay in renderableSpec.where.overlays) {
      final anchors = renderableSpec.where.geometryAnchors.where(
        (anchor) => anchor.region == overlay.region,
      );
      for (final anchor in anchors) {
        rendered.add(
          TutorialPlacementOverlay(
            type: overlay.type,
            points: _pointsFor(renderableSpec, overlay, anchor),
            label: overlay.region.name,
            colorHex: overlay.colorHex,
          ),
        );
      }
    }
    return TutorialPlacementMetadata(overlays: List.unmodifiable(rendered));
  }

  static List<TutorialPlacementPoint> _pointsFor(
    PersonalizedTutorialStepSpec spec,
    PersonalizedTutorialOverlay overlay,
    PersonalizedTutorialGeometryAnchor anchor,
  ) {
    if (overlay.type == TutorialPlacementOverlayType.dot) {
      final center = _center(anchor.points);
      return [TutorialPlacementPoint(center.x, center.y)];
    }
    if (overlay.type == TutorialPlacementOverlayType.arrow) {
      return _arrow(spec.how.direction, anchor);
    }
    return List.unmodifiable([
      for (final point in anchor.points)
        TutorialPlacementPoint(point.x, point.y),
    ]);
  }

  static List<TutorialPlacementPoint> _arrow(
    TutorialDirection direction,
    PersonalizedTutorialGeometryAnchor anchor,
  ) {
    final start = _center(anchor.points);
    final horizontalSign = switch (anchor.side) {
      TutorialGeometrySide.left => -1.0,
      TutorialGeometrySide.right => 1.0,
      TutorialGeometrySide.center => 1.0,
    };
    final delta = switch (direction) {
      TutorialDirection.none => (0.0, 0.0),
      TutorialDirection.outward => (0.09 * horizontalSign, 0.0),
      TutorialDirection.upward => (0.0, -0.09),
      TutorialDirection.upwardOutward => (0.075 * horizontalSign, -0.075),
      TutorialDirection.inward => (-0.09 * horizontalSign, 0.0),
      TutorialDirection.downward => (0.0, 0.09),
      TutorialDirection.horizontal => (0.09 * horizontalSign, 0.0),
      TutorialDirection.followBoundary => (0.07 * horizontalSign, 0.0),
    };
    return [
      TutorialPlacementPoint(start.x, start.y),
      TutorialPlacementPoint(
        (start.x + delta.$1).clamp(0, 1),
        (start.y + delta.$2).clamp(0, 1),
      ),
    ];
  }

  static TutorialNormalizedPoint _center(
    List<TutorialNormalizedPoint> points,
  ) => TutorialNormalizedPoint(
    x: points.fold<double>(0, (sum, point) => sum + point.x) / points.length,
    y: points.fold<double>(0, (sum, point) => sum + point.y) / points.length,
  );
}
