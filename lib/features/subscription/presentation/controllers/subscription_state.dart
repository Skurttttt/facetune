import '../../domain/entities/subscription_summary.dart';
import '../../domain/errors/subscription_state_failure.dart';

/// The lifecycle of the subscription view state.
///
/// Distinct members rather than a pair of booleans, because `isLoading` plus
/// `hasError` cannot express "showing last known state while refreshing", and
/// the UI needs that: a refresh must not blank out a figure the user is
/// looking at.
enum SubscriptionStatus {
  /// Nothing has been requested yet.
  initial,

  /// First load in flight, with nothing to show behind it.
  loading,

  /// Authoritative state is available.
  ready,

  /// A newer read is in flight while [SubscriptionState.summary] still holds
  /// the previous answer.
  refreshing,

  /// The read failed. [SubscriptionState.summary] may still hold an older
  /// answer worth showing.
  failure,

  /// No session. Any previously loaded state has been discarded.
  signedOut,
}

/// What the subscription surface currently knows.
///
/// [summary] is the server's answer, carried unchanged. This class never
/// computes entitlement, never decrements a balance, and offers no way to do
/// either — the only path to a new value is another server read.
class SubscriptionState {
  const SubscriptionState({
    this.status = SubscriptionStatus.initial,
    this.summary,
    this.message,
    this.failureKind,
    this.retryable = true,
  });

  final SubscriptionStatus status;

  /// The last authoritative answer, if one has been received.
  ///
  /// Deliberately retained through [SubscriptionStatus.refreshing] and
  /// [SubscriptionStatus.failure] so the UI can keep showing the last known
  /// figures instead of flashing empty. It is cleared on
  /// [SubscriptionStatus.signedOut], because one account's allowance must
  /// never be visible to the next.
  final SubscriptionSummary? summary;

  final String? message;
  final SubscriptionStateFailureKind? failureKind;
  final bool retryable;

  /// Whether a value is on screen while a newer one is being fetched.
  bool get isRefreshing => status == SubscriptionStatus.refreshing;

  /// Whether there is anything to show at all.
  bool get hasSummary => summary != null;

  /// Whether the session ended rather than the request failing.
  bool get isSessionFailure =>
      status == SubscriptionStatus.signedOut ||
      failureKind == SubscriptionStateFailureKind.sessionExpired;

  SubscriptionState copyWith({
    SubscriptionStatus? status,
    SubscriptionSummary? summary,
    String? message,
    SubscriptionStateFailureKind? failureKind,
    bool? retryable,
    bool clearMessage = false,
  }) => SubscriptionState(
    status: status ?? this.status,
    summary: summary ?? this.summary,
    message: clearMessage ? null : (message ?? this.message),
    failureKind: clearMessage ? null : (failureKind ?? this.failureKind),
    retryable: retryable ?? this.retryable,
  );

  @override
  bool operator ==(Object other) =>
      other is SubscriptionState &&
      other.status == status &&
      other.summary == summary &&
      other.message == message &&
      other.failureKind == failureKind &&
      other.retryable == retryable;

  @override
  int get hashCode =>
      Object.hash(status, summary, message, failureKind, retryable);
}
