import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../recommendation/domain/entities/makeup_recommendation.dart';
import '../../domain/entities/generated_preview.dart';
import '../../domain/errors/preview_failure.dart';
import '../../domain/repositories/makeup_preview_repository.dart';
import '../data_sources/preview_remote_data_source.dart';
import '../models/generated_preview_dto.dart';

class SupabaseMakeupPreviewRepository implements MakeupPreviewRepository {
  const SupabaseMakeupPreviewRepository(
    this._remoteDataSource, {
    Duration timeout = const Duration(seconds: 150),
  }) : _timeout = timeout;

  final PreviewRemoteDataSource _remoteDataSource;
  final Duration _timeout;

  @override
  Future<GeneratedPreview> generate({
    required MakeupRecommendation recommendation,
  }) async {
    if (_remoteDataSource.currentUserId == null) {
      throw const PreviewFailure(
        PreviewFailureType.authentication,
        'Sign in before generating a makeup preview.',
      );
    }
    try {
      final response = await _remoteDataSource
          .invoke(recommendationId: recommendation.id)
          .timeout(_timeout);
      final dto = GeneratedPreviewDto.fromResponse(response);
      if (dto.recommendationId != recommendation.id ||
          dto.analysisId != recommendation.analysisId ||
          dto.generatedImagePath == dto.originalImagePath) {
        throw const FormatException('Preview linkage is invalid.');
      }
      final urls = await Future.wait([
        _remoteDataSource.createSignedUrl(dto.originalImagePath),
        _remoteDataSource.createSignedUrl(dto.generatedImagePath),
      ]);
      return dto.toDomain(
        originalImageUrl: urls[0],
        generatedImageUrl: urls[1],
      );
    } on PreviewFailure {
      rethrow;
    } on TimeoutException {
      throw const PreviewFailure(
        PreviewFailureType.network,
        'Preview generation took too long. Please try again.',
        retryable: true,
        technicalCode: 'GEMINI_TIMEOUT',
      );
    } on SocketException {
      throw const PreviewFailure(
        PreviewFailureType.network,
        'Check your connection and try again.',
        retryable: true,
      );
    } on PreviewRemoteFailure catch (error) {
      final technicalCode = error.code.trim().isEmpty
          ? 'UNKNOWN_ERROR'
          : error.code.trim().toUpperCase();
      if (error.status == 401) {
        throw const PreviewFailure(
          PreviewFailureType.authentication,
          'Your session expired. Sign in again.',
        );
      }
      if (error.status == 400 || error.status == 404 || error.status == 422) {
        throw PreviewFailure(
          PreviewFailureType.validation,
          error.message,
          retryable: error.retryable,
          technicalCode: technicalCode,
        );
      }
      if (technicalCode.startsWith('GEMINI_') ||
          technicalCode.contains('IMAGE_')) {
        throw PreviewFailure(
          PreviewFailureType.gemini,
          error.message,
          retryable: error.retryable,
          technicalCode: technicalCode,
        );
      }
      throw PreviewFailure(
        PreviewFailureType.server,
        error.message,
        retryable: error.retryable || error.status >= 500,
        technicalCode: technicalCode,
      );
    } on FormatException {
      throw const PreviewFailure(
        PreviewFailureType.server,
        'The server returned an invalid preview result.',
        retryable: true,
        technicalCode: 'INVALID_FUNCTION_RESPONSE',
      );
    } on StorageException {
      throw const PreviewFailure(
        PreviewFailureType.server,
        'The private preview could not be loaded.',
        retryable: true,
        technicalCode: 'UNKNOWN_ERROR',
      );
    } catch (_) {
      throw const PreviewFailure(
        PreviewFailureType.server,
        'Your makeup preview could not be generated.',
        retryable: true,
      );
    }
  }
}
