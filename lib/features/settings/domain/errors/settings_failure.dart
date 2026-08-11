class SettingsFailure implements Exception {
  const SettingsFailure(this.message, {this.retryable = true});

  final String message;
  final bool retryable;

  @override
  String toString() => message;
}
