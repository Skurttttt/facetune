import 'dart:async';

import 'package:facetune/core/constants/app_constants.dart';
import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/analysis/domain/entities/face_analysis.dart';
import 'package:facetune/features/analysis/domain/repositories/face_analysis_repository.dart';
import 'package:facetune/features/analysis/domain/usecases/analyze_face.dart';
import 'package:facetune/features/analysis/presentation/controllers/face_analysis_controller.dart';
import 'package:facetune/features/scan/data/providers/image_validation_repository_provider.dart';
import 'package:facetune/features/scan/data/providers/selfie_repository_provider.dart';
import 'package:facetune/features/scan/domain/entities/local_image_validation.dart';
import 'package:facetune/features/scan/domain/entities/prepared_selfie.dart';
import 'package:facetune/features/scan/domain/entities/selfie_source.dart';
import 'package:facetune/features/scan/domain/errors/image_validation_failure.dart';
import 'package:facetune/features/scan/domain/errors/selfie_failure.dart';
import 'package:facetune/features/scan/domain/repositories/image_validation_repository.dart';
import 'package:facetune/features/scan/domain/repositories/selfie_repository.dart';
import 'package:facetune/features/scan/presentation/controllers/scan_controller.dart';
import 'package:facetune/features/scan/presentation/controllers/scan_state.dart';
import 'package:facetune/features/scan/presentation/pages/scan_page.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/analysis_response_fixture.dart';

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

class _FakeSelfies implements SelfieRepository {
  _FakeSelfies({this.result = _selfie, this.failure});

  /// Null models a dismissed picker.
  final PreparedSelfie? result;
  final Object? failure;

  int acquireCalls = 0;
  int discardCalls = 0;
  Completer<PreparedSelfie?>? gate;

  @override
  Future<PreparedSelfie?> acquire(SelfieSource source) {
    acquireCalls += 1;
    if (failure != null) return Future<PreparedSelfie?>.error(failure!);
    final open = gate;
    if (open != null) return open.future;
    return Future.value(result);
  }

  @override
  Future<PreparedSelfie> prepareCaptured(String path) =>
      throw UnimplementedError();

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
    return _localValidation;
  }
}

/// Counts every paid analysis.
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

class _Harness {
  _Harness({
    PreparedSelfie? result = _selfie,
    Object? acquireFailure,
    Object? validationFailure,
  }) : selfies = _FakeSelfies(result: result, failure: acquireFailure),
       validation = _FakeValidation(failure: validationFailure),
       analysisRepository = _CountingAnalysis() {
    analysis = FaceAnalysisController(AnalyzeFace(analysisRepository));
    controller = ScanController(
      selfieRepository: selfies,
      validationRepository: validation,
      analysis: analysis,
    );
  }

  final _FakeSelfies selfies;
  final _FakeValidation validation;
  final _CountingAnalysis analysisRepository;
  late final FaceAnalysisController analysis;
  late final ScanController controller;

  void dispose() {
    controller.dispose();
    analysis.dispose();
  }
}

Future<_CountingAnalysis> _pumpScanPage(
  WidgetTester tester, {
  PreparedSelfie? result = _selfie,
  Object? validationFailure,
  // Tall enough that the whole page is laid out. ScanPage is a ListView, so a
  // phone-height viewport leaves the action buttons unbuilt, and an assertion
  // that a button is absent would pass for the wrong reason.
  Size size = const Size(393, 1600),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final analysisRepository = _CountingAnalysis();
  final analysisController = FaceAnalysisController(
    AnalyzeFace(analysisRepository),
  );

  final router = GoRouter(
    initialLocation: AppConstants.scanRoute,
    routes: <RouteBase>[
      GoRoute(
        path: AppConstants.scanRoute,
        builder: (context, state) => const ScanPage(),
      ),
      GoRoute(
        path: AppConstants.liveScanRoute,
        builder: (context, state) =>
            const Scaffold(body: Text('Live scan route')),
      ),
      GoRoute(
        path: AppConstants.analysisRoute,
        builder: (context, state) =>
            const Scaffold(body: Text('Analysis route')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        selfieRepositoryProvider.overrideWithValue(
          _FakeSelfies(result: result),
        ),
        imageValidationRepositoryProvider.overrideWithValue(
          _FakeValidation(failure: validationFailure),
        ),
        faceAnalysisControllerProvider.overrideWith(
          (ref) => analysisController,
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return analysisRepository;
}

void main() {
  group('selection is the only tap', () {
    test('choosing a usable photo validates and analyses it once', () async {
      final harness = _Harness();
      addTearDown(harness.dispose);

      await harness.controller.chooseFromGalleryAndAnalyze();

      expect(harness.selfies.acquireCalls, 1);
      expect(harness.validation.calls, 1);
      expect(
        harness.analysisRepository.calls,
        1,
        reason: 'one selection is one analysis',
      );
      expect(
        harness.controller.state.stage,
        ScanStage.readyForSecureValidation,
      );
    });

    test('a second call while busy is ignored', () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      final gate = Completer<PreparedSelfie?>();
      harness.selfies.gate = gate;

      final first = harness.controller.chooseFromGalleryAndAnalyze();
      await Future<void>.delayed(Duration.zero);

      await harness.controller.chooseFromGalleryAndAnalyze();
      await harness.controller.chooseFromGalleryAndAnalyze();

      expect(harness.selfies.acquireCalls, 1);

      gate.complete(_selfie);
      await first;

      expect(harness.analysisRepository.calls, 1);
    });
  });

  group('a dismissed picker', () {
    test('changes nothing and spends nothing', () async {
      final harness = _Harness(result: null);
      addTearDown(harness.dispose);

      await harness.controller.chooseFromGalleryAndAnalyze();

      expect(harness.selfies.acquireCalls, 1);
      expect(harness.validation.calls, 0);
      expect(harness.analysisRepository.calls, 0);
      expect(harness.controller.state.stage, ScanStage.idle);
      expect(harness.controller.state.selfie, isNull);
      expect(harness.controller.state.errorMessage, isNull);
    });

    test('is not treated as a failure', () async {
      final harness = _Harness(result: null);
      addTearDown(harness.dispose);

      await harness.controller.chooseFromGalleryAndAnalyze();

      expect(
        harness.controller.state.errorMessage,
        isNull,
        reason: 'cancelling is a decision, not an error',
      );
    });
  });

  group('a rejected photo costs nothing', () {
    test('validation failure means zero analysis', () async {
      final harness = _Harness(
        validationFailure: const ImageValidationFailure(
          ImageValidationFailureType.dimensionsTooSmall,
          'That image is too small. Choose one at least 480 × 480 pixels.',
        ),
      );
      addTearDown(harness.dispose);

      await harness.controller.chooseFromGalleryAndAnalyze();

      expect(harness.validation.calls, 1);
      expect(harness.analysisRepository.calls, 0);
      expect(harness.controller.state.stage, ScanStage.validationFailed);
      expect(harness.controller.state.canReselect, isTrue);
    });

    test('the message is the validator own words, not a substitute', () async {
      const actual =
          'That image is damaged or cannot be decoded. '
          'Choose another photo.';
      final harness = _Harness(
        validationFailure: const ImageValidationFailure(
          ImageValidationFailureType.corruptImage,
          actual,
        ),
      );
      addTearDown(harness.dispose);

      await harness.controller.chooseFromGalleryAndAnalyze();

      expect(harness.controller.state.errorMessage, actual);
    });

    test('an inaccessible image is handled safely', () async {
      final harness = _Harness(
        validationFailure: const ImageValidationFailure(
          ImageValidationFailureType.missingFile,
          'The selected image is no longer available. Please choose it again.',
        ),
      );
      addTearDown(harness.dispose);

      await harness.controller.chooseFromGalleryAndAnalyze();

      expect(harness.controller.state.stage, ScanStage.validationFailed);
      expect(harness.analysisRepository.calls, 0);
    });

    test('an unexpected validation error still blocks analysis', () async {
      final harness = _Harness(
        validationFailure: StateError('decoder blew up'),
      );
      addTearDown(harness.dispose);

      await harness.controller.chooseFromGalleryAndAnalyze();

      expect(harness.analysisRepository.calls, 0);
      expect(harness.controller.state.stage, ScanStage.validationFailed);
      expect(
        harness.controller.state.errorMessage,
        isNot(contains('StateError')),
      );
    });

    test('a picker failure never reaches validation or analysis', () async {
      final harness = _Harness(
        acquireFailure: const SelfieFailure(
          SelfieFailureType.permissionDenied,
          'Gallery access was denied.',
        ),
      );
      addTearDown(harness.dispose);

      await harness.controller.chooseFromGalleryAndAnalyze();

      expect(harness.validation.calls, 0);
      expect(harness.analysisRepository.calls, 0);
    });

    test('reselecting after a rejection works and analyses once', () async {
      final harness = _Harness();
      addTearDown(harness.dispose);

      await harness.controller.chooseFromGalleryAndAnalyze();
      expect(harness.analysisRepository.calls, 1);

      await harness.controller.chooseFromGalleryAndAnalyze();

      expect(harness.selfies.acquireCalls, 2);
      expect(
        harness.analysisRepository.calls,
        2,
        reason: 'two deliberate selections are two analyses',
      );
    });
  });

  group('the redundant gates are gone', () {
    testWidgets('no Validate selfie button exists', (tester) async {
      await _pumpScanPage(tester);

      expect(find.text('Validate selfie'), findsNothing);
      expect(find.text('Validating image...'), findsNothing);
    });

    testWidgets('no Analyze selfie button exists', (tester) async {
      await _pumpScanPage(tester);

      expect(find.text('Analyze selfie'), findsNothing);
    });

    testWidgets('the screen offers camera and gallery, nothing else', (
      tester,
    ) async {
      await _pumpScanPage(tester);

      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.byKey(const ValueKey('gallery-choose')), findsOneWidget);
    });

    testWidgets('choosing a photo runs the whole sequence from one tap', (
      tester,
    ) async {
      final analysis = await _pumpScanPage(tester);

      await tester.tap(find.byKey(const ValueKey('gallery-choose')));
      await tester.pumpAndSettle();

      expect(
        analysis.calls,
        1,
        reason: 'one tap, one analysis, no intermediate buttons',
      );
    });

    testWidgets('a rejected photo shows the failure structure', (tester) async {
      await _pumpScanPage(
        tester,
        validationFailure: const ImageValidationFailure(
          ImageValidationFailureType.dimensionsTooSmall,
          'That image is too small. Choose one at least 480 × 480 pixels.',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('gallery-choose')));
      await tester.pumpAndSettle();

      expect(find.text('This photo needs another try'), findsOneWidget);
      expect(find.textContaining('too small'), findsOneWidget);
      expect(find.text('Choose another photo'), findsWidgets);
    });

    testWidgets('a rejected photo triggers no analysis', (tester) async {
      final analysis = await _pumpScanPage(
        tester,
        validationFailure: const ImageValidationFailure(
          ImageValidationFailureType.corruptImage,
          'That image is damaged.',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('gallery-choose')));
      await tester.pumpAndSettle();

      expect(analysis.calls, 0);
    });
  });

  group('rebuilds are free', () {
    testWidgets('rebuilding the screen analyses nothing', (tester) async {
      final analysis = await _pumpScanPage(tester);

      for (var i = 0; i < 5; i += 1) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(analysis.calls, 0);
    });

    testWidgets('rebuilding after a completed analysis does not repeat it', (
      tester,
    ) async {
      final analysis = await _pumpScanPage(tester);

      await tester.tap(find.byKey(const ValueKey('gallery-choose')));
      await tester.pumpAndSettle();
      expect(analysis.calls, 1);

      for (var i = 0; i < 5; i += 1) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(
        analysis.calls,
        1,
        reason: 'a rebuild must never re-spend a completed analysis',
      );
    });

    testWidgets('a resize analyses nothing', (tester) async {
      final analysis = await _pumpScanPage(tester);

      tester.view.physicalSize = const Size(320, 900);
      await tester.pumpAndSettle();

      expect(analysis.calls, 0);
      expect(tester.takeException(), isNull);
    });
  });
}
