import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_generation_status.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_instruction.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_session.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_source_mode.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step_category.dart';
import 'package:facetune/features/step_by_step_tutorial/presentation/widgets/tutorial_step_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TutorialStep _step({
  required int number,
  required TutorialStepCategory category,
  required String title,
  bool withImages = true,
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
  generationStatus: TutorialStepGenerationStatus.completed,
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

Future<void> _pump(WidgetTester tester, TutorialSession session) async {
  // The viewer's content (comparison image + instruction card + controls)
  // exceeds the default test surface height, and ListView only builds
  // children within the viewport/cache extent — so widgets below the fold
  // would otherwise never be built at all, not just "off-screen".
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: TutorialStepViewer(session: session)),
    ),
  );
}

void main() {
  testWidgets('shows an empty state when the session has no steps', (
    tester,
  ) async {
    await _pump(tester, _session(steps: const []));

    expect(find.text('No steps yet'), findsOneWidget);
  });

  testWidgets(
    'renders the header with style, variation, and dynamic step count',
    (tester) async {
      await _pump(
        tester,
        _session(
          steps: [
            _step(
              number: 1,
              category: TutorialStepCategory.blush,
              title: 'Blush',
            ),
          ],
          totalSteps: 6,
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
      _session(
        steps: [
          _step(
            number: 1,
            category: TutorialStepCategory.blush,
            title: 'Blush',
          ),
        ],
      ),
    );

    expect(find.text('Placement'), findsOneWidget);
    expect(find.text('Result'), findsOneWidget);
    expect(find.text('Before'), findsNothing);
    expect(find.text('After'), findsNothing);
  });

  testWidgets('shows a per-step fallback when a step has no images yet', (
    tester,
  ) async {
    await _pump(
      tester,
      _session(
        steps: [
          _step(
            number: 1,
            category: TutorialStepCategory.blush,
            title: 'Blush',
            withImages: false,
          ),
        ],
      ),
    );

    expect(find.text('Step still generating'), findsOneWidget);
    expect(find.text('Placement'), findsNothing);
  });

  testWidgets('renders the written instruction fields', (tester) async {
    await _pump(
      tester,
      _session(
        steps: [
          _step(
            number: 1,
            category: TutorialStepCategory.blush,
            title: 'Blush',
          ),
        ],
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

  testWidgets('Previous is disabled on the first step, Next advances', (
    tester,
  ) async {
    await _pump(
      tester,
      _session(
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
