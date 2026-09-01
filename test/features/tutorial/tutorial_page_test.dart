import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/tutorial/data/providers/tutorial_providers.dart';
import 'package:facetune/features/tutorial/domain/catalog/look_plan_convergence.dart';
import 'package:facetune/features/tutorial/domain/entities/canonical_preview_ref.dart';
import 'package:facetune/features/tutorial/domain/entities/recommendation_source_mode.dart';
import 'package:facetune/features/tutorial/domain/entities/standard_look_entry.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_manifest.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_session.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_step.dart';
import 'package:facetune/features/tutorial/domain/repositories/look_plan_repository.dart';
import 'package:facetune/features/tutorial/domain/repositories/tutorial_manifest_repository.dart';
import 'package:facetune/features/tutorial/domain/repositories/tutorial_session_repository.dart';
import 'package:facetune/features/tutorial/domain/repositories/tutorial_step_repository.dart';
import 'package:facetune/features/tutorial/domain/entities/validated_look_plan.dart';
import 'package:facetune/features/tutorial/presentation/pages/tutorial_page.dart';
import 'package:facetune/features/tutorial/presentation/utils/tutorial_image_focus.dart';
import 'package:facetune/features/tutorial/presentation/utils/tutorial_labels.dart';
import 'package:facetune/features/tutorial/presentation/widgets/tutorial_final_look_card.dart';
import 'package:facetune/features/tutorial/presentation/widgets/tutorial_image_viewer.dart';
import 'package:facetune/features/tutorial/presentation/widgets/tutorial_product_cards.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 8, 30);

MakeupRecommendationItem _item(
  String name,
  String hex, {
  String placement = 'Across the cheeks and temples.',
  String technique = 'Blend upward and outward.',
  String finish = 'satin',
  String intensity = 'soft',
  String reasoning = 'Suits the undertone.',
}) => MakeupRecommendationItem(
  name: name,
  hex: hex,
  placement: placement,
  technique: technique,
  finish: finish,
  intensity: intensity,
  reasoning: reasoning,
);

ValidatedLookPlan _standardPlan({
  String blushName = 'Warm peach',
  String blushReasoning = 'Suits the undertone.',
}) => LookPlanConvergence.fromStandard(
  MakeupRecommendation(
    id: 'rec-1',
    analysisId: 'analysis-1',
    styleCode: 'soft_glam',
    overallIntensity: 'soft',
    items: <String, MakeupRecommendationItem>{
      'foundation': _item('Warm beige', '#E3C4A8'),
      'blush': _item(blushName, '#E8A08C', reasoning: blushReasoning),
      'lipstick': _item('Rosewood', '#B86F72'),
      'lipGloss': _item('Clear shine', '#D8A0A2'),
    },
    modelId: 'm',
    promptVersion: 'v1',
    createdAt: _now,
  ),
);

ValidatedLookPlan _kitPlan() => LookPlanConvergence.fromMyMakeupKit(
  KitMakeupRecommendation(
    id: 'kit-rec-1',
    analysisId: 'analysis-1',
    styleCode: 'soft_glam',
    selections: const <KitMakeupSelection>[],
    productSnapshots: const <KitProductSnapshot>[
      KitProductSnapshot(
        productId: 'p1',
        category: 'foundation',
        colorHex: '#E3C4A8',
        finish: 'natural',
        productName: 'Studio Base',
        colorLabel: 'Warm Sand',
        foundationDepth: 'light',
        foundationUndertone: 'warm',
      ),
      KitProductSnapshot(
        productId: 'p2',
        category: 'lipstick',
        colorHex: '#B86F72',
        finish: 'cream',
        productName: 'Everyday Nude',
      ),
      KitProductSnapshot(
        productId: 'p3',
        category: 'lip_gloss',
        colorHex: '#D8A0A2',
        finish: 'glossy',
        // Deliberately unnamed: the card must not invent a name.
      ),
    ],
    overallIntensity: 'soft',
    summary: 'Owned products.',
    modelId: 'm',
    promptVersion: 'v1',
    createdAt: _now,
  ),
);

ValidatedLookPlan _standardPlanWithOnlyShade() => ValidatedLookPlan(
  id: 'rec-minimal',
  analysisId: 'analysis-1',
  styleCode: 'natural',
  source: StandardLookPlanSource(
    recommendationId: 'rec-minimal',
    entries: StandardLookEntries(
      byCategory: <TutorialCategory, List<StandardLookEntry>>{
        TutorialCategory.blush: const <StandardLookEntry>[
          StandardLookEntry(
            planKey: 'blush',
            shadeName: 'Muted rose',
            placement: '',
            technique: '',
            finish: '',
            intensity: '',
          ),
        ],
      },
    ),
  ),
  modelId: 'm',
  promptVersion: 'v1',
  createdAt: _now,
);

TutorialStep _step(
  TutorialCategory category,
  int position, {
  TutorialStepStatus status = TutorialStepStatus.ready,
}) => TutorialStep(
  id: 'step-${category.code}',
  sessionId: 'session-1',
  category: category,
  position: position,
  status: status,
  guidelineStoragePath: status == TutorialStepStatus.ready
      ? 'user-1/analyses/a/tutorials/session-1/${category.code}_0001.png'
      : null,
  productSnapshotItems: const [],
  createdAt: _now,
  updatedAt: _now,
);

TutorialSession _session({
  required List<TutorialCategory> present,
  required ValidatedLookPlan plan,
  List<TutorialStep> steps = const <TutorialStep>[],
}) {
  final mode = plan.sourceMode;
  return TutorialSession(
    id: 'session-1',
    userId: 'user-1',
    analysisId: 'analysis-1',
    canonicalPreviewId: 'preview-1',
    lookPlan: plan,
    status: TutorialSessionStatus.ready,
    manifest: TutorialManifest(
      canonicalPreviewId: 'preview-1',
      sourceMode: mode,
      status: TutorialManifestStatus.accepted,
      items: <TutorialManifestItem>[
        for (final category in TutorialCategory.values)
          TutorialManifestItem(
            category: category,
            presence: present.contains(category)
                ? TutorialCategoryPresence.present
                : TutorialCategoryPresence.absent,
            productBacked:
                mode == RecommendationSourceMode.myMakeupKit &&
                present.contains(category),
          ),
      ],
      modelId: 'm',
      promptVersion: 'v1',
      schemaVersion: 'v1',
      createdAt: _now,
    ),
    steps: steps,
    createdAt: _now,
    updatedAt: _now,
  );
}

class _Manifests implements TutorialManifestRepository {
  _Manifests(this.session);
  final TutorialSession session;

  @override
  Future<TutorialSession?> loadAccepted(CanonicalPreviewRef preview) async =>
      session;

  @override
  Future<TutorialSession> analyze(CanonicalPreviewRef preview) async => session;
}

class _Sessions implements TutorialSessionRepository {
  _Sessions(this.session);
  final TutorialSession session;

  @override
  Future<TutorialSession?> loadForCanonicalPreview(
    CanonicalPreviewRef preview,
  ) async => session;

  @override
  Future<TutorialSession> loadById(String sessionId) async => session;

  @override
  Future<TutorialSession> ensureSteps(TutorialSession value) async => value;

  @override
  Future<void> delete(String sessionId) async {}
}

class _Plans implements LookPlanRepository {
  _Plans(this.plan);
  final ValidatedLookPlan plan;

  @override
  Future<ValidatedLookPlan> loadForCanonicalPreview(
    CanonicalPreviewRef preview,
  ) async => plan;
}

class _Steps implements TutorialStepRepository {
  _Steps({this.failEverything = false});

  bool failEverything;
  int generateCalls = 0;
  int signCalls = 0;

  @override
  Future<List<TutorialStep>> loadForSession(String sessionId) async =>
      const <TutorialStep>[];

  @override
  Future<TutorialStep> generate({
    required String sessionId,
    required TutorialCategory category,
  }) async {
    generateCalls += 1;
    if (failEverything) {
      throw StateError('generation failed');
    }
    return _step(category, 1);
  }

  @override
  Future<String> resolveGuidelineUrl(TutorialStep step) async {
    signCalls += 1;
    return 'https://example.invalid/${step.id}.png';
  }
}

Future<_Steps> _pump(
  WidgetTester tester, {
  required List<TutorialCategory> present,
  required ValidatedLookPlan plan,
  List<TutorialStep> steps = const <TutorialStep>[],
  String? finalPreviewUrl,
  _Steps? stepRepository,
  ThemeMode themeMode = ThemeMode.light,
  Brightness systemBrightness = Brightness.light,
  Size size = const Size(1200, 4000),
  double textScale = 1,
}) async {
  // A tall surface so the whole step fits: the page is a lazily-built ListView,
  // and an off-screen product card is simply not in the tree to find.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.platformBrightnessTestValue = systemBrightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  final session = _session(present: present, plan: plan, steps: steps);
  final stepRepo = stepRepository ?? _Steps();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tutorialManifestRepositoryProvider.overrideWithValue(
          _Manifests(session),
        ),
        tutorialSessionRepositoryProvider.overrideWithValue(_Sessions(session)),
        lookPlanRepositoryProvider.overrideWithValue(_Plans(plan)),
        tutorialStepRepositoryProvider.overrideWithValue(stepRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: TutorialPage(
          preview: plan.sourceMode == RecommendationSourceMode.standard
              ? const CanonicalPreviewRef.standard('preview-1')
              : const CanonicalPreviewRef.myMakeupKit('preview-1'),
          finalPreviewUrl: finalPreviewUrl,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return stepRepo;
}

void main() {
  group('variable-length tutorials', () {
    testWidgets('a 5-step tutorial reports Step 1 of 5', (tester) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[
          TutorialCategory.foundation,
          TutorialCategory.concealer,
          TutorialCategory.blush,
          TutorialCategory.eyeliner,
          TutorialCategory.lips,
        ],
        plan: _standardPlan(),
      );

      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(find.text('Foundation'), findsOneWidget);
    });

    testWidgets('a 9-step tutorial reports Step 1 of 9', (tester) async {
      await _pump(
        tester,
        present: TutorialCategory.values,
        plan: _standardPlan(),
      );

      expect(find.text('Step 1 of 9'), findsOneWidget);
    });

    testWidgets('a 2-step tutorial reports Step 1 of 2', (tester) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[
          TutorialCategory.blush,
          TutorialCategory.lips,
        ],
        plan: _standardPlan(),
      );

      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(find.text('Blush'), findsOneWidget);
    });

    testWidgets('excluded categories are never shown', (tester) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.blush],
        plan: _standardPlan(),
      );

      expect(find.text('Blush'), findsOneWidget);
      expect(find.text('Eyeliner'), findsNothing);
      expect(find.text('Highlighter'), findsNothing);
      expect(find.text('Step 1 of 1'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('next and previous move through the steps', (tester) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[
          TutorialCategory.foundation,
          TutorialCategory.blush,
          TutorialCategory.lips,
        ],
        plan: _standardPlan(),
      );

      expect(find.text('Step 1 of 3'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 3'), findsOneWidget);
      expect(find.text('Blush'), findsOneWidget);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 3'), findsOneWidget);
    });

    testWidgets('the last step shows Finish instead of Next', (tester) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[
          TutorialCategory.blush,
          TutorialCategory.lips,
        ],
        plan: _standardPlan(),
      );

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 2'), findsOneWidget);
      expect(find.text('Finish'), findsWidgets);
      expect(find.text('Next'), findsNothing);
    });
  });

  group('ready steps are reused, never regenerated', () {
    testWidgets('opening with a ready step generates nothing', (tester) async {
      final steps = await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.blush],
        plan: _standardPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
      );

      expect(steps.generateCalls, 0);
      expect(steps.signCalls, greaterThan(0));
    });

    testWidgets('navigating back to a ready step does not regenerate', (
      tester,
    ) async {
      final steps = await _pump(
        tester,
        present: const <TutorialCategory>[
          TutorialCategory.blush,
          TutorialCategory.lips,
        ],
        plan: _standardPlan(),
        steps: <TutorialStep>[
          _step(TutorialCategory.blush, 1),
          _step(TutorialCategory.lips, 2),
        ],
      );

      // Both steps are already drawn, so reopening resumes on the last one.
      expect(find.text('Step 2 of 2'), findsOneWidget);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(steps.generateCalls, 0);
    });
  });

  group('Standard Mode product card', () {
    testWidgets('shows brand-neutral shades and instructions', (tester) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.blush],
        plan: _standardPlan(),
      );

      expect(find.text('Suggested shades'), findsOneWidget);
      expect(find.text(TutorialLabels.yourGoal), findsOneWidget);
      expect(find.text(TutorialLabels.shade), findsOneWidget);
      expect(find.text(TutorialLabels.hex), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StandardProductCard),
          matching: find.text(TutorialLabels.finish),
        ),
        findsOneWidget,
      );
      expect(find.text(TutorialLabels.intensity), findsOneWidget);
      expect(find.text('Warm peach'), findsOneWidget);
      expect(find.text('#E8A08C'), findsOneWidget);
      expect(find.text('Where to apply'), findsOneWidget);
      expect(find.text('How to apply'), findsOneWidget);
      expect(find.text('From your kit'), findsNothing);
    });

    testWidgets('Lips shows both plan entries', (tester) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.lips],
        plan: _standardPlan(),
      );

      expect(find.text('Rosewood'), findsOneWidget);
      expect(find.text('Clear shine'), findsOneWidget);
    });
  });

  group('My Makeup Kit product card', () {
    testWidgets('shows the exact stored product details', (tester) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.foundation],
        plan: _kitPlan(),
      );

      expect(find.text('From your kit'), findsOneWidget);
      expect(find.text('Studio Base'), findsOneWidget);
      expect(find.text('#E3C4A8'), findsOneWidget);
      expect(find.text('Warm Sand'), findsOneWidget);
      expect(find.text(TutorialLabels.shade), findsOneWidget);
      expect(find.text(TutorialLabels.hex), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MyMakeupKitProductCard),
          matching: find.text(TutorialLabels.finish),
        ),
        findsOneWidget,
      );
      expect(find.text(TutorialLabels.intensity), findsNothing);
      expect(find.text(TutorialLabels.yourGoal), findsNothing);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Warm'), findsOneWidget);
      expect(find.text('Suggested shades'), findsNothing);
    });

    testWidgets('a Lips step shows both owned products', (tester) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.lips],
        plan: _kitPlan(),
      );

      expect(find.text('From your kit (2 products)'), findsOneWidget);
      expect(find.text('Everyday Nude'), findsOneWidget);
      // The unnamed gloss falls back to its category, never an invented name.
      expect(find.text('Lip gloss'), findsOneWidget);
      expect(find.text('#B86F72'), findsOneWidget);
      expect(find.text('#D8A0A2'), findsOneWidget);
    });

    testWidgets('foundation-only fields are hidden for other categories', (
      tester,
    ) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.lips],
        plan: _kitPlan(),
      );

      expect(find.text('Depth'), findsNothing);
      expect(find.text('Undertone'), findsNothing);
    });
  });

  group('loading, error, and retry', () {
    testWidgets('a failed generation offers a retry', (tester) async {
      final steps = await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.blush],
        plan: _standardPlan(),
        stepRepository: _Steps(failEverything: true),
      );

      expect(steps.generateCalls, greaterThan(0));
      expect(find.text('Try again'), findsWidgets);
    });

    testWidgets('a tutorial with no steps says so', (tester) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[],
        plan: _standardPlan(),
      );

      expect(find.text('No steps for this look'), findsOneWidget);
    });
  });

  group('final preview reuse', () {
    testWidgets('the last step shows the existing final look', (tester) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[
          TutorialCategory.blush,
          TutorialCategory.lips,
        ],
        plan: _standardPlan(),
        steps: <TutorialStep>[
          _step(TutorialCategory.blush, 1),
          _step(TutorialCategory.lips, 2),
        ],
        finalPreviewUrl: 'https://example.invalid/final.png',
      );

      // A completed tutorial resumes on its last step, so the final look is
      // shown straight away rather than after navigating forward.
      expect(find.text('Step 2 of 2'), findsOneWidget);
      expect(find.text('Your final look'), findsOneWidget);
    });

    // Until V4-QA-5 this asserted the opposite — that stepping back hid the
    // final look, because it was rendered on the last step alone. QA-5
    // supersedes that: the finished result is most useful while the user is
    // still mid-application, so it is now reachable from every step.
    testWidgets('every step can reach the final look', (tester) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[
          TutorialCategory.blush,
          TutorialCategory.lips,
        ],
        plan: _standardPlan(),
        steps: <TutorialStep>[
          _step(TutorialCategory.blush, 1),
          _step(TutorialCategory.lips, 2),
        ],
        finalPreviewUrl: 'https://example.invalid/final.png',
      );

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(find.text('Your final look'), findsOneWidget);
      expect(
        find.text('The finished result you are working toward'),
        findsOneWidget,
        reason: 'a non-final step shows the compact reference',
      );
    });

    testWidgets('no final preview is shown when none was handed over', (
      tester,
    ) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.blush],
        plan: _standardPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
      );

      expect(find.text('Your final look'), findsNothing);
    });

    testWidgets('there is exactly one final look on a step', (tester) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[
          TutorialCategory.blush,
          TutorialCategory.lips,
        ],
        plan: _standardPlan(),
        steps: <TutorialStep>[
          _step(TutorialCategory.blush, 1),
          _step(TutorialCategory.lips, 2),
        ],
        finalPreviewUrl: 'https://example.invalid/final.png',
      );

      // The last step shows the expanded presentation and must not also show
      // the compact reference: one canonical preview, rendered once.
      expect(find.text('Your final look'), findsOneWidget);
      expect(
        find.text('The finished result you are working toward'),
        findsNothing,
      );
    });

    testWidgets('the final look is a different artifact to the guideline', (
      tester,
    ) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[
          TutorialCategory.blush,
          TutorialCategory.lips,
        ],
        plan: _standardPlan(),
        steps: <TutorialStep>[
          _step(TutorialCategory.blush, 1),
          _step(TutorialCategory.lips, 2),
        ],
        finalPreviewUrl: 'https://example.invalid/final.png',
      );

      final urls = tester
          .widgetList<PrivateImage>(find.byType(PrivateImage))
          .map((image) => image.url)
          .toSet();
      expect(
        urls.contains('https://example.invalid/final.png'),
        isTrue,
        reason: 'the canonical preview handed over is the one displayed',
      );
      expect(
        urls.length,
        greaterThan(1),
        reason: 'the guideline and the final look are separate images',
      );
    });
  });

  group('viewing is free', () {
    testWidgets('opening the guideline full screen generates nothing', (
      tester,
    ) async {
      final steps = await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.eyeliner],
        plan: _standardPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.eyeliner, 1)],
        finalPreviewUrl: 'https://example.invalid/final.png',
      );
      final generatedBefore = steps.generateCalls;
      final signedBefore = steps.signCalls;

      await tester.tap(find.byKey(guidelineViewerTapKey));
      await tester.pumpAndSettle();

      expect(find.byType(TutorialImageViewer), findsOneWidget);
      expect(steps.generateCalls, generatedBefore);
      expect(
        steps.signCalls,
        signedBefore,
        reason: 'the viewer reuses the URL already on screen',
      );
    });

    testWidgets('the viewer opens the guideline it was tapped from', (
      tester,
    ) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.eyeliner],
        plan: _standardPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.eyeliner, 1)],
      );

      final inline = tester
          .widgetList<PrivateImage>(find.byType(PrivateImage))
          .first
          .url;

      await tester.tap(find.byKey(guidelineViewerTapKey));
      await tester.pumpAndSettle();

      final viewer = tester.widget<TutorialImageViewer>(
        find.byType(TutorialImageViewer),
      );
      expect(viewer.url, inline);
      expect(
        viewer.focus,
        TutorialImageFocus.eyes,
        reason: 'an eyeliner step opens on the eyes',
      );
      expect(viewer.title, 'Eyeliner');
    });

    testWidgets('the viewer closes back to the step it came from', (
      tester,
    ) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.blush],
        plan: _standardPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
      );

      await tester.tap(find.byKey(guidelineViewerTapKey));
      await tester.pumpAndSettle();
      expect(find.byType(TutorialImageViewer), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(TutorialImageViewer), findsNothing);
      expect(find.text('Step 1 of 1'), findsOneWidget);
    });

    testWidgets('the final look opens its own viewer, not the guideline', (
      tester,
    ) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[
          TutorialCategory.blush,
          TutorialCategory.lips,
        ],
        plan: _standardPlan(),
        steps: <TutorialStep>[
          _step(TutorialCategory.blush, 1),
          _step(TutorialCategory.lips, 2),
        ],
        finalPreviewUrl: 'https://example.invalid/final.png',
      );

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TutorialFinalLookCard));
      await tester.pumpAndSettle();

      final viewer = tester.widget<TutorialImageViewer>(
        find.byType(TutorialImageViewer),
      );
      expect(viewer.url, 'https://example.invalid/final.png');
      expect(viewer.title, 'Your final look');
      expect(
        viewer.focus,
        TutorialImageFocus.wholeFace,
        reason: 'the finished look is judged whole, never zoomed into',
      );
    });
  });

  group('accessibility', () {
    testWidgets('progress is announced and the image is described', (
      tester,
    ) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.blush],
        plan: _standardPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
      );

      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .semanticsLabel,
        'Step 1 of 1',
      );
      // Asserted on the widget rather than rendered semantics: the network
      // image never loads in a test, so its semantics node is not built.
      expect(
        tester.widget<PrivateImage>(find.byType(PrivateImage)).semanticLabel,
        'Guideline markings showing where to apply Blush',
      );
    });

    testWidgets('shade chips describe their colour for screen readers', (
      tester,
    ) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.foundation],
        plan: _kitPlan(),
      );

      expect(
        find.bySemanticsLabel('Shade Warm Sand, hex code #E3C4A8'),
        findsOneWidget,
      );
    });
  });

  group('responsive result metadata', () {
    testWidgets('missing optional fields are omitted without placeholders', (
      tester,
    ) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.blush],
        plan: _standardPlanWithOnlyShade(),
        steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
      );

      expect(find.text(TutorialLabels.shade), findsOneWidget);
      expect(find.text('Muted rose'), findsOneWidget);
      expect(find.text(TutorialLabels.hex), findsNothing);
      expect(
        find.descendant(
          of: find.byType(StandardProductCard),
          matching: find.text(TutorialLabels.finish),
        ),
        findsNothing,
      );
      expect(find.text(TutorialLabels.intensity), findsNothing);
      expect(find.text(TutorialLabels.yourGoal), findsNothing);
    });

    testWidgets('the final-look reference fits POCO X3 GT at large text', (
      tester,
    ) async {
      // Two steps so the compact reference is what renders, at the POCO X3 GT's
      // real width rather than the 320 floor — width is what drives horizontal
      // overflow, and 393 is the screen this phase is signed off on. The height
      // is deliberately not the device's: the page is a lazy ListView, and at
      // 873 the controls simply are not built yet, so a taller surface is what
      // lets the whole step be laid out and checked at once.
      await _pump(
        tester,
        present: const <TutorialCategory>[
          TutorialCategory.blush,
          TutorialCategory.lips,
        ],
        plan: _standardPlan(),
        // No stored steps, so the tutorial opens on step 1 and the compact
        // reference is what renders. Navigating back from step 2 would reach
        // the same place, but the controls sit below the fold at 2x text and
        // getting to them adds scrolling that has nothing to do with what is
        // being asserted.
        finalPreviewUrl: 'https://example.invalid/final.png',
        size: const Size(393, 4000),
        textScale: 2,
      );

      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byType(TutorialFinalLookCard), findsOneWidget);
      expect(
        find.text('The finished result you are working toward'),
        findsOneWidget,
      );
    });

    testWidgets('long shade and goal wrap on a narrow large-text screen', (
      tester,
    ) async {
      final plan = _standardPlan(
        blushName:
            'Layered muted warm rose with a softly neutral peach undertone',
        blushReasoning:
            'Adds balanced warmth while keeping the strongest colour on the '
            'outer cheek and the inner edge softly diffused.',
      );
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.blush],
        plan: plan,
        steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
        size: const Size(320, 800),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      final longShade = find.text(
        'Layered muted warm rose with a softly neutral peach undertone',
        skipOffstage: false,
      );
      final outerScrollable = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      final scrollableState = tester.state<ScrollableState>(outerScrollable);
      var sawGoal = find
          .text(TutorialLabels.yourGoal, skipOffstage: false)
          .evaluate()
          .isNotEmpty;
      for (
        var scroll = 0;
        scroll < 20 && longShade.evaluate().isEmpty;
        scroll++
      ) {
        scrollableState.position.jumpTo(
          (scrollableState.position.pixels + 500).clamp(
            0,
            scrollableState.position.maxScrollExtent,
          ),
        );
        await tester.pumpAndSettle();
        sawGoal =
            sawGoal ||
            find
                .text(TutorialLabels.yourGoal, skipOffstage: false)
                .evaluate()
                .isNotEmpty;
      }
      expect(tester.takeException(), isNull);
      expect(longShade, findsOneWidget);
      expect(sawGoal, isTrue);
    });
  });

  group('the UI causes no duplicate AI calls', () {
    testWidgets('a rebuild does not generate again', (tester) async {
      final steps = await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.blush],
        plan: _standardPlan(),
      );
      final afterFirstBuild = steps.generateCalls;

      // Force several rebuilds.
      for (var i = 0; i < 5; i += 1) {
        await tester.pump();
      }

      expect(steps.generateCalls, afterFirstBuild);
      expect(afterFirstBuild, 1, reason: 'one step viewed, one call');
    });

    testWidgets('a rapid double tap on Next does not double-generate', (
      tester,
    ) async {
      final steps = await _pump(
        tester,
        present: const <TutorialCategory>[
          TutorialCategory.blush,
          TutorialCategory.lips,
        ],
        plan: _standardPlan(),
        steps: <TutorialStep>[
          _step(TutorialCategory.blush, 1),
          _step(TutorialCategory.lips, 2),
        ],
      );

      // Both steps are drawn, so the tutorial resumes complete on step 2.
      // Tapping Back then Next twice exercises navigation without regenerating.
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.tap(find.text('Next'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(steps.generateCalls, 0, reason: 'both steps were already ready');
    });
  });

  group('the route owns a globally themed page surface', () {
    testWidgets('Light uses the app light surface instead of black', (
      tester,
    ) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.blush],
        plan: _standardPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppTheme.lightTheme.colorScheme.surface);
      expect(scaffold.backgroundColor, isNot(Colors.black));
      expect(
        Theme.of(tester.element(find.byType(TutorialPage))).brightness,
        Brightness.light,
      );
    });

    testWidgets('Dark uses the app dark surface and dark card theme', (
      tester,
    ) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.blush],
        plan: _standardPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
        themeMode: ThemeMode.dark,
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppTheme.darkTheme.colorScheme.surface);
      final cardContext = tester.element(find.byType(Card).first);
      expect(
        Theme.of(cardContext).cardTheme.color,
        AppTheme.darkTheme.cardTheme.color,
      );
    });

    for (final brightness in Brightness.values) {
      testWidgets('System follows $brightness platform brightness', (
        tester,
      ) async {
        await _pump(
          tester,
          present: const <TutorialCategory>[TutorialCategory.blush],
          plan: _standardPlan(),
          steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
          themeMode: ThemeMode.system,
          systemBrightness: brightness,
        );

        final expectedTheme = brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme;
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, expectedTheme.colorScheme.surface);
        expect(
          Theme.of(tester.element(find.byType(TutorialPage))).brightness,
          brightness,
        );
      });
    }
  });
}
