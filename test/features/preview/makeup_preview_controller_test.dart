import 'package:facetune/features/preview/domain/entities/generated_preview.dart';
import 'package:facetune/features/preview/domain/repositories/makeup_preview_repository.dart';
import 'package:facetune/features/preview/domain/usecases/generate_makeup_preview.dart';
import 'package:facetune/features/preview/presentation/controllers/makeup_preview_controller.dart';
import 'package:facetune/features/preview/presentation/controllers/makeup_preview_state.dart';
import 'package:facetune/features/recommendation/data/models/makeup_recommendation_dto.dart';
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/recommendation_response_fixture.dart';

void main() {
  test('supports sequential variations for one recommendation', () async {
    final repository = _FakePreviewRepository();
    final controller = MakeupPreviewController(
      GenerateMakeupPreview(repository),
    );
    addTearDown(controller.dispose);
    final recommendation = MakeupRecommendationDto.fromResponse(
      validRecommendationResponse,
    ).recommendation;

    await controller.generate(recommendation: recommendation);
    expect(controller.state.preview?.generationNumber, 1);

    await controller.generateVariation();
    expect(controller.state.status, MakeupPreviewStatus.success);
    expect(controller.state.preview?.generationNumber, 2);
    expect(repository.calls, 2);
  });

  test(
    'restored results retain their recommendation for regeneration',
    () async {
      final repository = _FakePreviewRepository();
      final controller = MakeupPreviewController(
        GenerateMakeupPreview(repository),
      );
      addTearDown(controller.dispose);
      final recommendation = MakeupRecommendationDto.fromResponse(
        validRecommendationResponse,
      ).recommendation;
      final restoredPreview = await repository.generate(
        recommendation: recommendation,
      );
      repository.calls = 0;

      controller.restore(restoredPreview, recommendation: recommendation);
      await controller.generateVariation();

      expect(repository.calls, 1);
      expect(controller.state.status, MakeupPreviewStatus.success);
    },
  );
}

class _FakePreviewRepository implements MakeupPreviewRepository {
  int calls = 0;

  @override
  Future<GeneratedPreview> generate({
    required MakeupRecommendation recommendation,
  }) async {
    calls += 1;
    return GeneratedPreview(
      id: 'preview-$calls',
      analysisId: recommendation.analysisId,
      recommendationId: recommendation.id,
      originalImagePath: 'user/analyses/id/original/image.jpg',
      generatedImagePath: 'user/analyses/id/generated/preview_$calls.png',
      originalImageUrl: 'https://signed.example/original',
      generatedImageUrl: 'https://signed.example/preview-$calls',
      generationNumber: calls,
      modelId: 'gemini-3.1-flash-image',
      promptVersion: 'makeup_preview_v1',
      createdAt: DateTime.utc(2026, 8, 11),
    );
  }
}
