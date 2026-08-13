import '../../domain/entities/kit_generated_preview.dart';

class KitGeneratedPreviewDto {
  const KitGeneratedPreviewDto({
    required this.id,
    required this.analysisId,
    required this.kitRecommendationId,
    required this.originalImagePath,
    required this.generatedImagePath,
    required this.generationNumber,
    required this.modelId,
    required this.promptVersion,
    required this.createdAt,
  });

  final String id;
  final String analysisId;
  final String kitRecommendationId;
  final String originalImagePath;
  final String generatedImagePath;
  final int generationNumber;
  final String modelId;
  final String promptVersion;
  final DateTime createdAt;

  factory KitGeneratedPreviewDto.fromResponse(Object? payload) {
    final root = _object(payload, 'response');
    final data = _object(root['preview'], 'preview');
    if (_string(data, 'mode') != 'makeup_kit') {
      throw const FormatException('preview mode is invalid.');
    }
    final generationNumber = data['generationNumber'];
    if (generationNumber is! int || generationNumber <= 0) {
      throw const FormatException('generationNumber is invalid.');
    }
    return KitGeneratedPreviewDto(
      id: _string(data, 'id'),
      analysisId: _string(data, 'analysisId'),
      kitRecommendationId: _string(data, 'kitRecommendationId'),
      originalImagePath: _string(data, 'originalImagePath'),
      generatedImagePath: _string(data, 'generatedImagePath'),
      generationNumber: generationNumber,
      modelId: _string(data, 'modelId'),
      promptVersion: _string(data, 'promptVersion'),
      createdAt: DateTime.parse(_string(data, 'createdAt')).toUtc(),
    );
  }

  KitGeneratedPreview toDomain({
    required String originalImageUrl,
    required String generatedImageUrl,
  }) => KitGeneratedPreview(
    id: id,
    analysisId: analysisId,
    kitRecommendationId: kitRecommendationId,
    originalImagePath: originalImagePath,
    generatedImagePath: generatedImagePath,
    originalImageUrl: originalImageUrl,
    generatedImageUrl: generatedImageUrl,
    generationNumber: generationNumber,
    modelId: modelId,
    promptVersion: promptVersion,
    createdAt: createdAt,
  );

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
}
