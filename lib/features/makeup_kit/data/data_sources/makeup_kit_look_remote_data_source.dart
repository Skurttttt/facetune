import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_remote_data_source.dart';

abstract interface class MakeupKitLookRemoteDataSource {
  String? get currentUserId;

  Future<Object?> generateRecommendation({
    required String analysisId,
    required String styleCode,
  });

  Future<Object?> generatePreview({required String kitRecommendationId});

  Future<String> createSignedUrl(String storagePath);
}

class MakeupKitLookRemoteFailure implements Exception {
  const MakeupKitLookRemoteFailure({
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

class SupabaseMakeupKitLookRemoteDataSource extends SupabaseRemoteDataSource
    implements MakeupKitLookRemoteDataSource {
  const SupabaseMakeupKitLookRemoteDataSource(super.client);

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  Future<Object?> generateRecommendation({
    required String analysisId,
    required String styleCode,
  }) => _invoke('generate-kit-makeup-recommendation', {
    'analysisId': analysisId,
    'style': styleCode,
  });

  @override
  Future<Object?> generatePreview({required String kitRecommendationId}) =>
      _invoke('generate-kit-makeup-preview', {
        'kitRecommendationId': kitRecommendationId,
      });

  @override
  Future<String> createSignedUrl(String storagePath) =>
      client.storage.from('face-images').createSignedUrl(storagePath, 3600);

  Future<Object?> _invoke(String functionName, Map<String, String> body) async {
    try {
      final response = await client.functions.invoke(functionName, body: body);
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
      throw MakeupKitLookRemoteFailure(
        status: error.status,
        code: payload['code']?.toString() ?? '',
        message:
            payload['message']?.toString() ??
            'Your kit-based look could not be generated.',
        retryable: payload['retryable'] == true,
      );
    }
  }
}
