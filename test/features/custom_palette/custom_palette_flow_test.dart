import 'dart:io';

import 'package:facetune/core/constants/app_constants.dart';
import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/analysis/presentation/controllers/face_analysis_controller.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/custom_palette/data/custom_palette_providers.dart';
import 'package:facetune/features/custom_palette/domain/catalog/custom_palette_catalog.dart';
import 'package:facetune/features/custom_palette/domain/repositories/custom_palette_gateway.dart';
import 'package:facetune/features/custom_palette/domain/validation/custom_palette_contract.dart';
import 'package:facetune/features/custom_palette/presentation/pages/custom_palette_category_page.dart';
import 'package:facetune/features/custom_palette/presentation/pages/custom_palette_page.dart';
import 'package:facetune/features/custom_palette/presentation/pages/custom_palette_review_page.dart';
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
import '../../helpers/fake_auth_repository.dart';

class _FakeGateway implements CustomPaletteGateway {
  final requests = <CustomPaletteRequest>[];
  Object? error;

  @override
  Future<void> submit(CustomPaletteRequest request) async {
    requests.add(request);
    final failure = error;
    if (failure != null) throw failure;
  }
}

class _Harness {
  _Harness(this.container, this.gateway);

  final ProviderContainer container;
  final _FakeGateway gateway;
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
  final gateway = _FakeGateway();
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

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
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
        isNull,
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
    testWidgets('shows exactly the approved categories', (tester) async {
      await _pump(tester);
      await _enterPalette(tester);
      for (final label in ['Blush', 'Eyeshadow', 'Eyeliner', 'Lipstick']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      for (final label in [
        'Foundation',
        'Concealer',
        'Highlighter',
        'Contour/Bronzer',
        'Eyebrow',
        'Lip Gloss',
      ]) {
        expect(find.text(label), findsNothing, reason: label);
      }
    });

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

      await tester.tap(find.byType(Switch).first);
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
      await tester.tap(find.byType(Switch).first);
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
      expect(_callback(tester, 'Generate my look'), isNull);
    });

    testWidgets('an invalid draft cannot generate', (tester) async {
      final harness = await _pump(tester);
      await _enterPalette(tester);
      await tester.tap(find.byType(Switch).first);
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
      await _tapText(tester, 'Generate my look');
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
    final sources = Directory('lib/features/custom_palette')
        .listSync(recursive: true)
        .whereType<File>()
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
