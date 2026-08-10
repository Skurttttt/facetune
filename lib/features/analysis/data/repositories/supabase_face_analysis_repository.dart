import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../scan/domain/entities/local_image_validation.dart';
import '../../../scan/domain/entities/prepared_selfie.dart';
import '../../domain/entities/face_analysis.dart';
import '../../domain/errors/analysis_failure.dart';
import '../../domain/repositories/face_analysis_repository.dart';
import '../data_sources/analysis_remote_data_source.dart';
import '../models/face_analysis_dto.dart';

class SupabaseFaceAnalysisRepository implements FaceAnalysisRepository {
  const SupabaseFaceAnalysisRepository(
    this._remoteDataSource, {
    Uuid uuid = const Uuid(),
    Duration functionTimeout = const Duration(seconds: 105),
    int maximumAttempts = 2,
  }) : _uuid = uuid,
       _functionTimeout = functionTimeout,
       _maximumAttempts = maximumAttempts;

  final AnalysisRemoteDataSource _remoteDataSource;
  final Uuid _uuid;
  final Duration _functionTimeout;
  final int _maximumAttempts;

  @override
  Future<FaceAnalysis> analyze({
    required PreparedSelfie selfie,
    required LocalImageValidation localValidation,
    required void Function(AnalysisProgress progress) onProgress,
  }) async {
    final userId = _remoteDataSource.currentUserId;
    if (userId == null) {
      throw const AnalysisFailure(
        AnalysisFailureType.authentication,
        'Sign in before analyzing a selfie.',
      );
    }
    final analysisId = _uuid.v4();
    final imageId = _uuid.v4();
    final storagePath = '$userId/analyses/$analysisId/original/$imageId.jpg';
    try {
      onProgress(AnalysisProgress.uploading);
      await _remoteDataSource.uploadSelfie(
        localPath: selfie.uploadPath,
        storagePath: storagePath,
      );
      onProgress(AnalysisProgress.secureProcessing);
      Object? response;
      for (var attempt = 1; attempt <= _maximumAttempts; attempt += 1) {
        try {
          response = await _remoteDataSource
              .invokeAnalysis(
                analysisId: analysisId,
                storagePath: storagePath,
                localValidation: localValidation,
              )
              .timeout(_functionTimeout);
          break;
        } catch (error) {
          final failure = _mapFailure(error);
          if (!failure.retryable || attempt == _maximumAttempts) rethrow;
        }
      }
      try {
        return FaceAnalysisDto.fromResponse(response).analysis;
      } on FormatException {
        throw const AnalysisFailure(
          AnalysisFailureType.server,
          'The server returned an invalid analysis response.',
          retryable: true,
        );
      }
    } on AnalysisFailure {
      rethrow;
    } catch (error) {
      throw _mapFailure(error);
    }
  }

  AnalysisFailure _mapFailure(Object error) {
    if (error is AnalysisFailure) return error;
    if (error is TimeoutException) {
      return const AnalysisFailure(
        AnalysisFailureType.timeout,
        'Analysis took too long. Please try again.',
        retryable: true,
      );
    }
    if (error is SocketException) {
      return const AnalysisFailure(
        AnalysisFailureType.network,
        'Check your connection and try again.',
        retryable: true,
      );
    }
    if (error is AnalysisRemoteFailure) {
      if (error.status == 401) {
        return const AnalysisFailure(
          AnalysisFailureType.authentication,
          'Your session expired. Sign in again.',
        );
      }
      if (error.status == 422) {
        return AnalysisFailure(AnalysisFailureType.validation, error.message);
      }
      if (error.code.startsWith('gemini_') || error.code.contains('ai_')) {
        return AnalysisFailure(
          AnalysisFailureType.gemini,
          error.message,
          retryable: error.retryable,
        );
      }
      return AnalysisFailure(
        AnalysisFailureType.server,
        error.message,
        retryable: error.retryable || error.status >= 500,
      );
    }
    if (error is StorageException) {
      return const AnalysisFailure(
        AnalysisFailureType.server,
        'The private selfie could not be uploaded.',
        retryable: true,
      );
    }
    return const AnalysisFailure(
      AnalysisFailureType.server,
      'The analysis request could not be completed.',
      retryable: true,
    );
  }
}
