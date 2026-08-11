enum ProfileFailureKind {
  offline,
  timeout,
  sessionExpired,
  invalidData,
  unavailable,
  unknown,
}

class ProfileFailure implements Exception {
  const ProfileFailure(
    this.message, {
    this.kind = ProfileFailureKind.unknown,
    this.retryable = true,
  });

  final String message;
  final ProfileFailureKind kind;
  final bool retryable;

  @override
  String toString() => message;
}
