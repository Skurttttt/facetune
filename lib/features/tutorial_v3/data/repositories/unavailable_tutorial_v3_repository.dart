import '../../domain/entities/tutorial_v3_geometry.dart';
import '../../domain/entities/tutorial_v3_plan.dart';
import '../../domain/entities/tutorial_v3_session.dart';
import '../../domain/entities/tutorial_v3_session_images.dart';
import '../../domain/entities/tutorial_v3_session_snapshot.dart';
import '../../domain/errors/tutorial_v3_failure.dart';
import '../../domain/repositories/tutorial_v3_repository.dart';

const _unavailable = TutorialV3Failure(
  'Tutorials are unavailable right now. Please try again later.',
  kind: TutorialV3FailureKind.unavailable,
);

/// Stand-in used when the Supabase runtime is not configured.
///
/// Every call fails. A tutorial with no persistence has nowhere to keep its
/// plan or its geometry, and silently returning an empty session would look
/// to the screen exactly like a look that legitimately has no steps.
class UnavailableTutorialV3Repository implements TutorialV3Repository {
  const UnavailableTutorialV3Repository();

  @override
  Future<TutorialV3SessionSnapshot> openSession(TutorialV3EntryPoint entry) =>
      throw _unavailable;

  @override
  Future<TutorialV3SessionSnapshot?> findSessionById(String sessionId) =>
      throw _unavailable;

  @override
  Future<TutorialV3LoadedSession> persistPlan({
    required String sessionId,
    required TutorialV3Plan plan,
    String? plannerModel,
    String? plannerPromptVersion,
  }) => throw _unavailable;

  @override
  Future<TutorialV3LoadedSession> markPlanFailed({
    required String sessionId,
    required String error,
  }) => throw _unavailable;

  @override
  Future<TutorialV3GeometryPreparation> prepareGeometry({
    required String sessionId,
    required int stepIndex,
  }) => throw _unavailable;

  @override
  Future<TutorialV3LoadedSession> markGeometryFailed({
    required String sessionId,
    required int stepIndex,
    required String error,
  }) => throw _unavailable;

  @override
  Future<TutorialV3LoadedSession> persistGeometry({
    required String sessionId,
    required int stepIndex,
    required TutorialV3Geometry geometry,
    String? modelName,
    String? promptVersion,
  }) => throw _unavailable;

  @override
  Future<TutorialV3SessionImages> loadImages(TutorialV3Session session) =>
      throw _unavailable;

  @override
  Future<String> createSignedUrl(String storagePath) => throw _unavailable;
}
