import '../../features/subscription/domain/entities/purchased_credit_summary.dart';
import '../../features/subscription/domain/entities/billing_provider.dart';
import '../../features/subscription/domain/entities/entitlement_status.dart';
import '../../features/subscription/domain/entities/subscription_plan_code.dart';
import '../../features/subscription/domain/entities/usage_status.dart';

/// Human-readable labels over the Shared Contract vocabulary.
///
/// Labels are presentation only. The canonical codes stay underneath every
/// filter, key, and comparison; nothing here is ever sent back to the server.

String entitlementStatusLabel(EntitlementStatus status) => switch (status) {
  EntitlementStatus.pending => 'Pending',
  EntitlementStatus.active => 'Active',
  EntitlementStatus.gracePeriod => 'Grace Period',
  EntitlementStatus.expired => 'Expired',
  EntitlementStatus.suspended => 'Suspended',
  EntitlementStatus.revoked => 'Revoked',
};

String billingProviderLabel(BillingProvider provider) => switch (provider) {
  BillingProvider.none => 'None',
  BillingProvider.googlePlay => 'Google Play',
  BillingProvider.appleAppStore => 'Apple App Store',
  BillingProvider.adminGranted => 'Admin Granted',
};

/// The plan code as its own label. Display names come from the server row
/// where one is present; the code is what the filter shows.
String planCodeLabel(SubscriptionPlanCode plan) => switch (plan) {
  SubscriptionPlanCode.free => 'Free',
  SubscriptionPlanCode.plus => 'Plus',
  SubscriptionPlanCode.plusPreview => 'Plus Preview',
  SubscriptionPlanCode.pro => 'Pro',
  SubscriptionPlanCode.proPreview => 'Pro Preview',
  SubscriptionPlanCode.salonPro => 'Salon Pro',
  SubscriptionPlanCode.salonPreview => 'Salon Preview',
  SubscriptionPlanCode.salonPilot => 'Salon Pilot',
};

String usageStatusLabel(UsageStatus status) => switch (status) {
  UsageStatus.reserved => 'Reserved',
  UsageStatus.committed => 'Committed',
  UsageStatus.released => 'Released',
};

String allowanceSourceLabel(AllowanceSource source) => switch (source) {
  AllowanceSource.subscription => 'Subscription',
  AllowanceSource.purchasedCredit => 'Purchased credit',
};

/// `YYYY-MM-DD UTC`, for dates whose time of day carries no meaning.
String formatUtcDate(DateTime value) {
  final utc = value.toUtc();
  return '${utc.year}-${_two(utc.month)}-${_two(utc.day)} UTC';
}

/// `YYYY-MM-DD HH:MM:SS UTC`, for ledger timestamps.
String formatUtcDateTime(DateTime value) {
  final utc = value.toUtc();
  return '${utc.year}-${_two(utc.month)}-${_two(utc.day)} '
      '${_two(utc.hour)}:${_two(utc.minute)}:${_two(utc.second)} UTC';
}

/// The first eight and last four characters of a UUID, for dense tables.
/// The full value is always available through a tooltip or selection.
String shortId(String value) => value.length <= 14
    ? value
    : '${value.substring(0, 8)}…${value.substring(value.length - 4)}';

String _two(int number) => number.toString().padLeft(2, '0');
