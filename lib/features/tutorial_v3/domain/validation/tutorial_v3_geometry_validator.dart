import 'dart:math' as math;

import '../catalog/tutorial_v3_geometry_catalog.dart';
import '../entities/tutorial_v3_category.dart';
import '../entities/tutorial_v3_geometry.dart';
import '../errors/tutorial_v3_failure.dart';

/// Parses and validates an AI geometry response.
///
/// The guiding rule is **reject, never repair**. Out-of-range coordinates are
/// not clamped, unknown keys are not ignored, and a malformed primitive does
/// not get dropped so the rest can render. Any of those would produce an
/// overlay that looks authoritative while pointing somewhere wrong, which is
/// worse for a user than showing nothing.
abstract final class TutorialV3GeometryValidator {
  /// Keys allowed at the document root. Anything else is a contract breach —
  /// most importantly `text`, `label`, `color`, `style`, `svg`, `html`, which
  /// would mean the model tried to control presentation.
  static const _documentKeys = {
    'schema_version',
    'category',
    'coordinate_space',
    'primitives',
  };

  static const _primitiveKeys = {
    'kind',
    'role',
    'vertices',
    'center',
    'radius_x',
    'radius_y',
    'rotation',
    'start',
    'end',
    'position',
  };

  /// Validates [payload] against [expectedCategory].
  ///
  /// Throws [TutorialV3Failure] with every violation found, so a bounded
  /// repair retry can be told all of them at once.
  static TutorialV3Geometry validate(
    Map<String, Object?> payload, {
    required TutorialV3Category expectedCategory,
  }) {
    final errors = <String>[];

    _rejectUnknownKeys(payload, _documentKeys, 'document', errors);

    final schemaVersion = payload['schema_version'];
    if (schemaVersion is! int) {
      errors.add('schema_version must be an integer.');
    } else if (schemaVersion != tutorialV3GeometrySchemaVersion) {
      errors.add(
        'Unsupported geometry schema version $schemaVersion; '
        'this build reads $tutorialV3GeometrySchemaVersion.',
      );
    }

    final space = payload['coordinate_space'];
    if (space != tutorialV3CoordinateSpace) {
      errors.add(
        'coordinate_space must be "$tutorialV3CoordinateSpace", got "$space".',
      );
    }

    final categoryCode = payload['category'];
    final category = categoryCode is String
        ? TutorialV3Category.fromCode(categoryCode)
        : null;
    if (category == null) {
      errors.add('category "$categoryCode" is not a known category.');
    } else if (category != expectedCategory) {
      // The server asked about one step; a response about another category
      // cannot be trusted to describe this one.
      errors.add(
        'category mismatch: expected "${expectedCategory.code}", '
        'got "${category.code}".',
      );
    }

    final rawPrimitives = payload['primitives'];
    if (rawPrimitives is! List || rawPrimitives.isEmpty) {
      errors.add('primitives must be a non-empty list.');
      throw _failure(errors);
    }
    if (rawPrimitives.length > TutorialV3GeometryCatalog.maxPrimitives) {
      errors.add(
        'too many primitives (${rawPrimitives.length}); '
        'the limit is ${TutorialV3GeometryCatalog.maxPrimitives}.',
      );
    }

    final primitives = <TutorialV3Primitive>[];
    for (var index = 0; index < rawPrimitives.length; index++) {
      final primitive = _parsePrimitive(
        rawPrimitives[index],
        index,
        category ?? expectedCategory,
        errors,
      );
      if (primitive != null) primitives.add(primitive);
    }

    if (errors.isNotEmpty) throw _failure(errors);

    return TutorialV3Geometry(
      schemaVersion: schemaVersion as int,
      category: category!,
      coordinateSpace: space as String,
      primitives: primitives,
    );
  }

  static TutorialV3Primitive? _parsePrimitive(
    Object? raw,
    int index,
    TutorialV3Category category,
    List<String> errors,
  ) {
    final position = 'primitive $index';
    if (raw is! Map) {
      errors.add('$position is not an object.');
      return null;
    }
    final map = raw.cast<String, Object?>();
    _rejectUnknownKeys(map, _primitiveKeys, position, errors);

    final kind = map['kind'] is String
        ? TutorialV3PrimitiveKind.fromCode(map['kind']! as String)
        : null;
    if (kind == null) {
      errors.add('$position has unknown kind "${map['kind']}".');
      return null;
    }
    final role = map['role'] is String
        ? TutorialV3GeometryRole.fromCode(map['role']! as String)
        : null;
    if (role == null) {
      errors.add('$position has unknown role "${map['role']}".');
      return null;
    }

    if (!TutorialV3GeometryCatalog.kindsFor(role).contains(kind)) {
      errors.add(
        '$position uses kind "${kind.code}" for role "${role.code}", '
        'which only accepts '
        '${TutorialV3GeometryCatalog.kindsFor(role).map((k) => k.code).join(", ")}.',
      );
      return null;
    }
    if (!TutorialV3GeometryCatalog.rolesFor(category).contains(role)) {
      errors.add(
        '$position uses role "${role.code}", which "${category.code}" '
        'does not allow.',
      );
      return null;
    }

    switch (kind) {
      case TutorialV3PrimitiveKind.region:
        final vertices = _points(map['vertices'], position, 'vertices', errors);
        if (vertices == null) return null;
        if (vertices.length < TutorialV3GeometryCatalog.minRegionVertices ||
            vertices.length > TutorialV3GeometryCatalog.maxRegionVertices) {
          errors.add(
            '$position region needs '
            '${TutorialV3GeometryCatalog.minRegionVertices}'
            '–${TutorialV3GeometryCatalog.maxRegionVertices} vertices, '
            'got ${vertices.length}.',
          );
          return null;
        }
        return TutorialV3Region(role: role, vertices: vertices);

      case TutorialV3PrimitiveKind.polyline:
        final vertices = _points(map['vertices'], position, 'vertices', errors);
        if (vertices == null) return null;
        if (vertices.length < TutorialV3GeometryCatalog.minPolylineVertices ||
            vertices.length > TutorialV3GeometryCatalog.maxPolylineVertices) {
          errors.add(
            '$position polyline needs '
            '${TutorialV3GeometryCatalog.minPolylineVertices}'
            '–${TutorialV3GeometryCatalog.maxPolylineVertices} vertices, '
            'got ${vertices.length}.',
          );
          return null;
        }
        return TutorialV3Polyline(role: role, vertices: vertices);

      case TutorialV3PrimitiveKind.ellipse:
        final center = _point(map['center'], position, 'center', errors);
        final radiusX = _double(map['radius_x'], position, 'radius_x', errors);
        final radiusY = _double(map['radius_y'], position, 'radius_y', errors);
        final rotation = map['rotation'] == null
            ? 0.0
            : _double(map['rotation'], position, 'rotation', errors);
        if (center == null ||
            radiusX == null ||
            radiusY == null ||
            rotation == null) {
          return null;
        }
        for (final entry in {'radius_x': radiusX, 'radius_y': radiusY}.entries) {
          if (entry.value < TutorialV3GeometryCatalog.minRadius ||
              entry.value > TutorialV3GeometryCatalog.maxRadius) {
            errors.add(
              '$position ${entry.key} ${entry.value} is outside '
              '${TutorialV3GeometryCatalog.minRadius}'
              '–${TutorialV3GeometryCatalog.maxRadius}.',
            );
            return null;
          }
        }
        return TutorialV3Ellipse(
          role: role,
          center: center,
          radiusX: radiusX,
          radiusY: radiusY,
          rotation: rotation,
        );

      case TutorialV3PrimitiveKind.arrow:
        final start = _point(map['start'], position, 'start', errors);
        final end = _point(map['end'], position, 'end', errors);
        if (start == null || end == null) return null;
        final length = math.sqrt(
          math.pow(end.x - start.x, 2) + math.pow(end.y - start.y, 2),
        );
        if (length < TutorialV3GeometryCatalog.minArrowLength) {
          errors.add(
            '$position arrow length ${length.toStringAsFixed(4)} is below '
            '${TutorialV3GeometryCatalog.minArrowLength}; it shows no direction.',
          );
          return null;
        }
        return TutorialV3Arrow(role: role, start: start, end: end);

      case TutorialV3PrimitiveKind.marker:
        final at = _point(map['position'], position, 'position', errors);
        if (at == null) return null;
        return TutorialV3Marker(role: role, position: at);
    }
  }

  static void _rejectUnknownKeys(
    Map<String, Object?> map,
    Set<String> allowed,
    String where,
    List<String> errors,
  ) {
    final unknown = map.keys.where((key) => !allowed.contains(key)).toList()
      ..sort();
    if (unknown.isNotEmpty) {
      // Style, text and code fields land here. The model is not permitted to
      // control presentation, so their presence is a contract breach rather
      // than something to ignore.
      errors.add('$where has unsupported fields: ${unknown.join(", ")}.');
    }
  }

  static List<NormalizedPoint>? _points(
    Object? raw,
    String where,
    String field,
    List<String> errors,
  ) {
    if (raw is! List) {
      errors.add('$where $field must be a list.');
      return null;
    }
    final points = <NormalizedPoint>[];
    for (var index = 0; index < raw.length; index++) {
      final point = _point(raw[index], where, '$field[$index]', errors);
      if (point == null) return null;
      points.add(point);
    }
    return points;
  }

  static NormalizedPoint? _point(
    Object? raw,
    String where,
    String field,
    List<String> errors,
  ) {
    if (raw is! Map) {
      errors.add('$where $field must be an object with x and y.');
      return null;
    }
    final map = raw.cast<String, Object?>();
    final unknown = map.keys.where((key) => key != 'x' && key != 'y');
    if (unknown.isNotEmpty) {
      errors.add('$where $field has unsupported fields: ${unknown.join(", ")}.');
      return null;
    }
    final x = _double(map['x'], where, '$field.x', errors);
    final y = _double(map['y'], where, '$field.y', errors);
    if (x == null || y == null) return null;
    if (x < 0 || x > 1 || y < 0 || y > 1) {
      // Deliberately not clamped: an out-of-range value means the model
      // misunderstood the coordinate space, and a clamped point would draw a
      // confidently wrong overlay.
      errors.add('$where $field ($x, $y) is outside the normalized 0–1 range.');
      return null;
    }
    return NormalizedPoint(x, y);
  }

  static double? _double(
    Object? raw,
    String where,
    String field,
    List<String> errors,
  ) {
    if (raw is! num) {
      errors.add('$where $field must be a number.');
      return null;
    }
    final value = raw.toDouble();
    if (value.isNaN || value.isInfinite) {
      errors.add('$where $field is not a finite number.');
      return null;
    }
    return value;
  }

  static TutorialV3Failure _failure(List<String> errors) => TutorialV3Failure(
    errors.join(' '),
    kind: TutorialV3FailureKind.validation,
    retryable: false,
  );
}
