class SavedLooksFailure implements Exception {
  const SavedLooksFailure(
    this.message, {
    this.retryable = true,
    this.sessionExpired = false,
  });

  final String message;
  final bool retryable;
  final bool sessionExpired;
}
