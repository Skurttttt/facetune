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
import 'package:facetune/features/makeup_kit/presentation/pages/add_makeup_kit_product_page.dart';
import 'package:facetune/features/makeup_kit/presentation/pages/makeup_kit_overview_page.dart';
import 'package:facetune/features/makeup_kit/presentation/pages/makeup_kit_product_page.dart';
import 'package:facetune/features/makeup_kit/presentation/utils/makeup_kit_curated_shades.dart';
import 'package:facetune/features/makeup_kit/presentation/utils/makeup_kit_display.dart';
import 'package:facetune/features/makeup_kit/presentation/widgets/makeup_kit_category_section.dart';
import 'package:facetune/features/makeup_kit/presentation/widgets/makeup_kit_product_tile.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/fake_auth_repository.dart';

/// MKUX-P5: the three My Makeup Kit screens across the device, text-size and
/// theme matrix. Validation of the accepted P1–P4 UI.

class _Repository implements MakeupKitProductsRepository {
  _Repository(this.items);

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
  ) async => items.where((p) => p.category == category).toList();

  @override
  Future<MakeupKitProduct> create(MakeupKitProductDraft draft) =>
      throw UnimplementedError();

  @override
  Future<MakeupKitProduct> update(String id, MakeupKitProductDraft draft) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String productId) async => calls.add('delete');
}

class _Condition {
  const _Condition(
    this.name,
    this.size, {
    this.textScale = 1,
    this.themeMode = ThemeMode.light,
    this.platformBrightness = Brightness.light,
  });

  final String name;
  final Size size;
  final double textScale;
  final ThemeMode themeMode;
  final Brightness platformBrightness;

  Brightness get brightness => switch (themeMode) {
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
    ThemeMode.system => platformBrightness,
  };
}

const _poco = Size(393, 873);
const _conditions = <_Condition>[
  _Condition('POCO X3 GT, light', _poco),
  _Condition('POCO X3 GT, dark', _poco, themeMode: ThemeMode.dark),
  _Condition('POCO X3 GT, system light', _poco, themeMode: ThemeMode.system),
  _Condition(
    'POCO X3 GT, system dark',
    _poco,
    themeMode: ThemeMode.system,
    platformBrightness: Brightness.dark,
  ),
  _Condition('narrow Android 320, light', Size(320, 640)),
  _Condition(
    'short Android 393x560, dark',
    Size(393, 560),
    themeMode: ThemeMode.dark,
  ),
  _Condition('POCO X3 GT, 2x text', _poco, textScale: 2),
  _Condition(
    'narrow Android 320, 2x text, dark',
    Size(320, 640),
    textScale: 2,
    themeMode: ThemeMode.dark,
  ),
];

const _longName =
    'Luminous Satin Skin Perfecting Long-Wear Foundation Limited Edition';

MakeupKitProduct _product(
  String id,
  MakeupKitCategory category, {
  String? name,
  String? label,
  String hex = '#C99578',
  MakeupKitFinish? finish,
  FoundationDepth? depth,
  FoundationUndertone? undertone,
}) => MakeupKitProduct(
  id: id,
  userId: 'user-1',
  category: category,
  productName: name,
  colorLabel: label,
  color: NormalizedHexColor.parse(hex),
  finish: finish ?? MakeupKitFinish.matte,
  foundationDepth: depth,
  foundationUndertone: undertone,
  createdAt: DateTime.utc(2026, 9, 29),
  updatedAt: DateTime.utc(2026, 9, 29),
);

final _foundation = _product(
  'f-long',
  MakeupKitCategory.foundation,
  name: _longName,
  label: 'Warm Beige',
  finish: MakeupKitFinish.natural,
  depth: FoundationDepth.medium,
  undertone: FoundationUndertone.warm,
);

/// A large kit: four products in every category, the first one long-named.
final _largeKit = <MakeupKitProduct>[
  _foundation,
  for (final category in MakeupKitCategory.values)
    for (var i = 0; i < 4; i++)
      _product(
        '${category.code}-$i',
        category,
        label: MakeupKitCuratedShades.forCategory(category).last.label,
        hex: MakeupKitCuratedShades.forCategory(category).last.hex,
        finish: MakeupKitFinishDisplayOrder.first(category),
      ),
];

/// First finish allowed for a category, without importing the catalog twice.
abstract final class MakeupKitFinishDisplayOrder {
  static MakeupKitFinish first(MakeupKitCategory c) => switch (c) {
    MakeupKitCategory.lipGloss => MakeupKitFinish.glossy,
    MakeupKitCategory.highlighter => MakeupKitFinish.natural,
    _ => MakeupKitFinish.matte,
  };
}

Future<_Repository> _pump(
  WidgetTester tester,
  _Condition condition, {
  required String location,
  List<MakeupKitProduct>? items,
  MakeupKitProduct? editing,
}) async {
  tester.view.physicalSize = condition.size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = condition.textScale;
  tester.platformDispatcher.platformBrightnessTestValue =
      condition.platformBrightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  final repository = _Repository(items ?? _largeKit);
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
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: condition.themeMode,
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () {
                      if (location == 'edit') {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                AddMakeupKitProductPage(product: editing),
                          ),
                        );
                      } else {
                        context.push(location);
                      }
                    },
                    child: const Text('START'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: AppConstants.makeupKitRoute,
              builder: (context, state) => const MakeupKitOverviewPage(),
            ),
            GoRoute(
              path: AppConstants.makeupKitAddProductRoute,
              builder: (context, state) => const AddMakeupKitProductPage(),
            ),
            GoRoute(
              path: AppConstants.makeupKitProductRoute,
              name: 'makeupKitProduct',
              builder: (context, state) => MakeupKitProductPage(
                productId: state.pathParameters['productId']!,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('START'));
  await tester.pumpAndSettle();
  return repository;
}

/// The page's own vertical scroll view. Text fields contain horizontal
/// Scrollables of their own, so "the last Scrollable" is not the page.
Finder get _page => find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;

/// Scrolls [finder] into view and proves it is on screen and tappable.
Future<void> _expectReachable(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 150, scrollable: _page);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  final rect = tester.getRect(finder.first);
  // The visible area is the scrolling list itself (below the app bar),
  // clipped by the keyboard.
  final list = tester.getRect(_page);
  final keyboardTop =
      tester.view.physicalSize.height - tester.view.viewInsets.bottom;
  final visibleTop = list.top;
  final visibleBottom = list.bottom < keyboardTop ? list.bottom : keyboardTop;
  expect(
    rect.top,
    greaterThanOrEqualTo(visibleTop - 0.5),
    reason: '$finder above the visible area',
  );
  // A section taller than the visible area (four rows at 2x on 320x640)
  // cannot be on screen whole; its top must be, and its rows are checked on
  // their own.
  if (rect.height <= visibleBottom - visibleTop) {
    expect(
      rect.bottom,
      lessThanOrEqualTo(visibleBottom + 0.5),
      reason: '$finder hidden below the screen or keyboard',
    );
  } else {
    expect(rect.top, lessThan(visibleBottom));
  }
  expect(finder.hitTestable(), findsWidgets, reason: '$finder not tappable');
}

/// Nothing overflows and no paragraph is cut short — except where one line
/// with an ellipsis is the design and the full text is still spoken: product
/// rows (P1), field labels (Material), shade names (two lines, P4) and the
/// category field value.
void _expectNoClipping(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  final exempt = <RenderObject>{
    // AppBar: the shared FaceTuneTopBar title is one line by Material design,
    // and the test font's full-em glyphs overstate its width at 320px.
    for (final type in [MakeupKitProductTile, InputDecorator, AppBar])
      for (final e in find.byType(type).evaluate())
        ...tester.renderObjectList<RenderParagraph>(
          find.descendant(
            of: find.byWidget(e.widget),
            matching: find.byType(RichText),
          ),
        ),
    ...tester.renderObjectList<RenderParagraph>(
      find.descendant(
        of: find.bySemanticsLabel(RegExp(r' shade$')),
        matching: find.byType(RichText),
      ),
    ),
  };
  for (final paragraph in tester.renderObjectList<RenderParagraph>(
    find.byType(RichText),
  )) {
    if (exempt.contains(paragraph)) continue;
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: '"${paragraph.text.toPlainText()}" is clipped',
    );
  }
}

void main() {
  group('MKUX-P5 matrix', () {
    for (final condition in _conditions) {
      group(condition.name, () {
        testWidgets('inventory: large kit, every row reachable', (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          final repository = await _pump(
            tester,
            condition,
            location: AppConstants.makeupKitRoute,
          );

          expect(
            Theme.of(
              tester.element(find.byType(MakeupKitOverviewPage)),
            ).brightness,
            condition.brightness,
          );
          // One title (the app bar), the summary, the action, nothing floating.
          expect(find.text('My Makeup Kit'), findsOneWidget);
          expect(
            find.text('${_largeKit.length} products · 10 categories'),
            findsOneWidget,
          );
          expect(find.byType(FloatingActionButton), findsNothing);
          await _expectReachable(
            tester,
            find.widgetWithText(PrimaryButton, 'Add product'),
          );
          for (final category in MakeupKitCategory.values) {
            await _expectReachable(
              tester,
              find.byWidgetPredicate(
                (w) => w is MakeupKitCategorySection && w.category == category,
              ),
            );
            expect(
              find.bySemanticsLabel(
                '${category.label}, ${_largeKit.where((p) => p.category == category).length} products',
              ),
              findsOneWidget,
            );
          }
          // The last row of the last category is fully visible and tappable.
          await _expectReachable(
            tester,
            find.byType(MakeupKitProductTile).last,
          );
          final position = tester.state<ScrollableState>(_page).position;
          position.jumpTo(position.maxScrollExtent);
          await tester.pumpAndSettle();
          final last = find.byType(MakeupKitProductTile).last;
          expect(
            tester.getRect(last).bottom,
            lessThanOrEqualTo(tester.view.physicalSize.height),
          );
          _expectNoClipping(tester);
          expect(repository.calls, ['loadAll']);
          semantics.dispose();
        });

        testWidgets('inventory: empty kit is usable', (tester) async {
          await _pump(
            tester,
            condition,
            location: AppConstants.makeupKitRoute,
            items: const [],
          );
          expect(find.text('No products yet'), findsOneWidget);
          await _expectReachable(tester, find.text('Add your first product'));
          _expectNoClipping(tester);
        });

        testWidgets('details: long name, every value, both actions', (
          tester,
        ) async {
          await _pump(
            tester,
            condition,
            location: '/makeup-kit/product/${_foundation.id}',
          );

          expect(find.text(_longName), findsOneWidget); // wraps, not cut
          for (final value in [
            'Category',
            'Color',
            'Warm Beige',
            '#C99578',
            'Finish',
            'Natural',
            'Depth',
            'Medium',
            'Undertone',
            'Warm',
          ]) {
            await _expectReachable(tester, find.text(value));
          }
          await _expectReachable(
            tester,
            find.widgetWithText(PrimaryButton, 'Edit product'),
          );
          await _expectReachable(tester, find.text('Delete product'));
          // Delete stays the lighter action: no filled or outlined button.
          expect(
            find.ancestor(
              of: find.text('Delete product'),
              matching: find.byWidgetPredicate(
                (w) => w is FilledButton || w is OutlinedButton,
              ),
            ),
            findsNothing,
          );
          _expectNoClipping(tester);
        });

        testWidgets('form: every control reachable, CTA at the end', (
          tester,
        ) async {
          await _pump(
            tester,
            condition,
            location: 'edit',
            editing: _foundation,
          );

          for (final finder in [
            find.byKey(const ValueKey('makeup-kit-category-field')),
            find.widgetWithText(TextField, 'Product name (optional)'),
            find.bySemanticsLabel('Warm Beige shade'),
            find.byKey(const ValueKey('makeup-kit-selected-shade')),
            find.text('Fine-tune shade'),
            find.widgetWithText(ChoiceChip, 'Satin'),
            find.text('Foundation details'),
            find.widgetWithText(ChoiceChip, 'Deep'),
            find.widgetWithText(ChoiceChip, 'Cool'),
            find.widgetWithText(PrimaryButton, 'Save changes'),
          ]) {
            await _expectReachable(tester, finder);
          }
          _expectNoClipping(tester);
        });
      });
    }
  });

  group('MKUX-P5 keyboard open', () {
    for (final condition in [_conditions[0], _conditions[5]]) {
      testWidgets('${condition.name}: the form CTA stays reachable', (
        tester,
      ) async {
        await _pump(
          tester,
          condition,
          location: AppConstants.makeupKitAddProductRoute,
        );
        await tester.showKeyboard(
          find.widgetWithText(TextField, 'Product name (optional)'),
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();

        await _expectReachable(
          tester,
          find.widgetWithText(PrimaryButton, 'Add product'),
        );
        _expectNoClipping(tester);
      });
    }
  });

  group('MKUX-P5 accessibility', () {
    for (final condition in [_conditions[0], _conditions[1], _conditions[6]]) {
      for (final (screen, location) in [
        ('inventory', AppConstants.makeupKitRoute),
        ('details', '/makeup-kit/product/f-long'),
        ('form', 'edit'),
      ]) {
        testWidgets('$screen, ${condition.name}: 44dp, labelled, contrast', (
          tester,
        ) async {
          await _pump(
            tester,
            condition,
            location: location,
            editing: _foundation,
          );

          await expectLater(
            tester,
            meetsGuideline(
              const MinimumTapTargetGuideline(
                size: Size(44, 44),
                link: 'FACETUNE_MY_MAKEUP_KIT_UX_SOURCE_OF_TRUTH.md §35',
              ),
            ),
          );
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        });
      }
    }

    testWidgets('form: shades, selection, category and finish are spoken', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        _conditions[0],
        location: 'edit',
        editing: _foundation,
      );

      expect(find.bySemanticsLabel('Category, Foundation'), findsOneWidget);
      for (final shade in MakeupKitCuratedShades.forCategory(
        MakeupKitCategory.foundation,
      )) {
        final node = tester.getSemantics(
          find.bySemanticsLabel('${shade.label} shade'),
        );
        expect(
          node,
          containsSemantics(
            isButton: true,
            isInMutuallyExclusiveGroup: true,
            isSelected: shade.label == 'Warm Beige',
          ),
        );
      }
      expect(
        find.bySemanticsLabel(
          RegExp(r'^Selected shade\s+Warm Beige\s+#C99578$'),
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Natural'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.widgetWithText(ChoiceChip, 'Natural')),
        containsSemantics(label: 'Natural', isSelected: true),
      );
      expect(
        tester.getSemantics(find.widgetWithText(ChoiceChip, 'Matte')),
        containsSemantics(label: 'Matte', isSelected: false),
      );
      semantics.dispose();
    });

    testWidgets('form: focus moves in reading order', (tester) async {
      await _pump(
        tester,
        _conditions[0],
        location: 'edit',
        editing: _foundation,
      );

      final category = find.byKey(const ValueKey('makeup-kit-category-field'));
      final categoryFocus = Focus.of(
        tester.element(
          find.descendant(of: category, matching: find.byType(InputDecorator)),
        ),
      );
      categoryFocus.requestFocus();
      await tester.pump();
      FocusManager.instance.primaryFocus!.nextFocus();
      await tester.pump();
      final nameField = tester.widget<EditableText>(
        find.descendant(
          of: find.widgetWithText(TextField, 'Product name (optional)'),
          matching: find.byType(EditableText),
        ),
      );
      expect(nameField.focusNode.hasFocus, isTrue);
    });

    testWidgets('details: Delete is a spoken destructive action', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final repository = await _pump(
        tester,
        _conditions[0],
        location: '/makeup-kit/product/f-long',
      );

      await tester.ensureVisible(find.text('Delete product'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Delete product')),
        containsSemantics(label: 'Delete product', isButton: true),
      );
      await tester.tap(find.text('Delete product'));
      await tester.pumpAndSettle();
      expect(find.text('Delete product?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.calls, ['loadAll']);
      semantics.dispose();
    });
  });
}
