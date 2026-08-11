class ProfileFailure implements Exception {
  const ProfileFailure(this.message, {this.retryable = true});

  final String message;
  final bool retryable;

  @override
  String toString() => message;
}
