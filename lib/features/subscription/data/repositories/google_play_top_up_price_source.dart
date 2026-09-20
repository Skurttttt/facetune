import '../../domain/entities/plan_price.dart';
import '../../domain/entities/top_up_pack.dart';
import '../../domain/repositories/store_billing_gateway.dart';
import '../../domain/repositories/top_up_price_source.dart';

/// Top-up pack prices, taken from Google Play.
///
/// The same rule as `GooglePlayPlanPriceSource`: a pack the store did not
/// return is simply absent from the map, never filled in from a figure written
/// into the app, and an unavailable store is "no prices", not an error.
class GooglePlayTopUpPriceSource implements TopUpPriceSource {
  const GooglePlayTopUpPriceSource(this._store);

  final StoreBillingGateway _store;

  @override
  Future<Map<TopUpPack, PlanPrice>> loadPrices() async {
    if (!await _store.isAvailable()) return const <TopUpPack, PlanPrice>{};

    final products = await _store.loadTopUpProducts();
    return {for (final product in products) product.pack: product.price};
  }
}
