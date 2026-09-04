import 'dart:async';

import 'package:facetune/core/constants/app_constants.dart';
import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/analysis/domain/entities/face_analysis.dart';
import 'package:facetune/features/analysis/domain/repositories/face_analysis_repository.dart';
import 'package:facetune/features/analysis/domain/usecases/analyze_face.dart';
import 'package:facetune/features/analysis/presentation/controllers/face_analysis_controller.dart';
import 'package:facetune/features/scan/data/providers/image_validation_repository_provider.dart';
import 'package:facetune/features/scan/data/providers/live_camera_providers.dart';
import 'package:facetune/features/scan/data/providers/selfie_repository_provider.dart';
import 'package:facetune/features/scan/domain/entities/live_check.dart';
import 'package:facetune/features/scan/domain/entities/live_frame.dart';
import 'package:facetune/features/scan/domain/entities/live_validation_snapshot.dart';
import 'package:facetune/features/scan/domain/entities/local_image_validation.dart';
import 'package:facetune/features/scan/domain/entities/prepared_selfie.dart';
import 'package:facetune/features/scan/domain/entities/selfie_source.dart';
import 'package:facetune/features/scan/domain/repositories/image_validation_repository.dart';
import 'package:facetune/features/scan/domain/repositories/live_camera_session.dart';
import 'package:facetune/features/scan/domain/repositories/selfie_repository.dart';
import 'package:facetune/features/scan/presentation/controllers/live_capture_controller.dart';
import 'package:facetune/features/scan/presentation/controllers/live_scan_controller.dart';
import 'package:facetune/features/scan/presentation/controllers/live_scan_providers.dart';
import 'package:facetune/features/scan/presentation/controllers/live_scan_state.dart';
import 'package:facetune/features/scan/presentation/pages/live_camera_page.dart';
import 'package:facetune/features/scan/presentation/widgets/live_face_guide.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
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
  source: SelfieSource.camera,
);

const _localValidation = LocalImageValidation(
  mimeType: 'image/jpeg',
  width: 1024,
  height: 1365,
  originalSizeBytes: 2048,
  uploadSizeBytes: 1024,
);

const _allPass = LiveValidationSnapshot({
  LiveCheck.lighting: LiveCheckState.pass,
  LiveCheck.sharpness: LiveCheckState.pass,
  LiveCheck.steadiness: LiveCheckState.pass,
});

const _darkFail = LiveValidationSnapshot({
  LiveCheck.lighting: LiveCheckState.fail,
  LiveCheck.sharpness: LiveCheckState.pass,
  LiveCheck.steadiness: LiveCheckState.pass,
});

const _shaky = LiveValidationSnapshot({
  LiveCheck.lighting: LiveCheckState.pass,
  LiveCheck.sharpness: LiveCheckState.pass,
  LiveCheck.steadiness: LiveCheckState.fail,
});

class _FakeSession implements LiveCameraSession {
  final _frames = StreamController<LiveFrame>.broadcast();
  int captureCalls = 0;
  int disposeCalls = 0;

  @override
  Future<String> captureStill() async {
    captureCalls += 1;
    return '/tmp/captured.jpg';
  }

  @override
  Stream<LiveFrame> get frames => _frames.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    if (!_frames.isClosed) await _frames.close();
  }
}

class _FakeSelfies implements SelfieRepository {
  @override
  Future<PreparedSelfie> prepareCaptured(String path) async => _selfie;

  @override
  Future<PreparedSelfie?> acquire(SelfieSource source) async => null;

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
  const _Harness({required this.session, required this.analysis});

  final _FakeSession session;
  final _CountingAnalysis analysis;
}

Future<_Harness> _pumpCamera(
  WidgetTester tester, {
  LiveValidationSnapshot snapshot = _allPass,
  LiveScanStatusOverride status = LiveScanStatusOverride.running,
  LivePreview? preview,
  LiveScanController Function(_FakeSession session)? liveScanFactory,
  bool settle = true,
  ThemeMode themeMode = ThemeMode.light,
  Brightness platformBrightness = Brightness.light,
  Size size = const Size(393, 873),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.platformBrightnessTestValue = platformBrightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  final session = _FakeSession();
  final analysisRepository = _CountingAnalysis();
  final analysisController = FaceAnalysisController(
    AnalyzeFace(analysisRepository),
  );
  // Not disposed here: the override hands ownership to Riverpod, which disposes
  // it with the scope. Disposing it again from a teardown is a double dispose.

  final router = GoRouter(
    initialLocation: AppConstants.liveScanRoute,
    routes: <RouteBase>[
      GoRoute(
        path: AppConstants.liveScanRoute,
        builder: (context, state) => const LiveCameraPage(),
      ),
      GoRoute(
        path: AppConstants.scanRoute,
        builder: (context, state) => const Scaffold(body: Text('Scan route')),
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
        liveCameraSessionProvider.overrideWithValue(session),
        selfieRepositoryProvider.overrideWithValue(_FakeSelfies()),
        imageValidationRepositoryProvider.overrideWithValue(_FakeValidation()),
        faceAnalysisControllerProvider.overrideWith(
          (ref) => analysisController,
        ),
        // A placeholder preview: the plugin surface cannot render in a widget
        // test, and what is being tested here is the screen around it.
        livePreviewProvider.overrideWithValue(
          preview ??
              LivePreview(
                build: (context) => const AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ColoredBox(
                    key: ValueKey('test-live-preview'),
                    color: Colors.black12,
                  ),
                ),
              ),
        ),
        liveScanControllerProvider.overrideWith(
          (ref) =>
              liveScanFactory?.call(session) ??
              _StubLiveScan(
                session: session,
                snapshot: snapshot,
                status: status,
              ),
        ),
        liveCaptureControllerProvider.overrideWith(
          (ref) => LiveCaptureController(
            session: session,
            selfies: _FakeSelfies(),
            validation: _FakeValidation(),
            analysis: analysisController,
          ),
        ),
      ],
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // First build, then the post-frame camera-start callback.
    await tester.pump();
    await tester.pump();
  }
  return _Harness(session: session, analysis: analysisRepository);
}

enum LiveScanStatusOverride { running, starting, stopped }

/// A live-scan controller pinned to one state.
///
/// The real controller's own behaviour is proven in
/// `live_scan_controller_test.dart`; here the screen is what is under test, so
/// each guidance state is set directly rather than provoked from pixels.
class _StubLiveScan extends LiveScanController {
  _StubLiveScan({
    required LiveCameraSession session,
    required LiveValidationSnapshot snapshot,
    required LiveScanStatusOverride status,
  }) : super(source: session) {
    state = LiveScanState(
      // A running session in these tests has already measured a frame; that is
      // what makes the guidance assertions meaningful rather than testing the
      // camera-warming-up state over and over.
      hasSampled: status == LiveScanStatusOverride.running,
      status: switch (status) {
        LiveScanStatusOverride.running => LiveScanStatus.running,
        LiveScanStatusOverride.starting => LiveScanStatus.starting,
        LiveScanStatusOverride.stopped => LiveScanStatus.stopped,
      },
      snapshot: snapshot,
      errorMessage: status == LiveScanStatusOverride.stopped
          ? 'FaceTune could not open the camera. Try again.'
          : null,
    );
  }

  @override
  Future<void> start() async {}
}

/// Reproduces the production ordering: the first page build has no camera
/// controller, then camera startup completes and publishes `running`.
class _DelayedStartLiveScan extends LiveScanController {
  _DelayedStartLiveScan({
    required super.source,
    required this.startGate,
    required this.onCameraReady,
  });

  final Completer<void> startGate;
  final VoidCallback onCameraReady;

  @override
  Future<void> start() async {
    state = LiveScanState(status: LiveScanStatus.starting);
    await startGate.future;
    onCameraReady();
    state = LiveScanState(
      status: LiveScanStatus.running,
      hasSampled: true,
      snapshot: _allPass,
    );
  }
}

void main() {
  group('guidance states', () {
    testWidgets('Ready is shown with its instruction', (tester) async {
      await _pumpCamera(tester);

      expect(find.text('Ready'), findsOneWidget);
      expect(find.byKey(const ValueKey('test-live-preview')), findsOneWidget);
      expect(
        find.text("Take the photo when you're happy with your look."),
        findsOneWidget,
      );
    });

    testWidgets('a lighting failure gives one actionable line', (tester) async {
      await _pumpCamera(tester, snapshot: _darkFail);

      expect(find.text('Move toward better light'), findsOneWidget);
      expect(find.text('Ready'), findsNothing);
      expect(find.byKey(const ValueKey('test-live-preview')), findsOneWidget);
    });

    testWidgets('a steadiness failure gives its own line', (tester) async {
      await _pumpCamera(tester, snapshot: _shaky);

      expect(find.text('Hold the camera steady'), findsOneWidget);
    });

    testWidgets('a stopped camera explains itself', (tester) async {
      await _pumpCamera(
        tester,
        status: LiveScanStatusOverride.stopped,
        snapshot: LiveValidationSnapshot.unknown(),
      );

      expect(find.text('Camera unavailable'), findsOneWidget);
    });

    testWidgets('only one guidance headline is shown at a time', (
      tester,
    ) async {
      await _pumpCamera(tester, snapshot: _darkFail);

      // The detail exists but is collapsed behind a summary, not laid out as a
      // permanent report.
      expect(find.text('Lighting: needs attention'), findsNothing);
      expect(find.textContaining('checks ready'), findsOneWidget);
    });

    testWidgets('the compact summary can be opened for detail', (tester) async {
      await _pumpCamera(tester, snapshot: _darkFail);

      await tester.tap(find.textContaining('checks ready'));
      await tester.pumpAndSettle();

      expect(find.text('Lighting: needs attention'), findsOneWidget);
      // "Sharpness", not "Focus": the measurement is an image-gradient
      // estimate and never reads the lens's autofocus state.
      expect(find.text('Sharpness: good'), findsOneWidget);
      expect(find.text('Steadiness: good'), findsOneWidget);
      expect(find.byKey(const ValueKey('test-live-preview')), findsOneWidget);
    });
  });

  group('preview readiness', () {
    testWidgets(
      'camera startup state attaches the preview after initial null readiness',
      (tester) async {
        final startGate = Completer<void>();
        final cameraValue = ValueNotifier<bool>(false);
        addTearDown(cameraValue.dispose);

        await _pumpCamera(
          tester,
          settle: false,
          preview: LivePreview(
            listenableOf: () => cameraValue.value ? cameraValue : null,
            build: (context) => cameraValue.value
                ? const AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ColoredBox(
                      key: ValueKey('reactive-live-preview'),
                      color: Colors.black12,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          liveScanFactory: (session) => _DelayedStartLiveScan(
            source: session,
            startGate: startGate,
            onCameraReady: () => cameraValue.value = true,
          ),
        );

        expect(
          find.byKey(const ValueKey('reactive-live-preview')),
          findsNothing,
          reason: 'the first build occurs before the camera exists',
        );

        startGate.complete();
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('reactive-live-preview')),
          findsOneWidget,
          reason:
              'publishing LiveScanStatus.running must rebuild the viewport '
              'and attach it to the newly created camera listenable',
        );

        // Once attached, camera-value notifications rebuild the surface without
        // depending on any validation/checklist state change.
        cameraValue.value = false;
        await tester.pump();
        expect(
          find.byKey(const ValueKey('reactive-live-preview')),
          findsNothing,
        );
      },
    );

    testWidgets('the transparent face guide does not replace the preview', (
      tester,
    ) async {
      await _pumpCamera(tester);

      expect(find.byKey(const ValueKey('test-live-preview')), findsOneWidget);
      expect(find.byType(LiveFaceGuide), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LiveFaceGuide),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );
    });
  });

  group('the shutter is the only trigger', () {
    testWidgets('waiting in Ready captures nothing', (tester) async {
      final harness = await _pumpCamera(tester);

      expect(find.text('Ready'), findsOneWidget);

      // Ten seconds of a user deciding whether they like their hair.
      for (var i = 0; i < 10; i += 1) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(
        harness.session.captureCalls,
        0,
        reason: 'Ready must never mature into a photograph',
      );
      expect(harness.analysis.calls, 0);
    });

    testWidgets('a manual tap captures exactly once and analyses once', (
      tester,
    ) async {
      final harness = await _pumpCamera(tester);

      await tester.tap(find.byKey(const ValueKey('live-shutter')));
      await tester.pumpAndSettle();

      expect(harness.session.captureCalls, 1);
      expect(harness.analysis.calls, 1);
    });

    testWidgets('the shutter is enabled while the camera is running', (
      tester,
    ) async {
      await _pumpCamera(tester, snapshot: _darkFail);

      // A poor frame does not lock the user out: the still is re-validated
      // regardless, and the local pass is advisory.
      // Read from PrimaryButton itself. FilledButton.icon builds a private
      // subclass, so find.byType(FilledButton) does not match it.
      final button = tester.widget<PrimaryButton>(
        find.byKey(const ValueKey('live-shutter')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('the shutter is disabled while the camera is not running', (
      tester,
    ) async {
      await _pumpCamera(
        tester,
        status: LiveScanStatusOverride.stopped,
        snapshot: LiveValidationSnapshot.unknown(),
      );

      // Read from PrimaryButton itself. FilledButton.icon builds a private
      // subclass, so find.byType(FilledButton) does not match it.
      final button = tester.widget<PrimaryButton>(
        find.byKey(const ValueKey('live-shutter')),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('paid work never comes from a rebuild', () {
    testWidgets('rebuilding the page analyses nothing', (tester) async {
      final harness = await _pumpCamera(tester);

      for (var i = 0; i < 5; i += 1) {
        await tester.pump();
      }

      expect(harness.analysis.calls, 0);
      expect(harness.session.captureCalls, 0);
    });

    testWidgets('a theme change analyses nothing', (tester) async {
      for (final mode in <ThemeMode>[
        ThemeMode.light,
        ThemeMode.dark,
        ThemeMode.system,
      ]) {
        final harness = await _pumpCamera(tester, themeMode: mode);
        expect(harness.analysis.calls, 0, reason: 'theme $mode');
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('an orientation change analyses nothing', (tester) async {
      final harness = await _pumpCamera(tester);

      tester.view.physicalSize = const Size(873, 393);
      await tester.pumpAndSettle();

      expect(harness.analysis.calls, 0);
      expect(harness.session.captureCalls, 0);
    });

    testWidgets('a rebuild after capture does not analyse again', (
      tester,
    ) async {
      final harness = await _pumpCamera(tester);

      await tester.tap(find.byKey(const ValueKey('live-shutter')));
      await tester.pumpAndSettle();
      expect(harness.analysis.calls, 1);

      for (var i = 0; i < 5; i += 1) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        harness.analysis.calls,
        1,
        reason: 'a completed analysis must not be repeated by a rebuild',
      );
    });
  });

  group('resources', () {
    testWidgets('leaving the screen disposes the camera', (tester) async {
      final harness = await _pumpCamera(tester);

      // There is no gallery action on this route any more, so the way off the
      // screen is the global back control — which is the real exit path.
      final context = tester.element(find.byType(LiveCameraPage));
      GoRouter.of(context).go(AppConstants.scanRoute);
      await tester.pumpAndSettle();

      expect(find.text('Scan route'), findsOneWidget);
      expect(
        harness.session.disposeCalls,
        greaterThanOrEqualTo(1),
        reason: 'the camera must not stay open behind a closed screen',
      );
    });
  });

  group('accessibility and layout', () {
    testWidgets('the shutter carries an explicit semantic label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpCamera(tester);

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Take photo. Checks are ready.',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the face guide is hidden from screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpCamera(tester);

      // An alignment oval is useless to a screen-reader user and would sit
      // between them and the guidance that helps.
      expect(find.byType(ExcludeSemantics), findsWidgets);
      handle.dispose();
    });

    testWidgets('guidance is announced as a live region', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpCamera(tester, snapshot: _darkFail);

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
        findsWidgets,
      );
      handle.dispose();
    });

    testWidgets('renders at 320px and 2x text without overflow', (
      tester,
    ) async {
      await _pumpCamera(
        tester,
        size: const Size(320, 900),
        textScale: 2,
        snapshot: _darkFail,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Move toward better light'), findsOneWidget);

      await tester.ensureVisible(find.textContaining('checks ready'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('checks ready'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark theme without overflow', (tester) async {
      await _pumpCamera(
        tester,
        themeMode: ThemeMode.dark,
        platformBrightness: Brightness.dark,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Ready'), findsOneWidget);
    });
  });

  group('LSEP-4A: a single-purpose camera route', () {
    testWidgets('there is no gallery action on this route', (tester) async {
      await _pumpCamera(tester);

      // Gallery remains a capability of the app; it is simply not offered
      // again once the user has already opened the camera.
      expect(find.text('Choose from gallery'), findsNothing);
      expect(find.text('Choose another photo'), findsNothing);
      expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
    });

    testWidgets('the normal path does not scroll', (tester) async {
      await _pumpCamera(tester);

      // A fixed shell: no scrollable in the tree at all at POCO size and
      // default text.
      expect(find.byType(Scrollable), findsNothing);
      expect(find.byKey(const ValueKey('live-shutter')), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
    });

    testWidgets('everything stays visible without scrolling', (tester) async {
      await _pumpCamera(tester);

      final viewport = tester.view.physicalSize.height;
      for (final finder in <Finder>[
        find.text('New scan'),
        find.text('Ready'),
        find.byKey(const ValueKey('live-shutter')),
      ]) {
        final rect = tester.getRect(finder);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(
          rect.bottom,
          lessThanOrEqualTo(viewport),
          reason: 'must be on screen without scrolling',
        );
      }
    });

    testWidgets('the camera dominates the screen', (tester) async {
      await _pumpCamera(tester);

      final preview = tester.getRect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Live camera preview',
        ),
      );
      final shutter = tester.getRect(
        find.byKey(const ValueKey('live-shutter')),
      );
      expect(
        preview.height,
        greaterThan(shutter.height * 4),
        reason: 'status and controls must not compete with the preview',
      );
    });

    testWidgets('the preview uses the camera geometry, never a constant', (
      tester,
    ) async {
      await _pumpCamera(tester);

      // The harness preview owns a 3/4 display ratio, just as CameraPreview owns
      // its orientation-aware ratio in production. The page must preserve it
      // rather than impose a hardcoded shape of its own.
      final ratios = tester
          .widgetList<AspectRatio>(find.byType(AspectRatio))
          .map((widget) => widget.aspectRatio)
          .toList();
      expect(ratios, contains(3 / 4));
      // And nothing inside the preview scales, crops or transforms it.
      // Scoped to the preview subtree: Scaffold and InkWell bring Transforms
      // of their own, and forbidding those would assert nothing useful.
      final preview = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Live camera preview',
      );
      for (final forbidden in <Type>[FittedBox, OverflowBox, Transform]) {
        expect(
          find.descendant(of: preview, matching: find.byType(forbidden)),
          findsNothing,
          reason: 'the preview must not be -ed into shape',
        );
      }
    });

    testWidgets('an extreme text scale falls back to scrolling', (
      tester,
    ) async {
      await _pumpCamera(tester, size: const Size(320, 800), textScale: 2);

      // Non-scrolling is a goal for the normal path, never a reason to clip
      // copy or put the shutter out of reach.
      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsWidgets);

      // Reachable, which is the whole point of the fallback.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('live-shutter')),
        300,
      );
      expect(find.byKey(const ValueKey('live-shutter')), findsOneWidget);
    });

    testWidgets('the shared global top bar is reused', (tester) async {
      await _pumpCamera(tester);

      expect(find.byType(FaceTuneTopBar), findsOneWidget);
      expect(find.text('New scan'), findsOneWidget);
    });

    testWidgets('a camera still warming up says so', (tester) async {
      await _pumpCamera(
        tester,
        status: LiveScanStatusOverride.starting,
        snapshot: LiveValidationSnapshot.unknown(),
      );

      expect(find.text('Preparing camera…'), findsOneWidget);
      // No count before anything has been counted.
      expect(find.textContaining('checks ready'), findsNothing);
      expect(find.textContaining('not checked yet'), findsNothing);
    });
  });
}
