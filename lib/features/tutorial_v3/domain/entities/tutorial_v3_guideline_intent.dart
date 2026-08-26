import 'tutorial_v3_category.dart';
import 'tutorial_v3_guideline_base_image.dart';
import 'tutorial_v3_guideline_graphic.dart';
import 'tutorial_v3_scoped_face_attributes.dart';
import 'tutorial_v3_step_spec.dart';
import 'tutorial_v3_target_reference_mode.dart';

/// Everything a guideline generation call is allowed to know.
///
/// The constructor is private and [TutorialV3GuidelineIntent.fromSpec] is the
/// only way to build one, so a generation call cannot be handed free-form
/// instructions: whatever it draws must come from the persisted Step Spec.
/// The derivation is pure, so two calls for the same spec always produce the
/// same intent.
///
/// The intent carries the current step's category only. It has no field for
/// a previous step, a previous guideline, or any other step's instruction,
/// so a cumulative chain cannot be expressed.
class TutorialV3GuidelineIntent {
  const TutorialV3GuidelineIntent._({
    required this.category,
    required this.selectedStyleCode,
    required this.whereToApply,
    required this.direction,
    required this.technique,
    required this.coverage,
    required this.intensity,
    required this.visualDescription,
    required this.graphics,
    required this.faceAttributes,
    required this.targetReferenceMode,
  });

  /// Derives the intent for [spec].
  factory TutorialV3GuidelineIntent.fromSpec(
    TutorialV3GuidelineStepSpec spec,
  ) => TutorialV3GuidelineIntent._(
    category: spec.category,
    selectedStyleCode: spec.selectedStyleCode,
    whereToApply: spec.whereToApply,
    direction: spec.direction,
    technique: spec.technique,
    coverage: spec.coverage,
    intensity: spec.intensity,
    visualDescription: spec.guidelineVisualIntent.description,
    graphics: spec.guidelineVisualIntent.graphics,
    faceAttributes: spec.relevantFaceAttributes,
    targetReferenceMode: spec.targetReferenceMode,
  );

  final TutorialV3Category category;
  final String selectedStyleCode;
  final String whereToApply;
  final String direction;
  final String technique;
  final String? coverage;
  final String? intensity;
  final String visualDescription;
  final Set<TutorialV3GuidelineGraphic> graphics;
  final TutorialV3ScopedFaceAttributes faceAttributes;
  final TutorialV3TargetReferenceMode targetReferenceMode;

  /// Always the original selfie. See [TutorialV3GuidelineBaseImage].
  TutorialV3GuidelineBaseImage get baseImage =>
      TutorialV3GuidelineBaseImage.originalSelfie;

  @override
  bool operator ==(Object other) =>
      other is TutorialV3GuidelineIntent &&
      other.category == category &&
      other.selectedStyleCode == selectedStyleCode &&
      other.whereToApply == whereToApply &&
      other.direction == direction &&
      other.technique == technique &&
      other.coverage == coverage &&
      other.intensity == intensity &&
      other.visualDescription == visualDescription &&
      other.targetReferenceMode == targetReferenceMode &&
      other.graphics.length == graphics.length &&
      other.graphics.containsAll(graphics);

  @override
  int get hashCode => Object.hash(
    category,
    selectedStyleCode,
    whereToApply,
    direction,
    technique,
    coverage,
    intensity,
    visualDescription,
    targetReferenceMode,
    graphics.length,
  );
}
