enum PreviewFailureType { authentication, validation, network, server, gemini }

class PreviewFailure implements Exception {
  const PreviewFailure(
    this.type,
    this.message, {
    this.retryable = false,
    this.technicalCode,
  });

  final PreviewFailureType type;
  final String message;
  final bool retryable;
  final String? technicalCode;
}
