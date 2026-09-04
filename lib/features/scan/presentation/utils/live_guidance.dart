import '../../domain/entities/live_check.dart';
import '../controllers/live_scan_state.dart';

/// One line of guidance, and only one.
///
/// The Source of Truth is explicit that the camera must not permanently show a
/// wall of changing checks. A user framing their own face can act on one
/// instruction; three status rows updating several times a second are noise, and
/// on a screen reader they are worse than noise.
///
/// So the detailed states remain available — the compact counter exposes them —
/// but the headline is always the single most actionable thing.
///
/// **Every string here describes a state the app is actually in.** LSEP-4A
/// removed two that did not: a permanent-looking "Checking…" headline, and a
/// "not checked yet" row that persisted long after sampling had begun. Both
/// read as a broken feature rather than as a camera getting ready.
abstract final class LiveGuidance {
  static const readyTitle = 'Ready';
  static const readyBody = "Take the photo when you're happy with your look.";
  static const preparingTitle = 'Preparing camera…';

  /// The headline for the current state.
  static String title(LiveScanState state) {
    switch (state.status) {
      case LiveScanStatus.idle:
      case LiveScanStatus.starting:
        return preparingTitle;
      case LiveScanStatus.stopped:
        return 'Camera unavailable';
      case LiveScanStatus.running:
        // Frames are arriving but none has been measured yet. Honest, and
        // short-lived: the first reading lands within one cadence window.
        if (!state.hasSampled) return preparingTitle;
        if (state.isReady) return readyTitle;
        final issue = state.primaryIssue;
        if (issue == null) return readyTitle;
        return _titleFor(issue, state.snapshot.stateOf(issue));
    }
  }

  /// The supporting line, or null when the headline says enough.
  static String? body(LiveScanState state) {
    switch (state.status) {
      case LiveScanStatus.idle:
      case LiveScanStatus.starting:
        return null;
      case LiveScanStatus.stopped:
        return state.errorMessage;
      case LiveScanStatus.running:
        if (!state.hasSampled) return null;
        if (state.isReady) return readyBody;
        final issue = state.primaryIssue;
        if (issue == null) return readyBody;
        return _bodyFor(issue, state.snapshot.stateOf(issue));
    }
  }

  /// `2 of 3 checks ready`, for the optional compact detail.
  ///
  /// Suppressed entirely before the first measurement: "0 of 3 checks ready"
  /// while the camera is still opening states a result that has not happened.
  static String? checkSummary(LiveScanState state) {
    if (state.status != LiveScanStatus.running || !state.hasSampled) {
      return null;
    }
    final snapshot = state.snapshot;
    return '${snapshot.passingCount} of ${snapshot.checkCount} checks ready';
  }

  /// A screen-reader and row label for one check.
  static String checkLabel(LiveCheck check, LiveCheckState state) =>
      '${_name(check)}: ${_stateName(state)}';

  static String _name(LiveCheck check) => switch (check) {
    LiveCheck.lighting => 'Lighting',
    // "Sharpness", not "Focus". The measurement is an image-gradient estimate;
    // it does not read the lens's autofocus state, and naming it Focus would
    // claim a signal the app has never asked the camera for.
    LiveCheck.sharpness => 'Sharpness',
    LiveCheck.steadiness => 'Steadiness',
  };

  static String _stateName(LiveCheckState state) => switch (state) {
    // Reachable only before the first measurement, where the screen is already
    // saying it is preparing the camera.
    LiveCheckState.unknown => 'measuring…',
    LiveCheckState.checking => 'measuring…',
    LiveCheckState.pass => 'good',
    LiveCheckState.warning => 'could be better',
    LiveCheckState.fail => 'needs attention',
  };

  static String _titleFor(LiveCheck check, LiveCheckState state) =>
      switch (check) {
        LiveCheck.lighting =>
          state == LiveCheckState.fail
              ? 'Move toward better light'
              : 'A little more light would help',
        LiveCheck.steadiness => 'Hold the camera steady',
        LiveCheck.sharpness =>
          state == LiveCheckState.fail
              ? 'Image looks blurry'
              : 'Almost sharp enough',
      };

  static String? _bodyFor(LiveCheck check, LiveCheckState state) =>
      switch (check) {
        LiveCheck.lighting =>
          state == LiveCheckState.fail
              ? 'Face a window or turn on a light so your face is evenly lit.'
              : 'Your face is a little dark for an accurate shade match.',
        LiveCheck.steadiness =>
          'Rest your elbows or lean against something for a moment.',
        LiveCheck.sharpness =>
          'Give the camera a second to settle on your face.',
      };
}
