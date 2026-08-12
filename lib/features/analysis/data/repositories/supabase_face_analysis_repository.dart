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
    Duration uploadTimeout = const Duration(seconds: 45),
    Duration functionTimeout = const Duration(seconds: 105),
  }) : _uuid = uuid,
       _uploadTimeout = uploadTimeout,
       _functionTimeout = functionTimeout;

  final AnalysisRemoteDataSource _remoteDataSource;
  final Uuid _uuid;
  final Duration _uploadTimeout;
  final Duration _functionTimeout;

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
      try {
        await _remoteDataSource
            .uploadSelfie(
              localPath: selfie.uploadPath,
              storagePath: storagePath,
            )
            .timeout(_uploadTimeout);
      } on TimeoutException {
        throw const AnalysisFailure(
          AnalysisFailureType.timeout,
          'The selfie upload took too long. Check your connection and try again.',
          retryable: true,
        );
      }
      onProgress(AnalysisProgress.secureProcessing);
      final response = await _remoteDataSource
          .invokeAnalysis(
            analysisId: analysisId,
            storagePath: storagePath,
            localValidation: localValidation,
          )
          .timeout(_functionTimeout);
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
    if (error is FileSystemException) {
      return const AnalysisFailure(
        AnalysisFailureType.validation,
        'The selected image is no longer available. Choose it again.',
      );
    }
    if (error is AuthException) {
      return const AnalysisFailure(
        AnalysisFailureType.authentication,
        'Your session expired. Sign in again.',
      );
    }
    if (error is AnalysisRemoteFailure) {
      final code = error.code.trim().toLowerCase();
      if (error.status <= 0) {
        return const AnalysisFailure(
          AnalysisFailureType.network,
          'Check your connection and try again.',
          retryable: true,
        );
      }
      if (error.status == 401 || error.status == 403) {
        return const AnalysisFailure(
          AnalysisFailureType.authentication,
          'Your session expired. Sign in again.',
        );
      }
      if (error.status == 422) {
        return AnalysisFailure(
          AnalysisFailureType.validation,
          _validationMessages[code] ??
              'That selfie could not be validated. Choose another photo.',
        );
      }
      if (error.status == 404 && code == 'image_not_found') {
        return const AnalysisFailure(
          AnalysisFailureType.validation,
          'The uploaded selfie is no longer available. Choose it again.',
        );
      }
      if (error.status == 429) {
        return const AnalysisFailure(
          AnalysisFailureType.server,
          'You have reached the analysis limit for now. Please try again later.',
          retryable: true,
        );
      }
      if (error.status == 408 || error.status == 504) {
        return const AnalysisFailure(
          AnalysisFailureType.timeout,
          'Analysis took too long. Please try again.',
          retryable: true,
        );
      }
      if (code.startsWith('gemini_') || code.contains('ai_')) {
        return AnalysisFailure(
          AnalysisFailureType.gemini,
          code == 'gemini_rate_limited'
              ? 'Analysis is busy. Please try again shortly.'
              : 'Secure analysis is temporarily unavailable. Please try again.',
          retryable: error.retryable,
        );
      }
      if (code == 'server_configuration') {
        return const AnalysisFailure(
          AnalysisFailureType.server,
          'Secure analysis is unavailable right now.',
        );
      }
      return AnalysisFailure(
        AnalysisFailureType.server,
        code == 'persistence_failed'
            ? 'Your analysis could not be saved. Please try again.'
            : 'The analysis service is temporarily unavailable.',
        retryable: error.retryable || error.status >= 500,
      );
    }
    if (error is StorageException) {
      final status = int.tryParse(error.statusCode.toString());
      if (status == 401 || status == 403) {
        return const AnalysisFailure(
          AnalysisFailureType.authentication,
          'Your session expired. Sign in again.',
        );
      }
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

  static const _validationMessages = <String, String>{
    'no_face': 'No visible face was found. Choose a clear selfie.',
    'multiple_faces':
        'More than one face was found. Choose a selfie with one person.',
    'face_obscured':
        'Your face is too obscured for analysis. Choose a clearer selfie.',
    'insufficient_lighting':
        'The lighting is too dark or uneven. Choose a brighter selfie.',
    'excessive_blur':
        'The selfie is too blurry for analysis. Choose a sharper photo.',
    'poor_framing': 'Center your full face in the frame and try again.',
    'low_confidence':
        'The selfie is not clear enough for a reliable analysis. Try another photo.',
    'invalid_image_size': 'The selfie has an unsupported file size.',
    'invalid_image_type': 'Choose a supported selfie image.',
    'gemini_refusal':
        'This image could not be analyzed. Choose another selfie.',
  };
}
