import '../entities/tutorial_v3_category.dart';
import '../entities/tutorial_v3_face_attribute.dart';

/// The authoritative catalog of category ordering and per-category facial
/// attribute relevance.
///
/// This is the single source of truth for both rules. The planner must not
/// re-derive either, and no individual guideline call may reorder steps or
/// widen an attribute scope.
abstract final class TutorialV3CategoryCatalog {
  /// The only order in which categories may appear in a plan.
  ///
  /// A plan omits categories freely — the step count is dynamic — but the
  /// categories it does include must appear in this relative order. The
  /// order encodes the three fixed sequencing rules: Foundation first when
  /// present, Lip Gloss after lip color when both exist, and Final Look
  /// always last.
  static const List<TutorialV3Category> canonicalOrder = <TutorialV3Category>[
    TutorialV3Category.foundation,
    TutorialV3Category.concealer,
    TutorialV3Category.contourBronzer,
    TutorialV3Category.blush,
    TutorialV3Category.highlighter,
    TutorialV3Category.eyebrow,
    TutorialV3Category.eyeshadow,
    TutorialV3Category.eyeliner,
    TutorialV3Category.lipstick,
    TutorialV3Category.lipGloss,
    TutorialV3Category.finalLook,
  ];

  /// The facial attributes that may inform each category's instruction.
  ///
  /// The selected look is not listed: it applies to every category and is
  /// carried as its own Step Spec field rather than as a facial attribute.
  static const Map<TutorialV3Category, Set<TutorialV3FaceAttribute>>
  _relevantAttributes = <TutorialV3Category, Set<TutorialV3FaceAttribute>>{
    TutorialV3Category.foundation: {
      TutorialV3FaceAttribute.skinTone,
      TutorialV3FaceAttribute.undertone,
    },
    TutorialV3Category.concealer: {
      TutorialV3FaceAttribute.eyeShape,
      TutorialV3FaceAttribute.skinTone,
    },
    TutorialV3Category.contourBronzer: {TutorialV3FaceAttribute.faceShape},
    TutorialV3Category.blush: {TutorialV3FaceAttribute.faceShape},
    TutorialV3Category.highlighter: {TutorialV3FaceAttribute.faceShape},
    TutorialV3Category.eyebrow: {TutorialV3FaceAttribute.faceShape},
    TutorialV3Category.eyeshadow: {TutorialV3FaceAttribute.eyeShape},
    TutorialV3Category.eyeliner: {TutorialV3FaceAttribute.eyeShape},
    TutorialV3Category.lipstick: {TutorialV3FaceAttribute.lipShape},
    TutorialV3Category.lipGloss: {TutorialV3FaceAttribute.lipShape},
    TutorialV3Category.finalLook: <TutorialV3FaceAttribute>{},
  };

  /// The attributes [category] may reason about.
  static Set<TutorialV3FaceAttribute> relevantAttributes(
    TutorialV3Category category,
  ) =>
      _relevantAttributes[category] ?? const <TutorialV3FaceAttribute>{};

  /// Whether [attribute] is in scope for [category].
  static bool isRelevant(
    TutorialV3Category category,
    TutorialV3FaceAttribute attribute,
  ) => relevantAttributes(category).contains(attribute);

  /// The position of [category] in [canonicalOrder].
  static int orderRank(TutorialV3Category category) =>
      canonicalOrder.indexOf(category);
}
