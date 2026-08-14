/// Mirrors `PreviewFailureType` (preview/domain/errors/preview_failure.dart)
/// with one addition: [notFound], for a requested session/step that does
/// not exist or does not belong to the caller.
enum TutorialFailureType {
  authentication,
  validation,
  network,
  server,
  gemini,
  notFound,
}

class TutorialFailure implements Exception {
  const TutorialFailure(
    this.type,
    this.message, {
    this.retryable = false,
    this.technicalCode,
  });

  final TutorialFailureType type;
  final String message;
  final bool retryable;
  final String? technicalCode;
}
