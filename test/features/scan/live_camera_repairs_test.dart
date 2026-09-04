import 'dart:async';
import 'dart:typed_data';

import 'package:facetune/features/scan/domain/entities/live_check.dart';
import 'package:facetune/features/scan/domain/entities/live_frame.dart';
import 'package:facetune/features/scan/domain/entities/live_validation_snapshot.dart';
import 'package:facetune/features/scan/domain/repositories/live_frame_source.dart';
import 'package:facetune/features/scan/domain/services/live_frame_analyzer.dart';
import 'package:facetune/features/scan/presentation/controllers/live_scan_controller.dart';
import 'package:facetune/features/scan/presentation/controllers/live_scan_state.dart';
import 'package:facetune/features/scan/presentation/utils/live_guidance.dart';
import 'package:flutter_test/flutter_test.dart';

/// LSEP-4A: the four defects this phase root-caused, each held down by a test.
///
/// 1. Frames whose stride the platform did not report were judged unmeasurable,
///    so every check sat at "not checked yet" forever.
/// 2. Every dropped frame published a notifier update — ~25/sec — which rebuilt
///    the camera preview continuously and read as a frozen screen.
/// 3. A single noisy reading could flip Ready to Checking and back.
/// 4. The copy described states the app was not in.
class _FakeSource implements LiveFrameSource {
  final _frames = StreamController<LiveFrame>.broadcast();
  var _sequence = 0;

  @override
  Stream<LiveFrame> get frames => _frames.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    if (!_frames.isClosed) await _frames.close();
  }

  /// Emits a frame whose buffer is always well formed.
  ///
  /// [bytesPerRow] is what the *platform claims*, which is the thing under
  /// test — the buffer itself is sized from the real row length, exactly as a
  /// real device delivers it.
  void emit({int width = 32, int height = 32, int? bytesPerRow}) {
    final actualStride = (bytesPerRow != null && bytesPerRow >= width)
        ? bytesPerRow
        : width;
    final length = actualStride * height;
    _frames.add(
      LiveFrame(
        luma: Uint8List(length)..fillRange(0, length, 120),
        width: width,
        height: height,
        bytesPerRow: bytesPerRow,
        sequence: _sequence++,
      ),
    );
  }
}

class _ManualClock {
  DateTime now = DateTime.utc(2026, 9, 4);
  DateTime call() => now;
  void advance(Duration by) => now = now.add(by);
}

const _pass = LiveValidationSnapshot({
  LiveCheck.lighting: LiveCheckState.pass,
  LiveCheck.sharpness: LiveCheckState.pass,
  LiveCheck.steadiness: LiveCheckState.pass,
});

const _warn = LiveValidationSnapshot({
  LiveCheck.lighting: LiveCheckState.warning,
  LiveCheck.sharpness: LiveCheckState.pass,
  LiveCheck.steadiness: LiveCheckState.pass,
});

const _fail = LiveValidationSnapshot({
  LiveCheck.lighting: LiveCheckState.fail,
  LiveCheck.sharpness: LiveCheckState.pass,
  LiveCheck.steadiness: LiveCheckState.pass,
});

void main() {
  group('defect 1 — an unreported stride must not disable every check', () {
    test('a frame reporting bytesPerRow 0 is still measurable', () {
      const width = 32;
      const height = 32;
      final frame = LiveFrame(
        luma: Uint8List(width * height)..fillRange(0, width * height, 130),
        width: width,
        height: height,
        // camera_android_camerax reports 0 for some format/device pairs.
        bytesPerRow: 0,
        sequence: 0,
      );

      expect(frame.stride, width, reason: 'an impossible stride is ignored');
      expect(frame.isMeasurable, isTrue);
      expect(LiveFrameAnalyzer().measure(frame), isNotNull);
    });

    test('a frame reporting a null stride is still measurable', () {
      final frame = LiveFrame(
        luma: Uint8List(32 * 32)..fillRange(0, 32 * 32, 130),
        width: 32,
        height: 32,
        sequence: 0,
      );
      expect(frame.isMeasurable, isTrue);
    });

    test('a short buffer is measured over the rows it holds', () {
      // Half the rows the header claims. Previously rejected outright, which
      // produced no reading at all.
      const width = 32;
      final frame = LiveFrame(
        luma: Uint8List(width * 10)..fillRange(0, width * 10, 200),
        width: width,
        height: 20,
        sequence: 0,
      );

      expect(frame.usableRows, 10);
      expect(frame.isMeasurable, isTrue);
      final measured = LiveFrameAnalyzer().measure(frame);
      expect(measured, isNotNull);
      expect(measured!.meanLuma, closeTo(200, 0.01));
    });

    test('a genuinely empty buffer is still rejected', () {
      final frame = LiveFrame(
        luma: Uint8List(0),
        width: 32,
        height: 32,
        sequence: 0,
      );
      expect(frame.usableRows, 0);
      expect(frame.isMeasurable, isFalse);
    });

    test('a padded stride is still honoured', () {
      const width = 32;
      const stride = 48;
      const height = 8;
      final bytes = Uint8List(stride * height);
      for (var y = 0; y < height; y += 1) {
        for (var x = 0; x < stride; x += 1) {
          bytes[y * stride + x] = x < width ? 100 : 255;
        }
      }
      final measured = LiveFrameAnalyzer().measure(
        LiveFrame(
          luma: bytes,
          width: width,
          height: height,
          bytesPerRow: stride,
          sequence: 0,
        ),
      );
      expect(measured!.meanLuma, closeTo(100, 0.01));
    });

    test('real frames move the checks off unknown', () async {
      final source = _FakeSource();
      final clock = _ManualClock();
      final controller = LiveScanController(source: source, clock: clock.call);
      addTearDown(controller.dispose);

      await controller.start();
      for (var i = 0; i < 4; i += 1) {
        source.emit(bytesPerRow: 0);
        await Future<void>.delayed(Duration.zero);
        clock.advance(const Duration(seconds: 1));
      }

      expect(controller.state.hasSampled, isTrue);
      expect(
        controller.state.snapshot.stateOf(LiveCheck.lighting),
        isNot(LiveCheckState.unknown),
        reason: 'a measured frame must produce a measured lighting state',
      );
    });
  });

  group('defect 2 — dropped frames must not repaint the screen', () {
    test('dropping frames publishes no state', () async {
      final source = _FakeSource();
      final clock = _ManualClock();
      final controller = LiveScanController(
        source: source,
        clock: clock.call,
        analyzeFrame: (_) async => _pass,
      );
      addTearDown(controller.dispose);

      await controller.start();
      source.emit();
      await Future<void>.delayed(Duration.zero);

      var notifications = 0;
      final removeListener = controller.addListener(
        (_) => notifications += 1,
        fireImmediately: false,
      );

      // Sixty frames inside the cadence window — what a second of 60fps looks
      // like. Every one is dropped.
      for (var i = 0; i < 60; i += 1) {
        source.emit();
        await Future<void>.delayed(Duration.zero);
      }
      removeListener();

      expect(controller.droppedFrames, 60);
      expect(
        notifications,
        0,
        reason: 'dropping a frame is bookkeeping, not news',
      );
    });

    test('a steady scene publishes nothing after it settles', () async {
      final source = _FakeSource();
      final clock = _ManualClock();
      final controller = LiveScanController(
        source: source,
        clock: clock.call,
        analyzeFrame: (_) async => _pass,
      );
      addTearDown(controller.dispose);

      await controller.start();
      for (var i = 0; i < 4; i += 1) {
        source.emit();
        await Future<void>.delayed(Duration.zero);
        clock.advance(const Duration(seconds: 1));
      }

      var notifications = 0;
      final removeListener = controller.addListener(
        (_) => notifications += 1,
        fireImmediately: false,
      );
      for (var i = 0; i < 10; i += 1) {
        source.emit();
        await Future<void>.delayed(Duration.zero);
        clock.advance(const Duration(seconds: 1));
      }
      removeListener();

      expect(
        notifications,
        0,
        reason: 'an unchanged reading must not rebuild the camera screen',
      );
    });

    test('a real change does publish', () async {
      final source = _FakeSource();
      final clock = _ManualClock();
      var snapshot = _pass;
      final controller = LiveScanController(
        source: source,
        clock: clock.call,
        analyzeFrame: (_) async => snapshot,
      );
      addTearDown(controller.dispose);

      await controller.start();
      for (var i = 0; i < 3; i += 1) {
        source.emit();
        await Future<void>.delayed(Duration.zero);
        clock.advance(const Duration(seconds: 1));
      }
      expect(controller.state.snapshot, _pass);

      snapshot = _fail;
      source.emit();
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state.snapshot,
        _fail,
        reason: 'a severe failure is published immediately',
      );
    });
  });

  group('defect 3 — Ready must not flicker', () {
    test('one disagreeing warning does not immediately revoke Ready', () async {
      final source = _FakeSource();
      final clock = _ManualClock();
      var snapshot = _pass;
      final controller = LiveScanController(
        source: source,
        clock: clock.call,
        analyzeFrame: (_) async => snapshot,
      );
      addTearDown(controller.dispose);

      await controller.start();
      for (var i = 0; i < 3; i += 1) {
        source.emit();
        await Future<void>.delayed(Duration.zero);
        clock.advance(const Duration(seconds: 1));
      }
      expect(controller.state.isReady, isTrue);

      // A single noisy sample.
      snapshot = _warn;
      source.emit();
      await Future<void>.delayed(Duration.zero);
      clock.advance(const Duration(seconds: 1));

      expect(
        controller.state.isReady,
        isTrue,
        reason: 'one sample must not flip the headline',
      );

      // Sustained, so it is real.
      source.emit();
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.isReady, isFalse);
    });

    test('hysteresis is not an auto-capture window', () {
      // A behavioural restatement of the hard lock. The controller has no
      // capture surface at all, so no amount of agreement can take a photo.
      final controller = LiveScanController(source: _FakeSource());
      addTearDown(controller.dispose);
      expect(LiveScanController.agreementThreshold, greaterThan(1));
      expect(controller.state.eligibility, LiveCaptureEligibility.blocked);
    });
  });

  group('defect 4 — the copy must describe a real state', () {
    test('before any measurement the screen says it is preparing', () {
      final state = LiveScanState(status: LiveScanStatus.running);
      expect(state.hasSampled, isFalse);
      expect(LiveGuidance.title(state), LiveGuidance.preparingTitle);
      expect(
        LiveGuidance.checkSummary(state),
        isNull,
        reason: '"0 of 3 checks ready" states a result that has not happened',
      );
    });

    test('there is no permanent Checking headline', () {
      for (final status in LiveScanStatus.values) {
        for (final sampled in <bool>[true, false]) {
          final title = LiveGuidance.title(
            LiveScanState(
              status: status,
              hasSampled: sampled,
              snapshot: _pass,
              errorMessage: status == LiveScanStatus.stopped ? 'x' : null,
            ),
          );
          expect(
            title,
            isNot('Checking…'),
            reason: '$status / sampled=$sampled must not report Checking',
          );
        }
      }
    });

    test('no check reads "not checked yet" once sampling has begun', () {
      for (final check in LiveCheck.values) {
        for (final state in LiveCheckState.values) {
          expect(
            LiveGuidance.checkLabel(check, state),
            isNot(contains('not checked yet')),
          );
        }
      }
    });

    test('sharpness is never labelled Focus', () {
      expect(
        LiveGuidance.checkLabel(LiveCheck.sharpness, LiveCheckState.pass),
        startsWith('Sharpness'),
        reason: 'the app never reads the lens autofocus state',
      );
    });

    test('a measured session reports its counts', () {
      final state = LiveScanState(
        status: LiveScanStatus.running,
        hasSampled: true,
        snapshot: _warn,
      );
      expect(LiveGuidance.checkSummary(state), '2 of 3 checks ready');
      expect(LiveGuidance.title(state), 'A little more light would help');
    });
  });
}
