/// Image-relative side used by tutorial face geometry.
///
/// `left` means the left side of the displayed image, not the subject's
/// anatomical left. Keeping this convention explicit prevents a renderer from
/// silently mirroring eye, brow, or cheek placement.
enum TutorialGeometrySide { left, center, right }

/// Provenance of exact geometry. Semantic face attributes are intentionally
/// absent: labels such as `round` and `hooded` are not landmark coordinates.
enum TutorialGeometrySource { existingFaceTuneData, persistedTutorialGeometry }

class TutorialNormalizedPoint {
  TutorialNormalizedPoint({required this.x, required this.y}) {
    _validateCoordinate(x, 'x');
    _validateCoordinate(y, 'y');
  }

  final double x;
  final double y;

  static void _validateCoordinate(double value, String name) {
    if (!value.isFinite || value < 0 || value > 1) {
      throw ArgumentError.value(
        value,
        name,
        'Normalized coordinates must be between 0.0 and 1.0.',
      );
    }
  }
}

/// A semantic face region represented entirely in normalized image space.
/// No image dimensions, screen pixels, Flutter types, or inferred landmarks
/// are stored in the domain object.
class TutorialGeometryRegion {
  TutorialGeometryRegion({
    required this.side,
    required List<TutorialNormalizedPoint> boundary,
  }) : boundary = List.unmodifiable(boundary) {
    if (boundary.isEmpty) {
      throw ArgumentError.value(boundary, 'boundary', 'Cannot be empty.');
    }
  }

  final TutorialGeometrySide side;
  final List<TutorialNormalizedPoint> boundary;

  double get centerX =>
      boundary.fold<double>(0, (sum, point) => sum + point.x) / boundary.length;

  double get centerY =>
      boundary.fold<double>(0, (sum, point) => sum + point.y) / boundary.length;
}

class TutorialBilateralGeometry {
  TutorialBilateralGeometry({required this.left, required this.right}) {
    if (left.side != TutorialGeometrySide.left ||
        right.side != TutorialGeometrySide.right) {
      throw ArgumentError(
        'Bilateral geometry must contain image-left and image-right regions.',
      );
    }
    if (left.centerX >= right.centerX) {
      throw ArgumentError(
        'Image-left geometry must be left of image-right geometry.',
      );
    }
  }

  final TutorialGeometryRegion left;
  final TutorialGeometryRegion right;
}

class TutorialGeometryConfidence {
  TutorialGeometryConfidence({required this.score, required this.source}) {
    if (!score.isFinite || score < 0 || score > 1) {
      throw ArgumentError.value(
        score,
        'score',
        'Geometry confidence must be between 0.0 and 1.0.',
      );
    }
  }

  final double score;
  final TutorialGeometrySource source;
}

/// Exact tutorial geometry, supplied only when an approved existing data
/// source has real coordinates. Absence is represented by a provider returning
/// `null`; callers must not manufacture points from semantic attributes.
class TutorialFaceGeometry {
  TutorialFaceGeometry({
    required this.eyes,
    required this.brows,
    required this.nose,
    required this.lips,
    required this.forehead,
    required this.cheeks,
    required this.jaw,
    required this.chin,
    required this.faceBoundary,
    required this.confidence,
  }) {
    _requireCenter(nose, 'nose');
    _requireCenter(lips, 'lips');
    _requireCenter(forehead, 'forehead');
    _requireCenter(jaw, 'jaw');
    _requireCenter(chin, 'chin');
    _requireCenter(faceBoundary, 'faceBoundary');
  }

  final TutorialBilateralGeometry eyes;
  final TutorialBilateralGeometry brows;
  final TutorialGeometryRegion nose;
  final TutorialGeometryRegion lips;
  final TutorialGeometryRegion forehead;
  final TutorialBilateralGeometry cheeks;
  final TutorialGeometryRegion jaw;
  final TutorialGeometryRegion chin;
  final TutorialGeometryRegion faceBoundary;
  final TutorialGeometryConfidence confidence;

  static void _requireCenter(TutorialGeometryRegion region, String name) {
    if (region.side != TutorialGeometrySide.center) {
      throw ArgumentError.value(
        region.side,
        name,
        'This region must use center-side geometry.',
      );
    }
  }
}
