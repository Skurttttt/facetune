import 'dart:io';

import 'package:facetune/core/constants/app_constants.dart';
import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/analysis/presentation/controllers/face_analysis_controller.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/custom_palette/data/custom_palette_providers.dart';
import 'package:facetune/features/custom_palette/domain/catalog/custom_palette_catalog.dart';
import 'package:facetune/features/custom_palette/domain/catalog/custom_palette_color_model.dart';
import 'package:facetune/features/custom_palette/domain/repositories/custom_palette_gateway.dart';
import 'package:facetune/features/custom_palette/domain/validation/custom_palette_contract.dart';
import 'package:facetune/features/custom_palette/presentation/pages/custom_palette_category_page.dart';
import 'package:facetune/features/custom_palette/presentation/pages/custom_palette_page.dart';
import 'package:facetune/features/custom_palette/presentation/pages/custom_palette_result_page.dart';
import 'package:facetune/features/custom_palette/presentation/pages/custom_palette_review_page.dart';
import 'package:facetune/features/custom_palette/presentation/controllers/custom_palette_draft_controller.dart';
import 'package:facetune/features/custom_palette/presentation/widgets/custom_palette_selection_summary.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/makeup_kit/domain/value_objects/normalized_hex_color.dart';
import 'package:facetune/features/makeup_kit/presentation/utils/makeup_kit_display.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_recommendation_mode.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_recommendation_mode_controller.dart';
import 'package:facetune/features/makeup_kit/presentation/pages/recommendation_mode_selection_page.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/makeup_styles/presentation/controllers/makeup_style_selection_controller.dart';
import 'package:facetune/features/recommendation/presentation/controllers/makeup_recommendation_controller.dart';
import 'package:facetune/features/recommendation/presentation/controllers/makeup_recommendation_state.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/analysis_response_fixture.dart';
import '../../helpers/custom_palette_fixture.dart';
import '../../helpers/fake_auth_repository.dart';

class _Harness {
  _Harness(this.container, this.gateway);

  final ProviderContainer container;
  final FakePaletteGateway gateway;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  Size size = const Size(393, 2600),
  double textScale = 1,
  bool withAnalysis = true,
  String initialLocation = AppConstants.recommendationModeRoute,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final gateway = FakePaletteGateway();
  final container = ProviderContainer(
    overrides: [
      supabaseAvailableProvider.overrideWithValue(false),
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(
          user: const AuthUser(id: 'user-1', isAnonymous: false),
        ),
      ),
      customPaletteGatewayProvider.overrideWithValue(gateway),
    ],
  );
  addTearDown(container.dispose);
  if (withAnalysis) {
    container
        .read(faceAnalysisControllerProvider.notifier)
        .restore(FaceAnalysisDto.fromResponse(validAnalysisResponse).analysis);
    container
        .read(makeupStyleSelectionControllerProvider.notifier)
        .restore(
          MakeupStyleCatalog.styles.firstWhere((s) => s.code == 'soft_glam'),
        );
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        routerConfig: GoRouter(
          initialLocation: initialLocation,
          routes: [
            GoRoute(
              path: AppConstants.recommendationModeRoute,
              builder: (context, state) =>
                  const RecommendationModeSelectionPage(),
            ),
            GoRoute(
              path: AppConstants.customPaletteRoute,
              builder: (context, state) => const CustomPalettePage(),
            ),
            GoRoute(
              path: AppConstants.customPaletteCategoryRoute,
              builder: (context, state) => CustomPaletteCategoryPage(
                categoryCode: state.pathParameters['categoryCode']!,
              ),
            ),
            GoRoute(
              path: AppConstants.customPaletteReviewRoute,
              builder: (context, state) => const CustomPaletteReviewPage(),
            ),
            GoRoute(
              path: AppConstants.customPaletteResultRoute,
              builder: (context, state) => const CustomPaletteResultPage(),
            ),
            GoRoute(
              path: AppConstants.stylesRoute,
              builder: (context, state) => const Text('Styles page'),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(container, gateway);
}

VoidCallback? _callback(WidgetTester tester, String label) => tester
    .widget<PrimaryButton>(find.widgetWithText(PrimaryButton, label))
    .onPressed;

Future<void> _enterPalette(WidgetTester tester) async {
  await tester.tap(find.text('Use Custom Color Palette'));
  await tester.pumpAndSettle();
}

/// [_enterPalette] on a screen too short to show the entry without scrolling.
Future<void> _enterPaletteScrolled(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Use Custom Color Palette'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text('Use Custom Color Palette'));
  await tester.pumpAndSettle();
  await _enterPalette(tester);
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// The include switch of the category labelled [label], scrolled into view.
///
/// Targeted by its spoken label: with My Makeup Kit's ten categories the first
/// switch on the screen is Foundation, not Blush.
Future<Finder> _includeSwitch(WidgetTester tester, String label) async {
  final finder = find.descendant(
    of: find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.label == 'Include $label',
    ),
    matching: find.byType(Switch),
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  return finder;
}

Future<void> _chooseBlush(WidgetTester tester) async {
  await _tapText(tester, 'Choose Blush');
  await _tapText(tester, 'Red');
  await _tapText(tester, 'Matte');
  await _tapText(tester, 'Done');
}

void main() {
  group('mode selection', () {
    testWidgets('shows the third mode beside the two existing ones', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Makeup Recommendation'), findsOneWidget);
      expect(find.text('My Makeup Kit'), findsOneWidget);
      expect(find.text('Custom Color Palette'), findsOneWidget);
      expect(find.text('Use Makeup Recommendation'), findsOneWidget);
      expect(
        find.text('Let FaceTune choose the ideal makeup for you.'),
        findsOne,
      );
      expect(find.text('Use Custom Color Palette'), findsOneWidget);
    });

    testWidgets('entering it starts neither existing mode', (tester) async {
      final harness = await _pump(tester);
      harness.container
          .read(makeupRecommendationModeControllerProvider.notifier)
          .select(MakeupRecommendationMode.standard);
      await _enterPalette(tester);
      expect(find.text('Choose your colors'), findsOneWidget);
      expect(
        harness.container.read(makeupRecommendationModeControllerProvider),
        MakeupRecommendationMode.customColorPalette,
      );
      expect(
        harness.container.read(makeupRecommendationControllerProvider).status,
        MakeupRecommendationStatus.idle,
      );
    });

    testWidgets('does not depend on owning any kit product', (tester) async {
      await _pump(tester);
      await _enterPalette(tester);
      expect(find.text('Choose your colors'), findsOneWidget);
    });
  });

  group('palette screen', () {
    testWidgets(
      'shows exactly My Makeup Kit\'s categories, in Tutorial order',
      (tester) async {
        await _pump(tester);
        await _enterPalette(tester);
        const labels = [
          'Foundation',
          'Concealer',
          'Contour/Bronzer',
          'Blush',
          'Highlighter',
          'Eyebrow',
          'Eyeshadow',
          'Eyeliner',
          'Lipstick',
          'Lip Gloss',
        ];
        // The list is built lazily, so each row is scrolled to in turn. Every
        // label is found exactly once, and sits below the previous one whenever
        // both are on screen together.
        for (var i = 0; i < labels.length; i += 1) {
          final finder = find.text(labels[i]);
          await tester.scrollUntilVisible(
            finder,
            120,
            scrollable: find.byType(Scrollable).first,
          );
          expect(finder, findsOneWidget, reason: labels[i]);
          if (i > 0 && tester.any(find.text(labels[i - 1]))) {
            expect(
              tester.getTopLeft(finder).dy,
              greaterThan(tester.getTopLeft(find.text(labels[i - 1])).dy),
              reason: '${labels[i - 1]} before ${labels[i]}',
            );
          }
        }
      },
    );

    testWidgets('blocks Review until the contract passes, and says why', (
      tester,
    ) async {
      await _pump(tester);
      await _enterPalette(tester);
      expect(_callback(tester, 'Review palette'), isNull);
      expect(
        find.text('Turn on at least one category to continue.'),
        findsOneWidget,
      );

      await tester.tap(await _includeSwitch(tester, 'Blush'));
      await tester.pumpAndSettle();
      expect(_callback(tester, 'Review palette'), isNull);
      expect(find.text('Choose a color and finish for Blush.'), findsOneWidget);

      await _chooseBlush(tester);
      expect(_callback(tester, 'Review palette'), isNotNull);
    });

    testWidgets('a color without a finish stays blocked', (tester) async {
      await _pump(tester);
      await _enterPalette(tester);
      await _tapText(tester, 'Choose Blush');
      await _tapText(tester, 'Red');
      await _tapText(tester, 'Done');
      expect(_callback(tester, 'Review palette'), isNull);
    });

    testWidgets('turning a category off removes it from the look', (
      tester,
    ) async {
      await _pump(tester);
      await _enterPalette(tester);
      await _chooseBlush(tester);
      await tester.tap(await _includeSwitch(tester, 'Blush'));
      await tester.pumpAndSettle();
      expect(_callback(tester, 'Review palette'), isNull);
      expect(find.text('Red (#C8102E)'), findsOneWidget);
    });
  });

  group('category editor', () {
    testWidgets('filters finishes by category', (tester) async {
      await _pump(tester);
      await _enterPalette(tester);

      Future<void> expectFinishes(
        String button,
        List<String> shown,
        List<String> hidden,
      ) async {
        await _tapText(tester, button);
        for (final label in shown) {
          expect(find.text(label), findsOneWidget, reason: '$button $label');
        }
        for (final label in hidden) {
          expect(find.text(label), findsNothing, reason: '$button $label');
        }
        await _tapText(tester, 'Done');
      }

      await expectFinishes(
        'Choose Blush',
        ['Matte', 'Satin', 'Shimmer'],
        ['Glossy', 'Metallic', 'Glitter', 'Cream'],
      );
      await expectFinishes(
        'Choose Eyeshadow',
        ['Matte', 'Satin', 'Shimmer', 'Metallic', 'Glitter'],
        ['Glossy', 'Cream'],
      );
      await expectFinishes(
        'Choose Eyeliner',
        ['Matte', 'Satin', 'Glossy'],
        ['Shimmer', 'Metallic', 'Glitter', 'Cream'],
      );
      await expectFinishes(
        'Choose Lipstick',
        ['Matte', 'Satin', 'Cream', 'Glossy'],
        ['Shimmer', 'Metallic', 'Glitter'],
      );
    });

    testWidgets('offers every swatch and no hue or HEX control', (
      tester,
    ) async {
      await _pump(tester);
      await _enterPalette(tester);
      await _tapText(tester, 'Choose Blush');
      for (final swatch in CustomPaletteCatalog.swatches) {
        expect(find.text(swatch.label), findsOneWidget, reason: swatch.label);
      }
      await _tapText(tester, 'Red');
      expect(find.text('Saturation'), findsOneWidget);
      expect(find.text('Lightness'), findsOneWidget);
      expect(find.text('Hue'), findsNothing);
      expect(find.byType(Slider), findsNWidgets(2));
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('adjusting updates the final color and Reset restores it', (
      tester,
    ) async {
      await _pump(tester);
      await _enterPalette(tester);
      await _tapText(tester, 'Choose Blush');
      await _tapText(tester, 'Red');
      expect(find.text('Red (#C8102E)'), findsOneWidget);

      tester.widget<Slider>(find.byType(Slider).last).onChanged!(70);
      await tester.pumpAndSettle();
      expect(find.text('Red (#C8102E)'), findsNothing);
      expect(find.textContaining('Red, adjusted (#'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget);

      await _tapText(tester, 'Reset');
      expect(find.text('Red (#C8102E)'), findsOneWidget);
    });

    testWidgets('saturation is disabled for an achromatic color', (
      tester,
    ) async {
      await _pump(tester);
      await _enterPalette(tester);
      await _tapText(tester, 'Choose Blush');
      await _tapText(tester, 'Black');
      expect(
        tester.widget<Slider>(find.byType(Slider).first).onChanged,
        isNull,
      );
      expect(
        tester.widget<Slider>(find.byType(Slider).last).onChanged,
        isNotNull,
      );
      expect(
        find.text('This color has no saturation to adjust.'),
        findsOneWidget,
      );
    });

    testWidgets('an unsupported category shows the not-ready state', (
      tester,
    ) async {
      await _pump(
        tester,
        initialLocation: AppConstants.customPaletteCategoryLocation(
          'foundation',
        ),
      );
      expect(find.text('Your scan is not ready'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    });
  });

  group('live adjustment preview', () {
    const blush = MakeupKitCategory.blush;
    final preview = find.byKey(CustomPaletteCategoryPage.livePreviewKey);

    /// Blush's adjusted color, as the draft (the one source of truth) holds it.
    NormalizedHexColor adjusted(_Harness harness) => harness.container
        .read(customPaletteDraftControllerProvider)
        .selectionFor(blush)
        .adjustedColor!;

    /// The preview's swatch color and text must both show [color].
    void expectPreviewShows(
      WidgetTester tester,
      NormalizedHexColor color,
      String name,
    ) {
      expect(
        find.descendant(
          of: preview,
          matching: find.text('$name (${color.value})'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<AppColorSwatch>(
              find.descendant(
                of: preview,
                matching: find.byType(AppColorSwatch),
              ),
            )
            .color,
        color.toColor(),
      );
    }

    Future<_Harness> openRed(WidgetTester tester) async {
      final harness = await _pump(tester);
      await _enterPalette(tester);
      await _tapText(tester, 'Choose Blush');
      await _tapText(tester, 'Red');
      return harness;
    }

    Finder slider(String label) => find.byWidgetPredicate(
      (widget) =>
          widget is Slider &&
          widget.semanticFormatterCallback!(0).startsWith('$label, '),
    );

    testWidgets('sits between the swatches and the sliders, in owner order', (
      tester,
    ) async {
      await openRed(tester);
      double top(Finder finder) => tester.getRect(finder).top;
      double bottom(Finder finder) => tester.getRect(finder).bottom;

      // Title -> swatches -> preview -> Saturation -> Lightness -> Reset ->
      // Finish -> Done.
      final lastSwatch = find.text(CustomPaletteCatalog.swatches.last.label);
      expect(bottom(find.text('Color')), lessThan(top(lastSwatch)));
      expect(bottom(lastSwatch), lessThan(top(preview)));
      expect(bottom(preview), lessThan(top(find.text('Saturation'))));
      expect(
        bottom(find.text('Saturation')),
        lessThan(top(find.text('Lightness'))),
      );
      expect(bottom(find.text('Lightness')), lessThan(top(find.text('Reset'))));
      expect(bottom(find.text('Reset')), lessThan(top(find.text('Finish'))));
      expect(bottom(find.text('Matte')), lessThan(top(find.text('Done'))));
    });

    testWidgets('there is exactly one preview, before and after a choice', (
      tester,
    ) async {
      await _pump(tester);
      await _enterPalette(tester);
      await _tapText(tester, 'Choose Blush');
      expect(preview, findsOneWidget);
      expect(find.text('No color chosen'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);

      await _tapText(tester, 'Red');
      expect(preview, findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CustomPaletteCategoryPage),
          matching: find.byType(CustomPaletteSelectionSummary),
        ),
        findsOneWidget,
      );
    });

    testWidgets('every saturation step updates the swatch and HEX at once', (
      tester,
    ) async {
      final harness = await openRed(tester);
      expectPreviewShows(tester, adjusted(harness), 'Red');
      final seen = <String>{adjusted(harness).value};
      for (final value in [90, 60, 30]) {
        tester.widget<Slider>(slider('Saturation')).onChanged!(
          value.toDouble(),
        );
        // One frame, no settling: the preview must already be current.
        await tester.pump();
        expect(find.text('$value%'), findsOneWidget);
        expectPreviewShows(tester, adjusted(harness), 'Red, adjusted');
        expect(seen.add(adjusted(harness).value), isTrue);
      }
    });

    testWidgets('every lightness step updates the swatch and HEX at once', (
      tester,
    ) async {
      final harness = await openRed(tester);
      final seen = <String>{adjusted(harness).value};
      for (final value in [70, 20, 55]) {
        tester.widget<Slider>(slider('Lightness')).onChanged!(value.toDouble());
        await tester.pump();
        expect(find.text('$value%'), findsOneWidget);
        expectPreviewShows(tester, adjusted(harness), 'Red, adjusted');
        expect(seen.add(adjusted(harness).value), isTrue);
      }
    });

    testWidgets('the preview follows a real drag before the finger lifts', (
      tester,
    ) async {
      final harness = await openRed(tester);
      final lightness = slider('Lightness');
      final rect = tester.getRect(lightness);
      final gesture = await tester.startGesture(
        rect.centerLeft + const Offset(40, 0),
      );
      await tester.pump();
      final base = adjusted(harness).value;

      // Two moves while the finger is still down: each one must already be
      // in the preview, in a single frame, with no settling.
      await gesture.moveBy(Offset(rect.width / 4, 0));
      await tester.pump();
      final first = adjusted(harness).value;
      expect(first, isNot(base));
      expectPreviewShows(tester, adjusted(harness), 'Red, adjusted');

      await gesture.moveBy(Offset(rect.width / 4, 0));
      await tester.pump();
      final second = adjusted(harness).value;
      expect(second, isNot(first));
      expectPreviewShows(tester, adjusted(harness), 'Red, adjusted');

      await gesture.up();
      await tester.pumpAndSettle();
      expect(adjusted(harness).value, second);
      expect(preview, findsOneWidget);
    });

    testWidgets('Reset returns the preview and sliders to the base color', (
      tester,
    ) async {
      final harness = await openRed(tester);
      final baseLightness = tester.widget<Slider>(slider('Lightness')).value;
      tester.widget<Slider>(slider('Lightness')).onChanged!(80);
      tester.widget<Slider>(slider('Saturation')).onChanged!(40);
      await tester.pump();
      expectPreviewShows(tester, adjusted(harness), 'Red, adjusted');

      await _tapText(tester, 'Reset');
      expect(adjusted(harness).value, '#C8102E');
      expectPreviewShows(tester, adjusted(harness), 'Red');
      expect(tester.widget<Slider>(slider('Lightness')).value, baseLightness);
    });

    testWidgets('a new swatch moves the preview and the slider baseline', (
      tester,
    ) async {
      final harness = await openRed(tester);
      tester.widget<Slider>(slider('Lightness')).onChanged!(80);
      await tester.pump();

      await _tapText(tester, 'Blue');
      expect(adjusted(harness).value, '#1F6FD6');
      expectPreviewShows(tester, adjusted(harness), 'Blue');
      final hsl = CustomPaletteColorModel.toHsl(
        CustomPaletteCatalog.swatchFor(blush, '#1F6FD6')!.color,
      );
      expect(
        tester.widget<Slider>(slider('Lightness')).value,
        hsl.lightness.toDouble(),
      );
      expect(
        tester.widget<Slider>(slider('Saturation')).value,
        hsl.saturation.toDouble(),
      );
    });

    testWidgets('finish shows in the preview; Done keeps every choice', (
      tester,
    ) async {
      final harness = await openRed(tester);
      tester.widget<Slider>(slider('Lightness')).onChanged!(70);
      await tester.pump();
      await _tapText(tester, 'Satin');
      expect(
        find.descendant(of: preview, matching: find.text('Satin finish')),
        findsOneWidget,
      );
      final chosen = adjusted(harness).value;

      await _tapText(tester, 'Done');
      expect(find.byType(CustomPaletteCategoryPage), findsNothing);
      expect(find.text('Red, adjusted ($chosen)'), findsOneWidget);
      expect(find.text('Satin finish'), findsOneWidget);

      await _tapText(tester, 'Edit Blush');
      expect(
        find.descendant(
          of: preview,
          matching: find.text('Red, adjusted ($chosen)'),
        ),
        findsOneWidget,
      );
      expect(tester.widget<Slider>(slider('Lightness')).value, 70);
    });

    /// Opens Blush on a [size] screen at [scale] text, chooses Red, and scrolls
    /// the way a user would: until the preview sits at the top of the screen.
    Future<_Harness> openRedOn(
      WidgetTester tester,
      Size size,
      double scale,
    ) async {
      final harness = await _pump(tester, size: size, textScale: scale);
      await _enterPaletteScrolled(tester);
      GoRouter.of(
        tester.element(find.byType(CustomPalettePage)),
      ).push(AppConstants.customPaletteCategoryLocation('blush'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Red'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await _tapText(tester, 'Red');
      await tester.scrollUntilVisible(
        preview,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(preview);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      return harness;
    }

    bool onScreen(WidgetTester tester, Finder finder) {
      final viewport = tester.getRect(find.byType(Scrollable).first);
      final rect = tester.getRect(finder);
      return rect.top >= viewport.top && rect.bottom <= viewport.bottom;
    }

    testWidgets('dragging does not move the page', (tester) async {
      final harness = await openRedOn(tester, const Size(360, 640), 1.3);
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final before = position.pixels;

      final rect = tester.getRect(slider('Lightness'));
      final gesture = await tester.startGesture(rect.center);
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
      expect(position.pixels, before);
      await gesture.moveBy(const Offset(-90, 0));
      await tester.pump();
      expect(position.pixels, before);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(position.pixels, before);
      expect(preview, findsOneWidget);
      expect(onScreen(tester, preview), isTrue);
      expectPreviewShows(tester, adjusted(harness), 'Red, adjusted');
    });

    for (final (name, size, scale) in [
      ('compact phone at 1.3x text', const Size(360, 640), 1.3),
      ('narrow phone', const Size(320, 640), 1.0),
      ('phone', const Size(393, 851), 1.0),
      ('phone at 1.5x text', const Size(393, 851), 1.5),
    ]) {
      testWidgets('preview and both sliders fit on screen together: $name', (
        tester,
      ) async {
        await openRedOn(tester, size, scale);
        for (final finder in [
          preview,
          slider('Saturation'),
          slider('Lightness'),
        ]) {
          expect(onScreen(tester, finder), isTrue, reason: '$finder');
        }
      });
    }

    for (final (name, size) in [
      ('phone', const Size(393, 851)),
      ('narrow phone', const Size(320, 640)),
    ]) {
      testWidgets('2x text keeps order and stays live: $name', (tester) async {
        final harness = await openRedOn(tester, size, 2);
        // With the preview at the top, the Saturation slider directly below it
        // is on screen too. The test font is larger than the app's, so at 2x on
        // the shortest screen Lightness may sit just below the fold here;
        // ordinary scrolling, not an overlay, brings it up.
        expect(onScreen(tester, preview), isTrue);
        expect(onScreen(tester, slider('Saturation')), isTrue);
        expect(
          tester.getRect(preview).bottom,
          lessThan(tester.getRect(find.text('Saturation')).top),
        );
        tester.widget<Slider>(slider('Saturation')).onChanged!(60);
        await tester.pump();
        expectPreviewShows(tester, adjusted(harness), 'Red, adjusted');

        await tester.scrollUntilVisible(
          slider('Lightness'),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(slider('Lightness'));
        await tester.pumpAndSettle();
        tester.widget<Slider>(slider('Lightness')).onChanged!(65);
        await tester.pump();
        expect(find.text('65%'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('preview speaks its values; controls are usable targets', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final harness = await openRed(tester);
      tester.widget<Slider>(slider('Lightness')).onChanged!(70);
      await tester.pump();
      final label = tester
          .getSemantics(
            find.descendant(of: preview, matching: find.byType(Row)).first,
          )
          .label;
      expect(label, contains('Your blush'));
      expect(label, contains(adjusted(harness).value));
      expect(label, contains('No finish chosen'));
      for (final finder in [slider('Saturation'), slider('Lightness')]) {
        expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
      }
      expect(
        tester.getSize(find.widgetWithText(TertiaryButton, 'Reset')).height,
        greaterThanOrEqualTo(48),
      );
      handle.dispose();
    });
  });

  group('back and edit', () {
    testWidgets('choices survive leaving the editor and returning', (
      tester,
    ) async {
      await _pump(tester);
      await _enterPalette(tester);
      await _chooseBlush(tester);
      expect(find.text('Red (#C8102E)'), findsOneWidget);
      expect(find.text('Matte finish'), findsOneWidget);

      await _tapText(tester, 'Edit Blush');
      expect(find.text('Red (#C8102E)'), findsOneWidget);
      expect(find.text('Matte finish'), findsOneWidget);
      await _tapText(tester, 'Done');

      await _tapText(tester, 'Review palette');
      GoRouter.of(tester.element(find.byType(CustomPaletteReviewPage))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Red (#C8102E)'), findsOneWidget);
      expect(_callback(tester, 'Review palette'), isNotNull);
    });

    testWidgets('choices survive going back to the mode page and returning', (
      tester,
    ) async {
      final harness = await _pump(tester);
      await _enterPalette(tester);
      await _chooseBlush(tester);
      GoRouter.of(tester.element(find.byType(CustomPalettePage))).pop();
      await tester.pumpAndSettle();
      await _enterPalette(tester);
      expect(find.text('Red (#C8102E)'), findsOneWidget);
      expect(harness.gateway.requests, isEmpty);
    });

    testWidgets('a lost analysis shows the existing not-ready state', (
      tester,
    ) async {
      await _pump(
        tester,
        withAnalysis: false,
        initialLocation: AppConstants.customPaletteRoute,
      );
      expect(find.text('Your scan is not ready'), findsOneWidget);
      await _tapText(tester, 'Choose a style');
      expect(find.text('Styles page'), findsOneWidget);
    });
  });

  group('review and generate', () {
    testWidgets('shows swatch text, value and finish, then sends the payload', (
      tester,
    ) async {
      final harness = await _pump(tester);
      await _enterPalette(tester);
      await _chooseBlush(tester);
      await _tapText(tester, 'Review palette');

      expect(find.text('Blush'), findsOneWidget);
      expect(find.text('Red (#C8102E)'), findsOneWidget);
      expect(find.text('Matte finish'), findsOneWidget);
      expect(find.textContaining('stay as you chose them'), findsOneWidget);

      await _tapText(tester, 'Generate my look');
      final json = harness.gateway.requests.single.toJson();
      expect(json['sourceMode'], 'custom_color_palette');
      expect(json['style'], 'soft_glam');
      expect(json['categorySelections'], [
        {
          'categoryCode': 'blush',
          'baseColorValue': '#C8102E',
          'adjustedColorValue': '#C8102E',
          'colorLabel': 'Red',
          'finishCode': 'matte',
        },
      ]);
    });

    testWidgets('generating opens the result with the frozen palette', (
      tester,
    ) async {
      final harness = await _pump(tester);
      await _enterPalette(tester);
      await _chooseBlush(tester);
      await _tapText(tester, 'Review palette');
      await tester.tap(find.text('Generate my look'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final result = find.byType(CustomPaletteResultPage);
      expect(result, findsOneWidget);
      Finder onResult(String text) =>
          find.descendant(of: result, matching: find.text(text));
      expect(onResult('Your palette'), findsOneWidget);
      expect(onResult('Red (#C8102E)'), findsOneWidget);
      expect(onResult('Matte finish'), findsOneWidget);
      expect(harness.gateway.operations, hasLength(1));
      expect(harness.gateway.previewRecommendations, ['palette-1']);
    });

    testWidgets('an invalid draft cannot generate', (tester) async {
      final harness = await _pump(tester);
      await _enterPalette(tester);
      await tester.tap(await _includeSwitch(tester, 'Blush'));
      await tester.pumpAndSettle();
      GoRouter.of(
        tester.element(find.byType(CustomPalettePage)),
      ).push(AppConstants.customPaletteReviewRoute);
      await tester.pumpAndSettle();
      expect(_callback(tester, 'Generate my look'), isNull);
      expect(harness.gateway.requests, isEmpty);
    });

    testWidgets('a failure is shown and can be retried', (tester) async {
      final harness = await _pump(tester);
      harness.gateway.error = const CustomPaletteFailure(
        'Try again soon.',
        retryable: true,
      );
      await _enterPalette(tester);
      await _chooseBlush(tester);
      await _tapText(tester, 'Review palette');
      await _tapText(tester, 'Generate my look');
      expect(find.text('Try again soon.'), findsOneWidget);
      expect(_callback(tester, 'Generate my look'), isNotNull);

      harness.gateway.error = null;
      await tester.tap(find.text('Generate my look'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(harness.gateway.requests, hasLength(2));
      expect(
        harness.gateway.requests.first.paletteRequestId,
        harness.gateway.requests.last.paletteRequestId,
      );
      expect(find.text('Try again soon.'), findsNothing);
    });
  });

  test('the default gateway refuses rather than pretending to generate', () {
    expect(
      () => const UnavailableCustomPaletteGateway().submit(
        const CustomPaletteRequest(
          paletteRequestId: 'r',
          analysisId: 'a',
          styleCode: 's',
          selections: [],
        ),
      ),
      throwsA(isA<CustomPaletteFailure>()),
    );
  });

  group('accessibility and layout', () {
    testWidgets('swatches speak their name and selected state', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      await _enterPalette(tester);
      await _tapText(tester, 'Choose Blush');
      await _tapText(tester, 'Red');
      expect(
        tester.getSemantics(find.bySemanticsLabel('Red')),
        containsSemantics(label: 'Red', isSelected: true, isButton: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Blue')),
        containsSemantics(label: 'Blue', isSelected: false, isButton: true),
      );
      expect(find.byIcon(Icons.check_rounded), findsWidgets);
      handle.dispose();
    });

    testWidgets('sliders announce name and value', (tester) async {
      await _pump(tester);
      await _enterPalette(tester);
      await _tapText(tester, 'Choose Blush');
      await _tapText(tester, 'Red');
      final slider = tester.widget<Slider>(find.byType(Slider).last);
      expect(slider.semanticFormatterCallback!(0), startsWith('Lightness, '));
      expect(slider.semanticFormatterCallback!(0), endsWith(' percent'));
    });

    for (final (name, size, scale) in [
      ('phone', const Size(393, 851), 1.0),
      ('narrow phone', const Size(320, 640), 1.0),
      ('large text', const Size(393, 851), 2.0),
      ('narrow phone at large text', const Size(320, 640), 2.0),
    ]) {
      testWidgets('no overflow on $name', (tester) async {
        await _pump(tester, size: size, textScale: scale);
        expect(tester.takeException(), isNull);

        await tester.scrollUntilVisible(
          find.text('Use Custom Color Palette'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('Use Custom Color Palette'));
        await tester.pumpAndSettle();
        await _enterPalette(tester);
        expect(tester.takeException(), isNull);

        GoRouter.of(
          tester.element(find.byType(CustomPalettePage)),
        ).push(AppConstants.customPaletteCategoryLocation('eyeshadow'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.text('Black'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Black'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        GoRouter.of(
          tester.element(find.byType(CustomPaletteCategoryPage)),
        ).push(AppConstants.customPaletteReviewRoute);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  test('no Booking or provider scope, and no direct AI or database access', () {
    final sources = Directory('lib/features/custom_palette/presentation')
        .listSync(recursive: true)
        .whereType<File>()
        .followedBy(
          Directory(
            'lib/features/custom_palette/domain',
          ).listSync(recursive: true).whereType<File>(),
        )
        .where((file) => file.path.endsWith('.dart'));
    expect(sources, isNotEmpty);
    for (final file in sources) {
      final source = file.readAsStringSync().toLowerCase();
      for (final forbidden in [
        'booking',
        'salon',
        'provider_schedule',
        'gemini',
        'supabase',
        'generativelanguage',
        'service_role',
      ]) {
        expect(
          source,
          isNot(contains(forbidden)),
          reason: '${file.path}: $forbidden',
        );
      }
    }
  });
}
