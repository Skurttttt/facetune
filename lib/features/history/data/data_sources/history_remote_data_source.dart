import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_remote_data_source.dart';

abstract interface class HistoryRemoteDataSource {
  String? get currentUserId;

  Future<List<Map<String, Object?>>> selectAnalyses({
    required int offset,
    required int limit,
  });

  Future<List<Map<String, Object?>>> selectRecommendations(
    List<String> analysisIds,
  );

  Future<List<Map<String, Object?>>> selectGeneratedImages(
    List<String> analysisIds,
  );

  Future<List<Map<String, Object?>>> selectSavedLooks(
    List<String> generatedImageIds,
  );

  Future<String> createSignedUrl(String storagePath);

  Future<Object?> deleteSession(String analysisId);
}

class HistoryRemoteFailure implements Exception {
  const HistoryRemoteFailure({
    required this.status,
    required this.code,
    required this.message,
    required this.retryable,
  });

  final int status;
  final String code;
  final String message;
  final bool retryable;
}

class SupabaseHistoryRemoteDataSource extends SupabaseRemoteDataSource
    implements HistoryRemoteDataSource {
  const SupabaseHistoryRemoteDataSource(super.client);

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  Future<List<Map<String, Object?>>> selectAnalyses({
    required int offset,
    required int limit,
  }) async => _rows(
    await client
        .from('analyses')
        .select('*')
        .eq('user_id', currentUserId!)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + limit - 1),
  );

  @override
  Future<List<Map<String, Object?>>> selectRecommendations(
    List<String> analysisIds,
  ) => _selectLinked('recommendations', analysisIds);

  @override
  Future<List<Map<String, Object?>>> selectGeneratedImages(
    List<String> analysisIds,
  ) => _selectLinked('generated_images', analysisIds);

  Future<List<Map<String, Object?>>> _selectLinked(
    String table,
    List<String> analysisIds,
  ) async {
    if (analysisIds.isEmpty) return const [];
    return _rows(
      await client
          .from(table)
          .select('*')
          .inFilter('analysis_id', analysisIds)
          .order('created_at', ascending: false),
    );
  }

  @override
  Future<List<Map<String, Object?>>> selectSavedLooks(
    List<String> generatedImageIds,
  ) async {
    if (generatedImageIds.isEmpty) return const [];
    return _rows(
      await client
          .from('saved_looks')
          .select('id, generated_image_id, is_favorite, created_at')
          .inFilter('generated_image_id', generatedImageIds),
    );
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
      throw HistoryRemoteFailure(
        status: error.status,
        code: payload['code']?.toString() ?? '',
        message:
            payload['message']?.toString() ??
            'This history item could not be deleted.',
        retryable: payload['retryable'] == true,
      );
    }
  }

  static List<Map<String, Object?>> _rows(List<dynamic> rows) =>
      rows.map((row) => _row(row as Map)).toList();

  static Map<String, Object?> _row(Map row) =>
      row.map((key, value) => MapEntry(key.toString(), value));
}
