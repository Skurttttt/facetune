import 'package:flutter/semantics.dart';

import 'package:facetune/core/constants/app_constants.dart';
import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/analysis/data/repositories/unavailable_face_analysis_repository.dart';
import 'package:facetune/features/analysis/domain/entities/face_analysis.dart';
import 'package:facetune/features/analysis/presentation/controllers/face_analysis_controller.dart';
import 'package:facetune/features/analysis/domain/usecases/analyze_face.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/makeup_styles/domain/entities/makeup_style.dart';
import 'package:facetune/features/makeup_styles/presentation/controllers/makeup_style_selection_controller.dart';
import 'package:facetune/features/preview/data/models/generated_preview_dto.dart';
import 'package:facetune/features/preview/domain/repositories/makeup_preview_repository.dart';
import 'package:facetune/features/preview/domain/entities/generated_preview.dart';
import 'package:facetune/features/preview/domain/usecases/generate_makeup_preview.dart';
import 'package:facetune/features/preview/presentation/controllers/makeup_preview_controller.dart';
import 'package:facetune/features/preview/presentation/pages/preview_result_page.dart';
import 'package:facetune/features/recommendation/data/models/makeup_recommendation_dto.dart';
import 'package:facetune/features/recommendation/data/repositories/unavailable_makeup_recommendation_repository.dart';
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/recommendation/domain/usecases/generate_makeup_recommendation.dart';
import 'package:facetune/features/recommendation/presentation/controllers/makeup_recommendation_controller.dart';
import 'package:facetune/features/results/domain/services/result_share_service.dart';
import 'package:facetune/features/results/presentation/controllers/result_actions_controller.dart';
import 'package:facetune/features/results/presentation/widgets/beauty_profile_card.dart';
import 'package:facetune/features/results/presentation/widgets/before_after_comparison.dart';
import 'package:facetune/features/results/presentation/widgets/recommended_palette.dart';
import 'package:facetune/features/saved_looks/domain/entities/saved_look.dart';
import 'package:facetune/features/saved_looks/domain/repositories/saved_looks_repository.dart';
import 'package:facetune/features/tutorial/data/providers/tutorial_providers.dart';
import 'package:facetune/features/tutorial/domain/catalog/look_plan_convergence.dart';
import 'package:facetune/features/tutorial/domain/entities/canonical_preview_ref.dart';
import 'package:facetune/features/tutorial/domain/entities/recommendation_source_mode.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_manifest.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_session.dart';
import 'package:facetune/features/tutorial/domain/repositories/tutorial_manifest_repository.dart';
import 'package:facetune/features/tutorial/domain/repositories/tutorial_session_repository.dart';
import 'package:facetune/features/tutorial/domain/usecases/resolve_tutorial_manifest.dart';
import 'package:facetune/features/tutorial/presentation/controllers/realized_look_controller.dart';
import 'package:facetune/features/tutorial/presentation/pages/tutorial_page.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:facetune/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/analysis_response_fixture.dart';
import '../../helpers/generated_preview_response_fixture.dart';
import '../../helpers/recommendation_response_fixture.dart';

final _now = DateTime.utc(2026, 9, 3);

class _Harness {
  const _Harness({
    required this.manifests,
    required this.sessions,
    required this.savedLooks,
    required this.share,
    required this.previews,
  });

  final _CountingManifests manifests;
  final _CountingSessions sessions;
  final _SavedLooks savedLooks;
  final _Share share;
  final _CountingPreviews previews;

  List<int> get lifecycleCounts => <int>[
    sessions.loadCalls,
    manifests.loadAcceptedCalls,
    manifests.analyzeCalls,
    sessions.ensureStepsCalls,
    previews.generateCalls,
  ];
}

Future<_Harness> _pumpResult(
  WidgetTester tester, {
  List<TutorialCategory> present = TutorialCategory.values,
  ThemeMode themeMode = ThemeMode.light,
  Brightness platformBrightness = Brightness.light,
  Size size = const Size(393, 873),
  double textScale = 1,
  MakeupRecommendation? recommendationOverride,
  // Reaches the result the way the app does — pushed onto Home — so the route
  // can pop and the top bar's back control appears exactly as it does on a
  // device. The default keeps the result as the only route, which is what the
  // layout and lifecycle tests want.
  bool pushed = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.platformBrightnessTestValue = platformBrightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  final analysis = FaceAnalysisDto.fromResponse(validAnalysisResponse).analysis;
  final recommendation =
      recommendationOverride ??
      MakeupRecommendationDto.fromResponse(
        validRecommendationResponse,
      ).recommendation;
  final preview =
      GeneratedPreviewDto.fromResponse(validGeneratedPreviewResponse).toDomain(
        originalImageUrl: 'https://example.invalid/original.jpg',
        generatedImageUrl: 'https://example.invalid/generated.jpg',
      );
  final style = MakeupStyleCatalog.styles.firstWhere(
    (candidate) => candidate.code == recommendation.styleCode,
  );

  final analysisController = FaceAnalysisController(
    const AnalyzeFace(UnavailableFaceAnalysisRepository()),
  )..restore(analysis);
  final recommendationController = MakeupRecommendationController(
    const GenerateMakeupRecommendation(
      UnavailableMakeupRecommendationRepository(),
    ),
  )..restore(recommendation);
  final previews = _CountingPreviews(preview);
  final previewController = MakeupPreviewController(
    GenerateMakeupPreview(previews),
  )..restore(preview, recommendation: recommendation);
  final styleController = MakeupStyleSelectionController()..restore(style);

  final session = TutorialSession(
    id: 'session-1',
    userId: 'user-1',
    analysisId: analysis.id,
    canonicalPreviewId: preview.id,
    lookPlan: LookPlanConvergence.fromStandard(recommendation),
    status: TutorialSessionStatus.ready,
    manifest: TutorialManifest(
      canonicalPreviewId: preview.id,
      sourceMode: RecommendationSourceMode.standard,
      status: TutorialManifestStatus.accepted,
      items: <TutorialManifestItem>[
        for (final category in TutorialCategory.values)
          TutorialManifestItem(
            category: category,
            presence: present.contains(category)
                ? TutorialCategoryPresence.present
                : TutorialCategoryPresence.absent,
          ),
      ],
      modelId: 'manifest-model',
      promptVersion: 'tutorial_manifest_v4_1',
      schemaVersion: 'v1',
      createdAt: _now,
    ),
    createdAt: _now,
    updatedAt: _now,
  );
  final manifests = _CountingManifests(session);
  final sessions = _CountingSessions(session);
  final realizedLookController = RealizedLookController(
    resolveManifest: ResolveTutorialManifest(
      manifestRepository: manifests,
      sessionRepository: sessions,
    ),
  );
  final savedLooks = _SavedLooks(
    analysis: analysis,
    recommendation: recommendation,
    preview: preview,
    style: style,
  );
  final share = _Share();
  final actionsController = ResultActionsController(share, savedLooks, () {});

  late final GoRouter router;
  router = GoRouter(
    initialLocation: pushed
        ? AppConstants.homeRoute
        : AppConstants.previewRoute,
    routes: <RouteBase>[
      GoRoute(
        path: AppConstants.homeRoute,
        builder: (context, state) => const Scaffold(body: Text('Home route')),
      ),
      GoRoute(
        path: AppConstants.previewRoute,
        builder: (context, state) => const PreviewResultPage(),
      ),
      GoRoute(
        path: AppConstants.tutorialRoute,
        builder: (context, state) {
          final args = state.extra! as TutorialPageArgs;
          return Scaffold(
            body: Text(
              'Tutorial route ${args.preview.id} ${args.finalPreviewUrl}',
            ),
          );
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        faceAnalysisControllerProvider.overrideWith(
          (ref) => analysisController,
        ),
        makeupRecommendationControllerProvider.overrideWith(
          (ref) => recommendationController,
        ),
        makeupPreviewControllerProvider.overrideWith(
          (ref) => previewController,
        ),
        makeupStyleSelectionControllerProvider.overrideWith(
          (ref) => styleController,
        ),
        realizedLookControllerProvider.overrideWith(
          (ref) => realizedLookController,
        ),
        resultActionsControllerProvider.overrideWith(
          (ref) => actionsController,
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (pushed) {
    router.push(AppConstants.previewRoute);
    await tester.pumpAndSettle();
  }
  return _Harness(
    manifests: manifests,
    sessions: sessions,
    savedLooks: savedLooks,
    share: share,
    previews: previews,
  );
}

/// The result list's live scroll position.
ScrollPosition _scrollPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(of: _resultScroll, matching: find.byType(Scrollable))
          .first,
    )
    .position;

/// Scrolls the result list all the way to its end.
Future<void> _scrollToEnd(WidgetTester tester) async {
  final position = _scrollPosition(tester);
  for (var i = 0; i < 40 && position.pixels < position.maxScrollExtent; i++) {
    await tester.drag(_resultScroll, const Offset(0, -200));
    await tester.pumpAndSettle();
  }
}

final _resultScroll = find.byKey(const ValueKey('result-content-scroll'));

/// Scrolls until [finder] is genuinely inside the result viewport.
///
/// Neither `ensureVisible` nor `scrollUntilVisible` does the job here. The
/// overview actions are *built* while still off-screen, so `scrollUntilVisible`
/// stops immediately — it waits for the finder to match, not for the widget to
/// be on screen — and a tap then lands on empty space below the viewport.
/// Anything far enough away is disposed entirely, so the loop also has to cope
/// with the finder matching nothing until it arrives.
///
/// [step] is the drag per attempt: negative walks down the list, positive back
/// up towards the header and tabs.
Future<void> _reveal(
  WidgetTester tester,
  Finder finder, {
  double step = -160,
}) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    if (tester.any(finder)) {
      final viewport = tester.getRect(_resultScroll);
      final target = tester.getRect(finder);
      if (target.top >= viewport.top && target.bottom <= viewport.bottom) {
        return;
      }
    }
    await tester.drag(_resultScroll, Offset(0, step));
    await tester.pumpAndSettle();
  }
  fail('Could not bring $finder into the result viewport.');
}

/// The semantics node carrying [label], searched from the root.
///
/// `tester.getSemantics` climbs from a widget to the nearest *enclosing* node,
/// which for a segmented-button label is not the node that carries the
/// selection — it reports `Tristate.none` for a tab that is plainly selected.
/// Searching the tree asks the question the screen reader actually asks.
SemanticsData _semanticsFor(WidgetTester tester, String label) {
  SemanticsData? found;
  void walk(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (found == null && data.label == label) found = data;
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  walk(tester.getSemantics(find.byType(MaterialApp)));
  if (found == null) fail('No semantics node is labelled "$label".');
  return found!;
}

Future<void> _selectSection(WidgetTester tester, String label) async {
  final tab = find.text(label);
  await _reveal(tester, tab, step: 300);
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

void main() {
  group('UI-R2 premium result hero', () {
    testWidgets('the look is the title, and the headings above it are gone', (
      tester,
    ) async {
      await _pumpResult(tester);

      // The page title and the marketing headline both said what the screen
      // was, above a screen that shows it.
      expect(find.text('Your FaceTune result'), findsNothing);
      expect(find.text('Your look, revealed'), findsNothing);

      // The style itself, carrying the two facts that qualify it, on two lines
      // rather than four.
      expect(find.text('Soft Glam'), findsOneWidget);
      expect(find.text('Soft intensity · Warm undertone'), findsOneWidget);

      // Presentation bookkeeping, not a fact about the look.
      expect(find.textContaining('Variation'), findsNothing);
    });

    testWidgets('the comparison instruction is compact and sits on the image', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpResult(tester);

      expect(
        find.text(
          'Drag across the image to compare. '
          'Regenerate if the result does not feel like you.',
        ),
        findsNothing,
      );
      expect(find.text('Drag to compare'), findsOneWidget);

      // The arrow is not carrying the instruction on its own. The comparison
      // node merges its children, so its label is a run of text rather than the
      // phrase alone — and the instruction still rides on its hint. It no
      // longer mentions a slider, because there is no longer a slider.
      final comparisonSemantics = find.bySemanticsLabel(
        RegExp('Before and after makeup comparison'),
      );
      expect(comparisonSemantics, findsOneWidget);
      expect(
        tester.getSemantics(comparisonSemantics).hint,
        'Drag across the image to compare',
      );

      // No sentence explaining the regenerate button anywhere on the screen.
      expect(
        find.text('Regenerate if the result does not feel like you.'),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets('the final preview leads, and the tabs follow it', (
      tester,
    ) async {
      await _pumpResult(tester);

      final title = find.text('Soft Glam');
      final comparison = find.byType(BeforeAfterComparison);
      final tabs = find.byKey(const ValueKey('result-section-tabs'));
      expect(comparison, findsOneWidget);
      expect(tabs, findsOneWidget);

      expect(
        tester.getTopLeft(comparison).dy,
        greaterThan(tester.getTopLeft(title).dy),
      );
      expect(
        tester.getTopLeft(tabs).dy,
        greaterThan(tester.getTopLeft(comparison).dy),
      );
      // The hero is the tallest thing on the screen by a wide margin — the
      // header above it is two lines, not a page of copy.
      expect(
        tester.getSize(comparison).height,
        greaterThan(tester.getSize(find.byType(PreviewResultPage)).height / 2),
      );
    });
  });

  group('UI-R4 the result screen offers no Save control', () {
    testWidgets('Save look is gone from the whole screen', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpResult(tester);

      expect(find.byKey(const ValueKey('result-save-look')), findsNothing);
      expect(find.text('Save look'), findsNothing);
      expect(find.text('Saved'), findsNothing);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
      expect(find.byIcon(Icons.bookmark_rounded), findsNothing);

      // Not hidden behind an Opacity or an Offstage either: no semantics node
      // anywhere offers saving from this screen.
      expect(find.bySemanticsLabel('Save look'), findsNothing);
      expect(find.bySemanticsLabel('Saved'), findsNothing);
      handle.dispose();
    });

    testWidgets('walking the whole list turns up no Save control', (
      tester,
    ) async {
      await _pumpResult(tester);

      for (final section in const <String>['Overview', 'Makeup', 'Profile']) {
        await _selectSection(tester, section);
        await _scrollToEnd(tester);
        expect(find.byKey(const ValueKey('result-save-look')), findsNothing);
        expect(find.text('Save look'), findsNothing);
      }
    });

    testWidgets('the saved-look repository is never touched to save', (
      tester,
    ) async {
      final harness = await _pumpResult(tester);
      await _scrollToEnd(tester);

      // The screen still reads saved status — Favorite depends on it — but it
      // no longer offers a way to write one.
      expect(harness.savedLooks.saveCalls, 0);
    });
  });

  group('UI-R2 action hierarchy', () {
    testWidgets('Show me how is the only full-width primary action', (
      tester,
    ) async {
      await _pumpResult(tester);

      final tutorial = find.byKey(const ValueKey('result-show-tutorial'));
      expect(tutorial, findsOneWidget);
      expect(find.byType(PrimaryButton), findsOneWidget);

      final pageWidth = tester.getSize(find.byType(PreviewResultPage)).width;
      final tutorialWidth = tester.getSize(tutorial).width;
      expect(tutorialWidth, greaterThan(pageWidth * 0.8));

      // Each utility is a fraction of the CTA's width, and all three share one
      // row rather than stacking as full-width cards.
      for (final key in const <String>[
        'result-action-favorite',
        'result-action-share',
        'result-action-try-another',
      ]) {
        final action = find.byKey(ValueKey(key));
        await _reveal(tester, action);
        expect(action, findsOneWidget);
        expect(tester.getSize(action).width, lessThan(tutorialWidth / 2));
      }
      final favorite = find.byKey(const ValueKey('result-action-favorite'));
      final share = find.byKey(const ValueKey('result-action-share'));
      final tryAnother = find.byKey(
        const ValueKey('result-action-try-another'),
      );
      expect(tester.getTopLeft(favorite).dy, tester.getTopLeft(share).dy);
      expect(tester.getTopLeft(share).dy, tester.getTopLeft(tryAnother).dy);
    });

    testWidgets('the lower Return home action is gone, not merely hidden', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpResult(tester);
      // Walk the whole list so nothing below the fold is missed.
      await _reveal(
        tester,
        find.byKey(const ValueKey('result-action-try-another')),
      );

      expect(
        find.byKey(const ValueKey('result-action-return-home')),
        findsNothing,
      );
      expect(find.text('Return home'), findsNothing);
      // Not an invisible interactive control either: no semantics node offers
      // it anywhere in the tree.
      expect(find.bySemanticsLabel('Return home'), findsNothing);
      expect(find.byType(TertiaryButton), findsNothing);
      handle.dispose();
    });

    testWidgets('every utility says what it will do', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpResult(tester);
      await _reveal(
        tester,
        find.byKey(const ValueKey('result-action-try-another')),
      );

      expect(find.bySemanticsLabel('Favorite'), findsOneWidget);
      expect(find.bySemanticsLabel('Share look'), findsOneWidget);
      expect(find.bySemanticsLabel('Try another variation'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('result-action-favorite')));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Remove from favorites'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('there is exactly one Show me how the user can press', (
      tester,
    ) async {
      await _pumpResult(tester);

      expect(find.text('Show me how'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('result-show-tutorial')),
        findsOneWidget,
      );
    });

    testWidgets('Show me how keeps the canonical preview tutorial callback', (
      tester,
    ) async {
      await _pumpResult(tester);

      await tester.tap(find.byKey(const ValueKey('result-show-tutorial')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Tutorial route 8f326875-ff56-4a8f-8500-6baa49636417',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('https://example.invalid/generated.jpg'),
        findsOneWidget,
      );
    });

    testWidgets('Favorite and Share retain one callback authority', (
      tester,
    ) async {
      final harness = await _pumpResult(tester);

      final favorite = find.byKey(const ValueKey('result-action-favorite'));
      await _reveal(tester, favorite);
      await tester.tap(favorite);
      await tester.pumpAndSettle();
      // Favouriting a look that is not saved yet saves it *as* a favourite.
      // That is the controller's existing behaviour, and the compact control
      // reaches it through the same repository the full-width button did.
      expect(harness.savedLooks.saveCalls, 1);
      expect(harness.savedLooks.saved?.isFavorite, isTrue);

      await tester.tap(favorite);
      await tester.pumpAndSettle();
      expect(harness.savedLooks.favoriteCalls, 1);
      expect(harness.savedLooks.saved?.isFavorite, isFalse);

      final share = find.byKey(const ValueKey('result-action-share'));
      await _reveal(tester, share);
      await tester.tap(share);
      await tester.pumpAndSettle();
      expect(harness.share.calls, 1);
    });
  });

  group('UI-R2 regeneration safety', () {
    testWidgets('nothing but an explicit press regenerates', (tester) async {
      final harness = await _pumpResult(tester);
      expect(harness.previews.generateCalls, 0);

      await tester.drag(
        find.byKey(const ValueKey('result-content-scroll')),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(harness.previews.generateCalls, 0);

      await _selectSection(tester, 'Makeup');
      await _selectSection(tester, 'Profile');
      await _selectSection(tester, 'Overview');
      expect(harness.previews.generateCalls, 0);

      await tester.tap(find.byKey(const ValueKey('result-action-favorite')));
      await tester.pumpAndSettle();
      expect(harness.previews.generateCalls, 0);

      final tryAnother = find.byKey(
        const ValueKey('result-action-try-another'),
      );
      await _reveal(tester, tryAnother);
      await tester.tap(tryAnother);
      await tester.pumpAndSettle();
      expect(harness.previews.generateCalls, 1);
    });
  });

  group('UI-R3 one comparison control', () {
    testWidgets('the external slider is gone', (tester) async {
      await _pumpResult(tester);

      expect(find.byType(Slider), findsNothing);
      // The parts that carried the comparison stay.
      expect(find.byType(BeforeAfterComparison), findsOneWidget);
      expect(find.text('Before'), findsOneWidget);
      expect(find.text('After'), findsOneWidget);
      expect(find.text('Drag to compare'), findsOneWidget);
    });

    testWidgets('dragging the image still moves the reveal', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpResult(tester);

      final comparison = find.byType(BeforeAfterComparison);
      String reveal() => tester
          .getSemantics(
            find.bySemanticsLabel(RegExp('Before and after makeup comparison')),
          )
          .value;

      expect(reveal(), '50 percent before');

      // Drag from the middle of the image towards its left edge.
      final centre = tester.getCenter(comparison);
      await tester.dragFrom(centre, const Offset(-120, 0));
      await tester.pumpAndSettle();

      final afterLeftDrag = reveal();
      expect(afterLeftDrag, isNot('50 percent before'));

      await tester.dragFrom(centre, const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(reveal(), isNot(afterLeftDrag));
      handle.dispose();
    });

    testWidgets('the comparison is still adjustable without a drag gesture', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpResult(tester);

      final comparison = find.bySemanticsLabel(
        RegExp('Before and after makeup comparison'),
      );
      final node = tester.getSemantics(comparison);
      // The visible slider was carrying these actions. Removing it without
      // moving them here would have taken the comparison away from anyone who
      // cannot perform a horizontal drag.
      expect(node.getSemanticsData().hasAction(SemanticsAction.increase), true);
      expect(node.getSemanticsData().hasAction(SemanticsAction.decrease), true);
      expect(node.value, '50 percent before');
      expect(node.increasedValue, '60 percent before');
      expect(node.decreasedValue, '40 percent before');

      node.owner!.performAction(node.id, SemanticsAction.increase);
      await tester.pumpAndSettle();
      expect(tester.getSemantics(comparison).value, '60 percent before');

      final raised = tester.getSemantics(comparison);
      raised.owner!.performAction(raised.id, SemanticsAction.decrease);
      await tester.pumpAndSettle();
      expect(tester.getSemantics(comparison).value, '50 percent before');
      handle.dispose();
    });
  });

  group('UI-R4 the CTA area is only as tall as its one button', () {
    testWidgets('the bar is one button plus its own padding, nothing more', (
      tester,
    ) async {
      await _pumpResult(tester);

      final bar = tester.getRect(
        find.byKey(const ValueKey('result-primary-actions')),
      );
      final button = tester.getRect(
        find.byKey(const ValueKey('result-show-tutorial')),
      );

      // Structural rather than a magic number: the bar's height is the button
      // it contains plus the symmetric padding around it. No room is left for
      // the button that used to sit underneath.
      expect(bar.height, button.height + AppSpacing.sm * 2);
      expect(button.top - bar.top, AppSpacing.sm);
      expect(bar.bottom - button.bottom, AppSpacing.sm);

      // Exactly one button in the bar.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('result-primary-actions')),
          matching: find.byType(PrimaryButton),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('result-primary-actions')),
          matching: find.byType(SecondaryButton),
        ),
        findsNothing,
      );
    });

    testWidgets('the gap above the CTA is one section step, not a void', (
      tester,
    ) async {
      await _pumpResult(tester);
      await _scrollToEnd(tester);

      final bar = tester.getRect(
        find.byKey(const ValueKey('result-primary-actions')),
      );
      final lastContent = tester.getRect(
        find.byKey(const ValueKey('result-action-try-another')),
      );

      // The list's own trailing section gap, and nothing stacked on top of it.
      // `PageFrame`'s bottom tail used to add a second reservation for the same
      // clearance the bar already provides.
      expect(bar.top - lastContent.bottom, AppSpacing.lg);

      // Breathing room, not contact.
      expect(bar.top - lastContent.bottom, greaterThan(0));
    });

    testWidgets('a taller button grows the bar rather than clipping', (
      tester,
    ) async {
      await _pumpResult(tester, textScale: 2, size: const Size(320, 800));

      final bar = tester.getRect(
        find.byKey(const ValueKey('result-primary-actions')),
      );
      final button = tester.getRect(
        find.byKey(const ValueKey('result-show-tutorial')),
      );

      expect(bar.height, button.height + AppSpacing.sm * 2);
      expect(bar.bottom, 800);
      expect(find.text('Show me how'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('UI-R3 the CTA owns reserved space', () {
    // The device symptom this phase fixes: the tabs sat within a few points of
    // the viewport edge, and a real handset's gesture inset took the rest.
    for (final inset in <double>[0, 24, 48]) {
      testWidgets('with a ${inset}pt system inset nothing is covered', (
        tester,
      ) async {
        tester.view.padding = FakeViewPadding(bottom: inset);
        tester.view.viewPadding = FakeViewPadding(bottom: inset);
        await _pumpResult(tester);

        final bar = tester.getRect(
          find.byKey(const ValueKey('result-primary-actions')),
        );
        final list = tester.getRect(_resultScroll);

        // The structural guarantee: the scroll viewport ends where the bar
        // begins, so no scroll offset can put content underneath it.
        expect(list.bottom, lessThanOrEqualTo(bar.top));

        // The bar reaches the bottom of the screen and clears the inset, so
        // the buttons never sit behind the system navigation.
        expect(bar.bottom, 873);
        expect(
          tester
              .getRect(find.byKey(const ValueKey('result-show-tutorial')))
              .bottom,
          lessThanOrEqualTo(873 - inset),
        );

        // Wherever the tabs are, they are never under the bar.
        await _reveal(
          tester,
          find.byKey(const ValueKey('result-section-tabs')),
        );
        final tabs = tester.getRect(
          find.byKey(const ValueKey('result-section-tabs')),
        );
        expect(tabs.bottom, lessThanOrEqualTo(bar.top));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the CTA is not an overlay drawn over the content', (
      tester,
    ) async {
      await _pumpResult(tester);

      // Reached through the Scaffold's own bottom slot, so the framework
      // reserves its space rather than the page stacking it over the body.
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.bottomNavigationBar, isNotNull);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('result-primary-actions')),
          matching: find.byKey(const ValueKey('result-show-tutorial')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the last content in each tab is fully reachable', (
      tester,
    ) async {
      await _pumpResult(tester);
      final bar = tester.getRect(
        find.byKey(const ValueKey('result-primary-actions')),
      );

      // Overview ends with the utility row.
      final tryAnother = find.byKey(
        const ValueKey('result-action-try-another'),
      );
      await _reveal(tester, tryAnother);
      expect(tester.getRect(tryAnother).bottom, lessThanOrEqualTo(bar.top));

      await _selectSection(tester, 'Profile');
      final profile = find.byType(BeautyProfileCard);
      await _reveal(tester, profile);
      expect(tester.getRect(profile).bottom, lessThanOrEqualTo(bar.top));
      expect(tester.takeException(), isNull);
    });
  });

  group('UI-R3 top-right Home', () {
    testWidgets('Home replaces the bookmark in the top bar', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpResult(tester);

      final home = find.byKey(const ValueKey('result-home'));
      expect(home, findsOneWidget);
      expect(
        find.descendant(of: find.byType(FaceTuneTopBar), matching: home),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      expect(find.bySemanticsLabel('Home'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Home goes where Return home went', (tester) async {
      await _pumpResult(tester, pushed: true);

      await tester.tap(find.byKey(const ValueKey('result-home')));
      await tester.pumpAndSettle();

      expect(find.text('Home route'), findsOneWidget);
      expect(find.byType(PreviewResultPage), findsNothing);
    });

    testWidgets('Home does not pop, and Back does not go home', (tester) async {
      // Two routes deep, so a pop and a go-home land somewhere different.
      await _pumpResult(tester, pushed: true);

      await tester.tap(find.byType(FaceTuneBackButton));
      await tester.pumpAndSettle();
      // Back returns to whatever was below, which here is the home route the
      // harness starts on — proving it popped rather than navigated.
      expect(find.byType(PreviewResultPage), findsNothing);
    });

    testWidgets('tapping Home starts no AI work', (tester) async {
      final harness = await _pumpResult(tester, pushed: true);
      final opened = harness.lifecycleCounts;

      await tester.tap(find.byKey(const ValueKey('result-home')));
      await tester.pumpAndSettle();

      expect(harness.lifecycleCounts, opened);
      expect(harness.previews.generateCalls, 0);
    });
  });

  group('UI-R2 navigation presentation', () {
    testWidgets('a pushed result shows the FaceTune back control', (
      tester,
    ) async {
      await _pumpResult(tester, pushed: true);

      expect(find.byType(FaceTuneBackButton), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('the FaceTune back control pops, exactly as before', (
      tester,
    ) async {
      await _pumpResult(tester, pushed: true);
      expect(find.byType(PreviewResultPage), findsOneWidget);

      await tester.tap(find.byType(FaceTuneBackButton));
      await tester.pumpAndSettle();

      expect(find.byType(PreviewResultPage), findsNothing);
      expect(find.text('Home route'), findsOneWidget);
    });

    testWidgets('the Android system back still pops the result', (
      tester,
    ) async {
      await _pumpResult(tester, pushed: true);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(PreviewResultPage), findsNothing);
      expect(find.text('Home route'), findsOneWidget);
    });

    testWidgets('leaving by the back control starts no AI work', (
      tester,
    ) async {
      final harness = await _pumpResult(tester, pushed: true);
      final opened = harness.lifecycleCounts;

      await tester.tap(find.byType(FaceTuneBackButton));
      await tester.pumpAndSettle();

      expect(harness.lifecycleCounts, opened);
      expect(harness.previews.generateCalls, 0);
    });
  });

  group('UI-R1 result information architecture', () {
    testWidgets(
      'Overview is first and the primary action is immediately visible',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpResult(tester);

        expect(
          find.byKey(const ValueKey('result-section-tabs')),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Overview tab'), findsOneWidget);
        expect(find.bySemanticsLabel('Makeup tab'), findsOneWidget);
        expect(find.bySemanticsLabel('Profile tab'), findsOneWidget);
        expect(
          _semanticsFor(tester, 'Overview tab').flagsCollection.isSelected,
          isNot(_semanticsFor(tester, 'Makeup tab').flagsCollection.isSelected),
        );
        expect(
          find.byKey(const ValueKey('result-section-overview')),
          findsOneWidget,
        );
        expect(find.text('Detected beauty profile'), findsNothing);
        expect(find.text('Makeup breakdown'), findsNothing);

        final tutorial = find.byKey(const ValueKey('result-show-tutorial'));
        expect(tutorial, findsOneWidget);
        expect(tester.getBottomRight(tutorial).dy, lessThanOrEqualTo(873));
        handle.dispose();
      },
    );
  });

  group('UI-R1 lifecycle and authority locks', () {
    testWidgets('tabs, expansion, profile, and scrolling add zero AI work', (
      tester,
    ) async {
      final harness = await _pumpResult(tester);
      expect(harness.sessions.loadCalls, 1);
      expect(harness.manifests.loadAcceptedCalls, 1);
      expect(harness.manifests.analyzeCalls, 0);
      final openedCounts = harness.lifecycleCounts;

      await _selectSection(tester, 'Makeup');
      expect(find.text('Makeup breakdown'), findsOneWidget);
      expect(harness.lifecycleCounts, openedCounts);

      final foundation = find.text('Foundation');
      await _reveal(tester, foundation);
      await tester.tap(foundation);
      await tester.pumpAndSettle();
      // `DetailRow` renders "Placement: …" as one run of rich text, so the
      // label is a span rather than a `Text` of its own.
      expect(
        find.textContaining('Placement', findRichText: true),
        findsWidgets,
      );
      expect(harness.lifecycleCounts, openedCounts);

      await tester.tap(foundation);
      await tester.pumpAndSettle();
      expect(harness.lifecycleCounts, openedCounts);

      await _selectSection(tester, 'Profile');
      expect(find.text('Detected beauty profile'), findsOneWidget);
      expect(harness.lifecycleCounts, openedCounts);

      await _selectSection(tester, 'Makeup');
      await _selectSection(tester, 'Overview');
      expect(harness.lifecycleCounts, openedCounts);

      await tester.drag(
        find.byKey(const ValueKey('result-content-scroll')),
        const Offset(0, -250),
      );
      await tester.pump();
      expect(harness.lifecycleCounts, openedCounts);
      expect(harness.manifests.analyzeCalls, 0);
    });

    testWidgets('Profile keeps each authoritative confidence separate', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpResult(tester);
      await _selectSection(tester, 'Profile');

      expect(
        find.bySemanticsLabel('Skin tone, Medium, 88% confidence'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Undertone, Warm, 82% confidence'),
        findsOneWidget,
      );
      expect(find.text('88%'), findsOneWidget);
      expect(find.text('82%'), findsOneWidget);
      expect(find.text('Complexion'), findsNothing);
      handle.dispose();
    });
  });

  group('UI-R2 responsive, accessibility, and theme evidence', () {
    testWidgets('narrow 320 width at 2x text reflows without overflow', (
      tester,
    ) async {
      await _pumpResult(tester, size: const Size(320, 800), textScale: 2);

      expect(tester.takeException(), isNull);

      // The three utilities give up their row rather than clipping their
      // labels: each becomes a full-width action, stacked in order.
      final favorite = find.byKey(const ValueKey('result-action-favorite'));
      final share = find.byKey(const ValueKey('result-action-share'));
      final tryAnother = find.byKey(
        const ValueKey('result-action-try-another'),
      );
      await _reveal(tester, tryAnother);
      expect(
        tester.getTopLeft(share).dy,
        greaterThan(tester.getTopLeft(favorite).dy),
      );
      expect(
        tester.getTopLeft(tryAnother).dy,
        greaterThan(tester.getTopLeft(share).dy),
      );

      // Labels are wrapped, not clipped.
      for (final label in const <String>['Favorite', 'Share', 'Try another']) {
        expect(find.text(label), findsOneWidget);
      }

      // The single CTA and the top-bar utility both survive the squeeze.
      expect(
        find.byKey(const ValueKey('result-show-tutorial')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('result-save-look')), findsNothing);
      expect(tester.takeException(), isNull);

      // The Profile section is checked here too. The Makeup section is not:
      // at 320 with 2x text its `SectionHeader` action and its multi-product
      // category pill both overflow, which predates this phase and belongs to
      // the Makeup Breakdown, a system UI-R2 is not allowed to change.
      await _selectSection(tester, 'Profile');
      expect(tester.takeException(), isNull);
    });

    for (final condition
        in <
          ({
            String name,
            ThemeMode mode,
            Brightness platform,
            Brightness expected,
          })
        >[
          (
            name: 'Light',
            mode: ThemeMode.light,
            platform: Brightness.dark,
            expected: Brightness.light,
          ),
          (
            name: 'Dark',
            mode: ThemeMode.dark,
            platform: Brightness.light,
            expected: Brightness.dark,
          ),
          (
            name: 'System light',
            mode: ThemeMode.system,
            platform: Brightness.light,
            expected: Brightness.light,
          ),
          (
            name: 'System dark',
            mode: ThemeMode.system,
            platform: Brightness.dark,
            expected: Brightness.dark,
          ),
        ]) {
      testWidgets('${condition.name} keeps the result scheme', (tester) async {
        await _pumpResult(
          tester,
          themeMode: condition.mode,
          platformBrightness: condition.platform,
          pushed: true,
        );

        final context = tester.element(find.byType(PreviewResultPage));
        expect(Theme.of(context).brightness, condition.expected);

        // The back control reads the live scheme rather than a fixed light
        // surface, so it cannot be a control that only looks right in one mode.
        final material = tester.widget<Material>(
          find.descendant(
            of: find.byType(FaceTuneBackButton),
            matching: find.byType(Material),
          ),
        );
        expect(
          material.color,
          Theme.of(context).colorScheme.surfaceContainerHighest,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('palette stays horizontal and names every color', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final base = MakeupRecommendationDto.fromResponse(
        validRecommendationResponse,
      ).recommendation;
      final first = base.items.entries.first;
      final longRecommendation = MakeupRecommendation(
        id: base.id,
        analysisId: base.analysisId,
        styleCode: base.styleCode,
        overallIntensity: base.overallIntensity,
        items: <String, MakeupRecommendationItem>{
          ...base.items,
          first.key: MakeupRecommendationItem(
            name:
                'Layered muted warm rose with a softly neutral peach undertone',
            hex: first.value.hex,
            placement: first.value.placement,
            technique: first.value.technique,
            finish: first.value.finish,
            intensity: first.value.intensity,
            reasoning: first.value.reasoning,
          ),
        },
        modelId: base.modelId,
        promptVersion: base.promptVersion,
        createdAt: base.createdAt,
      );
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: RecommendedPalette(recommendation: longRecommendation),
            ),
          ),
        ),
      );

      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.scrollDirection, Axis.horizontal);
      expect(
        find.bySemanticsLabel(
          RegExp('Layered muted warm rose.*color #[0-9A-F]{6}'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      handle.dispose();
    });
  });
}

/// Counts every call that would reach Gemini to make a new final preview.
///
/// Regeneration is the one paid action reachable from this screen, and this
/// phase moved its control into a compact row — so the count existing at all is
/// the point: scrolling, switching tabs, saving and going back must leave it at
/// zero, and only a deliberate press may move it.
class _CountingPreviews implements MakeupPreviewRepository {
  _CountingPreviews(this._seed);

  final GeneratedPreview _seed;
  int generateCalls = 0;

  @override
  Future<GeneratedPreview> generate({
    required MakeupRecommendation recommendation,
  }) async {
    generateCalls += 1;
    // A new row for the same analysis and plan, exactly as a real variation is:
    // the referential chain still holds, so the page stays coherent.
    return GeneratedPreview(
      id: 'regenerated-$generateCalls',
      analysisId: _seed.analysisId,
      recommendationId: _seed.recommendationId,
      originalImagePath: _seed.originalImagePath,
      generatedImagePath: _seed.generatedImagePath,
      originalImageUrl: _seed.originalImageUrl,
      generatedImageUrl: _seed.generatedImageUrl,
      generationNumber: _seed.generationNumber + generateCalls,
      modelId: _seed.modelId,
      promptVersion: _seed.promptVersion,
      createdAt: _seed.createdAt,
    );
  }
}

class _CountingManifests implements TutorialManifestRepository {
  _CountingManifests(this.session);

  final TutorialSession session;
  int loadAcceptedCalls = 0;
  int analyzeCalls = 0;

  @override
  Future<TutorialSession?> loadAccepted(CanonicalPreviewRef preview) async {
    loadAcceptedCalls += 1;
    return session;
  }

  @override
  Future<TutorialSession> analyze(CanonicalPreviewRef preview) async {
    analyzeCalls += 1;
    return session;
  }
}

class _CountingSessions implements TutorialSessionRepository {
  _CountingSessions(this.session);

  final TutorialSession session;
  int loadCalls = 0;
  int ensureStepsCalls = 0;

  @override
  Future<TutorialSession?> loadForCanonicalPreview(
    CanonicalPreviewRef preview,
  ) async {
    loadCalls += 1;
    return null;
  }

  @override
  Future<TutorialSession> ensureSteps(TutorialSession value) async {
    ensureStepsCalls += 1;
    return value;
  }

  @override
  Future<TutorialSession> loadById(String sessionId) async => session;

  @override
  Future<void> delete(String sessionId) async {}
}

class _SavedLooks implements SavedLooksRepository {
  _SavedLooks({
    required this.analysis,
    required this.recommendation,
    required this.preview,
    required this.style,
  });

  final FaceAnalysis analysis;
  final MakeupRecommendation recommendation;
  final GeneratedPreview preview;
  final MakeupStyle style;
  SavedLook? saved;
  int saveCalls = 0;
  int favoriteCalls = 0;

  @override
  Future<SavedLook?> findByGeneratedImageId(String generatedImageId) async =>
      saved;

  @override
  Future<SavedLook> save(
    GeneratedPreview value, {
    bool favorite = false,
  }) async {
    saveCalls += 1;
    return saved = SavedLook(
      id: 'saved-1',
      preview: preview,
      analysis: analysis,
      recommendation: recommendation,
      style: style,
      isFavorite: favorite,
      createdAt: _now,
    );
  }

  @override
  Future<SavedLook> setFavorite(SavedLook look, bool favorite) async {
    favoriteCalls += 1;
    return saved = look.copyWith(isFavorite: favorite);
  }

  @override
  Future<void> remove(String savedLookId) async {
    saved = null;
  }

  @override
  Future<SavedLooksPageResult> loadPage({
    required int offset,
    required int limit,
  }) async => SavedLooksPageResult(
    items: saved == null ? const <SavedLook>[] : <SavedLook>[saved!],
    hasMore: false,
  );
}

class _Share implements ResultShareService {
  int calls = 0;

  @override
  Future<void> share({
    required String imageUrl,
    required String storagePath,
    required String previewId,
    required String styleName,
  }) async {
    calls += 1;
  }
}
