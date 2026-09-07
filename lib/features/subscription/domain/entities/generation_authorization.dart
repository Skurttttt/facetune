import '../errors/subscription_error_code.dart';

/// The server's answer to "may this user generate a new Final Makeup Preview
/// right now?".
///
/// This is the authoritative access decision. It is a sealed hierarchy so a
/// caller cannot read an "allowed" flag while ignoring the reason, and so the
/// compiler forces every call site to handle refusal. It is deliberately not a
/// `bool`: `if (canGenerate)` discards exactly the information the UI needs to
/// tell "you have used all 3 AI Looks this month" apart from "your subscription
/// is suspended".
///
/// The decision is *produced server-side and carried* here — it is not computed
/// on the client. Nothing in this file inspects an entitlement, counts usage,
/// or checks a date; doing so would create a second entitlement calculator
/// whose answer could disagree with the one that actually governs generation.
sealed class GenerationAuthorization {
  const GenerationAuthorization();

  /// Whether generation was permitted.
  ///
  /// Provided for readability at boundaries such as logging. Prefer matching on
  /// the variant, which also gives access to the reason or the capacity.
  bool get isAuthorized => this is GenerationAuthorized;
}

/// Generation is permitted, and capacity was available at the moment of the
/// decision.
final class GenerationAuthorized extends GenerationAuthorization {
  const GenerationAuthorized({required this.availableAiLooks})
    : assert(
        availableAiLooks > 0,
        'An authorization with no available capacity is a denial.',
      );

  /// Capacity remaining at decision time, including the look this request is
  /// about to reserve.
  ///
  /// A snapshot, not a licence to generate repeatedly: each new generation is
  /// authorized on its own.
  final int availableAiLooks;

  @override
  bool operator ==(Object other) =>
      other is GenerationAuthorized &&
      other.availableAiLooks == availableAiLooks;

  @override
  int get hashCode => availableAiLooks.hashCode;

  @override
  String toString() => 'GenerationAuthorized($availableAiLooks available)';
}

/// Generation is refused, with the sanitized reason.
final class GenerationDenied extends GenerationAuthorization {
  const GenerationDenied(this.reason);

  /// Why the request was refused, from the shared error vocabulary.
  ///
  /// The distinction the UI depends on is capacity versus entitlement:
  /// [SubscriptionErrorCode.aiLookLimitReached] warrants an upgrade prompt,
  /// while [SubscriptionErrorCode.entitlementSuspended] does not and must not
  /// be presented as one.
  final SubscriptionErrorCode reason;

  @override
  bool operator ==(Object other) =>
      other is GenerationDenied && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'GenerationDenied(${reason.code})';
}
