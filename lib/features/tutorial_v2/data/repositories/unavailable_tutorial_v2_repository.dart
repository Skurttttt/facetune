import '../../domain/entities/tutorial_v2_generation_status.dart';
import '../../domain/entities/tutorial_v2_plan.dart';
import '../../domain/entities/tutorial_v2_plan_context.dart';
import '../../domain/entities/tutorial_v2_session_snapshot.dart';
import '../../domain/errors/tutorial_v2_failure.dart';
import '../../domain/repositories/tutorial_v2_repository.dart';

/// Used when Supabase failed to initialize, so the tutorial surfaces a clear
/// unavailable state instead of a null-client crash.
class UnavailableTutorialV2Repository implements TutorialV2Repository {
  const UnavailableTutorialV2Repository();

  static const _failure = TutorialV2Failure(
    'Tutorials are unavailable right now. Try again later.',
    kind: TutorialV2FailureKind.unavailable,
  );

  @override
  Future<TutorialV2SessionSnapshot> getOrCreateSession({
    required String analysisId,
    required TutorialV2PlanContext context,
  }) async => throw _failure;

  @override
  Future<TutorialV2SessionSnapshot?> findSessionById(String sessionId) async =>
      throw _failure;

  @override
  Future<TutorialV2SessionSnapshot> persistPlan({
    required String sessionId,
    required TutorialV2Plan plan,
    String? plannerModel,
    String? plannerPromptVersion,
  }) async => throw _failure;

  @override
  Future<TutorialV2SessionSnapshot> markPlanFailed({
    required String sessionId,
    required String error,
  }) async => throw _failure;

  @override
  Future<TutorialV2SessionSnapshot> updateAssetStatus({
    required String sessionId,
    required int stepIndex,
    required TutorialV2AssetKind asset,
    required TutorialV2GenerationStatus status,
    String? error,
  }) async => throw _failure;

  @override
  Future<TutorialV2SessionSnapshot> persistAsset({
    required String sessionId,
    required int stepIndex,
    required TutorialV2AssetKind asset,
    required String storagePath,
    String? modelName,
    String? promptVersion,
  }) async => throw _failure;

  @override
  Future<TutorialV2SessionSnapshot> generateGuideline({
    required String sessionId,
    required int stepIndex,
  }) async => throw _failure;

  @override
  Future<String> createSignedUrl(String storagePath) async => throw _failure;
}
