import 'package:facetune/features/makeup_kit/data/data_sources/makeup_kit_look_remote_data_source.dart';
import 'package:facetune/features/makeup_kit/data/repositories/supabase_makeup_kit_look_repository.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/preview/domain/errors/preview_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('requires authentication before invoking a kit Edge Function', () async {
    final remote = _FakeLookRemote(userId: null);
    final repository = SupabaseMakeupKitLookRepository(remote);

    await expectLater(
      repository.generateRecommendation(
        analysisId: _analysisId,
        styleCode: 'soft_glam',
      ),
      throwsA(
        isA<PreviewFailure>().having(
          (failure) => failure.type,
          'type',
          PreviewFailureType.authentication,
        ),
      ),
    );
    expect(remote.recommendationCalls, 0);
  });

  test('status-zero function failure is treated as offline', () async {
    final remote = _FakeLookRemote(
      recommendationError: const MakeupKitLookRemoteFailure(
        status: 0,
        code: '',
        message: 'internal transport detail',
        retryable: false,
      ),
    );
    final repository = SupabaseMakeupKitLookRepository(remote);

    await expectLater(
      repository.generateRecommendation(
        analysisId: _analysisId,
        styleCode: 'soft_glam',
      ),
      throwsA(
        isA<PreviewFailure>()
            .having(
              (failure) => failure.type,
              'type',
              PreviewFailureType.network,
            )
            .having((failure) => failure.retryable, 'retryable', isTrue)
            .having(
              (failure) => failure.message,
              'message',
              isNot(contains('internal transport detail')),
            ),
      ),
    );
  });

  test('expired signed-URL session is surfaced as authentication', () async {
    final remote = _FakeLookRemote(
      previewResponse: _previewResponse,
      signedUrlError: const StorageException('expired', statusCode: '401'),
    );
    final repository = SupabaseMakeupKitLookRepository(remote);

    await expectLater(
      repository.generatePreview(recommendation: _recommendation),
      throwsA(
        isA<PreviewFailure>().having(
          (failure) => failure.type,
          'type',
          PreviewFailureType.authentication,
        ),
      ),
    );
  });
}

const _analysisId = '33333333-3333-4333-8333-333333333333';
const _recommendationId = '22222222-2222-4222-8222-222222222222';

final _recommendation = KitMakeupRecommendation(
  id: _recommendationId,
  analysisId: _analysisId,
  styleCode: 'soft_glam',
  selections: const [
    KitMakeupSelection(
      productId: '11111111-1111-4111-8111-111111111111',
      category: 'lipstick',
      colorHex: '#A45B67',
      finish: 'matte',
      placement: 'Across lips',
      technique: 'Apply lightly',
      intensity: 'soft',
    ),
  ],
  productSnapshots: const [
    KitProductSnapshot(
      productId: '11111111-1111-4111-8111-111111111111',
      category: 'lipstick',
      colorHex: '#A45B67',
      finish: 'matte',
    ),
  ],
  overallIntensity: 'soft',
  summary: 'A soft look.',
  modelId: 'model',
  promptVersion: 'prompt',
  createdAt: DateTime.utc(2026, 8, 14),
);

final _previewResponse = {
  'preview': {
    'id': '44444444-4444-4444-8444-444444444444',
    'mode': 'makeup_kit',
    'analysisId': _analysisId,
    'kitRecommendationId': _recommendationId,
    'originalImagePath': 'user/analyses/$_analysisId/original/image.jpg',
    'generatedImagePath':
        'user/analyses/$_analysisId/kit-generated/preview.png',
    'generationNumber': 1,
    'modelId': 'model',
    'promptVersion': 'prompt',
    'createdAt': '2026-08-14T00:00:00Z',
  },
};

class _FakeLookRemote implements MakeupKitLookRemoteDataSource {
  _FakeLookRemote({
    this.userId = 'user-1',
    this.recommendationError,
    this.previewResponse,
    this.signedUrlError,
  });

  final String? userId;
  final Object? recommendationError;
  final Object? previewResponse;
  final Object? signedUrlError;
  int recommendationCalls = 0;

  @override
  String? get currentUserId => userId;

  @override
  Future<Object?> generateRecommendation({
    required String analysisId,
    required String styleCode,
  }) async {
    recommendationCalls++;
    if (recommendationError != null) throw recommendationError!;
    throw UnimplementedError();
  }

  @override
  Future<Object?> generatePreview({
    required String kitRecommendationId,
  }) async => previewResponse ?? (throw UnimplementedError());

  @override
  Future<String> createSignedUrl(String storagePath) async {
    if (signedUrlError != null) throw signedUrlError!;
    return 'https://signed.example/$storagePath';
  }
}
