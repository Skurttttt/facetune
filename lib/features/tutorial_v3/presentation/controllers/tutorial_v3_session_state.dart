import '../../domain/entities/tutorial_v3_geometry.dart';
import '../../domain/entities/tutorial_v3_session_images.dart';
import '../../domain/entities/tutorial_v3_session_snapshot.dart';
import '../../domain/entities/tutorial_v3_step.dart';

/// Where the tutorial as a whole is.
enum TutorialV3Phase {
  /// Nothing opened yet.
  idle,

  /// Resolving or creating the session.
  opening,

  /// The session exists but has no plan; one is being generated.
  planning,

  /// A plan is persisted and a step can be shown.
  ready,

  /// The tutorial itself could not be opened or planned. Distinct from a
  /// single step's geometry failing, which leaves the tutorial usable.
  failed,
}

/// Where the tutorial's two images are.
///
/// Separate from both other phases: a signed URL that could not be minted is a
/// transient, independently retryable problem, and the instruction text stays
/// readable while it is being fixed.
enum TutorialV3ImagesPhase { loading, ready, failed }

/// Where the CURRENT step's overlay is.
///
/// Separate from [TutorialV3Phase] on purpose: a step whose geometry failed
/// still shows its instruction text, its target reference and its navigation.
/// One missing overlay is not a broken tutorial.
enum TutorialV3StepGeometryPhase {
  /// The step needs no overlay. Only ever the final look.
  notRequired,

  /// Being mapped.
  loading,

  /// Ready to draw.
  ready,

  /// Mapping failed. The step is still readable; the overlay is absent.
  failed,
}

/// One immutable read of the tutorial screen's state.
class TutorialV3SessionState {
  const TutorialV3SessionState({
    this.phase = TutorialV3Phase.idle,
    this.snapshot,
    this.currentStepIndex = 0,
    this.geometryPhase = TutorialV3StepGeometryPhase.notRequired,
    this.geometry,
    this.imagesPhase = TutorialV3ImagesPhase.loading,
    this.images,
    this.message,
    this.retryable = false,
  });

  final TutorialV3Phase phase;

  /// The last loaded session, kept across a geometry failure so the screen
  /// does not empty out when one overlay could not be prepared.
  final TutorialV3SessionSnapshot? snapshot;

  /// One-based, matching `tutorial_v3_steps.step_index`. Zero before a plan
  /// exists.
  final int currentStepIndex;

  final TutorialV3StepGeometryPhase geometryPhase;

  /// The current step's overlay geometry. Null for the final look and while a
  /// mapping is in flight or has failed.
  final TutorialV3Geometry? geometry;

  final TutorialV3ImagesPhase imagesPhase;

  /// Signed URLs for the original selfie and the canonical preview.
  final TutorialV3SessionImages? images;

  /// User-facing failure text, from the server where the server produced it.
  final String? message;

  final bool retryable;

  /// The session narrowed to a readable one, or null.
  ///
  /// An incompatible session stays in [snapshot] so the screen can report it,
  /// but its steps were never decoded and must not be reached.
  TutorialV3LoadedSession? get loaded {
    final current = snapshot;
    return current is TutorialV3LoadedSession ? current : null;
  }

  List<TutorialV3Step> get steps => loaded?.steps ?? const <TutorialV3Step>[];

  /// The number of steps actually persisted, so the "STEP N OF TOTAL" label is
  /// driven by the plan rather than by a hard-coded count.
  int get totalSteps => steps.length;

  TutorialV3Step? get currentStep => loaded?.stepAt(currentStepIndex);

  bool get isFinalStep => currentStep?.isFinalLook ?? false;

  bool get canGoPrevious =>
      phase == TutorialV3Phase.ready && currentStepIndex > 1;

  bool get canGoNext =>
      phase == TutorialV3Phase.ready && currentStepIndex < totalSteps;

  /// Whether the overlay can be drawn right now.
  bool get hasOverlay =>
      geometryPhase == TutorialV3StepGeometryPhase.ready && geometry != null;

  /// Whether the selfie and the target reference can be shown.
  bool get hasImages =>
      imagesPhase == TutorialV3ImagesPhase.ready && images != null;

  /// Whether the user should be offered a retry for this step's overlay.
  bool get canRetryGeometry =>
      geometryPhase == TutorialV3StepGeometryPhase.failed && retryable;

  TutorialV3SessionState copyWith({
    TutorialV3Phase? phase,
    TutorialV3SessionSnapshot? snapshot,
    int? currentStepIndex,
    TutorialV3StepGeometryPhase? geometryPhase,
    TutorialV3Geometry? geometry,
    bool clearGeometry = false,
    TutorialV3ImagesPhase? imagesPhase,
    TutorialV3SessionImages? images,
    String? message,
    bool clearMessage = false,
    bool? retryable,
  }) => TutorialV3SessionState(
    phase: phase ?? this.phase,
    snapshot: snapshot ?? this.snapshot,
    currentStepIndex: currentStepIndex ?? this.currentStepIndex,
    geometryPhase: geometryPhase ?? this.geometryPhase,
    geometry: clearGeometry ? null : (geometry ?? this.geometry),
    imagesPhase: imagesPhase ?? this.imagesPhase,
    images: images ?? this.images,
    message: clearMessage ? null : (message ?? this.message),
    retryable: retryable ?? this.retryable,
  );
}
