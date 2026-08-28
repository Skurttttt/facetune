import '../../domain/entities/tutorial_v3_geometry.dart';

/// Serializes validated geometry back to the persisted `jsonb` shape.
///
/// Decoding is `TutorialV3GeometryValidator`'s job — it is the strict half and
/// the only way to obtain a [TutorialV3Geometry]. This is the trivial inverse,
/// used when writing a document the validator has already accepted.
///
/// The two must stay in step: whatever this writes, the validator must accept.
/// A round-trip test pins that.
abstract final class TutorialV3GeometryCodec {
  static Map<String, Object?> encode(TutorialV3Geometry geometry) => {
    'schema_version': geometry.schemaVersion,
    'category': geometry.category.code,
    'coordinate_space': geometry.coordinateSpace,
    'primitives': geometry.primitives
        .map(_encodePrimitive)
        .toList(growable: false),
  };

  static Map<String, Object?> _encodePrimitive(TutorialV3Primitive primitive) {
    final base = <String, Object?>{
      'kind': primitive.kind.code,
      'role': primitive.role.code,
    };
    return switch (primitive) {
      TutorialV3Region(:final vertices) => {
        ...base,
        'vertices': vertices.map(_encodePoint).toList(growable: false),
      },
      TutorialV3Polyline(:final vertices) => {
        ...base,
        'vertices': vertices.map(_encodePoint).toList(growable: false),
      },
      TutorialV3Ellipse(
        :final center,
        :final radiusX,
        :final radiusY,
        :final rotation,
      ) =>
        {
          ...base,
          'center': _encodePoint(center),
          'radius_x': radiusX,
          'radius_y': radiusY,
          // Only emitted when non-zero: the validator treats it as optional,
          // and omitting the default keeps stored documents smaller.
          if (rotation != 0) 'rotation': rotation,
        },
      TutorialV3Arrow(:final start, :final end) => {
        ...base,
        'start': _encodePoint(start),
        'end': _encodePoint(end),
      },
      TutorialV3Marker(:final position) => {
        ...base,
        'position': _encodePoint(position),
      },
    };
  }

  static Map<String, Object?> _encodePoint(NormalizedPoint point) => {
    'x': point.x,
    'y': point.y,
  };
}
