import '../../domain/entities/canonical_preview_ref.dart';
import '../../domain/entities/tutorial_category.dart';
import '../../domain/entities/tutorial_step.dart';
import '../../domain/entities/tutorial_session.dart';
import '../../domain/entities/validated_look_plan.dart';
import '../../domain/errors/tutorial_failure.dart';
import '../../domain/repositories/look_plan_repository.dart';
import '../../domain/repositories/tutorial_manifest_repository.dart';
import '../../domain/repositories/tutorial_session_repository.dart';
import '../../domain/repositories/tutorial_step_repository.dart';

/// Used when Supabase is not configured, matching the `unavailable_*` fallback
/// every other FaceTune feature ships. Failing with a clear, non-retryable
/// message beats a null-object that silently produces an empty tutorial.
const _unavailable = TutorialFailure(
  'Tutorials are unavailable right now.',
  kind: TutorialFailureKind.unavailable,
  retryable: false,
);

class UnavailableLookPlanRepository implements LookPlanRepository {
  const UnavailableLookPlanRepository();

  @override
  Future<ValidatedLookPlan> loadForCanonicalPreview(
    CanonicalPreviewRef preview,
  ) async => throw _unavailable;
}

class UnavailableTutorialManifestRepository
    implements TutorialManifestRepository {
  const UnavailableTutorialManifestRepository();

  @override
  Future<TutorialSession?> loadAccepted(CanonicalPreviewRef preview) async =>
      throw _unavailable;

  @override
  Future<TutorialSession> analyze(CanonicalPreviewRef preview) async =>
      throw _unavailable;
}

class UnavailableTutorialSessionRepository
    implements TutorialSessionRepository {
  const UnavailableTutorialSessionRepository();

  @override
  Future<TutorialSession?> loadForCanonicalPreview(
    CanonicalPreviewRef preview,
  ) async => throw _unavailable;

  @override
  Future<TutorialSession> loadById(String sessionId) async =>
      throw _unavailable;

  @override
  Future<TutorialSession> ensureSteps(TutorialSession session) async =>
      throw _unavailable;

  @override
  Future<void> delete(String sessionId) async => throw _unavailable;
}

class UnavailableTutorialStepRepository implements TutorialStepRepository {
  const UnavailableTutorialStepRepository();

  @override
  Future<List<TutorialStep>> loadForSession(String sessionId) async =>
      throw _unavailable;

  @override
  Future<TutorialStep> generate({
    required String sessionId,
    required TutorialCategory category,
  }) async => throw _unavailable;

  @override
  Future<String> resolveGuidelineUrl(TutorialStep step) async =>
      throw _unavailable;
}
