import 'tutorial_instruction.dart';
import 'personalized_tutorial.dart';
import 'tutorial_placement_metadata.dart';
import 'tutorial_step_category.dart';

/// One step of a not-yet-persisted [TutorialPlan], produced by
/// `TutorialPlanningEngine`.
///
/// Deliberately distinct from `TutorialStep` (domain/entities/tutorial_step.dart):
/// that type represents a *persisted* row with an id, generation status,
/// and timestamps. This type is pure planning output — the phase that
/// turns a plan into persisted rows (`TutorialRepository.createStep`, see
/// ST-8) is expected to read one `PlannedTutorialStep` per call.
class PlannedTutorialStep {
  const PlannedTutorialStep({
    required this.stepNumber,
    required this.category,
    required this.title,
    required this.instruction,
    this.placementMetadata,
    this.personalizedSpec,
    this.reusableResultImagePath,
    this.reusableResultImageUrl,
    this.reusableModelId,
    this.reusablePromptVersion,
  });

  final int stepNumber;
  final TutorialStepCategory category;
  final String title;
  final TutorialInstruction instruction;
  final TutorialPlacementMetadata? placementMetadata;
  final PersonalizedTutorialStepSpec? personalizedSpec;

  /// Set only when this step's result can reuse an already-generated image
  /// instead of a new Gemini call — currently only the final cumulative
  /// step, reusing the existing final preview (guide §4.2). `null` means a
  /// later phase must generate this step's result image.
  final String? reusableResultImagePath;
  final String? reusableResultImageUrl;

  /// The model/prompt version that actually produced [reusableResultImagePath]
  /// — echoed from the source preview itself, not invented. `null` whenever
  /// [reusableResultImagePath] is `null`.
  final String? reusableModelId;
  final String? reusablePromptVersion;
}

/// The output of `TutorialPlanningEngine`: an ordered, dynamically-sized
/// list of steps derived from one source look.
class TutorialPlan {
  const TutorialPlan({required this.steps, required this.reusesFinalPreview});

  final List<PlannedTutorialStep> steps;

  /// Whether the last step in [steps] reuses the source's existing final
  /// preview rather than needing a new generation. `false` for a plan with
  /// no steps at all (nothing to show a "final look" of).
  final bool reusesFinalPreview;

  int get totalSteps => steps.length;
}
