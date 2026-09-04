import 'package:facetune/core/constants/app_constants.dart';
import 'package:facetune/features/analysis/domain/entities/face_analysis.dart';
import 'package:facetune/features/makeup_styles/domain/entities/makeup_style.dart';
import 'package:facetune/features/preview/domain/entities/generated_preview.dart';
import 'package:facetune/features/preview/domain/repositories/makeup_preview_repository.dart';
import 'package:facetune/features/preview/domain/usecases/generate_makeup_preview.dart';
import 'package:facetune/features/preview/presentation/controllers/makeup_preview_controller.dart';
import 'package:facetune/features/recommendation/data/models/makeup_recommendation_dto.dart';
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/recommendation/domain/repositories/makeup_recommendation_repository.dart';
import 'package:facetune/features/recommendation/domain/usecases/generate_makeup_recommendation.dart';
import 'package:facetune/features/recommendation/presentation/controllers/makeup_recommendation_controller.dart';
import 'package:facetune/features/recommendation/presentation/pages/makeup_recommendation_page.dart';
import 'package:facetune/features/recommendation/presentation/widgets/recommendation_item_card.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:facetune/theme/app_tokens.dart';
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

class _CountingRecommendations implements MakeupRecommendationRepository {
  int generateCalls = 0;

  @override
  Future<MakeupRecommendation> generate({
    required FaceAnalysis analysis,
    required MakeupStyle style,
  }) {
    generateCalls += 1;
    throw StateError('The restored palette must not request a recommendation.');
  }
}

class _Harness {
  const _Harness({
    required this.previews,
    required this.recommendations,
    required this.controller,
    required this.themeMode,
  });

  final _CountingPreviews previews;
  final _CountingRecommendations recommendations;
  final MakeupRecommendationController controller;
  final ValueNotifier<ThemeMode> themeMode;
}

Future<_Harness> _pumpPalette(
  WidgetTester tester, {
  Map<String, Object?> response = educatedRecommendationResponse,
  ThemeMode themeMode = ThemeMode.light,
  Brightness platformBrightness = Brightness.light,
  Size size = const Size(393, 873),
  double textScale = 1,
  MakeupRecommendation? recommendation,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.platformBrightnessTestValue = platformBrightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  final effectiveRecommendation =
      recommendation ??
      MakeupRecommendationDto.fromResponse(response).recommendation;
  final recommendations = _CountingRecommendations();
  final recommendationController = MakeupRecommendationController(
    GenerateMakeupRecommendation(recommendations),
  )..restore(effectiveRecommendation);
  final previews = _CountingPreviews();
  final previewController = MakeupPreviewController(
    GenerateMakeupPreview(previews),
  );
  final activeThemeMode = ValueNotifier(themeMode);
  addTearDown(activeThemeMode.dispose);

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
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: activeThemeMode,
          builder: (context, mode, _) => MaterialApp.router(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: mode,
            routerConfig: router,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(
    previews: previews,
    recommendations: recommendations,
    controller: recommendationController,
    themeMode: activeThemeMode,
  );
}

MakeupRecommendation _withItemCount(
  MakeupRecommendation recommendation,
  int count,
) => MakeupRecommendation(
  id: recommendation.id,
  analysisId: recommendation.analysisId,
  styleCode: recommendation.styleCode,
  overallIntensity: recommendation.overallIntensity,
  items: Map<String, MakeupRecommendationItem>.fromEntries(
    recommendation.items.entries.take(count),
  ),
  modelId: recommendation.modelId,
  promptVersion: recommendation.promptVersion,
  createdAt: recommendation.createdAt,
);

MakeupRecommendation _withLongFoundation(MakeupRecommendation recommendation) {
  final source = recommendation.items['foundation']!;
  final items = Map<String, MakeupRecommendationItem>.from(
    recommendation.items,
  );
  items['foundation'] = MakeupRecommendationItem(
    name: 'Layered warm amber medium tint with softly balanced golden tones',
    hex: source.hex,
    placement: source.placement,
    technique: source.technique,
    finish: source.finish,
    intensity: source.intensity,
    reasoning: source.reasoning,
    education: const MakeupRecommendationEducation(
      features:
          'Your warm undertone and medium skin-tone depth guide this balanced '
          'amber direction while keeping the explanation grounded in the '
          'features supplied by your analysis.',
      effect:
          'The warm amber shade, satin finish, and soft intensity create gentle '
          'visual warmth and a restrained light-reflecting finish.',
      style:
          'This measured contrast supports the selected soft-glam style without '
          'pushing the palette beyond its medium overall intensity.',
    ),
  );
  return MakeupRecommendation(
    id: recommendation.id,
    analysisId: recommendation.analysisId,
    styleCode: recommendation.styleCode,
    overallIntensity: recommendation.overallIntensity,
    items: items,
    modelId: recommendation.modelId,
    promptVersion: recommendation.promptVersion,
    createdAt: recommendation.createdAt,
  );
}

/// Opens the disclosure on the card at [index].
///
/// Scrolls it into view first: the palette is a lazy `ListView`, so a card
/// below the fold is neither built nor tappable until it is reached.
Future<void> _expandCard(WidgetTester tester, {int index = 0}) async {
  final allDisclosures = find.text('Why this works for you');
  for (
    var attempt = 0;
    allDisclosures.evaluate().isEmpty && attempt < 12;
    attempt += 1
  ) {
    await tester.drag(find.byType(ListView), const Offset(0, -160));
    await tester.pumpAndSettle();
  }
  final disclosure = find.text('Why this works for you').at(index);
  await tester.ensureVisible(disclosure);
  await tester.pumpAndSettle();
  await tester.tap(disclosure);
  await tester.pumpAndSettle();
}

Future<void> _expandFirstCard(WidgetTester tester) => _expandCard(tester);

Future<void> _expandNamedCard(WidgetTester tester, String title) async {
  await tester.scrollUntilVisible(find.text(title), 200);
  final card = find.ancestor(
    of: find.text(title),
    matching: find.byType(RecommendationItemCard),
  );
  final disclosure = find.descendant(
    of: card,
    matching: find.text('Why this works for you'),
  );
  await tester.scrollUntilVisible(disclosure, 100);
  await tester.pumpAndSettle();
  await tester.tap(disclosure);
  await tester.pumpAndSettle();
}

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
  group('screen architecture', () {
    testWidgets('the FaceTune top bar stays outside the scrollable palette', (
      tester,
    ) async {
      await _pumpPalette(tester);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.appBar, isA<FaceTuneTopBar>());
      expect(find.byType(ListView), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(FaceTuneTopBar),
        ),
        findsNothing,
      );
    });

    testWidgets('the header leads with the style the user chose', (
      tester,
    ) async {
      await _pumpPalette(tester);

      // The style's catalog name, not a title-cased style code: the product
      // writes it "Soft Glam".
      expect(find.text('Soft Glam'), findsOneWidget);
      // Intensity is its own line of metadata, not half of a bullet sentence.
      expect(find.text('Soft intensity'), findsOneWidget);
      expect(find.text('Personalized for your features.'), findsOneWidget);

      // The heading that only repeated the top bar, and the two sentences that
      // explained an affordance every card already names.
      expect(find.text('Your personalized palette'), findsNothing);
      expect(find.text('Soft glam · soft intensity'), findsNothing);
      expect(
        find.text('Chosen for your features and selected look.'),
        findsNothing,
      );
      expect(
        find.text('Tap any recommendation to learn why it works for you.'),
        findsNothing,
      );
    });

    testWidgets('the style outranks its metadata, and the bar outranks both', (
      tester,
    ) async {
      await _pumpPalette(tester);
      final theme = Theme.of(tester.element(find.text('Soft Glam')));

      final style = tester.widget<Text>(find.text('Soft Glam')).style;
      final intensity = tester.widget<Text>(find.text('Soft intensity')).style;
      expect(style?.fontSize, theme.textTheme.headlineSmall?.fontSize);
      expect(intensity?.fontSize, lessThan(style!.fontSize!));

      // The page title stays the page title.
      expect(find.text('Your makeup plan'), findsOneWidget);
    });
  });

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
      expect(
        find.text('Adds balanced warmth to the complexion.'),
        findsNothing,
        reason: 'generic reasoning must not remain permanently expanded',
      );
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

    testWidgets('the global chevron changes from collapsed to expanded', (
      tester,
    ) async {
      await _pumpPalette(tester);
      final firstCard = find.byType(RecommendationItemCard).first;

      expect(
        find.descendant(
          of: firstCard,
          matching: find.byIcon(Icons.expand_more_rounded),
        ),
        findsOneWidget,
      );

      await _expandFirstCard(tester);

      expect(
        find.descendant(
          of: firstCard,
          matching: find.byIcon(Icons.expand_less_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: firstCard,
          matching: find.byIcon(Icons.expand_more_rounded),
        ),
        findsNothing,
      );
    });

    testWidgets('the disclosure row is one control at an accessible size', (
      tester,
    ) async {
      await _pumpPalette(tester);
      final row = find
          .ancestor(
            of: find.text('Why this works for you').first,
            matching: find.byType(InkWell),
          )
          .first;

      expect(tester.getSize(row).height, greaterThanOrEqualTo(44));

      // The chevron travels with the label rather than sitting in its own
      // detached target at the card's edge.
      final chevron = find.byIcon(Icons.expand_more_rounded).first;
      final rowRect = tester.getRect(row);
      final chevronRect = tester.getRect(chevron);
      expect(chevronRect.left, lessThanOrEqualTo(rowRect.right));
      expect(chevronRect.center.dy, closeTo(rowRect.center.dy, 2));
    });

    testWidgets('the disclosure is quieter than the category it explains', (
      tester,
    ) async {
      await _pumpPalette(tester);
      final category = tester.widget<Text>(find.text('Foundation')).style;
      final disclosure = tester
          .widget<Text>(find.text('Why this works for you').first)
          .style;

      expect(disclosure!.fontSize, lessThan(category!.fontSize!));
    });

    testWidgets('only one card is open at a time', (tester) async {
      final harness = await _pumpPalette(tester);
      // Several cards are built and all are collapsed before anything is
      // tapped. The palette is a lazy ListView, so "several" is what is on
      // screen rather than all ten categories.
      expect(find.byType(RecommendationItemCard), findsWidgets);
      expect(_builtDisclosures(tester), greaterThan(1));

      await _expandNamedCard(tester, 'Foundation');
      expect(find.text('Your features'), findsOneWidget);
      expect(find.text('The effect'), findsOneWidget);
      expect(find.text('The style'), findsOneWidget);

      // Opening a second card closes the first. The count is the proof: two
      // open cards would put two of each heading on the page, so exactly one
      // of each means exactly one card is expanded.
      await _expandNamedCard(tester, 'Concealer');
      expect(find.text('Your features'), findsOneWidget);
      expect(find.text('The effect'), findsOneWidget);
      expect(find.text('The style'), findsOneWidget);

      // And it is the card that was just opened.
      final concealerCard = find.ancestor(
        of: find.text('Concealer'),
        matching: find.byType(RecommendationItemCard),
      );
      expect(
        find.descendant(
          of: concealerCard,
          matching: find.text('Your features'),
        ),
        findsOneWidget,
      );

      // Switching focus is presentation only.
      expect(harness.recommendations.generateCalls, 0);
      expect(harness.previews.generateCalls, 0);
    });

    testWidgets('tapping the open card closes it', (tester) async {
      await _pumpPalette(tester);

      await _expandNamedCard(tester, 'Foundation');
      expect(find.text('Your features'), findsOneWidget);

      await _expandNamedCard(tester, 'Foundation');
      expect(find.text('Your features'), findsNothing);
    });

    testWidgets('a middle card expands cleanly on a narrow viewport', (
      tester,
    ) async {
      final harness = await _pumpPalette(tester, size: const Size(320, 900));

      await _expandNamedCard(tester, 'Blush');

      expect(find.text('Your features'), findsOneWidget);
      expect(find.text('The effect'), findsOneWidget);
      expect(find.text('The style'), findsOneWidget);
      expect(harness.recommendations.generateCalls, 0);
      expect(harness.previews.generateCalls, 0);
      expect(tester.takeException(), isNull);
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
      expect(harness.recommendations.generateCalls, 0);
      expect(
        harness.controller.state.recommendation,
        isNotNull,
        reason: 'the plan was restored, never re-requested',
      );
    });

    testWidgets('scroll, theme, and viewport rebuilds cost zero paid calls', (
      tester,
    ) async {
      final harness = await _pumpPalette(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      harness.themeMode.value = ThemeMode.dark;
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(873, 393);
      await tester.pumpAndSettle();

      expect(harness.recommendations.generateCalls, 0);
      expect(harness.previews.generateCalls, 0);
      expect(tester.takeException(), isNull);
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

      expect(find.text('Ready for your preview'), findsNothing);
      expect(
        find.textContaining('Identity preservation is prioritized'),
        findsNothing,
      );
      expect(find.text('Generate makeup preview'), findsOneWidget);
    });

    testWidgets('is visible and enabled without scrolling', (tester) async {
      await _pumpPalette(tester);

      final action = find.byKey(const ValueKey('palette-generate-preview'));
      expect(action, findsOneWidget);
      expect(action.hitTestable(), findsOneWidget);
      expect(tester.widget<PrimaryButton>(action).onPressed, isNotNull);
    });

    testWidgets('is unavailable when no valid palette exists', (tester) async {
      final harness = await _pumpPalette(tester);

      harness.controller.clear();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('palette-generate-preview')),
        findsNothing,
      );
      expect(harness.previews.generateCalls, 0);
      expect(harness.recommendations.generateCalls, 0);
    });

    testWidgets('stays fixed while the palette scrolls', (tester) async {
      final harness = await _pumpPalette(tester);
      final action = find.byKey(const ValueKey('palette-generate-preview'));
      final before = tester.getRect(action);

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(tester.getRect(action), before);
      expect(action.hitTestable(), findsOneWidget);
      expect(harness.previews.generateCalls, 0);
      expect(harness.recommendations.generateCalls, 0);
    });

    testWidgets('reserves layout space above the action and SafeArea', (
      tester,
    ) async {
      await _pumpPalette(tester);

      final action = find.byKey(const ValueKey('palette-generate-preview'));
      final list = find.byType(ListView);
      expect(
        tester.getRect(list).bottom,
        lessThanOrEqualTo(tester.getRect(action).top),
      );
      final safeArea = find.ancestor(
        of: action,
        matching: find.byType(SafeArea),
      );
      expect(safeArea, findsOneWidget);
      expect(tester.widget<SafeArea>(safeArea).top, isFalse);
    });

    testWidgets('the final card can be fully viewed above the action', (
      tester,
    ) async {
      await _pumpPalette(tester);
      await tester.scrollUntilVisible(find.text('Lip gloss'), 400);
      final finalCard = find.ancestor(
        of: find.text('Lip gloss'),
        matching: find.byType(RecommendationItemCard),
      );
      await tester.ensureVisible(finalCard);
      await tester.pumpAndSettle();

      final action = find.byKey(const ValueKey('palette-generate-preview'));
      expect(
        tester.getRect(finalCard).bottom,
        lessThanOrEqualTo(tester.getRect(action).top),
      );
      expect(action.hitTestable(), findsOneWidget);
    });

    testWidgets('remains accessible when the final card is expanded', (
      tester,
    ) async {
      final harness = await _pumpPalette(tester);
      await tester.scrollUntilVisible(find.text('Lip gloss'), 400);
      final finalCard = find.ancestor(
        of: find.text('Lip gloss'),
        matching: find.byType(RecommendationItemCard),
      );
      final disclosure = find.descendant(
        of: finalCard,
        matching: find.text('Why this works for you'),
      );
      await tester.ensureVisible(disclosure);
      // Settle the scroll before tapping. Without it the tap offset is computed
      // mid-animation and can land on whatever is under the finger instead.
      await tester.pumpAndSettle();
      await tester.tap(disclosure);
      await tester.pumpAndSettle();

      final action = find.byKey(const ValueKey('palette-generate-preview'));
      expect(action.hitTestable(), findsOneWidget);
      expect(harness.recommendations.generateCalls, 0);
      expect(harness.previews.generateCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('remains outside the scroll content', (tester) async {
      await _pumpPalette(tester);

      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byKey(const ValueKey('palette-generate-preview')),
        ),
        findsNothing,
      );
    });

    testWidgets('the generation callback is unchanged', (tester) async {
      final harness = await _pumpPalette(tester);

      await tester.tap(find.text('Generate makeup preview'));
      await tester.pump();

      // Same two effects as before LSEP-2: exactly one generation is started
      // for the restored recommendation, and the preview route is pushed.
      expect(harness.previews.generateCalls, 1);
      expect(harness.recommendations.generateCalls, 0);
      await tester.pumpAndSettle();
      expect(find.text('Preview route'), findsOneWidget);
    });
  });

  group('grounding', () {
    testWidgets('renders only the authoritative education strings', (
      tester,
    ) async {
      await _pumpPalette(tester);
      await _expandFirstCard(tester);

      for (final value in validRecommendationEducation.values) {
        expect(find.text(value! as String), findsOneWidget);
      }
      for (final unsupported in <String>[
        'dark circles',
        'hydrates lips',
        'acne',
        'wrinkles',
        'lip asymmetry',
      ]) {
        expect(find.textContaining(unsupported), findsNothing);
      }
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
          final harness = await _pumpPalette(
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
          expect(harness.recommendations.generateCalls, 0);
          expect(harness.previews.generateCalls, 0);
        }
      }
    });

    testWidgets('long education wraps at 2x text on a narrow screen', (
      tester,
    ) async {
      final base = MakeupRecommendationDto.fromResponse(
        educatedRecommendationResponse,
      ).recommendation;
      final harness = await _pumpPalette(
        tester,
        size: const Size(320, 900),
        textScale: 2,
        recommendation: _withLongFoundation(base),
      );
      await _expandFirstCard(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Your features'), findsOneWidget);

      // Wrapped rather than clipped: the rendered body is taller than one line
      // and stays inside the viewport width.
      final body = tester.getRect(
        find.textContaining('Your warm undertone and medium skin-tone depth'),
      );
      expect(body.width, lessThanOrEqualTo(320));
      expect(
        body.height,
        greaterThan(40),
        reason: 'a 2x explanation must occupy several lines, not be truncated',
      );
      expect(harness.recommendations.generateCalls, 0);
      expect(harness.previews.generateCalls, 0);
    });

    testWidgets('supports five and nine recommendation palettes', (
      tester,
    ) async {
      final base = MakeupRecommendationDto.fromResponse(
        educatedRecommendationResponse,
      ).recommendation;

      for (final count in <int>[5, 9]) {
        await _pumpPalette(tester, recommendation: _withItemCount(base, count));
        expect(find.byType(ListView), findsOneWidget);
        expect(
          find.byKey(const ValueKey('palette-generate-preview')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: '$count items');
      }
    });
  });

  group('the card reads as one hierarchy', () {
    testWidgets('every rung is quieter than the one above it', (tester) async {
      await _pumpPalette(tester);
      await _expandNamedCard(tester, 'Foundation');

      final card = find.ancestor(
        of: find.text('Foundation').first,
        matching: find.byType(RecommendationItemCard),
      );
      double sizeOf(Finder finder) =>
          tester.widget<Text>(finder).style!.fontSize!;
      Finder inCard(Finder matching) =>
          find.descendant(of: card, matching: matching).first;

      final category = sizeOf(inCard(find.text('Foundation')));
      final shade = sizeOf(inCard(find.text('Warm peach')));
      final finish = sizeOf(inCard(find.text('Satin')));
      final intensity = sizeOf(inCard(find.text('Soft')));
      final disclosure = sizeOf(inCard(find.text('Why this works for you')));
      final sectionHeading = sizeOf(inCard(find.text('Your features')));
      final educationBody = sizeOf(
        inCard(find.text(validRecommendationEducation['features']! as String)),
      );

      // Category and shade share a size; the category carries the extra weight,
      // which is what keeps it the strongest thing on the card without making
      // the recommendation itself smaller.
      expect(shade, category);
      expect(
        tester.widget<Text>(inCard(find.text('Foundation'))).style!.fontWeight,
        FontWeight.w600,
      );

      // Everything that qualifies the recommendation sits below it.
      expect(finish, lessThan(shade));
      expect(intensity, lessThan(shade));
      expect(disclosure, lessThan(category));

      // And inside the explanation, the heading still outranks its own body —
      // previously they were the same size and differed only in weight.
      expect(educationBody, lessThan(sectionHeading));
      expect(sectionHeading, lessThan(category));
    });

    testWidgets('the intensity accent stays legible on the dark card', (
      tester,
    ) async {
      // `AppColors.rose` is tuned for light surfaces and falls under AA on the
      // dark card. Now that intensity is the smallest label on the card, it is
      // the last place that can afford an unresolved accent.
      await _pumpPalette(
        tester,
        themeMode: ThemeMode.dark,
        platformBrightness: Brightness.dark,
      );

      final intensity = tester.widget<Text>(find.text('Soft').first).style;
      expect(intensity?.color, AppColors.roseLight);
      expect(intensity?.color, isNot(AppColors.rose));
    });

    testWidgets('a long shade name wraps instead of being cut off', (
      tester,
    ) async {
      final base = MakeupRecommendationDto.fromResponse(
        educatedRecommendationResponse,
      ).recommendation;
      await _pumpPalette(
        tester,
        size: const Size(320, 900),
        recommendation: _withLongFoundation(base),
      );

      const longName =
          'Layered warm amber medium tint with softly balanced golden tones';
      final shade = tester.widget<Text>(find.text(longName));
      // No cap and no ellipsis: the whole recommendation is the point of the
      // card, and truncating it would hide which shade was actually chosen.
      expect(shade.maxLines, isNull);
      expect(shade.overflow, isNot(TextOverflow.ellipsis));

      final rect = tester.getRect(find.text(longName));
      expect(rect.width, lessThanOrEqualTo(320));
      expect(
        rect.height,
        greaterThan(shade.style!.fontSize!),
        reason: 'a name this long must occupy more than one line',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('nothing opens on its own', () {
    testWidgets('a fresh route entry expands no card at all', (tester) async {
      await _pumpPalette(tester);

      // Cards exist and every one of them is shut. Not "the first is open" and
      // not "the last selection was restored" — the screen opens quiet.
      expect(find.byType(RecommendationItemCard), findsWidgets);
      expect(_builtDisclosures(tester), greaterThan(1));
      expect(find.text('Your features'), findsNothing);
      expect(find.text('The effect'), findsNothing);
      expect(find.text('The style'), findsNothing);

      // Every built chevron points down.
      expect(
        find.byIcon(Icons.expand_less_rounded),
        findsNothing,
        reason: 'an up chevron would mean something was expanded',
      );
      expect(find.byIcon(Icons.expand_more_rounded), findsWidgets);
    });

    testWidgets('Foundation gets no head start over any other category', (
      tester,
    ) async {
      await _pumpPalette(tester);

      final foundation = find.ancestor(
        of: find.text('Foundation'),
        matching: find.byType(RecommendationItemCard),
      );
      expect(
        find.descendant(of: foundation, matching: find.text('Your features')),
        findsNothing,
      );
      // The first card is exactly as tall as the second, which it could not be
      // if it were carrying three open explanations.
      final cards = find.byType(RecommendationItemCard);
      expect(
        tester.getSize(cards.at(0)).height,
        tester.getSize(cards.at(1)).height,
      );
    });

    testWidgets('a text-scale rebuild opens nothing and costs nothing', (
      tester,
    ) async {
      final harness = await _pumpPalette(tester, textScale: 2);

      expect(find.text('Your features'), findsNothing);
      expect(harness.recommendations.generateCalls, 0);
      expect(harness.previews.generateCalls, 0);
      expect(tester.takeException(), isNull);
    });
  });
}
