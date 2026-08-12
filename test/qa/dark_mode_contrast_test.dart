import 'dart:math' as math;

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

  group('secondary text meets WCAG AA in both themes', () {
    /// WCAG 2.1 relative luminance.
    double luminance(Color color) {
      double channel(double value) {
        final srgb = value / 255;
        return srgb <= 0.03928
            ? srgb / 12.92
            : math.pow((srgb + 0.055) / 1.055, 2.4).toDouble();
      }

      return 0.2126 * channel(color.r * 255) +
          0.7152 * channel(color.g * 255) +
          0.0722 * channel(color.b * 255);
    }

    double contrast(Color a, Color b) {
      final first = luminance(a);
      final second = luminance(b);
      final lighter = first > second ? first : second;
      final darker = first > second ? second : first;
      return (lighter + 0.05) / (darker + 0.05);
    }

    test('muted text clears 4.5:1 on both surfaces', () {
      // The light-theme taupe reaches only ~3.4:1 on darkSurface, which is why
      // the dark variant exists.
      expect(contrast(AppColors.taupe, AppColors.ivory), greaterThan(4.5));
      expect(
        contrast(AppColors.taupeLight, AppColors.darkSurface),
        greaterThan(4.5),
      );
      expect(
        contrast(AppColors.taupeLight, AppColors.darkCard),
        greaterThan(4.5),
      );
      expect(contrast(AppColors.taupe, AppColors.darkSurface), lessThan(4.5));
    });

    test('accent chip labels clear 4.5:1 on the dark card', () {
      expect(
        contrast(AppColors.roseLight, AppColors.darkCard),
        greaterThan(4.5),
      );
      expect(
        contrast(AppColors.successLight, AppColors.darkCard),
        greaterThan(4.5),
      );
    });

    Future<BuildContext> contextFor(
      WidgetTester tester,
      ThemeData theme,
    ) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return captured;
    }

    testWidgets('muted and onTint lighten under the dark theme', (
      tester,
    ) async {
      final context = await contextFor(tester, AppTheme.darkTheme);

      expect(AppColors.muted(context), AppColors.taupeLight);
      expect(AppColors.onTint(context, AppColors.rose), AppColors.roseLight);
      expect(
        AppColors.onTint(context, AppColors.success),
        AppColors.successLight,
      );
    });

    testWidgets('muted and onTint keep brand tones under the light theme', (
      tester,
    ) async {
      final context = await contextFor(tester, AppTheme.lightTheme);

      expect(AppColors.muted(context), AppColors.taupe);
      expect(AppColors.onTint(context, AppColors.rose), AppColors.rose);
      expect(AppColors.onTint(context, AppColors.success), AppColors.success);
    });
  });

  test('onAccent picks a contrasting foreground for each surface', () {
    expect(AppColors.onAccent(AppColors.petal), AppColors.cocoa);
    expect(AppColors.onAccent(AppColors.blush), AppColors.cocoa);
    expect(AppColors.onAccent(AppColors.roseDark), Colors.white);
    expect(AppColors.onAccent(AppColors.darkCard), Colors.white);
  });
}
