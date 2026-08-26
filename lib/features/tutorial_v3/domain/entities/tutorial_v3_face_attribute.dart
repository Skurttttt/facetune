/// The facial attributes a tutorial step is allowed to reason about.
///
/// This is a deliberate subset of [FacialAttributes]. Hair and eye color are
/// excluded because no category in the V3 relevance table applies them, and
/// flooding a step with irrelevant attributes is exactly what the
/// personalization rules forbid.
enum TutorialV3FaceAttribute {
  faceShape('face_shape'),
  skinTone('skin_tone'),
  undertone('undertone'),
  eyeShape('eye_shape'),
  lipShape('lip_shape');

  const TutorialV3FaceAttribute(this.code);

  final String code;

  static TutorialV3FaceAttribute? fromCode(String code) {
    for (final attribute in values) {
      if (attribute.code == code) return attribute;
    }
    return null;
  }
}
