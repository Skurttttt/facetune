import 'tutorial_v3_category.dart';

/// The geometry schema version this build can interpret.
///
/// Bumped only when the primitive or role vocabulary changes incompatibly.
/// A stored document at any other version is rejected, never coerced — the
/// same rule that governs `TutorialV3PlanVersion`.
const tutorialV3GeometrySchemaVersion = 1;

/// The only coordinate space a geometry document may declare.
///
/// Coordinates are normalized against the ORIGINAL image, not the displayed
/// rect: the display size varies by device and BoxFit, so anything else would
/// bind the persisted geometry to one screen.
const tutorialV3CoordinateSpace = 'normalized_original_image';

/// A point in normalized original-image space.
///
/// `x` and `y` are both in [0,1] with the origin at the top-left. Validation
/// rejects anything outside that range rather than clamping — a coordinate at
/// 1.4 means the model misunderstood the space, and silently pulling it to 1.0
/// would draw a confidently wrong overlay.
class NormalizedPoint {
  const NormalizedPoint(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is NormalizedPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() =>
      '(${x.toStringAsFixed(4)}, ${y.toStringAsFixed(4)})';
}

/// What a primitive means instructionally.
///
/// The AI may not invent roles. Flutter maps each role to a fixed visual
/// treatment, so the role vocabulary is also the styling vocabulary — which is
/// how style stays entirely under Flutter's control.
enum TutorialV3GeometryRole {
  /// A broad area to cover with product.
  coverageZone('coverage_zone'),

  /// A localized area to place product on.
  placementZone('placement_zone'),

  /// A path along which product is applied.
  applicationPath('application_path'),

  /// The direction to blend or sweep.
  blendDirection('blend_direction'),

  /// An outline to follow, such as a lip border.
  boundary('boundary'),

  /// An area to deliberately avoid.
  exclusion('exclusion'),

  /// A small point of attention.
  focusMarker('focus_marker');

  const TutorialV3GeometryRole(this.code);

  final String code;

  static TutorialV3GeometryRole? fromCode(String code) {
    for (final role in values) {
      if (role.code == code) return role;
    }
    return null;
  }
}

/// The primitive families a geometry document may use.
enum TutorialV3PrimitiveKind {
  region('region'),
  ellipse('ellipse'),
  polyline('polyline'),
  arrow('arrow'),
  marker('marker');

  const TutorialV3PrimitiveKind(this.code);

  final String code;

  static TutorialV3PrimitiveKind? fromCode(String code) {
    for (final kind in values) {
      if (kind.code == code) return kind;
    }
    return null;
  }
}

/// One drawable instruction.
///
/// Sealed and discriminated: there is no "other" variant, so an unrecognised
/// primitive cannot be represented and must be rejected at parse time.
///
/// Note what is absent — colour, opacity, stroke width, font, gradient, blend
/// mode, z-order, animation, and any text. Flutter owns all of that. The model
/// supplies shape and meaning only.
sealed class TutorialV3Primitive {
  const TutorialV3Primitive({required this.role});

  final TutorialV3GeometryRole role;

  TutorialV3PrimitiveKind get kind;

  /// Every point this primitive occupies, for range validation.
  List<NormalizedPoint> get points;
}

/// A closed polygon — a coverage or placement area.
final class TutorialV3Region extends TutorialV3Primitive {
  const TutorialV3Region({required super.role, required this.vertices});

  final List<NormalizedPoint> vertices;

  @override
  TutorialV3PrimitiveKind get kind => TutorialV3PrimitiveKind.region;

  @override
  List<NormalizedPoint> get points => vertices;
}

/// An axis-aligned-then-rotated ellipse — the natural shape for a cheek or
/// under-eye area, and far cheaper to specify than a many-vertex polygon.
final class TutorialV3Ellipse extends TutorialV3Primitive {
  const TutorialV3Ellipse({
    required super.role,
    required this.center,
    required this.radiusX,
    required this.radiusY,
    this.rotation = 0,
  });

  final NormalizedPoint center;

  /// Normalized radii. Must be > 0 and small enough to stay sane on a face.
  final double radiusX;
  final double radiusY;

  /// Clockwise rotation in radians.
  final double rotation;

  @override
  TutorialV3PrimitiveKind get kind => TutorialV3PrimitiveKind.ellipse;

  @override
  List<NormalizedPoint> get points => [center];
}

/// An open path — a lash line, a lip border, a brow stroke.
final class TutorialV3Polyline extends TutorialV3Primitive {
  const TutorialV3Polyline({required super.role, required this.vertices});

  final List<NormalizedPoint> vertices;

  @override
  TutorialV3PrimitiveKind get kind => TutorialV3PrimitiveKind.polyline;

  @override
  List<NormalizedPoint> get points => vertices;
}

/// A directional indicator.
final class TutorialV3Arrow extends TutorialV3Primitive {
  const TutorialV3Arrow({
    required super.role,
    required this.start,
    required this.end,
  });

  final NormalizedPoint start;
  final NormalizedPoint end;

  @override
  TutorialV3PrimitiveKind get kind => TutorialV3PrimitiveKind.arrow;

  @override
  List<NormalizedPoint> get points => [start, end];
}

/// A single point of attention.
final class TutorialV3Marker extends TutorialV3Primitive {
  const TutorialV3Marker({required super.role, required this.position});

  final NormalizedPoint position;

  @override
  TutorialV3PrimitiveKind get kind => TutorialV3PrimitiveKind.marker;

  @override
  List<NormalizedPoint> get points => [position];
}

/// One validated geometry document for one step.
///
/// This is the entire contract between the AI and the renderer. It contains no
/// image, no text and no style — only where things are and what they mean.
class TutorialV3Geometry {
  const TutorialV3Geometry({
    required this.schemaVersion,
    required this.category,
    required this.coordinateSpace,
    required this.primitives,
  });

  final int schemaVersion;
  final TutorialV3Category category;
  final String coordinateSpace;
  final List<TutorialV3Primitive> primitives;

  bool get isCurrentSchema =>
      schemaVersion == tutorialV3GeometrySchemaVersion;

  Iterable<TutorialV3Primitive> withRole(TutorialV3GeometryRole role) =>
      primitives.where((primitive) => primitive.role == role);
}
