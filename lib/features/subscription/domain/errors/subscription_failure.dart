import 'subscription_error_code.dart';

/// A sanitized subscription or entitlement failure.
///
/// Shaped to match the existing failure convention in this project (see
/// `PreviewFailure`): a controlled classification, a user-facing message, and a
/// retryability hint, with no provider or database internals attached.
///
/// [code] is the machine-readable classification and drives behaviour;
/// [message] is display copy and must never be parsed.
class SubscriptionFailure implements Exception {
  const SubscriptionFailure(this.code, this.message, {this.retryable = false});

  /// The stable shared classification of what went wrong.
  final SubscriptionErrorCode code;

  /// User-facing copy. Safe to display; never contains internal state.
  final String message;

  /// Whether retrying the same request could plausibly succeed.
  ///
  /// A capacity refusal is not retryable — repeating it just fails again. A
  /// transient backend failure is.
  final bool retryable;

  @override
  String toString() => '${code.code}: $message';
}
