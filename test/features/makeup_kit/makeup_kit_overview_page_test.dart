import 'dart:async';

import 'package:facetune/core/constants/app_constants.dart';
import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_products_providers.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_product.dart';
import 'package:facetune/features/makeup_kit/domain/errors/makeup_kit_failure.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_products_repository.dart';
import 'package:facetune/features/makeup_kit/domain/value_objects/normalized_hex_color.dart';
import 'package:facetune/features/makeup_kit/presentation/pages/add_makeup_kit_product_page.dart';
import 'package:facetune/features/makeup_kit/presentation/pages/makeup_kit_overview_page.dart';
import 'package:facetune/shared/widgets/feedback/skeleton_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_auth_repository.dart';

MakeupKitProduct _product(
  String id, {
  MakeupKitCategory category = MakeupKitCategory.lipstick,
  String? productName,
  MakeupKitFinish finish = MakeupKitFinish.matte,
}) => MakeupKitProduct(
  id: id,
  userId: 'user-1',
  category: category,
  productName: productName,
  color: NormalizedHexColor.parse('#B86F72'),
  finish: finish,
  createdAt: DateTime.utc(2026, 8, 13),
  updatedAt: DateTime.utc(2026, 8, 13),
);

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
  testWidgets('shows skeletons while the kit is loading', (tester) async {
    final pending = Completer<List<MakeupKitProduct>>();
    final repository = _FakeRepository(pending: pending);

    await _pump(tester, repository);
    await tester.pump();

    expect(find.byType(SkeletonCard), findsWidgets);
    expect(find.text('My Makeup Kit unavailable'), findsNothing);

    // Resolve the pending load so the controller's internal `.timeout(...)`
    // Timer is cancelled before the test ends; otherwise flutter_test's
    // pending-timer invariant check fails the test. Plain `pump()` (not
    // `pumpAndSettle()`) — SkeletonCard's animation repeats forever, so
    // settling would spin until pumpAndSettle's own timeout.
    pending.complete(const []);
    await tester.pump();
    await tester.pump();
    expect(find.byType(SkeletonCard), findsNothing);
  });

  testWidgets('the Add Product action navigates to the add-product form', (
    tester,
  ) async {
    final repository = _FakeRepository(items: const []);

    await _pump(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Your kit is empty'), findsOneWidget);
    expect(find.text('Add Product'), findsWidgets);

    await tester.tap(find.text('Add Product').first);
    await tester.pumpAndSettle();

    expect(find.text('Add to My Makeup Kit'), findsOneWidget);
    expect(find.text('Your kit is empty'), findsNothing);
  });

  testWidgets('shows populated categories with product details', (
    tester,
  ) async {
    final repository = _FakeRepository(
      items: [
        _product('a', productName: 'My Nude Lipstick'),
        _product(
          'b',
          category: MakeupKitCategory.blush,
          finish: MakeupKitFinish.satin,
        ),
      ],
    );

    await _pump(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Lipstick'), findsOneWidget);
    expect(find.text('Blush'), findsOneWidget);
    expect(find.text('My Nude Lipstick'), findsOneWidget);
    expect(find.text('Matte'), findsOneWidget);
    expect(find.text('Satin'), findsOneWidget);
    expect(find.text('No products in this category yet.'), findsWidgets);
    expect(find.text('Your kit is empty'), findsNothing);
  });

  testWidgets('shows a retryable error state and retries on tap', (
    tester,
  ) async {
    final repository = _FakeRepository(
      loadError: const MakeupKitFailure('Your makeup kit could not be loaded.'),
    );

    await _pump(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('My Makeup Kit unavailable'), findsOneWidget);
    expect(find.text('Your makeup kit could not be loaded.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    repository.loadError = null;
    repository.items = [_product('a')];
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('My Makeup Kit unavailable'), findsNothing);
    expect(find.text('Lipstick'), findsOneWidget);
  });
}

class _FakeRepository implements MakeupKitProductsRepository {
  _FakeRepository({
    List<MakeupKitProduct> items = const [],
    this.pending,
    this.loadError,
  }) : items = List.of(items);

  List<MakeupKitProduct> items;
  Completer<List<MakeupKitProduct>>? pending;
  Object? loadError;

  @override
  Future<List<MakeupKitProduct>> loadAll() async {
    if (pending != null) return pending!.future;
    if (loadError != null) throw loadError!;
    return items;
  }

  @override
  Future<List<MakeupKitProduct>> loadByCategory(
    MakeupKitCategory category,
  ) async => items.where((item) => item.category == category).toList();

  @override
  Future<MakeupKitProduct> create(MakeupKitProductDraft draft) =>
      throw UnimplementedError();

  @override
  Future<MakeupKitProduct> update(
    String productId,
    MakeupKitProductDraft draft,
  ) => throw UnimplementedError();

  @override
  Future<void> delete(String productId) => throw UnimplementedError();
}
