/// A sanitized failure from a read-only admin listing.
///
/// Reads have exactly two failure outcomes that the page distinguishes: the
/// server refused or could not answer (`unavailable`, possibly retryable),
/// or the browser sent something the server does not accept — a filter
/// outside the vocabulary or a cursor that does not match the current filters
/// (`rejected`, never retryable as-is). Authentication and authorization
/// refusals are not read failures; they surface as `AdminAuthFailure` and are
/// handled by the authorization controller.
enum AdminReadFailureType { unavailable, rejected }

class AdminReadFailure implements Exception {
  const AdminReadFailure(this.type, {this.retryable = false});

  final AdminReadFailureType type;
  final bool retryable;

  @override
  String toString() => 'AdminReadFailure(${type.name})';
}
