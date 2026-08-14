import '../../domain/entities/tutorial_generation_status.dart';
import '../../domain/entities/tutorial_session.dart';
import '../../domain/errors/tutorial_failure.dart';

/// Controller-level view of a tutorial session's lifecycle.
///
/// [generating] and [partiallyComplete] are populated by translating an
/// already-persisted [TutorialSession.generationStatus] — see
/// [TutorialSessionState.statusFor]. This controller never starts
/// generation itself (see ARCHITECTURE_NOTES.md; that is a later phase's
/// responsibility, once an Edge Function exists). A loaded session found
/// sitting in an in-progress status is still a real case this state machine
/// must represent, e.g. resuming after the app was closed mid-generation.
enum TutorialSessionStatus {
  initial,
  loading,
  loaded,
  generating,
  partiallyComplete,
  failed,
}

class TutorialSessionState {
  const TutorialSessionState({
    this.status = TutorialSessionStatus.initial,
    this.session,
    this.message,
    this.retryable = false,
    this.failureType,
    this.technicalCode,
    this.generatingStepId,
    this.stepFailureStepId,
    this.stepFailureMessage,
    this.stepFailureRetryable = false,
    this.originalImageUrl,
  });

  final TutorialSessionStatus status;
  final TutorialSession? session;
  final String? message;
  final bool retryable;
  final TutorialFailureType? failureType;
  final String? technicalCode;

  /// The id of the step currently being generated via
  /// `TutorialSessionController.generateStep`, or null if none is in
  /// flight. Kept separate from [status] so the viewer can keep showing
  /// already-generated steps and Previous/Next navigation while one step
  /// generates, instead of replacing the whole page with a spinner
  /// (roadmap ST-10 tasks 4/8/9).
  final String? generatingStepId;

  /// The id of the step [stepFailureMessage] describes, or null if the most
  /// recent per-step generation attempt (if any) did not fail. Independent
  /// of [message]/[failureType], which describe a session-level (not
  /// per-step) failure.
  final String? stepFailureStepId;
  final String? stepFailureMessage;
  final bool stepFailureRetryable;

  /// Signed source-selfie URL supplied by the preview that opened the
  /// tutorial. It is used as the safe Placement source for step 1 and as
  /// a fallback for historical rows created before placement paths were
  /// persisted by the tutorial Edge Function.
  final String? originalImageUrl;

  bool get sessionExpired => failureType == TutorialFailureType.authentication;
  bool get isGeneratingStep => generatingStepId != null;

  /// Translates a loaded (possibly absent) session into the controller's
  /// status. A `null` session means "no tutorial has been generated for
  /// this look yet," which is a normal, non-error outcome of [loadExisting]
  /// — hence [TutorialSessionStatus.loaded] rather than [failed].
  static TutorialSessionStatus statusFor(TutorialSession? session) {
    if (session == null) return TutorialSessionStatus.loaded;
    switch (session.generationStatus) {
      case TutorialGenerationStatus.notStarted:
      case TutorialGenerationStatus.planning:
      case TutorialGenerationStatus.queued:
      case TutorialGenerationStatus.generating:
        return TutorialSessionStatus.generating;
      case TutorialGenerationStatus.partiallyComplete:
        return TutorialSessionStatus.partiallyComplete;
      case TutorialGenerationStatus.completed:
        return TutorialSessionStatus.loaded;
      case TutorialGenerationStatus.failed:
        return TutorialSessionStatus.failed;
    }
  }
}
