import '../entities/top_up_pack.dart';

/// The approved mapping between Google Play one-time product identifiers and
/// top-up packs.
///
/// The billing SDK needs product identifiers to query and to launch a purchase
/// with, and this is the one place they are written down for packs — the same
/// arrangement as `StoreProductCatalog` for plans, and for the same reason: a
/// product id must not be typed into a widget or a controller.
///
/// **It is not a grant mapping.** The direction that matters — `purchased
/// product id → credits granted` — is resolved by the server against verified
/// provider evidence and its own `top_up_packs` table. [packFor] exists only
/// so the client can label a purchase in progress and route its evidence to
/// the top-up verifier; it must never be used to grant, count, or persist a
/// credit.
abstract final class TopUpPackCatalog {
  /// The approved Google Play product identifiers, keyed by pack.
  ///
  /// Fixed strings following the `facetune_<offer>` convention the
  /// subscription products use. Not derived from [TopUpPack.code], for the
  /// reason `StoreProductCatalog` gives: renaming a pack must never silently
  /// rename a live store product.
  static const Map<TopUpPack, String> _productIds = {
    TopUpPack.extraAiLook: 'facetune_ai_look_topup_1',
    TopUpPack.previewBoost: 'facetune_preview_credit_topup_10',
  };

  /// The product identifiers to query from the store, in pack order.
  static Set<String> get productIds => TopUpPack.values
      .map((pack) => _productIds[pack])
      .whereType<String>()
      .toSet();

  /// The store product identifier for [pack].
  static String productIdFor(TopUpPack pack) => _productIds[pack]!;

  /// The pack a store product identifier corresponds to, or `null` when the
  /// identifier is not one of ours — which includes every subscription
  /// product, so a plan purchase can never be routed to the top-up verifier.
  ///
  /// **Display and routing only.** See the class comment.
  static TopUpPack? packFor(String providerProductId) {
    for (final entry in _productIds.entries) {
      if (entry.value == providerProductId) return entry.key;
    }
    return null;
  }
}
