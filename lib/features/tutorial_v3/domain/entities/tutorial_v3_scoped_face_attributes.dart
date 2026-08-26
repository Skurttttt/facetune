import '../../../analysis/domain/entities/facial_attributes.dart';
import '../catalog/tutorial_v3_category_catalog.dart';
import 'tutorial_v3_category.dart';
import 'tutorial_v3_face_attribute.dart';

/// The facial attributes carried by one step, already narrowed to those the
/// step's category is allowed to reason about.
///
/// Every field is nullable because scoping removes what is irrelevant: a
/// blush step carries a face shape and nothing else. Build instances with
/// [TutorialV3ScopedFaceAttributes.scope] rather than by hand so the scope
/// always matches the catalog.
class TutorialV3ScopedFaceAttributes {
  const TutorialV3ScopedFaceAttributes({
    this.faceShape,
    this.skinTone,
    this.undertone,
    this.eyeShape,
    this.lipShape,
  });

  /// Narrows [attributes] to exactly the attributes [category] may use.
  factory TutorialV3ScopedFaceAttributes.scope(
    FacialAttributes attributes,
    TutorialV3Category category,
  ) {
    final relevant = TutorialV3CategoryCatalog.relevantAttributes(category);
    return TutorialV3ScopedFaceAttributes(
      faceShape: relevant.contains(TutorialV3FaceAttribute.faceShape)
          ? attributes.faceShape
          : null,
      skinTone: relevant.contains(TutorialV3FaceAttribute.skinTone)
          ? attributes.skinTone
          : null,
      undertone: relevant.contains(TutorialV3FaceAttribute.undertone)
          ? attributes.undertone
          : null,
      eyeShape: relevant.contains(TutorialV3FaceAttribute.eyeShape)
          ? attributes.eyeShape
          : null,
      lipShape: relevant.contains(TutorialV3FaceAttribute.lipShape)
          ? attributes.lipShape
          : null,
    );
  }

  final FaceShape? faceShape;
  final SkinTone? skinTone;
  final Undertone? undertone;
  final EyeShape? eyeShape;
  final LipShape? lipShape;

  /// The attribute keys actually present, regardless of value.
  Set<TutorialV3FaceAttribute> get presentAttributes =>
      <TutorialV3FaceAttribute>{
        if (faceShape != null) TutorialV3FaceAttribute.faceShape,
        if (skinTone != null) TutorialV3FaceAttribute.skinTone,
        if (undertone != null) TutorialV3FaceAttribute.undertone,
        if (eyeShape != null) TutorialV3FaceAttribute.eyeShape,
        if (lipShape != null) TutorialV3FaceAttribute.lipShape,
      };

  bool get isEmpty => presentAttributes.isEmpty;

  bool get isNotEmpty => !isEmpty;
}
