import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../preview/domain/errors/preview_failure.dart';
import '../../domain/entities/kit_generated_preview.dart';
import '../../domain/entities/kit_makeup_recommendation.dart';
import '../../domain/repositories/makeup_kit_look_repository.dart';
import '../data_sources/makeup_kit_look_remote_data_source.dart';
import '../models/kit_generated_preview_dto.dart';
import '../models/kit_makeup_recommendation_dto.dart';

class SupabaseMakeupKitLookRepository implements MakeupKitLookRepository {
  const SupabaseMakeupKitLookRepository(
    this._remote, {
    Duration recommendationTimeout = const Duration(seconds: 105),
    Duration previewTimeout = const Duration(seconds: 180),
    Duration signedUrlTimeout = const Duration(seconds: 30),
  }) : _recommendationTimeout = recommendationTimeout,
       _previewTimeout = previewTimeout,
       _signedUrlTimeout = signedUrlTimeout;

  final MakeupKitLookRemoteDataSource _remote;
  final Duration _recommendationTimeout;
  final Duration _previewTimeout;
  final Duration _signedUrlTimeout;

  @override
  Future<KitMakeupRecommendation> generateRecommendation({
    required String analysisId,
    required String styleCode,
  }) async {
    _requireAuthentication();
    try {
      final response = await _remote
          .generateRecommendation(analysisId: analysisId, styleCode: styleCode)
          .timeout(_recommendationTimeout);
      final recommendation = KitMakeupRecommendationDto.fromResponse(
        response,
      ).recommendation;
      if (recommendation.analysisId != analysisId ||
          recommendation.styleCode != styleCode) {
        throw const FormatException('Recommendation linkage is invalid.');
      }
      return recommendation;
    } catch (error) {
      throw _map(error, stage: 'recommendation');
    }
  }

  @override
  Future<KitGeneratedPreview> generatePreview({
    required KitMakeupRecommendation recommendation,
  }) async {
    _requireAuthentication();
    try {
      final response = await _remote
          .generatePreview(kitRecommendationId: recommendation.id)
          .timeout(_previewTimeout);
      final dto = KitGeneratedPreviewDto.fromResponse(response);
      if (dto.kitRecommendationId != recommendation.id ||
          dto.analysisId != recommendation.analysisId ||
          dto.originalImagePath == dto.generatedImagePath) {
        throw const FormatException('Preview linkage is invalid.');
      }
      final urls = await Future.wait([
        _remote.createSignedUrl(dto.originalImagePath),
        _remote.createSignedUrl(dto.generatedImagePath),
      ]).timeout(_signedUrlTimeout);
      return dto.toDomain(
        originalImageUrl: urls[0],
        generatedImageUrl: urls[1],
      );
    } catch (error) {
      throw _map(error, stage: 'preview');
    }
  }

  void _requireAuthentication() {
    if (_remote.currentUserId == null) {
      throw const PreviewFailure(
        PreviewFailureType.authentication,
        'Sign in before generating a kit-based look.',
      );
    }
  }

  PreviewFailure _map(Object error, {required String stage}) {
    if (error is PreviewFailure) return error;
    if (error is TimeoutException) {
      return PreviewFailure(
        PreviewFailureType.network,
        '$stage generation took too long. Please try again.',
        retryable: true,
        technicalCode: 'GEMINI_TIMEOUT',
      );
    }
    if (error is SocketException) {
      return const PreviewFailure(
        PreviewFailureType.network,
        'Check your connection and try again.',
        retryable: true,
      );
    }
    if (error is MakeupKitLookRemoteFailure) {
      final code = error.code.trim().toUpperCase();
      if (error.status <= 0) {
        return PreviewFailure(
          PreviewFailureType.network,
          'Check your connection and try again.',
          retryable: true,
          technicalCode: code.isEmpty ? 'NETWORK_UNAVAILABLE' : code,
        );
      }
      if (error.status == 401) {
        return const PreviewFailure(
          PreviewFailureType.authentication,
          'Your session expired. Sign in again.',
        );
      }
      if (error.status == 409 || code == 'INVENTORY_CHANGED') {
        return const PreviewFailure(
          PreviewFailureType.validation,
          'A selected product was edited or removed. Create a new kit-based look.',
          technicalCode: 'INVENTORY_CHANGED',
        );
      }
      if (error.status == 400 || error.status == 404 || error.status == 422) {
        return PreviewFailure(
          PreviewFailureType.validation,
          error.message,
          retryable: error.retryable,
          technicalCode: code,
        );
      }
      if (error.status == 429) {
        return const PreviewFailure(
          PreviewFailureType.server,
          'You have reached the AI generation limit for now.',
          retryable: true,
          technicalCode: 'RATE_LIMITED',
        );
      }
      if (code.startsWith('GEMINI_') || code.contains('IMAGE')) {
        return PreviewFailure(
          PreviewFailureType.gemini,
          'The AI service could not create your kit preview right now.',
          retryable: error.retryable,
          technicalCode: code,
        );
      }
      return PreviewFailure(
        PreviewFailureType.server,
        'Your kit-based look could not be generated right now.',
        retryable: error.retryable || error.status >= 500,
        technicalCode: code,
      );
    }
    if (error is FormatException) {
      return const PreviewFailure(
        PreviewFailureType.server,
        'The server returned an invalid kit preview result.',
        retryable: true,
        technicalCode: 'INVALID_FUNCTION_RESPONSE',
      );
    }
    if (error is StorageException) {
      if (int.tryParse(error.statusCode.toString()) == 401) {
        return const PreviewFailure(
          PreviewFailureType.authentication,
          'Your session expired. Sign in again.',
        );
      }
      return const PreviewFailure(
        PreviewFailureType.server,
        'The private kit preview could not be loaded.',
        retryable: true,
      );
    }
    return const PreviewFailure(
      PreviewFailureType.server,
      'Your kit-based look could not be generated.',
      retryable: true,
    );
  }
}
