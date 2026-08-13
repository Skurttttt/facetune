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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_auth_repository.dart';

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
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                appBar: AppBar(title: const Text('Overview')),
                body: Center(
                  child: TextButton(
                    onPressed: () =>
                        context.push(AppConstants.makeupKitAddProductRoute),
                    child: const Text('Open add product'),
                  ),
                ),
              ),
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
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open add product'));
  await tester.pumpAndSettle();
}

Future<void> _selectCategory(WidgetTester tester, String label) async {
  await tester.ensureVisible(
    find.byType(DropdownButtonFormField<MakeupKitCategory>),
  );
  await tester.tap(find.byType(DropdownButtonFormField<MakeupKitCategory>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

/// Scrolls the finder into view before tapping it — the form is taller than
/// the default test viewport.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('defaults to Foundation with Depth and Undertone visible', (
    tester,
  ) async {
    await _pump(tester, _FakeRepository());

    expect(find.text('Depth'), findsOneWidget);
    expect(find.text('Undertone'), findsOneWidget);
  });

  testWidgets('Lipstick shows only its documented finishes', (tester) async {
    await _pump(tester, _FakeRepository());

    await _selectCategory(tester, 'Lipstick');

    expect(find.text('Depth'), findsNothing);
    expect(find.text('Matte'), findsOneWidget);
    expect(find.text('Satin'), findsOneWidget);
    expect(find.text('Cream'), findsOneWidget);
    expect(find.text('Glossy'), findsOneWidget);
    expect(find.text('Metallic'), findsNothing);
  });

  testWidgets('Eyeshadow shows only its documented finishes', (tester) async {
    await _pump(tester, _FakeRepository());

    await _selectCategory(tester, 'Eyeshadow');

    expect(find.text('Matte'), findsOneWidget);
    expect(find.text('Satin'), findsOneWidget);
    expect(find.text('Shimmer'), findsOneWidget);
    expect(find.text('Metallic'), findsOneWidget);
    expect(find.text('Glitter'), findsOneWidget);
    expect(find.text('Cream'), findsNothing);
  });

  testWidgets('Blush shows only its documented finishes', (tester) async {
    await _pump(tester, _FakeRepository());

    await _selectCategory(tester, 'Blush');

    expect(find.text('Matte'), findsOneWidget);
    expect(find.text('Satin'), findsOneWidget);
    expect(find.text('Shimmer'), findsOneWidget);
    expect(find.text('Glossy'), findsNothing);
    expect(find.text('Metallic'), findsNothing);
  });

  testWidgets('Eyeliner shows only its documented finishes', (tester) async {
    await _pump(tester, _FakeRepository());

    await _selectCategory(tester, 'Eyeliner');

    expect(find.text('Matte'), findsOneWidget);
    expect(find.text('Satin'), findsOneWidget);
    expect(find.text('Glossy'), findsOneWidget);
    expect(find.text('Cream'), findsNothing);
    expect(find.text('Shimmer'), findsNothing);
  });

  testWidgets(
    'switching away from Foundation clears Depth/Undertone from the draft',
    (tester) async {
      final repository = _FakeRepository();
      await _pump(tester, repository);

      await _tap(tester, find.text('Light'));
      await _tap(tester, find.text('Warm'));
      await _selectCategory(tester, 'Lipstick');
      await _tap(tester, find.text('Add to My Makeup Kit'));

      expect(repository.lastDraft?.category, MakeupKitCategory.lipstick);
      expect(repository.lastDraft?.foundationDepth, isNull);
      expect(repository.lastDraft?.foundationUndertone, isNull);
    },
  );

  testWidgets('saving successfully returns to the previous screen', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await _pump(tester, repository);

    await tester.enterText(
      find.widgetWithText(TextField, 'Product name (optional)'),
      'My Nude Lipstick',
    );
    await _tap(tester, find.text('Add to My Makeup Kit'));

    expect(repository.createCalls, 1);
    expect(repository.lastDraft?.productName, 'My Nude Lipstick');
    expect(find.text('Open add product'), findsOneWidget);
    expect(find.text('Add to My Makeup Kit'), findsNothing);
  });

  testWidgets(
    'a failed save keeps the user on the page with entered values intact',
    (tester) async {
      final repository = _FakeRepository(
        createError: const MakeupKitFailure('The product could not be added.'),
      );
      await _pump(tester, repository);

      await tester.enterText(
        find.widgetWithText(TextField, 'Product name (optional)'),
        'My Nude Lipstick',
      );
      await _tap(tester, find.text('Add to My Makeup Kit'));

      expect(find.text('The product could not be added.'), findsOneWidget);
      expect(find.text('Add to My Makeup Kit'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Product name (optional)'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Product name (optional)'),
            )
            .controller!
            .text,
        'My Nude Lipstick',
      );
    },
  );

  testWidgets('duplicate taps while saving only submit once', (tester) async {
    final pending = Completer<MakeupKitProduct>();
    final repository = _FakeRepository(pending: pending);
    await _pump(tester, repository);

    await tester.ensureVisible(find.text('Add to My Makeup Kit'));
    await tester.tap(find.text('Add to My Makeup Kit'));
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    await tester.tap(find.text('Saving…'), warnIfMissed: false);
    await tester.pump();

    expect(repository.createCalls, 1);

    pending.complete(
      MakeupKitProduct(
        id: 'new',
        userId: 'user-1',
        category: MakeupKitCategory.foundation,
        color: NormalizedHexColor.parse('#F1DFCB'),
        finish: MakeupKitFinish.matte,
        createdAt: DateTime.utc(2026, 8, 13),
        updatedAt: DateTime.utc(2026, 8, 13),
      ),
    );
    await tester.pumpAndSettle();
  });
}

class _FakeRepository implements MakeupKitProductsRepository {
  _FakeRepository({this.createError, this.pending});

  Object? createError;
  Completer<MakeupKitProduct>? pending;
  int createCalls = 0;
  MakeupKitProductDraft? lastDraft;

  @override
  Future<List<MakeupKitProduct>> loadAll() async => const [];

  @override
  Future<List<MakeupKitProduct>> loadByCategory(
    MakeupKitCategory category,
  ) async => const [];

  @override
  Future<MakeupKitProduct> create(MakeupKitProductDraft draft) async {
    createCalls++;
    lastDraft = draft;
    if (pending != null) return pending!.future;
    if (createError != null) throw createError!;
    return MakeupKitProduct(
      id: 'new',
      userId: 'user-1',
      category: draft.category,
      productName: draft.productName,
      color: draft.color,
      colorLabel: draft.colorLabel,
      finish: draft.finish,
      foundationDepth: draft.foundationDepth,
      foundationUndertone: draft.foundationUndertone,
      createdAt: DateTime.utc(2026, 8, 13),
      updatedAt: DateTime.utc(2026, 8, 13),
    );
  }

  @override
  Future<MakeupKitProduct> update(
    String productId,
    MakeupKitProductDraft draft,
  ) => throw UnimplementedError();

  @override
  Future<void> delete(String productId) => throw UnimplementedError();
}
