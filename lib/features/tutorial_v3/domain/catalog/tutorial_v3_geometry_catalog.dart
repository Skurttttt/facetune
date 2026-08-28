import '../entities/tutorial_v3_category.dart';
import '../entities/tutorial_v3_geometry.dart';

/// The authoritative rules for what geometry each category may contain.
///
/// Two independent constraints are enforced:
///
/// 1. **Role → primitive kind.** A direction is an arrow; a path is a
///    polyline. This is category-independent and stops a "blend_direction"
///    arriving as a 20-vertex polygon.
/// 2. **Category → roles.** An eyeliner step has no business emitting a
///    full-face coverage zone, and a foundation step has no business emitting
///    a lash-line path. This is what keeps one step from teaching another
///    category's technique.
///
/// Limits exist so a malformed or adversarial response cannot produce a
/// document that is expensive to render or impossible to read.
abstract final class TutorialV3GeometryCatalog {
  /// Maximum primitives in one document.
  static const maxPrimitives = 24;

  static const minRegionVertices = 3;
  static const maxRegionVertices = 24;

  static const minPolylineVertices = 2;
  static const maxPolylineVertices = 32;

  /// Radii must describe something visible but not absurd on a face.
  static const minRadius = 0.005;
  static const maxRadius = 0.6;

  /// An arrow shorter than this conveys no direction.
  static const minArrowLength = 0.01;

  static const Map<TutorialV3GeometryRole, Set<TutorialV3PrimitiveKind>>
  _rolePrimitives = {
    TutorialV3GeometryRole.coverageZone: {
      TutorialV3PrimitiveKind.region,
      TutorialV3PrimitiveKind.ellipse,
    },
    TutorialV3GeometryRole.placementZone: {
      TutorialV3PrimitiveKind.region,
      TutorialV3PrimitiveKind.ellipse,
    },
    TutorialV3GeometryRole.applicationPath: {
      TutorialV3PrimitiveKind.polyline,
    },
    TutorialV3GeometryRole.blendDirection: {TutorialV3PrimitiveKind.arrow},
    TutorialV3GeometryRole.boundary: {
      TutorialV3PrimitiveKind.polyline,
      TutorialV3PrimitiveKind.region,
    },
    TutorialV3GeometryRole.exclusion: {
      TutorialV3PrimitiveKind.region,
      TutorialV3PrimitiveKind.ellipse,
    },
    TutorialV3GeometryRole.focusMarker: {TutorialV3PrimitiveKind.marker},
  };

  static const Map<TutorialV3Category, Set<TutorialV3GeometryRole>>
  _categoryRoles = {
    TutorialV3Category.foundation: {
      TutorialV3GeometryRole.coverageZone,
      TutorialV3GeometryRole.blendDirection,
      TutorialV3GeometryRole.exclusion,
    },
    TutorialV3Category.concealer: {
      TutorialV3GeometryRole.placementZone,
      TutorialV3GeometryRole.blendDirection,
      TutorialV3GeometryRole.focusMarker,
    },
    TutorialV3Category.contourBronzer: {
      TutorialV3GeometryRole.placementZone,
      TutorialV3GeometryRole.blendDirection,
      TutorialV3GeometryRole.boundary,
    },
    TutorialV3Category.blush: {
      TutorialV3GeometryRole.placementZone,
      TutorialV3GeometryRole.blendDirection,
    },
    TutorialV3Category.highlighter: {
      TutorialV3GeometryRole.placementZone,
      TutorialV3GeometryRole.focusMarker,
    },
    TutorialV3Category.eyebrow: {
      TutorialV3GeometryRole.applicationPath,
      TutorialV3GeometryRole.boundary,
      TutorialV3GeometryRole.blendDirection,
    },
    TutorialV3Category.eyeshadow: {
      TutorialV3GeometryRole.placementZone,
      TutorialV3GeometryRole.blendDirection,
      TutorialV3GeometryRole.boundary,
    },
    TutorialV3Category.eyeliner: {
      TutorialV3GeometryRole.applicationPath,
      TutorialV3GeometryRole.blendDirection,
      TutorialV3GeometryRole.focusMarker,
    },
    TutorialV3Category.lipstick: {
      TutorialV3GeometryRole.boundary,
      TutorialV3GeometryRole.coverageZone,
      TutorialV3GeometryRole.applicationPath,
    },
    TutorialV3Category.lipGloss: {
      TutorialV3GeometryRole.placementZone,
      TutorialV3GeometryRole.applicationPath,
      TutorialV3GeometryRole.focusMarker,
    },
    // The final look reuses the canonical preview and draws no geometry.
    TutorialV3Category.finalLook: <TutorialV3GeometryRole>{},
  };

  static Set<TutorialV3PrimitiveKind> kindsFor(TutorialV3GeometryRole role) =>
      _rolePrimitives[role] ?? const {};

  static Set<TutorialV3GeometryRole> rolesFor(TutorialV3Category category) =>
      _categoryRoles[category] ?? const {};

  static bool allows(
    TutorialV3Category category,
    TutorialV3GeometryRole role,
    TutorialV3PrimitiveKind kind,
  ) => rolesFor(category).contains(role) && kindsFor(role).contains(kind);
}
