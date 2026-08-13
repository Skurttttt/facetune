import '../entities/makeup_kit_category.dart';
import '../entities/makeup_kit_product.dart';

abstract interface class MakeupKitProductsRepository {
  Future<List<MakeupKitProduct>> loadAll();

  Future<List<MakeupKitProduct>> loadByCategory(MakeupKitCategory category);

  Future<MakeupKitProduct> create(MakeupKitProductDraft draft);

  Future<MakeupKitProduct> update(
    String productId,
    MakeupKitProductDraft draft,
  );

  Future<void> delete(String productId);
}
