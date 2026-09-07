import '../../domain/entities/billing_provider.dart';
import '../../domain/entities/entitlement_status.dart';
import '../../domain/entities/reset_policy.dart';
import '../../domain/entities/subscription_plan_code.dart';
import '../../domain/entities/subscription_summary.dart';
import '../../domain/entities/subscription_usage_summary.dart';

/// Maps the `resolve_subscription_state()` payload into the domain.
///
/// Parsing is strict about identity and lenient about nothing that matters. An
/// unrecognised plan code or status is a [FormatException], never a silent
/// fallback: coercing an unknown status to `active`, or an unknown plan to a
/// paid one, would be the client inventing entitlement out of a parse error.
///
/// The counts are read as the server sent them. They are not recomputed here —
/// re-deriving `availableAiLooks` on the client would create a second answer
/// that could disagree with the one that actually governs generation.
abstract final class SubscriptionSummaryDto {
  static SubscriptionSummary fromResponse(Object? payload) {
    final data = _object(payload, 'subscription state');

    final planCodeValue = _string(data, 'planCode');
    final planCode = SubscriptionPlanCode.fromCode(planCodeValue);
    if (planCode == null) {
      throw const FormatException('The subscription plan is not recognised.');
    }

    final hasEntitlement = data['hasEntitlement'] == true;

    final statusValue = data['entitlementStatus'];
    EntitlementStatus? status;
    if (statusValue != null) {
      status = EntitlementStatus.fromCode(statusValue.toString());
      if (status == null) {
        throw const FormatException(
          'The entitlement status is not recognised.',
        );
      }
    }

    final providerValue = data['billingProvider'];
    final billingProvider = providerValue == null
        ? BillingProvider.none
        : BillingProvider.fromCode(providerValue.toString());
    if (billingProvider == null) {
      throw const FormatException('The billing provider is not recognised.');
    }

    final resetValue = data['resetPolicy'];
    final resetPolicy = resetValue == null
        ? ResetPolicy.none
        : ResetPolicy.fromCode(resetValue.toString());
    if (resetPolicy == null) {
      throw const FormatException('The reset policy is not recognised.');
    }

    // Clamped at zero before construction. The server already refuses to
    // report negative capacity; this makes a malformed payload impossible to
    // turn into an assertion crash in release-mode arithmetic.
    final usage = SubscriptionUsageSummary(
      effectiveAllowance: _count(data, 'effectiveAllowance'),
      committedUsage: _count(data, 'committedUsage'),
      reservedUsage: _count(data, 'reservedUsage'),
    );

    return SubscriptionSummary(
      hasEntitlement: hasEntitlement,
      planCode: planCode,
      planDisplayName: _optionalString(data, 'planDisplayName') ?? '',
      usage: usage,
      generationAuthorized: data['generationAuthorized'] == true,
      resolvedAt: _time(data, 'resolvedAt') ?? DateTime.now().toUtc(),
      entitlementId: _optionalString(data, 'entitlementId'),
      status: status,
      billingProvider: billingProvider,
      resetPolicy: resetPolicy,
      periodStart: _time(data, 'periodStart'),
      periodEnd: _time(data, 'periodEnd'),
      startsAt: _time(data, 'startsAt'),
      expiresAt: _time(data, 'expiresAt'),
      resetAt: _time(data, 'resetAt'),
      autoRenew: data['autoRenew'] == true,
      denialReason: _optionalString(data, 'denialReason'),
      verifiedAt: _time(data, 'verifiedAt'),
    );
  }

  static Map<String, Object?> _object(Object? value, String label) {
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    throw FormatException('The $label response is malformed.');
  }

  static String _string(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is String && value.isNotEmpty) return value;
    throw FormatException('$key is missing.');
  }

  static String? _optionalString(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  /// A non-negative count. Accepts `int` and the `num` a JSON decoder may
  /// produce; anything else is malformed rather than assumed to be zero.
  static int _count(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value == null) return 0;
    if (value is int) return value < 0 ? 0 : value;
    if (value is num) {
      final rounded = value.round();
      return rounded < 0 ? 0 : rounded;
    }
    throw FormatException('$key is not a number.');
  }

  static DateTime? _time(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value == null) return null;
    final parsed = DateTime.tryParse(value.toString());
    return parsed?.toUtc();
  }
}
