class HistoryFailure implements Exception {
  const HistoryFailure(this.message, {this.retryable = true});

  final String message;
  final bool retryable;

  @override
  String toString() => message;
}
