import '../entities/tutorial_category.dart';
import '../entities/tutorial_session.dart';
import '../entities/tutorial_step.dart';
import '../errors/tutorial_failure.dart';
import '../repositories/tutorial_step_repository.dart';

/// Generates one tutorial step on demand.
///
/// Guards the two conditions that would otherwise waste a paid AI call or
/// produce a step the look does not support: the category must be included by
/// the accepted manifest, and an already-ready step is returned as-is.
class GenerateTutorialStep {
  const GenerateTutorialStep(this._repository);

  final TutorialStepRepository _repository;

  Future<TutorialStep> call({
    required TutorialSession session,
    required TutorialCategory category,
  }) {
    if (!session.hasReusableManifest) {
      return Future<TutorialStep>.error(
        const TutorialFailure(
          'This tutorial is not ready yet.',
          kind: TutorialFailureKind.manifestUnavailable,
        ),
      );
    }
    if (!session.includedCategories.contains(category)) {
      return Future<TutorialStep>.error(
        const TutorialFailure(
          'This step is not part of this look.',
          kind: TutorialFailureKind.validation,
          retryable: false,
        ),
      );
    }
    final existing = session.stepFor(category);
    if (existing != null && existing.isReady) {
      return Future<TutorialStep>.value(existing);
    }
    return _repository.generate(sessionId: session.id, category: category);
  }
}
