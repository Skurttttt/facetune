import 'plan_price.dart';
import 'subscription_plan_code.dart';

/// One purchasable plan as the store currently describes it.
///
/// Assembled from a provider product query, so every field is the store's own
/// answer for this user in this region. The app contributes only the mapping
/// from [providerProductId] to [planCode]; it contributes no price and no
/// title.
///
/// This is a *catalogue* entry — what is on sale — and says nothing about what
/// the account owns. Holding one confers nothing.
class StoreProduct {
  const StoreProduct({
    required this.planCode,
    required this.providerProductId,
    required this.price,
  });

  /// The internal plan this store product corresponds to.
  ///
  /// Resolved through `StoreProductCatalog`, and used for display and for
  /// matching a tapped plan card to a product. It is not what grants the plan.
  final SubscriptionPlanCode planCode;

  /// The provider's product identifier, carried so a purchase can be launched
  /// and so evidence can name what was bought.
  final String providerProductId;

  /// The store's localized price. Never assembled locally.
  final PlanPrice price;

  @override
  bool operator ==(Object other) =>
      other is StoreProduct &&
      other.planCode == planCode &&
      other.providerProductId == providerProductId &&
      other.price == price;

  @override
  int get hashCode => Object.hash(planCode, providerProductId, price);

  @override
  String toString() => 'StoreProduct(${planCode.code}, $providerProductId)';
}
