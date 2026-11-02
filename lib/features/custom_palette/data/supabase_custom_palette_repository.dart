import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../analysis/data/models/face_analysis_dto.dart';
import '../../analysis/domain/entities/face_analysis.dart';
import '../../makeup_styles/domain/catalog/makeup_style_catalog.dart';
import '../domain/entities/custom_palette_look.dart';
import '../domain/repositories/custom_palette_gateway.dart';
import '../domain/validation/custom_palette_contract.dart';
import 'custom_palette_dtos.dart';
import 'custom_palette_remote_data_source.dart';

/// The real server path.
///
/// Every generated value shown to the user is read back from the server's frozen
/// rows, never carried over from the draft that produced them.
class SupabaseCustomPaletteRepository
    implements CustomPaletteGateway, CustomPaletteLibraryRepository {
  const SupabaseCustomPaletteRepository(
    this._remote, {
    Duration recommendationTimeout = const Duration(seconds: 100),
    Duration previewTimeout = const Duration(seconds: 150),
    Duration timeout = const Duration(seconds: 30),
  }) : _recommendationTimeout = recommendationTimeout,
       _previewTimeout = previewTimeout,
       _timeout = timeout;

  final CustomPaletteRemoteDataSource _remote;
  final Duration _recommendationTimeout;
  final Duration _previewTimeout;
  final Duration _timeout;

  String _requireUser() {
    final userId = _remote.currentUserId;
    if (userId == null) {
      throw const CustomPaletteFailure(
        'Sign in before generating a look.',
        sessionExpired: true,
      );
    }
    return userId;
  }

  CustomPaletteFailure _map(Object error) {
    if (error is CustomPaletteFailure) return error;
    if (error is PostgrestException) {
      return CustomPaletteFailure(
        'Your looks could not be loaded right now.',
        retryable: true,
        requestEnded: false,
        sessionExpired: error.code == 'PGRST301',
      );
    }
    // Anything else means no clear answer arrived: a dropped connection, a
    // timeout, an unreadable response. The server may still be working, or may
    // have finished, so the safe reading is that the request has not ended.
    return const CustomPaletteFailure(
      'The connection was interrupted. Please try again.',
      retryable: true,
      requestEnded: false,
    );
  }

  @override
  Future<CustomPaletteRecommendation> submit(
    CustomPaletteRequest request,
  ) async {
    _requireUser();
    try {
      final response = await _remote
          .createRecommendation(request.toJson())
          .timeout(_recommendationTimeout);
      final recommendation = CustomPaletteDtos.recommendationFromResponse(
        response,
      );
      if (recommendation.analysisId != request.analysisId ||
          recommendation.styleCode != request.styleCode) {
        throw const FormatException('Recommendation linkage is invalid.');
      }
      return recommendation;
    } catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<CustomPaletteGeneratedPreview> generatePreview({
    required CustomPaletteRecommendation recommendation,
    required String operationId,
  }) async {
    _requireUser();
    try {
      final response = await _remote
          .generatePreview(
            recommendationId: recommendation.id,
            operationId: operationId,
          )
          .timeout(_previewTimeout);
      final dto = CustomPalettePreviewDto.fromResponse(response);
      if (dto.recommendationId != recommendation.id ||
          dto.analysisId != recommendation.analysisId ||
          dto.originalImagePath == dto.generatedImagePath) {
        throw const FormatException('Preview linkage is invalid.');
      }
      return await _signed(dto);
    } catch (error) {
      throw _map(error);
    }
  }

  Future<CustomPaletteGeneratedPreview> _signed(
    CustomPalettePreviewDto dto,
  ) async {
    final urls = await Future.wait([
      _remote.createSignedUrl(dto.originalImagePath),
      _remote.createSignedUrl(dto.generatedImagePath),
    ]).timeout(_timeout);
    return dto.toDomain(originalImageUrl: urls[0], generatedImageUrl: urls[1]);
  }

  @override
  Future<CustomPaletteSavedLook?> findSaved(String previewId) async {
    final userId = _requireUser();
    try {
      final row = await _remote.findSaved(previewId).timeout(_timeout);
      if (row == null) return null;
      return (await _hydrateSaved([row], userId)).single;
    } catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<CustomPaletteSavedLook> save(
    CustomPaletteGeneratedPreview preview, {
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
                previewId: preview.id,
                favorite: favorite,
              )
              .timeout(_timeout);
        } on PostgrestException catch (error) {
          if (error.code != '23505') rethrow;
          row = await _remote.findSaved(preview.id).timeout(_timeout);
        }
      } else if (favorite && row['is_favorite'] != true) {
        row = await _remote
            .updateFavorite(savedLookId: row['id']! as String, favorite: true)
            .timeout(_timeout);
      }
      if (row == null) throw const FormatException('Saved look is missing.');
      return (await _hydrateSaved([row], userId)).single;
    } catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<CustomPaletteSavedLook> setFavorite(
    CustomPaletteSavedLook look,
    bool isFavorite,
  ) async {
    _requireUser();
    try {
      await _remote
          .updateFavorite(savedLookId: look.id, favorite: isFavorite)
          .timeout(_timeout);
      return look.copyWith(isFavorite: isFavorite);
    } catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<void> removeSaved(String savedLookId) async {
    _requireUser();
    try {
      await _remote.deleteSaved(savedLookId).timeout(_timeout);
    } catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<CustomPalettePage<CustomPaletteSavedLook>> loadSavedPage({
    required int offset,
    required int limit,
  }) async {
    final userId = _requireUser();
    try {
      final rows = await _remote
          .selectSaved(offset: offset, limit: limit)
          .timeout(_timeout);
      return CustomPalettePage(
        items: await _hydrateSaved(rows, userId),
        hasMore: rows.length == limit,
      );
    } catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<CustomPalettePage<CustomPaletteHistoryEntry>> loadHistoryPage({
    required int offset,
    required int limit,
  }) async {
    final userId = _requireUser();
    try {
      final previews = await _remote
          .selectHistoryPreviews(offset: offset, limit: limit)
          .timeout(_timeout);
      final saved = await _remote
          .selectSavedForPreviews([
            for (final row in previews) row['id']! as String,
          ])
          .timeout(_timeout);
      _assertOwned(saved, userId);
      final results = await _hydrateResults(previews, userId);
      final savedByPreview = {
        for (final row in saved) row['custom_palette_generated_image_id']: row,
      };
      return CustomPalettePage(
        items: List.unmodifiable([
          for (final result in results)
            CustomPaletteHistoryEntry(
              result: result,
              savedLook: switch (savedByPreview[result.preview.id]) {
                final row? => _savedFromRow(row, result),
                null => null,
              },
            ),
        ]),
        hasMore: previews.length == limit,
      );
    } catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<void> deleteSession(String analysisId) async {
    _requireUser();
    try {
      final response = await _remote
          .deleteSession(analysisId)
          .timeout(_timeout);
      final data = response is Map ? response : const {};
      if (data['deleted'] != true || data['analysisId'] != analysisId) {
        throw const FormatException('Deletion response is invalid.');
      }
    } catch (error) {
      throw _map(error);
    }
  }

  void _assertOwned(List<Map<String, Object?>> rows, String userId) {
    if (rows.any((row) => row['user_id'] != userId)) {
      throw const FormatException('A row belongs to another account.');
    }
  }

  CustomPaletteSavedLook _savedFromRow(
    Map<String, Object?> row,
    CustomPaletteLookResult result,
  ) => CustomPaletteSavedLook(
    id: row['id']! as String,
    result: result,
    isFavorite: row['is_favorite'] == true,
    createdAt: DateTime.parse(row['created_at']! as String),
  );

  Future<List<CustomPaletteSavedLook>> _hydrateSaved(
    List<Map<String, Object?>> savedRows,
    String userId,
  ) async {
    if (savedRows.isEmpty) return const [];
    _assertOwned(savedRows, userId);
    final previews = await _remote
        .selectPreviews([
          for (final row in savedRows)
            row['custom_palette_generated_image_id']! as String,
        ])
        .timeout(_timeout);
    final results = await _hydrateResults(previews, userId);
    final byPreview = {for (final result in results) result.preview.id: result};
    return List.unmodifiable([
      for (final row in savedRows)
        _savedFromRow(
          row,
          byPreview[row['custom_palette_generated_image_id']] ??
              (throw const FormatException('Missing linked look.')),
        ),
    ]);
  }

  Future<List<CustomPaletteLookResult>> _hydrateResults(
    List<Map<String, Object?>> previewRows,
    String userId,
  ) async {
    if (previewRows.isEmpty) return const [];
    _assertOwned(previewRows, userId);
    final linked = await Future.wait([
      _remote.selectRecommendations(
        previewRows
            .map((row) => row['custom_palette_recommendation_id']! as String)
            .toSet()
            .toList(),
      ),
      _remote.selectAnalyses(
        previewRows
            .map((row) => row['analysis_id']! as String)
            .toSet()
            .toList(),
      ),
    ]).timeout(_timeout);
    _assertOwned(linked[0], userId);
    _assertOwned(linked[1], userId);
    final recommendations = {for (final row in linked[0]) row['id']: row};
    final analyses = {for (final row in linked[1]) row['id']: row};
    return Future.wait(
      previewRows.map((row) async {
        final recommendationRow =
            recommendations[row['custom_palette_recommendation_id']];
        final analysisRow = analyses[row['analysis_id']];
        if (recommendationRow == null || analysisRow == null) {
          throw const FormatException('Missing linked look data.');
        }
        final analysis = _analysis(analysisRow);
        // The palette comes from this look's own frozen row, always.
        final recommendation = CustomPaletteDtos.recommendationFromRow(
          recommendationRow,
        );
        final style = MakeupStyleCatalog.styles
            .where((candidate) => candidate.code == recommendation.styleCode)
            .firstOrNull;
        if (style == null) throw const FormatException('Unknown makeup style.');
        return CustomPaletteLookResult(
          analysis: analysis,
          style: style,
          recommendation: recommendation,
          preview: await _signed(
            CustomPalettePreviewDto.fromRow(
              row,
              originalImagePath: analysis.originalImagePath,
            ),
          ),
        );
      }),
    );
  }

  FaceAnalysis _analysis(Map<String, Object?> row) {
    final metadata = row['raw_ai_metadata'];
    return FaceAnalysisDto.fromResponse({
      'analysis': {
        'id': row['id'],
        'originalImagePath': row['original_image_path'],
        'validation': metadata is Map ? metadata['validation'] : null,
        'attributes': {
          'faceShape': row['face_shape'],
          'skinTone': row['skin_tone'],
          'undertone': row['undertone'],
          'eyeShape': row['eye_shape'],
          'lipShape': row['lip_shape'],
          'hairColor': row['hair_color'],
          'eyeColor': row['eye_color'],
        },
        'confidence': row['confidence_json'],
        'modelId': row['model_name'] ?? 'unknown',
        'promptVersion': row['prompt_version'] ?? 'legacy',
        'createdAt': row['created_at'],
      },
    }).analysis;
  }
}
