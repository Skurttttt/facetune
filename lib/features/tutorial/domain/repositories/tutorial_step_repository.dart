import '../entities/tutorial_category.dart';
import '../entities/tutorial_step.dart';

/// Generates and retrieves the rendered guideline steps of a tutorial.
abstract interface class TutorialStepRepository {
  /// Loads every persisted step of [sessionId], in deterministic order.
  ///
  /// Never performs AI work.
  Future<List<TutorialStep>> loadForSession(String sessionId);

  /// Generates the guideline image for one already-included [category].
  ///
  /// One category per call, because steps are generated on demand rather than
  /// as an upfront batch — a user who views three steps should not pay for
  /// nine.
  ///
  /// Implementations must return an existing ready step rather than
  /// regenerating it. [category] must already be included by the session's
  /// accepted manifest; this method never decides inclusion.
  Future<TutorialStep> generate({
    required String sessionId,
    required TutorialCategory category,
  });

  /// Signs the private storage path of a ready step for display.
  ///
  /// Signed URLs are minted on demand and never persisted, since they expire.
  Future<String> resolveGuidelineUrl(TutorialStep step);
}
