import '../../domain/entities/plan_price.dart';
import '../../domain/entities/subscription_plan_code.dart';
import '../../domain/repositories/plan_price_source.dart';
import '../../domain/repositories/store_billing_gateway.dart';

/// The paywall's prices, taken from Google Play.
///
/// This is the source `UnavailablePlanPriceSource` was a placeholder for. The
/// shape of the answer is unchanged, and so is the rule behind it: a plan the
/// store did not return is simply absent from the map, never filled in from a
/// figure written into the app.
class GooglePlayPlanPriceSource implements PlanPriceSource {
  const GooglePlayPlanPriceSource(this._store);

  final StoreBillingGateway _store;

  @override
  Future<Map<SubscriptionPlanCode, PlanPrice>> loadPrices() async {
    // An unavailable store is not an error — it is "no prices", which the
    // paywall states plainly while still showing the plan comparison.
    if (!await _store.isAvailable()) {
      return const <SubscriptionPlanCode, PlanPrice>{};
    }

    final products = await _store.loadProducts();
    return {for (final product in products) product.planCode: product.price};
  }
}
