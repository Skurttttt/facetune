/// The makeup product categories a tutorial step can teach.
///
/// [code] is the stable identifier used across persistence and AI payload
/// boundaries, following the same convention as `MakeupKitCategory.code`.
/// UI display labels must never be used as the identity contract for a
/// category.
///
/// This is a canonical vocabulary, not a re-export of either source's raw
/// category strings. The two tutorial sources disagree on category spelling
/// today:
/// - standard recommendation items key on camelCase strings such as
///   `highlight`, `contour`, `lipGloss`
///   (`makeup_recommendation_dto.dart`);
/// - My Makeup Kit selections key on `MakeupKitCategory.code`, which uses
///   `highlighter`, `contour_bronzer`, `lip_gloss`.
///
/// The phase that builds the tutorial planning engine must map both
/// vocabularies onto [TutorialStepCategory] explicitly; do not assume the
/// strings are interchangeable.
enum TutorialStepCategory {
  foundation('foundation'),
  concealer('concealer'),
  contour('contour'),
  highlighter('highlighter'),
  blush('blush'),
  eyeshadow('eyeshadow'),
  eyebrow('eyebrow'),
  eyeliner('eyeliner'),
  lipstick('lipstick'),
  lipGloss('lip_gloss'),

  /// The optional cumulative final step described in
  /// FACETUNE_STEP_BY_STEP_TUTORIAL_GUIDE.md §4.2, which may reuse the
  /// existing final preview instead of a new tutorial-model generation.
  finalLook('final_look');

  const TutorialStepCategory(this.code);

  final String code;

  static TutorialStepCategory? fromCode(String code) {
    for (final category in values) {
      if (category.code == code) return category;
    }
    return null;
  }
}
