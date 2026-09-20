import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
// `BillingResponse` lives in the wrappers library, which the package exports
// separately from its platform API.
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// The single place the Google Play Billing SDK is touched.
///
/// Everything above this file works in domain terms; every `in_app_purchase`
/// type is confined here and in the gateway that maps it. That keeps the SDK
/// out of controllers and widgets, and it means the provider can be swapped or
/// faked without a domain change.
///
/// ## Why every call is guarded
///
/// The plugin resolves its platform implementation through a static that is
/// only set once the plugin has registered. Off Android — a unit test, a
/// desktop debug run — reading it throws, and a store that is present can still
/// be disabled, out of date, or unreachable. None of that is exceptional from
/// the app's point of view: it simply means purchasing is not available right
/// now, which the paywall already knows how to say. So the failures are turned
/// into that answer here rather than propagated as errors that would have to be
/// caught again in every caller.
class GooglePlayBillingDataSource {
  /// [store] is injectable so tests can drive the flow with a fake. Production
  /// passes nothing and the platform instance is resolved lazily.
  GooglePlayBillingDataSource({InAppPurchase? store}) : _injected = store;

  final InAppPurchase? _injected;
  InAppPurchase? _resolved;
  bool _resolutionFailed = false;

  /// The platform instance, or null when the plugin is not usable here.
  InAppPurchase? get _store {
    if (_injected != null) return _injected;
    if (_resolved != null || _resolutionFailed) return _resolved;
    try {
      _resolved = InAppPurchase.instance;
    } on Object {
      // Not registered on this platform. Remembered so the throw happens once
      // rather than on every poll.
      _resolutionFailed = true;
    }
    return _resolved;
  }

  /// Whether the store can be reached and billing used.
  Future<bool> isAvailable() async {
    final store = _store;
    if (store == null) return false;
    try {
      return await store.isAvailable();
    } on Object {
      return false;
    }
  }

  /// Queries [productIds] as subscriptions.
  ///
  /// Returns one entry per *offer*: Play models a subscription as base plans
  /// and offers, and the plugin flattens those into a
  /// [GooglePlayProductDetails] each, all sharing the same product id. Choosing
  /// between them is the gateway's job.
  ///
  /// Identifiers the store did not return are simply absent — the caller must
  /// treat a missing product as "not purchasable", never as "free" and never as
  /// a reason to show a price of its own.
  Future<List<GooglePlayProductDetails>> queryProducts(
    Set<String> productIds,
  ) async {
    final store = _store;
    if (store == null || productIds.isEmpty) {
      return const <GooglePlayProductDetails>[];
    }

    final response = await store.queryProductDetails(productIds);
    if (response.error != null && response.productDetails.isEmpty) {
      throw StoreQueryException(response.error!.message);
    }
    return response.productDetails.whereType<GooglePlayProductDetails>().toList(
      growable: false,
    );
  }

  /// Purchase events from the provider, including unprompted ones.
  ///
  /// Empty when the plugin is unusable, so a listener can always be attached
  /// without a platform check at the call site.
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _store?.purchaseStream ?? const Stream<List<PurchaseDetails>>.empty();

  /// Opens the provider's purchase sheet.
  ///
  /// Subscriptions go through `buyNonConsumable`: a subscription is not
  /// consumed and must never be re-purchasable by being consumed, which is what
  /// the consumable path would do.
  Future<bool> buy(PurchaseParam purchaseParam) async {
    final store = _store;
    if (store == null) return false;
    return store.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Opens the provider's purchase sheet for a top-up pack.
  ///
  /// A pack is a consumable — it must be purchasable again — but it is bought
  /// with `autoConsume: false` on purpose. Auto-consumption would consume on
  /// the device the moment Play reported the purchase, before the server had
  /// verified it or granted anything, and would waive the automatic refund
  /// that protects a purchase nothing was able to verify. Consumption happens
  /// server-side after the grant; see `consume` for the device-side fallback.
  Future<bool> buyTopUp(PurchaseParam purchaseParam) async {
    final store = _store;
    if (store == null) return false;
    return store.buyConsumable(
      purchaseParam: purchaseParam,
      autoConsume: false,
    );
  }

  /// Consumes a top-up purchase with the provider from the device.
  ///
  /// Called only for purchases the backend has verified and granted, and only
  /// when the backend itself could not reach Google to consume — see
  /// `StoreBillingGateway.completeVerifiedTopUp`, which is the only caller.
  /// Returns whether the provider accepted it; a refusal is not an error worth
  /// surfacing, because the grant already exists and the next verification
  /// retries the consumption server-side.
  Future<bool> consume(PurchaseDetails purchase) async {
    final store = _store;
    if (store == null) return false;
    try {
      final addition = store
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition?>();
      if (addition == null) return false;
      final result = await addition.consumePurchase(purchase);
      return result.responseCode == BillingResponse.ok;
    } on Object {
      return false;
    }
  }

  /// Asks the provider to re-deliver this account's existing purchases.
  ///
  /// Play answers on [purchaseStream] rather than here, with a `restored`
  /// status per purchase it still considers owned. Nothing is returned because
  /// nothing here is an answer: the recovered purchases take the same route to
  /// the server as a fresh one, and the server decides what they are worth.
  Future<void> restorePurchases() async {
    final store = _store;
    if (store == null) return;
    await store.restorePurchases();
  }

  /// Acknowledges a purchase with the provider.
  ///
  /// Called only for purchases the backend has verified — see
  /// `StoreBillingGateway.completeVerifiedPurchase`, which is the only caller
  /// and whose name states the precondition.
  Future<void> complete(PurchaseDetails purchase) async {
    final store = _store;
    if (store == null) return;
    await store.completePurchase(purchase);
  }
}

/// The store was reachable but refused the product query.
///
/// Carries the provider's message for display only; it is a sanitized
/// user-facing string, never a payload the app acts on.
class StoreQueryException implements Exception {
  const StoreQueryException(this.message);

  final String message;

  @override
  String toString() => 'StoreQueryException: $message';
}
