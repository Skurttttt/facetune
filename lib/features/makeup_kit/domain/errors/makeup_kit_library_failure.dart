class MakeupKitLibraryFailure implements Exception {
  const MakeupKitLibraryFailure(
    this.message, {
    this.retryable = true,
    this.sessionExpired = false,
  });

  final String message;
  final bool retryable;
  final bool sessionExpired;
}
