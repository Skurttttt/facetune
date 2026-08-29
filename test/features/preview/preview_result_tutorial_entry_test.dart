import 'dart:io';

import 'package:facetune/core/constants/app_constants.dart';
import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/analysis/domain/entities/face_analysis.dart';
import 'package:facetune/features/analysis/presentation/controllers/face_analysis_controller.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/makeup_styles/domain/entities/makeup_style.dart';
import 'package:facetune/features/makeup_styles/presentation/controllers/makeup_style_selection_controller.dart';
import 'package:facetune/features/preview/data/models/generated_preview_dto.dart';
import 'package:facetune/features/preview/domain/entities/generated_preview.dart';
import 'package:facetune/features/preview/presentation/controllers/makeup_preview_controller.dart';
import 'package:facetune/features/preview/presentation/pages/preview_result_page.dart';
import 'package:facetune/features/recommendation/data/models/makeup_recommendation_dto.dart';
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/recommendation/presentation/controllers/makeup_recommendation_controller.dart';
import 'package:facetune/features/results/presentation/widgets/result_actions.dart';
import 'package:facetune/features/saved_looks/data/providers/saved_looks_providers.dart';
import 'package:facetune/features/saved_looks/domain/entities/saved_look.dart';
import 'package:facetune/features/saved_looks/domain/repositories/saved_looks_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/analysis_response_fixture.dart';
import '../../helpers/fake_auth_repository.dart';
import '../../helpers/generated_preview_response_fixture.dart';
import '../../helpers/recommendation_response_fixture.dart';

/// V3-10F — the real call site, not the widget in isolation.
///
/// V3-10 shipped the tutorial route, the entry page, the server-side resolver
/// and an `onOpenTutorial` slot on [ResultActions] — and then never passed the
/// callback from the screen that renders it. Every existing test passed,
/// because each one covered a piece: the route constant, the entry page, the
/// RPC, and `ResultActions` constructed by hand inside the test itself. None
/// of them pumped the production widget tree, so the button was unreachable in
/// the app while the suite reported success.
///
/// These tests drive the real [PreviewResultPage] under a real router and
/// assert where a tap actually lands.
void main() {
  final softGlam = MakeupStyleCatalog.styles.firstWhere(
    (style) => style.code == 'soft_glam',
  );
  final analysis = FaceAnalysisDto.fromResponse(validAnalysisResponse).analysis;
  final recommendation = MakeupRecommendationDto.fromResponse(
    validRecommendationResponse,
  ).recommendation;
  final preview =
      GeneratedPreviewDto.fromResponse(validGeneratedPreviewResponse).toDomain(
        originalImageUrl: 'https://storage.test/original.jpg',
        generatedImageUrl: 'https://storage.test/generated.png',
      );

  late _FakeSavedLooksRepository savedLooks;
  late List<String> pushedLocations;

  setUp(() {
    savedLooks = _FakeSavedLooksRepository();
    pushedLocations = <String>[];
  });

  /// Pumps the production result screen with the controllers restored the way
  /// the app restores them, then hands back the container so a test can drive
  /// it further.
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    GeneratedPreview? restoredPreview,
    MakeupRecommendation? restoredRecommendation,
    MakeupStyle? restoredStyle,
    FaceAnalysis? restoredAnalysis,
  }) async {
    // The result screen is a lazily built list taller than the default 800x600
    // viewport, so the actions are never constructed at that size and every
    // finder reports "not found" for the wrong reason.
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer(
      overrides: [
        // The stand-in repositories, so nothing reaches for an uninitialised
        // Supabase client. The saved-looks repository is the only one this
        // screen actually calls, and it is faked below.
        supabaseAvailableProvider.overrideWithValue(false),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            user: const AuthUser(id: 'user-1', isAnonymous: false),
          ),
        ),
        savedLooksRepositoryProvider.overrideWithValue(savedLooks),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(faceAnalysisControllerProvider.notifier)
        .restore(restoredAnalysis ?? analysis);
    container
        .read(makeupStyleSelectionControllerProvider.notifier)
        .restore(restoredStyle ?? softGlam);
    container
        .read(makeupRecommendationControllerProvider.notifier)
        .restore(restoredRecommendation ?? recommendation);
    if (restoredPreview != null) {
      container
          .read(makeupPreviewControllerProvider.notifier)
          .restore(
            restoredPreview,
            recommendation: restoredRecommendation ?? recommendation,
          );
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: AppConstants.previewRoute,
            routes: [
              GoRoute(
                path: AppConstants.previewRoute,
                builder: (context, state) => const PreviewResultPage(),
              ),
              GoRoute(
                // The real route pattern. Recording the full location proves
                // what the screen pushed, rather than re-deriving it with the
                // same expression the production builder uses.
                path: AppConstants.tutorialRoute,
                builder: (context, state) {
                  pushedLocations.add(state.uri.toString());
                  return const Scaffold(body: Center(child: Text('tutorial')));
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tapTutorial(WidgetTester tester) async {
    final button = find.text('Step-by-step tutorial');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('the standard preview offers the tutorial', () {
    testWidgets('the real result screen renders the action', (tester) async {
      await pump(tester, restoredPreview: preview);

      expect(find.text('Step-by-step tutorial'), findsOneWidget);
    });

    testWidgets('the production call site supplies the callback', (
      tester,
    ) async {
      // The defect was precisely this: the widget declared the slot and the
      // screen left it null, so the button silently vanished.
      await pump(tester, restoredPreview: preview);

      final actions = tester.widget<ResultActions>(find.byType(ResultActions));
      expect(actions.onOpenTutorial, isNotNull);
    });

    testWidgets('tapping it navigates to the tutorial route', (tester) async {
      await pump(tester, restoredPreview: preview);
      await tapTutorial(tester);

      expect(pushedLocations, hasLength(1));
      expect(pushedLocations.single, AppConstants.tutorialPathFor(preview.id));
      expect(find.text('tutorial'), findsOneWidget);
    });

    testWidgets('the route names the canonical preview and nothing else', (
      tester,
    ) async {
      await pump(tester, restoredPreview: preview);
      await tapTutorial(tester);

      final location = pushedLocations.single;
      expect(location, '/tutorial/${preview.id}');
      // Not the analysis, not the recommendation, not a storage path, not a
      // signed URL. The V3-10 trust boundary is that the client can name only
      // the preview; everything else is resolved server-side under RLS.
      expect(location.contains(preview.analysisId), isFalse);
      expect(location.contains(preview.recommendationId), isFalse);
      expect(location.contains(preview.generatedImagePath), isFalse);
      expect(location.contains(preview.originalImagePath), isFalse);
      expect(location.contains('http'), isFalse);
    });

    testWidgets('it pushes, so back returns to the result', (tester) async {
      await pump(tester, restoredPreview: preview);
      await tapTutorial(tester);
      expect(find.text('tutorial'), findsOneWidget);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.text('Step-by-step tutorial'), findsOneWidget);
      expect(find.text('tutorial'), findsNothing);
    });

    testWidgets('the standard entry carries no kit flag', (tester) async {
      await pump(tester, restoredPreview: preview);
      await tapTutorial(tester);

      expect(pushedLocations.single.contains('kit'), isFalse);
    });
  });

  group('a look reopened from history offers the same action', () {
    testWidgets('history reaches the tutorial through the result screen', (
      tester,
    ) async {
      // This is exactly what HistoryPage._open does for a complete entry:
      // restore analysis, style and recommendation, restore the persisted
      // preview into the preview controller, then push the preview route.
      // Nothing about the screen distinguishes it from a fresh generation, so
      // the same action is offered and resolves the same persisted preview id.
      await pump(tester, restoredPreview: preview);
      await tapTutorial(tester);

      expect(pushedLocations.single, AppConstants.tutorialPathFor(preview.id));
    });

    test(
      'history routes into the shared result screen, not its own tutorial',
      () {
        final history = File(
          'lib/features/history/presentation/pages/history_page.dart',
        ).readAsStringSync();

        // A complete history entry is restored and pushed onto the preview
        // route, which is why no separate history tutorial entry exists.
        expect(
          history,
          contains('.restore(preview, recommendation: recommendation)'),
        );
        expect(history, contains('context.push(AppConstants.previewRoute)'));
        // If a second, parallel tutorial entry ever appears here, it needs its
        // own review — the supported path is the shared result surface.
        expect(history.contains('tutorialPathFor'), isFalse);
      },
    );
  });

  group('no action without a usable preview', () {
    testWidgets('an unlinked result offers no tutorial', (tester) async {
      // The preview no longer matches the active recommendation, so the screen
      // falls back to "Result links unavailable" and renders no actions at all.
      await pump(
        tester,
        restoredPreview: preview,
        restoredRecommendation: recommendation,
        restoredAnalysis: analysis,
        restoredStyle: MakeupStyleCatalog.styles.firstWhere(
          (style) => style.code != recommendation.styleCode,
        ),
      );

      expect(find.text('Result links unavailable'), findsOneWidget);
      expect(find.text('Step-by-step tutorial'), findsNothing);
      expect(find.byType(ResultActions), findsNothing);
    });

    testWidgets('a screen with no preview offers no tutorial', (tester) async {
      await pump(tester);

      expect(find.text('Result unavailable'), findsOneWidget);
      expect(find.text('Step-by-step tutorial'), findsNothing);
      expect(pushedLocations, isEmpty);
    });
  });

  group('the existing result actions are unchanged', () {
    testWidgets('every previous action is still offered', (tester) async {
      await pump(tester, restoredPreview: preview);

      expect(find.text('Save look'), findsOneWidget);
      expect(find.text('Favorite'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Generate another variation'), findsOneWidget);
      expect(find.text('Return home'), findsOneWidget);
    });

    testWidgets('saving still reaches the repository', (tester) async {
      await pump(tester, restoredPreview: preview);

      final save = find.text('Save look');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(savedLooks.saved, [preview.id]);
      expect(pushedLocations, isEmpty);
    });
  });
}

class _FakeSavedLooksRepository implements SavedLooksRepository {
  final List<String> saved = <String>[];

  @override
  Future<SavedLook?> findByGeneratedImageId(String generatedImageId) async =>
      null;

  @override
  Future<SavedLook> save(
    GeneratedPreview preview, {
    bool favorite = false,
  }) async {
    saved.add(preview.id);
    return SavedLook(
      id: 'saved-1',
      preview: preview,
      analysis: FaceAnalysisDto.fromResponse(validAnalysisResponse).analysis,
      recommendation: MakeupRecommendationDto.fromResponse(
        validRecommendationResponse,
      ).recommendation,
      style: MakeupStyleCatalog.styles.firstWhere(
        (style) => style.code == 'soft_glam',
      ),
      isFavorite: favorite,
      createdAt: DateTime.utc(2026, 8, 28),
    );
  }

  @override
  Object noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
