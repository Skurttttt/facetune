import '../../makeup_kit/domain/entities/makeup_kit_category.dart';
import '../../makeup_kit/domain/entities/makeup_kit_finish.dart';
import '../../makeup_kit/domain/value_objects/normalized_hex_color.dart';
import '../domain/catalog/custom_palette_catalog.dart';
import '../domain/entities/custom_palette_look.dart';

Map<String, Object?> _object(Object? value, String name) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw FormatException('$name is not an object.');
}

String _text(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('$key is missing.');
}

DateTime _time(Map<String, Object?> row, String key) =>
    DateTime.parse(_text(row, key));

/// Parses stored palette and plan values. Strict: a value outside the contract
/// is refused rather than shown, because this is the record of what the user
/// chose.
abstract final class CustomPaletteDtos {
  static List<CustomPaletteShade> palette(Object? value) {
    if (value is! List || value.isEmpty) {
      throw const FormatException('The palette is empty.');
    }
    return List.unmodifiable(
      value.map((raw) {
        final row = _object(raw, 'palette selection');
        final category = MakeupKitCategory.fromCode(
          _text(row, 'category_code'),
        );
        if (category == null || !CustomPaletteCatalog.isSupported(category)) {
          throw const FormatException('Unsupported palette category.');
        }
        final finish = MakeupKitFinish.fromCode(_text(row, 'finish_code'));
        if (finish == null ||
            !CustomPaletteCatalog.finishesFor(category).contains(finish)) {
          throw const FormatException('Unsupported palette finish.');
        }
        return CustomPaletteShade(
          category: category,
          baseColor: NormalizedHexColor.parse(_text(row, 'base_color_value')),
          adjustedColor: NormalizedHexColor.parse(
            _text(row, 'adjusted_color_value'),
          ),
          colorLabel: _text(row, 'color_label'),
          finish: finish,
        );
      }),
    );
  }

  static List<CustomPaletteApplication> applications(Object? plan) {
    final root = _object(plan, 'plan');
    final raw = root['applications'];
    if (raw is! List) throw const FormatException('The plan is malformed.');
    return List.unmodifiable(
      raw.map((entry) {
        final row = _object(entry, 'application');
        return CustomPaletteApplication(
          categoryCode: _text(row, 'categoryCode'),
          placement: _text(row, 'placement'),
          technique: _text(row, 'technique'),
          intensity: _text(row, 'intensity'),
          reasoning: _text(row, 'reasoning'),
        );
      }),
    );
  }

  /// From the Edge Function's response or a table row, normalized by the caller.
  static CustomPaletteRecommendation recommendation({
    required String id,
    required String analysisId,
    required String styleCode,
    required Object? palette,
    required Object? plan,
    required String modelId,
    required String promptVersion,
    required String createdAt,
    String? derivedFromPaletteId,
  }) {
    final root = _object(plan, 'plan');
    return CustomPaletteRecommendation(
      id: id,
      analysisId: analysisId,
      styleCode: styleCode,
      palette: CustomPaletteDtos.palette(palette),
      applications: applications(root),
      overallIntensity: _text(root, 'overallIntensity'),
      summary: _text(root, 'summary'),
      modelId: modelId,
      promptVersion: promptVersion,
      createdAt: DateTime.parse(createdAt),
      derivedFromPaletteId: derivedFromPaletteId,
    );
  }

  static CustomPaletteRecommendation recommendationFromResponse(
    Object? response,
  ) {
    final root = _object(response, 'response');
    final row = _object(root['recommendation'], 'recommendation');
    return recommendation(
      id: _text(row, 'id'),
      analysisId: _text(row, 'analysisId'),
      styleCode: _text(row, 'style'),
      palette: row['palette'],
      plan: row['plan'],
      modelId: _text(row, 'modelId'),
      promptVersion: _text(row, 'promptVersion'),
      createdAt: _text(row, 'createdAt'),
      derivedFromPaletteId: row['derivedFromPaletteId'] as String?,
    );
  }

  static CustomPaletteRecommendation recommendationFromRow(
    Map<String, Object?> row,
  ) => recommendation(
    id: _text(row, 'id'),
    analysisId: _text(row, 'analysis_id'),
    styleCode: _text(row, 'makeup_style'),
    palette: row['palette_snapshot_json'],
    plan: row['recommendation_json'],
    modelId: _text(row, 'model_name'),
    promptVersion: _text(row, 'prompt_version'),
    createdAt: _text(row, 'created_at'),
    derivedFromPaletteId: row['derived_from_palette_id'] as String?,
  );
}

/// The preview's stored facts, before its private images are signed.
class CustomPalettePreviewDto {
  const CustomPalettePreviewDto({
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

  factory CustomPalettePreviewDto.fromResponse(Object? response) {
    final root = _object(response, 'response');
    final row = _object(root['preview'], 'preview');
    if (row['mode'] != customColorPaletteSourceMode) {
      throw const FormatException('The preview is from another mode.');
    }
    return CustomPalettePreviewDto(
      id: _text(row, 'id'),
      analysisId: _text(row, 'analysisId'),
      recommendationId: _text(row, 'customPaletteRecommendationId'),
      originalImagePath: _text(row, 'originalImagePath'),
      generatedImagePath: _text(row, 'generatedImagePath'),
      generationNumber: row['generationNumber'] as int,
      modelId: _text(row, 'modelId'),
      promptVersion: _text(row, 'promptVersion'),
      createdAt: _time(row, 'createdAt'),
    );
  }

  factory CustomPalettePreviewDto.fromRow(
    Map<String, Object?> row, {
    required String originalImagePath,
  }) => CustomPalettePreviewDto(
    id: _text(row, 'id'),
    analysisId: _text(row, 'analysis_id'),
    recommendationId: _text(row, 'custom_palette_recommendation_id'),
    originalImagePath: originalImagePath,
    generatedImagePath: _text(row, 'storage_path'),
    generationNumber: row['generation_number'] as int,
    modelId: _text(row, 'model_name'),
    promptVersion: _text(row, 'prompt_version'),
    createdAt: _time(row, 'created_at'),
  );

  final String id;
  final String analysisId;
  final String recommendationId;
  final String originalImagePath;
  final String generatedImagePath;
  final int generationNumber;
  final String modelId;
  final String promptVersion;
  final DateTime createdAt;

  CustomPaletteGeneratedPreview toDomain({
    required String originalImageUrl,
    required String generatedImageUrl,
  }) => CustomPaletteGeneratedPreview(
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
}
