import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_library_providers.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_look_providers.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_products_providers.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_generated_preview.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_look_result.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_product.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_library_repository.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_look_repository.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_products_repository.dart';
import 'package:facetune/features/makeup_kit/domain/value_objects/normalized_hex_color.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_look_controller.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_look_state.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_products_controller.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_result_actions_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_auth_repository.dart';

void main() {
  test('sign-out clears all account-scoped My Makeup Kit state', () async {
    final auth = FakeAuthRepository(
      user: const AuthUser(id: 'user-1', isAnonymous: false),
    );
    final products = _AccountProductsRepository(items: [_product]);
    final container = ProviderContainer(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(auth),
        makeupKitProductsRepositoryProvider.overrideWithValue(products),
        makeupKitLookRepositoryProvider.overrideWithValue(
          const _UnusedLookRepository(),
        ),
        makeupKitLibraryRepositoryProvider.overrideWithValue(
          const _EmptyLibraryRepository(),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await auth.dispose();
    });

    await container.read(makeupKitProductsControllerProvider.notifier).load();
    container
        .read(makeupKitLookControllerProvider.notifier)
        .restore(recommendation: _recommendation, preview: _preview);
    await container
        .read(makeupKitResultActionsControllerProvider.notifier)
        .loadSavedStatus(_preview);

    final oldProducts = container.read(
      makeupKitProductsControllerProvider.notifier,
    );
    expect(container.read(makeupKitProductsControllerProvider).items, [
      _product,
    ]);
    expect(
      container.read(makeupKitLookControllerProvider).status,
      MakeupKitLookStatus.success,
    );
    expect(
      container.read(makeupKitResultActionsControllerProvider).loadedPreviewIds,
      contains(_preview.id),
    );

    products.items = const [];
    await container.read(authControllerProvider.notifier).signOut();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(authControllerProvider).user, isNull);
    expect(
      container.read(makeupKitProductsControllerProvider.notifier),
      isNot(same(oldProducts)),
    );
    expect(container.read(makeupKitProductsControllerProvider).items, isEmpty);
    expect(
      container.read(makeupKitLookControllerProvider).status,
      MakeupKitLookStatus.idle,
    );
    expect(
      container.read(makeupKitResultActionsControllerProvider).loadedPreviewIds,
      isEmpty,
    );
  });
}

final _product = MakeupKitProduct(
  id: '11111111-1111-4111-8111-111111111111',
  userId: 'user-1',
  category: MakeupKitCategory.lipstick,
  color: NormalizedHexColor.parse('#A45B67'),
  finish: MakeupKitFinish.matte,
  createdAt: DateTime.utc(2026, 8, 14),
  updatedAt: DateTime.utc(2026, 8, 14),
);

final _recommendation = KitMakeupRecommendation(
  id: '22222222-2222-4222-8222-222222222222',
  analysisId: '33333333-3333-4333-8333-333333333333',
  styleCode: 'soft_glam',
  selections: const [
    KitMakeupSelection(
      productId: '11111111-1111-4111-8111-111111111111',
      category: 'lipstick',
      colorHex: '#A45B67',
      finish: 'matte',
      placement: 'Across lips',
      technique: 'Apply lightly',
      intensity: 'soft',
    ),
  ],
  productSnapshots: const [
    KitProductSnapshot(
      productId: '11111111-1111-4111-8111-111111111111',
      category: 'lipstick',
      colorHex: '#A45B67',
      finish: 'matte',
    ),
  ],
  overallIntensity: 'soft',
  summary: 'A soft look.',
  modelId: 'model',
  promptVersion: 'prompt',
  createdAt: DateTime.utc(2026, 8, 14),
);

final _preview = KitGeneratedPreview(
  id: '44444444-4444-4444-8444-444444444444',
  analysisId: _recommendation.analysisId,
  kitRecommendationId: _recommendation.id,
  originalImagePath: 'user-1/analyses/analysis/original/image.jpg',
  generatedImagePath: 'user-1/analyses/analysis/kit-generated/preview.png',
  originalImageUrl: 'https://signed.example/original',
  generatedImageUrl: 'https://signed.example/preview',
  generationNumber: 1,
  modelId: 'model',
  promptVersion: 'prompt',
  createdAt: DateTime.utc(2026, 8, 14),
);

class _AccountProductsRepository implements MakeupKitProductsRepository {
  _AccountProductsRepository({required this.items});

  List<MakeupKitProduct> items;

  @override
  Future<List<MakeupKitProduct>> loadAll() async => items;

  @override
  Future<List<MakeupKitProduct>> loadByCategory(
    MakeupKitCategory category,
  ) async => items.where((item) => item.category == category).toList();

  @override
  Future<MakeupKitProduct> create(MakeupKitProductDraft draft) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String productId) => throw UnimplementedError();

  @override
  Future<MakeupKitProduct> update(
    String productId,
    MakeupKitProductDraft draft,
  ) => throw UnimplementedError();
}

class _UnusedLookRepository implements MakeupKitLookRepository {
  const _UnusedLookRepository();

  @override
  Future<KitMakeupRecommendation> generateRecommendation({
    required String analysisId,
    required String styleCode,
  }) => throw UnimplementedError();

  @override
  Future<KitGeneratedPreview> generatePreview({
    required KitMakeupRecommendation recommendation,
  }) => throw UnimplementedError();
}

class _EmptyLibraryRepository implements MakeupKitLibraryRepository {
  const _EmptyLibraryRepository();

  @override
  Future<KitSavedLook?> findSaved(String kitGeneratedImageId) async => null;

  @override
  Future<KitSavedLooksPageResult> loadSavedPage({
    required int offset,
    required int limit,
  }) async => const KitSavedLooksPageResult(items: [], hasMore: false);

  @override
  Future<KitHistoryPageResult> loadHistoryPage({
    required int offset,
    required int limit,
  }) async => const KitHistoryPageResult(items: [], hasMore: false);

  @override
  Future<void> deleteSession(String analysisId) => throw UnimplementedError();

  @override
  Future<void> removeSaved(String savedLookId) => throw UnimplementedError();

  @override
  Future<KitSavedLook> save(
    KitGeneratedPreview preview, {
    bool favorite = false,
  }) => throw UnimplementedError();

  @override
  Future<KitSavedLook> setFavorite(KitSavedLook look, bool isFavorite) =>
      throw UnimplementedError();
}
