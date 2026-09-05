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
import 'package:facetune/features/history/presentation/utils/look_metadata_presentation.dart';
import 'package:facetune/features/history/presentation/widgets/history_card.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_library_providers.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_look_providers.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_generated_preview.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_look_result.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/makeup_kit/data/repositories/unavailable_makeup_kit_look_repository.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_library_repository.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/preview/data/models/generated_preview_dto.dart';
import 'package:facetune/features/preview/data/providers/preview_providers.dart';
import 'package:facetune/features/preview/data/repositories/unavailable_makeup_preview_repository.dart';
import 'package:facetune/features/recommendation/data/models/makeup_recommendation_dto.dart';
import 'package:facetune/features/recommendation/data/providers/recommendation_providers.dart';
import 'package:facetune/features/recommendation/data/repositories/unavailable_makeup_recommendation_repository.dart';
import 'package:facetune/features/saved_looks/data/providers/saved_looks_providers.dart';
import 'package:facetune/features/saved_looks/data/repositories/unavailable_saved_looks_repository.dart';
import 'package:facetune/features/saved_looks/domain/entities/saved_look.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/analysis_response_fixture.dart';
import '../../helpers/fake_auth_repository.dart';
import '../../helpers/generated_preview_response_fixture.dart';
import '../../helpers/recommendation_response_fixture.dart';

/// Fixed "now", so the card's year rule and the date line are deterministic.
final _now = DateTime(2026, 9, 5, 13);

/// The timestamp both fixtures below present: `Sep 5 · 2:41 PM`.
final _occurredAt = DateTime(2026, 9, 5, 14, 41);

void main() {
  group('HIST-UI-3 shared card shell', () {
    testWidgets('both modes render one card widget with one geometry', (
      tester,
    ) async {
      await _pumpCard(tester, _standardItem());
      final standardCards = tester.widgetList(find.byType(HistoryCard)).length;
      final standardThumb = tester.getSize(find.byType(PrivateImage));
      final standardCardSize = tester.getSize(find.byType(HistoryCard));
      expect(standardCards, 1);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

      await _pumpCard(tester, _kitItem());
      expect(tester.widgetList(find.byType(HistoryCard)).length, 1);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

      // The point of the phase: identical footprint, not merely a similar one.
      expect(tester.getSize(find.byType(PrivateImage)), standardThumb);
      expect(
        standardThumb,
        const Size(HistoryCard.thumbnailWidth, HistoryCard.thumbnailHeight),
      );
      expect(tester.getSize(find.byType(HistoryCard)), standardCardSize);
    });

    testWidgets('both modes place title, mode, metadata and date alike', (
      tester,
    ) async {
      await _pumpCard(tester, _standardItem());
      final standardOrder = [
        tester.getTopLeft(find.text('Everyday')),
        tester.getTopLeft(find.text('Recommendation')),
        tester.getTopLeft(find.text('Plan ready')),
        tester.getTopLeft(find.text('Sep 5 · 2:41 PM')),
      ];

      await _pumpCard(tester, _kitItem());
      final kitOrder = [
        tester.getTopLeft(find.text('Old Money')),
        tester.getTopLeft(find.text('My Makeup Kit')),
        tester.getTopLeft(find.text('1 owned product')),
        tester.getTopLeft(find.text('Sep 5 · 2:41 PM')),
      ];

      expect(kitOrder, standardOrder);
    });

    test('a record from an earlier year keeps its year on the date line', () {
      expect(
        formatLookTimestamp(DateTime(2025, 9, 5, 14, 41), now: _now),
        'Sep 5, 2025 · 2:41 PM',
      );
      expect(
        formatLookTimestamp(DateTime(2026, 1, 9, 0, 5), now: _now),
        'Jan 9 · 12:05 AM',
      );
      expect(
        formatLookTimestamp(DateTime(2026, 1, 9, 12, 5), now: _now),
        'Jan 9 · 12:05 PM',
      );
    });
  });

  group('HIST-UI-3 Standard card content', () {
    testWidgets('presents Standard authority and leaks no My Kit metadata', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _standardItem(status: HistoryCompletionStatus.recommendationReady),
      );

      expect(find.text('Everyday'), findsOneWidget);
      expect(find.text('Recommendation'), findsOneWidget);
      expect(find.text('Plan ready'), findsOneWidget);
      expect(find.text('Sep 5 · 2:41 PM'), findsOneWidget);

      expect(find.textContaining('owned product'), findsNothing);
      expect(find.text('My Makeup Kit'), findsNothing);
    });

    test('each completion status keeps its existing label', () {
      expect(
        _standardItem(
          status: HistoryCompletionStatus.analysisReady,
        ).metadataLabel,
        'Analysis',
      );
      expect(
        _standardItem(
          status: HistoryCompletionStatus.recommendationReady,
        ).metadataLabel,
        'Plan ready',
      );
      expect(
        _standardItem(status: HistoryCompletionStatus.complete).metadataLabel,
        'Complete',
      );
    });

    testWidgets('status metadata is quiet body text, not a coloured pill', (
      tester,
    ) async {
      await _pumpCard(tester, _standardItem());
      final status = tester.widget<Text>(find.text('Plan ready'));
      final date = tester.widget<Text>(find.text('Sep 5 · 2:41 PM'));
      final mode = tester.widget<Text>(find.text('Recommendation'));

      // Status now reads exactly like the timestamp beside it, and carries none
      // of the emphasis the mode label still gets.
      expect(status.style, date.style);
      expect(status.style?.fontWeight, isNot(mode.style?.fontWeight));
      // The old badge drew its own tinted, pill-radius container.
      expect(
        find.descendant(
          of: find.byType(HistoryCard),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container && widget.decoration is BoxDecoration,
          ),
        ),
        findsNothing,
      );
    });
  });

  group('HIST-UI-3 My Makeup Kit card content', () {
    testWidgets('presents My Kit authority and no Standard status', (
      tester,
    ) async {
      await _pumpCard(tester, _kitItem());

      expect(find.text('Old Money'), findsOneWidget);
      expect(find.text('My Makeup Kit'), findsOneWidget);
      expect(find.text('1 owned product'), findsOneWidget);
      expect(find.text('Sep 5 · 2:41 PM'), findsOneWidget);

      expect(find.text('Recommendation'), findsNothing);
      for (final label in ['Analysis', 'Plan ready', 'Complete']) {
        expect(find.text(label), findsNothing);
      }
    });

    test('owned product grammar follows the real selection count', () {
      expect(_kitItem(selectionCount: 1).metadataLabel, '1 owned product');
      expect(_kitItem(selectionCount: 2).metadataLabel, '2 owned products');
      expect(_kitItem(selectionCount: 0).metadataLabel, '0 owned products');
      expect(_kitItem(selectionCount: 11).metadataLabel, '11 owned products');
    });

    testWidgets('plural grammar reaches the rendered card', (tester) async {
      await _pumpCard(tester, _kitItem(selectionCount: 2));
      expect(find.text('2 owned products'), findsOneWidget);
      expect(find.text('1 owned product'), findsNothing);
    });
  });

  group('HIST-UI-3 mode authority', () {
    test('neither adapter can borrow the other mode\'s metadata', () {
      final standard = _standardItem();
      final kit = _kitItem();

      expect(standard.modeLabel, 'Recommendation');
      expect(standard.metadataLabel, isNot(contains('owned product')));
      expect(kit.modeLabel, 'My Makeup Kit');
      expect(kit.metadataLabel, isNot('Plan ready'));
      expect(standard.thumbnailUrl, isNot(kit.thumbnailUrl));
      expect(standard.presentationKey, isNot(kit.presentationKey));
    });

    test('the shared card owns no repository, controller, or AI work', () {
      final source = File(
        'lib/features/history/presentation/widgets/history_card.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('/repositories/')));
      expect(source, isNot(contains('/controllers/')));
      expect(source, isNot(contains('flutter_riverpod')));
      expect(source, isNot(contains('.generate(')));
      expect(source.toLowerCase(), isNot(contains('gemini')));
      // The card must not reach into either domain entity directly; everything
      // it draws arrives through the presentation adapter.
      expect(source, isNot(contains('kit_look_result.dart')));
      expect(source, isNot(contains('history_entry.dart')));
    });
  });

  group('HIST-UI-3 safe actions', () {
    testWidgets('delete has left the primary card surface', (tester) async {
      await _pumpCard(tester, _standardItem());

      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    testWidgets('the overflow lists View, Favorite, then Delete', (
      tester,
    ) async {
      await _pumpCard(tester, _standardItem(), onFavorite: () {});
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('View'), findsOneWidget);
      expect(find.text('Favorite'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('View')).dy,
        lessThan(tester.getTopLeft(find.text('Favorite')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Favorite')).dy,
        lessThan(tester.getTopLeft(find.text('Delete')).dy),
      );
    });

    testWidgets('Delete carries the app\'s existing destructive tone', (
      tester,
    ) async {
      await _pumpCard(tester, _standardItem());
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      final deleteColor = tester.widget<Text>(find.text('Delete')).style?.color;
      final viewColor = tester.widget<Text>(find.text('View')).style?.color;
      expect(deleteColor, isNotNull);
      expect(deleteColor, isNot(viewColor));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.delete_outline_rounded)).color,
        deleteColor,
      );
    });

    testWidgets('card tap and overflow View both use the existing callback', (
      tester,
    ) async {
      var opens = 0;
      await _pumpCard(tester, _standardItem(), onOpen: () => opens += 1);

      await tester.tap(find.byType(HistoryCard));
      await tester.pumpAndSettle();
      expect(opens, 1);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(opens, 2);
    });

    testWidgets('Delete in the overflow calls the existing delete callback', (
      tester,
    ) async {
      var deletes = 0;
      await _pumpCard(tester, _standardItem(), onDelete: () => deletes += 1);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(deletes, 1);
    });

    testWidgets('favorite label reflects the record\'s current state', (
      tester,
    ) async {
      var favorites = 0;
      await _pumpCard(
        tester,
        _standardItem(),
        onFavorite: () => favorites += 1,
      );
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Favorite'), findsOneWidget);
      expect(find.text('Remove favorite'), findsNothing);
      await tester.tap(find.text('Favorite'));
      await tester.pumpAndSettle();
      expect(favorites, 1);

      await _pumpCard(
        tester,
        _standardItem(favorite: true),
        onFavorite: () => favorites += 1,
      );
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Remove favorite'), findsOneWidget);
      expect(find.text('Favorite'), findsNothing);
      await tester.tap(find.text('Remove favorite'));
      await tester.pumpAndSettle();
      expect(favorites, 2);
    });

    testWidgets('a mode with no favorite authority is offered no favorite', (
      tester,
    ) async {
      // My Kit history exposes delete only. Offering "Favorite" here would mean
      // inventing persistence the accepted authority does not have.
      await _pumpCard(tester, _kitItem(favorite: true));
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Favorite'), findsNothing);
      expect(find.text('Remove favorite'), findsNothing);
      expect(find.text('View'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('an existing favorite still shows the quiet heart', (
      tester,
    ) async {
      await _pumpCard(tester, _kitItem(favorite: true));
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

      await _pumpCard(tester, _kitItem());
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    });

    testWidgets('a mutating record exposes neither tap nor overflow', (
      tester,
    ) async {
      var opens = 0;
      await _pumpCard(
        tester,
        _standardItem(),
        isMutating: true,
        onOpen: () => opens += 1,
      );

      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(HistoryCard));
      await tester.pump();
      expect(opens, 0);
    });

    testWidgets('rendering and opening the overflow perform no AI work', (
      tester,
    ) async {
      var aiCalls = 0;
      await _pumpCard(
        tester,
        _standardItem(),
        onFavorite: () {},
        onRegenerate: () => aiCalls += 1,
      );
      expect(aiCalls, 0);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(aiCalls, 0);

      // The pre-existing regeneration action survives the move into the
      // overflow; it is still user-initiated and still runs nothing on render.
      expect(find.text('Generate another variation'), findsOneWidget);
      await tester.tap(find.text('Generate another variation'));
      await tester.pumpAndSettle();
      expect(aiCalls, 1);
    });
  });

  group('HIST-UI-3 delete confirmation is unchanged', () {
    testWidgets('cancelling a Standard delete keeps the record', (
      tester,
    ) async {
      final history = _CountingHistoryRepository(
        items: [_standardEntry(status: HistoryCompletionStatus.complete)],
      );
      await _pumpHistoryPage(tester, history: history);

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this history session?'), findsOneWidget);
      expect(find.text('Delete permanently'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(history.deleted, isEmpty);
      expect(find.text('Everyday'), findsOneWidget);
    });

    testWidgets('confirming a Standard delete uses the existing authority', (
      tester,
    ) async {
      final history = _CountingHistoryRepository(
        items: [_standardEntry(status: HistoryCompletionStatus.complete)],
      );
      await _pumpHistoryPage(tester, history: history);

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete permanently'));
      await tester.pumpAndSettle();

      expect(history.deleted, ['standard-analysis']);
      expect(find.text('Everyday'), findsNothing);
    });

    testWidgets('confirming a My Kit delete uses the existing authority', (
      tester,
    ) async {
      final kit = _FakeKitLibraryRepository(items: [_kitEntry()]);
      await _pumpHistoryPage(tester, kit: kit);

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this history session?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(kit.deleted, isEmpty);
      expect(find.text('Old Money'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete permanently'));
      await tester.pumpAndSettle();

      expect(kit.deleted, ['kit-analysis']);
      expect(find.text('Old Money'), findsNothing);
    });
  });
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Future<void> _pumpCard(
  WidgetTester tester,
  HistoryFeedItem item, {
  bool isMutating = false,
  VoidCallback? onOpen,
  VoidCallback? onDelete,
  VoidCallback? onFavorite,
  VoidCallback? onRegenerate,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(
          child: HistoryCard(
            item: item,
            isMutating: isMutating,
            now: _now,
            onOpen: onOpen ?? () {},
            onDelete: onDelete ?? () {},
            onFavorite: onFavorite,
            onRegenerate: onRegenerate,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpHistoryPage(
  WidgetTester tester, {
  _CountingHistoryRepository? history,
  _FakeKitLibraryRepository? kit,
}) async {
  final auth = FakeAuthRepository(
    user: const AuthUser(id: 'history-user', isAnonymous: false),
  );
  addTearDown(auth.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(auth),
        historyRepositoryProvider.overrideWithValue(
          history ?? _CountingHistoryRepository(),
        ),
        makeupKitLibraryRepositoryProvider.overrideWithValue(
          kit ?? _FakeKitLibraryRepository(),
        ),
        savedLooksRepositoryProvider.overrideWithValue(
          const UnavailableSavedLooksRepository(),
        ),
        makeupPreviewRepositoryProvider.overrideWithValue(
          const UnavailableMakeupPreviewRepository(),
        ),
        // The page clears the in-flight session controllers after a confirmed
        // delete. Every one of them is left on its real controller; only the
        // external repositories underneath are replaced.
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

/// Deletes for real. The page reloads both authorities after a successful
/// delete, so a fake that only counted would keep serving the row back and the
/// test would prove the opposite of what it claims.
class _CountingHistoryRepository implements HistoryRepository {
  _CountingHistoryRepository({List<HistoryEntry> items = const []})
    : items = [...items];

  final List<HistoryEntry> items;
  final deleted = <String>[];

  @override
  Future<HistoryPageResult> loadPage({
    required int offset,
    required int limit,
  }) async => HistoryPageResult(
    items: offset >= items.length ? const [] : items,
    hasMore: false,
    nextOffset: items.length,
  );

  @override
  Future<void> deleteSession(String analysisId) async {
    deleted.add(analysisId);
    items.removeWhere((item) => item.id == analysisId);
  }
}

class _FakeKitLibraryRepository implements MakeupKitLibraryRepository {
  _FakeKitLibraryRepository({List<KitHistoryEntry> items = const []})
    : items = [...items];

  final List<KitHistoryEntry> items;
  final deleted = <String>[];

  @override
  Future<KitHistoryPageResult> loadHistoryPage({
    required int offset,
    required int limit,
  }) async => KitHistoryPageResult(
    items: offset >= items.length ? const [] : items,
    hasMore: false,
  );

  @override
  Future<void> deleteSession(String analysisId) async {
    deleted.add(analysisId);
    items.removeWhere((item) => item.result.analysis.id == analysisId);
  }

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
// Fixtures — each one built only from its own mode's authority.
// ---------------------------------------------------------------------------

/// `Everyday` is catalog index 1; `Old Money` is index 11.
final _everyday = MakeupStyleCatalog.styles[1];
final _oldMoney = MakeupStyleCatalog.styles[11];

StandardHistoryFeedItem _standardItem({
  HistoryCompletionStatus status = HistoryCompletionStatus.recommendationReady,
  bool favorite = false,
}) =>
    StandardHistoryFeedItem(_standardEntry(status: status, favorite: favorite));

HistoryEntry _standardEntry({
  HistoryCompletionStatus status = HistoryCompletionStatus.recommendationReady,
  bool favorite = false,
}) {
  const id = 'standard-analysis';
  final analysis = _analysis(
    id,
    _occurredAt.subtract(const Duration(hours: 1)),
  );
  final recommendation = MakeupRecommendationDto.fromResponse({
    'recommendation': {
      ...validRecommendationResponse['recommendation']! as Map<String, Object?>,
      'id': 'standard-recommendation',
      'analysisId': id,
      'styleCode': _everyday.code,
    },
  }).recommendation;
  final preview =
      GeneratedPreviewDto.fromResponse({
        'preview': {
          ...validGeneratedPreviewResponse['preview']! as Map<String, Object?>,
          'id': 'standard-preview',
          'analysisId': id,
          'recommendationId': recommendation.id,
          'originalImagePath': analysis.originalImagePath,
          'generatedImagePath': 'user/analyses/$id/generated/preview.png',
        },
      }).toDomain(
        originalImageUrl: 'https://signed.example/standard-original',
        generatedImageUrl: 'https://signed.example/standard-thumbnail',
      );
  return HistoryEntry(
    analysis: analysis,
    recommendation: recommendation,
    style: _everyday,
    preview: preview,
    savedLook: favorite
        ? SavedLook(
            id: 'standard-saved',
            preview: preview,
            analysis: analysis,
            recommendation: recommendation,
            style: _everyday,
            isFavorite: true,
            createdAt: _occurredAt,
          )
        : null,
    thumbnailUrl: 'https://signed.example/standard-thumbnail',
    status: status,
    createdAt: analysis.createdAt,
    latestActivityAt: _occurredAt,
  );
}

MyMakeupKitHistoryFeedItem _kitItem({
  int selectionCount = 1,
  bool favorite = false,
}) => MyMakeupKitHistoryFeedItem(
  _kitEntry(selectionCount: selectionCount, favorite: favorite),
);

KitHistoryEntry _kitEntry({int selectionCount = 1, bool favorite = false}) {
  const analysisId = 'kit-analysis';
  final analysis = _analysis(
    analysisId,
    _occurredAt.subtract(const Duration(hours: 2)),
  );
  final recommendation = KitMakeupRecommendation(
    id: 'kit-recommendation',
    analysisId: analysisId,
    styleCode: _oldMoney.code,
    selections: [
      for (var index = 0; index < selectionCount; index++)
        KitMakeupSelection(
          productId: 'product-$index',
          category: 'lipstick',
          colorHex: '#A06060',
          finish: 'satin',
          placement: 'lips',
          technique: 'direct',
          intensity: 'soft',
        ),
    ],
    productSnapshots: [
      for (var index = 0; index < selectionCount; index++)
        KitProductSnapshot(
          productId: 'product-$index',
          category: 'lipstick',
          productName: 'Owned lipstick $index',
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
  final preview = KitGeneratedPreview(
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
    createdAt: _occurredAt,
  );
  final result = KitLookResult(
    analysis: analysis,
    style: _oldMoney,
    recommendation: recommendation,
    preview: preview,
  );
  return KitHistoryEntry(
    result: result,
    savedLook: favorite
        ? KitSavedLook(
            id: 'kit-saved',
            result: result,
            isFavorite: true,
            createdAt: _occurredAt,
          )
        : null,
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
