import '../../domain/entities/live_check.dart';
import '../../domain/entities/live_validation_snapshot.dart';

/// Where the live session is in its lifecycle.
enum LiveScanStatus {
  /// No session. Nothing is being delivered or analysed.
  idle,

  /// Starting the frame source.
  starting,

  /// Frames are arriving and being analysed.
  running,

  /// The source stopped or could not start.
  stopped,
}

/// Everything the live camera surface renders, owned in one place.
///
/// Deliberately one object rather than several providers. The snapshot, the
/// guidance line, and the shutter's eligibility all have to describe the same
/// frame — split across separate notifiers they would update independently, and
/// the screen would show a Ready message beside a blocked shutter.
class LiveScanState {
  LiveScanState({
    this.status = LiveScanStatus.idle,
    LiveValidationSnapshot? snapshot,
    this.isAnalyzing = false,
    this.analyzedFrames = 0,
    this.hasSampled = false,
    this.errorMessage,
  }) : snapshot = snapshot ?? LiveValidationSnapshot.unknown();

  final LiveScanStatus status;

  /// The most recent completed evaluation.
  final LiveValidationSnapshot snapshot;

  /// Whether an analysis is in flight right now.
  final bool isAnalyzing;

  /// How many frames have been analysed this session.
  final int analyzedFrames;

  /// Whether at least one frame has been analysed this session.
  ///
  /// The difference between "we have not looked yet" and "we looked and cannot
  /// tell", which the UI must never conflate. Before the first analysis the
  /// screen says it is preparing the camera; after it, every check reports a
  /// measured state. LSEP-4A: without this distinction the checklist showed
  /// "not checked yet" indefinitely, which read as a broken feature rather than
  /// as a camera still warming up.
  final bool hasSampled;

  /// A sanitized, user-facing reason the session is not running.
  final String? errorMessage;

  /// The single check worth acting on, or null when nothing needs attention.
  LiveCheck? get primaryIssue => snapshot.primaryIssue;

  /// What the frames imply about the shutter.
  ///
  /// A session that is not running is never eligible: eligibility describes
  /// measured frames, and there are none.
  LiveCaptureEligibility get eligibility => status == LiveScanStatus.running
      ? snapshot.eligibility
      : LiveCaptureEligibility.blocked;

  /// True only when the session is running and every check has passed.
  bool get isReady => status == LiveScanStatus.running && snapshot.isReady;

  LiveScanState copyWith({
    LiveScanStatus? status,
    LiveValidationSnapshot? snapshot,
    bool? isAnalyzing,
    int? analyzedFrames,
    bool? hasSampled,
    String? errorMessage,
    bool clearError = false,
  }) => LiveScanState(
    status: status ?? this.status,
    snapshot: snapshot ?? this.snapshot,
    isAnalyzing: isAnalyzing ?? this.isAnalyzing,
    analyzedFrames: analyzedFrames ?? this.analyzedFrames,
    hasSampled: hasSampled ?? this.hasSampled,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}
