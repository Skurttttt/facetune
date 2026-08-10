enum AnalysisFailureType {
  authentication,
  validation,
  timeout,
  network,
  server,
  gemini,
}

class AnalysisFailure implements Exception {
  const AnalysisFailure(this.type, this.message, {this.retryable = false});

  final AnalysisFailureType type;
  final String message;
  final bool retryable;
}
