import 'tutorial_v2_category.dart';

/// Where one step sits in the tutorial's cumulative category progression.
///
/// All three sets are explicit rather than derived at the call site, because
/// every AI prompt needs a different one of them (Source of Truth §15):
///
/// * [previouslyCompletedCategories] — must already be visible and must be
///   preserved unchanged.
/// * [currentCategory] — the only category this step is allowed to change.
/// * [futureCategories] — planned but not yet reached; must NOT appear early.
///
/// [cumulativeCategories] is what the result after this step should depict:
/// everything completed through this step, and nothing beyond it.
class TutorialV2CumulativeCategoryState {
  TutorialV2CumulativeCategoryState({
    required List<TutorialV2Category> previouslyCompletedCategories,
    required this.currentCategory,
    required List<TutorialV2Category> futureCategories,
  }) : previouslyCompletedCategories = List.unmodifiable(
         previouslyCompletedCategories,
       ),
       futureCategories = List.unmodifiable(futureCategories);

  final List<TutorialV2Category> previouslyCompletedCategories;
  final TutorialV2Category currentCategory;
  final List<TutorialV2Category> futureCategories;

  /// Everything that should be visible after this step completes.
  List<TutorialV2Category> get cumulativeCategories => List.unmodifiable([
    ...previouslyCompletedCategories,
    currentCategory,
  ]);

  /// Whether this is the first step, whose base state is the original selfie
  /// rather than a previous cumulative result.
  bool get isFirstStep => previouslyCompletedCategories.isEmpty;
}
