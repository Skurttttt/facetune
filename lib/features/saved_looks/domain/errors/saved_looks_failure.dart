class SavedLooksFailure implements Exception {
  const SavedLooksFailure(this.message, {this.retryable = true});

  final String message;
  final bool retryable;
}
