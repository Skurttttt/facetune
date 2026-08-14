import 'package:facetune/features/makeup_kit/domain/entities/kit_generated_preview.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/preview/domain/entities/generated_preview.dart';
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_generation_status.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_instruction.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_placement_metadata.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_session.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_source_mode.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step_category.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/errors/tutorial_failure.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/repositories/tutorial_repository.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/usecases/get_or_create_tutorial_session.dart';
import 'package:flutter_test/flutter_test.dart';

const _analysisId = 'analysis-1';
const _recommendationId = 'recommendation-1';
const _kitRecommendationId = 'kit-recommendation-1';

MakeupRecommendation _recommendation({bool applicable = true}) =>
    MakeupRecommendation(
      id: _recommendationId,
      analysisId: _analysisId,
      styleCode: 'soft_glam',
      overallIntensity: 'light',
      items: {
        'foundation': MakeupRecommendationItem(
          name: 'Medium beige',
          hex: '#C99573',
          placement: 'All over',
          technique: 'Blend with a sponge.',
          finish: 'satin',
          intensity: applicable ? 'light' : 'none',
          reasoning: 'Matches skin tone.',
        ),
        'blush': MakeupRecommendationItem(
          name: 'Warm peach',
          hex: '#E69A7A',
          placement: 'Upper cheekbones',
          technique: 'Blend upward.',
          finish: 'satin',
          intensity: applicable ? 'light' : 'skip',
          reasoning: 'Adds warmth.',
        ),
      },
      modelId: 'gemini-3.6-flash',
      promptVersion: 'makeup_recommendation_v3',
      createdAt: DateTime.utc(2026, 8, 14),
    );

GeneratedPreview _preview() => GeneratedPreview(
  id: 'preview-1',
  analysisId: _analysisId,
  recommendationId: _recommendationId,
  originalImagePath: 'user-1/analyses/$_analysisId/original/img.jpg',
  generatedImagePath:
      'user-1/analyses/$_analysisId/generated/$_recommendationId/preview_0001.png',
  originalImageUrl: 'https://signed.example/original',
  generatedImageUrl: 'https://signed.example/generated',
  generationNumber: 1,
  modelId: 'gemini-3-pro-image',
  promptVersion: 'makeup_preview_v4',
  createdAt: DateTime.utc(2026, 8, 14),
);

KitMakeupRecommendation _kitRecommendation() => KitMakeupRecommendation(
  id: _kitRecommendationId,
  analysisId: _analysisId,
  styleCode: 'everyday',
  selections: const [
    KitMakeupSelection(
      productId: 'p1',
      category: 'lipstick',
      colorHex: '#A45B67',
      finish: 'matte',
      placement: 'Across the lips',
      technique: 'Apply a thin, even layer.',
      intensity: 'soft',
    ),
  ],
  productSnapshots: const [
    KitProductSnapshot(
      productId: 'p1',
      category: 'lipstick',
      productName: 'My Everyday Lipstick',
      colorHex: '#A45B67',
      colorLabel: 'Rosewood',
      finish: 'matte',
    ),
  ],
  overallIntensity: 'light',
  summary: 'A soft everyday look from your kit.',
  modelId: 'gemini-3.6-flash',
  promptVersion: 'kit_makeup_recommendation_v2',
  createdAt: DateTime.utc(2026, 8, 14),
);

KitGeneratedPreview _kitPreview() => KitGeneratedPreview(
  id: 'kit-preview-1',
  analysisId: _analysisId,
  kitRecommendationId: _kitRecommendationId,
  originalImagePath: 'user-1/analyses/$_analysisId/original/img.jpg',
  generatedImagePath:
      'user-1/analyses/$_analysisId/kit-generated/$_kitRecommendationId/preview_0001.png',
  originalImageUrl: 'https://signed.example/original',
  generatedImageUrl: 'https://signed.example/kit-generated',
  generationNumber: 1,
  modelId: 'gemini-3.1-flash-image',
  promptVersion: 'kit_makeup_preview_v1',
  createdAt: DateTime.utc(2026, 8, 14),
);

void main() {
  group('reopening an existing valid tutorial', () {
    test('resumes it instead of creating a new one', () async {
      final existing = _RecordingRepository.buildSession(
        id: 'existing-session',
        generationStatus: TutorialGenerationStatus.completed,
      );
      final repository = _RecordingRepository(existingBeforeCreate: existing);
      final usecase = GetOrCreateTutorialSession(repository);

      final result = await usecase.forRecommendation(
        recommendation: _recommendation(),
        preview: _preview(),
      );

      expect(result.id, 'existing-session');
      expect(repository.createSessionCalls, 0);
      expect(repository.createStepTitles, isEmpty);
      expect(repository.loadExistingCalls, 1);
    });
  });

  group('resuming after an interrupted step-creation attempt (ST-13)', () {
    test('creates only the steps a previous attempt did not finish, without '
        'recreating the session', () async {
      final existing = _RecordingRepository.buildSession(
        id: 'partial-session',
        generationStatus: TutorialGenerationStatus.notStarted,
        totalSteps: 3,
      );
      final existingStep = TutorialStep(
        id: 'step-1',
        tutorialSessionId: 'partial-session',
        stepNumber: 1,
        category: TutorialStepCategory.foundation,
        title: 'Foundation',
        instruction: const TutorialInstruction(
          category: TutorialStepCategory.foundation,
          placement: 'All over',
          intensity: 'light',
          technique: 'Blend with a sponge.',
        ),
        generationStatus: TutorialStepGenerationStatus.notStarted,
        createdAt: DateTime.utc(2026, 8, 14),
        updatedAt: DateTime.utc(2026, 8, 14),
      );
      final repository = _RecordingRepository(
        existingBeforeCreate: existing,
        existingSteps: [existingStep],
      );
      final usecase = GetOrCreateTutorialSession(repository);

      final session = await usecase.forRecommendation(
        recommendation: _recommendation(),
        preview: _preview(),
      );

      // The already-existing session is reused, not recreated.
      expect(repository.createSessionCalls, 0);
      // Only the two missing steps (of the three the plan produces) are
      // created — the already-existing "Foundation" step is skipped.
      expect(repository.createStepTitles, ['Blush', 'Final Look']);
      expect(session.steps, hasLength(3));
      expect(session.steps.map((step) => step.stepNumber).toList(), [1, 2, 3]);
      // The session is still moved to queued once every step exists.
      expect(repository.updatedSessionStatus, TutorialGenerationStatus.queued);
    });
  });

  group('creating a new tutorial', () {
    test(
      'plans, persists a session and one step per category, then the final step',
      () async {
        final repository = _RecordingRepository();
        final usecase = GetOrCreateTutorialSession(repository);

        final session = await usecase.forRecommendation(
          recommendation: _recommendation(),
          preview: _preview(),
        );

        expect(repository.createSessionCalls, 1);
        expect(repository.createStepTitles, [
          'Foundation',
          'Blush',
          'Final Look',
        ]);
        expect(session.steps, hasLength(3));
        expect(session.totalSteps, 3);
      },
    );

    test(
      'sets prompt version to the planning engine version, not a Gemini prompt',
      () async {
        final repository = _RecordingRepository();
        final usecase = GetOrCreateTutorialSession(repository);

        await usecase.forRecommendation(
          recommendation: _recommendation(),
          preview: _preview(),
        );

        expect(repository.lastCreateSessionPromptVersion, 'tutorial_plan_v1');
      },
    );

    test(
      'only the final step is pre-marked completed with reused image data',
      () async {
        final repository = _RecordingRepository();
        final usecase = GetOrCreateTutorialSession(repository);

        await usecase.forRecommendation(
          recommendation: _recommendation(),
          preview: _preview(),
        );

        expect(repository.updateStepImagesCalls, hasLength(1));
        final call = repository.updateStepImagesCalls.single;
        expect(
          call.resultImagePath,
          'user-1/analyses/$_analysisId/generated/$_recommendationId/preview_0001.png',
        );
        expect(call.modelId, 'gemini-3-pro-image');
        expect(call.promptVersion, 'makeup_preview_v4');
        expect(repository.updateStepStatusCalls, [
          TutorialStepGenerationStatus.completed,
        ]);
      },
    );

    test('moves the session to queued once steps are persisted', () async {
      final repository = _RecordingRepository();
      final usecase = GetOrCreateTutorialSession(repository);

      await usecase.forRecommendation(
        recommendation: _recommendation(),
        preview: _preview(),
      );

      expect(repository.updatedSessionStatus, TutorialGenerationStatus.queued);
    });
  });

  group('duplicate prevention beyond the database constraint', () {
    test(
      'losing a create race resumes the winner\'s session instead of erroring or double-creating',
      () async {
        final repository = _RecordingRepository()
          ..simulateDuplicateSessionRaceOnCreate = true;
        final usecase = GetOrCreateTutorialSession(repository);

        final session = await usecase.forRecommendation(
          recommendation: _recommendation(),
          preview: _preview(),
        );

        // The race "winner" is simulated as already having a persisted
        // session by the time our createSession call is rejected.
        expect(session.id, 'race-winner-session');
        // We (the loser) must never create our own steps once we discover
        // the winner already did.
        expect(repository.createStepTitles, isEmpty);
      },
    );

    test(
      'a non-duplicate failure from createSession is not swallowed',
      () async {
        final repository = _RecordingRepository()
          ..failCreateWithServerError = true;
        final usecase = GetOrCreateTutorialSession(repository);

        await expectLater(
          usecase.forRecommendation(
            recommendation: _recommendation(),
            preview: _preview(),
          ),
          throwsA(
            isA<TutorialFailure>().having(
              (failure) => failure.type,
              'type',
              TutorialFailureType.server,
            ),
          ),
        );
        expect(repository.createStepTitles, isEmpty);
      },
    );
  });

  group('an inapplicable recommendation', () {
    test('is rejected before anything is persisted', () async {
      final repository = _RecordingRepository();
      final usecase = GetOrCreateTutorialSession(repository);

      await expectLater(
        usecase.forRecommendation(
          recommendation: _recommendation(applicable: false),
          preview: _preview(),
        ),
        throwsA(isA<TutorialFailure>()),
      );
      expect(repository.createSessionCalls, 0);
    });
  });

  group('My Makeup Kit source', () {
    test(
      'creates a session from only the owned selections, no fabrication',
      () async {
        final repository = _RecordingRepository();
        final usecase = GetOrCreateTutorialSession(repository);

        final session = await usecase.forKitRecommendation(
          recommendation: _kitRecommendation(),
          preview: _kitPreview(),
        );

        expect(repository.createStepTitles, ['Lipstick', 'Final Look']);
        expect(session.steps, hasLength(2));
        final lipstickStep = session.steps.first;
        expect(lipstickStep.instruction.productName, 'My Everyday Lipstick');
        expect(lipstickStep.instruction.colorName, 'Rosewood');
      },
    );

    test('resumes an existing kit tutorial instead of recreating it', () async {
      final existing = _RecordingRepository.buildSession(
        id: 'existing-kit-session',
        generationStatus: TutorialGenerationStatus.completed,
      );
      final repository = _RecordingRepository(existingBeforeCreate: existing);
      final usecase = GetOrCreateTutorialSession(repository);

      final result = await usecase.forKitRecommendation(
        recommendation: _kitRecommendation(),
        preview: _kitPreview(),
      );

      expect(result.id, 'existing-kit-session');
      expect(repository.createSessionCalls, 0);
    });
  });
}

class _StepImagesCall {
  const _StepImagesCall({
    required this.resultImagePath,
    required this.modelId,
    required this.promptVersion,
  });

  final String? resultImagePath;
  final String? modelId;
  final String? promptVersion;
}

/// Records every call `GetOrCreateTutorialSession` makes, and maintains just
/// enough in-memory state (a created session + its steps) to answer
/// `loadExisting` truthfully afterward — the same "fake persistence" shape
/// as `SupabaseTutorialRepository`, without Supabase.
class _RecordingRepository implements TutorialRepository {
  _RecordingRepository({
    this.existingBeforeCreate,
    List<TutorialStep> existingSteps = const [],
  }) {
    _steps.addAll(existingSteps);
  }

  final TutorialSession? existingBeforeCreate;
  bool simulateDuplicateSessionRaceOnCreate = false;
  bool failCreateWithServerError = false;

  int loadExistingCalls = 0;
  int createSessionCalls = 0;
  String? lastCreateSessionPromptVersion;
  final List<String> createStepTitles = [];
  final List<_StepImagesCall> updateStepImagesCalls = [];
  final List<TutorialStepGenerationStatus> updateStepStatusCalls = [];
  TutorialGenerationStatus? updatedSessionStatus;

  TutorialSession? _created;
  final List<TutorialStep> _steps = [];

  static TutorialSession buildSession({
    required String id,
    required TutorialGenerationStatus generationStatus,
    List<TutorialStep> steps = const [],
    int? totalSteps,
  }) => TutorialSession(
    id: id,
    userId: 'user-1',
    sourceMode: TutorialSourceMode.standardRecommendation,
    sourceAnalysisId: _analysisId,
    sourceRecommendationId: _recommendationId,
    styleCode: 'soft_glam',
    generationNumber: 1,
    totalSteps: totalSteps ?? steps.length,
    generationStatus: generationStatus,
    steps: steps,
    createdAt: DateTime.utc(2026, 8, 14),
    updatedAt: DateTime.utc(2026, 8, 14),
  );

  static TutorialStep _fakeStep({
    required int stepNumber,
    required TutorialStepCategory category,
  }) => TutorialStep(
    id: 'step-$stepNumber',
    tutorialSessionId: 'race-winner-session',
    stepNumber: stepNumber,
    category: category,
    title: category.code,
    instruction: TutorialInstruction(
      category: category,
      placement: 'All over',
      intensity: 'light',
      technique: 'Applied.',
    ),
    generationStatus: TutorialStepGenerationStatus.notStarted,
    createdAt: DateTime.utc(2026, 8, 14),
    updatedAt: DateTime.utc(2026, 8, 14),
  );

  @override
  Future<TutorialSession?> loadExisting({
    required TutorialSourceMode sourceMode,
    required String analysisId,
    String? recommendationId,
    String? kitRecommendationId,
    required int generationNumber,
  }) async {
    loadExistingCalls++;
    // `_steps` is always the source of truth for the returned steps list —
    // seeded by `existingSteps` (simulating steps a prior, interrupted
    // attempt already created) and/or appended to by `createStep` below —
    // so a resumed session correctly reflects steps created either before
    // or during this call, matching how `SupabaseTutorialRepository`
    // always re-fetches steps fresh (roadmap ST-13 hardening test).
    final base = _created ?? existingBeforeCreate;
    if (base == null) return null;
    return TutorialSession(
      id: base.id,
      userId: base.userId,
      sourceMode: base.sourceMode,
      sourceAnalysisId: base.sourceAnalysisId,
      sourceRecommendationId: base.sourceRecommendationId,
      sourceKitResultId: base.sourceKitResultId,
      styleCode: base.styleCode,
      generationNumber: base.generationNumber,
      totalSteps: base.totalSteps,
      promptVersion: base.promptVersion,
      generationStatus: base.generationStatus,
      steps: List.unmodifiable(_steps),
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
    );
  }

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
  }) async {
    createSessionCalls++;
    lastCreateSessionPromptVersion = promptVersion;
    if (failCreateWithServerError) {
      throw const TutorialFailure(
        TutorialFailureType.server,
        'Your tutorial could not be updated right now.',
        retryable: true,
      );
    }
    if (simulateDuplicateSessionRaceOnCreate) {
      // A concurrent request "won" — pretend it already persisted a
      // session *and every one of its steps*, matching what a real
      // winner's `createSession` + step-creation loop would have fully
      // completed by the time Postgres rejects our own insert with error
      // 23505 (`totalSteps: 3` mirrors the real plan `_recommendation()`
      // produces below, so the resume loop correctly finds nothing left
      // to create — see the ST-13 "resuming after an interrupted
      // step-creation attempt" tests for the case where it does).
      _created = buildSession(
        id: 'race-winner-session',
        generationStatus: TutorialGenerationStatus.queued,
        totalSteps: 3,
      );
      _steps.addAll([
        _fakeStep(stepNumber: 1, category: TutorialStepCategory.foundation),
        _fakeStep(stepNumber: 2, category: TutorialStepCategory.blush),
        _fakeStep(stepNumber: 3, category: TutorialStepCategory.finalLook),
      ]);
      throw const TutorialFailure(
        TutorialFailureType.validation,
        'A tutorial for this look already exists.',
        technicalCode: 'duplicate_session',
      );
    }
    final now = DateTime.utc(2026, 8, 14);
    _created = TutorialSession(
      id: 'session-1',
      userId: 'user-1',
      sourceMode: sourceMode,
      sourceAnalysisId: analysisId,
      sourceRecommendationId: recommendationId,
      sourceKitResultId: kitRecommendationId,
      styleCode: styleCode,
      generationNumber: generationNumber,
      totalSteps: totalSteps,
      promptVersion: promptVersion,
      generationStatus: TutorialGenerationStatus.notStarted,
      steps: const [],
      createdAt: now,
      updatedAt: now,
    );
    return _created!;
  }

  @override
  Future<TutorialStep> createStep({
    required String tutorialSessionId,
    required int stepNumber,
    required String title,
    required TutorialInstruction instruction,
    TutorialPlacementMetadata? placementMetadata,
  }) async {
    createStepTitles.add(title);
    final now = DateTime.utc(2026, 8, 14);
    final step = TutorialStep(
      id: 'step-$stepNumber',
      tutorialSessionId: tutorialSessionId,
      stepNumber: stepNumber,
      category: instruction.category,
      title: title,
      instruction: instruction,
      placementMetadata: placementMetadata,
      generationStatus: TutorialStepGenerationStatus.notStarted,
      createdAt: now,
      updatedAt: now,
    );
    _steps.add(step);
    return step;
  }

  @override
  Future<TutorialStep> updateStepImages({
    required String tutorialStepId,
    String? placementImagePath,
    String? resultImagePath,
    String? modelId,
    int? imageSize,
    String? promptVersion,
  }) async {
    updateStepImagesCalls.add(
      _StepImagesCall(
        resultImagePath: resultImagePath,
        modelId: modelId,
        promptVersion: promptVersion,
      ),
    );
    final index = _steps.indexWhere((step) => step.id == tutorialStepId);
    final current = _steps[index];
    final updated = TutorialStep(
      id: current.id,
      tutorialSessionId: current.tutorialSessionId,
      stepNumber: current.stepNumber,
      category: current.category,
      title: current.title,
      instruction: current.instruction,
      placementMetadata: current.placementMetadata,
      placementImagePath: placementImagePath ?? current.placementImagePath,
      resultImagePath: resultImagePath ?? current.resultImagePath,
      modelId: modelId ?? current.modelId,
      imageSize: imageSize ?? current.imageSize,
      promptVersion: promptVersion ?? current.promptVersion,
      generationStatus: current.generationStatus,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
    );
    _steps[index] = updated;
    return updated;
  }

  @override
  Future<TutorialStep> updateStepStatus({
    required String tutorialStepId,
    required TutorialStepGenerationStatus status,
  }) async {
    updateStepStatusCalls.add(status);
    final index = _steps.indexWhere((step) => step.id == tutorialStepId);
    final current = _steps[index];
    final updated = TutorialStep(
      id: current.id,
      tutorialSessionId: current.tutorialSessionId,
      stepNumber: current.stepNumber,
      category: current.category,
      title: current.title,
      instruction: current.instruction,
      placementMetadata: current.placementMetadata,
      placementImagePath: current.placementImagePath,
      resultImagePath: current.resultImagePath,
      modelId: current.modelId,
      imageSize: current.imageSize,
      promptVersion: current.promptVersion,
      generationStatus: status,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
    );
    _steps[index] = updated;
    return updated;
  }

  @override
  Future<TutorialStep> generateStepResult({required String tutorialStepId}) =>
      throw UnimplementedError();

  @override
  Future<TutorialSession> resetForRegeneration({
    required String tutorialSessionId,
  }) => throw UnimplementedError();

  @override
  Future<TutorialSession> updateSessionStatus({
    required String tutorialSessionId,
    required TutorialGenerationStatus status,
  }) async {
    updatedSessionStatus = status;
    final current = _created ?? existingBeforeCreate!;
    _created = TutorialSession(
      id: current.id,
      userId: current.userId,
      sourceMode: current.sourceMode,
      sourceAnalysisId: current.sourceAnalysisId,
      sourceRecommendationId: current.sourceRecommendationId,
      sourceKitResultId: current.sourceKitResultId,
      styleCode: current.styleCode,
      generationNumber: current.generationNumber,
      totalSteps: current.totalSteps,
      promptVersion: current.promptVersion,
      generationStatus: status,
      steps: current.steps,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
    );
    return _created!;
  }

  @override
  Future<List<TutorialStep>> loadSteps(String tutorialSessionId) async =>
      List.unmodifiable(_steps);
}
