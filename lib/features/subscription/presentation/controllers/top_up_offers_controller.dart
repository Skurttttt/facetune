import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/subscription_providers.dart';
import '../../domain/entities/plan_price.dart';
import '../../domain/entities/top_up_pack.dart';
import '../../domain/repositories/top_up_price_source.dart';

enum TopUpOffersStatus { loading, ready, failure }

/// What the paywall knows about top-up pack prices.
///
/// Tracked apart from `PaywallState` so the plan comparison is untouched by
/// packs: the two are different products from the store's point of view, are
/// loaded by different queries, and fail independently. As with plans, prices
/// come only from the provider; an empty map is "no prices", never "free".
class TopUpOffersState {
  const TopUpOffersState({
    this.status = TopUpOffersStatus.loading,
    this.prices = const {},
  });

  final TopUpOffersStatus status;

  /// Localized provider prices, keyed by pack.
  final Map<TopUpPack, PlanPrice> prices;

  bool get hasPrices => prices.isNotEmpty;

  PlanPrice? priceFor(TopUpPack pack) => prices[pack];

  @override
  bool operator ==(Object other) =>
      other is TopUpOffersState &&
      other.status == status &&
      other.prices.length == prices.length &&
      prices.entries.every((entry) => other.prices[entry.key] == entry.value);

  @override
  int get hashCode => Object.hash(status, prices.length);
}

/// Loads localized provider prices for the top-up packs.
final topUpOffersControllerProvider =
    StateNotifierProvider<TopUpOffersController, TopUpOffersState>(
      (ref) =>
          TopUpOffersController(ref.watch(topUpPriceSourceProvider))..load(),
    );

class TopUpOffersController extends StateNotifier<TopUpOffersState> {
  TopUpOffersController(this._prices) : super(const TopUpOffersState());

  final TopUpPriceSource _prices;
  int _epoch = 0;

  Future<void> load() async {
    if (state.status == TopUpOffersStatus.loading && _epoch > 0) return;
    final operation = ++_epoch;
    state = const TopUpOffersState(status: TopUpOffersStatus.loading);
    try {
      final prices = await _prices.loadPrices();
      if (!mounted || operation != _epoch) return;
      state = TopUpOffersState(status: TopUpOffersStatus.ready, prices: prices);
    } on Object {
      if (!mounted || operation != _epoch) return;
      // A price failure hides nothing the page can still say honestly; the
      // packs' contents are catalog facts. Only the action stays disabled.
      state = const TopUpOffersState(status: TopUpOffersStatus.failure);
    }
  }

  Future<void> retry() => load();
}
