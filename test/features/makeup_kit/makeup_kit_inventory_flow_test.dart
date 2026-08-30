import 'package:facetune/core/constants/app_constants.dart';
import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_products_providers.dart';
import 'package:facetune/features/makeup_kit/domain/entities/foundation_depth.dart';
import 'package:facetune/features/makeup_kit/domain/entities/foundation_undertone.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_product.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_products_repository.dart';
import 'package:facetune/features/makeup_kit/domain/value_objects/normalized_hex_color.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_products_controller.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_products_state.dart';
import 'package:facetune/features/makeup_kit/presentation/pages/add_makeup_kit_product_page.dart';
import 'package:facetune/features/makeup_kit/presentation/pages/makeup_kit_overview_page.dart';
import 'package:facetune/features/tutorial/domain/entities/look_product_snapshot.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_auth_repository.dart';

/// Inventory-flow coverage required by V4-3 that the shipped My Makeup Kit
/// tests did not already provide: the empty kit, several products in one
/// category, a fully incomplete product, and — most importantly — proof that
/// deleting an owned product cannot disturb a historical look.
MakeupKitProduct _product(
  String id, {
  MakeupKitCategory category = MakeupKitCategory.lipstick,
  MakeupKitFinish finish = MakeupKitFinish.matte,
  String? productName,
  String? colorLabel,
  String colorHex = '#B86F72',
  FoundationDepth? foundationDepth,
  FoundationUndertone? foundationUndertone,
}) => MakeupKitProduct(
  id: id,
  userId: 'user-1',
  category: category,
  productName: productName,
  color: NormalizedHexColor.parse(colorHex),
  colorLabel: colorLabel,
  finish: finish,
  foundationDepth: foundationDepth,
  foundationUndertone: foundationUndertone,
  createdAt: DateTime.utc(2026, 8, 30),
  updatedAt: DateTime.utc(2026, 8, 30),
);

MakeupKitProductDraft _draft({
  MakeupKitCategory category = MakeupKitCategory.lipstick,
  MakeupKitFinish finish = MakeupKitFinish.matte,
  String? productName,
}) => MakeupKitProductDraft(
  category: category,
  productName: productName,
  color: NormalizedHexColor.parse('#B86F72'),
  finish: finish,
);

class _FakeRepository implements MakeupKitProductsRepository {
  _FakeRepository({List<MakeupKitProduct> items = const [], this.createResult})
    : items = List<MakeupKitProduct>.from(items);

  List<MakeupKitProduct> items;
  MakeupKitProduct? createResult;
  final List<String> deletedIds = <String>[];

  @override
  Future<List<MakeupKitProduct>> loadAll() async => items;

  @override
  Future<List<MakeupKitProduct>> loadByCategory(
    MakeupKitCategory category,
  ) async => items.where((item) => item.category == category).toList();

  @override
  Future<MakeupKitProduct> create(MakeupKitProductDraft draft) async =>
      createResult ?? _product('created', category: draft.category);

  @override
  Future<MakeupKitProduct> update(
    String productId,
    MakeupKitProductDraft draft,
  ) async => _product(productId, category: draft.category);

  @override
  Future<void> delete(String productId) async => deletedIds.add(productId);
}

Future<void> _pump(
  WidgetTester tester,
  MakeupKitProductsRepository repository,
) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      supabaseAvailableProvider.overrideWithValue(true),
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(
          user: const AuthUser(id: 'user-1', isAnonymous: false),
        ),
      ),
      makeupKitProductsRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: AppConstants.makeupKitRoute,
        routes: [
          GoRoute(
            path: AppConstants.makeupKitRoute,
            builder: (context, state) => const MakeupKitOverviewPage(),
          ),
          GoRoute(
            path: AppConstants.makeupKitAddProductRoute,
            builder: (context, state) => const AddMakeupKitProductPage(),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  group('empty kit', () {
    test('an empty kit is a ready state, not a failure', () async {
      final controller = MakeupKitProductsController(_FakeRepository());
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.status, MakeupKitProductsStatus.ready);
      expect(controller.state.items, isEmpty);
      expect(controller.state.message, isNull);
      for (final category in MakeupKitCategory.values) {
        expect(controller.state.byCategory(category), isEmpty);
      }
    });

    testWidgets('offers to add a product instead of showing an error', (
      tester,
    ) async {
      await _pump(tester, _FakeRepository());
      await tester.pumpAndSettle();

      expect(find.text('Your kit is empty'), findsOneWidget);
      expect(
        find.text(
          'Add the makeup products you own to build personalized looks from them.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('could not be loaded'), findsNothing);
    });
  });

  group('adding the first product', () {
    test('creates from an empty kit and surfaces the new product', () async {
      final repository = _FakeRepository(createResult: _product('first'));
      final controller = MakeupKitProductsController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.state.items, isEmpty);

      final created = await controller.createProduct(_draft());

      expect(created, isTrue);
      expect(controller.state.items.map((p) => p.id), <String>['first']);
      expect(controller.state.isCreating, isFalse);
      expect(controller.state.feedback, 'Product added to your kit.');
      expect(controller.state.feedbackIsError, isFalse);
    });
  });

  group('multiple products in one category', () {
    test('byCategory returns every product of that category', () async {
      final repository = _FakeRepository(
        items: [
          _product('lip-1', productName: 'Everyday Nude'),
          _product('lip-2', productName: 'Evening Red'),
          _product('gloss-1', category: MakeupKitCategory.lipGloss),
          _product('blush-1', category: MakeupKitCategory.blush),
        ],
      );
      final controller = MakeupKitProductsController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      expect(
        controller.state
            .byCategory(MakeupKitCategory.lipstick)
            .map((p) => p.id),
        <String>['lip-1', 'lip-2'],
      );
      expect(
        controller.state.byCategory(MakeupKitCategory.blush).map((p) => p.id),
        <String>['blush-1'],
      );
    });

    test('adding a second product of a category keeps the first', () async {
      final repository = _FakeRepository(
        items: [_product('lip-1', productName: 'Everyday Nude')],
        createResult: _product('lip-2', productName: 'Evening Red'),
      );
      final controller = MakeupKitProductsController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      await controller.createProduct(_draft(productName: 'Evening Red'));

      expect(
        controller.state
            .byCategory(MakeupKitCategory.lipstick)
            .map((p) => p.id),
        <String>['lip-1', 'lip-2'],
      );
    });

    testWidgets('renders several products under one category heading', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakeRepository(
          items: [
            _product('lip-1', productName: 'Everyday Nude'),
            _product(
              'lip-2',
              productName: 'Evening Red',
              finish: MakeupKitFinish.satin,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lipstick'), findsOneWidget);
      expect(find.text('Everyday Nude'), findsOneWidget);
      expect(find.text('Evening Red'), findsOneWidget);
      expect(
        find.text('2 products across 1 category. Incomplete kits are welcome.'),
        findsOneWidget,
      );
    });
  });

  group('incomplete kit', () {
    test('a product with no optional metadata is valid', () async {
      final repository = _FakeRepository(items: [_product('bare')]);
      final controller = MakeupKitProductsController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      final product = controller.state.items.single;
      expect(controller.state.status, MakeupKitProductsStatus.ready);
      expect(product.productName, isNull);
      expect(product.colorLabel, isNull);
      expect(product.foundationDepth, isNull);
      expect(product.foundationUndertone, isNull);
    });

    test('a kit covering only some categories is valid', () async {
      final repository = _FakeRepository(
        items: [
          _product('f', category: MakeupKitCategory.foundation),
          _product('l'),
        ],
      );
      final controller = MakeupKitProductsController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.status, MakeupKitProductsStatus.ready);
      expect(
        controller.state.byCategory(MakeupKitCategory.eyeliner),
        isEmpty,
        reason: 'an uncovered category is normal, not an error',
      );
      expect(controller.state.message, isNull);
    });

    testWidgets('an unnamed product still renders without inventing a name', (
      tester,
    ) async {
      await _pump(tester, _FakeRepository(items: [_product('bare')]));
      await tester.pumpAndSettle();

      expect(find.text('Lipstick'), findsOneWidget);
      expect(find.text('Matte'), findsOneWidget);
      expect(
        find.text('1 product across 1 category. Incomplete kits are welcome.'),
        findsOneWidget,
      );
    });
  });

  group('deleting a product cannot disturb a historical look', () {
    // The kit recommendation persists an immutable product snapshot
    // (kit_makeup_recommendations.product_snapshot_json), and the history path
    // reads only that snapshot — never live inventory. Deleting the underlying
    // product therefore leaves past looks intact.
    KitMakeupRecommendation historicalLook() => KitMakeupRecommendation(
      id: 'kit-rec-1',
      analysisId: 'analysis-1',
      styleCode: 'soft_glam',
      selections: const <KitMakeupSelection>[
        KitMakeupSelection(
          productId: 'lip-1',
          category: 'lipstick',
          colorHex: '#B86F72',
          finish: 'matte',
          placement: 'lips',
          technique: 'blot',
          intensity: 'medium',
        ),
      ],
      productSnapshots: const <KitProductSnapshot>[
        KitProductSnapshot(
          productId: 'lip-1',
          category: 'lipstick',
          colorHex: '#B86F72',
          finish: 'matte',
          productName: 'Everyday Nude',
        ),
      ],
      overallIntensity: 'medium',
      summary: 'A soft everyday look.',
      modelId: 'server-reported-model',
      promptVersion: 'v1',
      createdAt: DateTime.utc(2026, 8, 30),
    );

    test('removes the product from live inventory', () async {
      final repository = _FakeRepository(
        items: [_product('lip-1', productName: 'Everyday Nude')],
      );
      final controller = MakeupKitProductsController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      final deleted = await controller.deleteProduct('lip-1');

      expect(deleted, isTrue);
      expect(repository.deletedIds, <String>['lip-1']);
      expect(controller.state.items, isEmpty);
      expect(controller.state.feedback, 'Product removed from your kit.');
    });

    test('the historical snapshot still resolves after deletion', () async {
      final repository = _FakeRepository(
        items: [_product('lip-1', productName: 'Everyday Nude')],
      );
      final controller = MakeupKitProductsController(repository);
      addTearDown(controller.dispose);
      final look = historicalLook();

      await controller.load();
      await controller.deleteProduct('lip-1');

      expect(controller.state.items, isEmpty);
      // The look still knows exactly which product was used, and how it looked
      // at the time — even though that product no longer exists.
      final snapshot = look.snapshotFor('lip-1');
      expect(snapshot.productName, 'Everyday Nude');
      expect(snapshot.colorHex, '#B86F72');
      expect(snapshot.finish, 'matte');
    });

    test(
      'editing a product does not rewrite the historical snapshot',
      () async {
        final repository = _FakeRepository(
          items: [_product('lip-1', productName: 'Everyday Nude')],
        );
        final controller = MakeupKitProductsController(repository);
        addTearDown(controller.dispose);
        final look = historicalLook();

        await controller.load();
        await controller.updateProduct(
          'lip-1',
          _draft(
            category: MakeupKitCategory.blush,
            finish: MakeupKitFinish.satin,
          ),
        );

        expect(
          controller.state.items.single.category,
          MakeupKitCategory.blush,
          reason: 'live inventory reflects the edit',
        );
        expect(
          look.snapshotFor('lip-1').category,
          'lipstick',
          reason: 'the historical snapshot must not follow the edit',
        );
        expect(look.snapshotFor('lip-1').finish, 'matte');
      },
    );

    test('the tutorial snapshot contract survives deletion too', () async {
      final look = historicalLook();
      final snapshot = LookProductSnapshot.fromKitSnapshots(
        look.productSnapshots,
      );

      expect(snapshot.covers(TutorialCategory.lips), isTrue);
      expect(
        snapshot.itemsFor(TutorialCategory.lips).single.productName,
        'Everyday Nude',
      );
    });
  });
}
