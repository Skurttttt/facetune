import 'billing_provider.dart';
import 'entitlement_status.dart';
import 'subscription_allowance.dart';
import 'subscription_period.dart';
import 'subscription_plan_code.dart';

/// One user's server-resolved entitlement.
///
/// This is the aggregate the rest of the app reads: which plan, in what state,
/// billed through whom, valid for what span, and granted how much. Every field
/// arrives from the backend already resolved — this type has no constructor
/// that grants anything, no way to change a status, and no method that decides
/// whether generation may proceed.
///
/// [allowance] is carried here rather than looked up from the plan catalog on
/// demand, because a live entitlement's allowance can validly differ from its
/// plan's configured default: an authorized adjustment to a Salon Pilot grant
/// changes the entitlement, not the plan. The catalog describes plans; this
/// describes a user.
class SubscriptionEntitlement {
  const SubscriptionEntitlement({
    required this.id,
    required this.userId,
    required this.planCode,
    required this.status,
    required this.billingProvider,
    required this.period,
    required this.allowance,
    required this.autoRenew,
    this.providerProductId,
    this.providerSubscriptionReference,
    this.verifiedAt,
  });

  /// The entitlement row's identity.
  final String id;

  /// The account this entitlement belongs to.
  ///
  /// Ownership is enforced server-side; this is carried for correlation and
  /// must never be used as the basis of a client-side ownership decision.
  final String userId;

  /// Which plan this entitlement grants.
  final SubscriptionPlanCode planCode;

  /// The entitlement service's current conclusion about validity.
  final EntitlementStatus status;

  /// The verified billing relationship behind this entitlement.
  final BillingProvider billingProvider;

  /// The span this entitlement covers, and what kind of span it is.
  final SubscriptionPeriod period;

  /// The allowance in force, including any authorized adjustment.
  final SubscriptionAllowance allowance;

  /// Whether the provider reports that this subscription will renew.
  ///
  /// `false` does not mean expired — a cancelled subscription normally stays
  /// entitled until the paid period ends. Always `false` for Free and Salon
  /// Pilot, neither of which renews.
  final bool autoRenew;

  /// The provider's product identifier, when one applies.
  ///
  /// Present for correlation and support only. Mapping a provider product to a
  /// plan code happens server-side; this value must never be used to decide
  /// which plan a user has — [planCode] already states it explicitly.
  final String? providerProductId;

  /// An opaque server-supplied reference to the provider-side subscription.
  ///
  /// This is a reference, never a purchase token or receipt: raw provider
  /// credentials do not belong in the client, in logs, or in this model.
  final String? providerSubscriptionReference;

  /// When the backend last verified this entitlement against the provider.
  ///
  /// Null for entitlements with no provider to verify against, such as Free.
  final DateTime? verifiedAt;
}
