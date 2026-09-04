import '../../domain/entities/makeup_recommendation.dart';

class MakeupRecommendationDto {
  const MakeupRecommendationDto(this.recommendation);

  final MakeupRecommendation recommendation;

  factory MakeupRecommendationDto.fromResponse(Object? payload) {
    final root = _object(payload, 'response');
    final data = _object(root['recommendation'], 'recommendation');
    final plan = _object(data['plan'], 'plan');
    const keys = [
      'foundation',
      'concealer',
      'contour',
      'highlight',
      'blush',
      'eyeshadow',
      'eyebrow',
      'eyeliner',
      'lipstick',
      'lipGloss',
    ];
    final items = <String, MakeupRecommendationItem>{};
    for (final key in keys) {
      final item = _object(plan[key], key);
      items[key] = MakeupRecommendationItem(
        name: _string(item, 'name'),
        hex: _nullableHex(item['hex'], key),
        placement: _string(item, 'placement'),
        technique: _string(item, 'technique'),
        finish: _string(item, 'finish'),
        intensity: _string(item, 'intensity'),
        reasoning: _string(item, 'reasoning'),
        education: _nullableEducation(item['education'], key),
      );
    }
    return MakeupRecommendationDto(
      MakeupRecommendation(
        id: _string(data, 'id'),
        analysisId: _string(data, 'analysisId'),
        styleCode: _string(data, 'style'),
        overallIntensity: _string(plan, 'overallIntensity'),
        items: Map.unmodifiable(items),
        modelId: _string(data, 'modelId'),
        promptVersion: _string(data, 'promptVersion'),
        createdAt: DateTime.parse(_string(data, 'createdAt')).toUtc(),
      ),
    );
  }

  static Map<String, Object?> _object(Object? value, String name) {
    if (value is! Map) throw FormatException('$name must be an object.');
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static String _string(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return value.trim();
  }

  /// The three education strings, or null when this plan predates them.
  ///
  /// Absent is a legitimate historical state, not a defect: every plan stored
  /// under `makeup_recommendation_v2` and earlier has no education object, and
  /// History, Saved Looks, and the kit library all rebuild those rows through
  /// this decoder. Returning null lets them open unchanged.
  ///
  /// Present but malformed is a different matter and still throws. A partial
  /// object — two of three sections, a non-string, an empty string — means the
  /// payload is wrong rather than old, and silently dropping it would show the
  /// user a card that claims to explain itself and then does not. Tolerating
  /// only true absence keeps "old" and "broken" from collapsing into one case.
  static MakeupRecommendationEducation? _nullableEducation(
    Object? value,
    String key,
  ) {
    if (value == null) return null;
    if (value is! Map) {
      throw FormatException('$key education must be an object.');
    }
    final education = value.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    return MakeupRecommendationEducation(
      features: _string(education, 'features'),
      effect: _string(education, 'effect'),
      style: _string(education, 'style'),
    );
  }

  static String? _nullableHex(Object? value, String key) {
    if (value == null) return null;
    if (value is! String || !RegExp(r'^#[0-9A-F]{6}$').hasMatch(value)) {
      throw FormatException('$key hex is invalid.');
    }
    return value;
  }
}
