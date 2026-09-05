import 'dart:async';
import 'dart:io';

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
import 'package:facetune/features/history/presentation/models/history_feed_item.dart';
import 'package:facetune/features/history/presentation/pages/history_page.dart';
import 'package:facetune/features/history/presentation/widgets/history_card.dart';
import 'package:facetune/features/history/presentation/widgets/history_card_skeleton.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_library_providers.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_look_providers.dart';
import 'package:facetune/features/makeup_kit/data/repositories/unavailable_makeup_kit_look_repository.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_generated_preview.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_look_result.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/makeup_kit/domain/errors/makeup_kit_library_failure.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_library_repository.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_history_controller.dart';
import 'package:facetune/features/makeup_kit/presentation/controllers/makeup_kit_library_state.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/preview/data/providers/preview_providers.dart';
import 'package:facetune/features/preview/data/repositories/unavailable_makeup_preview_repository.dart';
import 'package:facetune/features/preview/domain/entities/generated_preview.dart';
import 'package:facetune/features/recommendation/data/providers/recommendation_providers.dart';
import 'package:facetune/features/recommendation/data/repositories/unavailable_makeup_recommendation_repository.dart';
import 'package:facetune/features/saved_looks/data/providers/saved_looks_providers.dart';
import 'package:facetune/features/saved_looks/data/repositories/unavailable_saved_looks_repository.dart';
import 'package:facetune/features/saved_looks/domain/entities/saved_look.dart';
import 'package:facetune/features/saved_looks/domain/repositories/saved_looks_repository.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/analysis_response_fixture.dart';
import '../../helpers/fake_auth_repository.dart';

void main() {
  group('HIST-UI-6 the existing page contract', () {
    test('a first batch stays inside the accepted 10-20 band', () {
      expect(HistoryController.pageSize, inInclusiveRange(10, 20));
      expect(MakeupKitHistoryController.pageSize, inInclusiveRange(10, 20));
    });

    test('pages append rather than replace, and advance the offset', () async {
      final repository = _PagedHistoryRepository(total: 30);
      final controller = _controller(repository);
      await controller.loadInitial();
      final first = controller.state.items.map((item) => item.id).toList();
      expect(first, hasLength(HistoryController.pageSize));

      await controller.loadMore();

      // The rows already on screen are still there, in the same order, with
      // the next page after them.
      expect(
        controller.state.items.map((item) => item.id).take(first.length),
        first,
      );
      expect(controller.state.items, hasLength(HistoryController.pageSize * 2));
      expect(repository.requestedOffsets, [0, HistoryController.pageSize]);
      controller.dispose();
    });

    test('concurrent next-page calls issue one request', () async {
      final repository = _PagedHistoryRepository(total: 40);
      final controller = _controller(repository);
      await controller.loadInitial();
      repository.hold();

      final calls = [
        controller.loadMore(),
        controller.loadMore(),
        controller.loadMore(),
      ];
      repository.release();
      await Future.wait(calls);

      expect(repository.requestedOffsets, [0, HistoryController.pageSize]);
      expect(controller.state.items, hasLength(HistoryController.pageSize * 2));
      controller.dispose();
    });

    test('the end of the list stops asking for more', () async {
      final repository = _PagedHistoryRepository(total: 15);
      final controller = _controller(repository);
      await controller.loadInitial();
      await controller.loadMore();
      expect(controller.state.hasMore, isFalse);
      final requests = repository.requestedOffsets.length;

      await controller.loadMore();
      await controller.loadMore();

      expect(repository.requestedOffsets, hasLength(requests));
      expect(controller.state.items, hasLength(15));
      controller.dispose();
    });

    test('a failed next page keeps every page that succeeded', () async {
      final repository = _PagedHistoryRepository(total: 40);
      final controller = _controller(repository);
      await controller.loadInitial();
      final loaded = controller.state.items.map((item) => item.id).toList();

      repository.failure = const HistoryFailure('The network dropped.');
      await controller.loadMore();

      expect(controller.state.status, HistoryLoadStatus.failure);
      expect(controller.state.items.map((item) => item.id), loaded);
      expect(controller.state.hasMore, isTrue);

      // And the inline retry resumes from the page that failed, not from zero.
      repository.failure = null;
      await controller.retryLoadMore();
      expect(controller.state.items, hasLength(HistoryController.pageSize * 2));
      expect(repository.requestedOffsets.where((offset) => offset == 0), [0]);
      controller.dispose();
    });

    test('My Kit paging follows the same rules and can retry', () async {
      final repository = _PagedKitRepository(total: 30);
      final controller = _kitController(repository);
      await controller.loadInitial();
      final loaded = controller.state.items.map((item) => item.id).toList();
      expect(loaded, hasLength(MakeupKitHistoryController.pageSize));

      repository.hold();
      final calls = [controller.loadMore(), controller.loadMore()];
      repository.release();
      await Future.wait(calls);
      expect(repository.requestedOffsets, [
        0,
        MakeupKitHistoryController.pageSize,
      ]);

      repository.shouldFail = true;
      await controller.loadMore();
      expect(controller.state.status, MakeupKitLibraryStatus.failure);
      expect(
        controller.state.items,
        hasLength(MakeupKitHistoryController.pageSize * 2),
      );

      repository.shouldFail = false;
      await controller.retryLoadMore();
      expect(controller.state.items, hasLength(30));
      controller.dispose();
    });
  });

  group('HIST-UI-6 duplicates and identity', () {
    test('an overlapping page renders each record once', () {
      final shared = _standardEntry('overlap');
      final feed = buildHistoryFeed(
        recommendations: [_standardEntry('first'), shared, shared],
        myMakeupKit: const [],
      );

      expect(feed, hasLength(2));
      expect(
        feed.map((item) => item.stableId),
        containsAll(['first', 'overlap']),
      );
      expect(
        feed.map((item) => item.presentationKey).toSet(),
        hasLength(feed.length),
      );
    });

    test('the two authorities are deduplicated separately', () {
      // One analysis can produce a Standard record and a kit record. They are
      // different rows and must both survive; only a repeat within one mode is
      // a duplicate.
      final feed = buildHistoryFeed(
        recommendations: [_standardEntry('shared'), _standardEntry('shared')],
        myMakeupKit: [_kitEntry('shared'), _kitEntry('shared')],
      );

      expect(feed, hasLength(2));
      expect(feed.map((item) => item.recordType).toSet(), {
        HistoryFeedRecordType.recommendation,
        HistoryFeedRecordType.myMakeupKit,
      });
    });
  });

  group('HIST-UI-6 on the page', () {
    testWidgets('nearing the end fetches once and shows skeleton rows', (
      tester,
    ) async {
      final repository = _PagedHistoryRepository(total: 40);
      await _pumpPage(tester, history: repository);
      expect(find.byType(HistoryCard), findsWidgets);
      expect(repository.requestedOffsets, [0]);

      repository.hold();
      await _scrollToEnd(tester);

      // Scrolling near the end asked for exactly one more page, however many
      // scroll notifications the drag produced.
      expect(repository.requestedOffsets, [0, HistoryController.pageSize]);
      expect(find.byType(HistoryCardSkeleton), findsNWidgets(2));
      expect(find.byType(AppProgress), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // The pages already loaded are still on screen above them.
      expect(find.byType(HistoryCard), findsWidgets);

      repository.release();
      await tester.pump();
      await tester.pump();
      expect(find.byType(HistoryCardSkeleton), findsNothing);
    });

    testWidgets('a failed next page offers an inline retry at the bottom', (
      tester,
    ) async {
      final repository = _PagedHistoryRepository(total: 40);
      await _pumpPage(tester, history: repository);

      repository.failure = const HistoryFailure('The network dropped.');
      await _scrollToEnd(tester);
      await tester.pumpAndSettle();

      expect(find.text('Could not load more history'), findsOneWidget);
      // The whole-screen error state is for a first load that failed, never
      // for a next page.
      expect(find.text('History unavailable'), findsNothing);
      expect(find.byType(HistoryCard), findsWidgets);
      // Inline at the bottom: below the rows it belongs to, not above them.
      expect(
        tester.getTopLeft(find.text('Could not load more history')).dy,
        greaterThan(tester.getTopLeft(find.byType(HistoryCard).last).dy),
      );

      repository.failure = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Could not load more history'), findsNothing);
      expect(repository.requestedOffsets.where((offset) => offset == 0), [0]);
    });

    testWidgets('a failed My Kit next page has its own inline retry', (
      tester,
    ) async {
      final kit = _PagedKitRepository(total: 40);
      await _pumpPage(
        tester,
        history: _PagedHistoryRepository(total: 0),
        kit: kit,
      );
      expect(find.byType(HistoryCard), findsWidgets);

      kit.shouldFail = true;
      await _scrollToEnd(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('Could not load more My Makeup Kit history'),
        findsOneWidget,
      );
      expect(find.byType(HistoryCard), findsWidgets);

      kit.shouldFail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not load more My Makeup Kit history'),
        findsNothing,
      );
    });

    testWidgets('scrolling a fully loaded feed issues no further requests', (
      tester,
    ) async {
      final repository = _PagedHistoryRepository(total: 6);
      await _pumpPage(tester, history: repository);
      expect(repository.requestedOffsets, [0]);

      for (var i = 0; i < 3; i++) {
        await _scrollToEnd(tester);
        await tester.pumpAndSettle();
      }

      expect(repository.requestedOffsets, [0]);
    });
  });

  group('HIST-UI-6 cache and lifecycle', () {
    test('paging introduces no per-record query and no signing in the view', () {
      final repository = File(
        'lib/features/history/data/repositories/supabase_history_repository.dart',
      ).readAsStringSync();
      // One analyses query, then batched lookups by id — not one round trip
      // per row. This asserts the accepted shape has not been unpicked.
      expect(repository, contains('selectRecommendations(analysisIds)'));
      expect(repository, contains('selectGeneratedImages(analysisIds)'));
      expect(repository, contains('selectSavedLooks(generatedIds)'));

      for (final path in [
        'lib/features/history/presentation/pages/history_page.dart',
        'lib/features/history/presentation/widgets/history_feed.dart',
        'lib/features/history/presentation/widgets/history_card.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, isNot(contains('createSignedUrl')), reason: path);
        expect(source, isNot(contains('storage')), reason: path);
        expect(source.toLowerCase(), isNot(contains('gemini')), reason: path);
      }
    });

    testWidgets('an appended page never borrows an earlier row\'s thumbnail', (
      tester,
    ) async {
      final repository = _PagedHistoryRepository(total: 24);
      await _pumpPage(tester, history: repository);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HistoryPage)),
      );
      await container.read(historyControllerProvider.notifier).loadMore();
      await tester.pumpAndSettle();

      final urls = tester
          .widgetList<PrivateImage>(find.byType(PrivateImage))
          .map((image) => image.url)
          .toList();
      // Every rendered thumbnail belongs to exactly one record.
      expect(urls.toSet(), hasLength(urls.length));
      for (final image in tester.widgetList<PrivateImage>(
        find.byType(PrivateImage),
      )) {
        expect(image.url, startsWith('https://signed.example/'));
      }
    });

    testWidgets('an expired session on a next page keeps its recovery action', (
      tester,
    ) async {
      final repository = _PagedHistoryRepository(total: 40);
      await _pumpPage(tester, history: repository);

      repository.failure = const HistoryFailure(
        'Your session expired. Sign in again.',
        sessionExpired: true,
      );
      await _scrollToEnd(tester);
      await tester.pumpAndSettle();

      // The accepted recovery, not a plain retry, and the loaded rows survive.
      expect(find.text('Sign in again'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.byType(HistoryCard), findsWidgets);
    });
  });
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// Drags to the bottom of the feed, the way near-end loading is really reached.
///
/// Plain `pump`s rather than `pumpAndSettle`, because the skeletons this is
/// meant to reveal animate forever and would never let a settle return.
Future<void> _scrollToEnd(WidgetTester tester) async {
  // Repeated because the list grows as the next page is requested: the first
  // drag reaches the old bottom and triggers the fetch, the rest carry the
  // viewport down to the footer the fetch just added. Every drag after the
  // first is blocked by the in-flight guard, so this asks for one page, not
  // three.
  for (var attempt = 0; attempt < 3; attempt++) {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pump();
    await tester.pump();
  }
}

HistoryController _controller(HistoryRepository repository) =>
    HistoryController(repository, _NoopSavedLooksRepository(), () {});

MakeupKitHistoryController _kitController(
  MakeupKitLibraryRepository repository,
) => MakeupKitHistoryController(repository, () {});

Future<void> _pumpPage(
  WidgetTester tester, {
  required _PagedHistoryRepository history,
  _PagedKitRepository? kit,
}) async {
  // Short enough that one page overflows it, so near-end loading is reached by
  // scrolling — the way it happens on a device — rather than firing during the
  // very first layout and paging straight to the end of the fixture.
  tester.view.physicalSize = const Size(1000, 800);
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
          kit ?? _PagedKitRepository(total: 0),
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

/// A repository that really pages: it records the offsets it was asked for, so
/// a duplicate or a restarted request is visible rather than inferred.
class _PagedHistoryRepository implements HistoryRepository {
  _PagedHistoryRepository({required this.total});

  final int total;
  final requestedOffsets = <int>[];
  HistoryFailure? failure;
  Completer<void>? _gate;

  void hold() => _gate = Completer<void>();
  void release() {
    _gate?.complete();
    _gate = null;
  }

  @override
  Future<HistoryPageResult> loadPage({
    required int offset,
    required int limit,
  }) async {
    requestedOffsets.add(offset);
    await _gate?.future;
    final currentFailure = failure;
    if (currentFailure != null) throw currentFailure;
    final end = (offset + limit).clamp(0, total);
    final items = [
      for (var index = offset; index < end; index++)
        _standardEntry('entry-$index'),
    ];
    return HistoryPageResult(
      items: items,
      hasMore: end < total,
      nextOffset: end,
    );
  }

  @override
  Future<void> deleteSession(String analysisId) async {}
}

class _PagedKitRepository implements MakeupKitLibraryRepository {
  _PagedKitRepository({required this.total});

  final int total;
  final requestedOffsets = <int>[];
  bool shouldFail = false;
  Completer<void>? _gate;

  void hold() => _gate = Completer<void>();
  void release() {
    _gate?.complete();
    _gate = null;
  }

  @override
  Future<KitHistoryPageResult> loadHistoryPage({
    required int offset,
    required int limit,
  }) async {
    requestedOffsets.add(offset);
    await _gate?.future;
    if (shouldFail) throw const MakeupKitLibraryFailure('Kit paging failed.');
    final end = (offset + limit).clamp(0, total);
    return KitHistoryPageResult(
      items: [
        for (var index = offset; index < end; index++) _kitEntry('kit-$index'),
      ],
      hasMore: end < total,
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

HistoryEntry _standardEntry(String id) {
  final analysis = _analysis(id, _base.subtract(const Duration(hours: 1)));
  return HistoryEntry(
    analysis: analysis,
    thumbnailUrl: 'https://signed.example/$id',
    style: _everyday,
    status: HistoryCompletionStatus.complete,
    createdAt: analysis.createdAt,
    latestActivityAt: _base.subtract(Duration(minutes: id.hashCode % 10000)),
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
        createdAt: _base.subtract(Duration(minutes: id.hashCode % 10000)),
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
