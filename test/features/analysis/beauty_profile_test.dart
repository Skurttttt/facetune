import 'dart:io';

import 'package:facetune/core/constants/app_constants.dart';
import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/analysis/domain/usecases/analyze_face.dart';
import 'package:facetune/features/analysis/data/repositories/unavailable_face_analysis_repository.dart';
import 'package:facetune/features/analysis/presentation/controllers/face_analysis_controller.dart';
import 'package:facetune/features/analysis/presentation/pages/analysis_result_page.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/analysis_response_fixture.dart';

/// Every attribute the profile is required to present, and the model's own
/// confidence in each, taken straight from the fixture.
const _expected = <String, ({String value, int percent})>{
  'Face shape': (value: 'Oval', percent: 91),
  'Skin tone': (value: 'Medium', percent: 88),
  'Undertone': (value: 'Warm', percent: 82),
  'Eye shape': (value: 'Almond', percent: 90),
  'Lip shape': (value: 'Full', percent: 87),
  'Hair color': (value: 'Dark Brown', percent: 94),
  'Eye color': (value: 'Brown', percent: 89),
};

Future<void> _pumpProfile(
  WidgetTester tester, {
  Size size = const Size(393, 1400),
  double devicePixelRatio = 1,
  double topInset = 0,
  double bottomInset = 0,
  double textScale = 1,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = devicePixelRatio;
  tester.view.padding = FakeViewPadding(top: topInset, bottom: bottomInset);
  tester.view.viewPadding = FakeViewPadding(top: topInset, bottom: bottomInset);
  addTearDown(tester.view.reset);

  final analysis = FaceAnalysisDto.fromResponse(validAnalysisResponse).analysis;
  final controller = FaceAnalysisController(
    const AnalyzeFace(UnavailableFaceAnalysisRepository()),
  )..restore(analysis);

  final router = GoRouter(
    initialLocation: AppConstants.analysisRoute,
    routes: <RouteBase>[
      GoRoute(
        path: AppConstants.analysisRoute,
        builder: (context, state) => const AnalysisResultPage(),
      ),
      GoRoute(
        path: AppConstants.stylesRoute,
        builder: (context, state) => const Scaffold(body: Text('Styles route')),
      ),
      GoRoute(
        path: AppConstants.scanRoute,
        builder: (context, state) => const Scaffold(body: Text('Scan route')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        faceAnalysisControllerProvider.overrideWith((ref) => controller),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    // Flutter's square test font makes both the section title and every
    // confidence line wrap on a POCO-width viewport. Load the Android UI font
    // shipped with the active Flutter SDK so this layout test measures the same
    // line breaks as the target device without a machine-specific SDK path.
    final separator = Platform.pathSeparator;
    var directory = File(Platform.resolvedExecutable).parent;
    File? font;
    while (directory.parent.path != directory.path) {
      final candidate = File(
        '${directory.path}${separator}bin${separator}cache$separator'
        'artifacts${separator}material_fonts${separator}roboto-regular.ttf',
      );
      if (candidate.existsSync()) {
        font = candidate;
        break;
      }
      directory = directory.parent;
    }
    if (font == null) {
      throw StateError('Could not locate the Flutter SDK Roboto test font.');
    }
    final bytes = font.readAsBytesSync();
    await (FontLoader(
      'Roboto',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });

  group('every authoritative value survives', () {
    testWidgets('all seven attributes are shown', (tester) async {
      await _pumpProfile(tester);

      for (final entry in _expected.entries) {
        expect(
          find.text(entry.key),
          findsOneWidget,
          reason: '${entry.key} must still be presented',
        );
        expect(
          find.text(entry.value.value),
          findsWidgets,
          reason: '${entry.key} value must still be presented',
        );
      }
    });

    testWidgets('every individual confidence is shown, unaggregated', (
      tester,
    ) async {
      await _pumpProfile(tester);

      for (final entry in _expected.entries) {
        expect(
          find.text('${entry.value.percent}% confidence'),
          findsOneWidget,
          reason: '${entry.key} keeps its own confidence figure',
        );
      }
    });

    testWidgets('no aggregate or invented confidence appears', (tester) async {
      await _pumpProfile(tester);

      // The seven figures average to about 88.7%. A rounded aggregate would
      // land on one of these, and none of them may appear as a summary.
      for (final forbidden in <String>[
        'Overall confidence',
        'Average confidence',
        'Total confidence',
        'Combined confidence',
        'Confidence score',
      ]) {
        expect(
          find.textContaining(forbidden),
          findsNothing,
          reason: 'confidence values must never be aggregated',
        );
      }

      // Exactly seven confidence lines: one per attribute, no summary row.
      expect(
        find.textContaining('% confidence'),
        findsNWidgets(_expected.length),
      );
    });

    testWidgets('each row reads as one sentence to a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpProfile(tester);

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  'Face shape: Oval, 91 percent confidence',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('the redundant validation explanation is gone', () {
    testWidgets('the quality checklist paragraph is not shown', (tester) async {
      await _pumpProfile(tester);

      // The checks are settled history by the time this screen is reached: a
      // photo that failed them never got here.
      for (final gone in <String>[
        'passed secure visibility',
        'secure visibility, lighting, sharpness',
        'framing checks',
        'Local checks passed',
      ]) {
        expect(
          find.textContaining(gone),
          findsNothing,
          reason: '"$gone" is a re-explanation of a resolved problem',
        );
      }
    });

    testWidgets('the outcome itself is still stated', (tester) async {
      await _pumpProfile(tester);

      expect(find.text('Analysis complete'), findsOneWidget);
    });

    testWidgets('the attributes are what the screen leads with', (
      tester,
    ) async {
      await _pumpProfile(tester);

      // The outcome line sits above the attributes, and nothing else does.
      final outcome = tester.getTopLeft(find.text('Analysis complete')).dy;
      final firstAttribute = tester.getTopLeft(find.text('Face shape')).dy;
      expect(outcome, lessThan(firstAttribute));
    });
  });

  group('onward navigation', () {
    testWidgets('choosing a makeup style is the single next step', (
      tester,
    ) async {
      await _pumpProfile(tester);

      expect(find.text('Choose a makeup style'), findsOneWidget);

      await tester.tap(find.text('Choose a makeup style'));
      await tester.pumpAndSettle();

      expect(find.text('Styles route'), findsOneWidget);
    });
  });

  group('presentation holds up', () {
    testWidgets('has zero scroll extent on the POCO completed viewport', (
      tester,
    ) async {
      await _pumpProfile(
        tester,
        size: const Size(1080, 2400),
        devicePixelRatio: 2.75,
        topInset: 66,
        bottomInset: 132,
      );

      final listView = find.byType(ListView);
      final scrollable = find.descendant(
        of: listView,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      final viewport = tester.getRect(listView);

      expect(position.viewportDimension, closeTo(704.7272727, 0.001));
      expect(position.maxScrollExtent, 0);
      expect(
        tester.getRect(find.byType(AppCard)).bottom,
        lessThan(viewport.bottom),
      );
      expect(
        tester.getRect(find.byType(PrimaryButton)).bottom,
        lessThan(viewport.bottom),
      );
      for (final label in _expected.keys) {
        expect(
          tester.getRect(find.text(label)).bottom,
          lessThan(viewport.bottom),
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the CTA reachable by scrolling on a short viewport', (
      tester,
    ) async {
      await _pumpProfile(
        tester,
        size: const Size(393, 640),
        topInset: 24,
        bottomInset: 48,
      );

      final listView = find.byType(ListView);
      final scrollable = find.descendant(
        of: listView,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));

      await tester.scrollUntilVisible(
        find.text('Choose a makeup style'),
        80,
        scrollable: scrollable,
      );
      await tester.pump();

      final viewport = tester.getRect(listView);
      final cta = tester.getRect(find.byType(PrimaryButton));
      expect(cta.top, greaterThanOrEqualTo(viewport.top));
      expect(cta.bottom, lessThanOrEqualTo(viewport.bottom));
      expect(find.text('Eye color'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the CTA reachable at 2x text scale', (tester) async {
      await _pumpProfile(
        tester,
        size: const Size(1080, 2400),
        devicePixelRatio: 2.75,
        topInset: 66,
        bottomInset: 132,
        textScale: 2,
      );

      final listView = find.byType(ListView);
      final scrollable = find.descendant(
        of: listView,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));

      await tester.scrollUntilVisible(
        find.text('Choose a makeup style'),
        120,
        scrollable: scrollable,
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Face shape'), findsOneWidget);
      expect(find.text('91% confidence'), findsOneWidget);
      final viewport = tester.getRect(listView);
      final cta = tester.getRect(find.byType(PrimaryButton));
      expect(cta.top, greaterThanOrEqualTo(viewport.top));
      expect(cta.bottom, lessThanOrEqualTo(viewport.bottom));
    });

    testWidgets('renders in dark theme without overflow', (tester) async {
      await _pumpProfile(tester, themeMode: ThemeMode.dark);

      expect(tester.takeException(), isNull);
      expect(find.text('Analysis complete'), findsOneWidget);
    });
  });
}
