import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/subscription_providers.dart';
import '../../domain/repositories/plan_price_source.dart';
import 'paywall_state.dart';
import 'purchase_controller.dart';

/// Whether a purchase can actually be started from this build.
///
/// Now answered by the billing connection rather than being a constant `false`.
/// It reports only that Google Play is reachable and no attempt is already in
/// flight; the paywall additionally requires a *store price for that plan*
/// before enabling its button, so a plan Google Play has no product for still
/// cannot be tapped. The screen therefore never offers a button that silently
/// does nothing, and nothing here grants entitlement.
final purchaseAvailableProvider = Provider<bool>(
  (ref) => ref.watch(purchaseControllerProvider).canPurchase,
);

/// Loads localized provider prices for the paywall.
///
/// Kept apart from `SubscriptionController`: that one carries what the account
/// *has*, this one what the store *offers*. They fail independently, and the
/// plan comparison is still useful when the store is unreachable.
final paywallControllerProvider =
    StateNotifierProvider<PaywallController, PaywallState>(
      (ref) => PaywallController(ref.watch(planPriceSourceProvider))..load(),
    );

class PaywallController extends StateNotifier<PaywallState> {
  PaywallController(this._prices) : super(const PaywallState());

  final PlanPriceSource _prices;
  int _epoch = 0;

  Future<void> load() async {
    if (state.status == PaywallStatus.loading && _epoch > 0) return;
    final operation = ++_epoch;
    state = const PaywallState(status: PaywallStatus.loading);
    try {
      final prices = await _prices.loadPrices();
      if (!mounted || operation != _epoch) return;
      state = PaywallState(status: PaywallStatus.ready, prices: prices);
    } on Object {
      if (!mounted || operation != _epoch) return;
      // A price failure is not a paywall failure. The allowance comparison is
      // still accurate and still worth showing, so this reports ready with no
      // prices rather than blanking the screen.
      state = const PaywallState(
        status: PaywallStatus.failure,
        message: 'Prices could not be loaded. Please try again.',
      );
    }
  }

  Future<void> retry() => load();
}
