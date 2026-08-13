import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_products_providers.dart';
import 'package:facetune/features/makeup_kit/domain/entities/foundation_depth.dart';
import 'package:facetune/features/makeup_kit/domain/entities/foundation_undertone.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_product.dart';
import 'package:facetune/features/makeup_kit/domain/errors/makeup_kit_failure.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_products_repository.dart';
import 'package:facetune/features/makeup_kit/domain/value_objects/normalized_hex_color.dart';
import 'package:facetune/features/makeup_kit/presentation/pages/makeup_kit_product_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_auth_repository.dart';

final _foundation = MakeupKitProduct(
  id: 'product-1',
  userId: 'user-1',
  category: MakeupKitCategory.foundation,
  productName: 'Daily Base',
  color: NormalizedHexColor.parse('#C99578'),
  colorLabel: 'Warm Beige',
  finish: MakeupKitFinish.natural,
  foundationDepth: FoundationDepth.medium,
  foundationUndertone: FoundationUndertone.warm,
  createdAt: DateTime.utc(2026, 8, 13),
  updatedAt: DateTime.utc(2026, 8, 13),
);

Future<void> _pump(WidgetTester tester, _FakeRepository repository) async {
  await tester.pumpWidget(
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
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: TextButton(
                  onPressed: () => context.push('/product'),
                  child: const Text('My Makeup Kit'),
                ),
              ),
            ),
            GoRoute(
              path: '/product',
              builder: (context, state) =>
                  const MakeupKitProductPage(productId: 'product-1'),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('My Makeup Kit'));
  await tester.pumpAndSettle();
}

Future<void> _selectCategory(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButtonFormField<MakeupKitCategory>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows complete product details', (tester) async {
    await _pump(tester, _FakeRepository());

    expect(find.text('Daily Base'), findsOneWidget);
    expect(find.text('Foundation'), findsOneWidget);
    expect(find.text('Warm Beige (#C99578)'), findsOneWidget);
    expect(find.text('Natural'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Warm'), findsOneWidget);
  });

  testWidgets('editing category clears foundation-only metadata', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await _pump(tester, repository);

    await tester.tap(find.text('Edit Product'));
    await tester.pumpAndSettle();
    await _selectCategory(tester, 'Lipstick');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(repository.lastDraft?.category, MakeupKitCategory.lipstick);
    expect(repository.lastDraft?.foundationDepth, isNull);
    expect(repository.lastDraft?.foundationUndertone, isNull);
    expect(find.text('Lipstick'), findsOneWidget);
  });

  testWidgets('delete requires confirmation and refreshes local inventory', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await _pump(tester, repository);

    await tester.tap(find.text('Delete Product'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, 0);

    await tester.tap(find.text('Delete Product'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(find.text('My Makeup Kit'), findsOneWidget);
  });

  testWidgets('failed delete keeps product and allows retry', (tester) async {
    final repository = _FakeRepository(
      deleteError: const MakeupKitFailure('Could not delete product.'),
    );
    await _pump(tester, repository);

    await tester.tap(find.text('Delete Product'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Could not delete product.'), findsOneWidget);
    expect(find.text('Daily Base'), findsOneWidget);
    expect(find.text('Delete Product'), findsOneWidget);
  });
}

class _FakeRepository implements MakeupKitProductsRepository {
  _FakeRepository({this.deleteError}) : items = [_foundation];

  List<MakeupKitProduct> items;
  Object? deleteError;
  int deleteCalls = 0;
  MakeupKitProductDraft? lastDraft;

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
  Future<MakeupKitProduct> update(
    String productId,
    MakeupKitProductDraft draft,
  ) async {
    lastDraft = draft;
    final updated = MakeupKitProduct(
      id: productId,
      userId: 'user-1',
      category: draft.category,
      productName: draft.productName,
      color: draft.color,
      colorLabel: draft.colorLabel,
      finish: draft.finish,
      foundationDepth: draft.foundationDepth,
      foundationUndertone: draft.foundationUndertone,
      createdAt: _foundation.createdAt,
      updatedAt: DateTime.utc(2026, 8, 13, 1),
    );
    items = [updated];
    return updated;
  }

  @override
  Future<void> delete(String productId) async {
    deleteCalls++;
    if (deleteError != null) throw deleteError!;
    items = [];
  }
}
