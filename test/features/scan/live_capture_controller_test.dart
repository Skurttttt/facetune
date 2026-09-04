import 'dart:async';

import 'package:facetune/features/analysis/domain/entities/face_analysis.dart';
import 'package:facetune/features/analysis/domain/repositories/face_analysis_repository.dart';
import 'package:facetune/features/analysis/domain/usecases/analyze_face.dart';
import 'package:facetune/features/analysis/presentation/controllers/face_analysis_controller.dart';
import 'package:facetune/features/analysis/presentation/controllers/face_analysis_state.dart';
import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/scan/domain/entities/live_frame.dart';
import 'package:facetune/features/scan/domain/entities/local_image_validation.dart';
import 'package:facetune/features/scan/domain/entities/prepared_selfie.dart';
import 'package:facetune/features/scan/domain/entities/selfie_source.dart';
import 'package:facetune/features/scan/domain/errors/image_validation_failure.dart';
import 'package:facetune/features/scan/domain/errors/selfie_failure.dart';
import 'package:facetune/features/scan/domain/repositories/image_validation_repository.dart';
import 'package:facetune/features/scan/domain/repositories/live_camera_session.dart';
import 'package:facetune/features/scan/domain/repositories/selfie_repository.dart';
import 'package:facetune/features/scan/presentation/controllers/live_capture_controller.dart';
import 'package:facetune/features/scan/presentation/controllers/live_capture_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/analysis_response_fixture.dart';

const _selfie = PreparedSelfie(
  originalPath: '/tmp/original.jpg',
  uploadPath: '/tmp/upload.jpg',
  originalSizeBytes: 2048,
  uploadSizeBytes: 1024,
  source: SelfieSource.camera,
);

const _validation = LocalImageValidation(
  mimeType: 'image/jpeg',
  width: 1024,
  height: 1365,
  originalSizeBytes: 2048,
  uploadSizeBytes: 1024,
);

class _FakeSession implements LiveCameraSession {
  _FakeSession({this.failure});

  final Object? failure;
  int captureCalls = 0;
  Completer<String>? gate;

  @override
  Future<String> captureStill() {
    captureCalls += 1;
    if (failure != null) return Future<String>.error(failure!);
    final open = gate;
    if (open != null) return open.future;
    return Future.value('/tmp/captured.jpg');
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

class _FakeSelfies implements SelfieRepository {
  _FakeSelfies({this.failure});

  final Object? failure;
  int prepareCalls = 0;
  int discardCalls = 0;

  @override
  Future<PreparedSelfie> prepareCaptured(String path) async {
    prepareCalls += 1;
    if (failure != null) throw failure!;
    return _selfie;
  }

  @override
  Future<PreparedSelfie?> acquire(SelfieSource source) async => null;

  @override
  Future<bool> openPermissionSettings() async => true;

  @override
  Future<void> discard(PreparedSelfie selfie) async => discardCalls += 1;
}

class _FakeValidation implements ImageValidationRepository {
  _FakeValidation({this.failure});

  final Object? failure;
  int calls = 0;

  @override
  Future<LocalImageValidation> validateLocal(PreparedSelfie selfie) async {
    calls += 1;
    if (failure != null) throw failure!;
    return _validation;
  }
}

/// Counts every paid analysis. The instrument for the whole phase.
class _CountingAnalysis implements FaceAnalysisRepository {
  int calls = 0;

  @override
  Future<FaceAnalysis> analyze({
    required PreparedSelfie selfie,
    required LocalImageValidation localValidation,
    required void Function(AnalysisProgress progress) onProgress,
  }) async {
    calls += 1;
    onProgress(AnalysisProgress.uploading);
    return FaceAnalysisDto.fromResponse(validAnalysisResponse).analysis;
  }
}

class _Harness {
  _Harness({
    Object? captureFailure,
    Object? prepareFailure,
    Object? validationFailure,
  }) : session = _FakeSession(failure: captureFailure),
       selfies = _FakeSelfies(failure: prepareFailure),
       validation = _FakeValidation(failure: validationFailure),
       analysisRepository = _CountingAnalysis() {
    analysis = FaceAnalysisController(AnalyzeFace(analysisRepository));
    controller = LiveCaptureController(
      session: session,
      selfies: selfies,
      validation: validation,
      analysis: analysis,
    );
  }

  final _FakeSession session;
  final _FakeSelfies selfies;
  final _FakeValidation validation;
  final _CountingAnalysis analysisRepository;
  late final FaceAnalysisController analysis;
  late final LiveCaptureController controller;

  void dispose() {
    controller.dispose();
    analysis.dispose();
  }
}

void main() {
  group('nothing happens on its own', () {
    test(
      'an untouched controller captures nothing and analyses nothing',
      () async {
        final harness = _Harness();
        addTearDown(harness.dispose);

        // Time passing is the whole point: a Ready state must never mature into
        // a photograph.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(harness.session.captureCalls, 0);
        expect(harness.analysisRepository.calls, 0);
        expect(harness.controller.state.stage, LiveCaptureStage.idle);
      },
    );
  });

  group('one tap, one still, one analysis', () {
    test('a successful capture runs the whole sequence exactly once', () async {
      final harness = _Harness();
      addTearDown(harness.dispose);

      await harness.controller.capture();

      expect(harness.session.captureCalls, 1);
      expect(harness.selfies.prepareCalls, 1);
      expect(harness.validation.calls, 1);
      expect(harness.analysisRepository.calls, 1);
      expect(harness.controller.state.stage, LiveCaptureStage.complete);
      expect(harness.analysis.state.status, FaceAnalysisStatus.success);
    });

    test('a second tap while busy is ignored', () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      final gate = Completer<String>();
      harness.session.gate = gate;

      final first = harness.controller.capture();
      await Future<void>.delayed(Duration.zero);
      expect(harness.controller.state.isBusy, isTrue);

      // Four more impatient taps.
      await harness.controller.capture();
      await harness.controller.capture();
      await harness.controller.capture();
      await harness.controller.capture();

      expect(
        harness.session.captureCalls,
        1,
        reason: 'a double tap must not take two photographs',
      );

      gate.complete('/tmp/captured.jpg');
      await first;

      expect(harness.analysisRepository.calls, 1);
    });

    test('the captured still is kept on screen while it is checked', () async {
      final harness = _Harness();
      addTearDown(harness.dispose);

      await harness.controller.capture();

      expect(harness.controller.state.selfie, _selfie);
    });

    test('progress is described, never quantified', () {
      const stages = <LiveCaptureStage, String>{
        LiveCaptureStage.capturing: 'Capturing…',
        LiveCaptureStage.preparing: 'Checking photo…',
        LiveCaptureStage.validating: 'Checking photo…',
        LiveCaptureStage.analyzing: 'Analyzing your features…',
      };
      for (final entry in stages.entries) {
        final label = LiveCaptureState(stage: entry.key).progressLabel;
        expect(label, entry.value);
        expect(
          label,
          isNot(contains('%')),
          reason: 'a fake percentage would be a lie about a model call',
        );
      }
    });
  });

  group('a rejected still costs nothing', () {
    test('final local validation failure means zero analysis', () async {
      final harness = _Harness(
        validationFailure: const ImageValidationFailure(
          ImageValidationFailureType.dimensionsTooSmall,
          'That image is too small. Choose one at least 480 × 480 pixels.',
        ),
      );
      addTearDown(harness.dispose);

      await harness.controller.capture();

      expect(harness.validation.calls, 1);
      expect(
        harness.analysisRepository.calls,
        0,
        reason: 'a rejected still must never reach a paid call',
      );
      expect(harness.controller.state.stage, LiveCaptureStage.rejected);
      expect(harness.controller.state.message, contains('too small'));
    });

    test('a rejected still is discarded rather than left behind', () async {
      final harness = _Harness(
        validationFailure: const ImageValidationFailure(
          ImageValidationFailureType.corruptImage,
          'That image is damaged.',
        ),
      );
      addTearDown(harness.dispose);

      await harness.controller.capture();

      expect(harness.selfies.discardCalls, greaterThanOrEqualTo(1));
    });

    test('a capture failure never reaches preparation or analysis', () async {
      final harness = _Harness(
        captureFailure: const SelfieFailure(
          SelfieFailureType.preparationFailed,
          'The camera is not ready yet. Try again in a moment.',
        ),
      );
      addTearDown(harness.dispose);

      await harness.controller.capture();

      expect(harness.selfies.prepareCalls, 0);
      expect(harness.validation.calls, 0);
      expect(harness.analysisRepository.calls, 0);
      expect(harness.controller.state.stage, LiveCaptureStage.rejected);
    });

    test('a preparation failure never reaches analysis', () async {
      final harness = _Harness(
        prepareFailure: const SelfieFailure(
          SelfieFailureType.unsupportedType,
          'Choose a JPEG, PNG, WebP, HEIC, or HEIF image.',
        ),
      );
      addTearDown(harness.dispose);

      await harness.controller.capture();

      expect(harness.validation.calls, 0);
      expect(harness.analysisRepository.calls, 0);
      expect(harness.controller.state.stage, LiveCaptureStage.rejected);
    });

    test('a rejection message carries no platform detail', () async {
      final harness = _Harness(
        captureFailure: StateError('CameraException 42'),
      );
      addTearDown(harness.dispose);

      await harness.controller.capture();

      expect(harness.controller.state.message, isNotNull);
      expect(
        harness.controller.state.message,
        isNot(contains('CameraException')),
      );
      expect(harness.controller.state.message, isNot(contains('StateError')));
    });

    test('retake returns to the live preview and frees the still', () async {
      final harness = _Harness(
        validationFailure: const ImageValidationFailure(
          ImageValidationFailureType.corruptImage,
          'That image is damaged.',
        ),
      );
      addTearDown(harness.dispose);

      await harness.controller.capture();
      expect(harness.controller.state.stage, LiveCaptureStage.rejected);

      await harness.controller.retake();

      expect(harness.controller.state.stage, LiveCaptureStage.idle);
      expect(harness.controller.state.selfie, isNull);
      expect(harness.controller.state.showsPreview, isTrue);
    });

    test('a retaken capture is allowed and runs once', () async {
      final harness = _Harness();
      addTearDown(harness.dispose);

      await harness.controller.capture();
      await harness.controller.retake();
      await harness.controller.capture();

      expect(harness.session.captureCalls, 2);
      expect(
        harness.analysisRepository.calls,
        2,
        reason: 'two deliberate taps are two analyses, which is correct',
      );
    });
  });

  group('stale results', () {
    test('a capture superseded by retake does not analyse', () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      final gate = Completer<String>();
      harness.session.gate = gate;

      final pending = harness.controller.capture();
      await Future<void>.delayed(Duration.zero);

      // The user gives up on the shot while the shutter is still open.
      await harness.controller.retake();
      gate.complete('/tmp/captured.jpg');
      await pending;

      expect(
        harness.analysisRepository.calls,
        0,
        reason: 'an abandoned capture must not spend anything',
      );
      expect(harness.controller.state.stage, LiveCaptureStage.idle);
    });

    test('a capture superseded by disposal does not analyse', () async {
      final harness = _Harness();
      final gate = Completer<String>();
      harness.session.gate = gate;

      final pending = harness.controller.capture();
      await Future<void>.delayed(Duration.zero);

      harness.controller.dispose();
      gate.complete('/tmp/captured.jpg');
      await pending;

      expect(harness.analysisRepository.calls, 0);
      harness.analysis.dispose();
    });

    test('capture after disposal does nothing', () async {
      final harness = _Harness();
      harness.controller.dispose();

      await harness.controller.capture();

      expect(harness.session.captureCalls, 0);
      expect(harness.analysisRepository.calls, 0);
      harness.analysis.dispose();
    });
  });
}
