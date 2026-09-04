import '../../domain/entities/prepared_selfie.dart';

/// Where the capture-to-analysis sequence has reached.
///
/// One linear path, and every step after [capturing] is a consequence of the
/// user's single tap. Nothing here loops back to a capture on its own.
enum LiveCaptureStage {
  /// Waiting for the user. This is where Ready lives, and where the app waits
  /// indefinitely.
  idle,

  /// Taking the one still.
  capturing,

  /// Compressing and file-validating the captured still.
  preparing,

  /// Final local validation of the captured still.
  validating,

  /// Face analysis is running. The captured image stays on screen.
  analyzing,

  /// The still failed local validation, or capture failed. No paid call was
  /// made. The user can retake.
  rejected,

  /// Analysis finished. The screen hands off.
  complete,
}

class LiveCaptureState {
  const LiveCaptureState({
    this.stage = LiveCaptureStage.idle,
    this.selfie,
    this.message,
  });

  final LiveCaptureStage stage;

  /// The captured still, kept so the screen can keep showing the exact frame
  /// the user chose while the checks and the analysis run behind it.
  final PreparedSelfie? selfie;

  /// A sanitized, actionable reason the still was rejected.
  final String? message;

  /// Whether the sequence is mid-flight.
  ///
  /// The shutter's own guard. A second tap while this is true does nothing, so
  /// a double tap cannot produce two stills or two analyses.
  bool get isBusy =>
      stage == LiveCaptureStage.capturing ||
      stage == LiveCaptureStage.preparing ||
      stage == LiveCaptureStage.validating ||
      stage == LiveCaptureStage.analyzing;

  /// Whether the live preview should still be running.
  bool get showsPreview =>
      stage == LiveCaptureStage.idle || stage == LiveCaptureStage.rejected;

  /// The honest progress line. No percentages: nothing here knows a fraction.
  String? get progressLabel => switch (stage) {
    LiveCaptureStage.capturing => 'Capturing…',
    LiveCaptureStage.preparing ||
    LiveCaptureStage.validating => 'Checking photo…',
    LiveCaptureStage.analyzing => 'Analyzing your features…',
    _ => null,
  };

  LiveCaptureState copyWith({
    LiveCaptureStage? stage,
    PreparedSelfie? selfie,
    String? message,
    bool clearMessage = false,
    bool clearSelfie = false,
  }) => LiveCaptureState(
    stage: stage ?? this.stage,
    selfie: clearSelfie ? null : (selfie ?? this.selfie),
    message: clearMessage ? null : (message ?? this.message),
  );
}
