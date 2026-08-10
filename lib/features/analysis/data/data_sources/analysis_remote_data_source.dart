import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_remote_data_source.dart';
import '../../../scan/domain/entities/local_image_validation.dart';

abstract interface class AnalysisRemoteDataSource {
  String? get currentUserId;

  Future<void> uploadSelfie({
    required String localPath,
    required String storagePath,
  });

  Future<Object?> invokeAnalysis({
    required String analysisId,
    required String storagePath,
    required LocalImageValidation localValidation,
  });
}

class AnalysisRemoteFailure implements Exception {
  const AnalysisRemoteFailure({
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

class SupabaseAnalysisRemoteDataSource extends SupabaseRemoteDataSource
    implements AnalysisRemoteDataSource {
  const SupabaseAnalysisRemoteDataSource(super.client);

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  Future<void> uploadSelfie({
    required String localPath,
    required String storagePath,
  }) async {
    await client.storage
        .from('face-images')
        .upload(
          storagePath,
          File(localPath),
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );
  }

  @override
  Future<Object?> invokeAnalysis({
    required String analysisId,
    required String storagePath,
    required LocalImageValidation localValidation,
  }) async {
    try {
      final response = await client.functions.invoke(
        'analyze-face',
        body: {
          'analysisId': analysisId,
          'storagePath': storagePath,
          'localValidation': {
            'mimeType': localValidation.mimeType,
            'byteSize': localValidation.uploadSizeBytes,
            'width': localValidation.width,
            'height': localValidation.height,
          },
        },
      );
      return response.data;
    } on FunctionException catch (error) {
      final details = error.details;
      final payload = details is Map
          ? details.map((key, value) => MapEntry(key.toString(), value))
          : const <String, Object?>{};
      final nested = payload['error'];
      final serverError = nested is Map
          ? nested.map((key, value) => MapEntry(key.toString(), value))
          : payload;
      throw AnalysisRemoteFailure(
        status: error.status,
        code: serverError['code']?.toString() ?? '',
        message:
            serverError['message']?.toString() ??
            'The analysis service is temporarily unavailable.',
        retryable: serverError['retryable'] == true,
      );
    }
  }
}
