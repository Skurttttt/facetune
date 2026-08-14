import '../../../makeup_kit/domain/entities/kit_generated_preview.dart';
import '../../../makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import '../../../preview/domain/entities/generated_preview.dart';
import '../../../recommendation/domain/entities/makeup_recommendation.dart';
import '../entities/tutorial_generation_status.dart';
import '../entities/tutorial_plan.dart';
import '../entities/tutorial_session.dart';
import '../entities/tutorial_source_mode.dart';
import '../errors/tutorial_failure.dart';
import '../repositories/tutorial_repository.dart';
import '../services/tutorial_planning_engine.dart';

/// Resumes an existing tutorial session for a look, or plans and persists a
/// new one — never both, and never a second session for the same
/// (source, generation number) pair (guide §12, roadmap ST-8 tasks 2/3/5).
///
/// This is the only place `TutorialPlanningEngine`'s output is turned into
/// `TutorialRepository` writes. It never calls Gemini or an Edge Function
/// (roadmap ST-8 task 8) — every field it persists is either planned
/// deterministically (ST-7) or copied verbatim from an already-existing
/// preview.
class GetOrCreateTutorialSession {
  const GetOrCreateTutorialSession(this._repository);

  final TutorialRepository _repository;

  Future<TutorialSession> forRecommendation({
    required MakeupRecommendation recommendation,
    required GeneratedPreview preview,
  }) => _getOrCreate(
    sourceMode: TutorialSourceMode.standardRecommendation,
    analysisId: recommendation.analysisId,
    recommendationId: recommendation.id,
    generationNumber: preview.generationNumber,
    styleCode: recommendation.styleCode,
    plan: () => TutorialPlanningEngine.planFromRecommendation(
      recommendation: recommendation,
      preview: preview,
    ),
  );

  Future<TutorialSession> forKitRecommendation({
    required KitMakeupRecommendation recommendation,
    required KitGeneratedPreview preview,
  }) => _getOrCreate(
    sourceMode: TutorialSourceMode.makeupKit,
    analysisId: recommendation.analysisId,
    kitRecommendationId: recommendation.id,
    generationNumber: preview.generationNumber,
    styleCode: recommendation.styleCode,
    plan: () => TutorialPlanningEngine.planFromKitRecommendation(
      recommendation: recommendation,
      preview: preview,
    ),
  );

  Future<TutorialSession> _getOrCreate({
    required TutorialSourceMode sourceMode,
    required String analysisId,
    String? recommendationId,
    String? kitRecommendationId,
    required int generationNumber,
    required String styleCode,
    required TutorialPlan Function() plan,
  }) async {
    Future<TutorialSession?> loadExisting() => _repository.loadExisting(
      sourceMode: sourceMode,
      analysisId: analysisId,
      recommendationId: recommendationId,
      kitRecommendationId: kitRecommendationId,
      generationNumber: generationNumber,
    );

    final existing = await loadExisting();
    // A session whose step count already matches its planned total is
    // fully created — nothing left to resume (roadmap ST-13 hardening;
    // see the `else` branch below for the case this guards against).
    if (existing != null && existing.steps.length >= existing.totalSteps) {
      return existing;
    }

    final tutorialPlan = plan();
    if (tutorialPlan.steps.isEmpty) {
      throw const TutorialFailure(
        TutorialFailureType.validation,
        'This look does not have any makeup steps to build a tutorial '
        'from.',
      );
    }

    TutorialSession session;
    if (existing != null) {
      // A previous attempt already created the session but was
      // interrupted before every planned step was persisted (e.g. a
      // network failure partway through the loop below) — resume it
      // instead of leaving it permanently stuck with too few steps.
      // Planning is a pure function of the same source data, so
      // replanning here reproduces the identical step list; the loop
      // below only creates whichever of those steps are still missing.
      session = existing;
    } else {
      try {
        session = await _repository.createSession(
          sourceMode: sourceMode,
          analysisId: analysisId,
          recommendationId: recommendationId,
          kitRecommendationId: kitRecommendationId,
          styleCode: styleCode,
          generationNumber: generationNumber,
          totalSteps: tutorialPlan.totalSteps,
          promptVersion: TutorialPlanningEngine.planVersion,
        );
      } on TutorialFailure catch (failure) {
        if (failure.technicalCode != 'duplicate_session') rethrow;
        // Lost a race with a concurrent request that created this session
        // first (application-level duplicate prevention on top of the
        // database's own unique index — roadmap ST-8 task 5). Resume it
        // the same way as the `existing != null` branch above, rather
        // than assuming the winner necessarily finished creating every
        // step itself.
        final resumed = await loadExisting();
        if (resumed == null) rethrow;
        session = resumed;
      }
    }

    final createdStepNumbers = session.steps
        .map((step) => step.stepNumber)
        .toSet();
    for (final plannedStep in tutorialPlan.steps) {
      if (createdStepNumbers.contains(plannedStep.stepNumber)) continue;
      final step = await _repository.createStep(
        tutorialSessionId: session.id,
        stepNumber: plannedStep.stepNumber,
        title: plannedStep.title,
        instruction: plannedStep.instruction,
        placementMetadata: plannedStep.placementMetadata,
        personalizedSpec: plannedStep.personalizedSpec,
      );
      final reusablePath = plannedStep.reusableResultImagePath;
      if (reusablePath != null) {
        await _repository.updateStepImages(
          tutorialStepId: step.id,
          resultImagePath: reusablePath,
          modelId: plannedStep.reusableModelId,
          promptVersion: plannedStep.reusablePromptVersion,
        );
        await _repository.updateStepStatus(
          tutorialStepId: step.id,
          status: TutorialStepGenerationStatus.completed,
        );
      }
    }

    // Planning and step creation are both done; the remaining (non-reused)
    // steps are ready for a generation worker to pick up (ST-9).
    await _repository.updateSessionStatus(
      tutorialSessionId: session.id,
      status: TutorialGenerationStatus.queued,
    );

    final hydrated = await loadExisting();
    if (hydrated == null) {
      throw const TutorialFailure(
        TutorialFailureType.server,
        'The tutorial was created but could not be reloaded.',
        retryable: true,
      );
    }
    return hydrated;
  }
}
