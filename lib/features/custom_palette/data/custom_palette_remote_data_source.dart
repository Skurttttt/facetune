import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/supabase_remote_data_source.dart';
import '../domain/repositories/custom_palette_gateway.dart';

/// The raw server surface for this mode.
abstract interface class CustomPaletteRemoteDataSource {
  String? get currentUserId;

  Future<Object?> createRecommendation(Map<String, Object?> body);

  Future<Object?> generatePreview({
    required String recommendationId,
    required String operationId,
  });

  Future<String> createSignedUrl(String storagePath);

  Future<List<Map<String, Object?>>> selectHistoryPreviews({
    required int offset,
    required int limit,
  });
  Future<List<Map<String, Object?>>> selectPreviews(List<String> ids);
  Future<List<Map<String, Object?>>> selectRecommendations(List<String> ids);
  Future<List<Map<String, Object?>>> selectAnalyses(List<String> ids);

  Future<List<Map<String, Object?>>> selectSaved({
    required int offset,
    required int limit,
  });
  Future<List<Map<String, Object?>>> selectSavedForPreviews(
    List<String> previewIds,
  );
  Future<Map<String, Object?>?> findSaved(String previewId);
  Future<Map<String, Object?>> insertSaved({
    required String userId,
    required String previewId,
    required bool favorite,
  });
  Future<Map<String, Object?>> updateFavorite({
    required String savedLookId,
    required bool favorite,
  });
  Future<void> deleteSaved(String savedLookId);

  Future<Object?> deleteSession(String analysisId);
}

class SupabaseCustomPaletteRemoteDataSource extends SupabaseRemoteDataSource
    implements CustomPaletteRemoteDataSource {
  const SupabaseCustomPaletteRemoteDataSource(super.client);

  static const _saved = 'custom_palette_saved_looks';
  static const _previews = 'custom_palette_generated_images';

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  Future<Object?> _invoke(String name, Map<String, Object?> body) async {
    try {
      final response = await client.functions.invoke(name, body: body);
      return response.data;
    } on FunctionException catch (error) {
      final details = error.details;
      final root = details is Map
          ? details.map((key, value) => MapEntry(key.toString(), value))
          : const <String, Object?>{};
      final nested = root['error'];
      final payload = nested is Map
          ? nested.map((key, value) => MapEntry(key.toString(), value))
          : root;
      final code = payload['code']?.toString();
      throw CustomPaletteFailure(
        payload['message']?.toString() ??
            'Your look could not be created. Please try again.',
        retryable: payload['retryable'] == true,
        code: code,
        // With no code the server's answer never arrived, so the outcome is
        // unknown. An in-progress answer means the request is still running.
        requestEnded: code != null && code != 'preview_in_progress',
        sessionExpired:
            error.status == 401 ||
            code == 'invalid_session' ||
            code == 'authentication_required',
      );
    }
  }

  @override
  Future<Object?> createRecommendation(Map<String, Object?> body) =>
      _invoke('generate-custom-palette-recommendation', body);

  @override
  Future<Object?> generatePreview({
    required String recommendationId,
    required String operationId,
  }) => _invoke('generate-custom-palette-preview', {
    'customPaletteRecommendationId': recommendationId,
    'operationId': operationId,
  });

  @override
  Future<String> createSignedUrl(String storagePath) =>
      client.storage.from('face-images').createSignedUrl(storagePath, 3600);

  List<Map<String, Object?>> _rows(Object? rows) => [
    for (final row in rows! as List)
      (row as Map).map((key, value) => MapEntry(key.toString(), value)),
  ];

  Future<List<Map<String, Object?>>> _byIds(
    String table,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const [];
    return _rows(await client.from(table).select('*').inFilter('id', ids));
  }

  @override
  Future<List<Map<String, Object?>>> selectHistoryPreviews({
    required int offset,
    required int limit,
  }) async => _rows(
    await client
        .from(_previews)
        .select('*')
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + limit - 1),
  );

  @override
  Future<List<Map<String, Object?>>> selectPreviews(List<String> ids) =>
      _byIds(_previews, ids);

  @override
  Future<List<Map<String, Object?>>> selectRecommendations(List<String> ids) =>
      _byIds('custom_palette_recommendations', ids);

  @override
  Future<List<Map<String, Object?>>> selectAnalyses(List<String> ids) =>
      _byIds('analyses', ids);

  @override
  Future<List<Map<String, Object?>>> selectSaved({
    required int offset,
    required int limit,
  }) async => _rows(
    await client
        .from(_saved)
        .select('*')
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + limit - 1),
  );

  @override
  Future<List<Map<String, Object?>>> selectSavedForPreviews(
    List<String> previewIds,
  ) async {
    if (previewIds.isEmpty) return const [];
    return _rows(
      await client
          .from(_saved)
          .select('*')
          .inFilter('custom_palette_generated_image_id', previewIds),
    );
  }

  @override
  Future<Map<String, Object?>?> findSaved(String previewId) => client
      .from(_saved)
      .select('*')
      .eq('custom_palette_generated_image_id', previewId)
      .maybeSingle();

  @override
  Future<Map<String, Object?>> insertSaved({
    required String userId,
    required String previewId,
    required bool favorite,
  }) => client
      .from(_saved)
      .insert({
        'user_id': userId,
        'custom_palette_generated_image_id': previewId,
        'is_favorite': favorite,
      })
      .select('*')
      .single();

  @override
  Future<Map<String, Object?>> updateFavorite({
    required String savedLookId,
    required bool favorite,
  }) => client
      .from(_saved)
      .update({'is_favorite': favorite})
      .eq('id', savedLookId)
      .select('*')
      .single();

  @override
  Future<void> deleteSaved(String savedLookId) async {
    await client.from(_saved).delete().eq('id', savedLookId);
  }

  @override
  Future<Object?> deleteSession(String analysisId) async {
    final response = await client.functions.invoke(
      'delete-history-item',
      body: {'analysisId': analysisId},
    );
    return response.data;
  }
}
