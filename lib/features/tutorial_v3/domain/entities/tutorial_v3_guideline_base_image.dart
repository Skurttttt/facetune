/// The only image a V3 guideline may be generated from.
///
/// This enum intentionally has exactly one value. V3's central rule is that
/// every non-final step is generated independently from the ORIGINAL SELFIE,
/// and a generated guideline must never become the source image for the next
/// step. Modelling the base image as a single-valued type makes that drift
/// unrepresentable rather than merely discouraged: there is no
/// `previousGuideline` member to pass, so no later phase can introduce a
/// guideline-to-guideline chain without changing this file.
enum TutorialV3GuidelineBaseImage {
  originalSelfie('original_selfie');

  const TutorialV3GuidelineBaseImage(this.code);

  final String code;
}
