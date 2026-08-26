import 'tutorial_v3_category.dart';
import 'tutorial_v3_source_mode.dart';
import 'tutorial_v3_step_spec.dart';
import '../value_objects/tutorial_v3_plan_version.dart';

/// One complete tutorial, produced by a single planning call and persisted
/// before any guideline generation begins.
///
/// The step count is dynamic: a Natural look may need few steps and a Full
/// Glam look many. Nothing here pads a plan to a fixed length, and
/// [totalSteps] is always the real persisted length rather than a separately
/// stored number that could drift.
class TutorialV3Plan {
  const TutorialV3Plan({
    required this.planVersion,
    required this.sourceMode,
    required this.selectedStyleCode,
    required this.steps,
  });

  final TutorialV3PlanVersion planVersion;
  final TutorialV3SourceMode sourceMode;

  /// The persisted `makeup_style` code every step must agree with.
  final String selectedStyleCode;

  /// The plan's steps in presentation order. The last is always the final
  /// look; a validated plan guarantees it.
  final List<TutorialV3StepSpec> steps;

  int get totalSteps => steps.length;

  /// The steps that require a generated guideline image.
  Iterable<TutorialV3GuidelineStepSpec> get guidelineSteps =>
      steps.whereType<TutorialV3GuidelineStepSpec>();

  /// The categories this plan teaches, in order, excluding the final look.
  List<TutorialV3Category> get taughtCategories =>
      guidelineSteps.map((step) => step.category).toList(growable: false);

  /// The terminal step, or `null` if this plan has not been validated and
  /// does not end with one.
  TutorialV3FinalLookStepSpec? get finalStep {
    if (steps.isEmpty) return null;
    final last = steps.last;
    return last is TutorialV3FinalLookStepSpec ? last : null;
  }
}
