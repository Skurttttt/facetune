import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../analysis/data/models/face_analysis_dto.dart';
import '../../../makeup_styles/domain/catalog/makeup_style_catalog.dart';
import '../../domain/entities/kit_generated_preview.dart';
import '../../domain/entities/kit_look_result.dart';
import '../../domain/errors/makeup_kit_library_failure.dart';
import '../../domain/repositories/makeup_kit_library_repository.dart';
import '../data_sources/makeup_kit_library_remote_data_source.dart';
import '../models/kit_generated_preview_dto.dart';
import '../models/kit_makeup_recommendation_dto.dart';

class SupabaseMakeupKitLibraryRepository implements MakeupKitLibraryRepository {
  const SupabaseMakeupKitLibraryRepository(
    this._remote, {
    Duration timeout = const Duration(seconds: 30),
  }) : _timeout = timeout;

  final MakeupKitLibraryRemoteDataSource _remote;
  final Duration _timeout;

  @override
  Future<KitSavedLook?> findSaved(String kitGeneratedImageId) async {
    _requireUser();
    try {
      final row = await _remote
          .findSaved(kitGeneratedImageId)
          .timeout(_timeout);
      if (row == null) return null;
      return (await _hydrateSaved([row])).single;
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<KitSavedLook> save(
    KitGeneratedPreview preview, {
    bool favorite = false,
  }) async {
    final userId = _requireUser();
    try {
      var row = await _remote.findSaved(preview.id).timeout(_timeout);
      if (row == null) {
        try {
          row = await _remote
              .insertSaved(
                userId: userId,
                kitGeneratedImageId: preview.id,
                favorite: favorite,
              )
              .timeout(_timeout);
        } on PostgrestException catch (error) {
          if (error.code != '23505') rethrow;
          row = await _remote.findSaved(preview.id).timeout(_timeout);
        }
      } else if (favorite && row['is_favorite'] != true) {
        row = await _remote
            .updateFavorite(
              savedLookId: _requiredString(row, 'id'),
              favorite: true,
            )
            .timeout(_timeout);
      }
      if (row == null) {
        throw const FormatException('Saved kit look is missing.');
      }
      return (await _hydrateSaved([row])).single;
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<KitSavedLook> setFavorite(KitSavedLook look, bool isFavorite) async {
    _requireUser();
    try {
      await _remote
          .updateFavorite(savedLookId: look.id, favorite: isFavorite)
          .timeout(_timeout);
      return look.copyWith(isFavorite: isFavorite);
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<void> removeSaved(String savedLookId) async {
    _requireUser();
    try {
      await _remote.deleteSaved(savedLookId).timeout(_timeout);
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<KitSavedLooksPageResult> loadSavedPage({
    required int offset,
    required int limit,
  }) async {
    _requireUser();
    try {
      final rows = await _remote
          .selectSaved(offset: offset, limit: limit)
          .timeout(_timeout);
      return KitSavedLooksPageResult(
        items: await _hydrateSaved(rows),
        hasMore: rows.length == limit,
      );
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<KitHistoryPageResult> loadHistoryPage({
    required int offset,
    required int limit,
  }) async {
    _requireUser();
    try {
      final previewRows = await _remote
          .selectHistoryPreviews(offset: offset, limit: limit)
          .timeout(_timeout);
      final previewIds = previewRows
          .map((row) => _requiredString(row, 'id'))
          .toList();
      final savedRows = await _remote
          .selectSavedForPreviews(previewIds)
          .timeout(_timeout);
      final results = await _hydrateResults(previewRows);
      final savedByPreview = {
        for (final row in savedRows)
          _requiredString(row, 'kit_generated_image_id'): row,
      };
      return KitHistoryPageResult(
        items: List.unmodifiable([
          for (final result in results)
            KitHistoryEntry(
              result: result,
              savedLook: _savedFromRow(
                savedByPreview[result.preview.id],
                result,
              ),
            ),
        ]),
        hasMore: previewRows.length == limit,
      );
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<void> deleteSession(String analysisId) async {
    _requireUser();
    try {
      final response = await _remote
          .deleteSession(analysisId)
          .timeout(_timeout);
      final data = _map(response);
      if (data['deleted'] != true || data['analysisId'] != analysisId) {
        throw const FormatException('Deletion response is invalid.');
      }
    } catch (error) {
      throw _failure(error);
    }
  }

  Future<List<KitSavedLook>> _hydrateSaved(
    List<Map<String, Object?>> savedRows,
  ) async {
    if (savedRows.isEmpty) return const [];
    final previewIds = savedRows
        .map((row) => _requiredString(row, 'kit_generated_image_id'))
        .toList();
    final previewRows = await _remote
        .selectPreviews(previewIds)
        .timeout(_timeout);
    final results = await _hydrateResults(previewRows);
    final resultByPreview = {
      for (final result in results) result.preview.id: result,
    };
    return List.unmodifiable([
      for (final row in savedRows)
        _savedFromRow(
              row,
              resultByPreview[_requiredString(row, 'kit_generated_image_id')],
            ) ??
            (throw const FormatException('Missing linked kit result.')),
    ]);
  }

  Future<List<KitLookResult>> _hydrateResults(
    List<Map<String, Object?>> previewRows,
  ) async {
    if (previewRows.isEmpty) return const [];
    final recommendationIds = previewRows
        .map((row) => _requiredString(row, 'kit_recommendation_id'))
        .toSet()
        .toList();
    final analysisIds = previewRows
        .map((row) => _requiredString(row, 'analysis_id'))
        .toSet()
        .toList();
    final linked = await Future.wait([
      _remote.selectRecommendations(recommendationIds),
      _remote.selectAnalyses(analysisIds),
    ]).timeout(_timeout);
    final recommendations = {for (final row in linked[0]) row['id']: row};
    final analyses = {for (final row in linked[1]) row['id']: row};
    final results = <KitLookResult>[];
    for (final previewRow in previewRows) {
      final recommendationRow =
          recommendations[previewRow['kit_recommendation_id']];
      final analysisRow = analyses[previewRow['analysis_id']];
      if (recommendationRow == null || analysisRow == null) {
        throw const FormatException('Missing linked kit result data.');
      }
      final analysis = FaceAnalysisDto.fromResponse({
        'analysis': {
          'id': analysisRow['id'],
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
      final recommendation = KitMakeupRecommendationDto.fromResponse({
        'recommendation': {
          'id': recommendationRow['id'],
          'analysisId': recommendationRow['analysis_id'],
          'style': recommendationRow['makeup_style'],
          'plan': recommendationRow['recommendation_json'],
          'productSnapshot': recommendationRow['product_snapshot_json'],
          'modelId': recommendationRow['model_name'],
          'promptVersion': recommendationRow['prompt_version'],
          'createdAt': recommendationRow['created_at'],
        },
      }).recommendation;
      final previewDto = KitGeneratedPreviewDto.fromResponse({
        'preview': {
          'id': previewRow['id'],
          'mode': 'makeup_kit',
          'analysisId': previewRow['analysis_id'],
          'kitRecommendationId': previewRow['kit_recommendation_id'],
          'originalImagePath': analysis.originalImagePath,
          'generatedImagePath': previewRow['storage_path'],
          'generationNumber': previewRow['generation_number'],
          'modelId': previewRow['model_name'],
          'promptVersion': previewRow['prompt_version'],
          'createdAt': previewRow['created_at'],
        },
      });
      final urls = await Future.wait([
        _remote.createSignedUrl(previewDto.originalImagePath),
        _remote.createSignedUrl(previewDto.generatedImagePath),
      ]).timeout(_timeout);
      final style = MakeupStyleCatalog.styles
          .where((candidate) => candidate.code == recommendation.styleCode)
          .firstOrNull;
      if (style == null) throw const FormatException('Unknown makeup style.');
      results.add(
        KitLookResult(
          analysis: analysis,
          style: style,
          recommendation: recommendation,
          preview: previewDto.toDomain(
            originalImageUrl: urls[0],
            generatedImageUrl: urls[1],
          ),
        ),
      );
    }
    return List.unmodifiable(results);
  }

  static KitSavedLook? _savedFromRow(
    Map<String, Object?>? row,
    KitLookResult? result,
  ) {
    if (row == null || result == null) return null;
    return KitSavedLook(
      id: _requiredString(row, 'id'),
      result: result,
      isFavorite: row['is_favorite'] == true,
      createdAt: DateTime.parse(_requiredString(row, 'created_at')).toUtc(),
    );
  }

  String _requireUser() {
    final userId = _remote.currentUserId;
    if (userId == null) {
      throw const MakeupKitLibraryFailure(
        'Your session expired. Sign in again.',
        retryable: false,
        sessionExpired: true,
      );
    }
    return userId;
  }

  static MakeupKitLibraryFailure _failure(Object error) {
    if (error is MakeupKitLibraryFailure) return error;
    if (error is SocketException || error is TimeoutException) {
      return const MakeupKitLibraryFailure(
        'Check your connection and try again.',
      );
    }
    if (error is AuthException) {
      return const MakeupKitLibraryFailure(
        'Your session expired. Sign in again.',
        retryable: false,
        sessionExpired: true,
      );
    }
    if (error is MakeupKitLibraryRemoteFailure) {
      if (error.status == 401) {
        return const MakeupKitLibraryFailure(
          'Your session expired. Sign in again.',
          retryable: false,
          sessionExpired: true,
        );
      }
      return MakeupKitLibraryFailure(
        error.message,
        retryable: error.retryable || error.status >= 500,
      );
    }
    if (error is PostgrestException || error is StorageException) {
      return const MakeupKitLibraryFailure(
        'Your My Makeup Kit results could not be updated right now.',
      );
    }
    if (error is FormatException) {
      return const MakeupKitLibraryFailure(
        'A saved My Makeup Kit result contains incomplete data.',
        retryable: false,
      );
    }
    return const MakeupKitLibraryFailure(
      'Your My Makeup Kit results could not be loaded.',
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
    return value.trim();
  }

  static String _fallbackString(Object? value, String fallback) =>
      value is String && value.trim().isNotEmpty ? value.trim() : fallback;
}
