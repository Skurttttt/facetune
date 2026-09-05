import 'dart:async';

import 'package:facetune/core/constants/app_constants.dart';
import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/analysis/domain/entities/face_analysis.dart';
import 'package:facetune/features/analysis/presentation/controllers/face_analysis_controller.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_look_providers.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_products_providers.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_generated_preview.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_product.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_look_repository.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_products_repository.dart';
import 'package:facetune/features/makeup_kit/domain/value_objects/normalized_hex_color.dart';
import 'package:facetune/features/makeup_kit/presentation/pages/makeup_kit_recommendation_entry_page.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/makeup_styles/domain/entities/makeup_style.dart';
import 'package:facetune/features/makeup_styles/presentation/controllers/makeup_style_selection_controller.dart';
import 'package:facetune/features/preview/domain/entities/generated_preview.dart';
import 'package:facetune/features/preview/domain/repositories/makeup_preview_repository.dart';
import 'package:facetune/features/preview/domain/usecases/generate_makeup_preview.dart';
import 'package:facetune/features/preview/presentation/controllers/makeup_preview_controller.dart';
import 'package:facetune/features/preview/presentation/pages/preview_result_page.dart';
import 'package:facetune/features/recommendation/data/models/makeup_recommendation_dto.dart';
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/recommendation/domain/repositories/makeup_recommendation_repository.dart';
import 'package:facetune/features/recommendation/domain/usecases/generate_makeup_recommendation.dart';
import 'package:facetune/features/recommendation/presentation/controllers/makeup_recommendation_controller.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/analysis_response_fixture.dart';
import '../helpers/fake_auth_repository.dart';
import '../helpers/recommendation_response_fixture.dart';

/// The one wait before a canonical final preview, asserted from both modes.
///
/// The contract under test is that this screen shows exactly what the app can
/// know — one generation state, plus metadata already in hand — and that
/// showing it costs nothing: no generation is started, restarted, or repeated
/// because a placeholder pulsed.
void main() {
  group('Final preview loading — Makeup Recommendation', () {
    testWidgets('waits in the result frame, not a bare spinner', (
      tester,
    ) async {
      final harness = await _pumpStandardGenerating(tester);

      expect(find.byType(FinalPreviewLoadingView), findsOneWidget);
      expect(
        find.byKey(const ValueKey('final-preview-loading')),
        findsOneWidget,
      );

      // The generic spinner-only presentation is gone.
      expect(find.byType(LoadingState), findsNothing);
      expect(
        find.text('Creating another identity-conscious variation…'),
        findsNothing,
      );

      // Standard's own supporting line.
      expect(
        find.text('Personalizing your makeup preview for your features.'),
        findsOneWidget,
      );

      // One truthful status, and the neutral reassurance.
      expect(find.text(FinalPreviewLoadingView.activeStatus), findsOneWidget);
      expect(find.text(FinalPreviewLoadingView.reassurance), findsOneWidget);

      expect(harness.previews.calls, 1);
    });

    testWidgets('names the real selected style and the real intensity', (
      tester,
    ) async {
      final harness = await _pumpStandardGenerating(tester);
      final style = harness.style.name;

      expect(find.text('Creating your $style look'), findsOneWidget);
      // The plan fixture's own intensity, formatted the way the app formats it.
      expect(find.textContaining(' intensity'), findsOneWidget);
      expect(find.textContaining(style), findsWidgets);
    });

    testWidgets('omits metadata it does not have rather than inventing it', (
      tester,
    ) async {
      await _pumpStandardGenerating(tester, withStyle: false, withPlan: false);

      expect(find.text('Creating your look'), findsOneWidget);
      expect(find.textContaining(' intensity'), findsNothing);
      expect(find.textContaining('Unknown'), findsNothing);
      expect(find.textContaining('N/A'), findsNothing);
      expect(find.textContaining('null'), findsNothing);
      // The status is still there: it never depended on metadata.
      expect(find.text(FinalPreviewLoadingView.activeStatus), findsOneWidget);
    });

    testWidgets('shows no invented pipeline, progress, or stage list', (
      tester,
    ) async {
      await _pumpStandardGenerating(tester);

      for (final forbidden in const [
        'Preparing',
        'Saving',
        'Almost',
        'Finishing',
        'Nearly',
        '%',
        'Step ',
        'foundation',
        'blush',
        'lipstick',
      ]) {
        expect(
          find.textContaining(forbidden),
          findsNothing,
          reason: '"$forbidden" is not a state this app can observe',
        );
      }
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('pulsing the hero starts no further generation', (
      tester,
    ) async {
      final harness = await _pumpStandardGenerating(tester);
      expect(harness.previews.calls, 1);

      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(FinalPreviewLoadingView), findsOneWidget);
      expect(harness.previews.calls, 1);
      expect(harness.recommendations.calls, 0);
    });

    testWidgets('the canonical preview replaces the placeholder', (
      tester,
    ) async {
      final harness = await _pumpStandardGenerating(tester);

      harness.previews.complete();
      await tester.pumpAndSettle();

      expect(find.byType(FinalPreviewLoadingView), findsNothing);
      expect(
        find.byKey(const ValueKey('result-primary-actions')),
        findsWidgets,
      );
      expect(harness.previews.calls, 1);
    });

    testWidgets('the existing failure state is reached unchanged', (
      tester,
    ) async {
      final harness = await _pumpStandardGenerating(tester);

      harness.previews.fail();
      await tester.pumpAndSettle();

      expect(find.byType(FinalPreviewLoadingView), findsNothing);
      expect(find.text('Preview generation paused'), findsOneWidget);
      expect(harness.previews.calls, 1);
    });

    testWidgets('fits a narrow, short viewport at increased text scale', (
      tester,
    ) async {
      await _pumpStandardGenerating(
        tester,
        size: const Size(360, 640),
        textScale: 1.6,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(FinalPreviewLoadingView.activeStatus), findsOneWidget);
    });

    testWidgets('renders in dark theme without overflow', (tester) async {
      await _pumpStandardGenerating(tester, themeMode: ThemeMode.dark);

      expect(tester.takeException(), isNull);
      expect(find.byType(FinalPreviewLoadingView), findsOneWidget);
    });
  });

  group('Final preview loading — My Makeup Kit', () {
    testWidgets('waits in the same shell with owned-product copy', (
      tester,
    ) async {
      final harness = await _pumpKitGenerating(tester);

      expect(find.byType(FinalPreviewLoadingView), findsOneWidget);
      expect(
        find.text(
          'Using your selected makeup products to create your preview.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Personalizing your makeup preview for your features.'),
        findsNothing,
      );

      // The same single status and reassurance Standard shows.
      expect(find.text(FinalPreviewLoadingView.activeStatus), findsOneWidget);
      expect(find.text(FinalPreviewLoadingView.reassurance), findsOneWidget);
      expect(find.byType(LoadingState), findsNothing);
      expect(
        find.text('Applying your owned shades to the preview…'),
        findsNothing,
      );

      // Metadata from the kit's own already-held state.
      expect(
        find.text('Creating your ${harness.style.name} look'),
        findsOneWidget,
      );
      expect(find.textContaining(' intensity'), findsOneWidget);

      // The escape this state has always offered is still here.
      expect(find.text('Cancel and change mode'), findsOneWidget);

      // Kit authority only. Standard is never consulted for a kit preview.
      expect(harness.kitLook.previewCalls, 1);
      expect(harness.standard.calls, 0);
    });

    testWidgets('pulsing the hero starts no further generation', (
      tester,
    ) async {
      final harness = await _pumpKitGenerating(tester);

      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(FinalPreviewLoadingView), findsOneWidget);
      expect(harness.kitLook.previewCalls, 1);
      expect(harness.kitLook.recommendationCalls, 1);
      expect(harness.standard.calls, 0);
    });

    testWidgets('shows no invented pipeline or progress', (tester) async {
      await _pumpKitGenerating(tester);

      for (final forbidden in const ['Preparing', 'Saving', 'Almost', '%']) {
        expect(find.textContaining(forbidden), findsNothing);
      }
    });

    testWidgets('fits a narrow, short viewport at increased text scale', (
      tester,
    ) async {
      await _pumpKitGenerating(
        tester,
        size: const Size(360, 640),
        textScale: 1.6,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(FinalPreviewLoadingView.activeStatus), findsOneWidget);
    });
  });

  group('Final preview loading — parity and geometry', () {
    testWidgets('both modes draw the same hero frame', (tester) async {
      await _pumpStandardGenerating(tester);
      final standardHero = tester.getSize(
        find.byKey(const ValueKey('final-preview-loading')),
      );
      final standardStatus = tester.widget<Text>(
        find.text(FinalPreviewLoadingView.activeStatus),
      );

      await _pumpKitGenerating(tester);
      final kitHero = tester.getSize(
        find.byKey(const ValueKey('final-preview-loading')),
      );
      final kitStatus = tester.widget<Text>(
        find.text(FinalPreviewLoadingView.activeStatus),
      );

      expect(kitHero, standardHero);
      expect(kitStatus.style, standardStatus.style);
    });

    testWidgets('the placeholder keeps the canonical preview proportion', (
      tester,
    ) async {
      await _pumpStandardGenerating(tester);

      // The hero is the DecoratedBox inside the loading view — found by its
      // rendered geometry rather than by a private type.
      final view = find.byType(FinalPreviewLoadingView);
      final hero = find.descendant(
        of: view,
        matching: find.byType(DecoratedBox),
      );
      expect(hero, findsWidgets);
      final size = tester.getSize(hero.first);
      expect(
        size.width / size.height,
        closeTo(FinalPreviewLoadingView.heroAspectRatio, 0.01),
      );

      // It carries real visual weight rather than being a token strip.
      final viewport = tester.getSize(view);
      expect(size.height, greaterThan(viewport.height * 0.35));
    });

    testWidgets('a shorter viewport shrinks the hero rather than overflowing', (
      tester,
    ) async {
      await _pumpStandardGenerating(tester, size: const Size(393, 873));
      final onTallPhone = tester
          .getSize(
            find
                .descendant(
                  of: find.byType(FinalPreviewLoadingView),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          )
          .height;

      await _pumpStandardGenerating(tester, size: const Size(360, 640));
      final onShortPhone = tester
          .getSize(
            find
                .descendant(
                  of: find.byType(FinalPreviewLoadingView),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          )
          .height;

      expect(onShortPhone, lessThan(onTallPhone));
      expect(tester.takeException(), isNull);
    });
  });
}

// ---------------------------------------------------------------------------
// Makeup Recommendation harness
// ---------------------------------------------------------------------------

typedef _StandardHarness = ({
  _PendingPreviews previews,
  _CountingRecommendations recommendations,
  MakeupStyle style,
});

Future<_StandardHarness> _pumpStandardGenerating(
  WidgetTester tester, {
  Size size = const Size(393, 873),
  double textScale = 1,
  ThemeMode themeMode = ThemeMode.light,
  bool withStyle = true,
  bool withPlan = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final previews = _PendingPreviews();
  final recommendations = _CountingRecommendations();
  final analysis = FaceAnalysisDto.fromResponse(validAnalysisResponse).analysis;
  final style = MakeupStyleCatalog.styles.first;
  final parsed = MakeupRecommendationDto.fromResponse(
    validRecommendationResponse,
  ).recommendation;
  // Linked to this analysis and this style, because the result screen refuses
  // to resolve a plan whose analysis or style does not match the journey — the
  // same rule it applies in production, left untouched here.
  final recommendation = MakeupRecommendation(
    id: parsed.id,
    analysisId: analysis.id,
    styleCode: style.code,
    overallIntensity: parsed.overallIntensity,
    items: parsed.items,
    modelId: parsed.modelId,
    promptVersion: parsed.promptVersion,
    createdAt: parsed.createdAt,
  );

  final previewController = MakeupPreviewController(
    GenerateMakeupPreview(previews),
  );
  final recommendationController = MakeupRecommendationController(
    GenerateMakeupRecommendation(recommendations),
  );
  if (withPlan) recommendationController.restore(recommendation);

  final container = ProviderContainer(
    overrides: [
      makeupPreviewControllerProvider.overrideWith((ref) => previewController),
      makeupRecommendationControllerProvider.overrideWith(
        (ref) => recommendationController,
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(faceAnalysisControllerProvider.notifier).restore(analysis);
  if (withStyle) {
    container
        .read(makeupStyleSelectionControllerProvider.notifier)
        .restore(style);
  }

  final router = GoRouter(
    initialLocation: AppConstants.previewRoute,
    routes: <RouteBase>[
      GoRoute(
        path: AppConstants.previewRoute,
        builder: (context, state) => const PreviewResultPage(),
      ),
      GoRoute(
        path: AppConstants.homeRoute,
        builder: (context, state) => const Scaffold(body: Text('Home route')),
      ),
      GoRoute(
        path: AppConstants.recommendationRoute,
        builder: (context, state) => const Scaffold(body: Text('Plan route')),
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

  // Started the way the product starts it — from the plan screen's action,
  // before this page exists. Nothing on the page below causes this call.
  unawaited(previewController.generate(recommendation: recommendation));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
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
  // Not pumpAndSettle: the placeholder pulses for as long as the wait lasts.
  await tester.pump();
  return (previews: previews, recommendations: recommendations, style: style);
}

class _PendingPreviews implements MakeupPreviewRepository {
  final _completer = Completer<GeneratedPreview>();
  int calls = 0;
  MakeupRecommendation? last;

  void complete() => _completer.complete(
    GeneratedPreview(
      id: 'preview-1',
      analysisId: last!.analysisId,
      recommendationId: last!.id,
      originalImageUrl: 'https://example.test/original.jpg',
      generatedImageUrl: 'https://example.test/generated.jpg',
      originalImagePath: 'user/original.jpg',
      generatedImagePath: 'user/generated.jpg',
      generationNumber: 1,
      modelId: 'gemini-3.1-flash-image',
      promptVersion: 'makeup_preview_v2',
      createdAt: DateTime.utc(2026, 9, 6),
    ),
  );

  void fail() => _completer.completeError(StateError('offline'));

  @override
  Future<GeneratedPreview> generate({
    required MakeupRecommendation recommendation,
  }) {
    calls += 1;
    last = recommendation;
    return _completer.future;
  }
}

/// Present only to be counted. A preview wait must not create a plan.
class _CountingRecommendations implements MakeupRecommendationRepository {
  int calls = 0;

  @override
  Future<MakeupRecommendation> generate({
    required FaceAnalysis analysis,
    required MakeupStyle style,
  }) {
    calls += 1;
    throw StateError('The preview wait must not request a recommendation.');
  }
}

// ---------------------------------------------------------------------------
// My Makeup Kit harness
// ---------------------------------------------------------------------------

typedef _KitHarness = ({
  _PendingKitLook kitLook,
  _CountingRecommendations standard,
  MakeupStyle style,
});

Future<_KitHarness> _pumpKitGenerating(
  WidgetTester tester, {
  Size size = const Size(393, 873),
  double textScale = 1,
}) async {
  // The kit reaches its preview wait through its own "Your kit is ready"
  // screen, which is not this task's surface and does not fit a 360x640
  // viewport at 1.6x. The journey therefore runs at the default viewport and
  // the constraint is applied once the wait is on screen.
  tester.view.physicalSize = const Size(393, 873);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final scale = ValueNotifier<double>(1);
  addTearDown(scale.dispose);

  final kitLook = _PendingKitLook();
  final standard = _CountingRecommendations();
  final style = MakeupStyleCatalog.styles.first;
  final container = ProviderContainer(
    overrides: [
      supabaseAvailableProvider.overrideWithValue(false),
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(
          user: const AuthUser(id: 'user-1', isAnonymous: false),
        ),
      ),
      makeupKitProductsRepositoryProvider.overrideWithValue(_KitProducts()),
      makeupKitLookRepositoryProvider.overrideWithValue(kitLook),
    ],
  );
  addTearDown(container.dispose);
  container
      .read(faceAnalysisControllerProvider.notifier)
      .restore(FaceAnalysisDto.fromResponse(validAnalysisResponse).analysis);
  container
      .read(makeupStyleSelectionControllerProvider.notifier)
      .restore(style);

  final router = GoRouter(
    initialLocation: AppConstants.makeupKitRecommendationEntryRoute,
    routes: <RouteBase>[
      GoRoute(
        path: AppConstants.makeupKitRecommendationEntryRoute,
        builder: (context, state) => const MakeupKitRecommendationEntryPage(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ValueListenableBuilder<double>(
        valueListenable: scale,
        builder: (context, value, _) => MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(value)),
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // The kit's own explicit start, from the control the user taps. The plan
  // resolves immediately; the preview is what stays pending.
  await tester.tap(find.text('Create kit-based preview'));
  await tester.pump();
  await tester.pump();

  if (size != const Size(393, 873) || textScale != 1) {
    tester.view.physicalSize = size;
    scale.value = textScale;
    await tester.pump();
  }
  return (kitLook: kitLook, standard: standard, style: style);
}

class _PendingKitLook implements MakeupKitLookRepository {
  final _preview = Completer<KitGeneratedPreview>();
  int recommendationCalls = 0;
  int previewCalls = 0;

  @override
  Future<KitMakeupRecommendation> generateRecommendation({
    required String analysisId,
    required String styleCode,
  }) async {
    recommendationCalls += 1;
    return KitMakeupRecommendation(
      id: 'kit-recommendation-1',
      analysisId: analysisId,
      styleCode: styleCode,
      selections: const [
        KitMakeupSelection(
          productId: 'product-1',
          category: 'lipstick',
          colorHex: '#B86F72',
          finish: 'matte',
          placement: 'Across the lips',
          technique: 'Apply a thin layer',
          intensity: 'soft',
        ),
      ],
      productSnapshots: const [
        KitProductSnapshot(
          productId: 'product-1',
          category: 'lipstick',
          colorHex: '#B86F72',
          finish: 'matte',
          productName: 'My lipstick',
          colorLabel: 'Warm Rose',
        ),
      ],
      overallIntensity: 'soft',
      summary: 'Built from one owned product.',
      modelId: 'test-model',
      promptVersion: 'test-prompt',
      createdAt: DateTime.utc(2026, 9, 6),
    );
  }

  @override
  Future<KitGeneratedPreview> generatePreview({
    required KitMakeupRecommendation recommendation,
  }) {
    previewCalls += 1;
    return _preview.future;
  }
}

class _KitProducts implements MakeupKitProductsRepository {
  final _items = [
    MakeupKitProduct(
      id: 'product-1',
      userId: 'user-1',
      category: MakeupKitCategory.lipstick,
      color: NormalizedHexColor.parse('#B86F72'),
      finish: MakeupKitFinish.matte,
      createdAt: DateTime.utc(2026, 8, 13),
      updatedAt: DateTime.utc(2026, 8, 13),
    ),
  ];

  @override
  Future<List<MakeupKitProduct>> loadAll() async => _items;

  @override
  Future<List<MakeupKitProduct>> loadByCategory(
    MakeupKitCategory category,
  ) async => _items.where((item) => item.category == category).toList();

  @override
  Future<MakeupKitProduct> create(MakeupKitProductDraft draft) =>
      throw UnimplementedError();

  @override
  Future<MakeupKitProduct> update(
    String productId,
    MakeupKitProductDraft draft,
  ) => throw UnimplementedError();

  @override
  Future<void> delete(String productId) => throw UnimplementedError();
}
