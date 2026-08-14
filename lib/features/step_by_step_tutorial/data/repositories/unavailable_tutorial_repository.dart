import '../../domain/entities/tutorial_generation_status.dart';
import '../../domain/entities/tutorial_instruction.dart';
import '../../domain/entities/tutorial_placement_metadata.dart';
import '../../domain/entities/tutorial_session.dart';
import '../../domain/entities/tutorial_source_mode.dart';
import '../../domain/entities/tutorial_step.dart';
import '../../domain/errors/tutorial_failure.dart';
import '../../domain/repositories/tutorial_repository.dart';

/// Used when `supabaseAvailableProvider` reports the Supabase runtime is not
/// configured on this device — matches `UnavailableMakeupPreviewRepository`
/// and `UnavailableMakeupKitLookRepository` exactly. Distinct from ST-1's
/// (now superseded) `UnimplementedTutorialRepository`, which meant "no
/// implementation exists yet"; this means "an implementation exists but the
/// runtime it depends on is unavailable."
class UnavailableTutorialRepository implements TutorialRepository {
  const UnavailableTutorialRepository();

  static const _failure = TutorialFailure(
    TutorialFailureType.server,
    'Supabase runtime configuration is unavailable.',
  );

  @override
  Future<TutorialSession?> loadExisting({
    required TutorialSourceMode sourceMode,
    required String analysisId,
    String? recommendationId,
    String? kitRecommendationId,
    required int generationNumber,
  }) => throw _failure;

  @override
  Future<TutorialSession> createSession({
    required TutorialSourceMode sourceMode,
    required String analysisId,
    String? recommendationId,
    String? kitRecommendationId,
    required String styleCode,
    required int generationNumber,
    required int totalSteps,
    String? tutorialModel,
    int? tutorialImageSize,
    String? promptVersion,
  }) => throw _failure;

  @override
  Future<List<TutorialStep>> loadSteps(String tutorialSessionId) =>
      throw _failure;

  @override
  Future<TutorialStep> createStep({
    required String tutorialSessionId,
    required int stepNumber,
    required String title,
    required TutorialInstruction instruction,
    TutorialPlacementMetadata? placementMetadata,
  }) => throw _failure;

  @override
  Future<TutorialStep> updateStepImages({
    required String tutorialStepId,
    String? placementImagePath,
    String? resultImagePath,
    String? modelId,
    int? imageSize,
    String? promptVersion,
  }) => throw _failure;

  @override
  Future<TutorialSession> updateSessionStatus({
    required String tutorialSessionId,
    required TutorialGenerationStatus status,
  }) => throw _failure;

  @override
  Future<TutorialStep> updateStepStatus({
    required String tutorialStepId,
    required TutorialStepGenerationStatus status,
  }) => throw _failure;
}
