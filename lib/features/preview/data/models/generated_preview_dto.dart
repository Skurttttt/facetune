import '../../domain/entities/generated_preview.dart';

class GeneratedPreviewDto {
  const GeneratedPreviewDto({
    required this.id,
    required this.analysisId,
    required this.recommendationId,
    required this.originalImagePath,
    required this.generatedImagePath,
    required this.generationNumber,
    required this.modelId,
    required this.promptVersion,
    required this.createdAt,
  });

  final String id;
  final String analysisId;
  final String recommendationId;
  final String originalImagePath;
  final String generatedImagePath;
  final int generationNumber;
  final String modelId;
  final String promptVersion;
  final DateTime createdAt;

  factory GeneratedPreviewDto.fromResponse(Object? payload) {
    final root = _object(payload, 'response');
    final data = _object(root['preview'], 'preview');
    final generationNumber = data['generationNumber'];
    if (generationNumber is! int || generationNumber <= 0) {
      throw const FormatException('generationNumber is invalid.');
    }
    return GeneratedPreviewDto(
      id: _string(data, 'id'),
      analysisId: _string(data, 'analysisId'),
      recommendationId: _string(data, 'recommendationId'),
      originalImagePath: _string(data, 'originalImagePath'),
      generatedImagePath: _string(data, 'generatedImagePath'),
      generationNumber: generationNumber,
      modelId: _string(data, 'modelId'),
      promptVersion: _string(data, 'promptVersion'),
      createdAt: DateTime.parse(_string(data, 'createdAt')).toUtc(),
    );
  }

  GeneratedPreview toDomain({
    required String originalImageUrl,
    required String generatedImageUrl,
  }) => GeneratedPreview(
    id: id,
    analysisId: analysisId,
    recommendationId: recommendationId,
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
