import '../../domain/entities/analysis_confidence.dart';
import '../../domain/entities/face_analysis.dart';
import '../../domain/entities/facial_attributes.dart';
import '../../domain/entities/secure_image_validation.dart';

class FaceAnalysisDto {
  const FaceAnalysisDto(this.analysis);

  final FaceAnalysis analysis;

  factory FaceAnalysisDto.fromResponse(Object? payload) {
    final root = _object(payload, 'response');
    final data = _object(root['analysis'], 'analysis');
    final validation = _object(data['validation'], 'validation');
    final attributes = _object(data['attributes'], 'attributes');
    final confidence = _object(data['confidence'], 'confidence');
    return FaceAnalysisDto(
      FaceAnalysis(
        id: _string(data, 'id'),
        originalImagePath: _string(data, 'originalImagePath'),
        validation: SecureImageValidation(
          faceCount: _integer(validation, 'faceCount'),
          lightingAcceptable: _boolean(validation, 'lightingAcceptable'),
          sharpnessAcceptable: _boolean(validation, 'sharpnessAcceptable'),
          faceVisible: _boolean(validation, 'faceVisible'),
          framingAcceptable: _boolean(validation, 'framingAcceptable'),
        ),
        attributes: FacialAttributes(
          faceShape: _enumValue(attributes, 'faceShape', _faceShapes),
          skinTone: _enumValue(attributes, 'skinTone', _skinTones),
          undertone: _enumValue(attributes, 'undertone', _undertones),
          eyeShape: _enumValue(attributes, 'eyeShape', _eyeShapes),
          lipShape: _enumValue(attributes, 'lipShape', _lipShapes),
          hairColor: _enumValue(attributes, 'hairColor', _hairColors),
          eyeColor: _enumValue(attributes, 'eyeColor', _eyeColors),
        ),
        confidence: AnalysisConfidence(
          faceShape: _score(confidence, 'faceShape'),
          skinTone: _score(confidence, 'skinTone'),
          undertone: _score(confidence, 'undertone'),
          eyeShape: _score(confidence, 'eyeShape'),
          lipShape: _score(confidence, 'lipShape'),
          hairColor: _score(confidence, 'hairColor'),
          eyeColor: _score(confidence, 'eyeColor'),
        ),
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
    return value;
  }

  static int _integer(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is! int || value < 0) throw FormatException('$key is invalid.');
    return value;
  }

  static bool _boolean(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is! bool) throw FormatException('$key must be a boolean.');
    return value;
  }

  static double _score(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is! num || !value.isFinite || value < 0 || value > 1) {
      throw FormatException('$key confidence is invalid.');
    }
    return value.toDouble();
  }

  static T _enumValue<T>(
    Map<String, Object?> data,
    String key,
    Map<String, T> values,
  ) {
    final value = data[key];
    if (value is! String || !values.containsKey(value)) {
      throw FormatException('$key contains an unsupported value.');
    }
    return values[value] as T;
  }

  static const _faceShapes = {
    'oval': FaceShape.oval,
    'round': FaceShape.round,
    'square': FaceShape.square,
    'heart': FaceShape.heart,
    'oblong': FaceShape.oblong,
    'diamond': FaceShape.diamond,
    'triangle': FaceShape.triangle,
  };
  static const _skinTones = {
    'very_light': SkinTone.veryLight,
    'light': SkinTone.light,
    'medium': SkinTone.medium,
    'tan': SkinTone.tan,
    'deep': SkinTone.deep,
    'very_deep': SkinTone.veryDeep,
  };
  static const _undertones = {
    'warm': Undertone.warm,
    'cool': Undertone.cool,
    'neutral': Undertone.neutral,
    'olive': Undertone.olive,
  };
  static const _eyeShapes = {
    'almond': EyeShape.almond,
    'round': EyeShape.round,
    'hooded': EyeShape.hooded,
    'monolid': EyeShape.monolid,
    'upturned': EyeShape.upturned,
    'downturned': EyeShape.downturned,
    'deep_set': EyeShape.deepSet,
    'protruding': EyeShape.protruding,
  };
  static const _lipShapes = {
    'thin': LipShape.thin,
    'medium': LipShape.medium,
    'full': LipShape.full,
    'heart_shaped': LipShape.heartShaped,
    'wide': LipShape.wide,
    'round': LipShape.round,
  };
  static const _hairColors = {
    'black': HairColor.black,
    'dark_brown': HairColor.darkBrown,
    'brown': HairColor.brown,
    'light_brown': HairColor.lightBrown,
    'blonde': HairColor.blonde,
    'red': HairColor.red,
    'gray': HairColor.gray,
    'white': HairColor.white,
    'other': HairColor.other,
  };
  static const _eyeColors = {
    'dark_brown': EyeColor.darkBrown,
    'brown': EyeColor.brown,
    'hazel': EyeColor.hazel,
    'amber': EyeColor.amber,
    'green': EyeColor.green,
    'blue': EyeColor.blue,
    'gray': EyeColor.gray,
    'other': EyeColor.other,
  };
}
