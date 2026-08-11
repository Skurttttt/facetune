import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../analysis/domain/entities/face_analysis.dart';
import '../../../makeup_styles/domain/entities/makeup_style.dart';
import '../../domain/entities/makeup_recommendation.dart';
import '../../domain/errors/recommendation_failure.dart';
import '../../domain/repositories/makeup_recommendation_repository.dart';
import '../data_sources/recommendation_remote_data_source.dart';
import '../models/makeup_recommendation_dto.dart';

class SupabaseMakeupRecommendationRepository
    implements MakeupRecommendationRepository {
  const SupabaseMakeupRecommendationRepository(
    this._remoteDataSource, {
    Duration timeout = const Duration(seconds: 105),
  }) : _timeout = timeout;

  final RecommendationRemoteDataSource _remoteDataSource;
  final Duration _timeout;

  @override
  Future<MakeupRecommendation> generate({
    required FaceAnalysis analysis,
    required MakeupStyle style,
  }) async {
    if (_remoteDataSource.currentUserId == null) {
      throw const RecommendationFailure(
        RecommendationFailureType.authentication,
        'Sign in before generating a makeup plan.',
      );
    }
    try {
      final response = await _remoteDataSource
          .invoke(analysisId: analysis.id, styleCode: style.code)
          .timeout(_timeout);
      try {
        return MakeupRecommendationDto.fromResponse(response).recommendation;
      } on FormatException {
        throw const RecommendationFailure(
          RecommendationFailureType.server,
          'The server returned an invalid makeup plan.',
          retryable: true,
        );
      }
    } on RecommendationFailure {
      rethrow;
    } on TimeoutException {
      throw const RecommendationFailure(
        RecommendationFailureType.network,
        'Recommendation generation took too long. Please try again.',
        retryable: true,
      );
    } on SocketException {
      throw const RecommendationFailure(
        RecommendationFailureType.network,
        'Check your connection and try again.',
        retryable: true,
      );
    } on RecommendationRemoteFailure catch (error) {
      if (error.status == 401) {
        throw const RecommendationFailure(
          RecommendationFailureType.authentication,
          'Your session expired. Sign in again.',
        );
      }
      if (error.status == 400 || error.status == 404 || error.status == 422) {
        throw RecommendationFailure(
          RecommendationFailureType.validation,
          error.message,
          retryable: error.retryable,
        );
      }
      if (error.code.startsWith('gemini_') || error.code.contains('ai_')) {
        throw RecommendationFailure(
          RecommendationFailureType.gemini,
          error.message,
          retryable: error.retryable,
        );
      }
      throw RecommendationFailure(
        RecommendationFailureType.server,
        error.message,
        retryable: error.retryable || error.status >= 500,
      );
    } on StorageException {
      throw const RecommendationFailure(
        RecommendationFailureType.server,
        'The recommendation service is temporarily unavailable.',
        retryable: true,
      );
    } catch (_) {
      throw const RecommendationFailure(
        RecommendationFailureType.server,
        'Your makeup plan could not be generated.',
        retryable: true,
      );
    }
  }
}
