import 'dart:async';

import 'package:facetune/features/preview/domain/errors/preview_failure.dart';
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

  test('failed regeneration keeps the previous successful result', () async {
    final recommendation = MakeupRecommendationDto.fromResponse(
      validRecommendationResponse,
    ).recommendation;
    final repository = _SequencePreviewRepository();
    final controller = MakeupPreviewController(
      GenerateMakeupPreview(repository),
    );
    addTearDown(controller.dispose);

    await controller.generate(recommendation: recommendation);
    final previous = controller.state.preview;
    await controller.generateVariation();

    expect(controller.state.status, MakeupPreviewStatus.failure);
    expect(controller.state.previousPreview, same(previous));

    controller.showPreviousResult();
    expect(controller.state.status, MakeupPreviewStatus.success);
    expect(controller.state.preview, same(previous));
  });

  test('clear ignores a preview that completes late', () async {
    final completer = Completer<GeneratedPreview>();
    final controller = MakeupPreviewController(
      GenerateMakeupPreview(_PendingPreviewRepository(completer.future)),
    );
    addTearDown(controller.dispose);
    final recommendation = MakeupRecommendationDto.fromResponse(
      validRecommendationResponse,
    ).recommendation;

    final operation = controller.generate(recommendation: recommendation);
    controller.clear();
    completer.complete(_preview(recommendation, 1));
    await operation;

    expect(controller.state.status, MakeupPreviewStatus.idle);
    expect(controller.state.preview, isNull);
  });
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

class _SequencePreviewRepository implements MakeupPreviewRepository {
  int calls = 0;

  @override
  Future<GeneratedPreview> generate({
    required MakeupRecommendation recommendation,
  }) async {
    calls += 1;
    if (calls == 2) {
      throw const PreviewFailure(
        PreviewFailureType.gemini,
        'The AI service is temporarily unavailable.',
        retryable: true,
      );
    }
    return _preview(recommendation, calls);
  }
}

class _PendingPreviewRepository implements MakeupPreviewRepository {
  const _PendingPreviewRepository(this.result);

  final Future<GeneratedPreview> result;

  @override
  Future<GeneratedPreview> generate({
    required MakeupRecommendation recommendation,
  }) => result;
}

GeneratedPreview _preview(MakeupRecommendation recommendation, int number) =>
    GeneratedPreview(
      id: 'preview-$number',
      analysisId: recommendation.analysisId,
      recommendationId: recommendation.id,
      originalImagePath: 'user/analyses/id/original/image.jpg',
      generatedImagePath:
          'user/analyses/id/generated/preview_$number.png',
      originalImageUrl: 'https://signed.example/original',
      generatedImageUrl: 'https://signed.example/preview-$number',
      generationNumber: number,
      modelId: 'gemini-image',
      promptVersion: 'makeup_preview_v1',
      createdAt: DateTime.utc(2026, 8, 11),
    );
