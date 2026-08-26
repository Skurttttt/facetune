enum TutorialV3FailureKind {
  offline,
  timeout,
  sessionExpired,
  validation,
  ownership,
  notFound,
  generation,
  unavailable,
  unknown,
}

class TutorialV3Failure implements Exception {
  const TutorialV3Failure(
    this.message, {
    this.kind = TutorialV3FailureKind.unknown,
    this.retryable = true,
  });

  final String message;
  final TutorialV3FailureKind kind;
  final bool retryable;

  @override
  String toString() => message;
}
