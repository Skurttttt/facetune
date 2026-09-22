/// A sanitized failure from the read-only Users feature.
enum AdminUsersFailureType { notFound, unavailable }

class AdminUsersFailure implements Exception {
  const AdminUsersFailure(this.type, {this.retryable = false});

  final AdminUsersFailureType type;
  final bool retryable;
}
