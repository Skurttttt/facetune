import '../../../features/subscription/domain/errors/subscription_error_code.dart';

/// A typed refusal or failure from the admin session check.
///
/// Uses the Shared Contract error vocabulary already defined for the
/// Subscription domain rather than a second admin-only enum:
///
///   * [SubscriptionErrorCode.authRequired] — no valid session (expired,
///     signed out, tampered)
///   * [SubscriptionErrorCode.adminUnauthorized] — a real session that is not
///     an administrator (normal user, anonymous guest, revoked admin)
///   * [SubscriptionErrorCode.temporaryBackendFailure] — the server could not
///     answer; the caller must treat this as "not authorized right now"
class AdminAuthFailure implements Exception {
  const AdminAuthFailure(this.code, {this.retryable = false});

  final SubscriptionErrorCode code;
  final bool retryable;

  bool get isUnauthenticated => code == SubscriptionErrorCode.authRequired;
  bool get isUnauthorized => code == SubscriptionErrorCode.adminUnauthorized;

  @override
  String toString() => 'AdminAuthFailure(${code.code})';
}
