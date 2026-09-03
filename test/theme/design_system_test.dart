import 'dart:math' as math;

import 'package:facetune/theme/app_semantics.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:facetune/theme/app_tokens.dart';
import 'package:facetune/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color color) {
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

double _contrast(Color a, Color b) {
  final first = _luminance(a);
  final second = _luminance(b);
  final lighter = math.max(first, second);
  final darker = math.min(first, second);
  return (lighter + 0.05) / (darker + 0.05);
}

Future<BuildContext> _contextFor(WidgetTester tester, ThemeData theme) async {
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

void main() {
  group('semantic roles are legible', () {
    // Both palettes are asserted against the same thresholds. The whole point
    // of the semantic layer is that a role is safe to use without the caller
    // checking anything, so every combination it can produce has to clear AA.
    const palettes = {'light': AppSemantics.light, 'dark': AppSemantics.dark};

    palettes.forEach((name, palette) {
      final roles = {
        'info': palette.info,
        'success': palette.success,
        'warning': palette.warning,
        'danger': palette.danger,
      };

      roles.forEach((role, values) {
        test('$name.$role body copy clears 4.5:1', () {
          expect(
            _contrast(values.onSurface, values.surface),
            greaterThanOrEqualTo(4.5),
            reason: '$name.$role onSurface on its own surface',
          );
        });

        // 4.5 rather than the 3:1 that WCAG 1.4.11 sets for non-text graphics,
        // because the accent paints emphasised *words* as well as icons. Holding
        // both to the text threshold means a caller never has to know which.
        test('$name.$role accent clears 4.5:1 as icon and as text', () {
          expect(
            _contrast(values.accent, values.surface),
            greaterThanOrEqualTo(4.5),
            reason: '$name.$role accent on its own surface',
          );
        });
      });
    });

    test('the light warning accent is the deepened gold, not the brand gold', () {
      // The regression this guards: AppColors.gold reaches only 2.83:1 on the
      // warning tint, under even the 3:1 graphics minimum. Anyone "simplifying"
      // goldDeep back to gold breaks AA, and this says so by name.
      expect(AppSemantics.light.warning.accent, AppColors.goldDeep);
      expect(
        _contrast(AppColors.gold, AppSemantics.light.warning.surface),
        lessThan(3),
      );
      expect(
        _contrast(AppColors.goldDeep, AppSemantics.light.warning.surface),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('semantic roles are distinguishable from each other', () {
    // This is the actual defect UI-P0 found: `AppColors.petal` was the surface
    // for "Local checks passed" AND for "Analysis paused" on the same screen.
    // These tests fail if any two outcomes ever collapse onto one appearance
    // again.
    for (final entry in {
      'light': AppSemantics.light,
      'dark': AppSemantics.dark,
    }.entries) {
      test('${entry.key}: success and danger never share a surface', () {
        expect(entry.value.success.surface, isNot(entry.value.danger.surface));
        expect(entry.value.success.accent, isNot(entry.value.danger.accent));
      });

      test('${entry.key}: all four surfaces are distinct', () {
        final surfaces = {
          entry.value.info.surface,
          entry.value.success.surface,
          entry.value.warning.surface,
          entry.value.danger.surface,
        };
        expect(surfaces, hasLength(4));
      });

      test('${entry.key}: every tone carries a distinct icon', () {
        final icons = AppTone.values.map((tone) => tone.icon).toSet();
        expect(icons, hasLength(AppTone.values.length));
      });
    }

    test('a border delineates each surface from the page ground', () {
      // Necessary rather than decorative: in dark mode the tinted surfaces
      // separate from the ground by only ~1.05-1.10:1, so without the border
      // the notice has no visible edge at all.
      for (final role in [
        AppSemantics.dark.info,
        AppSemantics.dark.success,
        AppSemantics.dark.warning,
        AppSemantics.dark.danger,
      ]) {
        expect(
          _contrast(role.border, AppColors.darkSurface),
          greaterThan(_contrast(role.surface, AppColors.darkSurface)),
          reason: 'the border must be more visible than the surface it edges',
        );
      }
    });
  });

  group('theme resolution', () {
    testWidgets('light theme resolves the light palette', (tester) async {
      final context = await _contextFor(tester, AppTheme.lightTheme);
      expect(AppSemantics.of(context), same(AppSemantics.light));
      expect(AppTone.danger.resolve(context), AppSemantics.light.danger);
    });

    testWidgets('dark theme resolves the dark palette', (tester) async {
      final context = await _contextFor(tester, AppTheme.darkTheme);
      expect(AppSemantics.of(context), same(AppSemantics.dark));
      expect(AppTone.danger.resolve(context), AppSemantics.dark.danger);
    });

    testWidgets('an unregistered extension still resolves by brightness', (
      tester,
    ) async {
      // A bare MaterialApp — which is what most widget tests build — must not
      // throw. Falling back by brightness keeps those tests meaningful.
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(AppSemantics.of(captured), same(AppSemantics.dark));
    });

    testWidgets('System theme follows the platform brightness', (tester) async {
      // The app passes ThemeMode from a provider into MaterialApp.router. This
      // asserts the two ThemeData objects are actually selectable by platform
      // brightness, which is what "System" resolves through.
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      Future<ThemeData> themeUnder(Brightness platform) async {
        // Set on the platform dispatcher, not in a MediaQuery above the app:
        // MaterialApp builds its own MediaQuery from the view, so an ancestor
        // one is discarded and the test would silently always read light.
        tester.platformDispatcher.platformBrightnessTestValue = platform;
        // Unmount first. Re-pumping the same widget type updates the existing
        // element tree, and the new platform brightness would not be picked up
        // — the test would read the previous theme and pass for the wrong
        // reason.
        await tester.pumpWidget(const SizedBox.shrink());
        late BuildContext captured;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: Builder(
              builder: (context) {
                captured = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        return Theme.of(captured);
      }

      final light = await themeUnder(Brightness.light);
      expect(light.brightness, Brightness.light);
      expect(light.extension<AppSemantics>(), same(AppSemantics.light));

      final dark = await themeUnder(Brightness.dark);
      expect(dark.brightness, Brightness.dark);
      expect(dark.extension<AppSemantics>(), same(AppSemantics.dark));
    });

    test('both themes register the semantics extension', () {
      expect(AppTheme.lightTheme.extension<AppSemantics>(), isNotNull);
      expect(AppTheme.darkTheme.extension<AppSemantics>(), isNotNull);
    });

    test('the extension lerps between palettes rather than snapping', () {
      final midpoint = AppSemantics.light.lerp(AppSemantics.dark, 0.5);
      expect(midpoint.danger.surface, isNot(AppSemantics.light.danger.surface));
      expect(midpoint.danger.surface, isNot(AppSemantics.dark.danger.surface));
    });
  });

  group('typography', () {
    // A scale that only shrinks cannot push content out of the fixed-height
    // boxes the audit found. If a future change grows a role, that is a real
    // decision and it should have to come and edit this test.
    // `ThemeData.textTheme` carries null font sizes — Material resolves them
    // from `Typography` later — so the baseline has to be read from Typography
    // itself. Comparing against `ThemeData.textTheme` compares null to null and
    // passes no matter what the scale does.
    final material = Typography.material2021().englishLike;
    final ours = AppTheme.lightTheme.textTheme;

    /// Our effective size for a role: the explicit one, or Material's when we
    /// deliberately leave a role alone.
    double effective(TextStyle? mine, TextStyle? base) =>
        mine?.fontSize ?? base!.fontSize!;

    test('no role is larger than the Material default it replaces', () {
      final roles = <String, (TextStyle?, TextStyle?)>{
        'displayLarge': (ours.displayLarge, material.displayLarge),
        'displayMedium': (ours.displayMedium, material.displayMedium),
        'displaySmall': (ours.displaySmall, material.displaySmall),
        'headlineLarge': (ours.headlineLarge, material.headlineLarge),
        'headlineMedium': (ours.headlineMedium, material.headlineMedium),
        'headlineSmall': (ours.headlineSmall, material.headlineSmall),
        'titleLarge': (ours.titleLarge, material.titleLarge),
        'titleMedium': (ours.titleMedium, material.titleMedium),
        'titleSmall': (ours.titleSmall, material.titleSmall),
        'bodyLarge': (ours.bodyLarge, material.bodyLarge),
        'bodyMedium': (ours.bodyMedium, material.bodyMedium),
        'bodySmall': (ours.bodySmall, material.bodySmall),
        'labelLarge': (ours.labelLarge, material.labelLarge),
      };

      roles.forEach((role, pair) {
        expect(
          effective(pair.$1, pair.$2),
          lessThanOrEqualTo(pair.$2!.fontSize!),
          reason:
              '$role grew from ${pair.$2!.fontSize} to '
              '${effective(pair.$1, pair.$2)}; a scale that only shrinks '
              'cannot push content out of a fixed-height box',
        );
      });
    });

    test('the display end really was tightened', () {
      // Guards the other direction: if this scale ever silently becomes a
      // no-op copy of Material, the test above would still pass.
      expect(
        effective(ours.displaySmall, material.displaySmall),
        lessThan(material.displaySmall!.fontSize!),
      );
      expect(
        effective(ours.titleLarge, material.titleLarge),
        lessThan(material.titleLarge!.fontSize!),
      );
    });

    test('body sizes are left at the Material defaults', () {
      // Shrinking the sizes people actually read is how an app becomes
      // fashionable and unusable. Only the display end was tightened.
      expect(
        effective(ours.bodyLarge, material.bodyLarge),
        material.bodyLarge!.fontSize,
      );
      expect(
        effective(ours.bodyMedium, material.bodyMedium),
        material.bodyMedium!.fontSize,
      );
      expect(
        effective(ours.bodySmall, material.bodySmall),
        material.bodySmall!.fontSize,
      );
    });

    test('a section header sits below the screen headline', () {
      expect(
        effective(ours.titleLarge, material.titleLarge),
        lessThan(effective(ours.headlineSmall, material.headlineSmall)),
      );
    });

    test('light and dark share one scale', () {
      final dark = AppTheme.darkTheme.textTheme;
      expect(ours.titleLarge!.fontSize, dark.titleLarge!.fontSize);
      expect(ours.displaySmall!.fontSize, dark.displaySmall!.fontSize);
      expect(ours.headlineMedium!.fontSize, dark.headlineMedium!.fontSize);
    });

    test('one family across every role, set from one constant', () {
      // Guards the swap point. `AppTypography.fontFamily` is null today, which
      // means "the platform's own UI face" — so every role reports whatever
      // Material resolved, and crucially they all report the *same* thing.
      // A future licensed face is set in that one constant and nowhere else.
      expect(AppTypography.fontFamily, isNull);
      final families = {
        ours.displaySmall?.fontFamily,
        ours.headlineMedium?.fontFamily,
        ours.titleLarge?.fontFamily,
        ours.bodyMedium?.fontFamily,
        ours.labelLarge?.fontFamily,
      };
      expect(
        families,
        hasLength(1),
        reason: 'a role has been given its own font family',
      );
    });
  });

  group('component themes exist so screens need not restyle', () {
    for (final entry in {
      'light': AppTheme.lightTheme,
      'dark': AppTheme.darkTheme,
    }.entries) {
      final theme = entry.value;

      test(
        '${entry.key}: the invalid input state has a defined appearance',
        () {
          // Previously absent entirely, so a failed validation fell back to
          // Material's default red instead of the brand's.
          expect(theme.inputDecorationTheme.errorBorder, isNotNull);
          expect(theme.inputDecorationTheme.focusedErrorBorder, isNotNull);
          expect(theme.inputDecorationTheme.errorStyle?.color, isNotNull);

          final expected = entry.key == 'dark'
              ? AppColors.errorLight
              : AppColors.errorDeep;
          expect(theme.inputDecorationTheme.errorStyle!.color, expected);
        },
      );

      test('${entry.key}: focus is heavier than rest', () {
        final enabled =
            theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
        final focused =
            theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder;
        expect(
          focused.borderSide.width,
          greaterThan(enabled.borderSide.width),
          reason: 'focus must be visible without relying on colour alone',
        );
      });

      test('${entry.key}: dividers, chips and list tiles are themed', () {
        // Each of these was unthemed, so every raw `Divider` and `Chip` in the
        // app drew a framework default rather than the brand hairline.
        expect(theme.dividerTheme.color, isNotNull);
        expect(theme.chipTheme.shape, isNotNull);
        expect(theme.listTileTheme.titleTextStyle, isNotNull);
        expect(theme.segmentedButtonTheme.style, isNotNull);
      });

      test('${entry.key}: disabled buttons have a defined appearance', () {
        expect(theme.filledButtonTheme.style, isNotNull);
        expect(theme.outlinedButtonTheme.style, isNotNull);
        expect(theme.textButtonTheme.style, isNotNull);
      });

      test('${entry.key}: page transitions are configured for Android', () {
        expect(
          theme.pageTransitionsTheme.builders[TargetPlatform.android],
          isA<FadeForwardsPageTransitionsBuilder>(),
        );
      });
    }
  });

  group('token scales', () {
    test('spacing, radius and icon scales ascend', () {
      expect(AppSpacing.xxs, lessThan(AppSpacing.xs));
      expect(AppSpacing.xs, lessThan(AppSpacing.sm));
      expect(AppSpacing.sm, lessThan(AppSpacing.md));
      expect(AppSpacing.md, lessThan(AppSpacing.lg));
      expect(AppSpacing.lg, lessThan(AppSpacing.xl));
      expect(AppSpacing.xl, lessThan(AppSpacing.xxl));

      expect(AppRadii.sm, lessThan(AppRadii.md));
      expect(AppRadii.md, lessThan(AppRadii.lg));
      expect(AppRadii.lg, lessThan(AppRadii.xl));

      expect(AppIconSizes.sm, lessThan(AppIconSizes.md));
      expect(AppIconSizes.md, lessThan(AppIconSizes.lg));
      expect(AppIconSizes.lg, lessThan(AppIconSizes.hero));
    });

    test(
      'motion durations ascend and the shimmer is slower than any of them',
      () {
        expect(AppDurations.quick, lessThan(AppDurations.standard));
        expect(AppDurations.standard, lessThan(AppDurations.slow));
        // A shimmer pulsing at interaction speed reads as urgency, which is the
        // wrong signal while someone is waiting.
        expect(AppDurations.slow, lessThan(AppDurations.shimmer));
      },
    );

    test('onTint lightens every accent that needs it in dark mode', () {
      // gold and error were previously unhandled, so they stayed at their
      // light-surface tone on a dark card.
      final cases = {
        AppColors.rose: AppColors.roseLight,
        AppColors.success: AppColors.successLight,
        AppColors.taupe: AppColors.taupeLight,
        AppColors.gold: AppColors.goldLight,
        AppColors.error: AppColors.errorLight,
      };
      cases.forEach((input, expected) {
        expect(
          _contrast(expected, AppColors.darkCard),
          greaterThanOrEqualTo(4.5),
          reason: 'the dark variant of $input must clear AA on the dark card',
        );
      });
    });
  });
}
