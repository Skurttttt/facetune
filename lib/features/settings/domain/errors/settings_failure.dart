enum SettingsFailureKind {
  offline,
  timeout,
  sessionExpired,
  invalidData,
  unavailable,
  unknown,
}

class SettingsFailure implements Exception {
  const SettingsFailure(
    this.message, {
    this.kind = SettingsFailureKind.unknown,
    this.retryable = true,
  });

  final String message;
  final SettingsFailureKind kind;
  final bool retryable;

  @override
  String toString() => message;
}
