import 'tutorial_v3_category.dart';
import 'tutorial_v3_guideline_base_image.dart';
import 'tutorial_v3_guideline_visual_intent.dart';
import 'tutorial_v3_product_snapshot.dart';
import 'tutorial_v3_scoped_face_attributes.dart';
import 'tutorial_v3_source_mode.dart';
import 'tutorial_v3_target_reference_mode.dart';
import '../value_objects/tutorial_v3_plan_version.dart';

/// One validated step of a persisted tutorial plan.
///
/// A Step Spec is the single source of truth for that step: the text Flutter
/// renders and the intent a guideline image visualizes are both derived from
/// it, so they cannot disagree. Individual generation calls never invent a
/// different placement, direction, intensity, product, technique or
/// rationale.
///
/// The hierarchy is sealed and has exactly two variants. A step either
/// teaches an application ([TutorialV3GuidelineStepSpec]) or is the final
/// look ([TutorialV3FinalLookStepSpec]). There is no third variant, so an
/// intermediate makeup "result" step cannot be constructed, persisted or
/// switched on.
sealed class TutorialV3StepSpec {
  const TutorialV3StepSpec({
    required this.stepIndex,
    required this.sourceMode,
    required this.selectedStyleCode,
    required this.planVersion,
    required this.targetReferenceMode,
  });

  /// 1-based position in the plan.
  final int stepIndex;

  final TutorialV3SourceMode sourceMode;

  /// The persisted `makeup_style` code of the recommendation this tutorial
  /// belongs to. Never re-derived from client UI state.
  final String selectedStyleCode;

  final TutorialV3PlanVersion planVersion;

  /// How the canonical premium final preview is shown next to this step.
  final TutorialV3TargetReferenceMode targetReferenceMode;

  /// The category this step teaches.
  TutorialV3Category get category;

  /// Whether this is the terminal step. Derived from [category] rather than
  /// stored, so the flag can never contradict the category.
  bool get isFinalLook => category.isFinalLook;
}

/// A step that teaches how to apply one category.
final class TutorialV3GuidelineStepSpec extends TutorialV3StepSpec {
  const TutorialV3GuidelineStepSpec({
    required super.stepIndex,
    required this.category,
    required super.sourceMode,
    required super.selectedStyleCode,
    required super.planVersion,
    super.targetReferenceMode =
        TutorialV3TargetReferenceMode.fullCanonicalPreview,
    this.productSnapshot,
    this.coverage,
    this.intensity,
    required this.whereToApply,
    required this.direction,
    required this.technique,
    this.amount,
    this.toolSuggestion,
    this.personalizedTip,
    this.avoid,
    required this.relevantFaceAttributes,
    required this.faceRationale,
    required this.targetRationale,
    required this.targetLookCues,
    required this.guidelineVisualIntent,
  }) : assert(
         category != TutorialV3Category.finalLook,
         'The final look is not a guideline step.',
       );

  @override
  final TutorialV3Category category;

  /// The product this step teaches, if the category has one.
  final TutorialV3ProductSnapshot? productSnapshot;

  final String? coverage;
  final String? intensity;

  final String whereToApply;
  final String direction;
  final String technique;

  final String? amount;
  final String? toolSuggestion;
  final String? personalizedTip;
  final String? avoid;

  /// Only the attributes this category may reason about.
  final TutorialV3ScopedFaceAttributes relevantFaceAttributes;

  /// Why this placement suits this face.
  final String faceRationale;

  /// How this step contributes to the exact selected final look.
  final String targetRationale;

  /// Observable cues in the canonical final preview this step produces.
  final List<String> targetLookCues;

  final TutorialV3GuidelineVisualIntent guidelineVisualIntent;

  /// Always the original selfie — never a previously generated guideline.
  TutorialV3GuidelineBaseImage get baseImage =>
      TutorialV3GuidelineBaseImage.originalSelfie;
}

/// The terminal step, which reuses the existing canonical premium final
/// preview.
///
/// It carries no guideline visual intent, no product and no application
/// instruction, because nothing is generated for it. That absence is
/// structural: there is no field on this class through which a new final
/// image could be requested, and [category] is a constant getter rather than
/// a constructor parameter, so a final-look step can never be built with a
/// different category.
final class TutorialV3FinalLookStepSpec extends TutorialV3StepSpec {
  const TutorialV3FinalLookStepSpec({
    required super.stepIndex,
    required super.sourceMode,
    required super.selectedStyleCode,
    required super.planVersion,
    super.targetReferenceMode =
        TutorialV3TargetReferenceMode.fullCanonicalPreview,
    required this.targetRationale,
  });

  @override
  TutorialV3Category get category => TutorialV3Category.finalLook;

  /// A closing summary of what the completed look achieves.
  final String targetRationale;
}
