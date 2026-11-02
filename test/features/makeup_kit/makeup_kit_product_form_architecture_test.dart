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
import 'package:facetune/features/makeup_kit/presentation/pages/add_makeup_kit_product_page.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_auth_repository.dart';

/// Records the drafts the form hands to the repository — the form's only
/// output — so "same values" is checked where it matters.
class _RecordingRepository implements MakeupKitProductsRepository {
  _RecordingRepository({this.items = const [], this.failWith});

  final List<MakeupKitProduct> items;
  final Object? failWith;
  final calls = <String>[];
  final drafts = <MakeupKitProductDraft>[];

  MakeupKitProduct _saved(String id, MakeupKitProductDraft draft) =>
      MakeupKitProduct(
        id: id,
        userId: 'user-1',
        category: draft.category,
        productName: draft.productName,
        color: draft.color,
        colorLabel: draft.colorLabel,
        finish: draft.finish,
        foundationDepth: draft.foundationDepth,
        foundationUndertone: draft.foundationUndertone,
        createdAt: DateTime.utc(2026, 9, 29),
        updatedAt: DateTime.utc(2026, 9, 29),
      );

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
    drafts.add(draft);
    if (failWith != null) throw failWith!;
    return _saved('new', draft);
  }

  @override
  Future<MakeupKitProduct> update(
    String productId,
    MakeupKitProductDraft draft,
  ) async {
    calls.add('update:$productId');
    drafts.add(draft);
    if (failWith != null) throw failWith!;
    return _saved(productId, draft);
  }

  @override
  Future<void> delete(String productId) async => calls.add('delete');
}

final _foundation = MakeupKitProduct(
  id: 'p1',
  userId: 'user-1',
  category: MakeupKitCategory.foundation,
  productName: 'Daily Base',
  color: NormalizedHexColor.parse('#C99578'),
  colorLabel: 'Warm Beige',
  finish: MakeupKitFinish.satin,
  foundationDepth: FoundationDepth.medium,
  foundationUndertone: FoundationUndertone.warm,
  createdAt: DateTime.utc(2026, 9, 29),
  updatedAt: DateTime.utc(2026, 9, 29),
);

Future<_RecordingRepository> _pump(
  WidgetTester tester, {
  MakeupKitProduct? editing,
  Object? failWith,
  Size size = const Size(393, 873),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = _RecordingRepository(
    items: [?editing],
    failWith: failWith,
  );
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
      // A router, as in the app: the form closes itself with go_router's pop.
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AddMakeupKitProductPage(product: editing),
                    ),
                  ),
                  child: const Text('OPEN FORM'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('OPEN FORM'));
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _show(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pickCategory(WidgetTester tester, String label) async {
  await _tap(tester, find.byKey(const ValueKey('makeup-kit-category-field')));
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Finder _chip(String label) => find.widgetWithText(ChoiceChip, label);

void main() {
  group('MKUX-P3 form structure', () {
    testWidgets('Add reads: heading, Product, Shade, Finish, Foundation, CTA', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Add to your kit'), findsOneWidget);
      // The large notice box is gone; its guidance is one muted line.
      expect(find.byType(AppNotice), findsNothing);
      expect(
        find.textContaining('Choose the closest shade first'),
        findsOneWidget,
      );

      final order = [
        find.text('Add to your kit'),
        find.text('Product'),
        find.byKey(const ValueKey('makeup-kit-category-field')),
        find.widgetWithText(TextField, 'Product name (optional)'),
        find.text('Shade'),
        find.text('Finish'),
        find.text('Foundation details'),
        find.text('Depth'),
        find.text('Undertone'),
        find.widgetWithText(PrimaryButton, 'Add product'),
      ];
      final tops = <double>[];
      for (final finder in order) {
        await _show(tester, finder);
        tops.add(
          tester.getTopLeft(finder).dy +
              tester
                  .state<ScrollableState>(find.byType(Scrollable).first)
                  .position
                  .pixels,
        );
      }
      for (var i = 1; i < tops.length; i++) {
        expect(tops[i], greaterThan(tops[i - 1]), reason: '${order[i]}');
      }
    });

    testWidgets('Edit names the product and ends with Save changes', (
      tester,
    ) async {
      await _pump(tester, editing: _foundation);

      // The heading (the name field holds the same text, as input).
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == 'Daily Base'),
        findsOneWidget,
      );
      expect(find.text('Add to your kit'), findsNothing);
      await _show(tester, find.widgetWithText(PrimaryButton, 'Save changes'));
    });

    testWidgets('Foundation details appear only for Foundation', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Foundation details'), findsOneWidget);
      await _pickCategory(tester, 'Blush');
      expect(find.text('Foundation details'), findsNothing);
      expect(find.text('Depth'), findsNothing);
      await _pickCategory(tester, 'Foundation');
      await _show(tester, find.text('Foundation details'));
    });
  });

  group('MKUX-P3 same values in, same values out', () {
    testWidgets('Add with no changes sends the same defaults as before', (
      tester,
    ) async {
      final repository = await _pump(tester);

      await _tap(tester, find.widgetWithText(PrimaryButton, 'Add product'));

      final draft = repository.drafts.single;
      expect(repository.calls, ['loadAll', 'create']);
      expect(draft.category, MakeupKitCategory.foundation);
      expect(draft.productName, isNull);
      expect(draft.color.value, '#F1DFCB'); // first curated foundation shade
      expect(draft.colorLabel, 'Fair Ivory');
      expect(draft.finish, MakeupKitFinish.matte); // first allowed finish
      expect(draft.foundationDepth, isNull);
      expect(draft.foundationUndertone, isNull);
    });

    testWidgets('Add binds every chosen value', (tester) async {
      final repository = await _pump(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Product name (optional)'),
        '  Daily Base  ',
      );
      await _tap(tester, find.text('Warm Beige'));
      await _tap(tester, _chip('Dewy'));
      await _tap(tester, _chip('Tan'));
      await _tap(tester, _chip('Cool'));
      await _tap(tester, find.widgetWithText(PrimaryButton, 'Add product'));

      final draft = repository.drafts.single;
      expect(draft.category, MakeupKitCategory.foundation);
      expect(draft.productName, 'Daily Base'); // trimmed, as before
      expect(draft.color.value, '#C99578');
      expect(draft.colorLabel, 'Warm Beige');
      expect(draft.finish, MakeupKitFinish.dewy);
      expect(draft.foundationDepth, FoundationDepth.tan);
      expect(draft.foundationUndertone, FoundationUndertone.cool);
    });

    testWidgets('changing category keeps the same reset rules', (tester) async {
      final repository = await _pump(tester);

      await _tap(tester, _chip('Tan'));
      await _tap(tester, _chip('Satin'));
      await _pickCategory(tester, 'Blush');
      await _tap(tester, find.widgetWithText(PrimaryButton, 'Add product'));

      final draft = repository.drafts.single;
      expect(draft.category, MakeupKitCategory.blush);
      // Satin is valid for Blush, so it is kept; the shade resets to Blush's
      // first preset; Foundation-only fields are cleared.
      expect(draft.finish, MakeupKitFinish.satin);
      expect(draft.colorLabel, 'Soft Pink');
      expect(draft.color.value, '#F2B8C6');
      expect(draft.foundationDepth, isNull);
      expect(draft.foundationUndertone, isNull);
    });

    testWidgets('a blank name is still sent as no name', (tester) async {
      final repository = await _pump(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Product name (optional)'),
        '   ',
      );
      // Dismiss the keyboard first, as a user would; a focused field keeps
      // scrolling itself back into view to show its caret.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(PrimaryButton, 'Add product'));

      expect(repository.drafts.single.productName, isNull);
    });

    testWidgets('Edit preloads the product and saves it unchanged', (
      tester,
    ) async {
      final repository = await _pump(tester, editing: _foundation);

      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Product name (optional)'),
            )
            .controller
            ?.text,
        'Daily Base',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('makeup-kit-selected-shade')),
            )
            .data,
        'Warm Beige',
      );
      await _show(tester, _chip('Satin'));
      expect(tester.widget<ChoiceChip>(_chip('Satin')).selected, isTrue);
      await _show(tester, _chip('Medium'));
      expect(tester.widget<ChoiceChip>(_chip('Medium')).selected, isTrue);
      expect(tester.widget<ChoiceChip>(_chip('Warm')).selected, isTrue);

      await _tap(tester, find.widgetWithText(PrimaryButton, 'Save changes'));

      expect(repository.calls, ['loadAll', 'update:p1']);
      final draft = repository.drafts.single;
      final original = _foundation.toDraft();
      expect(draft.category, original.category);
      expect(draft.productName, original.productName);
      expect(draft.color, original.color);
      expect(draft.colorLabel, original.colorLabel);
      expect(draft.finish, original.finish);
      expect(draft.foundationDepth, original.foundationDepth);
      expect(draft.foundationUndertone, original.foundationUndertone);
      // Back to where the form was opened from.
      expect(find.text('OPEN FORM'), findsOneWidget);
    });

    testWidgets('a rejected save keeps the form and shows the same message', (
      tester,
    ) async {
      final repository = await _pump(
        tester,
        failWith: const MakeupKitFailure('The product could not be added.'),
      );

      await _tap(tester, find.widgetWithText(PrimaryButton, 'Add product'));

      expect(repository.calls, ['loadAll', 'create']);
      expect(find.text('The product could not be added.'), findsOneWidget);
      expect(find.byType(AddMakeupKitProductPage), findsOneWidget);
    });
  });

  group('MKUX-P3 layout', () {
    for (final (name, size, scale) in [
      ('POCO X3 GT', const Size(393, 873), 1.0),
      ('320 wide at 2x text', const Size(320, 640), 2.0),
    ]) {
      testWidgets('$name: the CTA is reachable and nothing overflows', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pump(tester, editing: _foundation, size: size);

        final cta = find.widgetWithText(PrimaryButton, 'Save changes');
        await _show(tester, cta);
        expect(cta.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
