import 'package:facetune/features/history/data/data_sources/history_remote_data_source.dart';
import 'package:facetune/features/history/data/repositories/supabase_history_repository.dart';
import 'package:facetune/features/history/domain/entities/history_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/analysis_response_fixture.dart';
import '../../helpers/generated_preview_response_fixture.dart';
import '../../helpers/recommendation_response_fixture.dart';

void main() {
  test(
    'hydrates analysis, recommendation, and preview completion stages',
    () async {
      final remote = _FakeHistoryRemoteDataSource(
        analyses: [
          _analysisRow('analysis-complete', '2026-08-11T03:00:00Z'),
          _analysisRow('recommendation-ready', '2026-08-11T02:00:00Z'),
          _analysisRow('analysis-ready', '2026-08-11T01:00:00Z'),
        ],
        recommendations: [
          _recommendationRow('rec-complete', 'analysis-complete'),
          _recommendationRow('rec-ready', 'recommendation-ready'),
        ],
        generated: [
          _generatedRow('preview-1', 'analysis-complete', 'rec-complete'),
        ],
        saved: [_savedRow('saved-1', 'preview-1')],
      );
      final repository = SupabaseHistoryRepository(remote);

      final page = await repository.loadPage(offset: 0, limit: 3);

      expect(page.items.map((entry) => entry.status), [
        HistoryCompletionStatus.complete,
        HistoryCompletionStatus.recommendationReady,
        HistoryCompletionStatus.analysisReady,
      ]);
      expect(page.items.first.isFavorite, isTrue);
      expect(page.items.first.preview?.recommendationId, 'rec-complete');
      expect(page.nextOffset, 3);
      expect(page.hasMore, isTrue);
      expect(
        remote.signedPaths,
        contains('user/analyses/analysis-ready/original/image.jpg'),
      );
    },
  );

  test('validates the authenticated deletion response', () async {
    final remote = _FakeHistoryRemoteDataSource(
      analyses: const [],
      recommendations: const [],
      generated: const [],
      saved: const [],
    );
    final repository = SupabaseHistoryRepository(remote);

    await repository.deleteSession('analysis-1');

    expect(remote.deletedAnalysisId, 'analysis-1');
  });
}

Map<String, Object?> _analysisRow(String id, String createdAt) {
  final analysis = validAnalysisResponse['analysis']! as Map<String, Object?>;
  final attributes = analysis['attributes']! as Map<String, Object?>;
  return {
    'id': id,
    'original_image_path': 'user/analyses/$id/original/image.jpg',
    'face_shape': attributes['faceShape'],
    'skin_tone': attributes['skinTone'],
    'undertone': attributes['undertone'],
    'eye_shape': attributes['eyeShape'],
    'lip_shape': attributes['lipShape'],
    'hair_color': attributes['hairColor'],
    'eye_color': attributes['eyeColor'],
    'confidence_json': analysis['confidence'],
    'raw_ai_metadata': {'validation': analysis['validation']},
    'model_name': analysis['modelId'],
    'prompt_version': analysis['promptVersion'],
    'created_at': createdAt,
  };
}

Map<String, Object?> _recommendationRow(String id, String analysisId) {
  final recommendation =
      validRecommendationResponse['recommendation']! as Map<String, Object?>;
  return {
    'id': id,
    'analysis_id': analysisId,
    'makeup_style': recommendation['style'],
    'recommendation_json': recommendation['plan'],
    'model_name': recommendation['modelId'],
    'prompt_version': recommendation['promptVersion'],
    'created_at': '2026-08-11T04:00:00Z',
  };
}

Map<String, Object?> _generatedRow(
  String id,
  String analysisId,
  String recommendationId,
) {
  final preview =
      validGeneratedPreviewResponse['preview']! as Map<String, Object?>;
  return {
    'id': id,
    'analysis_id': analysisId,
    'recommendation_id': recommendationId,
    'storage_path': 'user/analyses/$analysisId/generated/$id.png',
    'generation_number': preview['generationNumber'],
    'model_name': preview['modelId'],
    'prompt_version': preview['promptVersion'],
    'created_at': '2026-08-11T05:00:00Z',
  };
}

Map<String, Object?> _savedRow(String id, String generatedImageId) => {
  'id': id,
  'generated_image_id': generatedImageId,
  'is_favorite': true,
  'created_at': '2026-08-11T06:00:00Z',
};

class _FakeHistoryRemoteDataSource implements HistoryRemoteDataSource {
  _FakeHistoryRemoteDataSource({
    required this.analyses,
    required this.recommendations,
    required this.generated,
    required this.saved,
  });

  final List<Map<String, Object?>> analyses;
  final List<Map<String, Object?>> recommendations;
  final List<Map<String, Object?>> generated;
  final List<Map<String, Object?>> saved;
  final List<String> signedPaths = [];
  String? deletedAnalysisId;

  @override
  String? get currentUserId => 'user';

  @override
  Future<List<Map<String, Object?>>> selectAnalyses({
    required int offset,
    required int limit,
  }) async => analyses.skip(offset).take(limit).toList();

  @override
  Future<List<Map<String, Object?>>> selectRecommendations(
    List<String> analysisIds,
  ) async => recommendations;

  @override
  Future<List<Map<String, Object?>>> selectGeneratedImages(
    List<String> analysisIds,
  ) async => generated;

  @override
  Future<List<Map<String, Object?>>> selectSavedLooks(
    List<String> generatedImageIds,
  ) async => saved;

  @override
  Future<String> createSignedUrl(String storagePath) async {
    signedPaths.add(storagePath);
    return 'https://signed.example/$storagePath';
  }

  @override
  Future<Object?> deleteSession(String analysisId) async {
    deletedAnalysisId = analysisId;
    return {'deleted': true, 'analysisId': analysisId};
  }
}
