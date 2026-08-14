import 'dart:async';

import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_generation_status.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_instruction.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_placement_metadata.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_session.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_source_mode.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/errors/tutorial_failure.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/repositories/tutorial_repository.dart';
import 'package:facetune/features/step_by_step_tutorial/presentation/controllers/tutorial_session_controller.dart';
import 'package:facetune/features/step_by_step_tutorial/presentation/controllers/tutorial_session_state.dart';
import 'package:flutter_test/flutter_test.dart';

const analysisId = 'analysis-1';
const recommendationId = 'recommendation-1';

TutorialSession _session(TutorialGenerationStatus status) => TutorialSession(
  id: 'session-1',
  userId: 'user-1',
  sourceMode: TutorialSourceMode.standardRecommendation,
  sourceAnalysisId: analysisId,
  sourceRecommendationId: recommendationId,
  styleCode: 'soft_glam',
  generationNumber: 1,
  totalSteps: 8,
  generationStatus: status,
  steps: const [],
  createdAt: DateTime.utc(2026, 8, 14),
  updatedAt: DateTime.utc(2026, 8, 14),
);

Future<void> _load(TutorialSessionController controller) => controller.load(
  sourceMode: TutorialSourceMode.standardRecommendation,
  analysisId: analysisId,
  recommendationId: recommendationId,
  generationNumber: 1,
);

void main() {
  test(
    'loading a session that does not exist yet reports loaded/null',
    () async {
      final controller = TutorialSessionController(_FakeRepository());
      addTearDown(controller.dispose);

      await _load(controller);

      expect(controller.state.status, TutorialSessionStatus.loaded);
      expect(controller.state.session, isNull);
    },
  );

  test('an in-progress persisted session maps to generating', () async {
    final controller = TutorialSessionController(
      _FakeRepository(existing: _session(TutorialGenerationStatus.queued)),
    );
    addTearDown(controller.dispose);

    await _load(controller);

    expect(controller.state.status, TutorialSessionStatus.generating);
    expect(controller.state.session, isNotNull);
  });

  test(
    'a partially complete persisted session maps to partiallyComplete',
    () async {
      final controller = TutorialSessionController(
        _FakeRepository(
          existing: _session(TutorialGenerationStatus.partiallyComplete),
        ),
      );
      addTearDown(controller.dispose);

      await _load(controller);

      expect(controller.state.status, TutorialSessionStatus.partiallyComplete);
    },
  );

  test('a completed persisted session maps to loaded', () async {
    final controller = TutorialSessionController(
      _FakeRepository(existing: _session(TutorialGenerationStatus.completed)),
    );
    addTearDown(controller.dispose);

    await _load(controller);

    expect(controller.state.status, TutorialSessionStatus.loaded);
    expect(controller.state.session, isNotNull);
  });

  test('a failed repository call surfaces a retryable failure', () async {
    final controller = TutorialSessionController(
      _FakeRepository(
        failure: const TutorialFailure(
          TutorialFailureType.network,
          'Check your connection and try again.',
          retryable: true,
        ),
      ),
    );
    addTearDown(controller.dispose);

    await _load(controller);

    expect(controller.state.status, TutorialSessionStatus.failed);
    expect(controller.state.retryable, isTrue);
    expect(controller.state.sessionExpired, isFalse);
  });

  test('an authentication failure is flagged as session expired', () async {
    final controller = TutorialSessionController(
      _FakeRepository(
        failure: const TutorialFailure(
          TutorialFailureType.authentication,
          'Your session expired. Sign in again.',
        ),
      ),
    );
    addTearDown(controller.dispose);

    await _load(controller);

    expect(controller.state.sessionExpired, isTrue);
  });

  test('retry repeats the most recent lookup', () async {
    final repository = _FakeRepository();
    final controller = TutorialSessionController(repository);
    addTearDown(controller.dispose);

    await _load(controller);
    await controller.retry();

    expect(repository.loadCalls, 2);
  });

  test('retry before any load is a no-op', () async {
    final repository = _FakeRepository();
    final controller = TutorialSessionController(repository);
    addTearDown(controller.dispose);

    await controller.retry();

    expect(repository.loadCalls, 0);
    expect(controller.state.status, TutorialSessionStatus.initial);
  });

  test('a stale call resolving before the current one does not win', () async {
    final repository = _BlockingRepository();
    final controller = TutorialSessionController(repository);
    addTearDown(controller.dispose);

    final first = _load(controller);
    final second = _load(controller);
    // Resolve the stale (first) call's result first — it must be
    // discarded even though it settles before the current call does.
    repository.completeOldest(_session(TutorialGenerationStatus.failed));
    await Future<void>.delayed(Duration.zero);
    // Resolve the current (second) call's result — it must be the one
    // that ends up in state.
    repository.completeOldest(_session(TutorialGenerationStatus.completed));
    await Future.wait([first, second]);

    expect(controller.state.status, TutorialSessionStatus.loaded);
  });

  test('clear discards a load that completes afterward', () async {
    final repository = _BlockingRepository();
    final controller = TutorialSessionController(repository);
    addTearDown(controller.dispose);

    final operation = _load(controller);
    controller.clear();
    repository.completeOldest(_session(TutorialGenerationStatus.completed));
    await operation;

    expect(controller.state.status, TutorialSessionStatus.initial);
    expect(controller.state.session, isNull);
  });
}

class _FakeRepository implements TutorialRepository {
  _FakeRepository({this.existing, this.failure});

  final TutorialSession? existing;
  final TutorialFailure? failure;
  int loadCalls = 0;

  @override
  Future<TutorialSession?> loadExisting({
    required TutorialSourceMode sourceMode,
    required String analysisId,
    String? recommendationId,
    String? kitRecommendationId,
    required int generationNumber,
  }) async {
    loadCalls++;
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
}

class _BlockingRepository implements TutorialRepository {
  final List<Completer<TutorialSession?>> _pending = [];

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
}
