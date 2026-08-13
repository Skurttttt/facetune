import 'package:facetune/features/makeup_kit/data/data_sources/makeup_kit_library_remote_data_source.dart';
import 'package:facetune/features/makeup_kit/data/repositories/supabase_makeup_kit_library_repository.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_generated_preview.dart';
import 'package:facetune/features/makeup_kit/domain/errors/makeup_kit_library_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/analysis_response_fixture.dart';

void main() {
  test(
    'save and reopen use immutable snapshot after product edit and deletion',
    () async {
      final remote = _FakeRemote();
      final repository = SupabaseMakeupKitLibraryRepository(remote);

      final saved = await repository.save(_preview);
      expect(
        saved.result.recommendation.productSnapshots.single.productName,
        'Original foundation',
      );
      expect(
        saved.result.recommendation.productSnapshots.single.colorHex,
        '#C99578',
      );

      remote.activeProductName = 'Edited foundation';
      final reopened = (await repository.loadSavedPage(
        offset: 0,
        limit: 12,
      )).items.single;
      expect(
        reopened.result.recommendation.productSnapshots.single.productName,
        'Original foundation',
      );

      remote.activeProductName = null;
      final historical = (await repository.loadHistoryPage(
        offset: 0,
        limit: 12,
      )).items.single;
      final snapshot = historical.result.recommendation.productSnapshots.single;
      expect(snapshot.productName, 'Original foundation');
      expect(snapshot.foundationDepth, 'medium');
      expect(snapshot.foundationUndertone, 'warm');
      expect(historical.savedLook?.id, 'saved-1');
    },
  );

  test(
    'session deletion delegates to linked storage cleanup operation',
    () async {
      final remote = _FakeRemote();
      final repository = SupabaseMakeupKitLibraryRepository(remote);

      await repository.deleteSession(analysisId);

      expect(remote.deletedAnalysisId, analysisId);
    },
  );

  test(
    'rejects a cross-account row even if a remote query returns it',
    () async {
      final repository = SupabaseMakeupKitLibraryRepository(
        _CrossAccountRemote(),
      );

      await expectLater(
        repository.loadHistoryPage(offset: 0, limit: 12),
        throwsA(
          isA<MakeupKitLibraryFailure>().having(
            (failure) => failure.retryable,
            'retryable',
            isFalse,
          ),
        ),
      );
    },
  );
}

const analysisId = '33333333-3333-4333-8333-333333333333';
const recommendationId = '22222222-2222-4222-8222-222222222222';
const previewId = '44444444-4444-4444-8444-444444444444';
const productId = '11111111-1111-4111-8111-111111111111';

final _preview = KitGeneratedPreview(
  id: previewId,
  analysisId: analysisId,
  kitRecommendationId: recommendationId,
  originalImagePath: 'user/analyses/$analysisId/original/image.jpg',
  generatedImagePath:
      'user/analyses/$analysisId/kit-generated/$recommendationId/preview.png',
  originalImageUrl: 'https://signed.example/original',
  generatedImageUrl: 'https://signed.example/preview',
  generationNumber: 1,
  modelId: 'gemini-image',
  promptVersion: 'kit_makeup_preview_v1',
  createdAt: DateTime.utc(2026, 8, 14),
);

class _FakeRemote implements MakeupKitLibraryRemoteDataSource {
  String? activeProductName = 'Original foundation';
  String? deletedAnalysisId;
  Map<String, Object?>? savedRow;

  @override
  String? get currentUserId => 'user-1';

  @override
  Future<Map<String, Object?>?> findSaved(String kitGeneratedImageId) async =>
      savedRow;

  @override
  Future<Map<String, Object?>> insertSaved({
    required String userId,
    required String kitGeneratedImageId,
    required bool favorite,
  }) async {
    savedRow = _savedRow(favorite);
    return savedRow!;
  }

  @override
  Future<List<Map<String, Object?>>> selectSaved({
    required int offset,
    required int limit,
  }) async => savedRow == null ? [] : [savedRow!];

  @override
  Future<List<Map<String, Object?>>> selectHistoryPreviews({
    required int offset,
    required int limit,
  }) async => [_previewRow];

  @override
  Future<List<Map<String, Object?>>> selectPreviews(List<String> ids) async => [
    _previewRow,
  ];

  @override
  Future<List<Map<String, Object?>>> selectRecommendations(
    List<String> ids,
  ) async => [_recommendationRow];

  @override
  Future<List<Map<String, Object?>>> selectAnalyses(List<String> ids) async => [
    _analysisRow,
  ];

  @override
  Future<List<Map<String, Object?>>> selectSavedForPreviews(
    List<String> ids,
  ) async => savedRow == null ? [] : [savedRow!];

  @override
  Future<Map<String, Object?>> updateFavorite({
    required String savedLookId,
    required bool favorite,
  }) async {
    savedRow = _savedRow(favorite);
    return savedRow!;
  }

  @override
  Future<void> deleteSaved(String savedLookId) async => savedRow = null;

  @override
  Future<String> createSignedUrl(String storagePath) async =>
      'https://signed.example/$storagePath';

  @override
  Future<Object?> deleteSession(String analysisId) async {
    deletedAnalysisId = analysisId;
    return {'deleted': true, 'analysisId': analysisId};
  }

  static Map<String, Object?> _savedRow(bool favorite) => {
    'id': 'saved-1',
    'user_id': 'user-1',
    'kit_generated_image_id': previewId,
    'is_favorite': favorite,
    'created_at': '2026-08-14T06:00:00Z',
  };

  static final Map<String, Object?> _previewRow = {
    'id': previewId,
    'user_id': 'user-1',
    'analysis_id': analysisId,
    'kit_recommendation_id': recommendationId,
    'storage_path':
        'user/analyses/$analysisId/kit-generated/$recommendationId/preview.png',
    'generation_number': 1,
    'model_name': 'gemini-image',
    'prompt_version': 'kit_makeup_preview_v1',
    'created_at': '2026-08-14T05:00:00Z',
  };

  static final Map<String, Object?> _recommendationRow = {
    'id': recommendationId,
    'user_id': 'user-1',
    'analysis_id': analysisId,
    'makeup_style': 'soft_glam',
    'recommendation_json': {
      'selections': [
        {
          'productId': productId,
          'category': 'foundation',
          'colorHex': '#C99578',
          'finish': 'natural',
          'placement': 'Thin layer across the face',
          'technique': 'Blend lightly',
          'intensity': 'soft',
          'reasoning': 'Uses owned foundation',
        },
      ],
      'categoryCoverage': [],
      'overallIntensity': 'soft',
      'summary': 'A soft kit look.',
    },
    'product_snapshot_json': [
      {
        'productId': productId,
        'category': 'foundation',
        'productName': 'Original foundation',
        'colorHex': '#C99578',
        'colorLabel': 'Warm beige',
        'finish': 'natural',
        'foundationDepth': 'medium',
        'foundationUndertone': 'warm',
      },
    ],
    'model_name': 'gemini-flash',
    'prompt_version': 'kit_makeup_recommendation_v2',
    'created_at': '2026-08-14T04:00:00Z',
  };

  static Map<String, Object?> get _analysisRow {
    final source = validAnalysisResponse['analysis']! as Map<String, Object?>;
    final attributes = source['attributes']! as Map<String, Object?>;
    return {
      'id': analysisId,
      'user_id': 'user-1',
      'original_image_path': 'user/analyses/$analysisId/original/image.jpg',
      'face_shape': attributes['faceShape'],
      'skin_tone': attributes['skinTone'],
      'undertone': attributes['undertone'],
      'eye_shape': attributes['eyeShape'],
      'lip_shape': attributes['lipShape'],
      'hair_color': attributes['hairColor'],
      'eye_color': attributes['eyeColor'],
      'confidence_json': source['confidence'],
      'raw_ai_metadata': {'validation': source['validation']},
      'model_name': source['modelId'],
      'prompt_version': source['promptVersion'],
      'created_at': '2026-08-14T03:00:00Z',
    };
  }
}

class _CrossAccountRemote extends _FakeRemote {
  @override
  Future<List<Map<String, Object?>>> selectHistoryPreviews({
    required int offset,
    required int limit,
  }) async => [
    {..._FakeRemote._previewRow, 'user_id': 'another-user'},
  ];
}
