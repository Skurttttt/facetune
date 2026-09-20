import 'plan_price.dart';
import 'top_up_pack.dart';

/// One purchasable top-up pack as the store currently describes it.
///
/// The one-time-product counterpart of `StoreProduct`: assembled from a
/// provider product query, so the price is the store's own answer for this
/// user in this region. The app contributes only the mapping from
/// [providerProductId] to [pack]; it contributes no price.
///
/// A catalogue entry — what is on sale — and nothing about what the account
/// owns. Holding one confers nothing.
class TopUpStoreProduct {
  const TopUpStoreProduct({
    required this.pack,
    required this.providerProductId,
    required this.price,
  });

  final TopUpPack pack;
  final String providerProductId;

  /// The store's localized price. Never assembled locally.
  final PlanPrice price;

  @override
  bool operator ==(Object other) =>
      other is TopUpStoreProduct &&
      other.pack == pack &&
      other.providerProductId == providerProductId &&
      other.price == price;

  @override
  int get hashCode => Object.hash(pack, providerProductId, price);

  @override
  String toString() => 'TopUpStoreProduct(${pack.code}, $providerProductId)';
}
