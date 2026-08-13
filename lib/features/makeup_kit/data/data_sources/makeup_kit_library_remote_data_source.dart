import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_remote_data_source.dart';

abstract interface class MakeupKitLibraryRemoteDataSource {
  String? get currentUserId;

  Future<List<Map<String, Object?>>> selectSaved({
    required int offset,
    required int limit,
  });

  Future<Map<String, Object?>?> findSaved(String kitGeneratedImageId);

  Future<Map<String, Object?>> insertSaved({
    required String userId,
    required String kitGeneratedImageId,
    required bool favorite,
  });

  Future<Map<String, Object?>> updateFavorite({
    required String savedLookId,
    required bool favorite,
  });

  Future<void> deleteSaved(String savedLookId);

  Future<List<Map<String, Object?>>> selectHistoryPreviews({
    required int offset,
    required int limit,
  });

  Future<List<Map<String, Object?>>> selectPreviews(List<String> ids);

  Future<List<Map<String, Object?>>> selectRecommendations(List<String> ids);

  Future<List<Map<String, Object?>>> selectAnalyses(List<String> ids);

  Future<List<Map<String, Object?>>> selectSavedForPreviews(List<String> ids);

  Future<String> createSignedUrl(String storagePath);

  Future<Object?> deleteSession(String analysisId);
}

class MakeupKitLibraryRemoteFailure implements Exception {
  const MakeupKitLibraryRemoteFailure({
    required this.status,
    required this.message,
    required this.retryable,
  });

  final int status;
  final String message;
  final bool retryable;
}

class SupabaseMakeupKitLibraryRemoteDataSource extends SupabaseRemoteDataSource
    implements MakeupKitLibraryRemoteDataSource {
  const SupabaseMakeupKitLibraryRemoteDataSource(super.client);

  static const _savedColumns =
      'id,kit_generated_image_id,is_favorite,created_at';

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  Future<List<Map<String, Object?>>> selectSaved({
    required int offset,
    required int limit,
  }) async => _rows(
    await client
        .from('kit_saved_looks')
        .select(_savedColumns)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1),
  );

  @override
  Future<Map<String, Object?>?> findSaved(String kitGeneratedImageId) async {
    final row = await client
        .from('kit_saved_looks')
        .select(_savedColumns)
        .eq('kit_generated_image_id', kitGeneratedImageId)
        .maybeSingle();
    return row == null ? null : _row(row);
  }

  @override
  Future<Map<String, Object?>> insertSaved({
    required String userId,
    required String kitGeneratedImageId,
    required bool favorite,
  }) async => _row(
    await client
        .from('kit_saved_looks')
        .insert({
          'user_id': userId,
          'kit_generated_image_id': kitGeneratedImageId,
          'is_favorite': favorite,
        })
        .select(_savedColumns)
        .single(),
  );

  @override
  Future<Map<String, Object?>> updateFavorite({
    required String savedLookId,
    required bool favorite,
  }) async => _row(
    await client
        .from('kit_saved_looks')
        .update({'is_favorite': favorite})
        .eq('id', savedLookId)
        .select(_savedColumns)
        .single(),
  );

  @override
  Future<void> deleteSaved(String savedLookId) async {
    await client.from('kit_saved_looks').delete().eq('id', savedLookId);
  }

  @override
  Future<List<Map<String, Object?>>> selectHistoryPreviews({
    required int offset,
    required int limit,
  }) async => _rows(
    await client
        .from('kit_generated_images')
        .select('*')
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + limit - 1),
  );

  @override
  Future<List<Map<String, Object?>>> selectPreviews(List<String> ids) =>
      _selectByIds('kit_generated_images', ids);

  @override
  Future<List<Map<String, Object?>>> selectRecommendations(List<String> ids) =>
      _selectByIds('kit_makeup_recommendations', ids);

  @override
  Future<List<Map<String, Object?>>> selectAnalyses(List<String> ids) =>
      _selectByIds('analyses', ids);

  @override
  Future<List<Map<String, Object?>>> selectSavedForPreviews(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const [];
    return _rows(
      await client
          .from('kit_saved_looks')
          .select(_savedColumns)
          .inFilter('kit_generated_image_id', ids),
    );
  }

  Future<List<Map<String, Object?>>> _selectByIds(
    String table,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const [];
    return _rows(await client.from(table).select('*').inFilter('id', ids));
  }

  @override
  Future<String> createSignedUrl(String storagePath) =>
      client.storage.from('face-images').createSignedUrl(storagePath, 3600);

  @override
  Future<Object?> deleteSession(String analysisId) async {
    try {
      final response = await client.functions.invoke(
        'delete-history-item',
        body: {'analysisId': analysisId},
      );
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
      throw MakeupKitLibraryRemoteFailure(
        status: error.status,
        message:
            payload['message']?.toString() ??
            'This kit history item could not be deleted.',
        retryable: payload['retryable'] == true,
      );
    }
  }

  static List<Map<String, Object?>> _rows(List<dynamic> rows) =>
      rows.map((row) => _row(row as Map)).toList();

  static Map<String, Object?> _row(Map row) =>
      row.map((key, value) => MapEntry(key.toString(), value));
}
