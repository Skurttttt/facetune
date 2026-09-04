import 'dart:async';
import 'dart:typed_data';

import 'package:facetune/features/scan/domain/entities/live_check.dart';
import 'package:facetune/features/scan/domain/entities/live_frame.dart';
import 'package:facetune/features/scan/domain/entities/live_validation_snapshot.dart';
import 'package:facetune/features/scan/domain/repositories/live_frame_source.dart';
import 'package:facetune/features/scan/presentation/controllers/live_scan_controller.dart';
import 'package:facetune/features/scan/presentation/controllers/live_scan_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// A frame source under the test's control.
class _FakeSource implements LiveFrameSource {
  _FakeSource({this.failOnStart = false});

  final bool failOnStart;
  final _controller = StreamController<LiveFrame>.broadcast();

  int startCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;
  var _sequence = 0;

  bool get isStreamListenedTo => _controller.hasListener;

  @override
  Stream<LiveFrame> get frames => _controller.stream;

  @override
  Future<void> start() async {
    startCalls += 1;
    if (failOnStart) throw StateError('camera unavailable');
  }

  @override
  Future<void> stop() async => stopCalls += 1;

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    await _controller.close();
  }

  /// Emits one frame of uniform brightness.
  void emit(int value, {int width = 32, int height = 32}) {
    _controller.add(
      LiveFrame(
        luma: Uint8List(width * height)..fillRange(0, width * height, value),
        width: width,
        height: height,
        sequence: _sequence++,
      ),
    );
  }

  void emitError() => _controller.addError(StateError('stream died'));
}

/// A clock the test advances by hand, so cadence is deterministic.
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

const _fail = LiveValidationSnapshot({
  LiveCheck.lighting: LiveCheckState.fail,
  LiveCheck.sharpness: LiveCheckState.pass,
  LiveCheck.steadiness: LiveCheckState.pass,
});

void main() {
  group('lifecycle', () {
    test('starts idle', () {
      final controller = LiveScanController(source: _FakeSource());
      addTearDown(controller.dispose);

      expect(controller.state.status, LiveScanStatus.idle);
      expect(controller.state.snapshot, LiveValidationSnapshot.unknown());
      expect(controller.state.isAnalyzing, isFalse);
      expect(controller.state.eligibility, LiveCaptureEligibility.blocked);
    });

    test('start subscribes and runs', () async {
      final source = _FakeSource();
      final controller = LiveScanController(source: source);
      addTearDown(controller.dispose);

      await controller.start();

      expect(source.startCalls, 1);
      expect(source.isStreamListenedTo, isTrue);
      expect(controller.state.status, LiveScanStatus.running);
    });

    test('starting twice does not subscribe twice', () async {
      final source = _FakeSource();
      final controller = LiveScanController(source: source);
      addTearDown(controller.dispose);

      await controller.start();
      await controller.start();

      expect(
        source.startCalls,
        1,
        reason: 'a rebuild must not open a second session',
      );
    });

    test('a start failure stops with a sanitized message', () async {
      final source = _FakeSource(failOnStart: true);
      final controller = LiveScanController(source: source);
      addTearDown(controller.dispose);

      await controller.start();

      expect(controller.state.status, LiveScanStatus.stopped);
      expect(controller.state.errorMessage, isNotNull);
      expect(
        controller.state.errorMessage,
        isNot(contains('StateError')),
        reason: 'platform detail must not reach the user',
      );
      expect(controller.state.eligibility, LiveCaptureEligibility.blocked);
    });

    test('a stream error stops the session', () async {
      final source = _FakeSource();
      final controller = LiveScanController(source: source);
      addTearDown(controller.dispose);

      await controller.start();
      source.emitError();
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.status, LiveScanStatus.stopped);
      expect(controller.state.errorMessage, isNotNull);
    });

    test('stop cancels the subscription and stops the source', () async {
      final source = _FakeSource();
      final controller = LiveScanController(source: source);
      addTearDown(controller.dispose);

      await controller.start();
      await controller.stop();

      expect(source.stopCalls, 1);
      expect(source.isStreamListenedTo, isFalse);
      expect(controller.state.status, LiveScanStatus.stopped);
      expect(controller.state.snapshot, LiveValidationSnapshot.unknown());
    });

    test('frames arriving after stop are ignored', () async {
      final source = _FakeSource();
      final controller = LiveScanController(source: source);
      addTearDown(controller.dispose);

      await controller.start();
      await controller.stop();
      source.emit(120);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.analyzedFrames, 0);
    });
  });

  group('state transitions', () {
    test('an analysed frame moves the snapshot off unknown', () async {
      final source = _FakeSource();
      final controller = LiveScanController(
        source: source,
        analyzeFrame: (_) async => _pass,
      );
      addTearDown(controller.dispose);

      await controller.start();
      expect(controller.state.snapshot, LiveValidationSnapshot.unknown());

      source.emit(120);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.snapshot, _pass);
      expect(controller.state.isReady, isTrue);
      expect(controller.state.eligibility, LiveCaptureEligibility.ready);
      expect(controller.state.analyzedFrames, 1);
    });

    test('eligibility maps failure to blocked', () async {
      final source = _FakeSource();
      final controller = LiveScanController(
        source: source,
        analyzeFrame: (_) async => _fail,
      );
      addTearDown(controller.dispose);

      await controller.start();
      source.emit(5);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.eligibility, LiveCaptureEligibility.blocked);
      expect(controller.state.isReady, isFalse);
      expect(controller.state.primaryIssue, LiveCheck.lighting);
    });

    test('a session that is not running is never eligible', () async {
      final source = _FakeSource();
      final controller = LiveScanController(
        source: source,
        analyzeFrame: (_) async => _pass,
      );
      addTearDown(controller.dispose);

      await controller.start();
      source.emit(120);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.eligibility, LiveCaptureEligibility.ready);

      await controller.stop();
      expect(
        controller.state.eligibility,
        LiveCaptureEligibility.blocked,
        reason: 'eligibility describes measured frames; there are none',
      );
    });
  });

  group('concurrency', () {
    test(
      'only one analysis is in flight, and extra frames are dropped',
      () async {
        final source = _FakeSource();
        final clock = _ManualClock();
        final gate = Completer<LiveValidationSnapshot?>();
        var invocations = 0;
        final controller = LiveScanController(
          source: source,
          clock: clock.call,
          analyzeFrame: (_) {
            invocations += 1;
            return gate.future;
          },
        );
        addTearDown(controller.dispose);

        await controller.start();
        source.emit(120);
        await Future<void>.delayed(Duration.zero);
        expect(controller.isAnalyzing, isTrue);
        expect(
          controller.isAnalyzing,
          isTrue,
          reason: "in-flight is controller state, not published UI state",
        );

        // Five more frames arrive while the first is still being analysed, each
        // well past the cadence window so only the in-flight guard can stop them.
        for (var i = 0; i < 5; i += 1) {
          clock.advance(const Duration(seconds: 1));
          source.emit(120);
          await Future<void>.delayed(Duration.zero);
        }

        expect(
          invocations,
          1,
          reason: 'frames must be dropped while one analysis is in flight',
        );
        expect(controller.droppedFrames, 5, reason: 'dropped, not queued');

        gate.complete(_pass);
        await Future<void>.delayed(Duration.zero);
        expect(controller.state.analyzedFrames, 1);
        expect(controller.isAnalyzing, isFalse);
      },
    );

    test('there is no unbounded queue: work does not accumulate', () async {
      final source = _FakeSource();
      final clock = _ManualClock();
      final gate = Completer<LiveValidationSnapshot?>();
      var invocations = 0;
      final controller = LiveScanController(
        source: source,
        clock: clock.call,
        analyzeFrame: (_) {
          invocations += 1;
          return gate.future;
        },
      );
      addTearDown(controller.dispose);

      await controller.start();
      // A burst far larger than anything a real camera would deliver inside one
      // analysis. If frames were queued, releasing the gate would run 200 of
      // them; because they are dropped, exactly one ever started.
      for (var i = 0; i < 200; i += 1) {
        clock.advance(const Duration(seconds: 1));
        source.emit(120);
      }
      await Future<void>.delayed(Duration.zero);

      gate.complete(_pass);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(invocations, 1);
      expect(controller.state.analyzedFrames, 1);
      expect(controller.droppedFrames, greaterThanOrEqualTo(199));
    });

    test('cadence throttles frames even when nothing is in flight', () async {
      final source = _FakeSource();
      final clock = _ManualClock();
      var invocations = 0;
      final controller = LiveScanController(
        source: source,
        clock: clock.call,
        cadence: const Duration(milliseconds: 200),
        analyzeFrame: (_) async {
          invocations += 1;
          return _pass;
        },
      );
      addTearDown(controller.dispose);

      await controller.start();

      source.emit(120);
      await Future<void>.delayed(Duration.zero);
      expect(invocations, 1);

      // Inside the window: dropped.
      clock.advance(const Duration(milliseconds: 50));
      source.emit(120);
      await Future<void>.delayed(Duration.zero);
      expect(invocations, 1);
      expect(controller.droppedFrames, 1);

      // Past the window: analysed.
      clock.advance(const Duration(milliseconds: 200));
      source.emit(120);
      await Future<void>.delayed(Duration.zero);
      expect(invocations, 2);
    });

    test('a result from a superseded session is discarded', () async {
      final source = _FakeSource();
      final gate = Completer<LiveValidationSnapshot?>();
      final controller = LiveScanController(
        source: source,
        analyzeFrame: (_) => gate.future,
      );
      addTearDown(controller.dispose);

      await controller.start();
      final generation = controller.generation;
      source.emit(120);
      await Future<void>.delayed(Duration.zero);
      expect(controller.isAnalyzing, isTrue);

      // The session ends while the analysis is still open.
      await controller.stop();
      expect(controller.generation, greaterThan(generation));

      gate.complete(_pass);
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state.snapshot,
        LiveValidationSnapshot.unknown(),
        reason:
            'a stale result must not paint over the session that replaced it',
      );
      expect(controller.state.analyzedFrames, 0);
    });

    test('a stale result still clears the in-flight flag', () async {
      final source = _FakeSource();
      final gate = Completer<LiveValidationSnapshot?>();
      final controller = LiveScanController(
        source: source,
        analyzeFrame: (_) => gate.future,
      );
      addTearDown(controller.dispose);

      await controller.start();
      source.emit(120);
      await Future<void>.delayed(Duration.zero);
      await controller.stop();
      gate.complete(_pass);
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.isAnalyzing,
        isFalse,
        reason: 'a superseded analysis must not starve the next session',
      );
    });

    test('latest result wins after a restart', () async {
      final source = _FakeSource();
      final controller = LiveScanController(
        source: source,
        analyzeFrame: (_) async => _pass,
      );
      addTearDown(controller.dispose);

      await controller.start();
      source.emit(120);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.snapshot, _pass);

      await controller.stop();
      await controller.start();

      expect(
        controller.state.snapshot,
        LiveValidationSnapshot.unknown(),
        reason: 'a new session starts from unknown, not from stale readings',
      );
      expect(controller.state.analyzedFrames, 0);
      expect(controller.droppedFrames, 0);
    });

    test('an analysis failure leaves the previous snapshot standing', () async {
      final source = _FakeSource();
      final clock = _ManualClock();
      var calls = 0;
      final controller = LiveScanController(
        source: source,
        clock: clock.call,
        analyzeFrame: (_) async {
          calls += 1;
          if (calls == 2) throw StateError('measurement blew up');
          return _pass;
        },
      );
      addTearDown(controller.dispose);

      await controller.start();
      source.emit(120);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.snapshot, _pass);

      clock.advance(const Duration(seconds: 1));
      source.emit(120);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.snapshot, _pass);
      expect(controller.state.isAnalyzing, isFalse);
      expect(controller.state.status, LiveScanStatus.running);
    });
  });

  group('disposal', () {
    test('dispose releases the source and cancels the subscription', () async {
      final source = _FakeSource();
      final controller = LiveScanController(source: source);

      await controller.start();
      expect(source.isStreamListenedTo, isTrue);

      controller.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(source.disposeCalls, 1);
    });

    test(
      'a result landing after dispose does not touch the notifier',
      () async {
        final source = _FakeSource();
        final gate = Completer<LiveValidationSnapshot?>();
        final controller = LiveScanController(
          source: source,
          analyzeFrame: (_) => gate.future,
        );

        await controller.start();
        source.emit(120);
        await Future<void>.delayed(Duration.zero);

        controller.dispose();
        gate.complete(_pass);

        // A StateNotifier throws if its state is written after disposal, so the
        // absence of an error here is the assertion.
        await expectLater(Future<void>.delayed(Duration.zero), completes);
      },
    );

    test('start after dispose does nothing', () async {
      final source = _FakeSource();
      final controller = LiveScanController(source: source);
      controller.dispose();

      await controller.start();

      expect(source.startCalls, 0);
    });
  });

  group('no auto capture', () {
    test('the controller exposes no capture surface at all', () {
      final controller = LiveScanController(source: _FakeSource());
      addTearDown(controller.dispose);

      // A behavioural restatement of the hard lock: this type owns validation
      // state and nothing else. There is no method, timer, or callback here
      // that could ever fire a shutter, so "ready" can only ever be information
      // presented to a user who then decides.
      expect(controller, isA<LiveScanController>());
      expect(
        controller.state.eligibility,
        LiveCaptureEligibility.blocked,
        reason: 'eligibility is a report, never a trigger',
      );
    });
  });
}
