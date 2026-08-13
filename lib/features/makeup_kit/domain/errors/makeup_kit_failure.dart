enum MakeupKitFailureKind {
  offline,
  timeout,
  sessionExpired,
  validation,
  notFound,
  unavailable,
  unknown,
}

class MakeupKitFailure implements Exception {
  const MakeupKitFailure(
    this.message, {
    this.kind = MakeupKitFailureKind.unknown,
    this.retryable = true,
  });

  final String message;
  final MakeupKitFailureKind kind;
  final bool retryable;

  @override
  String toString() => message;
}
