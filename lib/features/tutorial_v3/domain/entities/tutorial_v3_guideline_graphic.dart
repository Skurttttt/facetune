/// The complete set of instructional marks a guideline image may add.
///
/// Guideline images teach placement only. This allow-list is exhaustive by
/// design: finished makeup appearance, beautification, retouching and
/// intentional facial alteration are not members, so a Step Spec has no way
/// to ask for them.
///
/// Typography is deliberately absent. Critical text is rendered by Flutter
/// from the Step Spec, and tutorial correctness must never depend on words
/// drawn inside a generated image.
enum TutorialV3GuidelineGraphic {
  translucentZone('translucent_zone'),
  arrow('arrow'),
  path('path'),
  softBand('soft_band'),
  marker('marker');

  const TutorialV3GuidelineGraphic(this.code);

  final String code;

  static TutorialV3GuidelineGraphic? fromCode(String code) {
    for (final graphic in values) {
      if (graphic.code == code) return graphic;
    }
    return null;
  }
}
