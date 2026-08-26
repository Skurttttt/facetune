import 'tutorial_v3_guideline_base_image.dart';
import 'tutorial_v3_guideline_graphic.dart';

/// What a step's guideline image must show, expressed as instructional marks
/// on the original selfie.
///
/// [baseImage] is fixed at the type level rather than stored, so no plan can
/// declare a different source image.
class TutorialV3GuidelineVisualIntent {
  const TutorialV3GuidelineVisualIntent({
    required this.description,
    required this.graphics,
  });

  /// A plain-language description of the marks to draw — zones, directions
  /// and paths for the current category only.
  final String description;

  /// The marks this guideline is allowed to use. Constrained by
  /// [TutorialV3GuidelineGraphic], so finished makeup, retouching and
  /// typography cannot be requested.
  final Set<TutorialV3GuidelineGraphic> graphics;

  /// Always the original selfie. See [TutorialV3GuidelineBaseImage].
  TutorialV3GuidelineBaseImage get baseImage =>
      TutorialV3GuidelineBaseImage.originalSelfie;
}
