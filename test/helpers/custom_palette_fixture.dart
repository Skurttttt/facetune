import 'dart:async';

import 'package:facetune/features/custom_palette/data/custom_palette_dtos.dart';
import 'package:facetune/features/custom_palette/domain/entities/custom_palette_look.dart';
import 'package:facetune/features/custom_palette/domain/repositories/custom_palette_gateway.dart';
import 'package:facetune/features/custom_palette/domain/validation/custom_palette_contract.dart';

const customPaletteFixtureAnalysisId = 'analysis-1';

Map<String, Object?> paletteRow({
  String category = 'blush',
  String base = '#C8102E',
  String adjusted = '#D93A52',
  String label = 'Red',
  String finish = 'matte',
}) => {
  'category_code': category,
  'base_color_value': base,
  'adjusted_color_value': adjusted,
  'color_label': label,
  'finish_code': finish,
};

Map<String, Object?> applicationRow(String category) => {
  'categoryCode': category,
  'placement': 'Along the upper cheekbones.',
  'technique': 'Blend outward in light layers.',
  'intensity': 'medium',
  'reasoning': 'This suits the selected style.',
};

CustomPaletteRecommendation paletteRecommendation({
  String id = 'palette-1',
  String analysisId = customPaletteFixtureAnalysisId,
  String styleCode = 'soft_glam',
  List<Map<String, Object?>>? palette,
  String? derivedFrom,
}) {
  final rows = palette ?? [paletteRow()];
  return CustomPaletteDtos.recommendation(
    id: id,
    analysisId: analysisId,
    styleCode: styleCode,
    palette: rows,
    plan: {
      'applications': [
        for (final row in rows) applicationRow(row['category_code']! as String),
      ],
      'overallIntensity': 'soft',
      'summary': 'A balanced look built around your chosen color.',
    },
    modelId: 'test-model',
    promptVersion: 'custom_palette_recommendation_v1',
    createdAt: '2026-11-02T00:00:00Z',
    derivedFromPaletteId: derivedFrom,
  );
}

CustomPaletteGeneratedPreview palettePreview({
  String id = 'preview-1',
  String analysisId = customPaletteFixtureAnalysisId,
  String recommendationId = 'palette-1',
  int generation = 1,
}) => CustomPaletteGeneratedPreview(
  id: id,
  analysisId: analysisId,
  recommendationId: recommendationId,
  originalImagePath: 'user/analyses/$analysisId/original/selfie.jpg',
  generatedImagePath:
      'user/analyses/$analysisId/custom-palette-generated/$recommendationId/'
      'preview_${generation.toString().padLeft(4, '0')}.png',
  originalImageUrl: 'https://example.invalid/original.jpg',
  generatedImageUrl: 'https://example.invalid/generated.png',
  generationNumber: generation,
  modelId: 'gemini-3.1-flash-image',
  promptVersion: 'custom_palette_preview_v1',
  createdAt: DateTime.utc(2026, 11, 2),
);

/// Records every request and answers as the server would.
class FakePaletteGateway implements CustomPaletteGateway {
  final requests = <CustomPaletteRequest>[];
  final operations = <String>[];
  final previewRecommendations = <String>[];
  Object? error;
  Completer<void>? gate;

  /// Consumed in order by preview calls; a failure is thrown, then cleared.
  final previewFailures = <CustomPaletteFailure>[];
  int _generation = 0;

  @override
  Future<CustomPaletteRecommendation> submit(
    CustomPaletteRequest request,
  ) async {
    requests.add(request);
    final pending = gate;
    if (pending != null) await pending.future;
    final failure = error;
    if (failure != null) throw failure;
    return paletteRecommendation(
      id: 'palette-${requests.length}',
      analysisId: request.analysisId,
      styleCode: request.styleCode,
      derivedFrom: request.derivedFromPaletteId,
      palette: [
        for (final selection in request.selections)
          paletteRow(
            category: selection.categoryCode,
            base: selection.baseColorValue!,
            adjusted: selection.adjustedColorValue!,
            label: selection.colorLabel!,
            finish: selection.finishCode!,
          ),
      ],
    );
  }

  @override
  Future<CustomPaletteGeneratedPreview> generatePreview({
    required CustomPaletteRecommendation recommendation,
    required String operationId,
  }) async {
    operations.add(operationId);
    previewRecommendations.add(recommendation.id);
    if (previewFailures.isNotEmpty) throw previewFailures.removeAt(0);
    _generation += 1;
    return palettePreview(
      id: 'preview-$_generation',
      analysisId: recommendation.analysisId,
      recommendationId: recommendation.id,
      generation: _generation,
    );
  }
}
