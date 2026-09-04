import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/live_frame.dart';
import '../../domain/entities/live_validation_snapshot.dart';
import '../../domain/repositories/live_frame_source.dart';
import '../../domain/services/live_frame_analyzer.dart';
import 'live_scan_state.dart';

/// The single owner of live-validation state.
///
/// Holds the current snapshot, the in-flight flag, the session generation
/// token, and the counters — so there is exactly one place that decides what
/// the camera surface is showing, and exactly one place a stale result can be
/// rejected.
///
/// **This controller cannot take a photograph.** There is no capture method, no
/// timer, and no path from a `pass` state to a shutter. Capture is a user
/// action on the screen that owns the shutter, and the Source of Truth forbids
/// it ever becoming anything else. A stability window may one day settle the
/// *display*; it must never settle into a countdown.
///
/// **No paid work.** Nothing here touches Supabase, an Edge Function, Gemini,
/// or the network. Frames are analysed with local arithmetic and dropped.
class LiveScanController extends StateNotifier<LiveScanState> {
  LiveScanController({
    required LiveFrameSource source,
    LiveFrameAnalyzer? analyzer,
    this.cadence = defaultCadence,
    DateTime Function() clock = DateTime.now,
    Future<LiveValidationSnapshot?> Function(LiveFrame frame)? analyzeFrame,
  }) : _source = source,
       _analyzer = analyzer ?? LiveFrameAnalyzer(),
       _clock = clock,
       _analyzeOverride = analyzeFrame,
       super(LiveScanState());

  /// The minimum gap between two analyses.
  ///
  /// **PROVISIONAL — not measured on a device.** The Source of Truth requires
  /// the cadence to be measured rather than invented, and no Android device was
  /// available for this phase. 200ms (5Hz) is a deliberately conservative
  /// starting point: fast enough that guidance feels live, slow enough that a
  /// 30-60fps stream cannot saturate the isolate. It is injectable precisely so
  /// the LSEP-4 device pass can replace it with a measured value.
  static const defaultCadence = Duration(milliseconds: 200);

  final LiveFrameSource _source;
  final LiveFrameAnalyzer _analyzer;
  final DateTime Function() _clock;

  /// Replaces the measurement step.
  ///
  /// Exists so a test can hold an analysis open and prove that the in-flight
  /// guard, the drop-don't-queue rule, and the stale-result rejection actually
  /// fire. In production this is null and [_analyzer] runs.
  final Future<LiveValidationSnapshot?> Function(LiveFrame frame)?
  _analyzeOverride;

  /// Minimum interval between analyses. See [defaultCadence].
  final Duration cadence;

  StreamSubscription<LiveFrame>? _subscription;

  /// Incremented on every start, stop and dispose.
  ///
  /// The stale-result guard. A result computed for generation N is discarded
  /// unless the controller is still on generation N when it lands, so a frame
  /// analysed just before the camera stopped can never overwrite the state of
  /// the session that replaced it.
  int _generation = 0;

  bool _analyzing = false;
  DateTime? _lastAnalysisAt;
  bool _disposed = false;

  /// Frames dropped this session.
  ///
  /// A plain field, deliberately not part of the published state. LSEP-4A: it
  /// used to live on the state, so every dropped frame produced a notifier
  /// update — roughly twenty-five per second at 30fps against a 200ms cadence.
  /// That rebuilt the whole camera screen, `CameraPreview` included, dozens of
  /// times a second, which on a device reads as a preview that has frozen.
  /// Dropping a frame is bookkeeping, not news.
  int _droppedFrames = 0;

  /// Frames analysed this session.
  int _analyzedFrames = 0;

  /// How many consecutive analyses have agreed with the pending snapshot.
  int _agreementRun = 0;

  /// The snapshot waiting for enough agreement to be published.
  LiveValidationSnapshot? _pending;

  /// Frames dropped this session, for diagnostics and tests.
  int get droppedFrames => _droppedFrames;

  /// How many consecutive agreeing readings promote a snapshot.
  ///
  /// Hysteresis, not a timer. Two agreeing readings at the sampling cadence is
  /// a fraction of a second — enough to stop a single noisy frame flipping
  /// Ready to Checking and back, and far too little to be mistaken for a
  /// countdown. A severe failure bypasses it entirely, because telling someone
  /// their shot is fine for one more beat when it is not would be worse than a
  /// flicker.
  ///
  /// **This is not, and must never become, an auto-capture window.** Ready may
  /// sit here indefinitely; only a tap takes a photograph.
  static const agreementThreshold = 2;

  /// Visible for tests: the current session token.
  int get generation => _generation;

  /// Visible for tests: whether an analysis is in flight.
  bool get isAnalyzing => _analyzing;

  /// Starts a session.
  ///
  /// Re-entrant: starting an already-running session is a no-op rather than a
  /// second subscription, because a rebuild must never double-subscribe.
  Future<void> start() async {
    if (_disposed) return;
    if (state.status == LiveScanStatus.starting ||
        state.status == LiveScanStatus.running) {
      return;
    }
    final generation = ++_generation;
    _analyzer.reset();
    _resetSession();
    state = LiveScanState(status: LiveScanStatus.starting);
    try {
      await _source.start();
      if (_disposed || generation != _generation) return;
      _subscription = _source.frames.listen(
        _onFrame,
        onError: (Object _) {
          if (_disposed || generation != _generation) return;
          state = state.copyWith(
            status: LiveScanStatus.stopped,
            isAnalyzing: false,
            errorMessage: 'The camera stopped unexpectedly. Try again.',
          );
        },
      );
      state = state.copyWith(
        status: LiveScanStatus.running,
        snapshot: LiveValidationSnapshot.unknown(),
        clearError: true,
      );
    } catch (_) {
      if (_disposed || generation != _generation) return;
      // Sanitized: a platform exception can name device internals, and this
      // string is rendered to the user.
      state = LiveScanState(
        status: LiveScanStatus.stopped,
        errorMessage: 'FaceTune could not open the camera. Try again.',
      );
    }
  }

  /// Stops the session and invalidates anything still in flight.
  Future<void> stop() async {
    if (_disposed) return;
    _generation += 1;
    _analyzer.reset();
    _resetSession();
    await _cancelSubscription();
    try {
      await _source.stop();
    } catch (_) {
      // Stopping is best-effort. A source that fails to stop must not strand
      // the state machine in `running`.
    }
    if (_disposed) return;
    state = LiveScanState(status: LiveScanStatus.stopped);
  }

  /// Handles one frame from the source.
  ///
  /// The whole no-queue contract lives here, and it is intentionally three
  /// cheap guards executed in order before any work happens:
  ///
  ///  1. wrong generation, disposed, or not running — ignore outright;
  ///  2. an analysis already in flight — **drop the frame**, never queue it;
  ///  3. inside the cadence window — drop the frame.
  ///
  /// Dropping rather than buffering is what bounds this. A camera emits faster
  /// than analysis completes, so any queue grows without limit and every result
  /// it yields describes a moment that has already passed.
  void _onFrame(LiveFrame frame) {
    if (_disposed || state.status != LiveScanStatus.running) return;
    if (_analyzing) {
      _droppedFrames += 1;
      return;
    }
    final now = _clock();
    final last = _lastAnalysisAt;
    if (last != null && now.difference(last) < cadence) {
      _droppedFrames += 1;
      return;
    }

    final generation = _generation;
    _analyzing = true;
    _lastAnalysisAt = now;

    unawaited(
      _analyze(frame)
          .then((result) {
            // Latest-result authority. A result only reaches the state if the
            // session it was computed for is still the current one, so an
            // analysis that was in flight when the camera stopped — or when a
            // new session started — is discarded rather than painted over the
            // session that replaced it.
            if (_disposed || generation != _generation) return;
            if (state.status != LiveScanStatus.running) return;
            _publish(result);
          })
          .catchError((Object _) {
            // A measurement failure is not worth showing anyone: the next frame
            // is milliseconds away. The previous snapshot stands.
            if (_disposed || generation != _generation) return;
            if (state.status != LiveScanStatus.running) return;
            state = state.copyWith(isAnalyzing: false);
          })
          .whenComplete(() {
            // Cleared even for a stale result, so a superseded session cannot
            // leave the flag stuck and starve the current one.
            _analyzing = false;
          }),
    );
  }

  /// Clears everything scoped to one live session.
  ///
  /// Called on every start and stop, so a new session never inherits the
  /// previous one's counters, pending reading, or agreement run.
  void _resetSession() {
    _analyzing = false;
    _lastAnalysisAt = null;
    _droppedFrames = 0;
    _analyzedFrames = 0;
    _agreementRun = 0;
    _pending = null;
  }

  /// Applies one analysis result, with hysteresis, and notifies only on change.
  ///
  /// Two rules, both there to stop the screen twitching:
  ///
  ///  * a reading is promoted only once [agreementThreshold] consecutive
  ///    analyses agree with it — except a severe failure, which is published at
  ///    once, because withholding "this is too dark to use" to avoid a flicker
  ///    is the wrong trade;
  ///  * the state is written only when the published snapshot actually
  ///    differs, so a steady scene produces no notifier traffic at all.
  void _publish(LiveValidationSnapshot? result) {
    final sampled = state.hasSampled;
    if (result == null) {
      if (!sampled) state = state.copyWith(hasSampled: true);
      return;
    }

    if (result == _pending) {
      _agreementRun += 1;
    } else {
      _pending = result;
      _agreementRun = 1;
    }

    final settled =
        _agreementRun >= agreementThreshold || result.hasFailure || !sampled;
    if (!settled) {
      if (!sampled) state = state.copyWith(hasSampled: true);
      return;
    }

    if (state.snapshot == result && sampled) {
      // Nothing changed on screen. The count still moves, because it is what
      // proves frames are being read at all.
      _analyzedFrames += 1;
      return;
    }
    _analyzedFrames += 1;
    state = state.copyWith(
      snapshot: result,
      hasSampled: true,
      analyzedFrames: _analyzedFrames,
    );
  }

  /// Runs the measurement for one frame.
  ///
  /// The default path evaluates [LiveFrameAnalyzer.analyze] *synchronously*
  /// before returning its future. That is deliberate: the platform may recycle
  /// a frame's buffer as soon as the stream listener returns, so the bytes have
  /// to be read inside this turn. Only the delivery of the result is deferred.
  Future<LiveValidationSnapshot?> _analyze(LiveFrame frame) {
    final override = _analyzeOverride;
    if (override != null) return override(frame);
    return Future<LiveValidationSnapshot?>.value(_analyzer.analyze(frame));
  }

  Future<void> _cancelSubscription() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    _analyzing = false;
    unawaited(_cancelSubscription());
    // Best-effort release. The camera must not be held after the screen is
    // gone, and a failure to release cannot be surfaced to a disposed notifier.
    unawaited(Future<void>.sync(_source.dispose).catchError((Object _) {}));
    super.dispose();
  }
}
