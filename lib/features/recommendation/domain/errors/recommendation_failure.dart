enum RecommendationFailureType {
  authentication,
  validation,
  network,
  server,
  gemini,
}

class RecommendationFailure implements Exception {
  const RecommendationFailure(
    this.type,
    this.message, {
    this.retryable = false,
  });

  final RecommendationFailureType type;
  final String message;
  final bool retryable;
}
