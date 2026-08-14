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
  });

  final TutorialSessionStatus status;
  final TutorialSession? session;
  final String? message;
  final bool retryable;
  final TutorialFailureType? failureType;
  final String? technicalCode;

  bool get sessionExpired => failureType == TutorialFailureType.authentication;

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
