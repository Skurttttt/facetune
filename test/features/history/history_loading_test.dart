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
import 'package:facetune/features/history/domain/repositories/history_repository.dart';
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
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_library_repository.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/preview/data/providers/preview_providers.dart';
import 'package:facetune/features/preview/data/repositories/unavailable_makeup_preview_repository.dart';
import 'package:facetune/features/recommendation/data/providers/recommendation_providers.dart';
import 'package:facetune/features/recommendation/data/repositories/unavailable_makeup_recommendation_repository.dart';
import 'package:facetune/features/saved_looks/data/providers/saved_looks_providers.dart';
import 'package:facetune/features/saved_looks/data/repositories/unavailable_saved_looks_repository.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/analysis_response_fixture.dart';
import '../../helpers/fake_auth_repository.dart';

final _now = DateTime(2026, 9, 5, 13);
final _occurredAt = DateTime(2026, 9, 5, 14, 41);

void main() {
  group('HIST-UI-4 initial load', () {
    testWidgets('shows card-shaped skeletons, not one screen-wide spinner', (
      tester,
    ) async {
      final history = _FakeHistoryRepository(
        items: [_standardEntry()],
        hold: true,
      );
      final kit = _FakeKitRepository(items: [_kitEntry()], hold: true);
      await _pumpPage(tester, history: history, kit: kit, settle: false);

      expect(find.byType(HistoryCardSkeleton), findsNWidgets(5));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Loading your history…'), findsNothing);
      expect(find.text('Loading My Makeup Kit history…'), findsNothing);

      // Nothing has arrived, so the screen must not claim there is nothing.
      expect(find.text('No FaceTune history yet'), findsNothing);

      history.release();
      kit.release();
      await tester.pumpAndSettle();
      expect(find.byType(HistoryCardSkeleton), findsNothing);
      expect(find.byType(HistoryCard), findsNWidgets(2));
    });

    testWidgets('keeps the header and filters in place across the load', (
      tester,
    ) async {
      final history = _FakeHistoryRepository(
        items: [_standardEntry()],
        hold: true,
      );
      final kit = _FakeKitRepository(hold: true);
      await _pumpPage(tester, history: history, kit: kit, settle: false);

      // Scoped to the page: the bottom navigation carries the word too.
      final header = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.text('History'),
      );
      final headerWhileLoading = tester.getTopLeft(header);
      final typeWhileLoading = tester.getTopLeft(find.text('TYPE'));
      expect(find.byType(TextField), findsOneWidget);

      history.release();
      kit.release();
      await tester.pumpAndSettle();

      // The whole point of skeleton-first: nothing above the feed moves when
      // the records land.
      expect(tester.getTopLeft(header), headerWhileLoading);
      expect(tester.getTopLeft(find.text('TYPE')), typeWhileLoading);
    });

    testWidgets('one authority still loading appends a tail, not a spinner', (
      tester,
    ) async {
      final history = _FakeHistoryRepository(items: [_standardEntry()]);
      final kit = _FakeKitRepository(items: [_kitEntry()], hold: true);
      await _pumpPage(tester, history: history, kit: kit, settle: false);
      await tester.pump();
      await tester.pump();

      expect(find.byType(HistoryCard), findsOneWidget);
      expect(find.text('Everyday'), findsOneWidget);
      expect(find.byType(HistoryCardSkeleton), findsNWidgets(2));
      expect(find.byType(CircularProgressIndicator), findsNothing);

      kit.release();
      await tester.pumpAndSettle();
      expect(find.byType(HistoryCardSkeleton), findsNothing);
      expect(find.byType(HistoryCard), findsNWidgets(2));
    });

    testWidgets('the skeleton matches the real card geometry', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: Center(child: HistoryCardSkeleton())),
        ),
      );
      await tester.pump();
      final skeletonSize = tester.getSize(find.byType(HistoryCardSkeleton));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: HistoryCard(
                item: _standardItem(),
                isMutating: false,
                now: _now,
                onOpen: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.getSize(find.byType(HistoryCard)), skeletonSize);
    });
  });

  group('HIST-UI-4 thumbnail loading', () {
    testWidgets('a feed thumbnail waits on a still ground, not a spinner', (
      tester,
    ) async {
      await _pumpCard(tester);
      final thumbnail = tester.widget<PrivateImage>(find.byType(PrivateImage));

      expect(thumbnail.placeholder, isA<ImageSkeleton>());
      expect(thumbnail.fadeIn, isTrue);

      await _pumpFrame(tester, thumbnail, frame: null);
      expect(find.byType(ImageSkeleton), findsOneWidget);
      expect(find.byType(ImagePlaceholder), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('the thumbnail fades in over that ground', (tester) async {
      await _pumpCard(tester);
      final thumbnail = tester.widget<PrivateImage>(find.byType(PrivateImage));

      await _pumpFrame(tester, thumbnail, frame: null);
      expect(_fadeOf(tester).opacity, 0);
      expect(_fadeOf(tester).duration, greaterThan(Duration.zero));
      // The ground is still underneath, so the box never blinks to nothing.
      expect(find.byType(ImageSkeleton), findsOneWidget);

      await _pumpFrame(tester, thumbnail, frame: 0);
      expect(_fadeOf(tester).opacity, 1);
      expect(find.byType(ImageSkeleton), findsOneWidget);
    });

    testWidgets('an image already in the cache is drawn without a fade', (
      tester,
    ) async {
      await _pumpCard(tester);
      final thumbnail = tester.widget<PrivateImage>(find.byType(PrivateImage));

      await _pumpFrame(tester, thumbnail, frame: 0, synchronouslyLoaded: true);

      // Returning to History must not re-animate what was already there.
      expect(find.byType(AnimatedOpacity), findsNothing);
      expect(find.byType(ImageSkeleton), findsNothing);
      expect(find.text('decoded'), findsOneWidget);
    });

    testWidgets('a failed thumbnail leaves the card readable and usable', (
      tester,
    ) async {
      var opens = 0;
      // Every request in a widget test fails, which is the failure path itself.
      await _pumpCard(tester, onOpen: () => opens += 1);
      await tester.pumpAndSettle();

      expect(find.byType(ImageUnavailable), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Everyday'), findsOneWidget);
      expect(find.text('Sep 5 · 2:41 PM'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

      await tester.tap(find.byType(HistoryCard));
      await tester.pumpAndSettle();
      expect(opens, 1);
    });

    testWidgets('the card keeps its footprint through every image state', (
      tester,
    ) async {
      await _pumpCard(tester);
      final whileLoading = tester.getSize(find.byType(HistoryCard));
      final thumbnailWhileLoading = tester.getSize(find.byType(PrivateImage));

      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(HistoryCard)), whileLoading);
      expect(tester.getSize(find.byType(PrivateImage)), thumbnailWhileLoading);
      expect(
        thumbnailWhileLoading,
        const Size(HistoryCard.thumbnailWidth, HistoryCard.thumbnailHeight),
      );
    });

    testWidgets('screens outside the feed keep their existing behaviour', (
      tester,
    ) async {
      const hero = PrivateImage(url: 'https://signed.example/hero');
      expect(hero.placeholder, isNull);
      expect(hero.fadeIn, isFalse);

      // No opt-in: still the spinner-on-a-ground placeholder, still a hard swap.
      await _pumpFrame(tester, hero, frame: null);
      expect(find.byType(ImagePlaceholder), findsOneWidget);
      expect(find.byType(ImageSkeleton), findsNothing);
      expect(find.byType(AnimatedOpacity), findsNothing);

      await _pumpFrame(tester, hero, frame: 0);
      expect(find.byType(ImagePlaceholder), findsNothing);
      expect(find.byType(AnimatedOpacity), findsNothing);
      expect(find.text('decoded'), findsOneWidget);
    });
  });

  group('HIST-UI-4 lifecycle', () {
    testWidgets('rebuilding a card resolves the same image, not a new one', (
      tester,
    ) async {
      final rebuild = ValueNotifier(0);
      addTearDown(rebuild.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<int>(
                valueListenable: rebuild,
                builder: (context, _, _) => HistoryCard(
                  item: _standardItem(),
                  isMutating: false,
                  now: _now,
                  onOpen: () {},
                  onDelete: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final first = tester.widget<Image>(find.byType(Image)).image;

      for (var i = 0; i < 5; i++) {
        rebuild.value++;
        await tester.pump();
      }

      // Equal providers are what makes Flutter's image cache return the same
      // stream instead of opening another request per build.
      expect(tester.widget<Image>(find.byType(Image)).image, first);
    });

    testWidgets('rebuilding the page fetches no further pages', (tester) async {
      final history = _FakeHistoryRepository(items: [_standardEntry()]);
      final kit = _FakeKitRepository(items: [_kitEntry()]);
      final rebuild = ValueNotifier(0);
      addTearDown(rebuild.dispose);

      await _pumpPage(tester, history: history, kit: kit, rebuildOn: rebuild);
      final loads = history.loadCalls;
      final signedUrls = history.servedUrls;
      final kitLoads = kit.loadCalls;
      expect(loads, greaterThan(0));

      for (var i = 0; i < 5; i++) {
        rebuild.value++;
        await tester.pump();
      }

      expect(history.loadCalls, loads);
      expect(history.servedUrls, signedUrls);
      expect(kit.loadCalls, kitLoads);
    });

    test('the History view layer signs nothing and reaches no storage', () {
      for (final path in [
        'lib/features/history/presentation/widgets/history_card.dart',
        'lib/features/history/presentation/widgets/history_card_skeleton.dart',
        'lib/features/history/presentation/widgets/history_feed.dart',
        'lib/shared/widgets/media/private_image.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, isNot(contains('createSignedUrl')), reason: path);
        expect(source, isNot(contains('storage')), reason: path);
        expect(source, isNot(contains('Supabase')), reason: path);
        expect(source.toLowerCase(), isNot(contains('gemini')), reason: path);
      }
    });
  });

  group('HIST-UI-4 filtering', () {
    testWidgets('filtering never leaves another record\'s thumbnail behind', (
      tester,
    ) async {
      final history = _FakeHistoryRepository(items: [_standardEntry()]);
      final kit = _FakeKitRepository(items: [_kitEntry()]);
      await _pumpPage(tester, history: history, kit: kit);

      expect(find.byType(HistoryCard), findsNWidgets(2));
      final before = tester
          .widgetList<PrivateImage>(find.byType(PrivateImage))
          .map((image) => image.url)
          .toSet();
      expect(before, {
        'https://signed.example/standard-thumbnail',
        'https://signed.example/kit-generated',
      });

      await tester.tap(find.widgetWithText(FilterChip, 'My Makeup Kit'));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryCard), findsOneWidget);
      expect(find.text('Old Money'), findsOneWidget);
      expect(
        tester.widget<PrivateImage>(find.byType(PrivateImage)).url,
        'https://signed.example/kit-generated',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// Renders exactly what [PrivateImage] draws for one decode state.
///
/// The network is not a usable seam in a widget test — every request answers
/// 400 — so the three states are driven straight through the frame builder.
Future<void> _pumpFrame(
  WidgetTester tester,
  PrivateImage image, {
  required int? frame,
  bool synchronouslyLoaded = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SizedBox.square(
          dimension: 120,
          child: Builder(
            builder: (context) => image.buildFrame(
              context,
              const Center(child: Text('decoded')),
              frame,
              synchronouslyLoaded,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

AnimatedOpacity _fadeOf(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));

Future<void> _pumpCard(WidgetTester tester, {VoidCallback? onOpen}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(
          child: HistoryCard(
            item: _standardItem(),
            isMutating: false,
            now: _now,
            onOpen: onOpen ?? () {},
            onDelete: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required _FakeHistoryRepository history,
  required _FakeKitRepository kit,
  bool settle = true,
  ValueNotifier<int>? rebuildOn,
}) async {
  // Tall enough that every skeleton and card in these fixtures is built rather
  // than left off-screen by the lazy sliver.
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final auth = FakeAuthRepository(
    user: const AuthUser(id: 'history-user', isAnonymous: false),
  );
  addTearDown(auth.dispose);

  const page = HistoryPage();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(auth),
        historyRepositoryProvider.overrideWithValue(history),
        makeupKitLibraryRepositoryProvider.overrideWithValue(kit),
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
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: rebuildOn == null
            ? page
            : ValueListenableBuilder<int>(
                valueListenable: rebuildOn,
                builder: (context, _, _) => page,
              ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Can hold its first page open, so the loading frame is observable.
class _FakeHistoryRepository implements HistoryRepository {
  _FakeHistoryRepository({
    List<HistoryEntry> items = const [],
    bool hold = false,
  }) : items = [...items],
       _gate = hold ? Completer<void>() : null;

  final List<HistoryEntry> items;
  final Completer<void>? _gate;
  int loadCalls = 0;

  /// How many already-signed thumbnail URLs this repository has handed out.
  /// The view layer never asks for one, so this must not move on a rebuild.
  int servedUrls = 0;

  void release() => _gate?.complete();

  @override
  Future<HistoryPageResult> loadPage({
    required int offset,
    required int limit,
  }) async {
    loadCalls += 1;
    await _gate?.future;
    final page = offset >= items.length ? const <HistoryEntry>[] : items;
    servedUrls += page.length;
    return HistoryPageResult(
      items: page,
      hasMore: false,
      nextOffset: items.length,
    );
  }

  @override
  Future<void> deleteSession(String analysisId) async =>
      items.removeWhere((item) => item.id == analysisId);
}

class _FakeKitRepository implements MakeupKitLibraryRepository {
  _FakeKitRepository({
    List<KitHistoryEntry> items = const [],
    bool hold = false,
  }) : items = [...items],
       _gate = hold ? Completer<void>() : null;

  final List<KitHistoryEntry> items;
  final Completer<void>? _gate;
  int loadCalls = 0;

  void release() => _gate?.complete();

  @override
  Future<KitHistoryPageResult> loadHistoryPage({
    required int offset,
    required int limit,
  }) async {
    loadCalls += 1;
    await _gate?.future;
    return KitHistoryPageResult(
      items: offset >= items.length ? const [] : items,
      hasMore: false,
    );
  }

  @override
  Future<void> deleteSession(String analysisId) async =>
      items.removeWhere((item) => item.result.analysis.id == analysisId);

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

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _everyday = MakeupStyleCatalog.styles[1];
final _oldMoney = MakeupStyleCatalog.styles[11];

StandardHistoryFeedItem _standardItem() =>
    StandardHistoryFeedItem(_standardEntry());

HistoryEntry _standardEntry() {
  const id = 'standard-analysis';
  final analysis = _analysis(
    id,
    _occurredAt.subtract(const Duration(hours: 1)),
  );
  return HistoryEntry(
    analysis: analysis,
    thumbnailUrl: 'https://signed.example/standard-thumbnail',
    style: _everyday,
    status: HistoryCompletionStatus.recommendationReady,
    createdAt: analysis.createdAt,
    latestActivityAt: _occurredAt,
  );
}

KitHistoryEntry _kitEntry() {
  const analysisId = 'kit-analysis';
  final analysis = _analysis(
    analysisId,
    _occurredAt.subtract(const Duration(hours: 2)),
  );
  final recommendation = KitMakeupRecommendation(
    id: 'kit-recommendation',
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
    createdAt: _occurredAt.subtract(const Duration(hours: 1)),
  );
  return KitHistoryEntry(
    result: KitLookResult(
      analysis: analysis,
      style: _oldMoney,
      recommendation: recommendation,
      preview: KitGeneratedPreview(
        id: 'kit-preview',
        analysisId: analysisId,
        kitRecommendationId: recommendation.id,
        originalImagePath: 'user/analyses/$analysisId/original/image.jpg',
        generatedImagePath: 'user/analyses/$analysisId/kit/preview.png',
        originalImageUrl: 'https://signed.example/kit-original',
        generatedImageUrl: 'https://signed.example/kit-generated',
        generationNumber: 1,
        modelId: 'existing-model',
        promptVersion: 'existing-prompt',
        createdAt: _occurredAt.subtract(const Duration(minutes: 5)),
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
