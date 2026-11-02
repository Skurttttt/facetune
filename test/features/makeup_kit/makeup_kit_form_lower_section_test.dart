import 'dart:io';

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
import 'package:facetune/features/makeup_kit/presentation/pages/add_makeup_kit_product_page.dart';
import 'package:facetune/features/makeup_kit/presentation/utils/makeup_kit_display.dart';
import 'package:facetune/features/makeup_kit/presentation/widgets/makeup_kit_choice_chip_group.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:facetune/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_auth_repository.dart';

/// The lower section of the product form: Fine-tune, Finish, Foundation
/// details (Depth, Undertone) and the CTA.

class _Repository implements MakeupKitProductsRepository {
  final calls = <String>[];
  final drafts = <MakeupKitProductDraft>[];

  @override
  Future<List<MakeupKitProduct>> loadAll() async {
    calls.add('loadAll');
    return const [];
  }

  @override
  Future<List<MakeupKitProduct>> loadByCategory(MakeupKitCategory c) async {
    calls.add('loadByCategory');
    return const [];
  }

  @override
  Future<MakeupKitProduct> create(MakeupKitProductDraft draft) async {
    calls.add('create');
    drafts.add(draft);
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
      createdAt: DateTime.utc(2026, 9, 29),
      updatedAt: DateTime.utc(2026, 9, 29),
    );
  }

  @override
  Future<MakeupKitProduct> update(String id, MakeupKitProductDraft d) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String productId) async => calls.add('delete');
}

Future<_Repository> _pump(
  WidgetTester tester, {
  Size size = const Size(393, 873),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final repository = _Repository();
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
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AddMakeupKitProductPage(),
                      ),
                    ),
                    child: const Text('OPEN'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
  return repository;
}

Finder get _page => find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;

Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 150, scrollable: _page);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Finder _chip(String label) => find.widgetWithText(ChoiceChip, label);

List<String> _groupLabels<T>(WidgetTester tester) => tester
    .widget<MakeupKitChoiceChipGroup<T>>(
      find.byType(MakeupKitChoiceChipGroup<T>),
    )
    .options
    .map(
      (o) => tester
          .widget<MakeupKitChoiceChipGroup<T>>(
            find.byType(MakeupKitChoiceChipGroup<T>),
          )
          .labelOf(o),
    )
    .toList();

void main() {
  group('lower section: same options, same values', () {
    testWidgets('Finish, Depth and Undertone offer exactly the same options', (
      tester,
    ) async {
      await _pump(tester);

      // Foundation (the default category).
      expect(_groupLabels<MakeupKitFinish>(tester), [
        'Matte',
        'Natural',
        'Dewy',
        'Satin',
      ]);
      expect(
        _groupLabels<FoundationDepth>(tester),
        FoundationDepth.values.map((d) => d.label).toList(),
      );
      expect(
        _groupLabels<FoundationUndertone>(tester),
        FoundationUndertone.values.map((u) => u.label).toList(),
      );
    });

    testWidgets('chip taps set the same values that are saved', (tester) async {
      final repository = await _pump(tester);

      for (final label in ['Satin', 'Deep', 'Neutral']) {
        await _show(tester, _chip(label));
        await tester.tap(_chip(label));
        await tester.pumpAndSettle();
        expect(tester.widget<ChoiceChip>(_chip(label)).selected, isTrue);
      }
      expect(repository.calls, ['loadAll']); // chip taps reach no repository

      await _show(tester, find.widgetWithText(PrimaryButton, 'Add product'));
      await tester.tap(find.widgetWithText(PrimaryButton, 'Add product'));
      await tester.pumpAndSettle();

      final draft = repository.drafts.single;
      expect(draft.finish, MakeupKitFinish.satin);
      expect(draft.foundationDepth, FoundationDepth.deep);
      expect(draft.foundationUndertone, FoundationUndertone.neutral);
    });

    testWidgets('the group reports every tap, the selected chip included', (
      tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: MakeupKitChoiceChipGroup<String>(
              options: const ['a', 'b'],
              selected: 'a',
              labelOf: (o) => o.toUpperCase(),
              onSelected: taps.add,
            ),
          ),
        ),
      );

      await tester.tap(find.text('A'));
      await tester.tap(find.text('B'));
      // As the ChoiceChips it replaces did: a tap on the selected one is
      // reported too; what it means is the caller's decision.
      expect(taps, ['a', 'b']);
    });
  });

  group('lower section: Finish width', () {
    testWidgets('the Finish card is as wide as the other sections', (
      tester,
    ) async {
      await _pump(tester);
      final product = tester.getRect(_card('Product')).width;

      await _show(tester, find.text('Finish'));
      expect(tester.getRect(_card('Finish')).width, product);
      await _show(tester, find.text('Foundation details'));
      expect(tester.getRect(_card('Foundation details')).width, product);

      // Eyebrow offers two finishes.
      await _pickCategory(tester, 'Eyebrow');
      await _show(tester, find.text('Finish'));
      expect(tester.getRect(_card('Finish')).width, product);
    });

    testWidgets('two finishes share the row evenly and still work', (
      tester,
    ) async {
      final repository = await _pump(tester);
      await _pickCategory(tester, 'Eyebrow');
      await _show(tester, _chip('Natural'));

      final card = tester.getRect(_card('Finish'));
      final matte = _pill(tester, 'Matte');
      final natural = _pill(tester, 'Natural');
      // Equal halves of the card's content width, one row, usual height.
      expect(matte.width, closeTo(natural.width, 0.5));
      expect(matte.top, natural.top);
      expect(
        matte.width * 2 + AppSpacing.xs,
        closeTo(card.width - AppSpacing.md * 2, 1),
      );
      expect(matte.height, inInclusiveRange(40, 44));
      expect(tester.getSize(_chip('Natural')).height, greaterThanOrEqualTo(44));
      // Finish keeps its check; selection moves as before.
      expect(tester.widget<ChoiceChip>(_chip('Matte')).showCheckmark, isTrue);
      expect(tester.widget<ChoiceChip>(_chip('Matte')).selected, isTrue);
      await tester.tap(_chip('Natural'));
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(_chip('Natural')).selected, isTrue);
      expect(tester.widget<ChoiceChip>(_chip('Matte')).selected, isFalse);

      await _show(tester, find.widgetWithText(PrimaryButton, 'Add product'));
      await tester.tap(find.widgetWithText(PrimaryButton, 'Add product'));
      await tester.pumpAndSettle();
      expect(repository.drafts.single.category, MakeupKitCategory.eyebrow);
      expect(repository.drafts.single.finish, MakeupKitFinish.natural);
    });

    testWidgets('two finishes at 2x text on a narrow phone: no overflow', (
      tester,
    ) async {
      await _pump(tester, size: const Size(320, 640), textScale: 2);
      await _pickCategory(tester, 'Eyebrow');
      await _show(tester, _chip('Natural'));

      expect(tester.takeException(), isNull);
      expect(_pill(tester, 'Matte').top, _pill(tester, 'Natural').top);
      expect(
        _pill(tester, 'Matte').width,
        closeTo(_pill(tester, 'Natural').width, 0.5),
      );
    });
  });

  group('lower section: presentation', () {
    testWidgets('each option is spoken with its selected state', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester);

      await _show(tester, _chip('Matte'));
      expect(
        tester.getSemantics(_chip('Matte')),
        containsSemantics(
          label: 'Matte',
          isSelected: true,
          hasSelectedState: true,
        ),
      );
      expect(
        tester.getSemantics(_chip('Natural')),
        containsSemantics(
          label: 'Natural',
          isSelected: false,
          hasSelectedState: true,
        ),
      );
      await _show(tester, _chip('Warm'));
      expect(
        tester.getSemantics(_chip('Warm')),
        containsSemantics(
          label: 'Warm',
          isSelected: false,
          hasSelectedState: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('chips stay 44dp+ to tap, and wrapped rows sit close', (
      tester,
    ) async {
      // Narrow enough that Depth wraps to a second row.
      await _pump(tester, size: const Size(320, 800));

      await _show(tester, _chip('Deep'));
      for (final label in ['Fair', 'Deep', 'Cool', 'Matte']) {
        final hit = tester.getSize(_chip(label));
        expect(hit.height, greaterThanOrEqualTo(44), reason: label);
      }
      // Wrapped rows: one tap target plus AppSpacing.xxs apart, so the
      // visible gap between chips is small (about 9 at normal text).
      final rects = [
        for (final depth in FoundationDepth.values)
          tester.getRect(_chip(depth.label)),
      ];
      final rowTops = rects.map((r) => r.top).toSet().toList()..sort();
      expect(rowTops.length, greaterThan(1), reason: 'Depth should wrap here');
      for (var i = 1; i < rowTops.length; i++) {
        expect(
          rowTops[i] - rowTops[i - 1],
          closeTo(rects.first.height + AppSpacing.xxs, 0.5),
        );
      }
    });

    testWidgets('chips are compact: 40-44 tall, 11 of padding per side', (
      tester,
    ) async {
      await _pump(tester);
      await _show(tester, _chip('Natural'));

      final visual = tester.getSize(
        find
            .descendant(of: _chip('Natural'), matching: find.byType(Material))
            .last,
      );
      final label = tester.getSize(find.text('Natural'));
      expect(visual.height, inInclusiveRange(40, 44));
      // Padding and border around the label: 2 × (3 + 8) + 2 × 1 border.
      expect(visual.width - label.width, closeTo(24, 0.5));
    });

    testWidgets('Depth and Undertone mark selection without the check', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester);

      await _show(tester, _chip('Medium'));
      await tester.tap(_chip('Medium'));
      await tester.pumpAndSettle();

      final medium = tester.widget<ChoiceChip>(_chip('Medium'));
      final light = tester.widget<ChoiceChip>(_chip('Light'));
      expect(medium.showCheckmark, isFalse);
      // Not colour alone: a heavier brand border and a bolder label...
      expect(medium.side?.width, AppBorders.emphasis);
      expect(light.side, isNull);
      expect(
        tester.widget<Text>(find.text('Medium')).style?.fontWeight,
        FontWeight.w700,
      );
      // ...and the spoken state.
      expect(
        tester.getSemantics(_chip('Medium')),
        containsSemantics(label: 'Medium', isSelected: true),
      );
      // Finish keeps its check.
      expect(tester.widget<ChoiceChip>(_chip('Matte')).showCheckmark, isTrue);
      semantics.dispose();
    });

    testWidgets('with real Roboto on the POCO: Finish and Depth each fit one '
        'row at 1x, and wrap as text grows', (tester) async {
      // The test font draws every glyph as a full em square, far wider than
      // Roboto, so this check loads the Roboto the Flutter SDK ships.
      final fonts = _sdkMaterialFonts();
      if (fonts == null) {
        markTestSkipped('Roboto not found in the Flutter SDK cache');
        return;
      }
      final loader = FontLoader('Roboto');
      for (final name in ['roboto-regular', 'roboto-medium', 'roboto-bold']) {
        final bytes = File('${fonts.path}/$name.ttf').readAsBytesSync();
        loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      }
      await loader.load();

      // (text scale, finish rows, depth rows)
      for (final (scale, finishRows, depthRows) in [
        (1.0, 1, 1),
        (1.15, 1, 2),
        (1.3, 2, 2),
      ]) {
        tester.view.physicalSize = const Size(393, 1600);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final theme = AppTheme.lightTheme;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supabaseAvailableProvider.overrideWithValue(true),
              authRepositoryProvider.overrideWithValue(
                FakeAuthRepository(
                  user: const AuthUser(id: 'user-1', isAnonymous: false),
                ),
              ),
              makeupKitProductsRepositoryProvider.overrideWithValue(
                _Repository(),
              ),
            ],
            child: MaterialApp(
              theme: theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
              ),
              home: const AddMakeupKitProductPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        int rows(List<String> labels) =>
            {for (final l in labels) tester.getRect(_chip(l)).top}.length;
        const depths = ['Fair', 'Light', 'Medium', 'Tan', 'Deep'];
        expect(
          rows(['Matte', 'Natural', 'Dewy', 'Satin']),
          finishRows,
          reason: 'Finish at ${scale}x',
        );
        expect(rows(depths), depthRows, reason: 'Depth at ${scale}x');
        expect(rows(['Cool', 'Neutral', 'Warm']), 1);
        if (scale == 1.0) {
          // The accepted four-finish card: one row, not taller than before.
          final finishCard = tester.getRect(
            find
                .ancestor(of: find.text('Finish'), matching: find.byType(Card))
                .first,
          );
          expect(finishCard.height, lessThanOrEqualTo(107.5));
        }

        if (scale == 1.0) {
          // And it stays one row whichever depth is chosen — no jump under
          // the finger when a selection is made.
          for (final pick in depths) {
            await tester.tap(_chip(pick));
            await tester.pumpAndSettle();
            expect(rows(depths), 1, reason: '$pick selected');
          }
        }
        // Tap targets stay accessible throughout.
        for (final l in depths) {
          expect(tester.getSize(_chip(l)).height, greaterThanOrEqualTo(44));
        }
      }
    });

    testWidgets('Fine-tune still expands and collapses', (tester) async {
      await _pump(tester);

      await _show(tester, find.text('Fine-tune shade'));
      expect(find.widgetWithText(TextField, 'HEX reference'), findsNothing);
      await tester.tap(find.text('Fine-tune shade'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'HEX reference'), findsOneWidget);
      await tester.tap(find.text('Fine-tune shade'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'HEX reference'), findsNothing);
    });

    testWidgets('the CTA ends the form without a tall empty tail', (
      tester,
    ) async {
      await _pump(tester);

      final cta = find.widgetWithText(PrimaryButton, 'Add product');
      await _show(tester, cta);
      final position = tester.state<ScrollableState>(_page).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final visibleBottom = tester.getRect(_page).bottom;
      final gapBelow = visibleBottom - tester.getRect(cta).bottom;
      expect(gapBelow, lessThanOrEqualTo(AppSpacing.lg + 0.5));
      expect(cta.hitTestable(), findsOneWidget);
    });

    for (final (name, size, scale) in [
      ('POCO X3 GT at 2x text', const Size(393, 873), 2.0),
      ('320 wide at 2x text', const Size(320, 640), 2.0),
    ]) {
      testWidgets('$name: every option reachable, nothing overflows', (
        tester,
      ) async {
        await _pump(tester, size: size, textScale: scale);

        for (final label in [
          'Fine-tune shade',
          'Matte',
          'Satin',
          'Fair',
          'Deep',
          'Cool',
          'Warm',
        ]) {
          await _show(
            tester,
            label == 'Fine-tune shade' ? find.text(label) : _chip(label),
          );
        }
        await _show(tester, find.widgetWithText(PrimaryButton, 'Add product'));
        expect(tester.takeException(), isNull);
      });
    }
  });
}

/// The Flutter SDK's bundled Material fonts, found from the test runner's own
/// location (`bin/cache/artifacts/engine/<platform>/flutter_tester`).
Directory? _sdkMaterialFonts() {
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 4; i++) {
    final candidate = Directory('${dir.path}/material_fonts');
    if (File('${candidate.path}/roboto-regular.ttf').existsSync()) {
      return candidate;
    }
    dir = dir.parent;
  }
  return null;
}

Finder _card(String heading) =>
    find.ancestor(of: find.text(heading), matching: find.byType(Card)).first;

Future<void> _pickCategory(WidgetTester tester, String label) async {
  final field = find.byKey(const ValueKey('makeup-kit-category-field'));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  final row = find.descendant(
    of: find.byType(BottomSheet),
    matching: find.widgetWithText(ListTile, label),
  );
  await tester.scrollUntilVisible(
    row,
    100,
    scrollable: find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
  expect(find.bySemanticsLabel('Category, $label'), findsOneWidget);
}

/// The visible pill of a chip (inside its padded tap target).
Rect _pill(WidgetTester tester, String label) => tester.getRect(
  find.descendant(of: _chip(label), matching: find.byType(Material)).last,
);
