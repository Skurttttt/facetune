import '../../../../core/data/supabase_remote_data_source.dart';

abstract interface class SavedLooksRemoteDataSource {
  String? get currentUserId;

  Future<List<Map<String, Object?>>> selectSavedLooks({
    required int offset,
    required int limit,
  });

  Future<Map<String, Object?>?> findSavedLook(String generatedImageId);

  Future<Map<String, Object?>> insertSavedLook({
    required String userId,
    required String generatedImageId,
    required bool favorite,
  });

  Future<Map<String, Object?>> updateFavorite({
    required String savedLookId,
    required bool favorite,
  });

  Future<void> deleteSavedLook(String savedLookId);

  Future<List<Map<String, Object?>>> selectGeneratedImages(List<String> ids);

  Future<List<Map<String, Object?>>> selectRecommendations(List<String> ids);

  Future<List<Map<String, Object?>>> selectAnalyses(List<String> ids);

  Future<String> createSignedUrl(String storagePath);
}

class SupabaseSavedLooksRemoteDataSource extends SupabaseRemoteDataSource
    implements SavedLooksRemoteDataSource {
  const SupabaseSavedLooksRemoteDataSource(super.client);

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  Future<List<Map<String, Object?>>> selectSavedLooks({
    required int offset,
    required int limit,
  }) async => _rows(
    await client
        .from('saved_looks')
        .select('id, generated_image_id, is_favorite, created_at')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1),
  );

  @override
  Future<Map<String, Object?>?> findSavedLook(String generatedImageId) async {
    final row = await client
        .from('saved_looks')
        .select('id, generated_image_id, is_favorite, created_at')
        .eq('generated_image_id', generatedImageId)
        .maybeSingle();
    return row == null ? null : _row(row);
  }

  @override
  Future<Map<String, Object?>> insertSavedLook({
    required String userId,
    required String generatedImageId,
    required bool favorite,
  }) async => _row(
    await client
        .from('saved_looks')
        .insert({
          'user_id': userId,
          'generated_image_id': generatedImageId,
          'is_favorite': favorite,
        })
        .select('id, generated_image_id, is_favorite, created_at')
        .single(),
  );

  @override
  Future<Map<String, Object?>> updateFavorite({
    required String savedLookId,
    required bool favorite,
  }) async => _row(
    await client
        .from('saved_looks')
        .update({'is_favorite': favorite})
        .eq('id', savedLookId)
        .select('id, generated_image_id, is_favorite, created_at')
        .single(),
  );

  @override
  Future<void> deleteSavedLook(String savedLookId) async {
    await client.from('saved_looks').delete().eq('id', savedLookId);
  }

  @override
  Future<List<Map<String, Object?>>> selectGeneratedImages(List<String> ids) =>
      _selectByIds('generated_images', '*', ids);

  @override
  Future<List<Map<String, Object?>>> selectRecommendations(List<String> ids) =>
      _selectByIds('recommendations', '*', ids);

  @override
  Future<List<Map<String, Object?>>> selectAnalyses(List<String> ids) =>
      _selectByIds('analyses', '*', ids);

  Future<List<Map<String, Object?>>> _selectByIds(
    String table,
    String columns,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const [];
    return _rows(await client.from(table).select(columns).inFilter('id', ids));
  }

  @override
  Future<String> createSignedUrl(String storagePath) =>
      client.storage.from('face-images').createSignedUrl(storagePath, 3600);

  static List<Map<String, Object?>> _rows(List<dynamic> rows) =>
      rows.map((row) => _row(row as Map)).toList();

  static Map<String, Object?> _row(Map row) =>
      row.map((key, value) => MapEntry(key.toString(), value));
}
