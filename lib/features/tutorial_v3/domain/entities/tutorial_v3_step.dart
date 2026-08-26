import 'tutorial_v3_guideline_status.dart';
import 'tutorial_v3_step_spec.dart';

/// A persisted step: its validated Step Spec plus the runtime state of its
/// guideline image.
///
/// The two are separate on purpose. A failed generation never rewrites the
/// spec, so retrying reuses the same instruction rather than re-planning,
/// and a ready asset is reused rather than regenerated when the user
/// revisits the step.
class TutorialV3Step {
  const TutorialV3Step({
    required this.spec,
    required this.guidelineStatus,
    this.guidelineStoragePath,
    this.attemptCount = 0,
    this.lastErrorCode,
  });

  /// A step that has been planned but not yet generated.
  factory TutorialV3Step.planned(TutorialV3StepSpec spec) => TutorialV3Step(
    spec: spec,
    guidelineStatus: spec.isFinalLook
        ? TutorialV3GuidelineStatus.notRequired
        : TutorialV3GuidelineStatus.pending,
  );

  final TutorialV3StepSpec spec;
  final TutorialV3GuidelineStatus guidelineStatus;

  /// The private path of the generated guideline, set only when the status
  /// is ready. Never the original selfie and never another step's asset.
  final String? guidelineStoragePath;

  /// How many generation attempts have been made, for bounded retry.
  final int attemptCount;

  /// The last failure code, kept so a retry can be reported honestly rather
  /// than silently substituting a placeholder.
  final String? lastErrorCode;

  int get stepIndex => spec.stepIndex;

  bool get isFinalLook => spec.isFinalLook;

  /// Whether this step can be displayed with its guideline image.
  bool get hasGuideline =>
      guidelineStatus == TutorialV3GuidelineStatus.ready &&
      guidelineStoragePath != null;
}
