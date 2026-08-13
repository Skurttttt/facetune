import 'package:facetune/features/makeup_kit/data/models/kit_generated_preview_dto.dart';
import 'package:facetune/features/makeup_kit/data/models/kit_makeup_recommendation_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses an exact owned-product plan and kit preview discriminator', () {
    final recommendation = KitMakeupRecommendationDto.fromResponse(
      recommendationResponse,
    ).recommendation;
    final preview = KitGeneratedPreviewDto.fromResponse(previewResponse);

    expect(recommendation.selections.single.productId, productId);
    expect(recommendation.selections.single.colorHex, '#A45B67');
    expect(preview.kitRecommendationId, recommendation.id);
    expect(preview.generationNumber, 1);
  });

  test('rejects a standard preview response at the kit boundary', () {
    final response = Map<String, Object?>.from(previewResponse);
    final preview = Map<String, Object?>.from(response['preview']! as Map);
    preview['mode'] = 'standard';
    response['preview'] = preview;

    expect(
      () => KitGeneratedPreviewDto.fromResponse(response),
      throwsFormatException,
    );
  });
}

const productId = '11111111-1111-4111-8111-111111111111';
const recommendationId = '22222222-2222-4222-8222-222222222222';
const analysisId = '33333333-3333-4333-8333-333333333333';

const recommendationResponse = <String, Object?>{
  'recommendation': <String, Object?>{
    'id': recommendationId,
    'analysisId': analysisId,
    'style': 'soft_glam',
    'plan': <String, Object?>{
      'selections': <Object?>[
        <String, Object?>{
          'productId': productId,
          'category': 'lipstick',
          'colorHex': '#A45B67',
          'finish': 'matte',
          'placement': 'Across the lips',
          'technique': 'Apply a thin layer',
          'intensity': 'soft',
          'reasoning': 'Matches the style',
        },
      ],
      'categoryCoverage': <Object?>[],
      'overallIntensity': 'soft',
      'summary': 'A soft owned-product look.',
    },
    'productSnapshot': <Object?>[],
    'modelId': 'gemini-3.6-flash',
    'promptVersion': 'kit_makeup_recommendation_v2',
    'createdAt': '2026-08-13T03:00:00Z',
  },
};

const previewResponse = <String, Object?>{
  'preview': <String, Object?>{
    'id': '44444444-4444-4444-8444-444444444444',
    'mode': 'makeup_kit',
    'analysisId': analysisId,
    'kitRecommendationId': recommendationId,
    'originalImagePath': 'user/analyses/$analysisId/original/image.jpg',
    'generatedImagePath':
        'user/analyses/$analysisId/kit-generated/$recommendationId/preview_0001.png',
    'generationNumber': 1,
    'modelId': 'gemini-3.1-flash-image',
    'promptVersion': 'kit_makeup_preview_v1',
    'createdAt': '2026-08-13T03:05:00Z',
  },
};
