import '../../domain/entities/plan_price.dart';
import '../../domain/entities/subscription_plan_code.dart';

enum PaywallStatus { loading, ready, failure }

/// What the paywall knows about prices.
///
/// Prices are tracked separately from subscription state because the two fail
/// independently: the store can be unreachable while the account's plan is
/// perfectly well known, and the comparison of allowances is still worth
/// showing when that happens.
class PaywallState {
  const PaywallState({
    this.status = PaywallStatus.loading,
    this.prices = const {},
    this.message,
  });

  final PaywallStatus status;

  /// Localized provider prices, keyed by plan. Empty when the provider has not
  /// supplied any — which is the normal state until billing is wired.
  final Map<SubscriptionPlanCode, PlanPrice> prices;

  final String? message;

  /// Whether any price at all could be shown.
  bool get hasPrices => prices.isNotEmpty;

  PlanPrice? priceFor(SubscriptionPlanCode plan) => prices[plan];

  @override
  bool operator ==(Object other) =>
      other is PaywallState &&
      other.status == status &&
      other.message == message &&
      _samePrices(other.prices, prices);

  static bool _samePrices(
    Map<SubscriptionPlanCode, PlanPrice> a,
    Map<SubscriptionPlanCode, PlanPrice> b,
  ) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(status, message, prices.length);
}
