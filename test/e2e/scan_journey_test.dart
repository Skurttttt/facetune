import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/analysis/data/providers/analysis_providers.dart';
import 'package:facetune/features/analysis/domain/entities/face_analysis.dart';
import 'package:facetune/features/analysis/domain/errors/analysis_failure.dart';
import 'package:facetune/features/analysis/domain/repositories/face_analysis_repository.dart';
import 'package:facetune/features/analysis/presentation/controllers/face_analysis_controller.dart';
import 'package:facetune/features/analysis/presentation/controllers/face_analysis_state.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/makeup_styles/domain/entities/makeup_style.dart';
import 'package:facetune/features/makeup_styles/presentation/controllers/makeup_style_selection_controller.dart';
import 'package:facetune/features/preview/data/models/generated_preview_dto.dart';
import 'package:facetune/features/preview/data/providers/preview_providers.dart';
import 'package:facetune/features/preview/domain/entities/generated_preview.dart';
import 'package:facetune/features/preview/domain/errors/preview_failure.dart';
import 'package:facetune/features/preview/domain/repositories/makeup_preview_repository.dart';
import 'package:facetune/features/preview/presentation/controllers/makeup_preview_controller.dart';
import 'package:facetune/features/preview/presentation/controllers/makeup_preview_state.dart';
import 'package:facetune/features/recommendation/data/models/makeup_recommendation_dto.dart';
import 'package:facetune/features/recommendation/data/providers/recommendation_providers.dart';
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/recommendation/domain/repositories/makeup_recommendation_repository.dart';
import 'package:facetune/features/recommendation/presentation/controllers/makeup_recommendation_controller.dart';
import 'package:facetune/features/results/presentation/controllers/result_actions_controller.dart';
import 'package:facetune/features/saved_looks/data/providers/saved_looks_providers.dart';
import 'package:facetune/features/saved_looks/domain/entities/saved_look.dart';
import 'package:facetune/features/saved_looks/domain/repositories/saved_looks_repository.dart';
import 'package:facetune/features/scan/data/providers/image_validation_repository_provider.dart';
import 'package:facetune/features/scan/data/providers/selfie_repository_provider.dart';
import 'package:facetune/features/scan/domain/entities/local_image_validation.dart';
import 'package:facetune/features/scan/domain/entities/prepared_selfie.dart';
import 'package:facetune/features/scan/domain/entities/selfie_source.dart';
import 'package:facetune/features/scan/domain/errors/image_validation_failure.dart';
import 'package:facetune/features/scan/domain/repositories/image_validation_repository.dart';
import 'package:facetune/features/scan/domain/repositories/selfie_repository.dart';
import 'package:facetune/features/scan/presentation/controllers/scan_controller.dart';
import 'package:facetune/features/scan/presentation/controllers/scan_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/analysis_response_fixture.dart';
import '../helpers/fake_auth_repository.dart';
import '../helpers/generated_preview_response_fixture.dart';
import '../helpers/recommendation_response_fixture.dart';

/// Phase 21 — end-to-end validation of the connected workflow.
///
/// These journeys drive the real controllers and use cases through a single
/// [ProviderContainer], overriding only the repository boundary. That exercises
/// the wiring between features — the seams the per-feature test suites never
/// cross — and asserts the referential chain the result screen depends on.
void main() {
  final softGlam = MakeupStyleCatalog.styles.firstWhere(
    (style) => style.code == 'soft_glam',
  );

  late _Harness harness;

  setUp(() => harness = _Harness());
  tearDown(() => harness.dispose());

  /// Drives selfie -> validation -> analysis -> style -> recommendation ->
  /// preview and returns the resulting preview.
  Future<GeneratedPreview> runFullJourney(_Harness harness) async {
    final scan = harness.container.read(scanControllerProvider.notifier);
    expect(await scan.chooseFromGallery(), isTrue);
    await scan.validateForAnalysis();
    expect(
      harness.container.read(scanControllerProvider).stage,
      ScanStage.readyForSecureValidation,
    );

    final scanState = harness.container.read(scanControllerProvider);
    await harness.container
        .read(faceAnalysisControllerProvider.notifier)
        .analyze(
          selfie: scanState.selfie!,
          localValidation: scanState.localValidation!,
        );
    final analysis = harness.container
        .read(faceAnalysisControllerProvider)
        .analysis;
    expect(analysis, isNotNull);

    harness.container
        .read(makeupStyleSelectionControllerProvider.notifier)
        .select(softGlam);
    harness.container
        .read(makeupStyleSelectionControllerProvider.notifier)
        .confirm();

    await harness.container
        .read(makeupRecommendationControllerProvider.notifier)
        .generate(analysis: analysis!, style: softGlam);
    final recommendation = harness.container
        .read(makeupRecommendationControllerProvider)
        .recommendation;
    expect(recommendation, isNotNull);

    await harness.container
        .read(makeupPreviewControllerProvider.notifier)
        .generate(recommendation: recommendation!);
    final preview = harness.container
        .read(makeupPreviewControllerProvider)
        .preview;
    expect(preview, isNotNull);
    return preview!;
  }

  group('journey 1 — new authenticated user completes a full scan', () {
    test('every stage reaches success and links to the previous one', () async {
      final preview = await runFullJourney(harness);

      final analysis = harness.container
          .read(faceAnalysisControllerProvider)
          .analysis!;
      final recommendation = harness.container
          .read(makeupRecommendationControllerProvider)
          .recommendation!;
      final style = harness.container
          .read(makeupStyleSelectionControllerProvider)
          .selectedStyle!;

      // This is exactly the guard PreviewResultPage requires before it will
      // render a result, so a journey that fails it would dead-end the user.
      expect(recommendation.analysisId, analysis.id);
      expect(preview.analysisId, analysis.id);
      expect(preview.recommendationId, recommendation.id);
      expect(style.code, recommendation.styleCode);
    });

    test('storage paths stay under the analysis that owns them', () async {
      final preview = await runFullJourney(harness);
      final analysis = harness.container
          .read(faceAnalysisControllerProvider)
          .analysis!;
      final recommendation = harness.container
          .read(makeupRecommendationControllerProvider)
          .recommendation!;

      expect(
        preview.originalImagePath,
        contains('/analyses/${analysis.id}/original/'),
      );
      expect(
        preview.generatedImagePath,
        contains('/analyses/${analysis.id}/generated/${recommendation.id}/'),
      );
      // The original must never be the generation target.
      expect(preview.generatedImagePath, isNot(contains('/original/')));
      expect(preview.generatedImagePath, isNot(preview.originalImagePath));
    });

    test(
      'saving the result links the saved look to the generated preview',
      () async {
        final preview = await runFullJourney(harness);
        final actions = harness.container.read(
          resultActionsControllerProvider.notifier,
        );

        await actions.toggleSaved(preview);

        final saved = harness.savedLooks.stored.values.single;
        expect(saved.preview.id, preview.id);
        expect(saved.recommendation.id, preview.recommendationId);
        expect(saved.analysis.id, preview.analysisId);
        expect(
          harness.container
              .read(resultActionsControllerProvider)
              .isSaved(preview.id),
          isTrue,
        );
      },
    );

    test('reopening from history restores a consistent workflow', () async {
      final preview = await runFullJourney(harness);
      final analysis = harness.container
          .read(faceAnalysisControllerProvider)
          .analysis!;
      final recommendation = harness.container
          .read(makeupRecommendationControllerProvider)
          .recommendation!;

      // Simulate leaving the workflow, then reopening the saved session.
      harness.container.read(faceAnalysisControllerProvider.notifier).clear();
      harness.container
          .read(makeupRecommendationControllerProvider.notifier)
          .clear();
      harness.container.read(makeupPreviewControllerProvider.notifier).clear();
      expect(
        harness.container.read(makeupPreviewControllerProvider).preview,
        isNull,
      );

      harness.container
          .read(faceAnalysisControllerProvider.notifier)
          .restore(analysis);
      harness.container
          .read(makeupRecommendationControllerProvider.notifier)
          .restore(recommendation);
      harness.container
          .read(makeupStyleSelectionControllerProvider.notifier)
          .select(softGlam);
      harness.container
          .read(makeupPreviewControllerProvider.notifier)
          .restore(preview, recommendation: recommendation);

      final restoredAnalysis = harness.container
          .read(faceAnalysisControllerProvider)
          .analysis!;
      final restoredPreview = harness.container
          .read(makeupPreviewControllerProvider)
          .preview!;
      expect(restoredPreview.analysisId, restoredAnalysis.id);
      expect(restoredPreview.recommendationId, recommendation.id);
      expect(
        harness.container.read(makeupPreviewControllerProvider).status,
        MakeupPreviewStatus.success,
      );
    });
  });

  group('journey 2 — returning user restores a session and rescans', () {
    test(
      'a restored session starts authenticated and can scan again',
      () async {
        expect(
          harness.container.read(authControllerProvider).user?.id,
          'user-1',
        );

        await runFullJourney(harness);
        final firstAnalysisId = harness.container
            .read(faceAnalysisControllerProvider)
            .analysis!
            .id;

        // A second scan of a different selfie must produce its own analysis.
        harness.analysis.nextAnalysisId =
            'b2b2b2b2-0000-4000-8000-000000000002';
        harness.container.read(faceAnalysisControllerProvider.notifier).clear();
        final scanState = harness.container.read(scanControllerProvider);
        await harness.container
            .read(faceAnalysisControllerProvider.notifier)
            .analyze(
              selfie: scanState.selfie!,
              localValidation: scanState.localValidation!,
            );

        final secondAnalysisId = harness.container
            .read(faceAnalysisControllerProvider)
            .analysis!
            .id;
        expect(secondAnalysisId, isNot(firstAnalysisId));
      },
    );

    test('favoriting a saved look persists through the repository', () async {
      final preview = await runFullJourney(harness);
      final actions = harness.container.read(
        resultActionsControllerProvider.notifier,
      );

      await actions.toggleFavorite(preview);

      expect(harness.savedLooks.stored.values.single.isFavorite, isTrue);
      expect(
        harness.container
            .read(resultActionsControllerProvider)
            .isFavorite(preview.id),
        isTrue,
      );
    });
  });

  group('journey 3 — guest user', () {
    test(
      'a guest completes the same workflow with owner-scoped data',
      () async {
        final guest = _Harness(
          user: const AuthUser(id: 'guest-1', isAnonymous: true),
        );
        addTearDown(guest.dispose);

        final preview = await runFullJourney(guest);
        final analysis = guest.container
            .read(faceAnalysisControllerProvider)
            .analysis!;

        expect(
          guest.container.read(authControllerProvider).user?.isAnonymous,
          isTrue,
        );
        expect(preview.analysisId, analysis.id);
        expect(guest.analysis.observedUploads, 1);
      },
    );

    test('switching account resets workflow state to empty', () async {
      await runFullJourney(harness);
      expect(
        harness.container.read(makeupPreviewControllerProvider).preview,
        isNotNull,
      );

      // Signing out rebuilds every user-scoped controller.
      await harness.container.read(authControllerProvider.notifier).signOut();

      expect(harness.container.read(authControllerProvider).user, isNull);
      expect(
        harness.container.read(faceAnalysisControllerProvider).analysis,
        isNull,
      );
      expect(
        harness.container
            .read(makeupRecommendationControllerProvider)
            .recommendation,
        isNull,
      );
      expect(
        harness.container.read(makeupPreviewControllerProvider).preview,
        isNull,
      );
      expect(harness.container.read(scanControllerProvider).selfie, isNull);
    });
  });

  group('journey 4 — failures recover instead of dead-ending', () {
    test(
      'an invalid image stops before analysis and allows reselect',
      () async {
        harness.validation.failure = const ImageValidationFailure(
          ImageValidationFailureType.dimensionsTooSmall,
          'That photo is too small for analysis.',
        );
        final scan = harness.container.read(scanControllerProvider.notifier);

        await scan.chooseFromGallery();
        await scan.validateForAnalysis();

        final state = harness.container.read(scanControllerProvider);
        expect(state.stage, isNot(ScanStage.readyForSecureValidation));
        expect(state.errorMessage, contains('too small'));
        // The selfie is retained so the user can retry or reselect.
        expect(state.selfie, isNotNull);

        harness.validation.failure = null;
        await scan.validateForAnalysis();
        expect(
          harness.container.read(scanControllerProvider).stage,
          ScanStage.readyForSecureValidation,
        );
      },
    );

    test(
      'an AI timeout is retryable and recovers on the next attempt',
      () async {
        harness.analysis.failure = const AnalysisFailure(
          AnalysisFailureType.timeout,
          'Analysis took too long. Please try again.',
          retryable: true,
        );
        final scan = harness.container.read(scanControllerProvider.notifier);
        await scan.chooseFromGallery();
        await scan.validateForAnalysis();
        final scanState = harness.container.read(scanControllerProvider);

        await harness.container
            .read(faceAnalysisControllerProvider.notifier)
            .analyze(
              selfie: scanState.selfie!,
              localValidation: scanState.localValidation!,
            );

        var analysisState = harness.container.read(
          faceAnalysisControllerProvider,
        );
        expect(analysisState.hasFailure, isTrue);
        expect(analysisState.retryable, isTrue);
        expect(analysisState.message, isNot(contains('Exception')));

        harness.analysis.failure = null;
        await harness.container
            .read(faceAnalysisControllerProvider.notifier)
            .analyze(
              selfie: scanState.selfie!,
              localValidation: scanState.localValidation!,
            );

        analysisState = harness.container.read(faceAnalysisControllerProvider);
        expect(analysisState.status, FaceAnalysisStatus.success);
        expect(analysisState.analysis, isNotNull);
      },
    );

    test('a failed regeneration keeps the previous valid preview', () async {
      final first = await runFullJourney(harness);
      harness.preview.failure = const PreviewFailure(
        PreviewFailureType.gemini,
        'The AI service could not create your preview right now.',
        retryable: true,
      );

      await harness.container
          .read(makeupPreviewControllerProvider.notifier)
          .generateVariation();

      final state = harness.container.read(makeupPreviewControllerProvider);
      expect(state.status, MakeupPreviewStatus.failure);
      expect(state.retryable, isTrue);
      // The earlier result is still offered rather than discarded.
      expect(state.previousPreview?.id, first.id);
    });
  });

  group('journey 5 — regeneration reuses the same analysis', () {
    test(
      'a new variation keeps the analysis and recommendation linkage',
      () async {
        final first = await runFullJourney(harness);
        final analysis = harness.container
            .read(faceAnalysisControllerProvider)
            .analysis!;
        final recommendation = harness.container
            .read(makeupRecommendationControllerProvider)
            .recommendation!;

        await harness.container
            .read(makeupPreviewControllerProvider.notifier)
            .generateVariation();

        final second = harness.container
            .read(makeupPreviewControllerProvider)
            .preview!;
        expect(second.id, isNot(first.id));
        expect(second.generationNumber, first.generationNumber + 1);
        expect(second.analysisId, analysis.id);
        expect(second.recommendationId, recommendation.id);
        // Regeneration must not re-run the analysis or the recommendation.
        expect(harness.analysis.observedUploads, 1);
        expect(harness.recommendation.generateCount, 1);
      },
    );

    test('the original selfie is never overwritten by a variation', () async {
      final first = await runFullJourney(harness);
      await harness.container
          .read(makeupPreviewControllerProvider.notifier)
          .generateVariation();
      final second = harness.container
          .read(makeupPreviewControllerProvider)
          .preview!;

      expect(second.originalImagePath, first.originalImagePath);
      expect(second.generatedImagePath, isNot(first.generatedImagePath));
    });
  });

  group('journey 6 — deletion removes only owned content', () {
    test('removing a saved look clears it from the repository', () async {
      final preview = await runFullJourney(harness);
      final actions = harness.container.read(
        resultActionsControllerProvider.notifier,
      );
      await actions.toggleSaved(preview);
      expect(harness.savedLooks.stored, isNotEmpty);

      await actions.toggleSaved(preview);

      expect(harness.savedLooks.stored, isEmpty);
      expect(
        harness.container
            .read(resultActionsControllerProvider)
            .isSaved(preview.id),
        isFalse,
      );
    });

    test('a delete failure surfaces a sanitized message', () async {
      final preview = await runFullJourney(harness);
      final actions = harness.container.read(
        resultActionsControllerProvider.notifier,
      );
      await actions.toggleSaved(preview);
      harness.savedLooks.failOnRemove = true;

      await actions.toggleSaved(preview);

      final feedback = harness.container
          .read(resultActionsControllerProvider)
          .feedback;
      expect(feedback, isNotNull);
      expect(feedback, isNot(contains('Exception')));
      expect(feedback, isNot(contains('postgres')));
    });
  });
}

class _Harness {
  _Harness({AuthUser user = const AuthUser(id: 'user-1', isAnonymous: false)})
    : auth = FakeAuthRepository(user: user) {
    container = ProviderContainer(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(auth),
        selfieRepositoryProvider.overrideWithValue(selfies),
        imageValidationRepositoryProvider.overrideWithValue(validation),
        faceAnalysisRepositoryProvider.overrideWithValue(analysis),
        makeupRecommendationRepositoryProvider.overrideWithValue(
          recommendation,
        ),
        makeupPreviewRepositoryProvider.overrideWithValue(preview),
        savedLooksRepositoryProvider.overrideWithValue(savedLooks),
      ],
    );
  }

  final FakeAuthRepository auth;
  final _FakeSelfieRepository selfies = _FakeSelfieRepository();
  final _FakeValidationRepository validation = _FakeValidationRepository();
  final _FakeAnalysisRepository analysis = _FakeAnalysisRepository();
  final _FakeRecommendationRepository recommendation =
      _FakeRecommendationRepository();
  final _FakePreviewRepository preview = _FakePreviewRepository();
  final _FakeSavedLooksRepository savedLooks = _FakeSavedLooksRepository();
  late final ProviderContainer container;

  void dispose() {
    container.dispose();
    auth.dispose();
  }
}

class _FakeSelfieRepository implements SelfieRepository {
  final discarded = <PreparedSelfie>[];

  @override
  Future<PreparedSelfie?> acquire(SelfieSource source) async =>
      const PreparedSelfie(
        originalPath: 'original.jpg',
        uploadPath: 'upload.jpg',
        originalSizeBytes: 2000,
        uploadSizeBytes: 900,
        source: SelfieSource.gallery,
      );

  @override
  Future<bool> openPermissionSettings() async => true;

  @override
  Future<void> discard(PreparedSelfie selfie) async => discarded.add(selfie);
}

class _FakeValidationRepository implements ImageValidationRepository {
  ImageValidationFailure? failure;

  @override
  Future<LocalImageValidation> validateLocal(PreparedSelfie selfie) async {
    final current = failure;
    if (current != null) throw current;
    return const LocalImageValidation(
      mimeType: 'image/jpeg',
      width: 1080,
      height: 1440,
      originalSizeBytes: 2000,
      uploadSizeBytes: 900,
    );
  }
}

class _FakeAnalysisRepository implements FaceAnalysisRepository {
  AnalysisFailure? failure;
  String? nextAnalysisId;
  int observedUploads = 0;

  @override
  Future<FaceAnalysis> analyze({
    required PreparedSelfie selfie,
    required LocalImageValidation localValidation,
    required void Function(AnalysisProgress progress) onProgress,
  }) async {
    onProgress(AnalysisProgress.uploading);
    final current = failure;
    if (current != null) throw current;
    observedUploads += 1;
    onProgress(AnalysisProgress.secureProcessing);
    final override = nextAnalysisId;
    if (override == null) {
      return FaceAnalysisDto.fromResponse(validAnalysisResponse).analysis;
    }
    final payload = Map<String, Object?>.from(validAnalysisResponse);
    final analysis = Map<String, Object?>.from(
      payload['analysis']! as Map<String, Object?>,
    )..['id'] = override;
    return FaceAnalysisDto.fromResponse({'analysis': analysis}).analysis;
  }
}

class _FakeRecommendationRepository implements MakeupRecommendationRepository {
  int generateCount = 0;

  @override
  Future<MakeupRecommendation> generate({
    required FaceAnalysis analysis,
    required MakeupStyle style,
  }) async {
    generateCount += 1;
    final payload = Map<String, Object?>.from(validRecommendationResponse);
    final recommendation =
        Map<String, Object?>.from(
            payload['recommendation']! as Map<String, Object?>,
          )
          ..['analysisId'] = analysis.id
          ..['style'] = style.code;
    return MakeupRecommendationDto.fromResponse({
      'recommendation': recommendation,
    }).recommendation;
  }
}

class _FakePreviewRepository implements MakeupPreviewRepository {
  PreviewFailure? failure;
  int generation = 0;

  @override
  Future<GeneratedPreview> generate({
    required MakeupRecommendation recommendation,
  }) async {
    final current = failure;
    if (current != null) throw current;
    generation += 1;
    final payload = Map<String, Object?>.from(validGeneratedPreviewResponse);
    final preview =
        Map<String, Object?>.from(payload['preview']! as Map<String, Object?>)
          ..['id'] = 'preview-$generation'
          ..['analysisId'] = recommendation.analysisId
          ..['recommendationId'] = recommendation.id
          ..['generationNumber'] = generation
          ..['originalImagePath'] =
              'user-1/analyses/${recommendation.analysisId}/original/image.jpg'
          ..['generatedImagePath'] =
              'user-1/analyses/${recommendation.analysisId}/generated/'
              '${recommendation.id}/preview_000$generation.png';
    return GeneratedPreviewDto.fromResponse({'preview': preview}).toDomain(
      originalImageUrl: 'https://signed.example/original',
      generatedImageUrl: 'https://signed.example/generated-$generation',
    );
  }
}

class _FakeSavedLooksRepository implements SavedLooksRepository {
  final stored = <String, SavedLook>{};
  bool failOnRemove = false;
  var _sequence = 0;

  @override
  Future<SavedLook?> findByGeneratedImageId(String generatedImageId) async =>
      stored.values
          .where((look) => look.preview.id == generatedImageId)
          .firstOrNull;

  @override
  Future<SavedLook> save(
    GeneratedPreview preview, {
    bool favorite = false,
  }) async {
    final look = SavedLook(
      id: 'saved-${++_sequence}',
      preview: preview,
      analysis: FaceAnalysisDto.fromResponse(validAnalysisResponse).analysis,
      recommendation: MakeupRecommendationDto.fromResponse(
        validRecommendationResponse,
      ).recommendation,
      style: MakeupStyleCatalog.styles.firstWhere(
        (style) => style.code == 'soft_glam',
      ),
      isFavorite: favorite,
      createdAt: DateTime.utc(2026, 8, 12),
    );
    stored[look.id] = look;
    return look;
  }

  @override
  Future<void> remove(String savedLookId) async {
    if (failOnRemove) {
      throw StateError('postgres: delete blocked');
    }
    stored.remove(savedLookId);
  }

  @override
  Future<SavedLook> setFavorite(SavedLook look, bool isFavorite) async {
    final updated = look.copyWith(isFavorite: isFavorite);
    stored[look.id] = updated;
    return updated;
  }

  @override
  Future<SavedLooksPageResult> loadPage({
    required int offset,
    required int limit,
  }) async => SavedLooksPageResult(
    items: stored.values.toList(growable: false),
    hasMore: false,
  );
}
