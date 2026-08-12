import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:facetune/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Color? _colorOf(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text)).text.style?.color;

Widget _app({required ThemeData theme, required Widget child}) => MaterialApp(
  theme: theme,
  home: Scaffold(body: child),
);

void main() {
  group('accent surfaces stay readable in dark mode', () {
    testWidgets('plain text on an accent card does not inherit onSurface', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          theme: AppTheme.darkTheme,
          child: const AppCard(
            color: AppColors.petal,
            child: Text('Guest account notice'),
          ),
        ),
      );

      // Without the accent-aware foreground this resolves to the dark theme's
      // near-white onSurface, which is invisible on the light petal card.
      expect(_colorOf(tester, 'Guest account notice'), AppColors.cocoa);
    });

    testWidgets('an explicit text theme style is recoloured too', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          theme: AppTheme.darkTheme,
          child: AppCard(
            color: AppColors.petal,
            child: Builder(
              builder: (context) => Text(
                'Ready when inspiration strikes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ),
      );

      expect(
        _colorOf(tester, 'Ready when inspiration strikes'),
        AppColors.cocoa,
      );
    });

    testWidgets('a default card still follows the active theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          theme: AppTheme.darkTheme,
          child: const AppCard(child: Text('Regular card copy')),
        ),
      );

      // Guards against over-correcting: uncoloured cards must stay theme-driven.
      expect(_colorOf(tester, 'Regular card copy'), isNot(AppColors.cocoa));
    });

    testWidgets('light mode keeps the same accent foreground', (tester) async {
      await tester.pumpWidget(
        _app(
          theme: AppTheme.lightTheme,
          child: const AppCard(
            color: AppColors.petal,
            child: Text('Guest account notice'),
          ),
        ),
      );

      expect(_colorOf(tester, 'Guest account notice'), AppColors.cocoa);
    });
  });

  test('onAccent picks a contrasting foreground for each surface', () {
    expect(AppColors.onAccent(AppColors.petal), AppColors.cocoa);
    expect(AppColors.onAccent(AppColors.blush), AppColors.cocoa);
    expect(AppColors.onAccent(AppColors.roseDark), Colors.white);
    expect(AppColors.onAccent(AppColors.darkCard), Colors.white);
  });
}
