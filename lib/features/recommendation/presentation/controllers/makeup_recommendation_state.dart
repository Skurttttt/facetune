import '../../domain/entities/makeup_recommendation.dart';
import '../../domain/errors/recommendation_failure.dart';

enum MakeupRecommendationStatus { idle, generating, success, failure }

class MakeupRecommendationState {
  const MakeupRecommendationState({
    this.status = MakeupRecommendationStatus.idle,
    this.recommendation,
    this.message,
    this.retryable = false,
    this.failureType,
  });

  final MakeupRecommendationStatus status;
  final MakeupRecommendation? recommendation;
  final String? message;
  final bool retryable;
  final RecommendationFailureType? failureType;
}
