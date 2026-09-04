import 'package:facetune/core/constants/app_constants.dart';
import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/analysis/domain/usecases/analyze_face.dart';
import 'package:facetune/features/analysis/data/repositories/unavailable_face_analysis_repository.dart';
import 'package:facetune/features/analysis/presentation/controllers/face_analysis_controller.dart';
import 'package:facetune/features/analysis/presentation/pages/analysis_result_page.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
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
  double textScale = 1,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
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
}

void main() {
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
    testWidgets('renders at 320px and 2x text without overflow', (
      tester,
    ) async {
      await _pumpProfile(tester, size: const Size(320, 2400), textScale: 2);

      expect(tester.takeException(), isNull);
      expect(find.text('Face shape'), findsOneWidget);
      expect(find.text('91% confidence'), findsOneWidget);
    });

    testWidgets('renders in dark theme without overflow', (tester) async {
      await _pumpProfile(tester, themeMode: ThemeMode.dark);

      expect(tester.takeException(), isNull);
      expect(find.text('Analysis complete'), findsOneWidget);
    });
  });
}
