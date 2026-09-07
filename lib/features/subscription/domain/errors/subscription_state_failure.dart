/// Why a subscription state read failed.
///
/// Separate from `SubscriptionErrorCode`, which is the shared *business*
/// vocabulary describing why generation was refused. This describes why the
/// client could not obtain an answer at all — a distinction that matters
/// because "you have no AI Looks left" is a real, displayable answer, while
/// "the request timed out" is not an answer about entitlement.
enum SubscriptionStateFailureKind {
  /// No active session, or it expired.
  sessionExpired,

  /// The device could not reach the backend.
  offline,

  /// The request did not complete in time.
  timeout,

  /// The server responded, but not with a state this app can read.
  invalidData,

  /// Subscriptions are not available in this build (no backend configured).
  unavailable,

  unknown,
}

/// A failure to read subscription state.
///
/// Follows the shape of `SettingsFailure` and `PreviewFailure`: a controlled
/// kind, user-facing copy, and a retryability hint, with no backend internals.
class SubscriptionStateFailure implements Exception {
  const SubscriptionStateFailure(
    this.message, {
    this.kind = SubscriptionStateFailureKind.unknown,
    this.retryable = true,
  });

  final String message;
  final SubscriptionStateFailureKind kind;
  final bool retryable;

  @override
  String toString() => message;
}
