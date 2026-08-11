import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../analysis/data/models/face_analysis_dto.dart';
import '../../../makeup_styles/domain/catalog/makeup_style_catalog.dart';
import '../../../preview/data/models/generated_preview_dto.dart';
import '../../../preview/domain/entities/generated_preview.dart';
import '../../../recommendation/data/models/makeup_recommendation_dto.dart';
import '../../domain/entities/saved_look.dart';
import '../../domain/errors/saved_looks_failure.dart';
import '../../domain/repositories/saved_looks_repository.dart';
import '../data_sources/saved_looks_remote_data_source.dart';

class SupabaseSavedLooksRepository implements SavedLooksRepository {
  const SupabaseSavedLooksRepository(this._remote);

  final SavedLooksRemoteDataSource _remote;

  @override
  Future<SavedLook?> findByGeneratedImageId(String generatedImageId) async {
    try {
      final row = await _remote.findSavedLook(generatedImageId);
      if (row == null) return null;
      final items = await _hydrate([row]);
      return items.single;
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<SavedLook> save(
    GeneratedPreview preview, {
    bool favorite = false,
  }) async {
    final userId = _remote.currentUserId;
    if (userId == null) {
      throw const SavedLooksFailure('Sign in before saving a look.');
    }
    try {
      var row = await _remote.findSavedLook(preview.id);
      if (row == null) {
        try {
          row = await _remote.insertSavedLook(
            userId: userId,
            generatedImageId: preview.id,
            favorite: favorite,
          );
        } on PostgrestException catch (error) {
          if (error.code != '23505') rethrow;
          row = await _remote.findSavedLook(preview.id);
        }
      } else if (favorite && row['is_favorite'] != true) {
        row = await _remote.updateFavorite(
          savedLookId: row['id']! as String,
          favorite: true,
        );
      }
      if (row == null) {
        throw const SavedLooksFailure('The saved look could not be loaded.');
      }
      return (await _hydrate([row])).single;
    } catch (error) {
      if (error is SavedLooksFailure) rethrow;
      throw _failure(error);
    }
  }

  @override
  Future<void> remove(String savedLookId) async {
    try {
      await _remote.deleteSavedLook(savedLookId);
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<SavedLook> setFavorite(SavedLook look, bool isFavorite) async {
    try {
      await _remote.updateFavorite(savedLookId: look.id, favorite: isFavorite);
      return look.copyWith(isFavorite: isFavorite);
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<SavedLooksPageResult> loadPage({
    required int offset,
    required int limit,
  }) async {
    try {
      final rows = await _remote.selectSavedLooks(offset: offset, limit: limit);
      return SavedLooksPageResult(
        items: await _hydrate(rows),
        hasMore: rows.length == limit,
      );
    } catch (error) {
      throw _failure(error);
    }
  }

  Future<List<SavedLook>> _hydrate(List<Map<String, Object?>> savedRows) async {
    if (savedRows.isEmpty) return const [];
    final generatedIds = savedRows
        .map((row) => row['generated_image_id']! as String)
        .toList();
    final generatedRows = await _remote.selectGeneratedImages(generatedIds);
    final generatedById = {for (final row in generatedRows) row['id']: row};
    final recommendationIds = generatedRows
        .map((row) => row['recommendation_id']! as String)
        .toSet()
        .toList();
    final analysisIds = generatedRows
        .map((row) => row['analysis_id']! as String)
        .toSet()
        .toList();
    final linked = await Future.wait([
      _remote.selectRecommendations(recommendationIds),
      _remote.selectAnalyses(analysisIds),
    ]);
    final recommendationsById = {for (final row in linked[0]) row['id']: row};
    final analysesById = {for (final row in linked[1]) row['id']: row};
    final items = <SavedLook>[];
    for (final savedRow in savedRows) {
      final generated = generatedById[savedRow['generated_image_id']];
      if (generated == null) throw const FormatException('Missing preview.');
      final recommendation =
          recommendationsById[generated['recommendation_id']];
      final analysis = analysesById[generated['analysis_id']];
      if (recommendation == null || analysis == null) {
        throw const FormatException('Missing linked result data.');
      }
      final analysisEntity = FaceAnalysisDto.fromResponse({
        'analysis': {
          'id': analysis['id'],
          'originalImagePath': analysis['original_image_path'],
          'validation': _map(analysis['raw_ai_metadata'])['validation'],
          'attributes': {
            'faceShape': analysis['face_shape'],
            'skinTone': analysis['skin_tone'],
            'undertone': analysis['undertone'],
            'eyeShape': analysis['eye_shape'],
            'lipShape': analysis['lip_shape'],
            'hairColor': analysis['hair_color'],
            'eyeColor': analysis['eye_color'],
          },
          'confidence': analysis['confidence_json'],
          'modelId': analysis['model_name'],
          'promptVersion': analysis['prompt_version'],
          'createdAt': analysis['created_at'],
        },
      }).analysis;
      final recommendationEntity = MakeupRecommendationDto.fromResponse({
        'recommendation': {
          'id': recommendation['id'],
          'analysisId': recommendation['analysis_id'],
          'style': recommendation['makeup_style'],
          'plan': recommendation['recommendation_json'],
          'modelId': recommendation['model_name'],
          'promptVersion': recommendation['prompt_version'],
          'createdAt': recommendation['created_at'],
        },
      }).recommendation;
      final generatedDto = GeneratedPreviewDto.fromResponse({
        'preview': {
          'id': generated['id'],
          'analysisId': generated['analysis_id'],
          'recommendationId': generated['recommendation_id'],
          'originalImagePath': analysisEntity.originalImagePath,
          'generatedImagePath': generated['storage_path'],
          'generationNumber': generated['generation_number'],
          'modelId': generated['model_name'],
          'promptVersion': generated['prompt_version'],
          'createdAt': generated['created_at'],
        },
      });
      final urls = await Future.wait([
        _remote.createSignedUrl(generatedDto.originalImagePath),
        _remote.createSignedUrl(generatedDto.generatedImagePath),
      ]);
      final style = MakeupStyleCatalog.styles.firstWhere(
        (candidate) => candidate.code == recommendationEntity.styleCode,
      );
      items.add(
        SavedLook(
          id: savedRow['id']! as String,
          preview: generatedDto.toDomain(
            originalImageUrl: urls[0],
            generatedImageUrl: urls[1],
          ),
          analysis: analysisEntity,
          recommendation: recommendationEntity,
          style: style,
          isFavorite: savedRow['is_favorite']! as bool,
          createdAt: DateTime.parse(savedRow['created_at']! as String).toUtc(),
        ),
      );
    }
    return List.unmodifiable(items);
  }

  static Map<String, Object?> _map(Object? value) {
    if (value is! Map) throw const FormatException('Expected object.');
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static SavedLooksFailure _failure(Object error) {
    if (error is SavedLooksFailure) return error;
    if (error is SocketException || error is TimeoutException) {
      return const SavedLooksFailure('Check your connection and try again.');
    }
    if (error is AuthException) {
      return const SavedLooksFailure('Your session expired. Sign in again.');
    }
    if (error is PostgrestException || error is StorageException) {
      return const SavedLooksFailure(
        'Your saved looks could not be updated right now.',
      );
    }
    if (error is FormatException) {
      return const SavedLooksFailure(
        'A saved look contains incomplete result data.',
        retryable: false,
      );
    }
    return const SavedLooksFailure('Your saved looks could not be loaded.');
  }
}
