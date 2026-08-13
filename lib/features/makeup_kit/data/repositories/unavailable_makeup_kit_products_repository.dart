import '../../domain/entities/makeup_kit_category.dart';
import '../../domain/entities/makeup_kit_product.dart';
import '../../domain/errors/makeup_kit_failure.dart';
import '../../domain/repositories/makeup_kit_products_repository.dart';

class UnavailableMakeupKitProductsRepository
    implements MakeupKitProductsRepository {
  const UnavailableMakeupKitProductsRepository();

  static const _failure = MakeupKitFailure(
    'My Makeup Kit is unavailable in this build.',
    kind: MakeupKitFailureKind.unavailable,
    retryable: false,
  );

  @override
  Future<List<MakeupKitProduct>> loadAll() => throw _failure;

  @override
  Future<List<MakeupKitProduct>> loadByCategory(MakeupKitCategory category) =>
      throw _failure;

  @override
  Future<MakeupKitProduct> create(MakeupKitProductDraft draft) =>
      throw _failure;

  @override
  Future<MakeupKitProduct> update(
    String productId,
    MakeupKitProductDraft draft,
  ) => throw _failure;

  @override
  Future<void> delete(String productId) => throw _failure;
}
