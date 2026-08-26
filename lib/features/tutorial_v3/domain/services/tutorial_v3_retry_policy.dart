/// How many times one step's guideline may be generated before the tutorial
/// stops asking.
///
/// Retries are bounded on purpose. A guideline that keeps failing is a real
/// failure the user should see as a failure — retrying it forever burns image
/// quota and hides the problem. A missing guideline is better than an endless
/// spinner or a confidently wrong picture.
abstract final class TutorialV3RetryPolicy {
  /// Total attempts allowed per step, including the first.
  static const maxGuidelineAttempts = 3;

  /// Whether another generation attempt may be started for a step that has
  /// already been attempted [attemptCount] times.
  static bool canAttemptAgain(int attemptCount) =>
      attemptCount < maxGuidelineAttempts;

  /// How many attempts remain for a step.
  static int attemptsRemaining(int attemptCount) {
    final remaining = maxGuidelineAttempts - attemptCount;
    return remaining < 0 ? 0 : remaining;
  }
}
