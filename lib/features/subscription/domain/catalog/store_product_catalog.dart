import '../entities/subscription_plan_code.dart';
import 'subscription_plan_catalog.dart';

/// The approved mapping between Google Play product identifiers and internal
/// plan codes.
///
/// ## What this is for
///
/// The billing SDK needs product identifiers to query and to launch a purchase
/// with, and the Source of Truth explicitly permits them to exist in client
/// purchase configuration for that reason. This is the one place they are
/// written down, so a product id cannot be typed into a widget or a controller.
///
/// ## What this is *not*
///
/// **It is not an entitlement mapping.** The direction that matters —
/// `purchased product id → granted plan` — is resolved by the server against
/// verified provider evidence. [planFor] exists only so the client can label a
/// purchase in progress ("Verifying your FaceTune Pro purchase…"); it must
/// never be used to grant, unlock, or persist a plan. A client that trusted it
/// would be trusting a string it chose itself.
///
/// ## Why Free and Salon Pilot are absent
///
/// Free is the default entitlement with nothing to buy, and Salon Pilot is
/// admin-granted research access. Neither is a store product, and neither may
/// ever become one by editing this file — the entries below are derived from
/// the plans the catalog marks publicly purchasable, and
/// `store_product_catalog_test.dart` fails if the two ever disagree.
abstract final class StoreProductCatalog {
  /// The approved Google Play product identifiers, keyed by plan.
  ///
  /// These strings are fixed by the approved subscription configuration. They
  /// are not derived from [SubscriptionPlanCode.code] on purpose: a store
  /// identifier and an internal plan code are different vocabularies owned by
  /// different systems, and deriving one from the other would silently rename a
  /// live store product the day someone renamed a plan code.
  static const Map<SubscriptionPlanCode, String> _productIds = {
    SubscriptionPlanCode.plus: 'facetune_plus',
    SubscriptionPlanCode.plusPreview: 'facetune_plus_preview',
    SubscriptionPlanCode.pro: 'facetune_pro',
    SubscriptionPlanCode.proPreview: 'facetune_pro_preview',
    SubscriptionPlanCode.salonPro: 'facetune_salon_pro',
    SubscriptionPlanCode.salonPreview: 'facetune_salon_preview',
  };

  /// The product identifiers to query from the store, in plan order.
  static Set<String> get purchasableProductIds => SubscriptionPlanCatalog
      .publiclyPurchasable
      .map((definition) => _productIds[definition.planCode])
      .whereType<String>()
      .toSet();

  /// The store product identifier for [plan], or `null` when the plan is not
  /// publicly purchasable.
  ///
  /// Returning `null` rather than throwing keeps the "not for sale" answer a
  /// normal, handleable one: asking for Salon Pilot's product id is a question
  /// with a correct answer, and that answer is "there isn't one".
  static String? productIdFor(SubscriptionPlanCode plan) => _productIds[plan];

  /// The plan a store product identifier corresponds to, or `null` when the
  /// identifier is not one of ours.
  ///
  /// **Display only.** See the class comment: this labels an in-flight
  /// purchase, and is never authority for what the account is entitled to.
  static SubscriptionPlanCode? planFor(String providerProductId) {
    for (final entry in _productIds.entries) {
      if (entry.value == providerProductId) return entry.key;
    }
    return null;
  }

  /// Whether [plan] can be bought through the store at all.
  static bool isPurchasable(SubscriptionPlanCode plan) =>
      _productIds.containsKey(plan);
}
