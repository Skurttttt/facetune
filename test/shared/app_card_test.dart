import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_semantics.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:facetune/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({required ThemeData theme, required Widget child}) => MaterialApp(
  theme: theme,
  home: Scaffold(body: Center(child: child)),
);

/// The `Card` an [AppCard] renders — the surface the theme and the emphasis
/// flag act on.
Card _cardOf(WidgetTester tester) => tester.widget<Card>(
  find.descendant(of: find.byType(AppCard), matching: find.byType(Card)),
);

/// The Material the card paints with, which is where elevation would show up.
Material _materialOf(WidgetTester tester) => tester.widget<Material>(
  find.descendant(of: find.byType(Card), matching: find.byType(Material)),
);

RoundedRectangleBorder _emphasisShape(WidgetTester tester) {
  final shape = _cardOf(tester).shape;
  expect(shape, isA<RoundedRectangleBorder>());
  return shape! as RoundedRectangleBorder;
}

void main() {
  group('default AppCard is unchanged', () {
    testWidgets('hands its shape and elevation to the theme', (tester) async {
      await tester.pumpWidget(
        _app(
          theme: AppTheme.lightTheme,
          child: const AppCard(child: Text('Regular card')),
        ),
      );

      final card = _cardOf(tester);
      // Null on both: the card is whatever `cardTheme` says, which is how every
      // existing consumer already gets the global radius and hairline.
      expect(card.shape, isNull);
      expect(card.elevation, isNull);
      expect(card.color, isNull);
      expect(_materialOf(tester).elevation, AppElevation.none);
    });

    testWidgets('draws the theme hairline, not the emphasis weight', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          theme: AppTheme.lightTheme,
          child: const AppCard(child: Text('Regular card')),
        ),
      );

      final themed =
          _materialOf(tester).shape ??
          AppTheme.lightTheme.cardTheme.shape as ShapeBorder;
      expect(themed, isA<RoundedRectangleBorder>());
      final shape = themed as RoundedRectangleBorder;
      expect(shape.side.width, AppBorders.hairline);
      expect(shape.borderRadius, BorderRadius.circular(AppRadii.lg));
    });

    testWidgets('does not claim to be selected', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          theme: AppTheme.lightTheme,
          child: const AppCard(child: Text('Regular card')),
        ),
      );

      expect(
        tester.getSemantics(find.byType(AppCard)),
        isNot(containsSemantics(isSelected: true)),
      );
      handle.dispose();
    });

    testWidgets('keeps its tap, padding and accent-colour behaviour', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          theme: AppTheme.darkTheme,
          child: AppCard(
            color: AppColors.petal,
            padding: const EdgeInsets.all(AppSpacing.sm),
            onTap: () => taps++,
            child: const Text('Accent card'),
          ),
        ),
      );

      await tester.tap(find.text('Accent card'));
      expect(taps, 1);
      expect(_cardOf(tester).color, AppColors.petal);
      final padding = tester.widget<Padding>(
        find
            .ancestor(
              of: find.text('Accent card'),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(padding.padding, const EdgeInsets.all(AppSpacing.sm));
    });
  });

  group('emphasized AppCard', () {
    testWidgets('light theme: emphasis border in the light info accent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          theme: AppTheme.lightTheme,
          child: const AppCard(emphasized: true, child: Text('Chosen')),
        ),
      );

      final shape = _emphasisShape(tester);
      expect(shape.side.width, AppBorders.emphasis);
      expect(shape.side.color, AppSemantics.light.info.accent);
      expect(shape.side.color, AppColors.rose);
    });

    testWidgets('dark theme: emphasis border in the dark info accent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          theme: AppTheme.darkTheme,
          child: const AppCard(emphasized: true, child: Text('Chosen')),
        ),
      );

      final shape = _emphasisShape(tester);
      expect(shape.side.width, AppBorders.emphasis);
      // The lightened tone, not raw rose: rose is 3.1:1 on the dark card.
      expect(shape.side.color, AppSemantics.dark.info.accent);
      expect(shape.side.color, AppColors.roseLight);
    });

    testWidgets('keeps the global card radius and surface', (tester) async {
      await tester.pumpWidget(
        _app(
          theme: AppTheme.lightTheme,
          child: const AppCard(emphasized: true, child: Text('Chosen')),
        ),
      );

      expect(
        _emphasisShape(tester).borderRadius,
        BorderRadius.circular(AppRadii.lg),
      );
      // No tint by default: the surface is still the theme's card colour.
      expect(_cardOf(tester).color, isNull);
    });

    testWidgets('adds no elevation or shadow', (tester) async {
      await tester.pumpWidget(
        _app(
          theme: AppTheme.lightTheme,
          child: const AppCard(emphasized: true, child: Text('Chosen')),
        ),
      );

      // Elevation is what paints a shadow; at zero the Material draws none,
      // whatever `shadowColor` the theme happens to forward.
      expect(_cardOf(tester).elevation, isNull);
      expect(_materialOf(tester).elevation, AppElevation.none);
      expect(AppTheme.lightTheme.cardTheme.elevation, AppElevation.none);
    });

    testWidgets('reports selected to assistive technology', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          theme: AppTheme.lightTheme,
          child: const AppCard(emphasized: true, child: Text('Chosen')),
        ),
      );

      expect(
        tester.getSemantics(find.byType(AppCard)),
        containsSemantics(isSelected: true),
      );
      handle.dispose();
    });

    testWidgets('emphasis and selection can be told apart', (tester) async {
      final handle = tester.ensureSemantics();
      // Emphasized but explicitly not selected — a recommended card.
      await tester.pumpWidget(
        _app(
          theme: AppTheme.lightTheme,
          child: const AppCard(
            emphasized: true,
            selected: false,
            child: Text('Recommended'),
          ),
        ),
      );
      expect(_emphasisShape(tester).side.width, AppBorders.emphasis);
      expect(
        tester.getSemantics(find.byType(AppCard)),
        isNot(containsSemantics(isSelected: true)),
      );

      // Selected but not emphasized — reported, not drawn heavier.
      await tester.pumpWidget(
        _app(
          theme: AppTheme.lightTheme,
          child: const AppCard(selected: true, child: Text('Chosen quietly')),
        ),
      );
      expect(_cardOf(tester).shape, isNull);
      expect(
        tester.getSemantics(find.byType(AppCard)),
        containsSemantics(isSelected: true),
      );
      handle.dispose();
    });

    testWidgets('a selected card does not mark its parent as selected', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          theme: AppTheme.lightTheme,
          child: Semantics(
            container: true,
            label: 'A list of cards',
            child: const AppCard(emphasized: true, child: Text('Chosen')),
          ),
        ),
      );

      // The flag lives on the card's own node, so a card inside a scrollable
      // never turns the whole list "selected".
      expect(
        tester.getSemantics(find.bySemanticsLabel('A list of cards')),
        isNot(containsSemantics(isSelected: true)),
      );
      expect(
        tester.getSemantics(find.byType(AppCard)),
        containsSemantics(isSelected: true),
      );
      handle.dispose();
    });

    testWidgets('still taps and still recolours an accent surface', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          theme: AppTheme.darkTheme,
          child: AppCard(
            emphasized: true,
            color: AppColors.petal,
            onTap: () => taps++,
            child: const Text('Chosen accent'),
          ),
        ),
      );

      await tester.tap(find.text('Chosen accent'));
      expect(taps, 1);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('Chosen accent'),
      );
      expect(paragraph.text.style?.color, AppColors.cocoa);
    });
  });
}
