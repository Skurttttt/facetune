import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_remote_data_source.dart';

abstract interface class PreviewRemoteDataSource {
  String? get currentUserId;

  Future<Object?> invoke({required String recommendationId});

  Future<String> createSignedUrl(String storagePath);
}

class PreviewRemoteFailure implements Exception {
  const PreviewRemoteFailure({
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

class SupabasePreviewRemoteDataSource extends SupabaseRemoteDataSource
    implements PreviewRemoteDataSource {
  const SupabasePreviewRemoteDataSource(super.client);

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  Future<Object?> invoke({required String recommendationId}) async {
    try {
      final response = await client.functions.invoke(
        'generate-makeup-preview',
        body: {'recommendationId': recommendationId},
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
      throw PreviewRemoteFailure(
        status: error.status,
        code: payload['code']?.toString() ?? '',
        message:
            payload['message']?.toString() ??
            'Your makeup preview could not be generated.',
        retryable: payload['retryable'] == true,
      );
    }
  }

  @override
  Future<String> createSignedUrl(String storagePath) =>
      client.storage.from('face-images').createSignedUrl(storagePath, 3600);
}
