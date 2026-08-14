import '../../domain/entities/personalized_tutorial.dart';
import '../../domain/entities/tutorial_face_geometry.dart';
import '../../domain/entities/tutorial_placement_metadata.dart';
import '../../domain/entities/tutorial_step_category.dart';

abstract final class PersonalizedTutorialStepSpecCodec {
  static Map<String, Object?> toJson(PersonalizedTutorialStepSpec spec) => {
    'stepNumber': spec.stepNumber,
    'what': {
      'category': spec.what.category.code,
      'productName': spec.what.productName,
      'colorName': spec.what.colorName,
      'colorHex': spec.what.colorHex,
      'finish': spec.what.finish,
      'productSnapshot': _snapshotToJson(spec.what.kitSnapshot),
    },
    'where': {
      'description': spec.where.description,
      'regions': spec.where.regions.map((value) => value.name).toList(),
      'side': spec.where.side.name,
      'geometryConfidence': spec.where.geometryConfidence.name,
      'placementConfidence': spec.where.placementConfidence.name,
      'overlays': [
        for (final overlay in spec.where.overlays)
          {
            'type': overlay.type.code,
            'region': overlay.region.name,
            'colorHex': overlay.colorHex,
          },
      ],
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
    },
    'how': {
      'direction': spec.how.direction.name,
      'intensity': spec.how.intensity.name,
      'technique': spec.how.technique.value,
      'tip': spec.how.tip,
    },
    'faceAdjustment': spec.faceAdjustment,
    'styleAdjustment': spec.styleAdjustment,
  };

  static PersonalizedTutorialStepSpec fromJson(Object? value) {
    final root = _object(value, 'personalized_spec_json');
    final what = _object(root['what'], 'what');
    final where = _object(root['where'], 'where');
    final how = _object(root['how'], 'how');
    final category = _enum(what, 'category', TutorialStepCategory.fromCode);
    return PersonalizedTutorialStepSpec(
      stepNumber: _int(root, 'stepNumber'),
      what: PersonalizedTutorialWhat(
        category: category,
        productName: _string(what, 'productName'),
        colorName: _string(what, 'colorName'),
        colorHex: _string(what, 'colorHex'),
        finish: _string(what, 'finish'),
        kitSnapshot: _snapshotFromJson(what['productSnapshot']),
      ),
      where: PersonalizedTutorialWhere(
        description: _requiredString(where, 'description'),
        regions: _list(where, 'regions').map((value) {
          if (value is! String) {
            throw const FormatException('region must be a string.');
          }
          return _named(TutorialPlacementRegion.values, value, 'region');
        }).toSet(),
        side: _named(
          TutorialPlacementSide.values,
          _requiredString(where, 'side'),
          'side',
        ),
        geometryConfidence: _named(
          TutorialPlacementConfidence.values,
          _requiredString(where, 'geometryConfidence'),
          'geometryConfidence',
        ),
        placementConfidence: _named(
          TutorialPlacementConfidence.values,
          _requiredString(where, 'placementConfidence'),
          'placementConfidence',
        ),
        overlays: _list(where, 'overlays').map((value) {
          final data = _object(value, 'overlay');
          return PersonalizedTutorialOverlay(
            type: _enum(data, 'type', TutorialPlacementOverlayType.fromCode),
            region: _named(
              TutorialPlacementRegion.values,
              _requiredString(data, 'region'),
              'region',
            ),
            colorHex: _string(data, 'colorHex'),
          );
        }).toList(),
        geometryAnchors: _list(where, 'geometryAnchors').map((value) {
          final data = _object(value, 'geometryAnchor');
          return PersonalizedTutorialGeometryAnchor(
            region: _named(
              TutorialPlacementRegion.values,
              _requiredString(data, 'region'),
              'region',
            ),
            side: _named(
              TutorialGeometrySide.values,
              _requiredString(data, 'side'),
              'geometry side',
            ),
            points: _list(data, 'points').map((value) {
              final point = _object(value, 'point');
              return TutorialNormalizedPoint(
                x: _number(point, 'x'),
                y: _number(point, 'y'),
              );
            }).toList(),
          );
        }).toList(),
      ),
      how: PersonalizedTutorialHow(
        direction: _named(
          TutorialDirection.values,
          _requiredString(how, 'direction'),
          'direction',
        ),
        intensity: _named(
          TutorialIntensity.values,
          _requiredString(how, 'intensity'),
          'intensity',
        ),
        technique: TutorialTechnique(_requiredString(how, 'technique')),
        tip: _string(how, 'tip'),
      ),
      faceAdjustment: _string(root, 'faceAdjustment'),
      styleAdjustment: _string(root, 'styleAdjustment'),
    );
  }

  static Map<String, Object?>? _snapshotToJson(
    TutorialKitProductSnapshot? snapshot,
  ) => snapshot == null
      ? null
      : {
          'productId': snapshot.productId,
          'category': snapshot.category.code,
          'productName': snapshot.productName,
          'colorName': snapshot.colorName,
          'colorHex': snapshot.colorHex,
          'finish': snapshot.finish,
          'foundationDepth': snapshot.foundationDepth,
          'foundationUndertone': snapshot.foundationUndertone,
        };

  static TutorialKitProductSnapshot? _snapshotFromJson(Object? value) {
    if (value == null) return null;
    final data = _object(value, 'productSnapshot');
    return TutorialKitProductSnapshot(
      productId: _requiredString(data, 'productId'),
      category: _enum(data, 'category', TutorialStepCategory.fromCode),
      productName: _string(data, 'productName'),
      colorName: _string(data, 'colorName'),
      colorHex: _requiredString(data, 'colorHex'),
      finish: _requiredString(data, 'finish'),
      foundationDepth: _string(data, 'foundationDepth'),
      foundationUndertone: _string(data, 'foundationUndertone'),
    );
  }

  static Map<String, Object?> _object(Object? value, String name) {
    if (value is! Map) throw FormatException('$name must be an object.');
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static List<Object?> _list(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is! List) throw FormatException('$key must be an array.');
    return value.cast<Object?>();
  }

  static String _requiredString(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return value;
  }

  static String? _string(Map<String, Object?> data, String key) {
    if (data[key] == null) return null;
    return _requiredString(data, key);
  }

  static int _int(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is! int) throw FormatException('$key must be an integer.');
    return value;
  }

  static double _number(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is! num) throw FormatException('$key must be a number.');
    return value.toDouble();
  }

  static T _enum<T>(
    Map<String, Object?> data,
    String key,
    T? Function(String) parse,
  ) {
    final value = _requiredString(data, key);
    return parse(value) ?? (throw FormatException('$key is unsupported.'));
  }

  static T _named<T extends Enum>(List<T> values, String name, String field) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('$field is unsupported.');
  }
}
