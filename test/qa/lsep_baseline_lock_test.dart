import 'dart:io';

import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/analysis/domain/entities/face_analysis.dart';
import 'package:facetune/features/analysis/domain/repositories/face_analysis_repository.dart';
import 'package:facetune/features/analysis/domain/usecases/analyze_face.dart';
import 'package:facetune/features/analysis/presentation/controllers/face_analysis_controller.dart';
import 'package:facetune/features/scan/domain/entities/live_frame.dart';
import 'package:facetune/features/scan/domain/entities/local_image_validation.dart';
import 'package:facetune/features/scan/domain/entities/prepared_selfie.dart';
import 'package:facetune/features/scan/domain/entities/selfie_source.dart';
import 'package:facetune/features/scan/domain/errors/image_validation_failure.dart';
import 'package:facetune/features/scan/domain/repositories/image_validation_repository.dart';
import 'package:facetune/features/scan/domain/repositories/live_camera_session.dart';
import 'package:facetune/features/scan/domain/repositories/selfie_repository.dart';
import 'package:facetune/features/scan/presentation/controllers/live_capture_controller.dart';
import 'package:facetune/features/scan/presentation/controllers/scan_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/analysis_response_fixture.dart';

/// LSEP-7: the baseline lock, in one runnable file.
///
/// Every item on the phase's PASS list is asserted here, so checking the lock is
/// one command rather than an audit across sixteen test files. The individual
/// phase suites still hold the detailed coverage; this is the gate.
///
/// ```text
/// AUTO CAPTURE                     NONE
/// LIVE GEMINI                      0
/// FACE ANALYSIS PER ACCEPTED STILL 1
/// FACE ANALYSIS FOR REJECTED STILL 0
/// EXTRA EDUCATION AI CALL          0
/// FINAL PREVIEW                    gemini-3.1-flash-image
/// TUTORIAL                         gemini-3.1-flash-image @ 1K
/// PLACEMENT / TECHNIQUE DATA       PRESERVED
/// PALETTE PLACEMENT / TECHNIQUE    HIDDEN
/// MY KIT AUTHORITY                 PRESERVED
/// ```
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

class _Selfies implements SelfieRepository {
  @override
  Future<PreparedSelfie?> acquire(SelfieSource source) async => _selfie;

  @override
  Future<PreparedSelfie> prepareCaptured(String path) async => _selfie;

  @override
  Future<bool> openPermissionSettings() async => true;

  @override
  Future<void> discard(PreparedSelfie selfie) async {}
}

class _Validation implements ImageValidationRepository {
  _Validation({this.failure});

  final Object? failure;

  @override
  Future<LocalImageValidation> validateLocal(PreparedSelfie selfie) async {
    if (failure != null) throw failure!;
    return _localValidation;
  }
}

class _Camera implements LiveCameraSession {
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

const _rejection = ImageValidationFailure(
  ImageValidationFailureType.dimensionsTooSmall,
  'That image is too small. Choose one at least 480 × 480 pixels.',
);

void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}'
    '${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  /// [input] with comments removed, so a comment naming a forbidden thing is
  /// not mistaken for the thing.
  String executable(String input) => input
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .split('\n')
      .where((line) {
        final trimmed = line.trimLeft();
        return !trimmed.startsWith('//') && !trimmed.startsWith('///');
      })
      .join('\n');

  group('LOCK: face analysis per accepted still is exactly 1', () {
    test('camera — one accepted still, one analysis', () async {
      final analysisRepository = _CountingAnalysis();
      final analysis = FaceAnalysisController(AnalyzeFace(analysisRepository));
      final camera = _Camera();
      final controller = LiveCaptureController(
        session: camera,
        selfies: _Selfies(),
        validation: _Validation(),
        analysis: analysis,
      );
      addTearDown(() {
        controller.dispose();
        analysis.dispose();
      });

      await controller.capture();

      expect(camera.captureCalls, 1);
      expect(analysisRepository.calls, 1);
    });

    test('gallery — one accepted selection, one analysis', () async {
      final analysisRepository = _CountingAnalysis();
      final analysis = FaceAnalysisController(AnalyzeFace(analysisRepository));
      final controller = ScanController(
        selfieRepository: _Selfies(),
        validationRepository: _Validation(),
        analysis: analysis,
      );
      addTearDown(() {
        controller.dispose();
        analysis.dispose();
      });

      await controller.chooseFromGalleryAndAnalyze();

      expect(analysisRepository.calls, 1);
    });
  });

  group('LOCK: face analysis for a rejected still is exactly 0', () {
    test('camera — a rejected still spends nothing', () async {
      final analysisRepository = _CountingAnalysis();
      final analysis = FaceAnalysisController(AnalyzeFace(analysisRepository));
      final controller = LiveCaptureController(
        session: _Camera(),
        selfies: _Selfies(),
        validation: _Validation(failure: _rejection),
        analysis: analysis,
      );
      addTearDown(() {
        controller.dispose();
        analysis.dispose();
      });

      await controller.capture();

      expect(analysisRepository.calls, 0);
    });

    test('gallery — a rejected selection spends nothing', () async {
      final analysisRepository = _CountingAnalysis();
      final analysis = FaceAnalysisController(AnalyzeFace(analysisRepository));
      final controller = ScanController(
        selfieRepository: _Selfies(),
        validationRepository: _Validation(failure: _rejection),
        analysis: analysis,
      );
      addTearDown(() {
        controller.dispose();
        analysis.dispose();
      });

      await controller.chooseFromGalleryAndAnalyze();

      expect(analysisRepository.calls, 0);
    });
  });

  group('LOCK: auto capture is NONE', () {
    const livePath = <String>[
      'lib/features/scan/domain/entities/live_check.dart',
      'lib/features/scan/domain/entities/live_frame.dart',
      'lib/features/scan/domain/entities/live_validation_snapshot.dart',
      'lib/features/scan/domain/repositories/live_camera_session.dart',
      'lib/features/scan/domain/repositories/live_frame_source.dart',
      'lib/features/scan/domain/services/live_frame_analyzer.dart',
      'lib/features/scan/data/repositories/camera_live_session.dart',
      'lib/features/scan/presentation/controllers/live_scan_controller.dart',
      'lib/features/scan/presentation/controllers/live_capture_controller.dart',
      'lib/features/scan/presentation/pages/live_camera_page.dart',
    ];

    test('no timer or countdown exists anywhere on the live path', () {
      for (final path in livePath) {
        final code = executable(source(path));
        for (final forbidden in <String>[
          'Timer(',
          'Timer.periodic',
          'countdown',
          'autoCapture',
          'Future.delayed',
        ]) {
          expect(
            code,
            isNot(contains(forbidden)),
            reason: '$path must contain no $forbidden',
          );
        }
      }
    });

    test('captureStill has exactly one caller, and it is capture()', () {
      final callers = <String>[
        for (final path in livePath)
          if (executable(source(path)).contains('.captureStill()')) path,
      ];
      expect(callers, [
        'lib/features/scan/presentation/controllers/live_capture_controller.dart',
      ]);
    });

    test('capture() is reached only from an onPressed', () {
      final page = executable(
        source('lib/features/scan/presentation/pages/live_camera_page.dart'),
      );
      // Exactly one call site, and it is guarded by the shutter's enabled
      // state. Matched on the guard rather than on a particular callback
      // spelling, so the assertion survives a refactor of the widget tree
      // without surviving a second call site.
      expect(RegExp(r'\.capture\(\)').allMatches(page).length, 1);
      expect(page, contains('onPressed: canCapture'));
      final guard = page.indexOf('onPressed: canCapture');
      final call = page.indexOf('.capture()');
      expect(guard, greaterThan(-1));
      expect(
        call,
        greaterThan(guard),
        reason: 'the only capture must sit inside the guarded onPressed',
      );
    });
  });

  group('LOCK: live Gemini calls are 0', () {
    test('nothing on the live path can reach a network or a model', () {
      const livePath = <String>[
        'lib/features/scan/domain/services/live_frame_analyzer.dart',
        'lib/features/scan/presentation/controllers/live_scan_controller.dart',
        'lib/features/scan/data/repositories/camera_live_session.dart',
      ];
      for (final path in livePath) {
        final code = executable(source(path));
        for (final forbidden in <String>[
          'package:supabase',
          'package:http',
          'functions.invoke',
          'generativelanguage',
          'Gemini',
          'gemini',
        ]) {
          expect(
            code,
            isNot(contains(forbidden)),
            reason: '$path must not reach $forbidden',
          );
        }
      }
    });

    test('live frames are never uploaded, persisted, or logged', () {
      const framePath = <String>[
        'lib/features/scan/domain/services/live_frame_analyzer.dart',
        'lib/features/scan/presentation/controllers/live_scan_controller.dart',
        'lib/features/scan/data/repositories/camera_live_session.dart',
      ];
      for (final path in framePath) {
        final code = executable(source(path));
        for (final forbidden in <String>[
          'writeAsBytes',
          'upload',
          'createSignedUrl',
          'base64',
          'debugPrint',
          'print(',
        ]) {
          expect(
            code,
            isNot(contains(forbidden)),
            reason: '$path must not leak a frame via $forbidden',
          );
        }
      }
    });

    test('the accepted still uses the existing secure pipeline', () {
      // Both intake paths converge on the same repository and the same
      // validated PreparedSelfie, so the still reaches the Edge Function the
      // way it always did.
      final capture = source(
        'lib/features/scan/presentation/controllers/live_capture_controller.dart',
      );
      expect(capture, contains('_selfies.prepareCaptured'));
      expect(capture, contains('_validation.validateLocal'));
      expect(capture, contains('_analysis.analyze'));

      final device = source(
        'lib/features/scan/data/repositories/device_selfie_repository.dart',
      );
      expect(
        device,
        contains('_prepare(path, SelfieSource.camera)'),
        reason: 'the captured still runs the same preparation as a picked one',
      );
    });
  });

  group('LOCK: exactly one recommendation call, no education call', () {
    final index = source(
      'supabase/functions/generate-makeup-recommendation/index.ts',
    );

    test('one Gemini request in the recommendation function', () {
      expect(
        RegExp(r'await requestGeminiRecommendation\(').allMatches(index).length,
        1,
      );
    });

    test('no second education operation exists', () {
      for (final forbidden in <String>[
        'requestGeminiEducation',
        'EDUCATION_PROMPT_VERSION',
        'generate-education',
      ]) {
        expect(executable(index), isNot(contains(forbidden)));
      }
    });

    test('education rides on the same structured response', () {
      final schema = source(
        'supabase/functions/generate-makeup-recommendation/schema.ts',
      );
      expect(schema, contains('education: educationSchema'));
      for (final section in <String>['features', 'effect', 'style']) {
        expect(schema, contains('$section: { type: "string"'));
      }
    });
  });

  group('LOCK: models and prompts', () {
    test('final preview is gemini-3.1-flash-image', () {
      expect(
        source('supabase/functions/_shared/final_preview_model.ts'),
        contains('export const FINAL_PREVIEW_MODEL = "gemini-3.1-flash-image"'),
      );
    });

    test('tutorial is gemini-3.1-flash-image at 1K', () {
      final config = source('supabase/functions/_shared/tutorial_ai_config.ts');
      expect(config, contains('"gemini-3.1-flash-image"'));
      expect(
        config,
        contains('export const TUTORIAL_OUTPUT_RESOLUTION = "1K" as const'),
      );
      expect(
        config,
        contains(
          'export const TUTORIAL_GUIDELINE_PROMPT_VERSION = '
          '"tutorial_guideline_v4_7"',
        ),
      );
    });

    test('manifest prompt is tutorial_manifest_v4_1', () {
      expect(
        source('supabase/functions/analyze-tutorial-manifest-v4/prompt.ts'),
        contains(
          'export const TUTORIAL_MANIFEST_PROMPT_VERSION = '
          '"tutorial_manifest_v4_1"',
        ),
      );
    });

    test('face analysis and recommendation models are unchanged', () {
      expect(
        source('supabase/functions/analyze-face/index.ts'),
        contains('Deno.env.get("GEMINI_MODEL")?.trim() || "gemini-3.6-flash"'),
      );
      expect(
        source('supabase/functions/generate-makeup-recommendation/index.ts'),
        contains('Deno.env.get("GEMINI_MODEL")?.trim() || "gemini-3.6-flash"'),
      );
    });

    test('the recommendation prompt is versioned to v3', () {
      expect(
        source('supabase/functions/generate-makeup-recommendation/prompt.ts'),
        contains(
          'export const MAKEUP_RECOMMENDATION_PROMPT_VERSION = '
          '"makeup_recommendation_v3"',
        ),
      );
    });
  });

  group('LOCK: placement and technique data preserved', () {
    test('the domain entity still carries both', () {
      final entity = source(
        'lib/features/recommendation/domain/entities/makeup_recommendation.dart',
      );
      expect(entity, contains('final String placement;'));
      expect(entity, contains('final String technique;'));
    });

    test('the decoder still requires both', () {
      final dto = source(
        'lib/features/recommendation/data/models/makeup_recommendation_dto.dart',
      );
      expect(dto, contains("placement: _string(item, 'placement')"));
      expect(dto, contains("technique: _string(item, 'technique')"));
    });

    test('the server contract still requires both', () {
      final validation = source(
        'supabase/functions/generate-makeup-recommendation/validation.ts',
      );
      expect(validation, contains('placement: text(input, "placement"'));
      expect(validation, contains('technique: text(input, "technique"'));
    });

    test('the tutorial still consumes both', () {
      expect(
        source(
          'lib/features/tutorial/domain/catalog/look_plan_convergence.dart',
        ),
        contains('placement: item.placement'),
      );
      expect(
        source(
          'lib/features/tutorial/presentation/widgets/tutorial_product_cards.dart',
        ),
        contains('entry.technique'),
      );
    });

    test('the Makeup Breakdown still presents both', () {
      final breakdown = source(
        'lib/features/results/presentation/widgets/makeup_breakdown.dart',
      );
      expect(breakdown, contains("label: 'Placement'"));
      expect(breakdown, contains("label: 'Technique'"));
    });
  });

  group('LOCK: placement and technique hidden on the Palette', () {
    test('the palette card renders neither', () {
      final card = executable(
        source(
          'lib/features/recommendation/presentation/widgets/'
          'recommendation_item_card.dart',
        ),
      );
      expect(card, isNot(contains('item.placement')));
      expect(card, isNot(contains('item.technique')));
      expect(card, isNot(contains("'Placement'")));
      expect(card, isNot(contains("'Technique'")));
    });

    test('the palette card renders the three education sections', () {
      final card = source(
        'lib/features/recommendation/presentation/widgets/'
        'recommendation_item_card.dart',
      );
      expect(card, contains("heading: 'Your features'"));
      expect(card, contains("heading: 'The effect'"));
      expect(card, contains("heading: 'The style'"));
      expect(card, contains("'Why this works for you'"));
    });
  });

  group('LOCK: education is grounded and teaches no application steps', () {
    final prompt = source(
      'supabase/functions/generate-makeup-recommendation/prompt.ts',
    );

    test('grounded in the actual analysis, style and chosen values', () {
      expect(
        prompt,
        contains(
          'Ground every sentence in the supplied facial attributes, the '
          'selected style, and the values you chose for this same category.',
        ),
      );
    });

    test('unobserved attributes cannot be invented', () {
      for (final forbidden in <String>[
        'acne',
        'dark circles',
        'skin sensitivity',
        'cheekbone prominence',
        'lip asymmetry',
      ]) {
        expect(prompt, contains(forbidden));
      }
      expect(prompt, contains('Never state or invent a confidence'));
    });

    test('products and brands cannot be invented', () {
      expect(prompt, contains('Never mention a brand, product line, retailer'));
    });

    test('application instructions cannot leak into education', () {
      expect(
        prompt,
        contains('Do not restate the placement or technique text.'),
        reason: 'where and how belong to Show Me How, not the Palette',
      );
    });
  });

  group('LOCK: My Makeup Kit authority preserved', () {
    final kitPrompt = source(
      'supabase/functions/generate-kit-makeup-recommendation/prompt.ts',
    );
    final kitIndex = source(
      'supabase/functions/generate-kit-makeup-recommendation/index.ts',
    );

    test('the kit contract is unchanged by this track', () {
      expect(kitPrompt, contains('"kit_makeup_recommendation_v2"'));
      expect(
        executable(kitPrompt),
        isNot(contains('education')),
        reason: 'the kit schema gained nothing from LSEP',
      );
    });

    test('owned-products-only selection is intact', () {
      expect(
        kitPrompt,
        contains(
          'Create one achievable look using ONLY products in the supplied '
          'authenticated inventory.',
        ),
      );
      expect(
        kitPrompt,
        contains(
          'Never invent, alter, infer, substitute, or recommend a product the '
          'user does not own.',
        ),
      );
    });

    test('there is no standard fallback', () {
      expect(
        executable(kitIndex),
        isNot(contains('../generate-makeup-recommendation')),
      );
      expect(executable(kitIndex), isNot(contains('"makeup_recommendation_v')));
    });

    test('server-side ownership validation still runs', () {
      expect(kitIndex, contains('makeup_kit_products'));
    });
  });

  group('LOCK: no database, RLS, storage or dependency drift', () {
    test('no migration mentions education or live scan', () {
      final migrations = Directory(
        '${root.path}${Platform.pathSeparator}supabase'
        '${Platform.pathSeparator}migrations',
      ).listSync().whereType<File>();

      for (final file in migrations) {
        final sql = file.readAsStringSync();
        for (final forbidden in <String>[
          'education',
          'live_scan',
          'liveScan',
        ]) {
          expect(
            sql,
            isNot(contains(forbidden)),
            reason: '${file.path} must be untouched by this track',
          );
        }
      }
    });

    test('only the approved camera dependency was added', () {
      final pubspec = source('pubspec.yaml');
      expect(pubspec, contains('camera:'));
      for (final forbidden in <String>[
        'google_mlkit',
        'tflite',
        'opencv',
        'mediapipe',
        'firebase_ml',
        'face_detection',
      ]) {
        expect(
          pubspec,
          isNot(contains(forbidden)),
          reason: 'no ML runtime or face detector was authorized',
        );
      }
    });
  });
}
