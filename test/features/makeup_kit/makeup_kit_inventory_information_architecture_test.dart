import 'package:facetune/core/constants/app_constants.dart';
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
import 'package:facetune/features/makeup_kit/presentation/pages/makeup_kit_overview_page.dart';
import 'package:facetune/features/makeup_kit/presentation/utils/makeup_kit_display.dart';
import 'package:facetune/features/makeup_kit/presentation/widgets/makeup_kit_category_section.dart';
import 'package:facetune/features/makeup_kit/presentation/widgets/makeup_kit_product_tile.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_auth_repository.dart';

/// Records every repository call — the overview's only way to reach the
/// network — so "no new query" is a fact the tests can check.
class _RecordingRepository implements MakeupKitProductsRepository {
  _RecordingRepository(this.items);

  final List<MakeupKitProduct> items;
  final calls = <String>[];

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
    return items.where((item) => item.category == category).toList();
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
  Future<void> delete(String productId) async => calls.add('delete');
}

MakeupKitProduct _product(
  String id,
  MakeupKitCategory category, {
  String? name,
  String? label,
  MakeupKitFinish finish = MakeupKitFinish.matte,
  FoundationDepth? depth,
  FoundationUndertone? undertone,
}) => MakeupKitProduct(
  id: id,
  userId: 'user-1',
  category: category,
  productName: name,
  colorLabel: label,
  color: NormalizedHexColor.parse('#B86F72'),
  finish: finish,
  foundationDepth: depth,
  foundationUndertone: undertone,
  createdAt: DateTime.utc(2026, 9, 29),
  updatedAt: DateTime.utc(2026, 9, 29),
);

/// A kit spread over most categories, in load (newest-first) order.
final _kit = <MakeupKitProduct>[
  _product(
    'f1',
    MakeupKitCategory.foundation,
    label: 'Deep Espresso',
    finish: MakeupKitFinish.natural,
    depth: FoundationDepth.light,
    undertone: FoundationUndertone.neutral,
  ),
  _product('l1', MakeupKitCategory.lipstick, name: 'Everyday Nude'),
  _product('f2', MakeupKitCategory.foundation, label: 'Fair Ivory'),
  _product('c1', MakeupKitCategory.concealer, label: 'Light'),
  _product('b1', MakeupKitCategory.blush, label: 'Soft Pink'),
  _product('e1', MakeupKitCategory.eyeshadow, label: 'Taupe'),
  _product('l2', MakeupKitCategory.lipstick, name: 'Evening Red'),
  _product('g1', MakeupKitCategory.lipGloss, label: 'Clear Pink'),
  _product('k1', MakeupKitCategory.contourBronzer, label: 'Warm Tan'),
  _product('br1', MakeupKitCategory.eyebrow, label: 'Ash Brown'),
  _product('ey1', MakeupKitCategory.eyeliner, label: 'Black'),
];

Future<_RecordingRepository> _pump(
  WidgetTester tester,
  List<MakeupKitProduct> items, {
  Size size = const Size(393, 873),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = _RecordingRepository(items);
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
          initialLocation: AppConstants.makeupKitRoute,
          routes: [
            GoRoute(
              path: AppConstants.makeupKitRoute,
              builder: (context, state) => const MakeupKitOverviewPage(),
            ),
            GoRoute(
              path: AppConstants.makeupKitAddProductRoute,
              builder: (context, state) => const Text('ADD PRODUCT ROUTE'),
            ),
            GoRoute(
              path: AppConstants.makeupKitProductRoute,
              name: 'makeupKitProduct',
              builder: (context, state) =>
                  Text('PRODUCT ${state.pathParameters['productId']}'),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  // scrollUntilVisible stops once the widget is built, which can be in the
  // list's off-screen cache; bring it fully on screen.
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// Walks the whole list, collecting what each category section shows.
Future<Map<MakeupKitCategory, List<String>>> _readSections(
  WidgetTester tester,
) async {
  final seen = <MakeupKitCategory, List<String>>{};
  for (final category in MakeupKitCategory.values) {
    final section = find.byWidgetPredicate(
      (w) => w is MakeupKitCategorySection && w.category == category,
    );
    await _scrollTo(tester, section);
    seen[category] = tester
        .widget<MakeupKitCategorySection>(section)
        .products
        .map((p) => p.id)
        .toList();
  }
  return seen;
}

void main() {
  group('MKUX-P1 inventory information architecture', () {
    testWidgets('the page title is not repeated', (tester) async {
      await _pump(tester, _kit);

      // The app bar is the page identity; there is no second headline.
      expect(find.text('My Makeup Kit'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('My Makeup Kit'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the summary counts come from the loaded kit', (tester) async {
      final repository = await _pump(tester, _kit);

      // 11 products in 9 populated categories (highlighter is empty),
      // derived here from the same list the fake repository returns.
      final populated = MakeupKitCategory.values
          .where((c) => _kit.any((p) => p.category == c))
          .length;
      expect(
        find.text('${_kit.length} products · $populated categories'),
        findsOneWidget,
      );
      expect(repository.calls, ['loadAll']);
    });

    testWidgets('same products, same grouping, same category order', (
      tester,
    ) async {
      final repository = await _pump(tester, _kit);

      final sections = await _readSections(tester);
      // Every category, in the domain's own order.
      expect(sections.keys.toList(), MakeupKitCategory.values);
      for (final category in MakeupKitCategory.values) {
        // The same products, in the same (load) order, as the controller's
        // own grouping — nothing added, dropped, or re-sorted.
        expect(
          sections[category],
          _kit.where((p) => p.category == category).map((p) => p.id).toList(),
          reason: category.code,
        );
      }
      // Sections appear on screen in that order.
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      final tops = <double>[];
      for (final category in MakeupKitCategory.values) {
        await _scrollTo(tester, find.text(category.label));
        tops.add(
          tester.getTopLeft(find.text(category.label)).dy +
              tester
                  .state<ScrollableState>(find.byType(Scrollable).first)
                  .position
                  .pixels,
        );
      }
      for (var i = 1; i < tops.length; i++) {
        expect(tops[i], greaterThan(tops[i - 1]));
      }
      expect(repository.calls, ['loadAll']);
    });

    testWidgets('each category heading carries its count', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _kit);

      await _scrollTo(tester, find.text('Foundation'));
      expect(find.bySemanticsLabel('Foundation, 2 products'), findsOneWidget);
      await _scrollTo(tester, find.text('Highlighter'));
      expect(find.bySemanticsLabel('Highlighter, 0 products'), findsOneWidget);
      // The note is its own node, not part of the heading.
      expect(
        find.bySemanticsLabel('No products in this category yet.'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('rows keep their swatch, name and metadata sources', (
      tester,
    ) async {
      await _pump(tester, _kit);

      // Foundation with a shade label, finish, depth and undertone.
      expect(find.text('Deep Espresso'), findsOneWidget);
      expect(find.text('Natural · Light · Neutral'), findsOneWidget);
      final tile = tester.widget<MakeupKitProductTile>(
        find.ancestor(
          of: find.text('Deep Espresso'),
          matching: find.byType(MakeupKitProductTile),
        ),
      );
      expect(tile.product.id, 'f1');
    });

    testWidgets('a row opens that product, with its id', (tester) async {
      final repository = await _pump(tester, _kit);

      await _scrollTo(tester, find.text('Evening Red'));
      await tester.tap(find.text('Evening Red'));
      await tester.pumpAndSettle();

      expect(find.text('PRODUCT l2'), findsOneWidget);
      expect(repository.calls, ['loadAll']);
    });

    testWidgets('Add product opens the same add-product route', (tester) async {
      final repository = await _pump(tester, _kit);

      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.tap(find.widgetWithText(PrimaryButton, 'Add product'));
      await tester.pumpAndSettle();

      expect(find.text('ADD PRODUCT ROUTE'), findsOneWidget);
      expect(repository.calls, ['loadAll']);
    });

    testWidgets('the last product is reachable and nothing covers it', (
      tester,
    ) async {
      await _pump(tester, _kit);

      final last = find.text('Black'); // eyeliner, the last category
      await _scrollTo(tester, last);
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();

      final rect = tester.getRect(last);
      expect(rect.bottom, lessThanOrEqualTo(873));
      expect(last.hitTestable(), findsOneWidget);
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(find.text('PRODUCT ey1'), findsOneWidget);
    });

    testWidgets('an empty kit offers to add the first product', (tester) async {
      final repository = await _pump(tester, const []);

      expect(find.text('No products yet'), findsOneWidget);
      expect(find.byType(MakeupKitCategorySection), findsNothing);
      expect(find.textContaining('products ·'), findsNothing);
      await tester.tap(find.text('Add your first product'));
      await tester.pumpAndSettle();
      expect(find.text('ADD PRODUCT ROUTE'), findsOneWidget);
      expect(repository.calls, ['loadAll']);
    });

    testWidgets('one product reads in the singular', (tester) async {
      await _pump(tester, [_kit.first]);

      expect(find.text('1 product · 1 category'), findsOneWidget);
    });

    testWidgets('narrow screen at 2x text lays out without overflow', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, _kit, size: const Size(320, 640));

      await _readSections(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
