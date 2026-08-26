import '../../domain/entities/personalized_tutorial.dart';
import '../../domain/entities/tutorial_face_geometry.dart';
import '../../domain/entities/tutorial_geometry_plan.dart';
import '../../domain/entities/tutorial_step_category.dart';

/// Parses `tutorial_sessions.geometry_plan_json` (validated server-side by
/// `plan-tutorial-geometry`, TF-2) into [TutorialGeometryPlan]. Parse-only:
/// the client never constructs or persists this shape itself — Gemini
/// decides it, FaceTune's backend validates and writes it.
abstract final class TutorialGeometryPlanCodec {
  static TutorialGeometryPlan fromJson(Object? value) {
    final root = _object(value, 'geometry_plan_json');
    final steps = _list(root, 'steps').map(_stepFromJson).toList();
    return TutorialGeometryPlan(steps: steps);
  }

  static TutorialCategoryGeometryPlan _stepFromJson(Object? value) {
    final data = _object(value, 'geometry plan step');
    return TutorialCategoryGeometryPlan(
      category: _enum(data, 'category', TutorialStepCategory.fromCode),
      placement: _requiredString(data, 'placement'),
      direction: _named(
        TutorialDirection.values,
        _requiredString(data, 'direction'),
        'direction',
      ),
      intensity: _named(
        TutorialIntensity.values,
        _requiredString(data, 'intensity'),
        'intensity',
      ),
      technique: _requiredString(data, 'technique'),
      confidence: _number(data, 'confidence'),
      colorHex: _string(data, 'colorHex'),
      finish: _string(data, 'finish'),
      zones: _list(data, 'zones').map(_zoneFromJson).toList(),
      paths: _list(data, 'paths').map(_pathFromJson).toList(),
      arrows: _list(data, 'arrows').map(_arrowFromJson).toList(),
    );
  }

  static TutorialGeometryZone _zoneFromJson(Object? value) {
    final data = _object(value, 'zone');
    return TutorialGeometryZone(
      shape: _enum(data, 'shape', TutorialGeometryZoneShape.fromCode),
      points: _list(data, 'points').map(_pointFromJson).toList(),
      confidence: _number(data, 'confidence'),
    );
  }

  static TutorialGeometryPath _pathFromJson(Object? value) {
    final data = _object(value, 'path');
    return TutorialGeometryPath(
      points: _list(data, 'points').map(_pointFromJson).toList(),
      confidence: _number(data, 'confidence'),
    );
  }

  static TutorialGeometryArrow _arrowFromJson(Object? value) {
    final data = _object(value, 'arrow');
    return TutorialGeometryArrow(
      from: _pointFromJson(data['from']),
      to: _pointFromJson(data['to']),
      confidence: _number(data, 'confidence'),
    );
  }

  static TutorialNormalizedPoint _pointFromJson(Object? value) {
    final data = _object(value, 'point');
    return TutorialNormalizedPoint(
      x: _number(data, 'x'),
      y: _number(data, 'y'),
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
