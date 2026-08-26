import 'tutorial_v3_category.dart';
import 'tutorial_v3_product_snapshot.dart';
import 'tutorial_v3_step_spec.dart';

/// The deterministic text bundle Flutter renders for one guideline step.
///
/// Every field is copied from the persisted Step Spec — nothing here is
/// generated, translated or inferred. Tutorial correctness therefore never
/// depends on words drawn inside an AI image, and the words on screen always
/// describe the same instruction the guideline image visualizes, because
/// both are derived from the same spec.
///
/// Presentation decides labels, ordering and formatting. This type decides
/// content.
class TutorialV3StepInstructions {
  const TutorialV3StepInstructions._({
    required this.stepIndex,
    required this.category,
    required this.product,
    required this.whereToApply,
    required this.direction,
    required this.technique,
    required this.coverage,
    required this.intensity,
    required this.amount,
    required this.toolSuggestion,
    required this.whyThisPlacement,
    required this.howThisBuildsTheLook,
    required this.tip,
    required this.avoid,
  });

  /// Derives the renderable text for [spec].
  factory TutorialV3StepInstructions.fromSpec(
    TutorialV3GuidelineStepSpec spec,
  ) => TutorialV3StepInstructions._(
    stepIndex: spec.stepIndex,
    category: spec.category,
    product: spec.productSnapshot,
    whereToApply: spec.whereToApply,
    direction: spec.direction,
    technique: spec.technique,
    coverage: spec.coverage,
    intensity: spec.intensity,
    amount: spec.amount,
    toolSuggestion: spec.toolSuggestion,
    whyThisPlacement: spec.faceRationale,
    howThisBuildsTheLook: spec.targetRationale,
    tip: spec.personalizedTip,
    avoid: spec.avoid,
  );

  final int stepIndex;
  final TutorialV3Category category;
  final TutorialV3ProductSnapshot? product;
  final String whereToApply;
  final String direction;
  final String technique;
  final String? coverage;
  final String? intensity;
  final String? amount;
  final String? toolSuggestion;
  final String whyThisPlacement;
  final String howThisBuildsTheLook;
  final String? tip;
  final String? avoid;
}
