import 'dart:async';

import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/analysis/domain/entities/face_analysis.dart';
import 'package:facetune/features/analysis/domain/repositories/face_analysis_repository.dart';
import 'package:facetune/features/analysis/domain/usecases/analyze_face.dart';
import 'package:facetune/features/analysis/presentation/controllers/face_analysis_controller.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/makeup_styles/domain/entities/makeup_style.dart';
import 'package:facetune/features/preview/domain/entities/generated_preview.dart';
import 'package:facetune/features/preview/domain/repositories/makeup_preview_repository.dart';
import 'package:facetune/features/preview/domain/usecases/generate_makeup_preview.dart';
import 'package:facetune/features/preview/data/models/generated_preview_dto.dart';
import 'package:facetune/features/preview/presentation/controllers/makeup_preview_controller.dart';
import 'package:facetune/features/recommendation/data/models/makeup_recommendation_dto.dart';
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/recommendation/domain/repositories/makeup_recommendation_repository.dart';
import 'package:facetune/features/recommendation/domain/usecases/generate_makeup_recommendation.dart';
import 'package:facetune/features/recommendation/presentation/controllers/makeup_recommendation_controller.dart';
import 'package:facetune/features/scan/domain/entities/live_frame.dart';
import 'package:facetune/features/scan/domain/entities/local_image_validation.dart';
import 'package:facetune/features/scan/domain/entities/prepared_selfie.dart';
import 'package:facetune/features/scan/domain/entities/selfie_source.dart';
import 'package:facetune/features/scan/domain/repositories/image_validation_repository.dart';
import 'package:facetune/features/scan/domain/repositories/live_camera_session.dart';
import 'package:facetune/features/scan/domain/repositories/selfie_repository.dart';
import 'package:facetune/features/scan/presentation/controllers/live_capture_controller.dart';
import 'package:facetune/features/scan/presentation/controllers/scan_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/analysis_response_fixture.dart';
import '../../helpers/generated_preview_response_fixture.dart';
import '../../helpers/recommendation_response_fixture.dart';

const _selfie = PreparedSelfie(
  originalPath: '/tmp/original.jpg',
  uploadPath: '/tmp/upload.jpg',
  originalSizeBytes: 2048,
  uploadSizeBytes: 1024,
  source: SelfieSource.gallery,
);

const _localValidation = LocalImageValidation(
  mimeType: 'image/jpeg',
  width: 1024,
  height: 1365,
  originalSizeBytes: 2048,
  uploadSizeBytes: 1024,
);

class _CountingAnalysis implements FaceAnalysisRepository {
  int calls = 0;

  @override
  Future<FaceAnalysis> analyze({
    required PreparedSelfie selfie,
    required LocalImageValidation localValidation,
    required void Function(AnalysisProgress progress) onProgress,
  }) async {
    calls += 1;
    return FaceAnalysisDto.fromResponse(validAnalysisResponse).analysis;
  }
}

class _CountingRecommendations implements MakeupRecommendationRepository {
  final requestedStyles = <String>[];
  final requestedAnalyses = <String>[];

  @override
  Future<MakeupRecommendation> generate({
    required FaceAnalysis analysis,
    required MakeupStyle style,
  }) async {
    requestedStyles.add(style.code);
    requestedAnalyses.add(analysis.id);
    final base = MakeupRecommendationDto.fromResponse(
      educatedRecommendationResponse,
    ).recommendation;
    return MakeupRecommendation(
      id: 'rec-${requestedStyles.length}',
      analysisId: analysis.id,
      styleCode: style.code,
      overallIntensity: base.overallIntensity,
      items: base.items,
      modelId: base.modelId,
      promptVersion: base.promptVersion,
      createdAt: base.createdAt,
    );
  }
}

class _CountingPreviews implements MakeupPreviewRepository {
  final requestedRecommendations = <String>[];

  @override
  Future<GeneratedPreview> generate({
    required MakeupRecommendation recommendation,
  }) async {
    requestedRecommendations.add(recommendation.id);
    return GeneratedPreviewDto.fromResponse(
      validGeneratedPreviewResponse,
    ).toDomain(
      originalImageUrl: 'https://example.invalid/original.jpg',
      generatedImageUrl: 'https://example.invalid/generated.jpg',
    );
  }
}

class _FakeSelfies implements SelfieRepository {
  int acquireCalls = 0;
  int prepareCalls = 0;

  @override
  Future<PreparedSelfie?> acquire(SelfieSource source) async {
    acquireCalls += 1;
    return _selfie;
  }

  @override
  Future<PreparedSelfie> prepareCaptured(String path) async {
    prepareCalls += 1;
    return _selfie;
  }

  @override
  Future<bool> openPermissionSettings() async => true;

  @override
  Future<void> discard(PreparedSelfie selfie) async {}
}

class _FakeValidation implements ImageValidationRepository {
  @override
  Future<LocalImageValidation> validateLocal(PreparedSelfie selfie) async =>
      _localValidation;
}

class _FakeCamera implements LiveCameraSession {
  int captureCalls = 0;

  @override
  Future<String> captureStill() async {
    captureCalls += 1;
    return '/tmp/captured.jpg';
  }

  @override
  Stream<LiveFrame> get frames => const Stream<LiveFrame>.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

/// The whole downstream chain, wired with counting fakes.
///
/// Deliberately assembled from the real controllers rather than stubs: what
/// LSEP-6 has to prove is that the pieces agree with each other about which
/// analysis they are working from, and a stub would agree by construction.
class _Journey {
  _Journey() {
    analysisRepository = _CountingAnalysis();
    recommendations = _CountingRecommendations();
    previews = _CountingPreviews();
    selfies = _FakeSelfies();
    camera = _FakeCamera();

    analysis = FaceAnalysisController(AnalyzeFace(analysisRepository));
    recommendation = MakeupRecommendationController(
      GenerateMakeupRecommendation(recommendations),
    );
    preview = MakeupPreviewController(GenerateMakeupPreview(previews));
    scan = ScanController(
      selfieRepository: selfies,
      validationRepository: _FakeValidation(),
      analysis: analysis,
    );
    capture = LiveCaptureController(
      session: camera,
      selfies: selfies,
      validation: _FakeValidation(),
      analysis: analysis,
    );
  }

  late final _CountingAnalysis analysisRepository;
  late final _CountingRecommendations recommendations;
  late final _CountingPreviews previews;
  late final _FakeSelfies selfies;
  late final _FakeCamera camera;

  late final FaceAnalysisController analysis;
  late final MakeupRecommendationController recommendation;
  late final MakeupPreviewController preview;
  late final ScanController scan;
  late final LiveCaptureController capture;

  MakeupStyle style(String code) =>
      MakeupStyleCatalog.styles.firstWhere((s) => s.code == code);

  /// Style selection through to a generated preview, as the app sequences it.
  Future<void> chooseStyleAndPreview(String code) async {
    await recommendation.generate(
      analysis: analysis.state.analysis!,
      style: style(code),
    );
    await preview.generate(
      recommendation: recommendation.state.recommendation!,
    );
  }

  void dispose() {
    capture.dispose();
    scan.dispose();
    preview.dispose();
    recommendation.dispose();
    analysis.dispose();
  }
}

void main() {
  group('gallery journey', () {
    test('gallery to beauty profile to style to palette to preview', () async {
      final journey = _Journey();
      addTearDown(journey.dispose);

      await journey.scan.chooseFromGalleryAndAnalyze();

      // Beauty profile.
      expect(journey.analysisRepository.calls, 1);
      final profile = journey.analysis.state.analysis!;
      expect(profile.attributes.faceShape.name, 'oval');
      expect(profile.confidence.faceShape, 0.91);

      await journey.chooseStyleAndPreview('soft_glam');

      // Palette, built from that same analysis.
      expect(journey.recommendations.requestedAnalyses, [profile.id]);
      expect(
        journey.recommendation.state.recommendation!.analysisId,
        profile.id,
      );
      // Education came through the palette intact.
      expect(
        journey
            .recommendation
            .state
            .recommendation!
            .items['blush']
            ?.education
            ?.features,
        validRecommendationEducation['features'],
      );

      // Preview, built from that recommendation.
      expect(journey.previews.requestedRecommendations, ['rec-1']);
      expect(
        journey.preview.state.preview,
        isNotNull,
        reason: 'the journey ends in a generated preview',
      );

      expect(
        journey.analysisRepository.calls,
        1,
        reason: 'the whole journey costs exactly one face analysis',
      );
    });
  });

  group('camera journey', () {
    test('camera to beauty profile to style to palette to preview', () async {
      final journey = _Journey();
      addTearDown(journey.dispose);

      await journey.capture.capture();

      expect(journey.camera.captureCalls, 1);
      expect(journey.selfies.prepareCalls, 1);
      expect(journey.analysisRepository.calls, 1);

      final profile = journey.analysis.state.analysis!;
      expect(profile.attributes.undertone.name, 'warm');
      expect(profile.confidence.undertone, 0.82);

      await journey.chooseStyleAndPreview('natural');

      expect(journey.recommendations.requestedAnalyses, [profile.id]);
      expect(journey.previews.requestedRecommendations, ['rec-1']);
      expect(
        journey.analysisRepository.calls,
        1,
        reason: 'the camera journey also costs exactly one face analysis',
      );
    });

    test('both entry points reach the same profile shape', () async {
      final gallery = _Journey();
      addTearDown(gallery.dispose);
      final camera = _Journey();
      addTearDown(camera.dispose);

      await gallery.scan.chooseFromGalleryAndAnalyze();
      await camera.capture.capture();

      final a = gallery.analysis.state.analysis!;
      final b = camera.analysis.state.analysis!;

      // Where the still came from changes nothing downstream.
      expect(a.attributes.faceShape, b.attributes.faceShape);
      expect(a.attributes.skinTone, b.attributes.skinTone);
      expect(a.confidence.faceShape, b.confidence.faceShape);
      expect(a.confidence.eyeColor, b.confidence.eyeColor);
    });
  });

  group('analysis reuse', () {
    test('style A, back, style B costs no new analysis', () async {
      final journey = _Journey();
      addTearDown(journey.dispose);

      await journey.scan.chooseFromGalleryAndAnalyze();
      expect(journey.analysisRepository.calls, 1);
      final profileId = journey.analysis.state.analysis!.id;

      await journey.chooseStyleAndPreview('soft_glam');
      // Going back is not an event the analysis controller observes; the state
      // simply persists. Choosing a different style then reuses it.
      await journey.chooseStyleAndPreview('bridal');

      expect(
        journey.analysisRepository.calls,
        1,
        reason: 'a second style must not re-analyse the face',
      );
      expect(journey.recommendations.requestedStyles, ['soft_glam', 'bridal']);
      expect(
        journey.recommendations.requestedAnalyses,
        [profileId, profileId],
        reason: 'both styles are built from the one accepted analysis',
      );
    });

    test('four style changes still cost one analysis', () async {
      final journey = _Journey();
      addTearDown(journey.dispose);

      await journey.scan.chooseFromGalleryAndAnalyze();
      for (final code in <String>['natural', 'office', 'party', 'clean_girl']) {
        await journey.chooseStyleAndPreview(code);
      }

      expect(journey.analysisRepository.calls, 1);
      expect(journey.recommendations.requestedStyles.length, 4);
    });

    test('re-requesting the same style reuses the recommendation', () async {
      final journey = _Journey();
      addTearDown(journey.dispose);

      await journey.scan.chooseFromGalleryAndAnalyze();
      await journey.chooseStyleAndPreview('soft_glam');
      await journey.recommendation.generate(
        analysis: journey.analysis.state.analysis!,
        style: journey.style('soft_glam'),
      );

      expect(
        journey.recommendations.requestedStyles,
        ['soft_glam'],
        reason: 'the same analysis and style must not be re-requested',
      );
      expect(journey.analysisRepository.calls, 1);
    });

    test('a new selfie is a new analysis, as it must be', () async {
      final journey = _Journey();
      addTearDown(journey.dispose);

      await journey.scan.chooseFromGalleryAndAnalyze();
      journey.analysis.clear();
      await journey.scan.chooseFromGalleryAndAnalyze();

      expect(
        journey.analysisRepository.calls,
        2,
        reason: 'a different source image is a different face to analyse',
      );
    });
  });

  group('preview generation is unchanged', () {
    test('one recommendation produces one preview request', () async {
      final journey = _Journey();
      addTearDown(journey.dispose);

      await journey.scan.chooseFromGalleryAndAnalyze();
      await journey.chooseStyleAndPreview('soft_glam');

      expect(journey.previews.requestedRecommendations.length, 1);
    });

    test(
      'a repeated generate for the same plan is a deliberate variation',
      () async {
        final journey = _Journey();
        addTearDown(journey.dispose);

        await journey.scan.chooseFromGalleryAndAnalyze();
        await journey.chooseStyleAndPreview('soft_glam');
        final plan = journey.recommendation.state.recommendation!;

        await journey.preview.generate(recommendation: plan);

        // Unchanged behaviour: regeneration is an explicit user action and is not
        // deduplicated, unlike recommendation generation.
        expect(journey.previews.requestedRecommendations, ['rec-1', 'rec-1']);
        expect(journey.analysisRepository.calls, 1);
      },
    );
  });
}
