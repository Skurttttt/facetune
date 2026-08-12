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
    Duration loadTimeout = const Duration(seconds: 30),
  }) : _deletionTimeout = deletionTimeout,
       _loadTimeout = loadTimeout;

  final HistoryRemoteDataSource _remote;
  final Duration _deletionTimeout;
  final Duration _loadTimeout;

  @override
  Future<HistoryPageResult> loadPage({
    required int offset,
    required int limit,
  }) async {
    if (_remote.currentUserId == null) {
      throw const HistoryFailure(
        'Your session expired. Sign in again.',
        retryable: false,
        sessionExpired: true,
      );
    }
    try {
      final analyses = await _remote
          .selectAnalyses(offset: offset, limit: limit)
          .timeout(_loadTimeout);
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
      ]).timeout(_loadTimeout);
      final recommendations = linked[0];
      final generatedImages = linked[1];
      final generatedIds = generatedImages
          .map((row) => _requiredString(row, 'id'))
          .toList();
      final savedLooks = await _remote
          .selectSavedLooks(generatedIds)
          .timeout(_loadTimeout);
      final entries = await Future.wait(
        analyses.map(
          (analysis) => _hydrate(
            analysis,
            recommendations: recommendations,
            generatedImages: generatedImages,
            savedLooks: savedLooks,
          ),
        ),
      ).timeout(_loadTimeout);
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

    final originalUrlFuture = _remote
        .createSignedUrl(analysis.originalImagePath)
        .timeout(_loadTimeout);
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
    ]).timeout(_loadTimeout);
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
      throw const HistoryFailure(
        'Your session expired. Sign in again.',
        retryable: false,
        sessionExpired: true,
      );
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
      return const HistoryFailure(
        'Your session expired. Sign in again.',
        retryable: false,
        sessionExpired: true,
      );
    }
    if ((error is StorageException &&
            int.tryParse(error.statusCode.toString()) == 401) ||
        (error is PostgrestException && _isExpiredSession(error))) {
      return const HistoryFailure(
        'Your session expired. Sign in again.',
        retryable: false,
        sessionExpired: true,
      );
    }
    if (error is HistoryRemoteFailure) {
      if (error.status == 401) {
        return const HistoryFailure(
          'Your session expired. Sign in again.',
          retryable: false,
          sessionExpired: true,
        );
      }
      if (error.status == 404) {
        return const HistoryFailure(
          'This history item no longer exists. Refresh your history.',
          retryable: false,
        );
      }
      if (error.status == 403) {
        return const HistoryFailure(
          'You no longer have access to this history session.',
          retryable: false,
        );
      }
      return HistoryFailure(
        loading
            ? 'Your FaceTune history could not be loaded right now.'
            : 'This history session could not be deleted right now.',
        retryable: error.retryable || error.status >= 500,
      );
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

  static bool _isExpiredSession(PostgrestException error) {
    final detail = '${error.code} ${error.message} ${error.details}'
        .toLowerCase();
    return error.code == 'PGRST301' ||
        (detail.contains('jwt') &&
            (detail.contains('expired') || detail.contains('invalid')));
  }
}
