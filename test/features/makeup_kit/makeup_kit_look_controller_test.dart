import 'dart:async';

import 'package:facetune/features/makeup_kit/domain/entities/kit_generated_preview.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_look_repository.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_look_controller.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_look_state.dart';
import 'package:facetune/features/preview/domain/errors/preview_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'generates a validated recommendation before its isolated preview',
    () async {
      final repository = _FakeRepository();
      final controller = MakeupKitLookController(repository);
      addTearDown(controller.dispose);

      await controller.generate(analysisId: analysisId, styleCode: 'soft_glam');

      expect(controller.state.status, MakeupKitLookStatus.success);
      expect(repository.recommendationCalls, 1);
      expect(repository.previewCalls, 1);
      expect(controller.state.preview?.kitRecommendationId, recommendationId);
    },
  );

  test(
    'variation reuses the validated plan and retains a failed prior result',
    () async {
      final repository = _FakeRepository(failSecondPreview: true);
      final controller = MakeupKitLookController(repository);
      addTearDown(controller.dispose);

      await controller.generate(analysisId: analysisId, styleCode: 'soft_glam');
      final first = controller.state.preview;
      await controller.generateVariation();

      expect(repository.recommendationCalls, 1);
      expect(repository.previewCalls, 2);
      expect(controller.state.status, MakeupKitLookStatus.failure);
      expect(controller.state.previousPreview, same(first));
    },
  );

  test(
    'duplicate taps while generation is active do not duplicate AI calls',
    () async {
      final repository = _BlockingRepository();
      final controller = MakeupKitLookController(repository);
      addTearDown(controller.dispose);

      final first = controller.generate(
        analysisId: analysisId,
        styleCode: 'soft_glam',
      );
      await Future<void>.delayed(Duration.zero);
      await controller.generate(analysisId: analysisId, styleCode: 'soft_glam');
      await controller.retry();
      await controller.generateVariation();

      expect(repository.recommendationCalls, 1);
      repository.releaseRecommendation(recommendation);
      await Future<void>.delayed(Duration.zero);
      expect(repository.previewCalls, 1);
      repository.releasePreview(_preview(1));
      await first;
      expect(controller.state.status, MakeupKitLookStatus.success);
    },
  );

  test('clear ignores a late preview completion', () async {
    final repository = _BlockingRepository();
    final controller = MakeupKitLookController(repository);
    addTearDown(controller.dispose);

    final operation = controller.generate(
      analysisId: analysisId,
      styleCode: 'soft_glam',
    );
    repository.releaseRecommendation(recommendation);
    await Future<void>.delayed(Duration.zero);
    controller.clear();
    repository.releasePreview(_preview(1));
    await operation;

    expect(controller.state.status, MakeupKitLookStatus.idle);
  });

  test('surfaces stale inventory without silently regenerating', () async {
    final controller = MakeupKitLookController(_StaleInventoryRepository());
    addTearDown(controller.dispose);

    await controller.generate(analysisId: analysisId, styleCode: 'soft_glam');

    expect(controller.state.status, MakeupKitLookStatus.failure);
    expect(controller.state.technicalCode, 'INVENTORY_CHANGED');
    expect(controller.state.retryable, isFalse);
  });
}

const analysisId = '33333333-3333-4333-8333-333333333333';
const recommendationId = '22222222-2222-4222-8222-222222222222';
final recommendation = KitMakeupRecommendation(
  id: recommendationId,
  analysisId: analysisId,
  styleCode: 'soft_glam',
  selections: [
    KitMakeupSelection(
      productId: '11111111-1111-4111-8111-111111111111',
      category: 'lipstick',
      colorHex: '#A45B67',
      finish: 'matte',
      placement: 'Across the lips',
      technique: 'Apply a thin layer',
      intensity: 'soft',
    ),
  ],
  overallIntensity: 'soft',
  summary: 'A soft look.',
  modelId: 'gemini-3.6-flash',
  promptVersion: 'kit_makeup_recommendation_v2',
  createdAt: DateTime.utc(2026, 8, 13),
);

KitGeneratedPreview _preview(int number) => KitGeneratedPreview(
  id: 'preview-$number',
  analysisId: analysisId,
  kitRecommendationId: recommendationId,
  originalImagePath: 'user/analyses/$analysisId/original/image.jpg',
  generatedImagePath:
      'user/analyses/$analysisId/kit-generated/$recommendationId/preview_$number.png',
  originalImageUrl: 'https://signed.example/original',
  generatedImageUrl: 'https://signed.example/generated-$number',
  generationNumber: number,
  modelId: 'gemini-3.1-flash-image',
  promptVersion: 'kit_makeup_preview_v1',
  createdAt: DateTime.utc(2026, 8, 13),
);

class _FakeRepository implements MakeupKitLookRepository {
  _FakeRepository({this.failSecondPreview = false});

  final bool failSecondPreview;
  int recommendationCalls = 0;
  int previewCalls = 0;

  @override
  Future<KitMakeupRecommendation> generateRecommendation({
    required String analysisId,
    required String styleCode,
  }) async {
    recommendationCalls++;
    return recommendation;
  }

  @override
  Future<KitGeneratedPreview> generatePreview({
    required KitMakeupRecommendation recommendation,
  }) async {
    previewCalls++;
    if (failSecondPreview && previewCalls == 2) {
      throw const PreviewFailure(
        PreviewFailureType.gemini,
        'Preview failed.',
        retryable: true,
      );
    }
    return _preview(previewCalls);
  }
}

class _BlockingRepository implements MakeupKitLookRepository {
  final _recommendation = Completer<KitMakeupRecommendation>();
  final _preview = Completer<KitGeneratedPreview>();
  int recommendationCalls = 0;
  int previewCalls = 0;

  void releaseRecommendation(KitMakeupRecommendation value) =>
      _recommendation.complete(value);

  void releasePreview(KitGeneratedPreview value) => _preview.complete(value);

  @override
  Future<KitMakeupRecommendation> generateRecommendation({
    required String analysisId,
    required String styleCode,
  }) {
    recommendationCalls++;
    return _recommendation.future;
  }

  @override
  Future<KitGeneratedPreview> generatePreview({
    required KitMakeupRecommendation recommendation,
  }) {
    previewCalls++;
    return _preview.future;
  }
}

class _StaleInventoryRepository extends _FakeRepository {
  @override
  Future<KitGeneratedPreview> generatePreview({
    required KitMakeupRecommendation recommendation,
  }) => throw const PreviewFailure(
    PreviewFailureType.validation,
    'A selected product was edited or removed.',
    technicalCode: 'INVENTORY_CHANGED',
  );
}
