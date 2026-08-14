import 'dart:async';

import 'package:facetune/features/preview/domain/entities/generated_preview.dart';
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_generation_status.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_instruction.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/personalized_tutorial.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_placement_metadata.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_session.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_source_mode.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step_category.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/errors/tutorial_failure.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/repositories/tutorial_repository.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/usecases/get_or_create_tutorial_session.dart';
import 'package:facetune/features/step_by_step_tutorial/presentation/controllers/tutorial_session_controller.dart';
import 'package:facetune/features/step_by_step_tutorial/presentation/controllers/tutorial_session_state.dart';
import 'package:flutter_test/flutter_test.dart';

const analysisId = 'analysis-1';
const recommendationId = 'recommendation-1';

TutorialSession _session(
  TutorialGenerationStatus status, {
  List<TutorialStep> steps = const [],
}) => TutorialSession(
  id: 'session-1',
  userId: 'user-1',
  sourceMode: TutorialSourceMode.standardRecommendation,
  sourceAnalysisId: analysisId,
  sourceRecommendationId: recommendationId,
  styleCode: 'soft_glam',
  generationNumber: 1,
  totalSteps: 8,
  generationStatus: status,
  steps: steps,
  createdAt: DateTime.utc(2026, 8, 14),
  updatedAt: DateTime.utc(2026, 8, 14),
);

TutorialStep _step({
  required String id,
  required int stepNumber,
  String? resultImageUrl,
  TutorialStepGenerationStatus status = TutorialStepGenerationStatus.notStarted,
  TutorialStepCategory category = TutorialStepCategory.foundation,
}) => TutorialStep(
  id: id,
  tutorialSessionId: 'session-1',
  stepNumber: stepNumber,
  category: category,
  title: 'Apply Foundation',
  instruction: const TutorialInstruction(
    category: TutorialStepCategory.foundation,
    placement: 'All over',
    intensity: 'light',
    technique: 'Blend with a sponge.',
  ),
  placementImagePath: resultImageUrl == null ? null : 'placement/path.jpg',
  placementImageUrl: resultImageUrl == null ? null : 'https://signed/placement',
  resultImagePath: resultImageUrl == null ? null : 'result/path.jpg',
  resultImageUrl: resultImageUrl,
  generationStatus: status,
  createdAt: DateTime.utc(2026, 8, 14),
  updatedAt: DateTime.utc(2026, 8, 14),
);

MakeupRecommendation _recommendation() => MakeupRecommendation(
  id: recommendationId,
  analysisId: analysisId,
  styleCode: 'soft_glam',
  overallIntensity: 'light',
  items: {
    'foundation': const MakeupRecommendationItem(
      name: 'Medium beige',
      hex: '#C99573',
      placement: 'All over',
      technique: 'Blend with a sponge.',
      finish: 'satin',
      intensity: 'light',
      reasoning: 'Matches skin tone.',
    ),
  },
  modelId: 'gemini-3.6-flash',
  promptVersion: 'makeup_recommendation_v3',
  createdAt: DateTime.utc(2026, 8, 14),
);

GeneratedPreview _preview() => GeneratedPreview(
  id: 'preview-1',
  analysisId: analysisId,
  recommendationId: recommendationId,
  originalImagePath: 'user-1/analyses/$analysisId/original/img.jpg',
  generatedImagePath:
      'user-1/analyses/$analysisId/generated/$recommendationId/preview_0001.png',
  originalImageUrl: 'https://signed.example/original',
  generatedImageUrl: 'https://signed.example/generated',
  generationNumber: 1,
  modelId: 'gemini-3-pro-image',
  promptVersion: 'makeup_preview_v4',
  createdAt: DateTime.utc(2026, 8, 14),
);

Future<void> _prepare(TutorialSessionController controller) =>
    controller.prepareForRecommendation(
      recommendation: _recommendation(),
      preview: _preview(),
    );

void main() {
  test('preparing when no session exists yet reports loaded/null', () async {
    final controller = TutorialSessionController(
      _FakeRepository(),
      GetOrCreateTutorialSession(_FakeRepository()),
    );
    addTearDown(controller.dispose);

    await _prepare(controller);

    expect(controller.state.status, TutorialSessionStatus.loaded);
    expect(controller.state.session, isNull);
  });

  test('an in-progress persisted session maps to generating', () async {
    final repository = _FakeRepository(
      existing: _session(TutorialGenerationStatus.queued),
    );
    final controller = TutorialSessionController(
      repository,
      GetOrCreateTutorialSession(repository),
    );
    addTearDown(controller.dispose);

    await _prepare(controller);

    expect(controller.state.status, TutorialSessionStatus.generating);
    expect(controller.state.session, isNotNull);
  });

  test('a completed persisted session maps to loaded', () async {
    final repository = _FakeRepository(
      existing: _session(TutorialGenerationStatus.completed),
    );
    final controller = TutorialSessionController(
      repository,
      GetOrCreateTutorialSession(repository),
    );
    addTearDown(controller.dispose);

    await _prepare(controller);

    expect(controller.state.status, TutorialSessionStatus.loaded);
    expect(controller.state.session, isNotNull);
  });

  test('a failed check surfaces a retryable failure', () async {
    final repository = _FakeRepository(
      failure: const TutorialFailure(
        TutorialFailureType.network,
        'Check your connection and try again.',
        retryable: true,
      ),
    );
    final controller = TutorialSessionController(
      repository,
      GetOrCreateTutorialSession(repository),
    );
    addTearDown(controller.dispose);

    await _prepare(controller);

    expect(controller.state.status, TutorialSessionStatus.failed);
    expect(controller.state.retryable, isTrue);
    expect(controller.state.sessionExpired, isFalse);
  });

  test('an authentication failure is flagged as session expired', () async {
    final repository = _FakeRepository(
      failure: const TutorialFailure(
        TutorialFailureType.authentication,
        'Your session expired. Sign in again.',
      ),
    );
    final controller = TutorialSessionController(
      repository,
      GetOrCreateTutorialSession(repository),
    );
    addTearDown(controller.dispose);

    await _prepare(controller);

    expect(controller.state.sessionExpired, isTrue);
  });

  test('retry repeats the check, not a pending generate', () async {
    final repository = _FakeRepository();
    final controller = TutorialSessionController(
      repository,
      GetOrCreateTutorialSession(repository),
    );
    addTearDown(controller.dispose);

    await _prepare(controller);
    await controller.retry();

    expect(repository.loadExistingCalls, 2);
    expect(repository.createSessionCalls, 0);
  });

  test('retry before any operation is a no-op', () async {
    final repository = _FakeRepository();
    final controller = TutorialSessionController(
      repository,
      GetOrCreateTutorialSession(repository),
    );
    addTearDown(controller.dispose);

    await controller.retry();

    expect(repository.loadExistingCalls, 0);
    expect(controller.state.status, TutorialSessionStatus.initial);
  });

  test('generate before prepare is a no-op', () async {
    final repository = _FakeRepository();
    final controller = TutorialSessionController(
      repository,
      GetOrCreateTutorialSession(repository),
    );
    addTearDown(controller.dispose);

    await controller.generate();

    expect(repository.createSessionCalls, 0);
    expect(controller.state.status, TutorialSessionStatus.initial);
  });

  test('generate plans and persists a new session, then reports it', () async {
    final repository = _CreatingRepository();
    final controller = TutorialSessionController(
      repository,
      GetOrCreateTutorialSession(repository),
    );
    addTearDown(controller.dispose);

    await _prepare(controller);
    expect(controller.state.session, isNull);

    await controller.generate();

    expect(controller.state.status, TutorialSessionStatus.generating);
    expect(controller.state.session, isNotNull);
    expect(controller.state.session!.steps, isNotEmpty);
    expect(repository.createSessionCalls, 1);
  });

  test(
    'retry after a failed generate re-runs generate, not the original check',
    () async {
      final repository = _CreatingRepository()..failNextCreate = true;
      final controller = TutorialSessionController(
        repository,
        GetOrCreateTutorialSession(repository),
      );
      addTearDown(controller.dispose);

      await _prepare(controller);
      await controller.generate();
      expect(controller.state.status, TutorialSessionStatus.failed);

      repository.failNextCreate = false;
      await controller.retry();

      expect(controller.state.status, TutorialSessionStatus.generating);
      expect(controller.state.session, isNotNull);
    },
  );

  test('a second prepare call while one is already in flight is ignored '
      '(application-level duplicate prevention)', () async {
    final repository = _BlockingRepository();
    final controller = TutorialSessionController(
      repository,
      GetOrCreateTutorialSession(repository),
    );
    addTearDown(controller.dispose);

    final first = _prepare(controller);
    final second = _prepare(controller); // must be a no-op, not queued
    expect(controller.state.status, TutorialSessionStatus.loading);
    repository.completeOldest(_session(TutorialGenerationStatus.completed));
    await Future.wait([first, second]);

    // Only the first call's repository query ever actually ran.
    expect(repository.startedCalls, 1);
    expect(controller.state.status, TutorialSessionStatus.loaded);
  });

  test('clear discards a check that completes afterward', () async {
    final repository = _BlockingRepository();
    final controller = TutorialSessionController(
      repository,
      GetOrCreateTutorialSession(repository),
    );
    addTearDown(controller.dispose);

    final operation = _prepare(controller);
    controller.clear();
    repository.completeOldest(_session(TutorialGenerationStatus.completed));
    await operation;

    expect(controller.state.status, TutorialSessionStatus.initial);
    expect(controller.state.session, isNull);
  });

  group('generateStep', () {
    test('is a no-op when no session is loaded', () async {
      final controller = TutorialSessionController(
        _FakeRepository(),
        GetOrCreateTutorialSession(_FakeRepository()),
      );
      addTearDown(controller.dispose);

      await controller.generateStep('step-2');

      expect(controller.state.status, TutorialSessionStatus.initial);
    });

    test('is a no-op for a step id not in the loaded session', () async {
      final session = _session(
        TutorialGenerationStatus.generating,
        steps: [_step(id: 'step-1', stepNumber: 1, resultImageUrl: 'url')],
      );
      final repository = _StepGenerationRepository(session);
      final controller = TutorialSessionController(
        repository,
        GetOrCreateTutorialSession(repository),
      );
      addTearDown(controller.dispose);
      await _prepare(controller);

      await controller.generateStep('not-a-real-step');

      expect(repository.generateCalls, 0);
    });

    test('is a no-op for a step that already has a result', () async {
      final session = _session(
        TutorialGenerationStatus.generating,
        steps: [_step(id: 'step-1', stepNumber: 1, resultImageUrl: 'url')],
      );
      final repository = _StepGenerationRepository(session);
      final controller = TutorialSessionController(
        repository,
        GetOrCreateTutorialSession(repository),
      );
      addTearDown(controller.dispose);
      await _prepare(controller);

      await controller.generateStep('step-1');

      expect(repository.generateCalls, 0);
    });

    test('generates the missing step and merges it into the session', () async {
      final session = _session(
        TutorialGenerationStatus.generating,
        steps: [
          _step(
            id: 'step-1',
            stepNumber: 1,
            resultImageUrl: 'url',
            status: TutorialStepGenerationStatus.completed,
          ),
          _step(id: 'step-2', stepNumber: 2),
        ],
      );
      final repository = _StepGenerationRepository(session);
      final controller = TutorialSessionController(
        repository,
        GetOrCreateTutorialSession(repository),
      );
      addTearDown(controller.dispose);
      await _prepare(controller);

      await controller.generateStep('step-2');

      expect(repository.generateCalls, 1);
      expect(controller.state.generatingStepId, isNull);
      expect(controller.state.stepFailureStepId, isNull);
      final updatedSteps = controller.state.session!.steps;
      expect(
        updatedSteps.firstWhere((step) => step.id == 'step-2').resultImageUrl,
        isNotNull,
      );
      // The untouched sibling step is preserved as-is.
      expect(
        updatedSteps.firstWhere((step) => step.id == 'step-1').resultImageUrl,
        'url',
      );
      // The overall session-level status (e.g. from a full reload) is left
      // alone by a per-step merge — see the controller's doc comment.
      expect(controller.state.status, TutorialSessionStatus.generating);
    });

    test(
      'guards against a second call while one is already in flight',
      () async {
        final session = _session(
          TutorialGenerationStatus.generating,
          steps: [_step(id: 'step-1', stepNumber: 1)],
        );
        final repository = _StepGenerationRepository(session)..blocking = true;
        final controller = TutorialSessionController(
          repository,
          GetOrCreateTutorialSession(repository),
        );
        addTearDown(controller.dispose);
        await _prepare(controller);

        final first = controller.generateStep('step-1');
        final second = controller.generateStep('step-1'); // must be a no-op
        expect(controller.state.generatingStepId, 'step-1');
        repository.completeOldest(
          _step(id: 'step-1', stepNumber: 1, resultImageUrl: 'url'),
        );
        await Future.wait([first, second]);

        expect(repository.generateCalls, 1);
      },
    );

    test('a failed generation reports a per-step failure without clearing '
        'the session', () async {
      final session = _session(
        TutorialGenerationStatus.generating,
        steps: [_step(id: 'step-1', stepNumber: 1)],
      );
      final repository = _StepGenerationRepository(session)
        ..failure = const TutorialFailure(
          TutorialFailureType.gemini,
          'The image service did not return a usable image.',
          retryable: true,
        );
      final controller = TutorialSessionController(
        repository,
        GetOrCreateTutorialSession(repository),
      );
      addTearDown(controller.dispose);
      await _prepare(controller);

      await controller.generateStep('step-1');

      expect(controller.state.generatingStepId, isNull);
      expect(controller.state.stepFailureStepId, 'step-1');
      expect(
        controller.state.stepFailureMessage,
        'The image service did not return a usable image.',
      );
      expect(controller.state.stepFailureRetryable, isTrue);
      expect(controller.state.session, isNotNull);
    });

    test(
      'clear discards a generateStep result that resolves afterward',
      () async {
        final session = _session(
          TutorialGenerationStatus.generating,
          steps: [_step(id: 'step-1', stepNumber: 1)],
        );
        final repository = _StepGenerationRepository(session)..blocking = true;
        final controller = TutorialSessionController(
          repository,
          GetOrCreateTutorialSession(repository),
        );
        addTearDown(controller.dispose);
        await _prepare(controller);

        final operation = controller.generateStep('step-1');
        controller.clear();
        repository.completeOldest(
          _step(id: 'step-1', stepNumber: 1, resultImageUrl: 'url'),
        );
        await operation;

        expect(controller.state.status, TutorialSessionStatus.initial);
        expect(controller.state.session, isNull);
      },
    );
  });

  group('regenerate', () {
    test('is a no-op when no session is loaded', () async {
      final controller = TutorialSessionController(
        _FakeRepository(),
        GetOrCreateTutorialSession(_FakeRepository()),
      );
      addTearDown(controller.dispose);

      await controller.regenerate();

      expect(controller.state.status, TutorialSessionStatus.initial);
    });

    test(
      'resets the session and every non-final step, reported as generating',
      () async {
        final session = _session(
          TutorialGenerationStatus.completed,
          steps: [
            _step(
              id: 'step-1',
              stepNumber: 1,
              resultImageUrl: 'url-1',
              status: TutorialStepGenerationStatus.completed,
            ),
            _step(
              id: 'step-2',
              stepNumber: 2,
              category: TutorialStepCategory.finalLook,
              resultImageUrl: 'url-final',
              status: TutorialStepGenerationStatus.completed,
            ),
          ],
        );
        final repository = _StepGenerationRepository(session);
        final controller = TutorialSessionController(
          repository,
          GetOrCreateTutorialSession(repository),
        );
        addTearDown(controller.dispose);
        await _prepare(controller);

        await controller.regenerate();

        expect(repository.resetCalls, 1);
        expect(controller.state.status, TutorialSessionStatus.generating);
        final steps = controller.state.session!.steps;
        expect(
          steps.firstWhere((s) => s.id == 'step-1').resultImageUrl,
          isNull,
        );
        // The final-look step is never touched by regeneration.
        expect(
          steps.firstWhere((s) => s.id == 'step-2').resultImageUrl,
          'url-final',
        );
      },
    );

    test(
      'a reset failure surfaces as a normal session-level failure',
      () async {
        final session = _session(
          TutorialGenerationStatus.completed,
          steps: [_step(id: 'step-1', stepNumber: 1, resultImageUrl: 'url')],
        );
        final repository = _StepGenerationRepository(session)
          ..resetFailure = const TutorialFailure(
            TutorialFailureType.server,
            'Your tutorial could not be updated right now.',
            retryable: true,
          );
        final controller = TutorialSessionController(
          repository,
          GetOrCreateTutorialSession(repository),
        );
        addTearDown(controller.dispose);
        await _prepare(controller);

        await controller.regenerate();

        expect(controller.state.status, TutorialSessionStatus.failed);
        expect(controller.state.retryable, isTrue);
      },
    );

    test('is a no-op while a step is already generating', () async {
      final session = _session(
        TutorialGenerationStatus.generating,
        steps: [_step(id: 'step-1', stepNumber: 1)],
      );
      final repository = _StepGenerationRepository(session)..blocking = true;
      final controller = TutorialSessionController(
        repository,
        GetOrCreateTutorialSession(repository),
      );
      addTearDown(controller.dispose);
      await _prepare(controller);

      unawaited(controller.generateStep('step-1'));
      await controller.regenerate();

      expect(repository.resetCalls, 0);
    });

    test(
      'clear discards a regenerate result that resolves afterward',
      () async {
        final session = _session(
          TutorialGenerationStatus.completed,
          steps: [_step(id: 'step-1', stepNumber: 1, resultImageUrl: 'url')],
        );
        final repository = _StepGenerationRepository(session)
          ..resetBlocking = true;
        final controller = TutorialSessionController(
          repository,
          GetOrCreateTutorialSession(repository),
        );
        addTearDown(controller.dispose);
        await _prepare(controller);

        final operation = controller.regenerate();
        controller.clear();
        repository.completeOldestReset(session);
        await operation;

        expect(controller.state.status, TutorialSessionStatus.initial);
        expect(controller.state.session, isNull);
      },
    );
  });
}

class _FakeRepository implements TutorialRepository {
  _FakeRepository({this.existing, this.failure});

  final TutorialSession? existing;
  final TutorialFailure? failure;
  int loadExistingCalls = 0;
  int createSessionCalls = 0;

  @override
  Future<TutorialSession?> loadExisting({
    required TutorialSourceMode sourceMode,
    required String analysisId,
    String? recommendationId,
    String? kitRecommendationId,
    required int generationNumber,
  }) async {
    loadExistingCalls++;
    if (failure != null) throw failure!;
    return existing;
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
    throw UnimplementedError();
  }

  @override
  Future<List<TutorialStep>> loadSteps(String tutorialSessionId) =>
      throw UnimplementedError();

  @override
  Future<TutorialStep> createStep({
    required String tutorialSessionId,
    required int stepNumber,
    required String title,
    required TutorialInstruction instruction,
    TutorialPlacementMetadata? placementMetadata,
    PersonalizedTutorialStepSpec? personalizedSpec,
  }) => throw UnimplementedError();

  @override
  Future<TutorialStep> updateStepImages({
    required String tutorialStepId,
    String? placementImagePath,
    String? resultImagePath,
    String? modelId,
    int? imageSize,
    String? promptVersion,
  }) => throw UnimplementedError();

  @override
  Future<TutorialSession> updateSessionStatus({
    required String tutorialSessionId,
    required TutorialGenerationStatus status,
  }) => throw UnimplementedError();

  @override
  Future<TutorialStep> updateStepStatus({
    required String tutorialStepId,
    required TutorialStepGenerationStatus status,
  }) => throw UnimplementedError();

  @override
  Future<TutorialStep> generateStepResult({required String tutorialStepId}) =>
      throw UnimplementedError();

  @override
  Future<TutorialSession> resetForRegeneration({
    required String tutorialSessionId,
  }) => throw UnimplementedError();
}

/// A minimal in-memory "database" backing a successful (or, once
/// [failNextCreate] is set, a failing) create flow — enough for the
/// controller to exercise [GetOrCreateTutorialSession] end to end without
/// a real Supabase project. Deep coverage of the create flow itself
/// (duplicate handling, snapshot fields, ordering, ...) lives in
/// `get_or_create_tutorial_session_test.dart`; this fake only needs to be
/// complete enough for the controller-level tests above.
class _CreatingRepository implements TutorialRepository {
  TutorialSession? _session;
  final List<TutorialStep> _steps = [];
  bool failNextCreate = false;
  int createSessionCalls = 0;

  @override
  Future<TutorialSession?> loadExisting({
    required TutorialSourceMode sourceMode,
    required String analysisId,
    String? recommendationId,
    String? kitRecommendationId,
    required int generationNumber,
  }) async {
    final session = _session;
    if (session == null) return null;
    return TutorialSession(
      id: session.id,
      userId: session.userId,
      sourceMode: session.sourceMode,
      sourceAnalysisId: session.sourceAnalysisId,
      sourceRecommendationId: session.sourceRecommendationId,
      sourceKitResultId: session.sourceKitResultId,
      styleCode: session.styleCode,
      generationNumber: session.generationNumber,
      totalSteps: session.totalSteps,
      generationStatus: session.generationStatus,
      steps: List.unmodifiable(_steps),
      createdAt: session.createdAt,
      updatedAt: session.updatedAt,
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
    if (failNextCreate) {
      throw const TutorialFailure(
        TutorialFailureType.server,
        'Your tutorial could not be updated right now.',
        retryable: true,
      );
    }
    final now = DateTime.utc(2026, 8, 14);
    _session = TutorialSession(
      id: 'session-1',
      userId: 'user-1',
      sourceMode: sourceMode,
      sourceAnalysisId: analysisId,
      sourceRecommendationId: recommendationId,
      sourceKitResultId: kitRecommendationId,
      styleCode: styleCode,
      generationNumber: generationNumber,
      totalSteps: totalSteps,
      generationStatus: TutorialGenerationStatus.notStarted,
      steps: const [],
      createdAt: now,
      updatedAt: now,
    );
    return _session!;
  }

  @override
  Future<TutorialStep> createStep({
    required String tutorialSessionId,
    required int stepNumber,
    required String title,
    required TutorialInstruction instruction,
    TutorialPlacementMetadata? placementMetadata,
    PersonalizedTutorialStepSpec? personalizedSpec,
  }) async {
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
  }) async => _steps.firstWhere((step) => step.id == tutorialStepId);

  @override
  Future<TutorialSession> updateSessionStatus({
    required String tutorialSessionId,
    required TutorialGenerationStatus status,
  }) async {
    final session = _session!;
    _session = TutorialSession(
      id: session.id,
      userId: session.userId,
      sourceMode: session.sourceMode,
      sourceAnalysisId: session.sourceAnalysisId,
      sourceRecommendationId: session.sourceRecommendationId,
      sourceKitResultId: session.sourceKitResultId,
      styleCode: session.styleCode,
      generationNumber: session.generationNumber,
      totalSteps: session.totalSteps,
      generationStatus: status,
      steps: session.steps,
      createdAt: session.createdAt,
      updatedAt: session.updatedAt,
    );
    return _session!;
  }

  @override
  Future<TutorialStep> updateStepStatus({
    required String tutorialStepId,
    required TutorialStepGenerationStatus status,
  }) async => _steps.firstWhere((step) => step.id == tutorialStepId);

  @override
  Future<List<TutorialStep>> loadSteps(String tutorialSessionId) async =>
      List.unmodifiable(_steps);

  @override
  Future<TutorialStep> generateStepResult({required String tutorialStepId}) =>
      throw UnimplementedError();

  @override
  Future<TutorialSession> resetForRegeneration({
    required String tutorialSessionId,
  }) => throw UnimplementedError();
}

class _BlockingRepository implements TutorialRepository {
  final List<Completer<TutorialSession?>> _pending = [];
  int startedCalls = 0;

  /// Completes the oldest still-pending [loadExisting] call, FIFO, so
  /// overlapping calls can be resolved in either order.
  void completeOldest(TutorialSession? session) =>
      _pending.removeAt(0).complete(session);

  @override
  Future<TutorialSession?> loadExisting({
    required TutorialSourceMode sourceMode,
    required String analysisId,
    String? recommendationId,
    String? kitRecommendationId,
    required int generationNumber,
  }) {
    startedCalls++;
    final completer = Completer<TutorialSession?>();
    _pending.add(completer);
    return completer.future;
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
  }) => throw UnimplementedError();

  @override
  Future<List<TutorialStep>> loadSteps(String tutorialSessionId) =>
      throw UnimplementedError();

  @override
  Future<TutorialStep> createStep({
    required String tutorialSessionId,
    required int stepNumber,
    required String title,
    required TutorialInstruction instruction,
    TutorialPlacementMetadata? placementMetadata,
    PersonalizedTutorialStepSpec? personalizedSpec,
  }) => throw UnimplementedError();

  @override
  Future<TutorialStep> updateStepImages({
    required String tutorialStepId,
    String? placementImagePath,
    String? resultImagePath,
    String? modelId,
    int? imageSize,
    String? promptVersion,
  }) => throw UnimplementedError();

  @override
  Future<TutorialSession> updateSessionStatus({
    required String tutorialSessionId,
    required TutorialGenerationStatus status,
  }) => throw UnimplementedError();

  @override
  Future<TutorialStep> updateStepStatus({
    required String tutorialStepId,
    required TutorialStepGenerationStatus status,
  }) => throw UnimplementedError();

  @override
  Future<TutorialStep> generateStepResult({required String tutorialStepId}) =>
      throw UnimplementedError();

  @override
  Future<TutorialSession> resetForRegeneration({
    required String tutorialSessionId,
  }) => throw UnimplementedError();
}

/// Backs [TutorialSessionController.generateStep]/[TutorialSessionController.regenerate]
/// tests: [loadExisting] always returns [session] (mutated in place by
/// tests as needed), [generateStepResult] either completes immediately
/// with an updated copy of the requested step, blocks on a [Completer]
/// (see [completeOldest]), or throws [failure], and [resetForRegeneration]
/// either completes with every non-final-look step reset to
/// `notStarted`, blocks (see [completeOldestReset]), or throws
/// [resetFailure] — whichever the test configures.
class _StepGenerationRepository implements TutorialRepository {
  _StepGenerationRepository(this.session);

  TutorialSession session;
  TutorialFailure? failure;
  bool blocking = false;
  int generateCalls = 0;
  final List<Completer<TutorialStep>> _pending = [];

  TutorialFailure? resetFailure;
  bool resetBlocking = false;
  int resetCalls = 0;
  final List<Completer<TutorialSession>> _pendingReset = [];

  void completeOldest(TutorialStep step) => _pending.removeAt(0).complete(step);

  void completeOldestReset(TutorialSession result) =>
      _pendingReset.removeAt(0).complete(result);

  @override
  Future<TutorialSession?> loadExisting({
    required TutorialSourceMode sourceMode,
    required String analysisId,
    String? recommendationId,
    String? kitRecommendationId,
    required int generationNumber,
  }) async => session;

  @override
  Future<TutorialStep> generateStepResult({
    required String tutorialStepId,
  }) async {
    generateCalls++;
    if (blocking) {
      final completer = Completer<TutorialStep>();
      _pending.add(completer);
      return completer.future;
    }
    if (failure != null) throw failure!;
    final step = session.steps.firstWhere((s) => s.id == tutorialStepId);
    return _step(
      id: step.id,
      stepNumber: step.stepNumber,
      resultImageUrl: 'https://signed.example/result-${step.stepNumber}',
      status: TutorialStepGenerationStatus.completed,
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
  }) => throw UnimplementedError();

  @override
  Future<List<TutorialStep>> loadSteps(String tutorialSessionId) =>
      throw UnimplementedError();

  @override
  Future<TutorialStep> createStep({
    required String tutorialSessionId,
    required int stepNumber,
    required String title,
    required TutorialInstruction instruction,
    TutorialPlacementMetadata? placementMetadata,
    PersonalizedTutorialStepSpec? personalizedSpec,
  }) => throw UnimplementedError();

  @override
  Future<TutorialStep> updateStepImages({
    required String tutorialStepId,
    String? placementImagePath,
    String? resultImagePath,
    String? modelId,
    int? imageSize,
    String? promptVersion,
  }) => throw UnimplementedError();

  @override
  Future<TutorialSession> updateSessionStatus({
    required String tutorialSessionId,
    required TutorialGenerationStatus status,
  }) => throw UnimplementedError();

  @override
  Future<TutorialStep> updateStepStatus({
    required String tutorialStepId,
    required TutorialStepGenerationStatus status,
  }) => throw UnimplementedError();

  @override
  Future<TutorialSession> resetForRegeneration({
    required String tutorialSessionId,
  }) async {
    resetCalls++;
    if (resetBlocking) {
      final completer = Completer<TutorialSession>();
      _pendingReset.add(completer);
      return completer.future;
    }
    if (resetFailure != null) throw resetFailure!;
    final resetSteps = [
      for (final step in session.steps)
        if (step.category == TutorialStepCategory.finalLook)
          step
        else
          _step(
            id: step.id,
            stepNumber: step.stepNumber,
            category: step.category,
          ),
    ];
    session = TutorialSession(
      id: session.id,
      userId: session.userId,
      sourceMode: session.sourceMode,
      sourceAnalysisId: session.sourceAnalysisId,
      sourceRecommendationId: session.sourceRecommendationId,
      sourceKitResultId: session.sourceKitResultId,
      styleCode: session.styleCode,
      generationNumber: session.generationNumber,
      totalSteps: session.totalSteps,
      generationStatus: TutorialGenerationStatus.notStarted,
      steps: resetSteps,
      createdAt: session.createdAt,
      updatedAt: session.updatedAt,
    );
    return session;
  }
}
