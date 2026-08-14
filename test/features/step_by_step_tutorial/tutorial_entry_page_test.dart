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
import 'package:facetune/features/step_by_step_tutorial/presentation/pages/tutorial_entry_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpWithState(
  WidgetTester tester,
  TutorialSessionState fixedState, {
  TutorialRepository? repository,
}) async {
  final repo = repository ?? _NoopRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tutorialSessionControllerProvider.overrideWith(
          (ref) =>
              TutorialSessionController(repo, GetOrCreateTutorialSession(repo))
                ..state = fixedState,
        ),
      ],
      child: const MaterialApp(home: TutorialEntryPage()),
    ),
  );
}

TutorialSession _session(
  TutorialGenerationStatus status, {
  List<TutorialStep> steps = const [],
}) => TutorialSession(
  id: 'session-1',
  userId: 'user-1',
  sourceMode: TutorialSourceMode.standardRecommendation,
  sourceAnalysisId: 'analysis-1',
  sourceRecommendationId: 'recommendation-1',
  styleCode: 'soft_glam',
  generationNumber: 1,
  totalSteps: 8,
  generationStatus: status,
  steps: steps,
  createdAt: DateTime.utc(2026, 8, 14),
  updatedAt: DateTime.utc(2026, 8, 14),
);

TutorialStep _step(int number) => TutorialStep(
  id: 'step-$number',
  tutorialSessionId: 'session-1',
  stepNumber: number,
  category: TutorialStepCategory.blush,
  title: 'Blush',
  instruction: const TutorialInstruction(
    category: TutorialStepCategory.blush,
    placement: 'Upper cheekbones',
    intensity: 'light',
    technique: 'Blend upward toward temples.',
  ),
  generationStatus: TutorialStepGenerationStatus.completed,
  placementImageUrl: 'https://signed.example/placement-$number',
  resultImageUrl: 'https://signed.example/result-$number',
  createdAt: DateTime.utc(2026, 8, 14),
  updatedAt: DateTime.utc(2026, 8, 14),
);

void main() {
  testWidgets('initial status shows an unidentified-tutorial message', (
    tester,
  ) async {
    await _pumpWithState(tester, const TutorialSessionState());

    expect(find.text('Tutorial unavailable'), findsOneWidget);
    expect(find.text('Return'), findsOneWidget);
  });

  testWidgets('loading status shows a loading indicator', (tester) async {
    await _pumpWithState(
      tester,
      const TutorialSessionState(status: TutorialSessionStatus.loading),
    );

    expect(find.text('Preparing your tutorial…'), findsOneWidget);
  });

  testWidgets(
    'loaded with no session offers an explicit generate action, not a claim it already works',
    (tester) async {
      await _pumpWithState(
        tester,
        const TutorialSessionState(status: TutorialSessionStatus.loaded),
      );

      expect(find.text('Ready to build your tutorial'), findsOneWidget);
      expect(find.text('Generate my tutorial'), findsOneWidget);
    },
  );

  testWidgets(
    'loaded with a session but no steps shows an honest empty state',
    (tester) async {
      await _pumpWithState(
        tester,
        TutorialSessionState(
          status: TutorialSessionStatus.loaded,
          session: _session(TutorialGenerationStatus.completed),
        ),
      );

      expect(find.text('No steps yet'), findsOneWidget);
    },
  );

  testWidgets('loaded with steps opens the tutorial step viewer', (
    tester,
  ) async {
    await _pumpWithState(
      tester,
      TutorialSessionState(
        status: TutorialSessionStatus.loaded,
        session: _session(
          TutorialGenerationStatus.completed,
          steps: [_step(1)],
        ),
      ),
    );

    expect(find.textContaining('STEP 1 OF'), findsOneWidget);
  });

  testWidgets(
    'a generating session with some steps ready still opens the viewer',
    (tester) async {
      await _pumpWithState(
        tester,
        TutorialSessionState(
          status: TutorialSessionStatus.generating,
          session: _session(
            TutorialGenerationStatus.generating,
            steps: [_step(1)],
          ),
        ),
      );

      expect(find.textContaining('STEP 1 OF'), findsOneWidget);
    },
  );

  testWidgets('generating status offers a check-again action', (tester) async {
    await _pumpWithState(
      tester,
      const TutorialSessionState(status: TutorialSessionStatus.generating),
    );

    expect(find.text('Tutorial in progress'), findsOneWidget);
    expect(find.text('Check again'), findsOneWidget);
  });

  testWidgets('a retryable failure offers a try-again action', (tester) async {
    await _pumpWithState(
      tester,
      const TutorialSessionState(
        status: TutorialSessionStatus.failed,
        message: 'Check your connection and try again.',
        retryable: true,
      ),
    );

    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('an expired session offers a sign-in action', (tester) async {
    await _pumpWithState(
      tester,
      const TutorialSessionState(
        status: TutorialSessionStatus.failed,
        message: 'Your session expired. Sign in again.',
        failureType: TutorialFailureType.authentication,
      ),
    );

    expect(find.text('Sign in again'), findsOneWidget);
  });

  group('regenerate (ST-12)', () {
    testWidgets('a session with steps shows a regenerate action', (
      tester,
    ) async {
      await _pumpWithState(
        tester,
        TutorialSessionState(
          status: TutorialSessionStatus.loaded,
          session: _session(
            TutorialGenerationStatus.completed,
            steps: [_step(1)],
          ),
        ),
      );

      expect(find.byTooltip('Regenerate tutorial'), findsOneWidget);
    });

    testWidgets('loaded with no session shows no regenerate action', (
      tester,
    ) async {
      await _pumpWithState(
        tester,
        const TutorialSessionState(status: TutorialSessionStatus.loaded),
      );

      expect(find.byTooltip('Regenerate tutorial'), findsNothing);
    });

    testWidgets('cancelling the confirmation leaves the tutorial untouched', (
      tester,
    ) async {
      final repository = _RegeneratingRepository();
      await _pumpWithState(
        tester,
        TutorialSessionState(
          status: TutorialSessionStatus.loaded,
          session: _session(
            TutorialGenerationStatus.completed,
            steps: [_step(1)],
          ),
        ),
        repository: repository,
      );

      await tester.tap(find.byTooltip('Regenerate tutorial'));
      await tester.pumpAndSettle();
      expect(find.text('Regenerate this tutorial?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repository.resetCalls, 0);
      expect(find.textContaining('STEP 1 OF'), findsOneWidget);
    });

    testWidgets(
      'confirming the dialog calls through and the viewer reflects the reset',
      (tester) async {
        final repository = _RegeneratingRepository();
        await _pumpWithState(
          tester,
          TutorialSessionState(
            status: TutorialSessionStatus.loaded,
            session: _session(
              TutorialGenerationStatus.completed,
              steps: [_step(1)],
            ),
          ),
          repository: repository,
        );

        await tester.tap(find.byTooltip('Regenerate tutorial'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Regenerate'));
        await tester.pumpAndSettle();

        expect(repository.resetCalls, 1);
        expect(find.text('Ready to generate'), findsOneWidget);
      },
    );
  });
}

class _NoopRepository implements TutorialRepository {
  @override
  Future<TutorialSession?> loadExisting({
    required TutorialSourceMode sourceMode,
    required String analysisId,
    String? recommendationId,
    String? kitRecommendationId,
    required int generationNumber,
  }) => throw UnimplementedError();

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

/// Backs the "regenerate" widget tests: [resetForRegeneration] resolves
/// with a session whose one step has been cleared back to `notStarted`,
/// mirroring what `SupabaseTutorialRepository.resetForRegeneration`
/// actually returns.
class _RegeneratingRepository extends _NoopRepository {
  int resetCalls = 0;

  @override
  Future<TutorialSession> resetForRegeneration({
    required String tutorialSessionId,
  }) async {
    resetCalls++;
    return _session(
      TutorialGenerationStatus.notStarted,
      steps: [
        TutorialStep(
          id: 'step-1',
          tutorialSessionId: 'session-1',
          stepNumber: 1,
          category: TutorialStepCategory.blush,
          title: 'Blush',
          instruction: const TutorialInstruction(
            category: TutorialStepCategory.blush,
            placement: 'Upper cheekbones',
            intensity: 'light',
            technique: 'Blend upward toward temples.',
          ),
          generationStatus: TutorialStepGenerationStatus.notStarted,
          createdAt: DateTime.utc(2026, 8, 14),
          updatedAt: DateTime.utc(2026, 8, 14),
        ),
      ],
    );
  }
}
