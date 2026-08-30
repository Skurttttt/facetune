/// The controlled tutorial step vocabulary.
///
/// This is the complete set of categories the tutorial system understands. It
/// is deliberately smaller than the My Makeup Kit inventory vocabulary: several
/// inventory categories collapse into one tutorial step (Lipstick and Lip Gloss
/// both become [lips]). See `TutorialCategoryMapping`.
///
/// Two separate concerns must never be conflated:
///
/// * **Inclusion** — which categories appear in one specific tutorial. This is
///   dynamic, decided per look by visual comparison of the original selfie
///   against the canonical final preview.
/// * **Order** — the sequence included categories are presented in. This is
///   deterministic, fixed by [order] below, and never chosen by the AI.
///
/// All nine categories are supported; none is mandatory. A tutorial with three
/// steps is as valid as one with nine, and nothing in this type assumes
/// otherwise.
///
/// The AI can never introduce a category name. [fromCode] rejects anything
/// outside this enum, so a model that invents "Radiance Layer" or
/// "Cheek Sculpting Enhancement" fails validation rather than creating a step.
enum TutorialCategory {
  foundation('foundation', 1),
  concealer('concealer', 2),
  contourBronzer('contour_bronzer', 3),
  blush('blush', 4),
  highlighter('highlighter', 5),
  eyebrows('eyebrows', 6),
  eyeshadow('eyeshadow', 7),
  eyeliner('eyeliner', 8),
  lips('lips', 9);

  const TutorialCategory(this.code, this.order);

  /// The stable wire/persistence identifier.
  final String code;

  /// Position in the deterministic logical application order.
  ///
  /// This is the *absolute* rank within the full vocabulary, not the index
  /// within any particular tutorial. Two tutorials that both include
  /// [eyeliner] give it the same [order] even when one has three steps and the
  /// other has nine. Presentation positions are derived by
  /// [orderedSubset], which preserves relative order after filtering.
  final int order;

  /// Returns the category for [code], or `null` when [code] is outside the
  /// controlled vocabulary.
  static TutorialCategory? fromCode(String code) {
    for (final category in values) {
      if (category.code == code) return category;
    }
    return null;
  }

  /// The full vocabulary in deterministic logical order.
  static List<TutorialCategory> get orderedVocabulary =>
      List<TutorialCategory>.unmodifiable(
        values.toList()..sort((a, b) => a.order.compareTo(b.order)),
      );

  /// Sorts [categories] into the deterministic logical order, dropping
  /// duplicates.
  ///
  /// Order is entirely independent of inclusion: the result depends only on
  /// [order], never on the iteration order of the input. Removing Contour and
  /// Highlighter from a full set therefore leaves the remaining categories in
  /// exactly their original relative sequence.
  static List<TutorialCategory> orderedSubset(
    Iterable<TutorialCategory> categories,
  ) {
    final unique = categories.toSet().toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return List<TutorialCategory>.unmodifiable(unique);
  }
}
