import '../entities/plan_price.dart';
import '../entities/top_up_pack.dart';

/// Supplies localized prices for the approved top-up packs.
///
/// The one-time-product counterpart of `PlanPriceSource`, and separate from it
/// so the paywall's plan pricing is untouched by top-ups. The rule is the
/// same: a pack the store did not return is simply absent from the map, never
/// filled in from a figure written into the app.
abstract interface class TopUpPriceSource {
  /// Prices keyed by pack, omitting any the provider did not return.
  ///
  /// An empty map means "no prices are available", never "these are free".
  Future<Map<TopUpPack, PlanPrice>> loadPrices();
}
