import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_remote_data_source.dart';

abstract interface class RecommendationRemoteDataSource {
  String? get currentUserId;

  Future<Object?> invoke({
    required String analysisId,
    required String styleCode,
  });
}

class RecommendationRemoteFailure implements Exception {
  const RecommendationRemoteFailure({
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

class SupabaseRecommendationRemoteDataSource extends SupabaseRemoteDataSource
    implements RecommendationRemoteDataSource {
  const SupabaseRecommendationRemoteDataSource(super.client);

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  Future<Object?> invoke({
    required String analysisId,
    required String styleCode,
  }) async {
    try {
      final response = await client.functions.invoke(
        'generate-makeup-recommendation',
        body: {'analysisId': analysisId, 'style': styleCode},
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
      throw RecommendationRemoteFailure(
        status: error.status,
        code: payload['code']?.toString() ?? '',
        message:
            payload['message']?.toString() ??
            'Your makeup plan could not be generated.',
        retryable: payload['retryable'] == true,
      );
    }
  }
}
