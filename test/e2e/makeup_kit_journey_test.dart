import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/analysis/data/providers/analysis_providers.dart';
import 'package:facetune/features/analysis/domain/entities/face_analysis.dart';
import 'package:facetune/features/analysis/domain/repositories/face_analysis_repository.dart';
import 'package:facetune/features/analysis/presentation/controllers/face_analysis_controller.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_library_providers.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_look_providers.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_products_providers.dart';
import 'package:facetune/features/makeup_kit/domain/entities/foundation_depth.dart';
import 'package:facetune/features/makeup_kit/domain/entities/foundation_undertone.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_generated_preview.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_look_result.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_product.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_recommendation_mode.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_library_repository.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_look_repository.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_products_repository.dart';
import 'package:facetune/features/makeup_kit/domain/validation/makeup_kit_product_validator.dart';
import 'package:facetune/features/makeup_kit/domain/value_objects/normalized_hex_color.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_history_controller.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_library_state.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_look_controller.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_look_state.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_products_controller.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_result_actions_controller.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_saved_controller.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_recommendation_mode_controller.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/makeup_styles/presentation/controllers/makeup_style_selection_controller.dart';
import 'package:facetune/features/preview/domain/errors/preview_failure.dart';
import 'package:facetune/features/scan/data/providers/image_validation_repository_provider.dart';
import 'package:facetune/features/scan/data/providers/selfie_repository_provider.dart';
import 'package:facetune/features/scan/domain/entities/local_image_validation.dart';
import 'package:facetune/features/scan/domain/entities/prepared_selfie.dart';
import 'package:facetune/features/scan/domain/entities/selfie_source.dart';
import 'package:facetune/features/scan/domain/repositories/image_validation_repository.dart';
import 'package:facetune/features/scan/domain/repositories/selfie_repository.dart';
import 'package:facetune/features/scan/presentation/controllers/scan_controller.dart';
import 'package:facetune/features/scan/presentation/controllers/scan_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/analysis_response_fixture.dart';
import '../helpers/fake_auth_repository.dart';

/// MK-13 connected regression coverage for the additive My Makeup Kit path.
///
/// Real controllers and provider wiring are exercised in one container. Only
/// repository boundaries are replaced, keeping ordinary tests deterministic,
/// account-scoped, and free of paid Gemini or live Supabase calls.
void main() {
  late _KitJourneyHarness harness;

  setUp(() => harness = _KitJourneyHarness());
  tearDown(() => harness.dispose());

  test(
    'authenticated inventory to preview, save, history, and reopen',
    () async {
      await harness.signIn();
      final products = harness.container.read(
        makeupKitProductsControllerProvider.notifier,
      );
      await products.load();

      expect(await products.createProduct(_foundationDraft()), isTrue);
      expect(
        await products.createProduct(
          _draft(
            MakeupKitCategory.lipstick,
            '#B86F72',
            MakeupKitFinish.cream,
            name: 'Nude Rose',
          ),
        ),
        isTrue,
      );
      expect(
        await products.createProduct(
          _draft(
            MakeupKitCategory.lipstick,
            '#8A2635',
            MakeupKitFinish.matte,
            name: 'Deep Red',
          ),
        ),
        isTrue,
      );
      expect(
        await products.createProduct(
          _draft(
            MakeupKitCategory.blush,
            '#E69A7A',
            MakeupKitFinish.satin,
            name: 'Warm Peach',
          ),
        ),
        isTrue,
      );
      expect(
        await products.createProduct(
          _draft(
            MakeupKitCategory.eyeshadow,
            '#806252',
            MakeupKitFinish.shimmer,
            name: 'Soft Bronze',
          ),
        ),
        isTrue,
      );

      var inventory = harness.container
          .read(makeupKitProductsControllerProvider)
          .items;
      expect(inventory, hasLength(5));
      expect(
        inventory.where((item) => item.category == MakeupKitCategory.lipstick),
        hasLength(2),
      );

      final deepRed = inventory.firstWhere(
        (item) => item.productName == 'Deep Red',
      );
      expect(
        await products.updateProduct(
          deepRed.id,
          _draft(
            MakeupKitCategory.lipstick,
            '#7A1F32',
            MakeupKitFinish.satin,
            name: 'Evening Red',
          ),
        ),
        isTrue,
      );
      final blush = harness.container
          .read(makeupKitProductsControllerProvider)
          .items
          .firstWhere((item) => item.category == MakeupKitCategory.blush);
      expect(await products.deleteProduct(blush.id), isTrue);

      final analysis = await harness.scanAndAnalyze();
      final style = MakeupStyleCatalog.styles.firstWhere(
        (candidate) => candidate.code == 'soft_glam',
      );
      final styleController = harness.container.read(
        makeupStyleSelectionControllerProvider.notifier,
      );
      styleController.select(style);
      styleController.confirm();
      harness.container
          .read(makeupRecommendationModeControllerProvider.notifier)
          .select(MakeupRecommendationMode.makeupKit);

      final lookController = harness.container.read(
        makeupKitLookControllerProvider.notifier,
      );
      await lookController.generate(
        analysisId: analysis.id,
        styleCode: style.code,
      );
      final lookState = harness.container.read(makeupKitLookControllerProvider);
      expect(lookState.status, MakeupKitLookStatus.success);
      expect(lookState.preview, isNotNull);

      inventory = harness.container
          .read(makeupKitProductsControllerProvider)
          .items;
      final ownedIds = inventory.map((item) => item.id).toSet();
      final selectedIds = lookState.recommendation!.selections
          .map((selection) => selection.productId)
          .toSet();
      expect(selectedIds, isNotEmpty);
      expect(selectedIds.difference(ownedIds), isEmpty);
      expect(
        lookState.recommendation!.productSnapshots
            .firstWhere((item) => item.productName == 'Evening Red')
            .colorHex,
        '#7A1F32',
      );
      expect(
        lookState.preview!.generatedImagePath,
        isNot(lookState.preview!.originalImagePath),
      );

      final actions = harness.container.read(
        makeupKitResultActionsControllerProvider.notifier,
      );
      await actions.toggleSaved(lookState.preview!);
      expect(
        harness.container
            .read(makeupKitResultActionsControllerProvider)
            .isSaved(lookState.preview!.id),
        isTrue,
      );

      final saved = harness.container.read(
        makeupKitSavedControllerProvider.notifier,
      );
      await saved.loadInitial();
      expect(
        harness.container.read(makeupKitSavedControllerProvider).items,
        hasLength(1),
      );

      final historySubscription = harness.container.listen(
        makeupKitHistoryControllerProvider,
        (_, _) {},
      );
      addTearDown(historySubscription.close);
      final history = harness.container.read(
        makeupKitHistoryControllerProvider.notifier,
      );
      await history.loadInitial();
      final historyState = harness.container.read(
        makeupKitHistoryControllerProvider,
      );
      expect(historyState.status, MakeupKitLibraryStatus.ready);
      expect(historyState.items, hasLength(1));

      // Historical snapshots must remain understandable after the underlying
      // selected product is removed from the active inventory.
      expect(await products.deleteProduct(deepRed.id), isTrue);
      final historical = historyState.items.single.result;
      expect(
        historical.recommendation.productSnapshots
            .firstWhere((item) => item.productId == deepRed.id)
            .productName,
        'Evening Red',
      );

      harness.container.read(faceAnalysisControllerProvider.notifier).clear();
      harness.container.read(makeupKitLookControllerProvider.notifier).clear();
      harness.container
          .read(makeupRecommendationModeControllerProvider.notifier)
          .clear();

      harness.container
          .read(faceAnalysisControllerProvider.notifier)
          .restore(historical.analysis);
      harness.container
          .read(makeupStyleSelectionControllerProvider.notifier)
          .restore(historical.style);
      harness.container
          .read(makeupRecommendationModeControllerProvider.notifier)
          .select(MakeupRecommendationMode.makeupKit);
      harness.container
          .read(makeupKitLookControllerProvider.notifier)
          .restore(
            recommendation: historical.recommendation,
            preview: historical.preview,
          );

      expect(
        harness.container.read(faceAnalysisControllerProvider).analysis?.id,
        historical.analysis.id,
      );
      expect(
        harness.container.read(makeupKitLookControllerProvider).preview?.id,
        historical.preview.id,
      );
      expect(
        harness.container.read(makeupRecommendationModeControllerProvider),
        MakeupRecommendationMode.makeupKit,
      );
    },
  );

  test(
    'empty kit fails honestly without invoking preview generation',
    () async {
      await harness.signIn();
      final controller = harness.container.read(
        makeupKitLookControllerProvider.notifier,
      );

      await controller.generate(
        analysisId: _analysis.id,
        styleCode: 'soft_glam',
      );

      final state = harness.container.read(makeupKitLookControllerProvider);
      expect(state.status, MakeupKitLookStatus.failure);
      expect(state.technicalCode, 'EMPTY_KIT');
      expect(harness.looks.previewCalls, 0);
    },
  );

  test('one-product incomplete kit selects only that owned product', () async {
    await harness.signIn();
    final products = harness.container.read(
      makeupKitProductsControllerProvider.notifier,
    );
    await products.load();
    expect(
      await products.createProduct(
        _draft(
          MakeupKitCategory.lipstick,
          '#B86F72',
          MakeupKitFinish.cream,
          name: 'Only Lipstick',
        ),
      ),
      isTrue,
    );

    await harness.container
        .read(makeupKitLookControllerProvider.notifier)
        .generate(analysisId: _analysis.id, styleCode: 'natural');

    final recommendation = harness.container
        .read(makeupKitLookControllerProvider)
        .recommendation!;
    expect(recommendation.selections, hasLength(1));
    expect(recommendation.selections.single.category, 'lipstick');
    expect(
      recommendation.selections.single.productId,
      harness.products.items.single.id,
    );
  });
}

final _analysis = FaceAnalysisDto.fromResponse(validAnalysisResponse).analysis;

MakeupKitProductDraft _foundationDraft() => MakeupKitProductDraft(
  category: MakeupKitCategory.foundation,
  productName: 'Everyday Foundation',
  color: NormalizedHexColor.parse('#C99578'),
  colorLabel: 'Warm Beige',
  finish: MakeupKitFinish.natural,
  foundationDepth: FoundationDepth.medium,
  foundationUndertone: FoundationUndertone.warm,
);

MakeupKitProductDraft _draft(
  MakeupKitCategory category,
  String color,
  MakeupKitFinish finish, {
  String? name,
}) => MakeupKitProductDraft(
  category: category,
  productName: name,
  color: NormalizedHexColor.parse(color),
  colorLabel: name,
  finish: finish,
);

class _KitJourneyHarness {
  _KitJourneyHarness() : auth = FakeAuthRepository() {
    looks = _FakeKitLookRepository(products);
    library = _FakeKitLibraryRepository(looks);
    container = ProviderContainer(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(auth),
        selfieRepositoryProvider.overrideWithValue(selfies),
        imageValidationRepositoryProvider.overrideWithValue(validation),
        faceAnalysisRepositoryProvider.overrideWithValue(analyses),
        makeupKitProductsRepositoryProvider.overrideWithValue(products),
        makeupKitLookRepositoryProvider.overrideWithValue(looks),
        makeupKitLibraryRepositoryProvider.overrideWithValue(library),
      ],
    );
  }

  final FakeAuthRepository auth;
  final _FakeSelfieRepository selfies = _FakeSelfieRepository();
  final _FakeValidationRepository validation = _FakeValidationRepository();
  final _FakeAnalysisRepository analyses = _FakeAnalysisRepository();
  final _FakeKitProductsRepository products = _FakeKitProductsRepository();
  late final _FakeKitLookRepository looks;
  late final _FakeKitLibraryRepository library;
  late final ProviderContainer container;

  Future<void> signIn() async {
    await container
        .read(authControllerProvider.notifier)
        .signInWithEmail(email: 'kit@example.com', password: 'valid-password');
    products.userId = container.read(authControllerProvider).user!.id;
  }

  Future<FaceAnalysis> scanAndAnalyze() async {
    final scan = container.read(scanControllerProvider.notifier);
    expect(await scan.chooseFromGallery(), isTrue);
    await scan.validateForAnalysis();
    final scanState = container.read(scanControllerProvider);
    expect(scanState.stage, ScanStage.readyForSecureValidation);
    await container
        .read(faceAnalysisControllerProvider.notifier)
        .analyze(
          selfie: scanState.selfie!,
          localValidation: scanState.localValidation!,
        );
    return container.read(faceAnalysisControllerProvider).analysis!;
  }

  void dispose() {
    container.dispose();
    auth.dispose();
  }
}

class _FakeSelfieRepository implements SelfieRepository {
  @override
  Future<PreparedSelfie?> acquire(SelfieSource source) async => PreparedSelfie(
    originalPath: 'original.jpg',
    uploadPath: 'upload.jpg',
    originalSizeBytes: 2000,
    uploadSizeBytes: 900,
    source: source,
  );

  @override
  Future<void> discard(PreparedSelfie selfie) async {}

  @override
  Future<bool> openPermissionSettings() async => true;
}

class _FakeValidationRepository implements ImageValidationRepository {
  @override
  Future<LocalImageValidation> validateLocal(PreparedSelfie selfie) async =>
      const LocalImageValidation(
        mimeType: 'image/jpeg',
        width: 1080,
        height: 1440,
        originalSizeBytes: 2000,
        uploadSizeBytes: 900,
      );
}

class _FakeAnalysisRepository implements FaceAnalysisRepository {
  @override
  Future<FaceAnalysis> analyze({
    required PreparedSelfie selfie,
    required LocalImageValidation localValidation,
    required void Function(AnalysisProgress progress) onProgress,
  }) async {
    onProgress(AnalysisProgress.uploading);
    onProgress(AnalysisProgress.secureProcessing);
    return _analysis;
  }
}

class _FakeKitProductsRepository implements MakeupKitProductsRepository {
  final items = <MakeupKitProduct>[];
  String? userId;
  int _sequence = 0;

  @override
  Future<List<MakeupKitProduct>> loadAll() async => List.unmodifiable(items);

  @override
  Future<List<MakeupKitProduct>> loadByCategory(
    MakeupKitCategory category,
  ) async =>
      List.unmodifiable(items.where((item) => item.category == category));

  @override
  Future<MakeupKitProduct> create(MakeupKitProductDraft draft) async {
    MakeupKitProductValidator.validate(draft);
    final product = _product('product-${++_sequence}', draft);
    items.add(product);
    return product;
  }

  @override
  Future<MakeupKitProduct> update(
    String productId,
    MakeupKitProductDraft draft,
  ) async {
    MakeupKitProductValidator.validate(draft);
    final index = items.indexWhere((item) => item.id == productId);
    if (index < 0) throw StateError('Product not found.');
    final product = _product(productId, draft);
    items[index] = product;
    return product;
  }

  @override
  Future<void> delete(String productId) async {
    items.removeWhere((item) => item.id == productId);
  }

  MakeupKitProduct _product(String id, MakeupKitProductDraft draft) {
    final now = DateTime.utc(2026, 8, 14, 1, _sequence);
    return MakeupKitProduct(
      id: id,
      userId: userId!,
      category: draft.category,
      productName: draft.productName,
      color: draft.color,
      colorLabel: draft.colorLabel,
      finish: draft.finish,
      foundationDepth: draft.foundationDepth,
      foundationUndertone: draft.foundationUndertone,
      createdAt: now,
      updatedAt: now,
    );
  }
}

class _FakeKitLookRepository implements MakeupKitLookRepository {
  _FakeKitLookRepository(this.products);

  final _FakeKitProductsRepository products;
  KitMakeupRecommendation? latestRecommendation;
  KitGeneratedPreview? latestPreview;
  int previewCalls = 0;

  @override
  Future<KitMakeupRecommendation> generateRecommendation({
    required String analysisId,
    required String styleCode,
  }) async {
    if (products.items.isEmpty) {
      throw const PreviewFailure(
        PreviewFailureType.validation,
        'Add at least one valid product to My Makeup Kit.',
        technicalCode: 'EMPTY_KIT',
      );
    }
    final selections = products.items.map(_selection).toList(growable: false);
    final snapshots = products.items.map(_snapshot).toList(growable: false);
    return latestRecommendation = KitMakeupRecommendation(
      id: 'kit-recommendation-1',
      analysisId: analysisId,
      styleCode: styleCode,
      selections: selections,
      productSnapshots: snapshots,
      overallIntensity: 'soft',
      summary: 'A truthful look made only from registered products.',
      modelId: 'mock-gemini',
      promptVersion: 'kit_makeup_recommendation_v2',
      createdAt: DateTime.utc(2026, 8, 14),
    );
  }

  @override
  Future<KitGeneratedPreview> generatePreview({
    required KitMakeupRecommendation recommendation,
  }) async {
    previewCalls += 1;
    for (final selection in recommendation.selections) {
      final product = products.items
          .where((candidate) => candidate.id == selection.productId)
          .firstOrNull;
      if (product == null ||
          product.category.code != selection.category ||
          product.color.value != selection.colorHex ||
          product.finish.code != selection.finish) {
        throw const PreviewFailure(
          PreviewFailureType.validation,
          'A selected product was edited or removed.',
          technicalCode: 'INVENTORY_CHANGED',
        );
      }
    }
    return latestPreview = KitGeneratedPreview(
      id: 'kit-preview-$previewCalls',
      analysisId: recommendation.analysisId,
      kitRecommendationId: recommendation.id,
      originalImagePath:
          'user/analyses/${recommendation.analysisId}/original/image.jpg',
      generatedImagePath:
          'user/analyses/${recommendation.analysisId}/kit-generated/'
          '${recommendation.id}/preview_$previewCalls.png',
      originalImageUrl: 'https://signed.example/original',
      generatedImageUrl: 'https://signed.example/kit-preview-$previewCalls',
      generationNumber: previewCalls,
      modelId: 'mock-image-model',
      promptVersion: 'kit_makeup_preview_v1',
      createdAt: DateTime.utc(2026, 8, 14),
    );
  }

  KitMakeupSelection _selection(MakeupKitProduct product) => KitMakeupSelection(
    productId: product.id,
    category: product.category.code,
    colorHex: product.color.value,
    finish: product.finish.code,
    placement: 'Apply to the ${product.category.code}.',
    technique: 'Blend lightly.',
    intensity: 'soft',
  );

  KitProductSnapshot _snapshot(MakeupKitProduct product) => KitProductSnapshot(
    productId: product.id,
    category: product.category.code,
    productName: product.productName,
    colorHex: product.color.value,
    colorLabel: product.colorLabel,
    finish: product.finish.code,
    foundationDepth: product.foundationDepth?.code,
    foundationUndertone: product.foundationUndertone?.code,
  );
}

class _FakeKitLibraryRepository implements MakeupKitLibraryRepository {
  _FakeKitLibraryRepository(this.looks);

  final _FakeKitLookRepository looks;
  final saved = <String, KitSavedLook>{};

  KitLookResult _result(KitGeneratedPreview preview) {
    final recommendation = looks.latestRecommendation!;
    final style = MakeupStyleCatalog.styles.firstWhere(
      (candidate) => candidate.code == recommendation.styleCode,
    );
    return KitLookResult(
      analysis: _analysis,
      style: style,
      recommendation: recommendation,
      preview: preview,
    );
  }

  @override
  Future<KitSavedLook?> findSaved(String kitGeneratedImageId) async => saved
      .values
      .where((look) => look.result.preview.id == kitGeneratedImageId)
      .firstOrNull;

  @override
  Future<KitSavedLook> save(
    KitGeneratedPreview preview, {
    bool favorite = false,
  }) async {
    final look = KitSavedLook(
      id: 'kit-saved-${saved.length + 1}',
      result: _result(preview),
      isFavorite: favorite,
      createdAt: DateTime.utc(2026, 8, 14),
    );
    saved[look.id] = look;
    return look;
  }

  @override
  Future<KitSavedLook> setFavorite(KitSavedLook look, bool isFavorite) async {
    final updated = look.copyWith(isFavorite: isFavorite);
    saved[look.id] = updated;
    return updated;
  }

  @override
  Future<void> removeSaved(String savedLookId) async {
    saved.remove(savedLookId);
  }

  @override
  Future<KitSavedLooksPageResult> loadSavedPage({
    required int offset,
    required int limit,
  }) async => KitSavedLooksPageResult(
    items: saved.values.skip(offset).take(limit).toList(growable: false),
    hasMore: false,
  );

  @override
  Future<KitHistoryPageResult> loadHistoryPage({
    required int offset,
    required int limit,
  }) async {
    final preview = looks.latestPreview;
    if (preview == null) {
      return const KitHistoryPageResult(items: [], hasMore: false);
    }
    final savedLook = await findSaved(preview.id);
    return KitHistoryPageResult(
      items: [
        KitHistoryEntry(result: _result(preview), savedLook: savedLook),
      ].skip(offset).take(limit).toList(growable: false),
      hasMore: false,
    );
  }

  @override
  Future<void> deleteSession(String analysisId) async {
    saved.removeWhere((_, look) => look.result.analysis.id == analysisId);
  }
}
