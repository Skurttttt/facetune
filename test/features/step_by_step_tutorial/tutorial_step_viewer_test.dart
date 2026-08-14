import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_generation_status.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_instruction.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/personalized_tutorial.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_placement_metadata.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_session.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_source_mode.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step_category.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/repositories/tutorial_repository.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/usecases/get_or_create_tutorial_session.dart';
import 'package:facetune/features/step_by_step_tutorial/presentation/controllers/tutorial_session_controller.dart';
import 'package:facetune/features/step_by_step_tutorial/presentation/controllers/tutorial_session_state.dart';
import 'package:facetune/features/step_by_step_tutorial/presentation/widgets/tutorial_step_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

TutorialStep _step({
  required int number,
  TutorialStepCategory category = TutorialStepCategory.blush,
  String title = 'Blush',
  bool withImages = true,
  TutorialStepGenerationStatus status = TutorialStepGenerationStatus.completed,
}) => TutorialStep(
  id: 'step-$number',
  tutorialSessionId: 'session-1',
  stepNumber: number,
  category: category,
  title: title,
  instruction: TutorialInstruction(
    category: category,
    placement: 'Upper cheekbones',
    intensity: 'light',
    technique: 'Blend upward toward temples.',
    colorName: 'Peach Rose',
    hex: '#E58C87',
    finish: 'satin',
    direction: 'Toward the temples',
    tip: 'Smile to find the apple of your cheek.',
  ),
  generationStatus: status,
  placementImageUrl: withImages
      ? 'https://signed.example/placement-$number'
      : null,
  resultImageUrl: withImages ? 'https://signed.example/result-$number' : null,
  createdAt: DateTime.utc(2026, 8, 14),
  updatedAt: DateTime.utc(2026, 8, 14),
);

TutorialSession _session({
  required List<TutorialStep> steps,
  int totalSteps = 8,
}) => TutorialSession(
  id: 'session-1',
  userId: 'user-1',
  sourceMode: TutorialSourceMode.standardRecommendation,
  sourceAnalysisId: 'analysis-1',
  sourceRecommendationId: 'recommendation-1',
  styleCode: 'soft_glam',
  generationNumber: 2,
  totalSteps: totalSteps,
  generationStatus: TutorialGenerationStatus.completed,
  steps: steps,
  createdAt: DateTime.utc(2026, 8, 14),
  updatedAt: DateTime.utc(2026, 8, 14),
);

Future<void> _pump(
  WidgetTester tester,
  TutorialSessionState state, {
  TutorialRepository? repository,
}) async {
  // The viewer's content (comparison image + instruction card + controls)
  // exceeds the default test surface height, and ListView only builds
  // children within the viewport/cache extent — so widgets below the fold
  // would otherwise never be built at all, not just "off-screen".
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repo = repository ?? _NoopRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tutorialSessionControllerProvider.overrideWith(
          (ref) =>
              TutorialSessionController(repo, GetOrCreateTutorialSession(repo))
                ..state = state,
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TutorialStepViewer(
              state: ref.watch(tutorialSessionControllerProvider),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows an empty state when the session has no steps', (
    tester,
  ) async {
    await _pump(
      tester,
      TutorialSessionState(session: _session(steps: const [])),
    );

    expect(find.text('No steps yet'), findsOneWidget);
  });

  testWidgets(
    'renders the header with style, variation, and dynamic step count',
    (tester) async {
      await _pump(
        tester,
        TutorialSessionState(
          session: _session(
            steps: [
              _step(
                number: 1,
                category: TutorialStepCategory.blush,
                title: 'Blush',
              ),
            ],
            totalSteps: 6,
          ),
        ),
      );

      expect(find.text('How to Apply This Look'), findsOneWidget);
      expect(find.text('Soft Glam · Variation 2'), findsOneWidget);
      expect(find.textContaining('STEP 1 OF 6'), findsOneWidget);
      expect(find.textContaining('BLUSH'), findsOneWidget);
    },
  );

  testWidgets('shows the Placement/Result slider labels, not Before/After', (
    tester,
  ) async {
    await _pump(
      tester,
      TutorialSessionState(
        session: _session(
          steps: [
            _step(
              number: 1,
              category: TutorialStepCategory.blush,
              title: 'Blush',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Placement'), findsOneWidget);
    expect(find.text('Result'), findsOneWidget);
    expect(find.text('Before'), findsNothing);
    expect(find.text('After'), findsNothing);
  });

  testWidgets('the next ungenerated step offers an explicit generate action', (
    tester,
  ) async {
    await _pump(
      tester,
      TutorialSessionState(
        session: _session(
          steps: [
            _step(
              number: 1,
              withImages: false,
              status: TutorialStepGenerationStatus.notStarted,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Ready to generate'), findsOneWidget);
    expect(find.text('Generate this step'), findsOneWidget);
    expect(find.text('Placement'), findsNothing);
  });

  testWidgets(
    'a step beyond the next-to-generate one shows a not-yet-available state',
    (tester) async {
      await _pump(
        tester,
        TutorialSessionState(
          session: _session(
            steps: [
              _step(number: 1),
              _step(
                number: 2,
                withImages: false,
                status: TutorialStepGenerationStatus.notStarted,
              ),
              _step(
                number: 3,
                withImages: false,
                status: TutorialStepGenerationStatus.notStarted,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Next Step'));
      await tester.pump();
      expect(find.text('Ready to generate'), findsOneWidget);

      await tester.tap(find.text('Next Step'));
      await tester.pump();
      expect(find.text('Not yet available'), findsOneWidget);
      expect(find.text('Generate this step'), findsNothing);
    },
  );

  testWidgets('shows a loading state while the current step is generating', (
    tester,
  ) async {
    await _pump(
      tester,
      TutorialSessionState(
        session: _session(
          steps: [
            _step(
              number: 1,
              withImages: false,
              status: TutorialStepGenerationStatus.generating,
            ),
          ],
        ),
        generatingStepId: 'step-1',
      ),
    );

    expect(find.text('Generating this step…'), findsOneWidget);
  });

  testWidgets('shows a fresh per-step failure with its message', (
    tester,
  ) async {
    await _pump(
      tester,
      TutorialSessionState(
        session: _session(
          steps: [
            _step(
              number: 1,
              withImages: false,
              status: TutorialStepGenerationStatus.failed,
            ),
          ],
        ),
        stepFailureStepId: 'step-1',
        stepFailureMessage: 'The image service did not return a usable image.',
        stepFailureRetryable: true,
      ),
    );

    expect(find.text('This step could not be generated'), findsOneWidget);
    expect(
      find.text('The image service did not return a usable image.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets(
    'shows a persisted failure from an earlier session even without a fresh message',
    (tester) async {
      await _pump(
        tester,
        TutorialSessionState(
          session: _session(
            steps: [
              _step(
                number: 1,
                withImages: false,
                status: TutorialStepGenerationStatus.failed,
              ),
            ],
          ),
        ),
      );

      expect(find.text('This step could not be generated'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    },
  );

  testWidgets(
    'a non-retryable fresh failure offers no futile Try again button',
    (tester) async {
      await _pump(
        tester,
        TutorialSessionState(
          session: _session(
            steps: [
              _step(
                number: 1,
                withImages: false,
                status: TutorialStepGenerationStatus.failed,
              ),
            ],
          ),
          stepFailureStepId: 'step-1',
          stepFailureMessage: 'This look no longer exists.',
          stepFailureRetryable: false,
        ),
      );

      expect(find.text('This step could not be generated'), findsOneWidget);
      expect(find.text('This look no longer exists.'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    },
  );

  testWidgets(
    'tapping Generate this step calls through to the controller and renders the result',
    (tester) async {
      final repository = _GeneratingRepository();
      await _pump(
        tester,
        TutorialSessionState(
          session: _session(
            steps: [
              _step(
                number: 1,
                withImages: false,
                status: TutorialStepGenerationStatus.notStarted,
              ),
            ],
          ),
        ),
        repository: repository,
      );

      expect(find.text('Generate this step'), findsOneWidget);
      await tester.tap(find.text('Generate this step'));
      // The fake repository resolves without an artificial delay, so the
      // transient "Generating this step…" frame is not reliably
      // observable here — that rendering path is covered directly by
      // "shows a loading state while the current step is generating".
      await tester.pumpAndSettle();

      expect(find.text('Placement'), findsOneWidget);
      expect(find.text('Result'), findsOneWidget);
      expect(repository.generateCalls, 1);
    },
  );

  testWidgets('renders the written instruction fields', (tester) async {
    await _pump(
      tester,
      TutorialSessionState(
        session: _session(
          steps: [
            _step(
              number: 1,
              category: TutorialStepCategory.blush,
              title: 'Blush',
            ),
          ],
        ),
      ),
    );

    expect(find.textContaining('Peach Rose · #E58C87'), findsOneWidget);
    expect(find.textContaining('satin'), findsOneWidget);
    expect(find.textContaining('Upper cheekbones'), findsOneWidget);
    expect(find.textContaining('Toward the temples'), findsOneWidget);
    expect(find.textContaining('light'), findsOneWidget);
    expect(find.textContaining('Blend upward toward temples.'), findsOneWidget);
    expect(
      find.textContaining('Smile to find the apple of your cheek.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'renders a stored Result when step 1 placement falls back to the original selfie',
    (tester) async {
      final step = _step(number: 1);
      final missingPersistedPlacement = TutorialStep(
        id: step.id,
        tutorialSessionId: step.tutorialSessionId,
        stepNumber: step.stepNumber,
        category: step.category,
        title: step.title,
        instruction: step.instruction,
        placementMetadata: step.placementMetadata,
        placementImagePath: null,
        placementImageUrl: null,
        resultImagePath: step.resultImagePath,
        resultImageUrl: step.resultImageUrl,
        modelId: step.modelId,
        imageSize: step.imageSize,
        promptVersion: step.promptVersion,
        generationStatus: step.generationStatus,
        createdAt: step.createdAt,
        updatedAt: step.updatedAt,
      );
      await _pump(
        tester,
        TutorialSessionState(
          session: _session(steps: [missingPersistedPlacement]),
          originalImageUrl: 'https://signed.example/original',
        ),
      );

      expect(find.text('Placement'), findsOneWidget);
      expect(find.text('Result'), findsOneWidget);
      expect(find.text('Not yet available'), findsNothing);
    },
  );

  testWidgets('Previous is disabled on the first step, Next advances', (
    tester,
  ) async {
    await _pump(
      tester,
      TutorialSessionState(
        session: _session(
          steps: [
            _step(
              number: 1,
              category: TutorialStepCategory.foundation,
              title: 'Foundation',
            ),
            _step(
              number: 2,
              category: TutorialStepCategory.blush,
              title: 'Blush',
            ),
          ],
        ),
      ),
    );

    expect(find.textContaining('STEP 1 OF'), findsOneWidget);
    // Previous is disabled on the first step: tapping it must not throw and
    // must not move the step index (there is no earlier step to show).
    await tester.tap(find.text('Previous'), warnIfMissed: false);
    await tester.pump();
    expect(find.textContaining('STEP 1 OF'), findsOneWidget);

    await tester.tap(find.text('Next Step'));
    await tester.pump();

    expect(find.textContaining('STEP 2 OF'), findsOneWidget);
    expect(find.textContaining('BLUSH'), findsOneWidget);

    // Next is disabled on the last step: tapping it must not advance past
    // the final available step.
    await tester.tap(find.text('Next Step'), warnIfMissed: false);
    await tester.pump();
    expect(find.textContaining('STEP 2 OF'), findsOneWidget);
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

/// Backs the end-to-end "tap Generate this step" test: [generateStepResult]
/// resolves immediately with a fully-imaged copy of step 1.
class _GeneratingRepository extends _NoopRepository {
  int generateCalls = 0;

  @override
  Future<TutorialStep> generateStepResult({
    required String tutorialStepId,
  }) async {
    generateCalls++;
    return _step(number: 1);
  }
}
