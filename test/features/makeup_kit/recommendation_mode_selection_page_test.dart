import 'package:facetune/core/constants/app_constants.dart';
import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_products_providers.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_look_providers.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_generated_preview.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_product.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_recommendation_mode.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_products_repository.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_look_repository.dart';
import 'package:facetune/features/makeup_kit/domain/value_objects/normalized_hex_color.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_recommendation_mode_controller.dart';
import 'package:facetune/features/makeup_kit/presentation/pages/makeup_kit_recommendation_entry_page.dart';
import 'package:facetune/features/makeup_kit/presentation/pages/recommendation_mode_selection_page.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/makeup_styles/domain/entities/makeup_style.dart';
import 'package:facetune/features/makeup_styles/presentation/controllers/makeup_style_selection_controller.dart';
import 'package:facetune/features/recommendation/data/models/makeup_recommendation_dto.dart';
import 'package:facetune/features/recommendation/data/providers/recommendation_providers.dart';
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/recommendation/domain/repositories/makeup_recommendation_repository.dart';
import 'package:facetune/features/analysis/presentation/controllers/face_analysis_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/analysis_response_fixture.dart';
import '../../helpers/fake_auth_repository.dart';
import '../../helpers/recommendation_response_fixture.dart';

Future<
  ({
    ProviderContainer container,
    _FakeRecommendationRepository recommendation,
    _FakeKitLookRepository kitLook,
  })
>
_pump(WidgetTester tester, {required bool hasProduct}) async {
  final recommendation = _FakeRecommendationRepository();
  final kitLook = _FakeKitLookRepository();
  final container = ProviderContainer(
    overrides: [
      supabaseAvailableProvider.overrideWithValue(false),
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(
          user: const AuthUser(id: 'user-1', isAnonymous: false),
        ),
      ),
      makeupKitProductsRepositoryProvider.overrideWithValue(
        _FakeKitRepository(hasProduct: hasProduct),
      ),
      makeupKitLookRepositoryProvider.overrideWithValue(kitLook),
      makeupRecommendationRepositoryProvider.overrideWithValue(recommendation),
    ],
  );
  addTearDown(container.dispose);
  container
      .read(faceAnalysisControllerProvider.notifier)
      .restore(FaceAnalysisDto.fromResponse(validAnalysisResponse).analysis);
  container
      .read(makeupStyleSelectionControllerProvider.notifier)
      .restore(
        MakeupStyleCatalog.styles.firstWhere(
          (style) => style.code == 'soft_glam',
        ),
      );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: AppConstants.recommendationModeRoute,
          routes: [
            GoRoute(
              path: AppConstants.recommendationModeRoute,
              builder: (context, state) =>
                  const RecommendationModeSelectionPage(),
            ),
            GoRoute(
              path: AppConstants.recommendationRoute,
              builder: (context, state) =>
                  const Scaffold(body: Text('Existing recommendation route')),
            ),
            GoRoute(
              path: AppConstants.makeupKitRecommendationEntryRoute,
              builder: (context, state) =>
                  const MakeupKitRecommendationEntryPage(),
            ),
            GoRoute(
              path: AppConstants.makeupKitAddProductRoute,
              builder: (context, state) =>
                  const Scaffold(body: Text('Add Product Form')),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (
    container: container,
    recommendation: recommendation,
    kitLook: kitLook,
  );
}

void main() {
  testWidgets('standard mode uses the existing generation path unchanged', (
    tester,
  ) async {
    final harness = await _pump(tester, hasProduct: true);

    await tester.tap(find.text('Use Makeup Recommendation'));
    await tester.pumpAndSettle();

    expect(harness.recommendation.calls, 1);
    expect(harness.recommendation.lastStyle?.code, 'soft_glam');
    expect(
      harness.container.read(makeupRecommendationModeControllerProvider),
      MakeupRecommendationMode.standard,
    );
    expect(find.text('Existing recommendation route'), findsOneWidget);
  });

  testWidgets('non-empty kit enters the isolated kit boundary', (tester) async {
    final harness = await _pump(tester, hasProduct: true);

    expect(find.textContaining('1 product you already own'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use My Makeup Kit'));
    await tester.pumpAndSettle();

    expect(harness.recommendation.calls, 0);
    expect(
      harness.container.read(makeupRecommendationModeControllerProvider),
      MakeupRecommendationMode.makeupKit,
    );
    expect(find.text('Your kit is ready'), findsOneWidget);
    expect(find.text('Change mode'), findsOneWidget);
  });

  testWidgets('kit entry generates through the isolated preview pipeline', (
    tester,
  ) async {
    final harness = await _pump(tester, hasProduct: true);

    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use My Makeup Kit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create kit-based preview'));
    await tester.pumpAndSettle();

    expect(harness.recommendation.calls, 0);
    expect(harness.kitLook.recommendationCalls, 1);
    expect(harness.kitLook.previewCalls, 1);
    expect(find.text('Your kit-based preview'), findsOneWidget);
  });

  testWidgets(
    'empty kit offers Add Product and keeps standard mode available',
    (tester) async {
      await _pump(tester, hasProduct: false);

      expect(find.text('Use Makeup Recommendation'), findsOneWidget);
      expect(
        find.text('Add at least one product before creating a kit-based look.'),
        findsOneWidget,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Product'));
      await tester.pumpAndSettle();
      expect(find.text('Add Product Form'), findsOneWidget);
    },
  );
}

class _FakeRecommendationRepository implements MakeupRecommendationRepository {
  int calls = 0;
  MakeupStyle? lastStyle;

  @override
  Future<MakeupRecommendation> generate({
    required analysis,
    required MakeupStyle style,
  }) async {
    calls++;
    lastStyle = style;
    return MakeupRecommendationDto.fromResponse(
      validRecommendationResponse,
    ).recommendation;
  }
}

class _FakeKitRepository implements MakeupKitProductsRepository {
  _FakeKitRepository({required this.hasProduct});

  final bool hasProduct;

  List<MakeupKitProduct> get _items => hasProduct
      ? [
          MakeupKitProduct(
            id: 'product-1',
            userId: 'user-1',
            category: MakeupKitCategory.lipstick,
            color: NormalizedHexColor.parse('#B86F72'),
            finish: MakeupKitFinish.matte,
            createdAt: DateTime.utc(2026, 8, 13),
            updatedAt: DateTime.utc(2026, 8, 13),
          ),
        ]
      : const [];

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

class _FakeKitLookRepository implements MakeupKitLookRepository {
  int recommendationCalls = 0;
  int previewCalls = 0;

  @override
  Future<KitMakeupRecommendation> generateRecommendation({
    required String analysisId,
    required String styleCode,
  }) async {
    recommendationCalls++;
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
      overallIntensity: 'soft',
      summary: 'A soft look using your lipstick.',
      modelId: 'gemini-3.6-flash',
      promptVersion: 'kit_makeup_recommendation_v2',
      createdAt: DateTime.utc(2026, 8, 13),
    );
  }

  @override
  Future<KitGeneratedPreview> generatePreview({
    required KitMakeupRecommendation recommendation,
  }) async {
    previewCalls++;
    return KitGeneratedPreview(
      id: 'kit-preview-1',
      analysisId: recommendation.analysisId,
      kitRecommendationId: recommendation.id,
      originalImagePath: 'user/analyses/id/original/image.jpg',
      generatedImagePath: 'user/analyses/id/kit-generated/preview.png',
      originalImageUrl: 'https://signed.example/original',
      generatedImageUrl: 'https://signed.example/generated',
      generationNumber: 1,
      modelId: 'gemini-3.1-flash-image',
      promptVersion: 'kit_makeup_preview_v1',
      createdAt: DateTime.utc(2026, 8, 13),
    );
  }
}
