import '../../../makeup_kit/domain/entities/makeup_kit_category.dart';

/// The categories a V3 tutorial step can teach.
///
/// [code] is the stable identifier used across persistence and AI payload
/// boundaries. UI display labels must never be used as the identity contract
/// for a category.
///
/// The ten makeup categories deliberately reuse the exact `code` values of
/// [MakeupKitCategory] so a Kit-sourced tutorial never has to translate
/// vocabularies. [finalLook] is the one V3-only member: it is not a product
/// category and has no Kit counterpart, because the final step reuses the
/// existing canonical premium preview rather than teaching an application.
///
/// There is deliberately no per-category "result" member. V3 generates no
/// intermediate makeup appearance, so a "foundation result" step is not
/// representable in this domain.
enum TutorialV3Category {
  foundation('foundation', MakeupKitCategory.foundation),
  concealer('concealer', MakeupKitCategory.concealer),
  contourBronzer('contour_bronzer', MakeupKitCategory.contourBronzer),
  blush('blush', MakeupKitCategory.blush),
  highlighter('highlighter', MakeupKitCategory.highlighter),
  eyebrow('eyebrow', MakeupKitCategory.eyebrow),
  eyeshadow('eyeshadow', MakeupKitCategory.eyeshadow),
  eyeliner('eyeliner', MakeupKitCategory.eyeliner),
  lipstick('lipstick', MakeupKitCategory.lipstick),
  lipGloss('lip_gloss', MakeupKitCategory.lipGloss),
  finalLook('final_look', null);

  const TutorialV3Category(this.code, this.kitCategory);

  final String code;

  /// The My Makeup Kit category this tutorial category maps onto, or `null`
  /// for [finalLook], which is not a product category.
  final MakeupKitCategory? kitCategory;

  bool get isFinalLook => this == TutorialV3Category.finalLook;

  /// The categories that teach an application step, i.e. everything except
  /// [finalLook].
  static Iterable<TutorialV3Category> get guidelineCategories =>
      values.where((category) => !category.isFinalLook);

  static TutorialV3Category? fromCode(String code) {
    for (final category in values) {
      if (category.code == code) return category;
    }
    return null;
  }

  static TutorialV3Category? fromKitCategory(MakeupKitCategory kitCategory) {
    for (final category in values) {
      if (category.kitCategory == kitCategory) return category;
    }
    return null;
  }
}
