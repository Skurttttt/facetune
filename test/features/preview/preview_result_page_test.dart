import 'dart:ui' show SemanticsFlag;

import 'package:facetune/core/constants/app_constants.dart';
import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/analysis/data/repositories/unavailable_face_analysis_repository.dart';
import 'package:facetune/features/analysis/domain/entities/face_analysis.dart';
import 'package:facetune/features/analysis/presentation/controllers/face_analysis_controller.dart';
import 'package:facetune/features/analysis/domain/usecases/analyze_face.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/makeup_styles/domain/entities/makeup_style.dart';
import 'package:facetune/features/makeup_styles/presentation/controllers/makeup_style_selection_controller.dart';
import 'package:facetune/features/preview/data/models/generated_preview_dto.dart';
import 'package:facetune/features/preview/data/repositories/unavailable_makeup_preview_repository.dart';
import 'package:facetune/features/preview/domain/entities/generated_preview.dart';
import 'package:facetune/features/preview/domain/usecases/generate_makeup_preview.dart';
import 'package:facetune/features/preview/presentation/controllers/makeup_preview_controller.dart';
import 'package:facetune/features/preview/presentation/pages/preview_result_page.dart';
import 'package:facetune/features/recommendation/data/models/makeup_recommendation_dto.dart';
import 'package:facetune/features/recommendation/data/repositories/unavailable_makeup_recommendation_repository.dart';
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/recommendation/domain/usecases/generate_makeup_recommendation.dart';
import 'package:facetune/features/recommendation/presentation/controllers/makeup_recommendation_controller.dart';
import 'package:facetune/features/results/domain/services/result_share_service.dart';
import 'package:facetune/features/results/presentation/controllers/result_actions_controller.dart';
import 'package:facetune/features/results/presentation/widgets/recommended_palette.dart';
import 'package:facetune/features/saved_looks/domain/entities/saved_look.dart';
import 'package:facetune/features/saved_looks/domain/repositories/saved_looks_repository.dart';
import 'package:facetune/features/tutorial/data/providers/tutorial_providers.dart';
import 'package:facetune/features/tutorial/domain/catalog/look_plan_convergence.dart';
import 'package:facetune/features/tutorial/domain/entities/canonical_preview_ref.dart';
import 'package:facetune/features/tutorial/domain/entities/recommendation_source_mode.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_manifest.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_session.dart';
import 'package:facetune/features/tutorial/domain/repositories/tutorial_manifest_repository.dart';
import 'package:facetune/features/tutorial/domain/repositories/tutorial_session_repository.dart';
import 'package:facetune/features/tutorial/domain/usecases/resolve_tutorial_manifest.dart';
import 'package:facetune/features/tutorial/presentation/controllers/realized_look_controller.dart';
import 'package:facetune/features/tutorial/presentation/pages/tutorial_page.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/analysis_response_fixture.dart';
import '../../helpers/generated_preview_response_fixture.dart';
import '../../helpers/recommendation_response_fixture.dart';

final _now = DateTime.utc(2026, 9, 3);

class _Harness {
  const _Harness({
    required this.manifests,
    required this.sessions,
    required this.savedLooks,
    required this.share,
  });

  final _CountingManifests manifests;
  final _CountingSessions sessions;
  final _SavedLooks savedLooks;
  final _Share share;

  List<int> get lifecycleCounts => <int>[
    sessions.loadCalls,
    manifests.loadAcceptedCalls,
    manifests.analyzeCalls,
    sessions.ensureStepsCalls,
  ];
}

Future<_Harness> _pumpResult(
  WidgetTester tester, {
  List<TutorialCategory> present = TutorialCategory.values,
  ThemeMode themeMode = ThemeMode.light,
  Brightness platformBrightness = Brightness.light,
  Size size = const Size(393, 873),
  double textScale = 1,
  MakeupRecommendation? recommendationOverride,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.platformBrightnessTestValue = platformBrightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  final analysis = FaceAnalysisDto.fromResponse(validAnalysisResponse).analysis;
  final recommendation =
      recommendationOverride ??
      MakeupRecommendationDto.fromResponse(
        validRecommendationResponse,
      ).recommendation;
  final preview =
      GeneratedPreviewDto.fromResponse(validGeneratedPreviewResponse).toDomain(
        originalImageUrl: 'https://example.invalid/original.jpg',
        generatedImageUrl: 'https://example.invalid/generated.jpg',
      );
  final style = MakeupStyleCatalog.styles.firstWhere(
    (candidate) => candidate.code == recommendation.styleCode,
  );

  final analysisController = FaceAnalysisController(
    const AnalyzeFace(UnavailableFaceAnalysisRepository()),
  )..restore(analysis);
  final recommendationController = MakeupRecommendationController(
    const GenerateMakeupRecommendation(
      UnavailableMakeupRecommendationRepository(),
    ),
  )..restore(recommendation);
  final previewController = MakeupPreviewController(
    const GenerateMakeupPreview(UnavailableMakeupPreviewRepository()),
  )..restore(preview, recommendation: recommendation);
  final styleController = MakeupStyleSelectionController()..restore(style);

  final session = TutorialSession(
    id: 'session-1',
    userId: 'user-1',
    analysisId: analysis.id,
    canonicalPreviewId: preview.id,
    lookPlan: LookPlanConvergence.fromStandard(recommendation),
    status: TutorialSessionStatus.ready,
    manifest: TutorialManifest(
      canonicalPreviewId: preview.id,
      sourceMode: RecommendationSourceMode.standard,
      status: TutorialManifestStatus.accepted,
      items: <TutorialManifestItem>[
        for (final category in TutorialCategory.values)
          TutorialManifestItem(
            category: category,
            presence: present.contains(category)
                ? TutorialCategoryPresence.present
                : TutorialCategoryPresence.absent,
          ),
      ],
      modelId: 'manifest-model',
      promptVersion: 'tutorial_manifest_v4_1',
      schemaVersion: 'v1',
      createdAt: _now,
    ),
    createdAt: _now,
    updatedAt: _now,
  );
  final manifests = _CountingManifests(session);
  final sessions = _CountingSessions(session);
  final realizedLookController = RealizedLookController(
    resolveManifest: ResolveTutorialManifest(
      manifestRepository: manifests,
      sessionRepository: sessions,
    ),
  );
  final savedLooks = _SavedLooks(
    analysis: analysis,
    recommendation: recommendation,
    preview: preview,
    style: style,
  );
  final share = _Share();
  final actionsController = ResultActionsController(share, savedLooks, () {});

  late final GoRouter router;
  router = GoRouter(
    initialLocation: AppConstants.previewRoute,
    routes: <RouteBase>[
      GoRoute(
        path: AppConstants.homeRoute,
        builder: (context, state) => const Scaffold(body: Text('Home route')),
      ),
      GoRoute(
        path: AppConstants.previewRoute,
        builder: (context, state) => const PreviewResultPage(),
      ),
      GoRoute(
        path: AppConstants.tutorialRoute,
        builder: (context, state) {
          final args = state.extra! as TutorialPageArgs;
          return Scaffold(
            body: Text(
              'Tutorial route ${args.preview.id} ${args.finalPreviewUrl}',
            ),
          );
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        faceAnalysisControllerProvider.overrideWith(
          (ref) => analysisController,
        ),
        makeupRecommendationControllerProvider.overrideWith(
          (ref) => recommendationController,
        ),
        makeupPreviewControllerProvider.overrideWith(
          (ref) => previewController,
        ),
        makeupStyleSelectionControllerProvider.overrideWith(
          (ref) => styleController,
        ),
        realizedLookControllerProvider.overrideWith(
          (ref) => realizedLookController,
        ),
        resultActionsControllerProvider.overrideWith(
          (ref) => actionsController,
        ),
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
  return _Harness(
    manifests: manifests,
    sessions: sessions,
    savedLooks: savedLooks,
    share: share,
  );
}

Future<void> _selectSection(WidgetTester tester, String label) async {
  final tab = find.text(label);
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

void main() {
  group('UI-R1 result information architecture', () {
    testWidgets(
      'Overview is first and primary actions are immediately visible',
      (tester) async {
        await _pumpResult(tester);

        expect(
          find.byKey(const ValueKey('result-section-tabs')),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Overview tab'), findsOneWidget);
        expect(find.bySemanticsLabel('Makeup tab'), findsOneWidget);
        expect(find.bySemanticsLabel('Profile tab'), findsOneWidget);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Overview tab'))
              .hasFlag(SemanticsFlag.isSelected),
          isTrue,
        );
        expect(
          find.byKey(const ValueKey('result-section-overview')),
          findsOneWidget,
        );
        expect(find.text('Detected beauty profile'), findsNothing);
        expect(find.text('Makeup breakdown'), findsNothing);

        final tutorial = find.byKey(const ValueKey('result-show-tutorial'));
        final save = find.byKey(const ValueKey('result-save-look'));
        expect(tutorial, findsOneWidget);
        expect(save, findsOneWidget);
        expect(tester.getBottomRight(tutorial).dy, lessThanOrEqualTo(873));
        expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(873));
        expect(find.text('Save look'), findsOneWidget);
      },
    );

    testWidgets('Show me how keeps the canonical preview tutorial callback', (
      tester,
    ) async {
      await _pumpResult(tester);

      await tester.tap(find.byKey(const ValueKey('result-show-tutorial')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Tutorial route 8f326875-ff56-4a8f-8500-6baa49636417',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('https://example.invalid/generated.jpg'),
        findsOneWidget,
      );
    });

    testWidgets('Save, Favorite, and Share retain one callback authority', (
      tester,
    ) async {
      final harness = await _pumpResult(tester);

      await tester.tap(find.byKey(const ValueKey('result-save-look')));
      await tester.pumpAndSettle();
      expect(harness.savedLooks.saveCalls, 1);
      expect(find.text('Saved'), findsOneWidget);

      await tester.ensureVisible(find.text('Favorite'));
      await tester.tap(find.text('Favorite'));
      await tester.pumpAndSettle();
      expect(harness.savedLooks.favoriteCalls, 1);

      await tester.ensureVisible(find.text('Share'));
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(harness.share.calls, 1);
    });
  });

  group('UI-R1 lifecycle and authority locks', () {
    testWidgets('tabs, expansion, profile, and scrolling add zero AI work', (
      tester,
    ) async {
      final harness = await _pumpResult(tester);
      expect(harness.sessions.loadCalls, 1);
      expect(harness.manifests.loadAcceptedCalls, 1);
      expect(harness.manifests.analyzeCalls, 0);
      final openedCounts = harness.lifecycleCounts;

      await _selectSection(tester, 'Makeup');
      expect(find.text('Makeup breakdown'), findsOneWidget);
      expect(harness.lifecycleCounts, openedCounts);

      final foundation = find.text('Foundation');
      await tester.ensureVisible(foundation);
      await tester.tap(foundation);
      await tester.pumpAndSettle();
      expect(find.text('Placement'), findsWidgets);
      expect(harness.lifecycleCounts, openedCounts);

      await tester.tap(foundation);
      await tester.pumpAndSettle();
      expect(harness.lifecycleCounts, openedCounts);

      await _selectSection(tester, 'Profile');
      expect(find.text('Detected beauty profile'), findsOneWidget);
      expect(harness.lifecycleCounts, openedCounts);

      await _selectSection(tester, 'Makeup');
      await _selectSection(tester, 'Overview');
      expect(harness.lifecycleCounts, openedCounts);

      await tester.drag(
        find.byKey(const ValueKey('result-content-scroll')),
        const Offset(0, -250),
      );
      await tester.pump();
      expect(harness.lifecycleCounts, openedCounts);
      expect(harness.manifests.analyzeCalls, 0);
    });

    testWidgets('Profile keeps each authoritative confidence separate', (
      tester,
    ) async {
      await _pumpResult(tester);
      await _selectSection(tester, 'Profile');

      expect(
        find.bySemanticsLabel('Skin tone, Medium, 88% confidence'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Undertone, Warm, 82% confidence'),
        findsOneWidget,
      );
      expect(find.text('88%'), findsOneWidget);
      expect(find.text('82%'), findsOneWidget);
      expect(find.text('Complexion'), findsNothing);
    });
  });

  group('UI-R1 responsive, accessibility, and theme evidence', () {
    testWidgets('narrow 320 width at 2x text reflows without overflow', (
      tester,
    ) async {
      await _pumpResult(tester, size: const Size(320, 800), textScale: 2);

      expect(tester.takeException(), isNull);
      final tutorial = find.byKey(const ValueKey('result-show-tutorial'));
      final save = find.byKey(const ValueKey('result-save-look'));
      expect(
        tester.getTopLeft(save).dy,
        greaterThan(tester.getTopLeft(tutorial).dy),
      );
      await _selectSection(tester, 'Makeup');
      expect(tester.takeException(), isNull);
      await _selectSection(tester, 'Profile');
      expect(tester.takeException(), isNull);
    });

    for (final condition
        in <
          ({
            String name,
            ThemeMode mode,
            Brightness platform,
            Brightness expected,
          })
        >[
          (
            name: 'Light',
            mode: ThemeMode.light,
            platform: Brightness.dark,
            expected: Brightness.light,
          ),
          (
            name: 'Dark',
            mode: ThemeMode.dark,
            platform: Brightness.light,
            expected: Brightness.dark,
          ),
          (
            name: 'System light',
            mode: ThemeMode.system,
            platform: Brightness.light,
            expected: Brightness.light,
          ),
          (
            name: 'System dark',
            mode: ThemeMode.system,
            platform: Brightness.dark,
            expected: Brightness.dark,
          ),
        ]) {
      testWidgets('${condition.name} keeps the result scheme', (tester) async {
        await _pumpResult(
          tester,
          themeMode: condition.mode,
          platformBrightness: condition.platform,
        );

        expect(
          Theme.of(tester.element(find.byType(PreviewResultPage))).brightness,
          condition.expected,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('palette stays horizontal and names every color', (
      tester,
    ) async {
      final base = MakeupRecommendationDto.fromResponse(
        validRecommendationResponse,
      ).recommendation;
      final first = base.items.entries.first;
      final longRecommendation = MakeupRecommendation(
        id: base.id,
        analysisId: base.analysisId,
        styleCode: base.styleCode,
        overallIntensity: base.overallIntensity,
        items: <String, MakeupRecommendationItem>{
          ...base.items,
          first.key: MakeupRecommendationItem(
            name:
                'Layered muted warm rose with a softly neutral peach undertone',
            hex: first.value.hex,
            placement: first.value.placement,
            technique: first.value.technique,
            finish: first.value.finish,
            intensity: first.value.intensity,
            reasoning: first.value.reasoning,
          ),
        },
        modelId: base.modelId,
        promptVersion: base.promptVersion,
        createdAt: base.createdAt,
      );
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: RecommendedPalette(recommendation: longRecommendation),
            ),
          ),
        ),
      );

      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.scrollDirection, Axis.horizontal);
      expect(
        find.bySemanticsLabel(
          RegExp('Layered muted warm rose.*color #[0-9A-F]{6}'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

class _CountingManifests implements TutorialManifestRepository {
  _CountingManifests(this.session);

  final TutorialSession session;
  int loadAcceptedCalls = 0;
  int analyzeCalls = 0;

  @override
  Future<TutorialSession?> loadAccepted(CanonicalPreviewRef preview) async {
    loadAcceptedCalls += 1;
    return session;
  }

  @override
  Future<TutorialSession> analyze(CanonicalPreviewRef preview) async {
    analyzeCalls += 1;
    return session;
  }
}

class _CountingSessions implements TutorialSessionRepository {
  _CountingSessions(this.session);

  final TutorialSession session;
  int loadCalls = 0;
  int ensureStepsCalls = 0;

  @override
  Future<TutorialSession?> loadForCanonicalPreview(
    CanonicalPreviewRef preview,
  ) async {
    loadCalls += 1;
    return null;
  }

  @override
  Future<TutorialSession> ensureSteps(TutorialSession value) async {
    ensureStepsCalls += 1;
    return value;
  }

  @override
  Future<TutorialSession> loadById(String sessionId) async => session;

  @override
  Future<void> delete(String sessionId) async {}
}

class _SavedLooks implements SavedLooksRepository {
  _SavedLooks({
    required this.analysis,
    required this.recommendation,
    required this.preview,
    required this.style,
  });

  final FaceAnalysis analysis;
  final MakeupRecommendation recommendation;
  final GeneratedPreview preview;
  final MakeupStyle style;
  SavedLook? saved;
  int saveCalls = 0;
  int favoriteCalls = 0;

  @override
  Future<SavedLook?> findByGeneratedImageId(String generatedImageId) async =>
      saved;

  @override
  Future<SavedLook> save(
    GeneratedPreview value, {
    bool favorite = false,
  }) async {
    saveCalls += 1;
    return saved = SavedLook(
      id: 'saved-1',
      preview: preview,
      analysis: analysis,
      recommendation: recommendation,
      style: style,
      isFavorite: favorite,
      createdAt: _now,
    );
  }

  @override
  Future<SavedLook> setFavorite(SavedLook look, bool favorite) async {
    favoriteCalls += 1;
    return saved = look.copyWith(isFavorite: favorite);
  }

  @override
  Future<void> remove(String savedLookId) async {
    saved = null;
  }

  @override
  Future<SavedLooksPageResult> loadPage({
    required int offset,
    required int limit,
  }) async => SavedLooksPageResult(
    items: saved == null ? const <SavedLook>[] : <SavedLook>[saved!],
    hasMore: false,
  );
}

class _Share implements ResultShareService {
  int calls = 0;

  @override
  Future<void> share({
    required GeneratedPreview preview,
    required String styleName,
  }) async {
    calls += 1;
  }
}
