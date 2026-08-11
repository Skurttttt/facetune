import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../analysis/data/models/face_analysis_dto.dart';
import '../../../makeup_styles/domain/catalog/makeup_style_catalog.dart';
import '../../../preview/data/models/generated_preview_dto.dart';
import '../../../recommendation/data/models/makeup_recommendation_dto.dart';
import '../../../saved_looks/domain/entities/saved_look.dart';
import '../../domain/entities/history_entry.dart';
import '../../domain/errors/history_failure.dart';
import '../../domain/repositories/history_repository.dart';
import '../data_sources/history_remote_data_source.dart';

class SupabaseHistoryRepository implements HistoryRepository {
  const SupabaseHistoryRepository(
    this._remote, {
    Duration deletionTimeout = const Duration(seconds: 30),
  }) : _deletionTimeout = deletionTimeout;

  final HistoryRemoteDataSource _remote;
  final Duration _deletionTimeout;

  @override
  Future<HistoryPageResult> loadPage({
    required int offset,
    required int limit,
  }) async {
    if (_remote.currentUserId == null) {
      throw const HistoryFailure('Sign in to view your FaceTune history.');
    }
    try {
      final analyses = await _remote.selectAnalyses(
        offset: offset,
        limit: limit,
      );
      if (analyses.isEmpty) {
        return HistoryPageResult(
          items: const [],
          hasMore: false,
          nextOffset: offset,
        );
      }
      final analysisIds = analyses
          .map((row) => _requiredString(row, 'id'))
          .toList();
      final linked = await Future.wait([
        _remote.selectRecommendations(analysisIds),
        _remote.selectGeneratedImages(analysisIds),
      ]);
      final recommendations = linked[0];
      final generatedImages = linked[1];
      final generatedIds = generatedImages
          .map((row) => _requiredString(row, 'id'))
          .toList();
      final savedLooks = await _remote.selectSavedLooks(generatedIds);
      final entries = await Future.wait(
        analyses.map(
          (analysis) => _hydrate(
            analysis,
            recommendations: recommendations,
            generatedImages: generatedImages,
            savedLooks: savedLooks,
          ),
        ),
      );
      return HistoryPageResult(
        items: List.unmodifiable(entries),
        hasMore: analyses.length == limit,
        nextOffset: offset + analyses.length,
      );
    } catch (error) {
      if (error is HistoryFailure) rethrow;
      throw _failure(error, loading: true);
    }
  }

  Future<HistoryEntry> _hydrate(
    Map<String, Object?> analysisRow, {
    required List<Map<String, Object?>> recommendations,
    required List<Map<String, Object?>> generatedImages,
    required List<Map<String, Object?>> savedLooks,
  }) async {
    final analysisId = _requiredString(analysisRow, 'id');
    final analysisRecommendations = recommendations
        .where((row) => row['analysis_id'] == analysisId)
        .toList();
    final analysisPreviews = generatedImages
        .where((row) => row['analysis_id'] == analysisId)
        .toList();
    final previewRow = analysisPreviews.firstOrNull;
    final recommendationRow = previewRow == null
        ? analysisRecommendations.firstOrNull
        : analysisRecommendations
              .where((row) => row['id'] == previewRow['recommendation_id'])
              .firstOrNull;
    final analysis = FaceAnalysisDto.fromResponse({
      'analysis': {
        'id': analysisId,
        'originalImagePath': analysisRow['original_image_path'],
        'validation': _map(analysisRow['raw_ai_metadata'])['validation'],
        'attributes': {
          'faceShape': analysisRow['face_shape'],
          'skinTone': analysisRow['skin_tone'],
          'undertone': analysisRow['undertone'],
          'eyeShape': analysisRow['eye_shape'],
          'lipShape': analysisRow['lip_shape'],
          'hairColor': analysisRow['hair_color'],
          'eyeColor': analysisRow['eye_color'],
        },
        'confidence': analysisRow['confidence_json'],
        'modelId': _fallbackString(analysisRow['model_name'], 'unknown'),
        'promptVersion': _fallbackString(
          analysisRow['prompt_version'],
          'legacy',
        ),
        'createdAt': analysisRow['created_at'],
      },
    }).analysis;

    final recommendation = recommendationRow == null
        ? null
        : MakeupRecommendationDto.fromResponse({
            'recommendation': {
              'id': recommendationRow['id'],
              'analysisId': recommendationRow['analysis_id'],
              'style': recommendationRow['makeup_style'],
              'plan': recommendationRow['recommendation_json'],
              'modelId': _fallbackString(
                recommendationRow['model_name'],
                'unknown',
              ),
              'promptVersion': _fallbackString(
                recommendationRow['prompt_version'],
                'legacy',
              ),
              'createdAt': recommendationRow['created_at'],
            },
          }).recommendation;
    final style = recommendation == null
        ? null
        : MakeupStyleCatalog.styles
              .where((candidate) => candidate.code == recommendation.styleCode)
              .firstOrNull;
    if (recommendation != null && style == null) {
      throw const FormatException('Unknown historical makeup style.');
    }

    final originalUrlFuture = _remote.createSignedUrl(
      analysis.originalImagePath,
    );
    if (previewRow == null || recommendation == null || style == null) {
      final originalUrl = await originalUrlFuture;
      return HistoryEntry(
        analysis: analysis,
        recommendation: recommendation,
        style: style,
        thumbnailUrl: originalUrl,
        status: recommendation == null
            ? HistoryCompletionStatus.analysisReady
            : HistoryCompletionStatus.recommendationReady,
        createdAt: analysis.createdAt,
        latestActivityAt: recommendation?.createdAt ?? analysis.createdAt,
      );
    }

    final generatedDto = GeneratedPreviewDto.fromResponse({
      'preview': {
        'id': previewRow['id'],
        'analysisId': previewRow['analysis_id'],
        'recommendationId': previewRow['recommendation_id'],
        'originalImagePath': analysis.originalImagePath,
        'generatedImagePath': previewRow['storage_path'],
        'generationNumber': previewRow['generation_number'],
        'modelId': _fallbackString(previewRow['model_name'], 'unknown'),
        'promptVersion': _fallbackString(
          previewRow['prompt_version'],
          'legacy',
        ),
        'createdAt': previewRow['created_at'],
      },
    });
    final urls = await Future.wait([
      originalUrlFuture,
      _remote.createSignedUrl(generatedDto.generatedImagePath),
    ]);
    final preview = generatedDto.toDomain(
      originalImageUrl: urls[0],
      generatedImageUrl: urls[1],
    );
    final savedRow = savedLooks
        .where((row) => row['generated_image_id'] == preview.id)
        .firstOrNull;
    final savedLook = savedRow == null
        ? null
        : SavedLook(
            id: _requiredString(savedRow, 'id'),
            preview: preview,
            analysis: analysis,
            recommendation: recommendation,
            style: style,
            isFavorite: savedRow['is_favorite'] == true,
            createdAt: DateTime.parse(
              _requiredString(savedRow, 'created_at'),
            ).toUtc(),
          );
    return HistoryEntry(
      analysis: analysis,
      recommendation: recommendation,
      style: style,
      preview: preview,
      savedLook: savedLook,
      thumbnailUrl: preview.generatedImageUrl,
      status: HistoryCompletionStatus.complete,
      createdAt: analysis.createdAt,
      latestActivityAt: preview.createdAt,
    );
  }

  @override
  Future<void> deleteSession(String analysisId) async {
    if (_remote.currentUserId == null) {
      throw const HistoryFailure('Sign in before deleting history.');
    }
    try {
      final response = await _remote
          .deleteSession(analysisId)
          .timeout(_deletionTimeout);
      final data = _map(response);
      if (data['deleted'] != true || data['analysisId'] != analysisId) {
        throw const FormatException('Deletion response is invalid.');
      }
    } catch (error) {
      if (error is HistoryFailure) rethrow;
      throw _failure(error, loading: false);
    }
  }

  static HistoryFailure _failure(Object error, {required bool loading}) {
    if (error is SocketException || error is TimeoutException) {
      return const HistoryFailure('Check your connection and try again.');
    }
    if (error is AuthException) {
      return const HistoryFailure('Your session expired. Sign in again.');
    }
    if (error is HistoryRemoteFailure) {
      if (error.status == 401) {
        return const HistoryFailure('Your session expired. Sign in again.');
      }
      if (error.status == 404) {
        return const HistoryFailure(
          'This history item no longer exists. Refresh your history.',
          retryable: false,
        );
      }
      return HistoryFailure(error.message, retryable: error.retryable);
    }
    if (error is PostgrestException || error is StorageException) {
      return HistoryFailure(
        loading
            ? 'Your FaceTune history could not be loaded right now.'
            : 'This history item could not be deleted right now.',
      );
    }
    if (error is FormatException) {
      return const HistoryFailure(
        'A history item contains incomplete result data.',
        retryable: false,
      );
    }
    return HistoryFailure(
      loading
          ? 'Your FaceTune history could not be loaded.'
          : 'This history item could not be deleted.',
    );
  }

  static Map<String, Object?> _map(Object? value) {
    if (value is! Map) throw const FormatException('Expected an object.');
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static String _requiredString(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key is missing.');
    }
    return value;
  }

  static String _fallbackString(Object? value, String fallback) =>
      value is String && value.trim().isNotEmpty ? value.trim() : fallback;
}
