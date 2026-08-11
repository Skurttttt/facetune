class HistoryFailure implements Exception {
  const HistoryFailure(
    this.message, {
    this.retryable = true,
    this.sessionExpired = false,
  });

  final String message;
  final bool retryable;
  final bool sessionExpired;

  @override
  String toString() => message;
}
