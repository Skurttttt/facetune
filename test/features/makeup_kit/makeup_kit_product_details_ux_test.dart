import 'dart:async';

import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_products_providers.dart';
import 'package:facetune/features/makeup_kit/domain/entities/foundation_depth.dart';
import 'package:facetune/features/makeup_kit/domain/entities/foundation_undertone.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_product.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_products_repository.dart';
import 'package:facetune/features/makeup_kit/domain/value_objects/normalized_hex_color.dart';
import 'package:facetune/features/makeup_kit/presentation/pages/add_makeup_kit_product_page.dart';
import 'package:facetune/features/makeup_kit/presentation/pages/makeup_kit_product_page.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_auth_repository.dart';

MakeupKitProduct _product({
  String id = 'p1',
  MakeupKitCategory category = MakeupKitCategory.foundation,
  String? name,
  String? label,
  String hex = '#5C3A21',
  MakeupKitFinish finish = MakeupKitFinish.natural,
  FoundationDepth? depth,
  FoundationUndertone? undertone,
}) => MakeupKitProduct(
  id: id,
  userId: 'user-1',
  category: category,
  productName: name,
  colorLabel: label,
  color: NormalizedHexColor.parse(hex),
  finish: finish,
  foundationDepth: depth,
  foundationUndertone: undertone,
  createdAt: DateTime.utc(2026, 9, 29),
  updatedAt: DateTime.utc(2026, 9, 29),
);

/// Records every repository call; delete can be held open.
class _RecordingRepository implements MakeupKitProductsRepository {
  _RecordingRepository(this.items);

  List<MakeupKitProduct> items;
  final calls = <String>[];
  final deletedIds = <String>[];
  Completer<void>? holdDelete;

  @override
  Future<List<MakeupKitProduct>> loadAll() async {
    calls.add('loadAll');
    return items;
  }

  @override
  Future<List<MakeupKitProduct>> loadByCategory(
    MakeupKitCategory category,
  ) async {
    calls.add('loadByCategory');
    return items;
  }

  @override
  Future<MakeupKitProduct> create(MakeupKitProductDraft draft) async {
    calls.add('create');
    throw UnimplementedError();
  }

  @override
  Future<MakeupKitProduct> update(
    String productId,
    MakeupKitProductDraft draft,
  ) async {
    calls.add('update');
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String productId) async {
    calls.add('delete');
    deletedIds.add(productId);
    await holdDelete?.future;
    items = items.where((p) => p.id != productId).toList();
  }
}

Future<_RecordingRepository> _pump(
  WidgetTester tester,
  MakeupKitProduct product, {
  Size size = const Size(393, 873),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = _RecordingRepository([product]);
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
                  onPressed: () => context.push('/product/${product.id}'),
                  child: const Text('INVENTORY'),
                ),
              ),
            ),
            GoRoute(
              path: '/product/:id',
              builder: (context, state) =>
                  MakeupKitProductPage(productId: state.pathParameters['id']!),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('INVENTORY'));
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

// By text: TextButton.icon builds a TextButton subclass, which an exact-type
// finder misses.
Finder get _deleteAction => find.text('Delete product');

void main() {
  group('MKUX-P2 Product Details', () {
    testWidgets('a foundation shows every recorded attribute, in order', (
      tester,
    ) async {
      final repository = await _pump(
        tester,
        _product(
          label: 'Deep Espresso',
          depth: FoundationDepth.light,
          undertone: FoundationUndertone.neutral,
        ),
      );

      // Identity: shade label as title, category under it.
      expect(find.text('Deep Espresso'), findsNWidgets(2)); // title + Color
      expect(find.text('Foundation'), findsNWidgets(2)); // subtitle + Category
      // Attributes, label above value, in the target order.
      final order = ['Category', 'Color', 'Finish', 'Depth', 'Undertone'];
      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      for (var i = 1; i < order.length; i++) {
        expect(top(order[i]), greaterThan(top(order[i - 1])));
      }
      expect(find.text('#5C3A21'), findsOneWidget);
      expect(find.text('Natural'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Neutral'), findsOneWidget);
      expect(repository.calls, ['loadAll']);
    });

    testWidgets('fields that do not apply are not shown', (tester) async {
      await _pump(
        tester,
        _product(
          category: MakeupKitCategory.lipstick,
          name: 'Everyday Nude',
          hex: '#B86F72',
          finish: MakeupKitFinish.matte,
        ),
      );

      expect(find.text('Everyday Nude'), findsOneWidget);
      expect(find.text('Lipstick'), findsNWidgets(2));
      expect(find.text('Depth'), findsNothing);
      expect(find.text('Undertone'), findsNothing);
      // No shade label recorded: the colour is its HEX, shown once.
      expect(find.text('#B86F72'), findsOneWidget);
    });

    testWidgets('a foundation with only a depth shows only the depth', (
      tester,
    ) async {
      await _pump(
        tester,
        _product(label: 'Fair Ivory', depth: FoundationDepth.fair),
      );

      expect(find.text('Depth'), findsOneWidget);
      expect(find.text('Fair'), findsOneWidget);
      expect(find.text('Undertone'), findsNothing);
    });

    testWidgets('with no name or shade label, the category is not repeated', (
      tester,
    ) async {
      await _pump(tester, _product(category: MakeupKitCategory.blush));

      // Title falls back to the category (as before); no duplicate subtitle.
      expect(find.text('Blush'), findsNWidgets(2)); // title + Category value
      expect(find.text('#5C3A21'), findsOneWidget);
    });

    testWidgets('Edit opens the same form with the same product', (
      tester,
    ) async {
      final product = _product(
        label: 'Deep Espresso',
        depth: FoundationDepth.light,
      );
      final repository = await _pump(tester, product);

      expect(
        find.widgetWithText(PrimaryButton, 'Edit product'),
        findsOneWidget,
      );
      await _tapVisible(tester, find.text('Edit product'));

      final form = tester.widget<AddMakeupKitProductPage>(
        find.byType(AddMakeupKitProductPage),
      );
      expect(form.product?.id, 'p1');
      expect(form.product?.color, product.color);
      expect(repository.calls, ['loadAll']);
    });

    testWidgets('Delete: same confirmation; cancel sends nothing', (
      tester,
    ) async {
      final repository = await _pump(tester, _product(label: 'Deep Espresso'));

      await _tapVisible(tester, _deleteAction);
      expect(find.text('Delete product?'), findsOneWidget);
      expect(
        find.text(
          'This removes the product from your makeup kit. This action cannot '
          'be undone.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repository.deletedIds, isEmpty);
      expect(find.byType(MakeupKitProductPage), findsOneWidget);
    });

    testWidgets('Delete: confirm deletes this id once and returns', (
      tester,
    ) async {
      final repository = await _pump(tester, _product(label: 'Deep Espresso'));
      repository.holdDelete = Completer<void>();

      await _tapVisible(tester, _deleteAction);
      await tester.tap(find.text('Delete').last);
      await tester.pump();

      // While the request runs, both actions are off and Delete says so.
      expect(find.text('Deleting…'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.ancestor(
                of: find.text('Deleting…'),
                matching: find.byWidgetPredicate((w) => w is TextButton),
              ),
            )
            .onPressed,
        isNull,
      );
      final edit = tester.widget<ButtonStyleButton>(
        find.descendant(
          of: find.widgetWithText(PrimaryButton, 'Edit product'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(edit.onPressed, isNull);

      repository.holdDelete!.complete();
      await tester.pumpAndSettle();

      expect(repository.deletedIds, ['p1']);
      expect(find.byType(MakeupKitProductPage), findsNothing);
      expect(find.text('INVENTORY'), findsOneWidget);
    });

    testWidgets('Delete is lower emphasis than Edit', (tester) async {
      await _pump(tester, _product(label: 'Deep Espresso'));

      // Edit: the filled primary button. Delete: a text action below it.
      await tester.scrollUntilVisible(
        _deleteAction,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(OutlinedButton), findsNothing);
      expect(
        tester.getTopLeft(_deleteAction).dy,
        greaterThan(
          tester
              .getTopLeft(find.widgetWithText(PrimaryButton, 'Edit product'))
              .dy,
        ),
      );
    });

    testWidgets('each attribute is read as one phrase', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _product(label: 'Deep Espresso'));

      expect(
        find.bySemanticsLabel(RegExp(r'^Color\s+Deep Espresso\s+#5C3A21$')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Finish\s+Natural$')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('narrow screen at 2x text lays out without overflow', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(
        tester,
        _product(
          name: 'A long product name that has to wrap onto more lines',
          label: 'Deep Espresso',
          depth: FoundationDepth.light,
          undertone: FoundationUndertone.neutral,
        ),
        size: const Size(320, 640),
      );

      await tester.scrollUntilVisible(
        _deleteAction,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
