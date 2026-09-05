import 'dart:async';

import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/analysis/data/providers/analysis_providers.dart';
import 'package:facetune/features/analysis/data/repositories/unavailable_face_analysis_repository.dart';
import 'package:facetune/features/analysis/domain/entities/face_analysis.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/history/data/providers/history_providers.dart';
import 'package:facetune/features/history/domain/entities/history_entry.dart';
import 'package:facetune/features/history/domain/errors/history_failure.dart';
import 'package:facetune/features/history/domain/repositories/history_repository.dart';
import 'package:facetune/features/history/presentation/controllers/history_controller.dart';
import 'package:facetune/features/history/presentation/controllers/history_state.dart';
import 'package:facetune/features/history/presentation/pages/history_page.dart';
import 'package:facetune/features/history/presentation/widgets/history_card.dart';
import 'package:facetune/features/history/presentation/widgets/history_card_skeleton.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_library_providers.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_look_providers.dart';
import 'package:facetune/features/makeup_kit/data/repositories/unavailable_makeup_kit_look_repository.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_generated_preview.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_look_result.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_library_repository.dart';
import 'package:facetune/features/makeup_kit/domain/errors/makeup_kit_library_failure.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_history_controller.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_library_state.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/preview/data/providers/preview_providers.dart';
import 'package:facetune/features/preview/data/repositories/unavailable_makeup_preview_repository.dart';
import 'package:facetune/features/recommendation/data/providers/recommendation_providers.dart';
import 'package:facetune/features/recommendation/data/repositories/unavailable_makeup_recommendation_repository.dart';
import 'package:facetune/features/saved_looks/data/providers/saved_looks_providers.dart';
import 'package:facetune/features/saved_looks/data/repositories/unavailable_saved_looks_repository.dart';
import 'package:facetune/features/saved_looks/domain/entities/saved_look.dart';
import 'package:facetune/features/saved_looks/domain/repositories/saved_looks_repository.dart';
import 'package:facetune/features/preview/domain/entities/generated_preview.dart';
import 'package:facetune/theme/app_semantics.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/analysis_response_fixture.dart';
import '../../helpers/fake_auth_repository.dart';

void main() {
  group('HIST-UI-5 refresh keeps the feed', () {
    test('a reload does not empty the list while it is in flight', () async {
      final repository = _FakeHistoryRepository(page: _page(['a', 'b']));
      final controller = _controller(repository);
      await controller.loadInitial();
      expect(controller.state.items, hasLength(2));

      repository.page = _page(['a', 'b', 'c']);
      repository.hold();
      final pending = controller.refresh();

      // Mid-flight: the rows the user is looking at are still there.
      expect(controller.state.status, HistoryLoadStatus.refreshing);
      expect(controller.state.items.map((item) => item.id), ['a', 'b']);

      repository.release();
      await pending;

      expect(controller.state.status, HistoryLoadStatus.ready);
      expect(controller.state.items.map((item) => item.id), ['a', 'b', 'c']);
      controller.dispose();
    });

    test('a failed reload keeps the feed and reports as an error', () async {
      final repository = _FakeHistoryRepository(page: _page(['a', 'b']));
      final controller = _controller(repository);
      await controller.loadInitial();

      repository.failure = const HistoryFailure('The network dropped.');
      await controller.refresh();

      expect(controller.state.items.map((item) => item.id), ['a', 'b']);
      expect(controller.state.status, HistoryLoadStatus.ready);
      expect(controller.state.feedback, 'The network dropped.');
      // Without this the failure arrives in the same tone as "Added to
      // favorites."
      expect(controller.state.feedbackIsError, isTrue);
      controller.dispose();
    });

    test('an expired session on reload still offers recovery', () async {
      final repository = _FakeHistoryRepository(page: _page(['a']));
      final controller = _controller(repository);
      await controller.loadInitial();

      repository.failure = const HistoryFailure(
        'Your session expired.',
        sessionExpired: true,
      );
      await controller.refresh();

      expect(controller.state.sessionExpired, isTrue);
      expect(controller.state.items, hasLength(1));
      controller.dispose();
    });

    test('reloading an empty feed falls back to the first-load path', () async {
      final repository = _FakeHistoryRepository(page: _page([]));
      final controller = _controller(repository);
      await controller.loadInitial();
      expect(controller.state.items, isEmpty);

      repository.page = _page(['a']);
      await controller.refresh();

      // Nothing was on screen to protect, so skeletons are the honest state.
      expect(controller.state.items.map((item) => item.id), ['a']);
      controller.dispose();
    });

    test('overlapping reloads fetch once and never duplicate rows', () async {
      final repository = _FakeHistoryRepository(page: _page(['a', 'b']));
      final controller = _controller(repository);
      await controller.loadInitial();
      final loadsAfterFirst = repository.loadCalls;

      repository.page = _page(['a', 'b']);
      repository.hold();
      final first = controller.refresh();
      final second = controller.refresh();
      // A reload also blocks paging, so the two cannot interleave.
      await controller.loadMore();
      repository.release();
      await Future.wait([first, second]);

      expect(repository.loadCalls, loadsAfterFirst + 1);
      expect(controller.state.items.map((item) => item.id), ['a', 'b']);
      controller.dispose();
    });

    test('My Kit history reloads under the same rules', () async {
      final repository = _FakeKitRepository(items: [_kitEntry('kit-a')]);
      final controller = _kitController(repository);
      await controller.loadInitial();
      expect(controller.state.items, hasLength(1));

      repository.hold();
      final pending = controller.refresh();
      expect(controller.state.status, MakeupKitLibraryStatus.refreshing);
      expect(controller.state.items, hasLength(1));
      repository.release();
      await pending;
      expect(controller.state.status, MakeupKitLibraryStatus.ready);

      repository.shouldFail = true;
      await controller.refresh();
      expect(controller.state.items, hasLength(1));
      expect(controller.state.status, MakeupKitLibraryStatus.ready);
      controller.dispose();
    });
  });

  group('HIST-UI-5 session state on the page', () {
    testWidgets('a reload leaves the feed and the scroll offset alone', (
      tester,
    ) async {
      // Enough rows to overflow the viewport with room to spare. Six used to
      // overflow it by a hair; POLISH-P1 gave the viewport back the 32 points
      // `PageFrame` was holding below it, and six then fit exactly, leaving
      // nothing to scroll and this test asserting against a zero offset.
      final history = _FakeHistoryRepository(
        page: _page([for (var i = 0; i < 14; i++) 'row-$i']),
      );
      await _pumpPage(tester, history: history);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      final offset = _offset(tester);
      expect(offset, greaterThan(0));

      // What returning from a favorited preview triggers.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HistoryPage)),
      );
      container.read(savedLooksRevisionProvider.notifier).state++;
      await tester.pump();

      // Mid-reload the rows are still there, so the position cannot collapse.
      expect(find.byType(HistoryCard), findsWidgets);
      expect(find.byType(HistoryCardSkeleton), findsNothing);
      expect(_offset(tester), offset);

      await tester.pumpAndSettle();
      expect(_offset(tester), offset);
      expect(find.byType(HistoryCard), findsWidgets);
    });

    testWidgets('type, status and query survive an opened record', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        history: _FakeHistoryRepository(page: _page(['a', 'b'])),
      );

      await tester.enterText(find.byType(TextField), 'everyday');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Recommendations'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Completed'));
      await tester.pumpAndSettle();

      // Stand in for pushing a record and popping back: the page is rebuilt
      // under the same element, exactly as it is when a route above it closes.
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        _selectedChips(tester),
        containsAll(['Recommendations', 'Completed']),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'everyday',
      );
      // Sort was the fourth thing this test carried across the round trip.
      // POLISH-P1 removed the control, so there is no longer any order for a
      // return journey to preserve or to lose.
      expect(find.text('Sort'), findsNothing);
    });

    testWidgets('the search box can never disagree with the filtered feed', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        history: _FakeHistoryRepository(page: _page(['a'])),
      );

      await tester.enterText(find.byType(TextField), 'nothing matches this');
      await tester.pumpAndSettle();

      // HIST-UI-7 renamed this state; the point of this test is the one below.
      expect(find.text('No matches found'), findsOneWidget);
      // The uncontrolled field used to leave an empty box over a filtered feed.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'nothing matches this',
      );
    });

    testWidgets('the feed carries a page storage key for its offset', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        history: _FakeHistoryRepository(page: _page(['a'])),
      );

      expect(
        tester.widget<CustomScrollView>(find.byType(CustomScrollView)).key,
        const PageStorageKey('history-feed'),
      );
    });

    testWidgets(
      'a failed reload keeps the rows and says so in the error tone',
      (tester) async {
        final history = _FakeHistoryRepository(page: _page(['a', 'b']));
        await _pumpPage(tester, history: history);
        expect(find.byType(HistoryCard), findsNWidgets(2));

        history.failure = const HistoryFailure('The network dropped.');
        await tester.fling(
          find.byType(CustomScrollView),
          const Offset(0, 400),
          1000,
        );
        await tester.pumpAndSettle();

        // The feed the user was reading is untouched, and the page never falls
        // back to the whole-screen error state.
        expect(find.byType(HistoryCard), findsNWidgets(2));
        expect(find.text('History unavailable'), findsNothing);
        expect(find.text('The network dropped.'), findsOneWidget);

        // And it arrives in the danger tone, not the one "Added to favorites."
        // uses.
        final danger = AppTheme.lightTheme
            .extension<AppSemantics>()!
            .danger
            .feedbackSurface;
        expect(
          tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
          danger,
        );
      },
    );

    testWidgets('pull to refresh performs one fetch per authority', (
      tester,
    ) async {
      final history = _FakeHistoryRepository(page: _page(['a', 'b']));
      final kit = _FakeKitRepository(items: [_kitEntry('kit-a')]);
      await _pumpPage(tester, history: history, kit: kit);
      final historyLoads = history.loadCalls;
      final kitLoads = kit.loadCalls;

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(history.loadCalls, historyLoads + 1);
      expect(kit.loadCalls, kitLoads + 1);
      expect(find.byType(HistoryCard), findsNWidgets(3));
    });
  });
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

double _offset(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable).first)
    .position
    .pixels;

Iterable<String> _selectedChips(WidgetTester tester) => tester
    .widgetList<FilterChip>(find.byType(FilterChip))
    .where((chip) => chip.selected)
    .map((chip) => ((chip.label as Text).data)!);

HistoryController _controller(HistoryRepository repository) =>
    HistoryController(repository, _NoopSavedLooksRepository(), () {});

MakeupKitHistoryController _kitController(
  MakeupKitLibraryRepository repository,
) => MakeupKitHistoryController(repository, () {});

Future<void> _pumpPage(
  WidgetTester tester, {
  required _FakeHistoryRepository history,
  _FakeKitRepository? kit,
}) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final auth = FakeAuthRepository(
    user: const AuthUser(id: 'history-user', isAnonymous: false),
  );
  addTearDown(auth.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(auth),
        historyRepositoryProvider.overrideWithValue(history),
        makeupKitLibraryRepositoryProvider.overrideWithValue(
          kit ?? _FakeKitRepository(),
        ),
        savedLooksRepositoryProvider.overrideWithValue(
          const UnavailableSavedLooksRepository(),
        ),
        makeupPreviewRepositoryProvider.overrideWithValue(
          const UnavailableMakeupPreviewRepository(),
        ),
        faceAnalysisRepositoryProvider.overrideWithValue(
          const UnavailableFaceAnalysisRepository(),
        ),
        makeupRecommendationRepositoryProvider.overrideWithValue(
          const UnavailableMakeupRecommendationRepository(),
        ),
        makeupKitLookRepositoryProvider.overrideWithValue(
          const UnavailableMakeupKitLookRepository(),
        ),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const HistoryPage()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Answers every load with whatever [page] currently holds, so a test can say
/// what the server returns on the *next* fetch without juggling a queue.
class _FakeHistoryRepository implements HistoryRepository {
  _FakeHistoryRepository({required this.page});

  HistoryPageResult page;
  HistoryFailure? failure;
  int loadCalls = 0;
  Completer<void>? _gate;

  void hold() => _gate = Completer<void>();
  void release() => _gate?.complete();

  @override
  Future<HistoryPageResult> loadPage({
    required int offset,
    required int limit,
  }) async {
    loadCalls += 1;
    await _gate?.future;
    final currentFailure = failure;
    if (currentFailure != null) throw currentFailure;
    return offset >= page.items.length
        ? HistoryPageResult(items: const [], hasMore: false, nextOffset: offset)
        : page;
  }

  @override
  Future<void> deleteSession(String analysisId) async {}
}

class _FakeKitRepository implements MakeupKitLibraryRepository {
  _FakeKitRepository({List<KitHistoryEntry> items = const []})
    : items = [...items];

  final List<KitHistoryEntry> items;
  bool shouldFail = false;
  int loadCalls = 0;
  Completer<void>? _gate;

  void hold() => _gate = Completer<void>();
  void release() => _gate?.complete();

  @override
  Future<KitHistoryPageResult> loadHistoryPage({
    required int offset,
    required int limit,
  }) async {
    loadCalls += 1;
    await _gate?.future;
    if (shouldFail) throw const MakeupKitLibraryFailure('Kit reload failed.');
    return KitHistoryPageResult(
      items: offset >= items.length ? const [] : items,
      hasMore: false,
    );
  }

  @override
  Future<void> deleteSession(String analysisId) async {}

  @override
  Future<KitSavedLook?> findSaved(String kitGeneratedImageId) async => null;

  @override
  Future<KitSavedLook> save(
    KitGeneratedPreview preview, {
    bool favorite = false,
  }) => throw UnimplementedError();

  @override
  Future<KitSavedLook> setFavorite(KitSavedLook look, bool isFavorite) =>
      throw UnimplementedError();

  @override
  Future<void> removeSaved(String savedLookId) => throw UnimplementedError();

  @override
  Future<KitSavedLooksPageResult> loadSavedPage({
    required int offset,
    required int limit,
  }) async => const KitSavedLooksPageResult(items: [], hasMore: false);
}

class _NoopSavedLooksRepository implements SavedLooksRepository {
  @override
  Future<SavedLook> save(GeneratedPreview preview, {bool favorite = false}) =>
      throw UnimplementedError();

  @override
  Future<SavedLook> setFavorite(SavedLook look, bool favorite) =>
      throw UnimplementedError();

  @override
  Future<SavedLook?> findByGeneratedImageId(String generatedImageId) async =>
      null;

  @override
  Future<SavedLooksPageResult> loadPage({
    required int offset,
    required int limit,
  }) async => const SavedLooksPageResult(items: [], hasMore: false);

  @override
  Future<void> remove(String savedLookId) async {}
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _everyday = MakeupStyleCatalog.styles[1];
final _oldMoney = MakeupStyleCatalog.styles[11];
final _base = DateTime(2026, 9, 5, 12);

HistoryPageResult _page(List<String> ids) => HistoryPageResult(
  items: [for (final id in ids) _standardEntry(id)],
  hasMore: false,
  nextOffset: ids.length,
);

HistoryEntry _standardEntry(String id) {
  final analysis = _analysis(id, _base.subtract(const Duration(hours: 1)));
  return HistoryEntry(
    analysis: analysis,
    thumbnailUrl: 'https://signed.example/$id',
    style: _everyday,
    status: HistoryCompletionStatus.complete,
    createdAt: analysis.createdAt,
    // Derived from the id so ordering is stable whatever a page contains.
    latestActivityAt: _base.subtract(Duration(minutes: id.codeUnitAt(0))),
  );
}

KitHistoryEntry _kitEntry(String id) {
  final analysisId = 'analysis-$id';
  final analysis = _analysis(analysisId, _base);
  final recommendation = KitMakeupRecommendation(
    id: 'recommendation-$id',
    analysisId: analysisId,
    styleCode: _oldMoney.code,
    selections: const [
      KitMakeupSelection(
        productId: 'product-0',
        category: 'lipstick',
        colorHex: '#A06060',
        finish: 'satin',
        placement: 'lips',
        technique: 'direct',
        intensity: 'soft',
      ),
    ],
    productSnapshots: const [
      KitProductSnapshot(
        productId: 'product-0',
        category: 'lipstick',
        productName: 'Owned lipstick',
        colorHex: '#A06060',
        finish: 'satin',
      ),
    ],
    overallIntensity: 'soft',
    summary: 'Authoritative kit summary',
    modelId: 'existing-model',
    promptVersion: 'existing-prompt',
    createdAt: _base,
  );
  return KitHistoryEntry(
    result: KitLookResult(
      analysis: analysis,
      style: _oldMoney,
      recommendation: recommendation,
      preview: KitGeneratedPreview(
        id: 'preview-$id',
        analysisId: analysisId,
        kitRecommendationId: recommendation.id,
        originalImagePath: 'user/analyses/$analysisId/original/image.jpg',
        generatedImagePath: 'user/analyses/$analysisId/kit/preview.png',
        originalImageUrl: 'https://signed.example/$id-original',
        generatedImageUrl: 'https://signed.example/$id-generated',
        generationNumber: 1,
        modelId: 'existing-model',
        promptVersion: 'existing-prompt',
        createdAt: _base,
      ),
    ),
  );
}

FaceAnalysis _analysis(String id, DateTime createdAt) {
  final raw = validAnalysisResponse['analysis']! as Map<String, Object?>;
  return FaceAnalysisDto.fromResponse({
    'analysis': {
      ...raw,
      'id': id,
      'originalImagePath': 'user/analyses/$id/original/image.jpg',
      'createdAt': createdAt.toUtc().toIso8601String(),
    },
  }).analysis;
}
