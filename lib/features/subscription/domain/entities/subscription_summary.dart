import 'billing_provider.dart';
import 'entitlement_status.dart';
import 'reset_policy.dart';
import 'subscription_plan_code.dart';
import 'subscription_usage_summary.dart';

/// The authoritative subscription state for the signed-in account, as resolved
/// by the server.
///
/// Every field here was computed by `public.resolve_subscription_state()` and
/// carried to the client unchanged. Nothing in this class derives entitlement,
/// and nothing in it can be mutated to grant access: there is no setter, no
/// decrement, and no constructor that manufactures capacity. A stale copy is
/// wrong but never dangerous, because the server re-decides on every
/// generation attempt regardless of what this says.
///
/// [usage] carries the capacity arithmetic. The distinction it draws —
/// `availableAiLooks` for "may I start one now", `remainingAiLooks` for "what
/// do I show" — is the server's, not the client's.
class SubscriptionSummary {
  const SubscriptionSummary({
    required this.hasEntitlement,
    required this.planCode,
    required this.planDisplayName,
    required this.usage,
    required this.generationAuthorized,
    required this.resolvedAt,
    this.entitlementId,
    this.status,
    this.billingProvider = BillingProvider.none,
    this.resetPolicy = ResetPolicy.none,
    this.periodStart,
    this.periodEnd,
    this.startsAt,
    this.expiresAt,
    this.resetAt,
    this.autoRenew = false,
    this.denialReason,
    this.verifiedAt,
  });

  /// Whether an entitlement row exists for this account at all.
  ///
  /// `false` means one has not been provisioned yet — not that the user is on
  /// a lesser plan. Generation is refused in that state rather than assumed.
  final bool hasEntitlement;

  /// The plan governing this account. Falls back to [SubscriptionPlanCode.free]
  /// as the default plan identity when no entitlement exists, which is a label
  /// only — it grants nothing on its own.
  final SubscriptionPlanCode planCode;

  /// Server-supplied product name, e.g. "FaceTune Plus". Display copy only.
  final String planDisplayName;

  /// Server-computed allowance, usage, and capacity.
  final SubscriptionUsageSummary usage;

  /// The server's answer to "may this account generate right now".
  ///
  /// Safe to drive UX affordances from. It is never the gate itself: the
  /// generation request is authorized again server-side, so a stale `true`
  /// here cannot produce an uncharged AI Look.
  final bool generationAuthorized;

  /// When the server resolved this snapshot.
  final DateTime resolvedAt;

  final String? entitlementId;

  /// Null only when no entitlement exists.
  final EntitlementStatus? status;

  final BillingProvider billingProvider;
  final ResetPolicy resetPolicy;

  /// Verified billing period, for recurring plans.
  final DateTime? periodStart;
  final DateTime? periodEnd;

  /// Term of the entitlement, for admin-granted plans.
  final DateTime? startsAt;
  final DateTime? expiresAt;

  /// When the allowance next replenishes, or null when it never does.
  ///
  /// Already resolved server-side to the right date for the plan's reset
  /// policy, so presentation never has to choose between [periodEnd] and
  /// [expiresAt].
  final DateTime? resetAt;

  final bool autoRenew;

  /// Why generation is refused, when it is. From the shared error vocabulary.
  final String? denialReason;

  /// When the backend last verified this against the billing provider.
  final DateTime? verifiedAt;

  /// Whether this plan's allowance ever replenishes.
  bool get replenishes => resetPolicy == ResetPolicy.billingPeriod;

  @override
  bool operator ==(Object other) =>
      other is SubscriptionSummary &&
      other.hasEntitlement == hasEntitlement &&
      other.planCode == planCode &&
      other.planDisplayName == planDisplayName &&
      other.usage == usage &&
      other.generationAuthorized == generationAuthorized &&
      other.resolvedAt == resolvedAt &&
      other.entitlementId == entitlementId &&
      other.status == status &&
      other.billingProvider == billingProvider &&
      other.resetPolicy == resetPolicy &&
      other.periodStart == periodStart &&
      other.periodEnd == periodEnd &&
      other.startsAt == startsAt &&
      other.expiresAt == expiresAt &&
      other.resetAt == resetAt &&
      other.autoRenew == autoRenew &&
      other.denialReason == denialReason &&
      other.verifiedAt == verifiedAt;

  @override
  int get hashCode => Object.hash(
    hasEntitlement,
    planCode,
    planDisplayName,
    usage,
    generationAuthorized,
    resolvedAt,
    entitlementId,
    status,
    billingProvider,
    resetPolicy,
    Object.hash(
      periodStart,
      periodEnd,
      startsAt,
      expiresAt,
      resetAt,
      autoRenew,
      denialReason,
      verifiedAt,
    ),
  );

  @override
  String toString() =>
      'SubscriptionSummary(${planCode.code}, ${status?.code ?? 'none'}, '
      '${usage.remainingAiLooks}/${usage.effectiveAllowance})';
}
