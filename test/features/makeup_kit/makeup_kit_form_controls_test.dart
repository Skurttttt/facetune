import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_products_providers.dart';
import 'package:facetune/features/makeup_kit/domain/catalog/makeup_kit_finish_catalog.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_product.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_products_repository.dart';
import 'package:facetune/features/makeup_kit/domain/value_objects/normalized_hex_color.dart';
import 'package:facetune/features/makeup_kit/presentation/pages/add_makeup_kit_product_page.dart';
import 'package:facetune/features/makeup_kit/presentation/utils/makeup_kit_curated_shades.dart';
import 'package:facetune/features/makeup_kit/presentation/utils/makeup_kit_display.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_auth_repository.dart';

/// Records every repository call and every draft the form sends.
class _RecordingRepository implements MakeupKitProductsRepository {
  _RecordingRepository([this.items = const []]);

  final List<MakeupKitProduct> items;
  final calls = <String>[];
  final drafts = <MakeupKitProductDraft>[];

  MakeupKitProduct _saved(String id, MakeupKitProductDraft d) =>
      MakeupKitProduct(
        id: id,
        userId: 'user-1',
        category: d.category,
        productName: d.productName,
        color: d.color,
        colorLabel: d.colorLabel,
        finish: d.finish,
        foundationDepth: d.foundationDepth,
        foundationUndertone: d.foundationUndertone,
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
    return _saved('new', draft);
  }

  @override
  Future<MakeupKitProduct> update(
    String productId,
    MakeupKitProductDraft draft,
  ) async {
    calls.add('update:$productId');
    drafts.add(draft);
    return _saved(productId, draft);
  }

  @override
  Future<void> delete(String productId) async => calls.add('delete');
}

Future<_RecordingRepository> _pump(
  WidgetTester tester, {
  MakeupKitProduct? editing,
  Size size = const Size(393, 873),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = _RecordingRepository([?editing]);
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

final _categoryField = find.byKey(const ValueKey('makeup-kit-category-field'));
final _selectedShade = find.byKey(const ValueKey('makeup-kit-selected-shade'));

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

Finder _sheetRow(MakeupKitCategory category) => find.descendant(
  of: find.byType(BottomSheet),
  matching: find.widgetWithText(ListTile, category.label),
);

Future<void> _pickCategory(WidgetTester tester, MakeupKitCategory c) async {
  await _tap(tester, _categoryField);
  // The sheet's list is built lazily; scroll it, not the form.
  await tester.scrollUntilVisible(
    _sheetRow(c),
    120,
    scrollable: find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.ensureVisible(_sheetRow(c));
  await tester.pumpAndSettle();
  await tester.tap(_sheetRow(c));
  await tester.pumpAndSettle();
}

Finder _shadeTile(String label) => find.bySemanticsLabel('$label shade');

Future<void> _submit(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await _tap(tester, find.widgetWithText(PrimaryButton, 'Add product'));
}

String _selected(WidgetTester tester) =>
    tester.widget<Text>(_selectedShade).data!;

void main() {
  group('MKUX-P4 category selector', () {
    testWidgets('every category is offered, in domain order, and maps to '
        'its own domain value', (tester) async {
      for (final category in MakeupKitCategory.values) {
        final repository = await _pump(tester);

        await _pickCategory(tester, category);
        await _submit(tester);

        final draft = repository.drafts.single;
        expect(draft.category, category, reason: category.code);
        expect(draft.category.code, category.code);
        // Picking still runs the old transition: the category's first shade
        // and a finish valid for it.
        final firstShade = MakeupKitCuratedShades.forCategory(category).first;
        expect(draft.colorLabel, firstShade.label, reason: category.code);
        expect(draft.color, firstShade.color, reason: category.code);
        expect(
          MakeupKitFinishCatalog.isValidCombination(category, draft.finish),
          isTrue,
        );
        expect(repository.calls, ['loadAll', 'create']);
      }
    });

    testWidgets('the sheet lists all ten in the same order, current checked', (
      tester,
    ) async {
      final repository = await _pump(tester);

      await _tap(tester, _categoryField);
      final rows = tester
          .widgetList<ListTile>(
            find.descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(ListTile),
            ),
          )
          .toList();
      expect(
        rows.map((r) => (r.title! as Text).data),
        MakeupKitCategory.values.map((c) => c.label),
      );
      expect(rows.where((r) => r.selected).single.title, isA<Text>());
      expect((rows.first.title! as Text).data, 'Foundation');
      expect(rows.first.selected, isTrue);
      expect(repository.calls, ['loadAll']);
    });

    testWidgets('dismissing the sheet changes nothing', (tester) async {
      final repository = await _pump(tester);
      await _tap(tester, _shadeTile('Warm Beige'));

      await _tap(tester, _categoryField);
      await tester.tapAt(const Offset(10, 10)); // the scrim
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(_selected(tester), 'Warm Beige');
      expect(repository.calls, ['loadAll']);
    });

    testWidgets('re-picking the current category behaves as the dropdown did', (
      tester,
    ) async {
      await _pump(tester);
      await _tap(tester, _shadeTile('Warm Beige'));

      // The dropdown reported a re-pick too, and the page reset the shade.
      await _pickCategory(tester, MakeupKitCategory.foundation);
      expect(_selected(tester), 'Fair Ivory');
    });

    testWidgets('the field reads its value to assistive technology', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester);

      // Its own node: not merged with the section heading or the name field.
      expect(find.bySemanticsLabel('Category, Foundation'), findsOneWidget);
      expect(find.bySemanticsLabel('Product'), findsOneWidget);
      expect(find.bySemanticsLabel('Product name (optional)'), findsOneWidget);
      await _pickCategory(tester, MakeupKitCategory.lipGloss);
      expect(find.bySemanticsLabel('Category, Lip Gloss'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('MKUX-P4 shade picker', () {
    testWidgets('every curated shade maps to its own value and label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      for (final category in MakeupKitCategory.values) {
        final repository = await _pump(tester);
        await _pickCategory(tester, category);
        final shades = MakeupKitCuratedShades.forCategory(category);

        for (final shade in shades) {
          await _tap(tester, _shadeTile(shade.label));
          expect(_selected(tester), shade.label, reason: shade.label);
          expect(find.text(shade.color.value), findsOneWidget);
          // Exactly one tile is selected, and it is this one.
          final node = tester.getSemantics(_shadeTile(shade.label));
          expect(
            node,
            containsSemantics(
              isSelected: true,
              isInMutuallyExclusiveGroup: true,
            ),
          );
        }
        await _submit(tester);

        final draft = repository.drafts.single;
        expect(draft.color, shades.last.color, reason: category.code);
        expect(draft.colorLabel, shades.last.label, reason: category.code);
      }
      semantics.dispose();
    });

    testWidgets('shade taps reach no repository', (tester) async {
      final repository = await _pump(tester);

      for (final shade in MakeupKitCuratedShades.forCategory(
        MakeupKitCategory.foundation,
      )) {
        await _tap(tester, _shadeTile(shade.label));
      }
      expect(repository.calls, ['loadAll']);
    });

    testWidgets('Edit shows the saved shade selected', (tester) async {
      final semantics = tester.ensureSemantics();
      final product = MakeupKitProduct(
        id: 'p1',
        userId: 'user-1',
        category: MakeupKitCategory.lipstick,
        color: NormalizedHexColor.parse('#8B2635'),
        colorLabel: 'Deep Red',
        finish: MakeupKitFinish.cream,
        createdAt: DateTime.utc(2026, 9, 29),
        updatedAt: DateTime.utc(2026, 9, 29),
      );
      final repository = await _pump(tester, editing: product);

      expect(_selected(tester), 'Deep Red');
      await _show(tester, _shadeTile('Deep Red'));
      expect(
        tester.getSemantics(_shadeTile('Deep Red')),
        containsSemantics(isSelected: true),
      );
      await _tap(tester, find.widgetWithText(PrimaryButton, 'Save changes'));
      final draft = repository.drafts.single;
      expect(draft.color, product.color);
      expect(draft.colorLabel, 'Deep Red');
      expect(draft.finish, MakeupKitFinish.cream);
      semantics.dispose();
    });
  });

  group('MKUX-P4 fine-tune', () {
    testWidgets('stays collapsed until asked, and a HEX value is sent as is', (
      tester,
    ) async {
      final repository = await _pump(tester);

      expect(find.widgetWithText(TextField, 'HEX reference'), findsNothing);
      await _tap(tester, find.text('Fine-tune shade'));
      await tester.enterText(
        find.widgetWithText(TextField, 'HEX reference'),
        'aabbcc',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(_selected(tester), '#AABBCC'); // no name for a fine-tuned colour
      await _submit(tester);
      final draft = repository.drafts.single;
      expect(draft.color.value, '#AABBCC');
      expect(draft.colorLabel, isNull);
    });

    // Colour only. The label is NOT preserved today: initState falls back to
    // the first Foundation preset's name when a product has no label, so the
    // form shows and would save "Fair Ivory". That is a pre-existing defect,
    // reported for a decision rather than locked in here.
    testWidgets('a saved custom colour keeps its value through Edit', (
      tester,
    ) async {
      final product = MakeupKitProduct(
        id: 'p2',
        userId: 'user-1',
        category: MakeupKitCategory.blush,
        color: NormalizedHexColor.parse('#123456'),
        finish: MakeupKitFinish.satin,
        createdAt: DateTime.utc(2026, 9, 29),
        updatedAt: DateTime.utc(2026, 9, 29),
      );
      final repository = await _pump(tester, editing: product);

      await _tap(tester, find.widgetWithText(PrimaryButton, 'Save changes'));
      final draft = repository.drafts.single;
      expect(draft.color.value, '#123456');
      expect(draft.finish, MakeupKitFinish.satin);
      expect(draft.category, MakeupKitCategory.blush);
    });
  });

  group('MKUX-P4 finish', () {
    testWidgets('every allowed finish is shown and maps to its value', (
      tester,
    ) async {
      for (final category in MakeupKitCategory.values) {
        final repository = await _pump(tester);
        await _pickCategory(tester, category);

        final allowed = MakeupKitFinishCatalog.allowedFinishes(category);
        // The chip's own text (a two-option row wraps it in an Align).
        final chips = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(ChoiceChip),
                matching: find.byType(Text),
              ),
            )
            .map((t) => t.data)
            .where((l) => allowed.any((f) => f.label == l))
            .toList();
        expect(chips, allowed.map((f) => f.label).toList());

        await _tap(tester, find.widgetWithText(ChoiceChip, allowed.last.label));
        await _submit(tester);
        expect(repository.drafts.single.finish, allowed.last);
      }
    });
  });

  group('MKUX-P4 at 2x text on a narrow phone', () {
    testWidgets('selector, shades and finishes stay usable', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repository = await _pump(tester, size: const Size(320, 640));

      // The sheet scrolls to its last row.
      await _pickCategory(tester, MakeupKitCategory.eyeliner);
      for (final shade in MakeupKitCuratedShades.forCategory(
        MakeupKitCategory.eyeliner,
      )) {
        await _tap(tester, _shadeTile(shade.label));
        expect(_selected(tester), shade.label);
      }
      for (final finish in MakeupKitFinishCatalog.allowedFinishes(
        MakeupKitCategory.eyeliner,
      )) {
        await _show(tester, find.widgetWithText(ChoiceChip, finish.label));
      }
      expect(tester.takeException(), isNull);
      // The track's floor (SoT §35) is 44dp. The one target under Android's
      // 48dp is the app-wide FaceTuneBackButton (44×44), outside MKUX.
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
      expect(repository.calls, ['loadAll']);
    });
  });
}
