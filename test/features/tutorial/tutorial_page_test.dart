import 'dart:async';
import 'dart:io';

import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/tutorial/data/providers/tutorial_providers.dart';
import 'package:facetune/features/tutorial/domain/catalog/tutorial_instruction_catalog.dart';
import 'package:facetune/features/tutorial/domain/catalog/look_plan_convergence.dart';
import 'package:facetune/features/tutorial/domain/entities/canonical_preview_ref.dart';
import 'package:facetune/features/tutorial/domain/entities/recommendation_source_mode.dart';
import 'package:facetune/features/tutorial/domain/entities/standard_look_entry.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_guide_type.dart';
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
import 'package:facetune/features/tutorial/presentation/widgets/tutorial_bottom_navigation.dart';
import 'package:facetune/features/tutorial/presentation/widgets/tutorial_final_look_card.dart';
import 'package:facetune/features/tutorial/presentation/widgets/tutorial_guide_key.dart';
import 'package:facetune/features/tutorial/presentation/widgets/tutorial_image_viewer.dart';
import 'package:facetune/features/tutorial/presentation/widgets/tutorial_instructions_card.dart';
import 'package:facetune/features/tutorial/presentation/widgets/tutorial_product_cards.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

ValidatedLookPlan _kitPlan({
  String foundationName = 'Studio Base',
  String lipstickName = 'Everyday Nude',
  bool includeEyeshadow = false,
}) => LookPlanConvergence.fromMyMakeupKit(
  KitMakeupRecommendation(
    id: 'kit-rec-1',
    analysisId: 'analysis-1',
    styleCode: 'soft_glam',
    selections: const <KitMakeupSelection>[],
    productSnapshots: <KitProductSnapshot>[
      KitProductSnapshot(
        productId: 'p1',
        category: 'foundation',
        colorHex: '#E3C4A8',
        finish: 'natural',
        productName: foundationName,
        colorLabel: 'Warm Sand',
        foundationDepth: 'light',
        foundationUndertone: 'warm',
      ),
      KitProductSnapshot(
        productId: 'p2',
        category: 'lipstick',
        colorHex: '#B86F72',
        finish: 'cream',
        productName: lipstickName,
      ),
      KitProductSnapshot(
        productId: 'p3',
        category: 'lip_gloss',
        colorHex: '#D8A0A2',
        finish: 'glossy',
        // Deliberately unnamed: the card must not invent a name.
      ),
      if (includeEyeshadow)
        const KitProductSnapshot(
          productId: 'p4',
          category: 'eyeshadow',
          colorHex: '#8B6B73',
          finish: 'satin',
          productName: 'Soft Focus Shadow',
          colorLabel: 'Muted Plum',
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
  _Manifests(this.session, this.audit);
  final TutorialSession session;
  final _Steps audit;

  @override
  Future<TutorialSession?> loadAccepted(CanonicalPreviewRef preview) async {
    audit.manifestLoadCalls += 1;
    return session;
  }

  @override
  Future<TutorialSession> analyze(CanonicalPreviewRef preview) async {
    audit.manifestAnalyzeCalls += 1;
    return session;
  }
}

class _Sessions implements TutorialSessionRepository {
  _Sessions(this.session, this.audit);
  final TutorialSession session;
  final _Steps audit;

  @override
  Future<TutorialSession?> loadForCanonicalPreview(
    CanonicalPreviewRef preview,
  ) async {
    audit.sessionPreviewLoadCalls += 1;
    return session;
  }

  @override
  Future<TutorialSession> loadById(String sessionId) async {
    audit.sessionIdLoadCalls += 1;
    return session;
  }

  @override
  Future<TutorialSession> ensureSteps(TutorialSession value) async {
    audit.ensureStepsCalls += 1;
    return value;
  }

  @override
  Future<void> delete(String sessionId) async {}
}

class _Plans implements LookPlanRepository {
  _Plans(this.plan, this.audit);
  final ValidatedLookPlan plan;
  final _Steps audit;

  @override
  Future<ValidatedLookPlan> loadForCanonicalPreview(
    CanonicalPreviewRef preview,
  ) async {
    audit.lookPlanLoadCalls += 1;
    return plan;
  }
}

class _Steps implements TutorialStepRepository {
  _Steps({this.failEverything = false});

  bool failEverything;
  int generateCalls = 0;
  int signCalls = 0;
  int stepLoadCalls = 0;
  int manifestLoadCalls = 0;
  int manifestAnalyzeCalls = 0;
  int sessionPreviewLoadCalls = 0;
  int sessionIdLoadCalls = 0;
  int ensureStepsCalls = 0;
  int lookPlanLoadCalls = 0;

  ({
    int generated,
    int signed,
    int stepsLoaded,
    int manifestLoaded,
    int manifestAnalyzed,
    int sessionPreviewLoaded,
    int sessionIdLoaded,
    int stepsEnsured,
    int lookPlanLoaded,
  })
  get protectedCallSnapshot => (
    generated: generateCalls,
    signed: signCalls,
    stepsLoaded: stepLoadCalls,
    manifestLoaded: manifestLoadCalls,
    manifestAnalyzed: manifestAnalyzeCalls,
    sessionPreviewLoaded: sessionPreviewLoadCalls,
    sessionIdLoaded: sessionIdLoadCalls,
    stepsEnsured: ensureStepsCalls,
    lookPlanLoaded: lookPlanLoadCalls,
  );

  @override
  Future<List<TutorialStep>> loadForSession(String sessionId) async {
    stepLoadCalls += 1;
    return const <TutorialStep>[];
  }

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
  ValueNotifier<double>? textScaleNotifier,
  bool disableAnimations = false,
  bool pushTutorialRoute = false,
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
  final tutorialPage = TutorialPage(
    preview: plan.sourceMode == RecommendationSourceMode.standard
        ? const CanonicalPreviewRef.standard('preview-1')
        : const CanonicalPreviewRef.myMakeupKit('preview-1'),
    finalPreviewUrl: finalPreviewUrl,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tutorialManifestRepositoryProvider.overrideWithValue(
          _Manifests(session, stepRepo),
        ),
        tutorialSessionRepositoryProvider.overrideWithValue(
          _Sessions(session, stepRepo),
        ),
        lookPlanRepositoryProvider.overrideWithValue(_Plans(plan, stepRepo)),
        tutorialStepRepositoryProvider.overrideWithValue(stepRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        builder: (context, child) {
          Widget scaled(double scale) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: disableAnimations,
            ),
            child: child!,
          );

          final notifier = textScaleNotifier;
          return notifier == null
              ? scaled(textScale)
              : ValueListenableBuilder<double>(
                  valueListenable: notifier,
                  builder: (context, scale, child) => scaled(scale),
                );
        },
        home: pushTutorialRoute
            ? const Scaffold(body: Text('Tutorial closed'))
            : tutorialPage,
      ),
    ),
  );
  if (pushTutorialRoute) {
    await tester.pumpAndSettle();
    final routeContext = tester.element(find.text('Tutorial closed'));
    unawaited(
      Navigator.of(
        routeContext,
      ).push<void>(MaterialPageRoute<void>(builder: (_) => tutorialPage)),
    );
  }
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
        steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
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
    testWidgets('shows the brand-neutral beauty hierarchy', (tester) async {
      final steps = await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.blush],
        plan: _standardPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
      );

      final card = find.byType(StandardProductCard);
      expect(find.text(TutorialLabels.suggestedShades), findsOneWidget);
      expect(find.text(TutorialLabels.yourGoal), findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.byType(TutorialRecommendationSection),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.byType(AppColorSwatch)),
        findsOneWidget,
      );
      expect(find.text('Warm peach'), findsOneWidget);
      expect(find.text('satin · Soft'), findsOneWidget);
      expect(find.text(TutorialLabels.shade), findsNothing);
      expect(find.text(TutorialLabels.hex), findsNothing);
      expect(find.text('#E8A08C'), findsNothing);
      expect(
        find.descendant(of: card, matching: find.text(TutorialLabels.finish)),
        findsNothing,
      );
      expect(find.text(TutorialLabels.intensity), findsNothing);
      expect(find.text(TutorialLabels.whereToApply), findsNothing);
      expect(find.text('Across the cheeks and temples.'), findsNothing);
      expect(find.text(TutorialLabels.technique), findsNothing);
      expect(find.text('Blend upward and outward.'), findsNothing);
      expect(find.text(TutorialLabels.howToApply), findsOneWidget);
      expect(find.text(TutorialLabels.fromYourKit), findsNothing);
      expect(steps.generateCalls, 0);
    });

    testWidgets('Lips shows both plan entries', (tester) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.lips],
        plan: _standardPlan(),
      );

      expect(find.text('Rosewood'), findsOneWidget);
      expect(find.text('Clear shine'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StandardProductCard),
          matching: find.byType(AppColorSwatch),
        ),
        findsNWidgets(2),
      );
    });
  });

  group('My Makeup Kit product card', () {
    testWidgets('shows the exact stored product details', (tester) async {
      final steps = await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.foundation],
        plan: _kitPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.foundation, 1)],
      );

      final card = find.byType(MyMakeupKitProductCard);
      expect(find.text(TutorialLabels.fromYourKit), findsOneWidget);
      expect(find.text('Studio Base'), findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.byType(TutorialRecommendationSection),
        ),
        findsOneWidget,
      );
      final swatch = tester.widget<AppColorSwatch>(
        find.descendant(of: card, matching: find.byType(AppColorSwatch)),
      );
      expect(swatch.color, const Color(0xFFE3C4A8));
      expect(swatch.semanticLabel, 'Shade for Studio Base');
      expect(find.text('Natural'), findsOneWidget);
      expect(find.text('#E3C4A8'), findsNothing);
      expect(find.text(TutorialLabels.shade), findsNothing);
      expect(find.text(TutorialLabels.hex), findsNothing);
      expect(
        find.descendant(of: card, matching: find.text(TutorialLabels.finish)),
        findsNothing,
      );
      expect(find.text(TutorialLabels.intensity), findsNothing);
      expect(find.text(TutorialLabels.yourGoal), findsNothing);
      expect(find.text('Soft'), findsNothing);
      expect(find.text('Light'), findsNothing);
      expect(find.text('Warm'), findsNothing);
      expect(find.text(TutorialLabels.whereToApply), findsNothing);
      expect(find.text(TutorialLabels.technique), findsNothing);
      expect(find.text(TutorialLabels.suggestedShades), findsNothing);
      expect(steps.generateCalls, 0);
    });

    testWidgets('a Lips step shows both owned products', (tester) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.lips],
        plan: _kitPlan(),
      );

      expect(find.text(TutorialLabels.fromYourKit), findsOneWidget);
      expect(find.text('Everyday Nude'), findsOneWidget);
      // The unnamed gloss falls back to its category, never an invented name.
      expect(find.text('Lip gloss'), findsOneWidget);
      expect(find.text('Cream'), findsOneWidget);
      expect(find.text('Glossy'), findsOneWidget);
      expect(find.text('#B86F72'), findsNothing);
      expect(find.text('#D8A0A2'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(MyMakeupKitProductCard),
          matching: find.byType(AppColorSwatch),
        ),
        findsNWidgets(2),
      );
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

  group('shared beauty recommendation presentation', () {
    testWidgets('the two adapters keep separate presentation-ready values', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StandardProductCard(
              entries: _standardPlan().standardEntriesFor(
                TutorialCategory.blush,
              ),
            ),
          ),
        ),
      );
      var section = tester.widget<TutorialRecommendationSection>(
        find.byType(TutorialRecommendationSection),
      );
      expect(section.sectionLabel, TutorialLabels.suggestedShades);
      expect(section.items.single.displayName, 'Warm peach');
      expect(section.items.single.finish, 'satin');
      expect(section.items.single.intensity, 'Soft');
      expect(section.items.single.brand, isNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: MyMakeupKitProductCard(
              items: _kitPlan().productSnapshot.itemsFor(
                TutorialCategory.foundation,
              ),
            ),
          ),
        ),
      );
      section = tester.widget<TutorialRecommendationSection>(
        find.byType(TutorialRecommendationSection),
      );
      expect(section.sectionLabel, TutorialLabels.fromYourKit);
      expect(section.items.single.displayName, 'Studio Base');
      expect(section.items.single.finish, 'Natural');
      expect(
        section.items.single.intensity,
        isNull,
        reason: 'the snapshot has no per-product intensity to display',
      );
      expect(
        section.items.single.brand,
        isNull,
        reason: 'the immutable snapshot has no authoritative brand field',
      );
      expect(find.text('Warm peach'), findsNothing);
      expect(find.text('Soft'), findsNothing);
    });

    testWidgets('missing My Kit data renders no Standard substitute', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: MyMakeupKitProductCard(items: [])),
        ),
      );

      expect(find.byType(TutorialRecommendationSection), findsOneWidget);
      expect(find.byType(AppCard), findsNothing);
      expect(find.text(TutorialLabels.fromYourKit), findsNothing);
      expect(find.text(TutorialLabels.suggestedShades), findsNothing);
    });

    testWidgets('long names and metadata wrap at 320px with large text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      const longName =
          'Layered muted warm rose with a softly neutral peach undertone';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(
            body: TutorialRecommendationSection(
              sectionLabel: TutorialLabels.suggestedShades,
              items: <TutorialRecommendationItem>[
                TutorialRecommendationItem(
                  displayName: longName,
                  swatch: Color(0xFFE8A08C),
                  finish: 'Soft-focus luminous satin',
                  intensity: 'Medium',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text(longName), findsOneWidget);
      expect(find.text('Soft-focus luminous satin · Medium'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('the shared component owns no business authority', () {
      final source = File(
        '${Directory.current.path}${Platform.pathSeparator}'
        '${'lib/features/tutorial/presentation/widgets/'
            'tutorial_recommendation_section.dart'.replaceAll('/', Platform.pathSeparator)}',
      ).readAsStringSync();
      final executable = source
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');

      for (final forbidden in <String>[
        'Repository',
        'Controller',
        'Provider',
        'riverpod',
        'StandardLookEntry',
        'LookProductSnapshot',
        'RecommendationSourceMode',
        '../../domain/',
        '../../data/',
      ]) {
        expect(
          executable.contains(forbidden),
          isFalse,
          reason: '$forbidden belongs outside the shared visual component',
        );
      }
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
    final modes = <String, (ValidatedLookPlan Function(), String)>{
      'Standard': (_standardPlan, 'https://example.invalid/standard-final.png'),
      'My Makeup Kit': (_kitPlan, 'https://example.invalid/my-kit-final.png'),
    };

    for (final MapEntry(key: mode, value: (plan, previewUrl))
        in modes.entries) {
      testWidgets(
        '$mode uses one canonical compact Final Look on regular and final steps',
        (tester) async {
          final steps = await _pump(
            tester,
            present: const <TutorialCategory>[
              TutorialCategory.foundation,
              TutorialCategory.lips,
            ],
            plan: plan(),
            steps: <TutorialStep>[
              _step(TutorialCategory.foundation, 1),
              _step(TutorialCategory.lips, 2),
            ],
            finalPreviewUrl: previewUrl,
          );

          Future<void> expectCompactCardAndViewer() async {
            final card = find.byType(TutorialFinalLookCard);
            expect(card, findsOneWidget);
            expect(
              find.descendant(
                of: card,
                matching: find.text('View your target'),
              ),
              findsOneWidget,
            );
            expect(
              find.descendant(of: card, matching: find.byType(AspectRatio)),
              findsNothing,
              reason: 'no runtime step may restore the giant inline image',
            );
            expect(
              tester
                  .widget<PrivateImage>(
                    find.descendant(
                      of: card,
                      matching: find.byType(PrivateImage),
                    ),
                  )
                  .url,
              previewUrl,
              reason: 'each mode must retain its own handed-over preview',
            );

            final generatedBefore = steps.generateCalls;
            final signedBefore = steps.signCalls;
            await tester.tap(card);
            await tester.pumpAndSettle();

            final viewer = tester.widget<TutorialImageViewer>(
              find.byType(TutorialImageViewer),
            );
            expect(viewer.url, previewUrl);
            expect(viewer.title, TutorialLabels.yourFinalLook);
            expect(viewer.focus, TutorialImageFocus.wholeFace);
            expect(steps.generateCalls, generatedBefore);
            expect(
              steps.signCalls,
              signedBefore,
              reason: 'the viewer reuses the canonical URL already on screen',
            );

            await tester.tap(find.byTooltip(TutorialLabels.close));
            await tester.pumpAndSettle();
            expect(find.byType(TutorialImageViewer), findsNothing);
          }

          // Completed stored steps resume on the runtime-final category.
          expect(find.text('Step 2 of 2'), findsOneWidget);
          expect(find.text(TutorialLabels.finish_), findsWidgets);
          await expectCompactCardAndViewer();
          expect(find.text('Step 2 of 2'), findsOneWidget);

          await tester.tap(find.text(TutorialLabels.back));
          await tester.pumpAndSettle();

          expect(find.text('Step 1 of 2'), findsOneWidget);
          expect(find.text(TutorialLabels.next), findsWidgets);
          await expectCompactCardAndViewer();
          expect(find.text('Step 1 of 2'), findsOneWidget);
        },
      );
    }

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
      expect(find.text('View your target'), findsOneWidget);
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

      // The final step uses the same single compact reference as every other
      // runtime step; it must not add the former giant inline image.
      expect(find.byType(TutorialFinalLookCard), findsOneWidget);
      expect(find.text('Your final look'), findsOneWidget);
      expect(find.text('View your target'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TutorialFinalLookCard),
          matching: find.byType(AspectRatio),
        ),
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

    testWidgets('swatches have accessible text names without exposing hex', (
      tester,
    ) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.foundation],
        plan: _kitPlan(),
      );

      expect(find.bySemanticsLabel('Shade for Studio Base'), findsOneWidget);
      expect(find.text('#E3C4A8'), findsNothing);
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

      expect(find.text('Muted rose'), findsOneWidget);
      expect(find.text(TutorialLabels.shade), findsNothing);
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
      // 873 the lower content simply is not built yet, so a taller surface is
      // what lets the whole step be laid out and checked at once. (The step
      // controls are no longer among that content — they are a persistent
      // footer — but everything below the fold still is.)
      await _pump(
        tester,
        present: const <TutorialCategory>[
          TutorialCategory.blush,
          TutorialCategory.lips,
        ],
        plan: _standardPlan(),
        // No stored steps, so the tutorial opens on step 1 and the compact
        // reference is what renders. Navigating back from step 2 would reach
        // the same place, but that adds scrolling and a tap that have nothing
        // to do with what is being asserted.
        finalPreviewUrl: 'https://example.invalid/final.png',
        size: const Size(393, 4000),
        textScale: 2,
      );

      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byType(TutorialFinalLookCard), findsOneWidget);
      expect(find.text('View your target'), findsOneWidget);
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

  // UI-P5 — presentation only. Every assertion below is about what the step
  // looks like and how it is reached; none of it may change what the tutorial
  // does, which is what the first group here checks first.
  group('presentation polish leaves behaviour alone', () {
    testWidgets('the close control exits without generating anything', (
      tester,
    ) async {
      // The exit affordance the tutorial did not have. It must leave — not
      // cancel, restart, or redraw — so the generation count is the assertion
      // that matters as much as the pop.
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
        pushTutorialRoute: true,
      );

      expect(find.byTooltip(TutorialLabels.closeTutorial), findsOneWidget);
      expect(steps.generateCalls, 0);

      await tester.tap(find.byTooltip(TutorialLabels.closeTutorial));
      await tester.pumpAndSettle();

      expect(find.byType(TutorialPage), findsNothing);
      expect(find.text('Tutorial closed'), findsOneWidget);
      expect(steps.generateCalls, 0, reason: 'leaving must cost nothing');
    });

    testWidgets('close is distinct from the in-page step Back button', (
      tester,
    ) async {
      // Two retreats that mean different things. If they ever wear the same
      // icon or the same word, one of them is lying.
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
      );

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.text(TutorialLabels.back), findsOneWidget);
      expect(
        find.byIcon(Icons.arrow_back),
        findsNothing,
        reason: 'a back arrow beside a Back button is two meanings, one icon',
      );
    });

    testWidgets('the guideline advertises that it opens', (tester) async {
      // Tapping the guideline has always opened the viewer; nothing on screen
      // said so, while the smaller Final Look card beside it did.
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.blush],
        plan: _standardPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
      );

      expect(find.text(TutorialLabels.tapToEnlarge), findsWidgets);
      expect(find.byIcon(Icons.zoom_out_map), findsWidgets);
    });

    testWidgets('the viewer still opens from the guideline', (tester) async {
      final steps = await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.blush],
        plan: _standardPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
      );

      await tester.tap(find.byKey(guidelineViewerTapKey));
      await tester.pumpAndSettle();

      expect(find.byType(TutorialImageViewer), findsOneWidget);
      // Viewing an artifact already on screen draws nothing new.
      expect(steps.generateCalls, 0);
    });

    testWidgets('redraw still requires explicit confirmation', (tester) async {
      // The cost gate. Presentation moved this control to the shared tertiary
      // button; it must still be a two-step action.
      final steps = await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.blush],
        plan: _standardPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
      );

      await tester.tap(find.text(TutorialLabels.redrawGuide));
      await tester.pumpAndSettle();

      // The sheet is up and nothing has been spent yet.
      expect(steps.generateCalls, 0);

      // Dismissing costs nothing.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(steps.generateCalls, 0);
    });

    testWidgets('the step header keeps both the count and the bar', (
      tester,
    ) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[
          TutorialCategory.blush,
          TutorialCategory.lips,
        ],
        plan: _standardPlan(),
      );

      expect(find.text('Step 1 of 2'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.5);
      // The bar keeps its own spoken label: a reader landing on it hears what
      // it is, which is a different job from the counter's live announcement.
      expect(bar.semanticsLabel, 'Step 1 of 2');
    });

    testWidgets('the header stacks rather than overflowing at large text', (
      tester,
    ) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.blush],
        plan: _standardPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
        size: const Size(320, 2400),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Step 1 of 1'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('instruction order and beauty metadata remain distinct', (
      tester,
    ) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.blush],
        plan: _standardPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
      );

      expect(find.text(TutorialLabels.howToApply), findsOneWidget);
      expect(find.text(TutorialLabels.suggestedShades), findsOneWidget);
      expect(find.text('Warm peach'), findsOneWidget);
      expect(find.text('satin · Soft'), findsOneWidget);
      expect(find.text(TutorialLabels.shade), findsNothing);
      expect(find.text(TutorialLabels.hex), findsNothing);
      expect(find.text(TutorialLabels.intensity), findsNothing);
      expect(find.text('#E8A08C'), findsNothing);
      expect(find.text(TutorialLabels.guideKey), findsOneWidget);
    });

    testWidgets('both adapters use the same surface in both themes', (
      tester,
    ) async {
      final items = _kitPlan().productSnapshot.itemsFor(
        TutorialCategory.foundation,
      );
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        for (final adapter in <Widget>[
          StandardProductCard(
            entries: _standardPlan().standardEntriesFor(
              TutorialCategory.foundation,
            ),
          ),
          MyMakeupKitProductCard(items: items),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: mode,
              home: Scaffold(body: adapter),
            ),
          );
          await tester.pump();

          expect(find.byType(TutorialRecommendationSection), findsOneWidget);
          expect(tester.widget<AppCard>(find.byType(AppCard)).color, isNull);
          expect(find.byType(AppColorSwatch), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    });
  });

  group('guide hero, compact key, and redraw placement', () {
    Finder insideGuideKey(Finder matching) =>
        find.descendant(of: find.byType(TutorialGuideKey), matching: matching);

    testWidgets('Blush shows only its accepted guide symbols', (tester) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.blush],
        plan: _standardPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
      );

      for (final type in <TutorialGuideType>[
        TutorialGuideType.startAnchor,
        TutorialGuideType.placementBoundary,
        TutorialGuideType.direction,
      ]) {
        expect(insideGuideKey(find.text(type.symbol)), findsOneWidget);
        expect(
          insideGuideKey(find.text(TutorialLabels.guideTypeName(type))),
          findsOneWidget,
        );
      }
      expect(
        insideGuideKey(find.text(TutorialGuideType.blendZone.symbol)),
        findsNothing,
      );
    });

    testWidgets('Eyeshadow shows Blend zone without an invented Start', (
      tester,
    ) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.eyeshadow],
        plan: _standardPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.eyeshadow, 1)],
      );

      for (final type in <TutorialGuideType>[
        TutorialGuideType.placementBoundary,
        TutorialGuideType.blendZone,
        TutorialGuideType.direction,
      ]) {
        expect(insideGuideKey(find.text(type.symbol)), findsOneWidget);
      }
      expect(
        insideGuideKey(find.text(TutorialGuideType.startAnchor.symbol)),
        findsNothing,
      );
    });

    testWidgets('the key is inline and the top content follows guide order', (
      tester,
    ) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.blush],
        plan: _standardPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
      );

      expect(TutorialLabels.guideKey, 'Guide key');
      expect(
        find.descendant(
          of: find.byType(TutorialGuideKey),
          matching: find.byType(Container),
        ),
        findsNothing,
        reason: 'the compact key is inline content, not another card',
      );

      final guideTop = tester.getTopLeft(find.byKey(guidelineViewerTapKey)).dy;
      final keyTop = tester.getTopLeft(find.byType(TutorialGuideKey)).dy;
      final redrawTop = tester
          .getTopLeft(find.text(TutorialLabels.redrawGuide))
          .dy;
      final howToTop = tester
          .getTopLeft(find.text(TutorialLabels.howToApply))
          .dy;

      expect(guideTop, lessThan(keyTop));
      expect(keyTop, lessThan(redrawTop));
      expect(redrawTop, lessThan(howToTop));
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(find.text(TutorialLabels.redraw), findsNothing);
    });

    for (final MapEntry(key: mode, value: plan)
        in <String, ValidatedLookPlan Function()>{
          'Standard': _standardPlan,
          'My Makeup Kit': _kitPlan,
        }.entries) {
      testWidgets('$mode uses the same guide-area presentation', (
        tester,
      ) async {
        await _pump(
          tester,
          present: const <TutorialCategory>[TutorialCategory.foundation],
          plan: plan(),
          steps: <TutorialStep>[_step(TutorialCategory.foundation, 1)],
        );

        expect(find.byKey(guidelineViewerTapKey), findsOneWidget);
        expect(find.text(TutorialLabels.tapToEnlarge), findsOneWidget);
        expect(find.byType(TutorialGuideKey), findsOneWidget);
        expect(find.text(TutorialLabels.redrawGuide), findsOneWidget);
        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      });
    }

    testWidgets('redraw still calls the existing callback only after confirm', (
      tester,
    ) async {
      final steps = await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.blush],
        plan: _standardPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
      );
      expect(steps.generateCalls, 0);

      await tester.tap(find.text(TutorialLabels.redrawGuide));
      await tester.pumpAndSettle();

      expect(find.text(TutorialLabels.redraw), findsOneWidget);
      expect(find.text(TutorialLabels.redrawExplanation), findsOneWidget);
      expect(steps.generateCalls, 0, reason: 'opening confirmation is free');

      await tester.tap(find.text(TutorialLabels.redrawConfirm));
      await tester.pumpAndSettle();

      expect(steps.generateCalls, 1);
    });

    testWidgets('rebuilds never trigger redraw', (tester) async {
      final steps = await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.blush],
        plan: _standardPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.blush, 1)],
        size: const Size(393, 873),
      );
      expect(steps.generateCalls, 0);

      tester.view.physicalSize = const Size(320, 800);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(393, 873);
      await tester.pumpAndSettle();

      expect(find.text(TutorialLabels.redrawGuide), findsOneWidget);
      expect(steps.generateCalls, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('editorial instruction rail', () {
    final modes = <String, (ValidatedLookPlan Function(), bool)>{
      'Standard': (_standardPlan, true),
      'My Makeup Kit': (_kitPlan, false),
    };

    for (final MapEntry(key: mode, value: (plan, hasGoal)) in modes.entries) {
      testWidgets('$mode uses the same How to apply presentation', (
        tester,
      ) async {
        final steps = await _pump(
          tester,
          present: const <TutorialCategory>[TutorialCategory.foundation],
          plan: plan(),
          steps: <TutorialStep>[_step(TutorialCategory.foundation, 1)],
        );
        final expected = TutorialInstructionCatalog.forCategory(
          TutorialCategory.foundation,
        );
        final rail = find.byType(TutorialInstructionsCard);

        expect(rail, findsOneWidget);
        expect(
          find.descendant(of: rail, matching: find.byType(AppCard)),
          findsNothing,
        );
        expect(
          find.descendant(of: rail, matching: find.byType(VerticalDivider)),
          findsNWidgets(expected.length - 1),
        );
        for (final step in expected.steps) {
          expect(
            find.descendant(
              of: rail,
              matching: find.text(step.sequence.toString().padLeft(2, '0')),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(of: rail, matching: find.text(step.shortTitle)),
            findsOneWidget,
          );
          expect(
            find.descendant(of: rail, matching: find.text(step.instruction)),
            findsOneWidget,
          );
        }
        expect(
          find.descendant(
            of: rail,
            matching: find.text(TutorialLabels.yourGoal),
          ),
          hasGoal ? findsOneWidget : findsNothing,
          reason: 'goal presence follows authority, not presentation mode',
        );
        expect(steps.generateCalls, 0, reason: 'rendering the rail is free');
      });
    }
  });

  group('step navigation is a persistent footer', () {
    /// The footer the Scaffold itself is holding.
    ///
    /// Read from `Scaffold.bottomNavigationBar` rather than found anywhere in
    /// the tree on purpose: a `TutorialBottomNavigation` rendered inside the
    /// body would satisfy `find.byType` while failing the only property that
    /// matters, which is that the body is measured against what is left after
    /// it.
    TutorialBottomNavigation footerOf(WidgetTester tester) {
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      final footer = scaffold.bottomNavigationBar;
      expect(
        footer,
        isA<TutorialBottomNavigation>(),
        reason: 'step navigation belongs in the Scaffold bottom slot',
      );
      return footer! as TutorialBottomNavigation;
    }

    /// A label as it appears *in the footer*.
    ///
    /// Necessary rather than fussy: "Finish" is also the name of a product
    /// field, so a bare text finder matches the recommendation card and would
    /// report a Finish button on every regular step.
    Finder inFooter(String label) => find.descendant(
      of: find.byType(TutorialBottomNavigation),
      matching: find.text(label),
    );

    /// Both modes, with the recommendation card each one is allowed to draw.
    ///
    /// Every footer claim below is made about each of them, from the same
    /// assertions — which is what "identical presentation" has to mean if it is
    /// to be testable at all. The card types come along so each run can also
    /// show that the thing behind the shared shell is still two authorities.
    final modes = <String, (ValidatedLookPlan Function(), Type, Type)>{
      'Standard': (_standardPlan, StandardProductCard, MyMakeupKitProductCard),
      'My Makeup Kit': (_kitPlan, MyMakeupKitProductCard, StandardProductCard),
    };

    // Deliberately ends on Blush rather than Lips: "last" must mean the last
    // runtime category, and a tutorial whose final step is Blush is the case
    // that would pass anyway if the page had quietly hardcoded Lips.
    const endsOnBlush = <TutorialCategory>[
      TutorialCategory.foundation,
      TutorialCategory.blush,
    ];

    // Both modes carry authoritative data for these two, so the recommendation
    // card actually renders in each and can be told apart.
    const endsOnLips = <TutorialCategory>[
      TutorialCategory.foundation,
      TutorialCategory.lips,
    ];

    for (final MapEntry(key: mode, value: (plan, ownCard, otherCard))
        in modes.entries) {
      testWidgets('$mode: a regular step offers Back and Next', (tester) async {
        await _pump(
          tester,
          present: const <TutorialCategory>[
            TutorialCategory.foundation,
            TutorialCategory.blush,
            TutorialCategory.lips,
          ],
          plan: plan(),
        );

        expect(find.text('Step 1 of 3'), findsOneWidget);
        final footer = footerOf(tester);
        expect(footer.isLastStep, isFalse);
        expect(
          footer.canGoBack,
          isFalse,
          reason: 'there is no previous step to return to on step 1',
        );
        expect(inFooter(TutorialLabels.back), findsOneWidget);
        expect(inFooter(TutorialLabels.next), findsOneWidget);
        expect(inFooter(TutorialLabels.finish_), findsNothing);
        expect(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byType(TutorialBottomNavigation),
          ),
          findsNothing,
          reason: 'the footer must not be a child of the scroll view',
        );
      });

      testWidgets('$mode: one footer, its own recommendation authority', (
        tester,
      ) async {
        // The final step, and the whole point of a shared shell in one test:
        // the footer is the same widget making the same claims under both
        // modes, while the section above it is still each mode's own card.
        await _pump(
          tester,
          present: endsOnLips,
          plan: plan(),
          // Both drawn, so the tutorial resumes on the last step.
          steps: <TutorialStep>[
            _step(TutorialCategory.foundation, 1),
            _step(TutorialCategory.lips, 2),
          ],
        );

        expect(find.text('Step 2 of 2'), findsOneWidget);
        final footer = footerOf(tester);
        expect(footer.isLastStep, isTrue);
        expect(footer.canGoBack, isTrue);
        expect(inFooter(TutorialLabels.back), findsOneWidget);
        expect(inFooter(TutorialLabels.finish_), findsOneWidget);
        expect(inFooter(TutorialLabels.next), findsNothing);

        expect(find.byType(ownCard), findsOneWidget);
        expect(
          find.byType(otherCard),
          findsNothing,
          reason: 'shared presentation must not become shared authority',
        );
      });

      testWidgets('$mode: the final step is the last runtime category', (
        tester,
      ) async {
        await _pump(
          tester,
          present: endsOnBlush,
          plan: plan(),
          steps: <TutorialStep>[
            _step(TutorialCategory.foundation, 1),
            _step(TutorialCategory.blush, 2),
          ],
        );

        expect(find.text('Step 2 of 2'), findsOneWidget);
        expect(find.text('Blush'), findsOneWidget);
        expect(
          footerOf(tester).isLastStep,
          isTrue,
          reason: 'Blush is last here, and last is what Finish follows',
        );
        expect(inFooter(TutorialLabels.finish_), findsOneWidget);
      });
    }

    for (final present in <List<TutorialCategory>>[
      <TutorialCategory>[TutorialCategory.blush],
      <TutorialCategory>[TutorialCategory.foundation, TutorialCategory.blush],
      <TutorialCategory>[
        TutorialCategory.foundation,
        TutorialCategory.concealer,
        TutorialCategory.eyeshadow,
        TutorialCategory.lips,
      ],
    ]) {
      final n = present.length;
      testWidgets('a $n-step tutorial finishes on step $n', (tester) async {
        // N comes from the accepted manifest, so the footer's Finish has to
        // move with it. Nothing here tells the page how many steps to expect.
        await _pump(
          tester,
          present: present,
          plan: _standardPlan(),
          steps: <TutorialStep>[
            for (var index = 0; index < n; index += 1)
              _step(present[index], index + 1),
          ],
        );

        expect(find.text('Step $n of $n'), findsOneWidget);
        final footer = footerOf(tester);
        expect(footer.isLastStep, isTrue);
        expect(footer.canGoBack, n > 1);
        expect(inFooter(TutorialLabels.finish_), findsOneWidget);
      });
    }

    testWidgets('the footer drives the same navigation it always did', (
      tester,
    ) async {
      final steps = await _pump(
        tester,
        present: const <TutorialCategory>[
          TutorialCategory.foundation,
          TutorialCategory.blush,
          TutorialCategory.lips,
        ],
        plan: _standardPlan(),
        steps: <TutorialStep>[
          _step(TutorialCategory.foundation, 1),
          _step(TutorialCategory.blush, 2),
          _step(TutorialCategory.lips, 3),
        ],
      );

      expect(find.text('Step 3 of 3'), findsOneWidget);

      await tester.tap(inFooter(TutorialLabels.back));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 3'), findsOneWidget);

      await tester.tap(inFooter(TutorialLabels.next));
      await tester.pumpAndSettle();
      expect(find.text('Step 3 of 3'), findsOneWidget);

      expect(
        steps.generateCalls,
        0,
        reason: 'moving between drawn steps redraws nothing',
      );
    });

    testWidgets('Finish leaves by the same path close does', (tester) async {
      final steps = await _pump(
        tester,
        present: endsOnBlush,
        plan: _standardPlan(),
        steps: <TutorialStep>[
          _step(TutorialCategory.foundation, 1),
          _step(TutorialCategory.blush, 2),
        ],
        pushTutorialRoute: true,
      );

      expect(find.text('Step 2 of 2'), findsOneWidget);

      await tester.tap(inFooter(TutorialLabels.finish_));
      await tester.pumpAndSettle();

      expect(find.byType(TutorialPage), findsNothing);
      expect(find.text('Tutorial closed'), findsOneWidget);
      expect(steps.generateCalls, 0, reason: 'finishing must cost nothing');
    });

    testWidgets('a screen that is not a step has no footer', (tester) async {
      // Nothing to navigate, so nothing to navigate with. A footer over a
      // spinner or an empty state would be a control that cannot mean anything.
      await _pump(
        tester,
        present: const <TutorialCategory>[],
        plan: _standardPlan(),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.bottomNavigationBar, isNull);
      expect(find.text(TutorialLabels.next), findsNothing);
      expect(find.text(TutorialLabels.back), findsNothing);
    });

    testWidgets('the footer never overlaps the content on a POCO X3 GT', (
      tester,
    ) async {
      await _pump(
        tester,
        present: endsOnBlush,
        plan: _standardPlan(),
        steps: <TutorialStep>[
          _step(TutorialCategory.foundation, 1),
          _step(TutorialCategory.blush, 2),
        ],
        finalPreviewUrl: 'https://example.invalid/final.png',
        size: const Size(393, 873),
      );

      final footerRect = tester.getRect(find.byType(TutorialBottomNavigation));
      final listRect = tester.getRect(find.byType(ListView));

      expect(
        listRect.bottom,
        lessThanOrEqualTo(footerRect.top),
        reason: 'the scroll view must end where the footer begins',
      );
      expect(footerRect.bottom, lessThanOrEqualTo(873));
      expect(footerRect.top, greaterThanOrEqualTo(0));
      expect(
        footerRect.height,
        lessThan(873 * 0.25),
        reason: 'a reserved strip, not a second screen',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrolling to the end moves the content, not the footer', (
      tester,
    ) async {
      final steps = await _pump(
        tester,
        present: endsOnBlush,
        plan: _standardPlan(),
        steps: <TutorialStep>[
          _step(TutorialCategory.foundation, 1),
          _step(TutorialCategory.blush, 2),
        ],
        finalPreviewUrl: 'https://example.invalid/final.png',
        size: const Size(393, 873),
      );

      final footer = find.byType(TutorialBottomNavigation);
      final before = tester.getRect(footer);

      final scrollable = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      // A lazy list grows its extent as it builds, so settle on the true end
      // rather than trusting the first reported maximum.
      for (
        var attempt = 0;
        attempt < 20 && position.pixels < position.maxScrollExtent;
        attempt += 1
      ) {
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
      }

      expect(
        position.pixels,
        greaterThan(0),
        reason:
            'the step must actually be scrollable for this to prove anything',
      );
      expect(
        tester.getRect(footer),
        before,
        reason: 'the footer is outside the scroll view, so it cannot move',
      );

      // The recommendation is now the last content on every step. It has to
      // remain fully readable rather than hiding behind the persistent strip.
      final recommendation = find.byType(StandardProductCard);
      expect(recommendation, findsOneWidget);
      expect(
        tester.getRect(recommendation).bottom,
        lessThanOrEqualTo(before.top),
      );

      expect(inFooter(TutorialLabels.finish_), findsOneWidget);
      expect(steps.generateCalls, 0, reason: 'scrolling is free');
    });

    testWidgets('rebuilding the footer costs no generations', (tester) async {
      final steps = await _pump(
        tester,
        present: endsOnBlush,
        plan: _standardPlan(),
        steps: <TutorialStep>[
          _step(TutorialCategory.foundation, 1),
          _step(TutorialCategory.blush, 2),
        ],
        size: const Size(393, 873),
      );
      expect(steps.generateCalls, 0);

      // A resize is what a persistent footer actually notices: it re-runs the
      // LayoutBuilder and can flip between the row and the stacked form.
      tester.view.physicalSize = const Size(320, 800);
      await tester.pumpAndSettle();
      expect(inFooter(TutorialLabels.finish_), findsOneWidget);

      tester.view.physicalSize = const Size(393, 873);
      await tester.pumpAndSettle();

      expect(inFooter(TutorialLabels.finish_), findsOneWidget);
      expect(steps.generateCalls, 0);
      expect(tester.takeException(), isNull);
    });

    test('the shared footer owns no data authority', () {
      // The boundary the mode-authority lock draws: presentation may be shared,
      // authority may not. Asserted on the source because the property is the
      // absence of a dependency, which no widget test can observe.
      final source = File(
        '${Directory.current.path}${Platform.pathSeparator}'
        '${'lib/features/tutorial/presentation/widgets/'
            'tutorial_bottom_navigation.dart'.replaceAll('/', Platform.pathSeparator)}',
      ).readAsStringSync();

      // Prose explaining what this widget deliberately does not hold is not the
      // defect, so the check reads executable lines only.
      final executable = source
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');

      for (final forbidden in <String>[
        'Repository',
        'Controller',
        'Provider',
        'riverpod',
        'TutorialSession',
        'ValidatedLookPlan',
        'LookProductSnapshot',
        'StandardLookEntry',
        'RecommendationSourceMode',
      ]) {
        expect(
          executable.contains(forbidden),
          isFalse,
          reason: '$forbidden has no business inside a shared footer',
        );
      }
      for (final layer in <String>[
        '../../domain/',
        '../../data/',
        '../controllers/',
      ]) {
        expect(
          executable.contains("import '$layer"),
          isFalse,
          reason: 'the footer must not reach into $layer',
        );
      }
    });
  });

  group('TUT-UI-6 responsive and accessibility polish', () {
    final modePlans = <(String, ValidatedLookPlan)>[
      ('Standard', _standardPlan()),
      (
        'My Makeup Kit',
        _kitPlan(
          lipstickName:
              'Velvet Cloud Longwear Lip Colour in Muted Rosewood No. 12',
          includeEyeshadow: true,
        ),
      ),
    ];
    final viewports = <(String, Size, double, ThemeMode, Brightness)>[
      (
        'POCO X3 GT Light',
        const Size(393, 873),
        1,
        ThemeMode.light,
        Brightness.light,
      ),
      (
        '320-wide Dark at 2x text',
        const Size(320, 640),
        2,
        ThemeMode.dark,
        Brightness.dark,
      ),
      (
        'short System Light at 2x text',
        const Size(393, 520),
        2,
        ThemeMode.system,
        Brightness.light,
      ),
      (
        'short System Dark',
        const Size(393, 520),
        1,
        ThemeMode.system,
        Brightness.dark,
      ),
    ];

    for (final (modeName, plan) in modePlans) {
      for (final (viewportName, size, scale, themeMode, brightness)
          in viewports) {
        testWidgets('$modeName: final multi-row step survives $viewportName', (
          tester,
        ) async {
          await _pump(
            tester,
            present: const <TutorialCategory>[
              TutorialCategory.foundation,
              TutorialCategory.eyeshadow,
              TutorialCategory.lips,
            ],
            plan: plan,
            steps: <TutorialStep>[
              _step(TutorialCategory.foundation, 1),
              _step(TutorialCategory.eyeshadow, 2),
              _step(TutorialCategory.lips, 3),
            ],
            finalPreviewUrl: 'https://example.invalid/$modeName-final.png',
            size: size,
            textScale: scale,
            themeMode: themeMode,
            systemBrightness: brightness,
          );

          expect(find.text('Step 3 of 3'), findsOneWidget);
          expect(find.text(TutorialLabels.finish_), findsWidgets);
          final footer = find.byType(TutorialBottomNavigation);
          final footerRect = tester.getRect(footer);
          expect(
            tester.getRect(find.byType(ListView)).bottom,
            lessThanOrEqualTo(footerRect.top),
          );
          expect(tester.takeException(), isNull);

          final scrollable = find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first;
          final position = tester.state<ScrollableState>(scrollable).position;
          for (var attempt = 0; attempt < 30; attempt += 1) {
            position.jumpTo(position.maxScrollExtent);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (find
                    .byType(TutorialRecommendationSection)
                    .evaluate()
                    .isNotEmpty &&
                position.pixels == position.maxScrollExtent) {
              break;
            }
          }

          final recommendation = tester.widget<TutorialRecommendationSection>(
            find.byType(TutorialRecommendationSection),
          );
          expect(
            recommendation.items,
            hasLength(2),
            reason: 'both modes keep both authoritative Lips rows',
          );
          expect(
            tester.getRect(find.byType(TutorialRecommendationSection)).bottom,
            lessThanOrEqualTo(footerRect.top),
          );
          final expectedBrightness = themeMode == ThemeMode.dark
              ? Brightness.dark
              : themeMode == ThemeMode.light
              ? Brightness.light
              : brightness;
          expect(
            Theme.of(tester.element(find.byType(TutorialPage))).brightness,
            expectedBrightness,
          );
        });
      }
    }

    testWidgets('the longest category heading wraps without truncation', (
      tester,
    ) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.contourBronzer],
        plan: _standardPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.contourBronzer, 1)],
        size: const Size(320, 640),
        textScale: 2,
      );

      final heading = tester.widget<Text>(find.text('Contour & Bronzer'));
      expect(heading.maxLines, isNull);
      expect(heading.overflow, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('interactive semantics are complete and unambiguous', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        present: const <TutorialCategory>[
          TutorialCategory.foundation,
          TutorialCategory.lips,
        ],
        plan: _standardPlan(),
        steps: <TutorialStep>[
          _step(TutorialCategory.foundation, 1),
          _step(TutorialCategory.lips, 2),
        ],
        finalPreviewUrl: 'https://example.invalid/final.png',
      );

      void expectButton(String label) {
        final finder = find.bySemanticsLabel(label);
        expect(finder, findsOneWidget);
        expect(tester.getSemantics(finder).flagsCollection.isButton, isTrue);
      }

      expectButton(TutorialLabels.closeTutorial);
      expectButton(TutorialLabels.back);
      expectButton(TutorialLabels.finish_);
      expectButton(TutorialLabels.redrawGuide);
      expectButton(
        '${TutorialLabels.guidelineImageLabel(TutorialCategory.lips)}. '
        '${TutorialLabels.tapToEnlarge}.',
      );
      expectButton(
        '${TutorialLabels.yourFinalLook}. '
        '${TutorialLabels.finalLookHint}. '
        '${TutorialLabels.tapToEnlarge}.',
      );

      final guideHeading = find.bySemanticsLabel(
        '${TutorialLabels.guideKey}. ${TutorialLabels.guideKeySemantics}',
      );
      expect(guideHeading, findsOneWidget);
      expect(
        tester.getSemantics(guideHeading).flagsCollection.isHeader,
        isTrue,
      );
      for (final type in TutorialInstructionCatalog.forCategory(
        TutorialCategory.lips,
      ).referencedGuideTypes) {
        expect(
          find.bySemanticsLabel(TutorialLabels.guideTypeSemantics(type)),
          findsWidgets,
        );
      }

      final instructions = TutorialInstructionCatalog.forCategory(
        TutorialCategory.lips,
      );
      for (final step in instructions.steps) {
        expect(
          find.bySemanticsLabel(
            'Step ${step.sequence}. ${step.shortTitle}. '
            '${TutorialLabels.guideTypeSemantics(step.guideType)}. '
            '${step.instruction}',
          ),
          findsOneWidget,
        );
      }
      expect(find.bySemanticsLabel('Shade for Rosewood'), findsOneWidget);
      expect(find.text('Rosewood'), findsOneWidget);

      await tester.tap(find.byType(TutorialFinalLookCard));
      await tester.pumpAndSettle();
      expectButton(TutorialLabels.close);
      await tester.tap(find.bySemanticsLabel(TutorialLabels.close));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 2'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('guide and instruction traversal order is explicit', (
      tester,
    ) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.lips],
        plan: _standardPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.lips, 1)],
      );

      List<double> orderedKeys(Finder parent) => tester
          .widgetList<Semantics>(
            find.descendant(of: parent, matching: find.byType(Semantics)),
          )
          .map((semantics) => semantics.properties.sortKey)
          .whereType<OrdinalSortKey>()
          .map((key) => key.order)
          .toList();

      final guideKeys = orderedKeys(find.byType(TutorialGuideKey));
      expect(
        guideKeys,
        List<double>.generate(guideKeys.length, (i) => i.toDouble()),
      );
      final instructionKeys = orderedKeys(
        find.byType(TutorialInstructionsCard),
      );
      expect(
        instructionKeys,
        List<double>.generate(instructionKeys.length, (i) => i.toDouble()),
      );
    });

    testWidgets('footer labels and touch targets survive 2x text', (
      tester,
    ) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[
          TutorialCategory.foundation,
          TutorialCategory.lips,
        ],
        plan: _standardPlan(),
        steps: <TutorialStep>[
          _step(TutorialCategory.foundation, 1),
          _step(TutorialCategory.lips, 2),
        ],
        size: const Size(320, 520),
        textScale: 2,
      );

      final footer = find.byType(TutorialBottomNavigation);
      for (final type in <Type>[SecondaryButton, PrimaryButton]) {
        final button = find.descendant(of: footer, matching: find.byType(type));
        final size = tester.getSize(button);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      for (final label in <String>[
        TutorialLabels.back,
        TutorialLabels.finish_,
      ]) {
        final text = tester.widget<Text>(
          find.descendant(of: footer, matching: find.text(label)),
        );
        expect(text.maxLines, isNull);
        expect(text.overflow, isNull);
      }
      expect(
        find.descendant(
          of: footer,
          matching: find.byIcon(Icons.arrow_back_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: footer, matching: find.byIcon(Icons.check_rounded)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced-motion mode adds no tutorial animation', (
      tester,
    ) async {
      await _pump(
        tester,
        present: const <TutorialCategory>[TutorialCategory.lips],
        plan: _standardPlan(),
        steps: <TutorialStep>[_step(TutorialCategory.lips, 1)],
        finalPreviewUrl: 'https://example.invalid/final.png',
        disableAnimations: true,
      );

      final context = tester.element(find.byType(TutorialPage));
      expect(MediaQuery.disableAnimationsOf(context), isTrue);
      expect(
        find.descendant(
          of: find.byType(TutorialPage),
          matching: find.byType(AnimatedContainer),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(TutorialPage),
          matching: find.byType(AnimatedOpacity),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('theme, text scale, resize, and scroll add zero calls', (
      tester,
    ) async {
      final textScale = ValueNotifier<double>(1);
      addTearDown(textScale.dispose);
      final steps = await _pump(
        tester,
        present: const <TutorialCategory>[
          TutorialCategory.foundation,
          TutorialCategory.eyeshadow,
          TutorialCategory.lips,
        ],
        plan: _standardPlan(),
        steps: <TutorialStep>[
          _step(TutorialCategory.foundation, 1),
          _step(TutorialCategory.eyeshadow, 2),
          _step(TutorialCategory.lips, 3),
        ],
        finalPreviewUrl: 'https://example.invalid/final.png',
        themeMode: ThemeMode.system,
        textScaleNotifier: textScale,
      );
      final before = steps.protectedCallSnapshot;

      textScale.value = 2;
      tester.view.physicalSize = const Size(320, 520);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      tester.platformDispatcher.onPlatformBrightnessChanged?.call();
      await tester.pumpAndSettle();

      final scrollable = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(steps.protectedCallSnapshot, before);
      expect(steps.generateCalls, 0, reason: 'no redraw or AI generation');
      expect(steps.manifestAnalyzeCalls, 0, reason: 'no manifest analysis');
      expect(tester.takeException(), isNull);
    });

    test('the tutorial presentation cannot call preview generation', () {
      final paths = <String>[
        'lib/features/tutorial/presentation/pages/tutorial_page.dart',
        'lib/features/tutorial/presentation/widgets/'
            'tutorial_final_look_card.dart',
      ];
      final source = paths
          .map(
            (path) => File(
              '${Directory.current.path}${Platform.pathSeparator}'
              '${path.replaceAll('/', Platform.pathSeparator)}',
            ).readAsStringSync(),
          )
          .join('\n');
      for (final forbidden in <String>[
        'features/preview/',
        'MakeupPreviewRepository',
        'generatePreview',
        'regeneratePreview',
      ]) {
        expect(source, isNot(contains(forbidden)));
      }
    });
  });
}
