/// Resolves which already-stored image a step's Placement side should
/// reuse, per the V1 cost strategy
/// (FACETUNE_STEP_BY_STEP_TUTORIAL_GUIDE.md §4.1, roadmap ST-6 task 8):
///
/// - Step 1's Placement reuses the original selfie.
/// - Step N's Placement (N > 1) reuses Step N-1's Result.
///
/// This is a pure placement-*source* rule — it returns a storage path, not
/// an image. It does not fetch, upload, or generate anything, and nothing
/// in this phase calls it yet: a future planning/generation phase is
/// expected to call this when persisting each step's
/// `placement_image_path` (see `TutorialRepository.createStep`).
abstract final class TutorialPlacementSourceResolver {
  /// Returns the storage path Step [stepNumber]'s placement image should
  /// reuse.
  ///
  /// Throws [ArgumentError] if [stepNumber] is less than 1, or if
  /// [stepNumber] is greater than 1 and [previousStepResultPath] is null
  /// (Step N-1 must have a result image before Step N's placement can be
  /// resolved).
  static String resolve({
    required int stepNumber,
    required String originalImagePath,
    String? previousStepResultPath,
  }) {
    if (stepNumber < 1) {
      throw ArgumentError.value(
        stepNumber,
        'stepNumber',
        'must be 1 or greater',
      );
    }
    if (stepNumber == 1) return originalImagePath;
    if (previousStepResultPath == null) {
      throw ArgumentError(
        'Step $stepNumber needs step ${stepNumber - 1}\'s result image '
        'path before its placement image can be resolved.',
      );
    }
    return previousStepResultPath;
  }
}
