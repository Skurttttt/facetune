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
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/recommendation/domain/repositories/makeup_recommendation_repository.dart';
import 'package:facetune/features/recommendation/domain/usecases/generate_makeup_recommendation.dart';
import 'package:facetune/features/recommendation/presentation/controllers/makeup_recommendation_controller.dart';
import 'package:facetune/features/recommendation/presentation/pages/makeup_recommendation_page.dart';
import 'package:facetune/features/recommendation/presentation/widgets/recommendation_item_card.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/analysis_response_fixture.dart';
import '../helpers/fake_auth_repository.dart';

/// The shell both modes wait in, asserted from both sides.
///
/// The point of these tests is not that a particular widget is on screen but
/// that the two modes present the same wait while keeping their own authority:
/// Standard never asks the kit for anything, the kit never asks Standard, and
/// neither page starts generation because a skeleton rebuilt.
void main() {
  group('Makeup plan loading — Makeup Recommendation', () {
    testWidgets('waits in the destination-shaped shell, not a bare spinner', (
      tester,
    ) async {
      final harness = await _pumpStandardLoading(tester);

      expect(find.byType(MakeupPlanLoadingView), findsOneWidget);
      expect(find.byKey(const ValueKey('makeup-plan-loading')), findsOneWidget);
      expect(find.text('Creating your makeup plan'), findsOneWidget);
      expect(
        find.text('Personalizing your recommendations for your features.'),
        findsOneWidget,
      );

      // The screen the wait belongs to still names itself.
      expect(find.text('Your makeup plan'), findsOneWidget);

      // The generic spinner-only presentation is gone.
      expect(find.byType(LoadingState), findsNothing);
      expect(
        find.text('Designing your personalized makeup plan…'),
        findsNothing,
      );

      // Placeholder geometry, and nothing that could be read as a plan.
      expect(find.byType(RecommendationItemCard), findsNothing);
      expect(find.byType(AppColorSwatch), findsNWidgets(5));

      // No invented progress anywhere on the page.
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining('Almost'), findsNothing);
      expect(find.textContaining('Step '), findsNothing);

      // The wait cost exactly the one generation the mode selection started.
      expect(harness.repository.calls, 1);
    });

    testWidgets('rebuilding the skeleton starts no further generation', (
      tester,
    ) async {
      final harness = await _pumpStandardLoading(tester);
      expect(harness.repository.calls, 1);

      // Several shimmer frames, which is what a real wait does to this page.
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(MakeupPlanLoadingView), findsOneWidget);
      expect(harness.repository.calls, 1);
    });

    testWidgets('the plan replaces the skeleton when it arrives', (
      tester,
    ) async {
      final harness = await _pumpStandardLoading(tester);

      harness.repository.complete();
      await tester.pumpAndSettle();

      expect(find.byType(MakeupPlanLoadingView), findsNothing);
      expect(find.byType(RecommendationItemCard), findsWidgets);
      expect(harness.repository.calls, 1);
    });

    testWidgets('a failed plan still reaches its existing error state', (
      tester,
    ) async {
      final harness = await _pumpStandardLoading(tester);

      harness.repository.fail();
      await tester.pumpAndSettle();

      expect(find.byType(MakeupPlanLoadingView), findsNothing);
      expect(find.text('We could not create your plan'), findsOneWidget);
    });

    testWidgets('fits a narrow, short viewport at increased text scale', (
      tester,
    ) async {
      await _pumpStandardLoading(
        tester,
        size: const Size(360, 640),
        textScale: 1.6,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Creating your makeup plan'), findsOneWidget);
    });
  });

  group('Makeup plan loading — My Makeup Kit', () {
    testWidgets('waits in the same shell with owned-product copy', (
      tester,
    ) async {
      final harness = await _pumpKitPlanLoading(tester);

      expect(find.byType(MakeupPlanLoadingView), findsOneWidget);
      expect(find.byKey(const ValueKey('makeup-plan-loading')), findsOneWidget);
      expect(find.text('Creating your makeup plan'), findsOneWidget);
      expect(
        find.text('Personalizing your owned products for your features.'),
        findsOneWidget,
      );
      expect(
        find.text('Personalizing your recommendations for your features.'),
        findsNothing,
      );
      expect(find.text('Your makeup plan'), findsOneWidget);

      expect(find.byType(LoadingState), findsNothing);
      expect(
        find.text('Choosing the best products from your kit…'),
        findsNothing,
      );
      expect(find.byType(AppColorSwatch), findsNWidgets(4));
      expect(find.textContaining('%'), findsNothing);

      // The escape this state has always offered is still here.
      expect(find.text('Cancel and change mode'), findsOneWidget);

      // Kit authority only: one kit recommendation, no Standard call at all.
      expect(harness.kitLook.recommendationCalls, 1);
      expect(harness.kitLook.previewCalls, 0);
      expect(harness.standard.calls, 0);
    });

    testWidgets('rebuilding the skeleton starts no further generation', (
      tester,
    ) async {
      final harness = await _pumpKitPlanLoading(tester);

      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(MakeupPlanLoadingView), findsOneWidget);
      expect(harness.kitLook.recommendationCalls, 1);
      expect(harness.kitLook.previewCalls, 0);
      expect(harness.standard.calls, 0);
    });

    testWidgets('the plan wait hands over to the final preview wait', (
      tester,
    ) async {
      final harness = await _pumpKitPlanLoading(tester);

      harness.kitLook.completeRecommendation();
      await tester.pump();

      // Two stages, two screens. The plan wait ends when the plan arrives, and
      // the preview wait — its own shell, with its own copy — takes over. The
      // boundary between them is a real state transition, which is why it can
      // be asserted at all.
      expect(find.byType(MakeupPlanLoadingView), findsNothing);
      expect(find.byType(FinalPreviewLoadingView), findsOneWidget);
      expect(
        find.text(
          'Using your selected makeup products to create your preview.',
        ),
        findsOneWidget,
      );
      expect(harness.kitLook.previewCalls, 1);
      expect(harness.standard.calls, 0);
    });

    testWidgets('fits a narrow, short viewport at increased text scale', (
      tester,
    ) async {
      await _pumpKitPlanLoading(
        tester,
        size: const Size(360, 640),
        textScale: 1.6,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Creating your makeup plan'), findsOneWidget);
    });
  });

  group('Makeup plan loading — parity', () {
    testWidgets('both modes wait in one shell, differing only in copy', (
      tester,
    ) async {
      await _pumpStandardLoading(tester);
      final standard = tester.widget<MakeupPlanLoadingView>(
        find.byType(MakeupPlanLoadingView),
      );
      final standardCards = find.byType(AppColorSwatch).evaluate().length;
      final standardTitle = tester.widget<Text>(
        find.text('Creating your makeup plan'),
      );

      await _pumpKitPlanLoading(tester);
      final kit = tester.widget<MakeupPlanLoadingView>(
        find.byType(MakeupPlanLoadingView),
      );
      final kitCards = find.byType(AppColorSwatch).evaluate().length;
      final kitTitle = tester.widget<Text>(
        find.text('Creating your makeup plan'),
      );

      expect(kit.title, standard.title);
      expect(kitTitle.style, standardTitle.style);
      expect(kit.supportingText, isNot(standard.supportingText));

      // Same geometry from the same arithmetic. The kit reserves room for the
      // escape control it carries, so its run is one card shorter on the same
      // viewport — that is the same rule applied to different real content, not
      // a different rule.
      expect(standardCards, 5);
      expect(kitCards, 4);
    });

    testWidgets('placeholder cards are identical in both modes', (
      tester,
    ) async {
      await _pumpStandardLoading(tester);
      final standardCard = tester.getSize(find.byType(AppCard).first);

      await _pumpKitPlanLoading(tester);
      final kitCard = tester.getSize(find.byType(AppCard).first);

      expect(kitCard, standardCard);
    });
  });

  group('Makeup plan loading — skeleton density', () {
    testWidgets('a tall phone fills its viewport with about five cards', (
      tester,
    ) async {
      // POCO X3 GT geometry: 1080x2400 at 2.75x.
      await _pumpStandardLoading(tester, size: const Size(393, 873));

      expect(find.byType(AppColorSwatch), findsNWidgets(5));
      expect(tester.takeException(), isNull);

      // The run reaches the lower half rather than stopping a third of the way
      // down: the last card's bottom sits below the vertical midpoint.
      final viewport = tester.getRect(find.byType(MakeupPlanLoadingView));
      final lastCard = tester.getRect(find.byType(AppCard).last);
      expect(lastCard.bottom, greaterThan(viewport.center.dy));
      expect(lastCard.bottom, lessThanOrEqualTo(viewport.bottom));
    });

    testWidgets('a shorter phone draws fewer cards rather than overflowing', (
      tester,
    ) async {
      await _pumpStandardLoading(tester, size: const Size(360, 640));

      final count = find.byType(AppColorSwatch).evaluate().length;
      expect(count, lessThan(5));
      expect(
        count,
        greaterThanOrEqualTo(MakeupPlanLoadingView.minimumSections),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('increased text scale gives the header its room back', (
      tester,
    ) async {
      await _pumpStandardLoading(tester, size: const Size(393, 873));
      final atNormalScale = find.byType(AppColorSwatch).evaluate().length;

      await _pumpStandardLoading(
        tester,
        size: const Size(393, 873),
        textScale: 2,
      );
      final atLargeScale = find.byType(AppColorSwatch).evaluate().length;

      expect(atLargeScale, lessThanOrEqualTo(atNormalScale));
      expect(
        atLargeScale,
        greaterThanOrEqualTo(MakeupPlanLoadingView.minimumSections),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the count never exceeds the documented ceiling', (
      tester,
    ) async {
      await _pumpStandardLoading(tester, size: const Size(393, 2000));

      expect(
        find.byType(AppColorSwatch),
        findsNWidgets(MakeupPlanLoadingView.maximumSections),
      );
    });

    testWidgets('cards keep their real proportions rather than stretching', (
      tester,
    ) async {
      await _pumpStandardLoading(tester, size: const Size(393, 873));
      final onTallPhone = tester.getSize(find.byType(AppCard).first);

      await _pumpStandardLoading(tester, size: const Size(360, 640));
      final onShortPhone = tester.getSize(find.byType(AppCard).first);

      // A fixed card height is what makes the fit arithmetic exact: the loader
      // adds or removes cards, it never stretches them to fill space.
      expect(onTallPhone.height, onShortPhone.height);
      expect(onTallPhone.height, lessThan(140));
    });

    testWidgets('the kit reserves room for its escape control', (tester) async {
      await _pumpKitPlanLoading(tester, size: const Size(393, 873));

      final cancel = find.text('Cancel and change mode');
      expect(cancel, findsOneWidget);

      // On screen, not pushed below the fold by the placeholder run.
      final viewport = tester.getRect(find.byType(MakeupPlanLoadingView));
      expect(tester.getRect(cancel).bottom, lessThanOrEqualTo(viewport.bottom));
      expect(tester.takeException(), isNull);
    });
  });
}

// ---------------------------------------------------------------------------
// Makeup Recommendation harness
// ---------------------------------------------------------------------------

typedef _StandardHarness = ({_PendingRecommendations repository});

Future<_StandardHarness> _pumpStandardLoading(
  WidgetTester tester, {
  Size size = const Size(393, 873),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repository = _PendingRecommendations();
  final controller = MakeupRecommendationController(
    GenerateMakeupRecommendation(repository),
  );
  final analysis = FaceAnalysisDto.fromResponse(validAnalysisResponse).analysis;
  final style = MakeupStyleCatalog.styles.first;

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

  // Started exactly where the product starts it — from the mode the user chose,
  // before the page exists. Nothing on the page below causes this call.
  unawaited(controller.generate(analysis: analysis, style: style));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        makeupRecommendationControllerProvider.overrideWith(
          (ref) => controller,
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    ),
  );
  // Not pumpAndSettle: the skeleton pulses for as long as the wait lasts.
  await tester.pump();
  return (repository: repository);
}

class _PendingRecommendations implements MakeupRecommendationRepository {
  final _completer = Completer<MakeupRecommendation>();
  int calls = 0;
  FaceAnalysis? lastAnalysis;
  MakeupStyle? lastStyle;

  void complete() {
    _completer.complete(
      MakeupRecommendation(
        id: 'recommendation-1',
        analysisId: lastAnalysis!.id,
        styleCode: lastStyle!.code,
        overallIntensity: 'soft',
        items: const {
          'lipstick': MakeupRecommendationItem(
            name: 'Warm Rose',
            hex: '#B86F72',
            finish: 'matte',
            intensity: 'soft',
            placement: 'Across the lips',
            technique: 'Apply a thin layer',
            reasoning: 'Suits the detected undertone.',
          ),
        },
        modelId: 'test-model',
        promptVersion: 'test-prompt',
        createdAt: DateTime.utc(2026, 9, 6),
      ),
    );
  }

  void fail() => _completer.completeError(StateError('offline'));

  @override
  Future<MakeupRecommendation> generate({
    required FaceAnalysis analysis,
    required MakeupStyle style,
  }) {
    calls += 1;
    lastAnalysis = analysis;
    lastStyle = style;
    return _completer.future;
  }
}

// ---------------------------------------------------------------------------
// My Makeup Kit harness
// ---------------------------------------------------------------------------

typedef _KitHarness = ({
  _PendingKitLook kitLook,
  _CountingStandardRecommendations standard,
});

Future<_KitHarness> _pumpKitPlanLoading(
  WidgetTester tester, {
  Size size = const Size(393, 873),
  double textScale = 1,
}) async {
  // The kit reaches its plan wait through its own "Your kit is ready" screen,
  // which is not this task's surface and does not fit a 360x640 viewport at
  // 1.6x. So the journey runs at the default viewport and the constraint is
  // applied once the wait is on screen — which is the thing being measured.
  tester.view.physicalSize = const Size(393, 873);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final scale = ValueNotifier<double>(1);
  addTearDown(scale.dispose);

  final kitLook = _PendingKitLook();
  final standard = _CountingStandardRecommendations();
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
      .restore(MakeupStyleCatalog.styles.first);

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

  // The kit's own explicit start, from the control the user taps.
  await tester.tap(find.text('Create kit-based preview'));
  await tester.pump();

  if (size != const Size(393, 873) || textScale != 1) {
    tester.view.physicalSize = size;
    scale.value = textScale;
    await tester.pump();
  }
  return (kitLook: kitLook, standard: standard);
}

class _PendingKitLook implements MakeupKitLookRepository {
  final _recommendation = Completer<KitMakeupRecommendation>();
  final _preview = Completer<KitGeneratedPreview>();
  int recommendationCalls = 0;
  int previewCalls = 0;
  String? _analysisId;
  String? _styleCode;

  void completeRecommendation() => _recommendation.complete(
    KitMakeupRecommendation(
      id: 'kit-recommendation-1',
      analysisId: _analysisId!,
      styleCode: _styleCode!,
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
    ),
  );

  @override
  Future<KitMakeupRecommendation> generateRecommendation({
    required String analysisId,
    required String styleCode,
  }) {
    recommendationCalls += 1;
    _analysisId = analysisId;
    _styleCode = styleCode;
    return _recommendation.future;
  }

  @override
  Future<KitGeneratedPreview> generatePreview({
    required KitMakeupRecommendation recommendation,
  }) {
    previewCalls += 1;
    return _preview.future;
  }
}

/// Present only to be counted. Standard must not be reached from kit mode.
class _CountingStandardRecommendations
    implements MakeupRecommendationRepository {
  int calls = 0;

  @override
  Future<MakeupRecommendation> generate({
    required FaceAnalysis analysis,
    required MakeupStyle style,
  }) {
    calls += 1;
    throw StateError('The kit plan must never request a Standard plan.');
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
