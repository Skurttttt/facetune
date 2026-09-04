import 'package:facetune/core/constants/app_constants.dart';
import 'package:facetune/features/preview/domain/entities/generated_preview.dart';
import 'package:facetune/features/preview/domain/repositories/makeup_preview_repository.dart';
import 'package:facetune/features/preview/domain/usecases/generate_makeup_preview.dart';
import 'package:facetune/features/preview/presentation/controllers/makeup_preview_controller.dart';
import 'package:facetune/features/recommendation/data/models/makeup_recommendation_dto.dart';
import 'package:facetune/features/recommendation/data/repositories/unavailable_makeup_recommendation_repository.dart';
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/recommendation/domain/usecases/generate_makeup_recommendation.dart';
import 'package:facetune/features/recommendation/presentation/controllers/makeup_recommendation_controller.dart';
import 'package:facetune/features/recommendation/presentation/pages/makeup_recommendation_page.dart';
import 'package:facetune/features/recommendation/presentation/widgets/recommendation_item_card.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/recommendation_response_fixture.dart';

/// Counts every preview generation the page causes.
///
/// The instrument for the cost contract: expanding and collapsing a palette
/// card must leave this at zero, and only the CTA may move it.
class _CountingPreviews implements MakeupPreviewRepository {
  int generateCalls = 0;

  @override
  Future<GeneratedPreview> generate({
    required MakeupRecommendation recommendation,
  }) async {
    generateCalls += 1;
    throw StateError('unreachable in these tests');
  }
}

class _Harness {
  const _Harness({required this.previews, required this.controller});

  final _CountingPreviews previews;
  final MakeupRecommendationController controller;
}

Future<_Harness> _pumpPalette(
  WidgetTester tester, {
  Map<String, Object?> response = educatedRecommendationResponse,
  ThemeMode themeMode = ThemeMode.light,
  Brightness platformBrightness = Brightness.light,
  Size size = const Size(393, 873),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.platformBrightnessTestValue = platformBrightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  final recommendation = MakeupRecommendationDto.fromResponse(
    response,
  ).recommendation;
  final recommendationController = MakeupRecommendationController(
    const GenerateMakeupRecommendation(
      // Throws if consulted. The palette is handed an already-generated plan, so
      // any call here would be the paid-call regression these tests guard.
      UnavailableMakeupRecommendationRepository(),
    ),
  )..restore(recommendation);
  final previews = _CountingPreviews();
  final previewController = MakeupPreviewController(
    GenerateMakeupPreview(previews),
  );

  final router = GoRouter(
    initialLocation: AppConstants.recommendationRoute,
    routes: <RouteBase>[
      GoRoute(
        path: AppConstants.recommendationRoute,
        builder: (context, state) => const MakeupRecommendationPage(),
      ),
      GoRoute(
        path: AppConstants.previewRoute,
        builder: (context, state) =>
            const Scaffold(body: Text('Preview route')),
      ),
      GoRoute(
        path: AppConstants.stylesRoute,
        builder: (context, state) => const Scaffold(body: Text('Styles route')),
      ),
      GoRoute(
        path: AppConstants.analysisRoute,
        builder: (context, state) =>
            const Scaffold(body: Text('Analysis route')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        makeupRecommendationControllerProvider.overrideWith(
          (ref) => recommendationController,
        ),
        makeupPreviewControllerProvider.overrideWith(
          (ref) => previewController,
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(previews: previews, controller: recommendationController);
}

/// Opens the disclosure on the card at [index].
///
/// Scrolls it into view first: the palette is a lazy `ListView`, so a card
/// below the fold is neither built nor tappable until it is reached.
Future<void> _expandCard(WidgetTester tester, {int index = 0}) async {
  final disclosure = find.text('Why this works for you').at(index);
  await tester.ensureVisible(disclosure);
  await tester.pumpAndSettle();
  await tester.tap(disclosure);
  await tester.pumpAndSettle();
}

Future<void> _expandFirstCard(WidgetTester tester) => _expandCard(tester);

/// How many disclosures are currently built.
///
/// The palette lazily builds its cards, so the count is whatever is on screen
/// rather than the ten categories in the plan.
int _builtDisclosures(WidgetTester tester) =>
    tester.widgetList(find.text('Why this works for you')).length;

/// The semantics node carrying [label].
///
/// Located through the `Semantics` widget itself rather than
/// `find.bySemanticsLabel`, which matches a node's final merged label and so
/// misses a container whose label is combined with its children's.
Finder _semanticsLabelled(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);

void main() {
  group('the palette answers what and why, not how', () {
    testWidgets('placement is absent from the palette', (tester) async {
      await _pumpPalette(tester);

      expect(find.textContaining('Placement'), findsNothing);
      expect(find.textContaining('Upper cheekbones'), findsNothing);

      await _expandFirstCard(tester);

      // Still absent once the card is open: it was removed, not hidden behind
      // the disclosure.
      expect(find.textContaining('Placement'), findsNothing);
      expect(find.textContaining('Upper cheekbones'), findsNothing);
    });

    testWidgets('technique is absent from the palette', (tester) async {
      await _pumpPalette(tester);

      expect(find.textContaining('Technique'), findsNothing);
      expect(find.textContaining('Blend upward'), findsNothing);

      await _expandFirstCard(tester);

      expect(find.textContaining('Technique'), findsNothing);
      expect(find.textContaining('Blend upward'), findsNothing);
    });

    testWidgets('what was chosen is still shown', (tester) async {
      await _pumpPalette(tester);

      expect(find.text('Foundation'), findsOneWidget);
      expect(find.text('Warm peach'), findsWidgets);
      expect(find.text('Satin'), findsWidgets);
      expect(find.text('Soft'), findsWidgets);
    });
  });

  group('placement and technique survive in the system', () {
    testWidgets('the recommendation the page renders still carries them', (
      tester,
    ) async {
      final harness = await _pumpPalette(tester);
      final items = harness.controller.state.recommendation!.items;

      expect(items, isNotEmpty);
      for (final entry in items.entries) {
        expect(
          entry.value.placement,
          'Upper cheekbones',
          reason: '${entry.key} placement must survive the UI change',
        );
        expect(
          entry.value.technique,
          'Blend upward with a soft brush',
          reason: '${entry.key} technique must survive the UI change',
        );
      }
    });
  });

  group('progressive disclosure', () {
    testWidgets('every card is collapsed by default', (tester) async {
      await _pumpPalette(tester);

      expect(find.text('Why this works for you'), findsWidgets);
      expect(find.text('Your features'), findsNothing);
      expect(find.text('The effect'), findsNothing);
      expect(find.text('The style'), findsNothing);
    });

    testWidgets('expanding reveals the three grounded sections', (
      tester,
    ) async {
      await _pumpPalette(tester);
      await _expandFirstCard(tester);

      expect(find.text('Your features'), findsOneWidget);
      expect(find.text('The effect'), findsOneWidget);
      expect(find.text('The style'), findsOneWidget);
      expect(
        find.text(validRecommendationEducation['features']! as String),
        findsOneWidget,
      );
      expect(
        find.text(validRecommendationEducation['effect']! as String),
        findsOneWidget,
      );
      expect(
        find.text(validRecommendationEducation['style']! as String),
        findsOneWidget,
      );
    });

    testWidgets('collapsing hides them again', (tester) async {
      await _pumpPalette(tester);
      await _expandFirstCard(tester);
      expect(find.text('Your features'), findsOneWidget);

      await _expandFirstCard(tester);
      expect(find.text('Your features'), findsNothing);
    });

    testWidgets('expansion state is announced to a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpPalette(tester);

      final disclosure = _semanticsLabelled(
        'Foundation, why this works for you',
      );
      expect(disclosure, findsOneWidget);
      expect(
        tester
            .getSemantics(disclosure)
            .flagsCollection
            .isExpanded
            .toBoolOrNull(),
        isFalse,
      );

      await _expandFirstCard(tester);

      expect(
        tester
            .getSemantics(disclosure)
            .flagsCollection
            .isExpanded
            .toBoolOrNull(),
        isTrue,
      );

      // Disposed inline rather than through addTearDown: the framework asserts
      // no handle is still active when the test body ends, and a teardown runs
      // after that check.
      handle.dispose();
    });

    testWidgets('one card opening does not open the others', (tester) async {
      await _pumpPalette(tester);
      // Several cards are built and all are collapsed before anything is
      // tapped. The palette is a lazy ListView, so "several" is what is on
      // screen rather than all ten categories.
      expect(find.byType(RecommendationItemCard), findsWidgets);
      expect(_builtDisclosures(tester), greaterThan(1));

      await _expandFirstCard(tester);

      expect(find.text('Your features'), findsOneWidget);
      expect(find.text('The effect'), findsOneWidget);
      expect(find.text('The style'), findsOneWidget);
    });
  });

  group('expansion is free', () {
    testWidgets('opening and closing every card costs zero paid calls', (
      tester,
    ) async {
      final harness = await _pumpPalette(tester);

      expect(_builtDisclosures(tester), greaterThan(1));

      // Toggle the first two cards open and shut, re-reading the count each
      // time: opening a card changes how many the lazy list keeps built, so a
      // cached index goes stale.
      for (final index in <int>[0, 1, 0, 1]) {
        if (index >= _builtDisclosures(tester)) continue;
        await _expandCard(tester, index: index);
      }

      expect(
        harness.previews.generateCalls,
        0,
        reason: 'disclosure must never reach the preview generator',
      );
      // The recommendation repository throws if consulted; reaching here proves
      // no recommendation call was issued either.
      expect(
        harness.controller.state.recommendation,
        isNotNull,
        reason: 'the plan was restored, never re-requested',
      );
    });
  });

  group('plans generated before education', () {
    testWidgets('render safely with no disclosure affordance', (tester) async {
      await _pumpPalette(tester, response: legacyRecommendationResponse);

      expect(find.byType(RecommendationItemCard), findsWidgets);
      expect(find.text('Why this works for you'), findsNothing);
      expect(find.text('Your features'), findsNothing);
      expect(find.text('The effect'), findsNothing);
      expect(find.text('The style'), findsNothing);
    });

    testWidgets('no fallback paragraph is invented', (tester) async {
      await _pumpPalette(tester, response: legacyRecommendationResponse);

      // The plan's own authored reasoning is shown, because it is real data for
      // this exact recommendation. Nothing else is.
      expect(
        find.text('Adds balanced warmth to the complexion.'),
        findsWidgets,
      );
      for (final invented in <String>[
        'Your features',
        'The effect',
        'The style',
        'No explanation',
        'not available',
        'Unavailable',
      ]) {
        expect(
          find.textContaining(invented),
          findsNothing,
          reason: 'the palette must not invent "$invented"',
        );
      }
    });

    testWidgets('placement and technique stay absent for legacy plans too', (
      tester,
    ) async {
      await _pumpPalette(tester, response: legacyRecommendationResponse);

      expect(find.textContaining('Placement'), findsNothing);
      expect(find.textContaining('Technique'), findsNothing);
    });
  });

  group('the preview CTA', () {
    testWidgets('the oversized ready-for-preview panel is gone', (
      tester,
    ) async {
      await _pumpPalette(tester);
      await tester.scrollUntilVisible(
        find.text('Generate makeup preview'),
        300,
      );

      expect(find.text('Ready for your preview'), findsNothing);
      expect(
        find.textContaining('Identity preservation is prioritized'),
        findsNothing,
      );
      expect(find.text('Generate makeup preview'), findsOneWidget);
    });

    testWidgets('the generation callback is unchanged', (tester) async {
      final harness = await _pumpPalette(tester);
      await tester.scrollUntilVisible(
        find.text('Generate makeup preview'),
        300,
      );

      await tester.tap(find.text('Generate makeup preview'));
      await tester.pump();

      // Same two effects as before LSEP-2: exactly one generation is started
      // for the restored recommendation, and the preview route is pushed.
      expect(harness.previews.generateCalls, 1);
      await tester.pumpAndSettle();
      expect(find.text('Preview route'), findsOneWidget);
    });
  });

  group('presentation holds up', () {
    testWidgets('renders in light, dark and system without overflow', (
      tester,
    ) async {
      for (final mode in <ThemeMode>[
        ThemeMode.light,
        ThemeMode.dark,
        ThemeMode.system,
      ]) {
        for (final brightness in <Brightness>[
          Brightness.light,
          Brightness.dark,
        ]) {
          await _pumpPalette(
            tester,
            themeMode: mode,
            platformBrightness: brightness,
          );
          await _expandFirstCard(tester);
          expect(
            tester.takeException(),
            isNull,
            reason: 'no overflow in $mode / $brightness',
          );
          expect(find.text('Your features'), findsOneWidget);
        }
      }
    });

    testWidgets('long education wraps at 2x text on a narrow screen', (
      tester,
    ) async {
      await _pumpPalette(tester, size: const Size(320, 900), textScale: 2);
      await _expandFirstCard(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Your features'), findsOneWidget);

      // Wrapped rather than clipped: the rendered body is taller than one line
      // and stays inside the viewport width.
      final body = tester.getRect(
        find.text(validRecommendationEducation['features']! as String),
      );
      expect(body.width, lessThanOrEqualTo(320));
      expect(
        body.height,
        greaterThan(40),
        reason: 'a 2x explanation must occupy several lines, not be truncated',
      );
    });
  });
}
