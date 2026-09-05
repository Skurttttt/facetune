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
import 'package:facetune/features/history/presentation/models/history_feed_item.dart';
import 'package:facetune/features/history/presentation/pages/history_page.dart';
import 'package:facetune/features/history/presentation/widgets/history_card.dart';
import 'package:facetune/features/history/presentation/widgets/history_card_skeleton.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_library_providers.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_look_providers.dart';
import 'package:facetune/features/makeup_kit/data/repositories/unavailable_makeup_kit_look_repository.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_generated_preview.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_look_result.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_library_repository.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/makeup_styles/domain/entities/makeup_style.dart';
import 'package:facetune/features/preview/data/providers/preview_providers.dart';
import 'package:facetune/features/preview/data/repositories/unavailable_makeup_preview_repository.dart';
import 'package:facetune/features/recommendation/data/providers/recommendation_providers.dart';
import 'package:facetune/features/recommendation/data/repositories/unavailable_makeup_recommendation_repository.dart';
import 'package:facetune/features/saved_looks/data/providers/saved_looks_providers.dart';
import 'package:facetune/features/saved_looks/data/repositories/unavailable_saved_looks_repository.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_semantics.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/analysis_response_fixture.dart';
import '../../helpers/fake_auth_repository.dart';

final _occurredAt = DateTime(2026, 9, 5, 14, 41);

void main() {
  group('HIST-UI-7 empty states', () {
    test('each absence is told apart from the others', () {
      HistoryEmptyReason reason({
        bool hasAnyRecords = true,
        HistoryFeedTypeFilter type = HistoryFeedTypeFilter.all,
        HistoryFilter status = HistoryFilter.all,
        String query = '',
      }) => resolveHistoryEmptyReason(
        hasAnyRecords: hasAnyRecords,
        typeFilter: type,
        statusFilter: status,
        query: query,
      );

      expect(reason(hasAnyRecords: false), HistoryEmptyReason.noHistory);
      expect(
        reason(type: HistoryFeedTypeFilter.myMakeupKit),
        HistoryEmptyReason.noMyMakeupKitHistory,
      );
      expect(
        reason(status: HistoryFilter.favorites),
        HistoryEmptyReason.noFavorites,
      );
      expect(reason(query: 'soft glam'), HistoryEmptyReason.noMatches);

      // A search explains an empty feed better than a filter sitting behind it.
      expect(
        reason(status: HistoryFilter.favorites, query: 'soft glam'),
        HistoryEmptyReason.noMatches,
      );
      // Two narrowing filters at once: neither alone is the explanation.
      expect(
        reason(
          type: HistoryFeedTypeFilter.myMakeupKit,
          status: HistoryFilter.favorites,
        ),
        HistoryEmptyReason.noMatches,
      );
      // Records exist and nothing is filtered — never "no history yet".
      expect(reason(), HistoryEmptyReason.noMatches);
      // Whitespace is not a search.
      expect(
        reason(hasAnyRecords: false, query: '   '),
        HistoryEmptyReason.noHistory,
      );
    });

    test('the copy is exactly what the phase specifies', () {
      expect(HistoryEmptyReason.noHistory.title, 'No history yet');
      expect(
        HistoryEmptyReason.noHistory.message,
        'Looks you create will appear here.',
      );
      expect(
        HistoryEmptyReason.noMyMakeupKitHistory.title,
        'No My Makeup Kit history yet',
      );
      expect(
        HistoryEmptyReason.noMyMakeupKitHistory.message,
        'Looks created with products from your kit will appear here.',
      );
      expect(HistoryEmptyReason.noFavorites.title, 'No favorites yet');
      expect(
        HistoryEmptyReason.noFavorites.message,
        'Favorite a look to keep it easy to find.',
      );
      expect(HistoryEmptyReason.noMatches.title, 'No matches found');
      expect(
        HistoryEmptyReason.noMatches.message,
        'Try another search or clear your filters.',
      );
    });

    testWidgets('an account with no records is told so, once', (tester) async {
      await _pumpPage(tester, history: _FakeHistoryRepository());

      expect(find.text('No history yet'), findsOneWidget);
      expect(find.text('Looks you create will appear here.'), findsOneWidget);
      expect(find.text('No matches found'), findsNothing);
    });

    testWidgets('filtering to My Makeup Kit with none says which is missing', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        history: _FakeHistoryRepository(items: [_standardEntry()]),
      );
      await tester.tap(find.widgetWithText(FilterChip, 'My Makeup Kit'));
      await tester.pumpAndSettle();

      expect(find.text('No My Makeup Kit history yet'), findsOneWidget);
      // Not "no history yet": there is history, just none of this kind.
      expect(find.text('No history yet'), findsNothing);
    });

    testWidgets('filtering to Favorites with none says so', (tester) async {
      await _pumpPage(
        tester,
        history: _FakeHistoryRepository(items: [_standardEntry()]),
      );
      await tester.tap(find.widgetWithText(FilterChip, 'Favorites'));
      await tester.pumpAndSettle();

      expect(find.text('No favorites yet'), findsOneWidget);
      expect(
        find.text('Favorite a look to keep it easy to find.'),
        findsOneWidget,
      );
    });

    testWidgets('a search that matches nothing points at the search', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        history: _FakeHistoryRepository(items: [_standardEntry()]),
      );
      await tester.enterText(find.byType(TextField), 'nothing matches this');
      await tester.pumpAndSettle();

      expect(find.text('No matches found'), findsOneWidget);
      expect(
        find.text('Try another search or clear your filters.'),
        findsOneWidget,
      );
    });

    testWidgets('an empty state never wears the error tone', (tester) async {
      await _pumpPage(tester, history: _FakeHistoryRepository());

      final status = tester.widget<StatusState>(find.byType(StatusState));
      expect(status.tone, AppTone.info);
      expect(status.liveRegion, isFalse);
    });
  });

  group('HIST-UI-7 error states', () {
    testWidgets('a failed first load offers a working retry', (tester) async {
      final repository = _FakeHistoryRepository(
        failure: const HistoryFailure('The network dropped.'),
      );
      await _pumpPage(tester, history: repository);

      expect(find.text('History unavailable'), findsOneWidget);
      expect(find.text('The network dropped.'), findsOneWidget);

      repository
        ..failure = null
        ..items.add(_standardEntry());
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('History unavailable'), findsNothing);
      expect(find.byType(HistoryCard), findsOneWidget);
    });

    testWidgets('an expired session offers recovery, not a bare retry', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        history: _FakeHistoryRepository(
          failure: const HistoryFailure(
            'Your session expired. Sign in again.',
            sessionExpired: true,
          ),
        ),
      );

      expect(find.text('Sign in again'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('a failed thumbnail leaves a stable fallback in place', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        history: _FakeHistoryRepository(items: [_standardEntry()]),
      );
      final size = tester.getSize(find.byType(HistoryCard));
      await tester.pumpAndSettle();

      // Every request in a widget test fails, so this is the failure path.
      expect(find.byType(ImageUnavailable), findsOneWidget);
      expect(tester.getSize(find.byType(HistoryCard)), size);
      expect(find.text('Everyday'), findsOneWidget);
    });
  });

  group('HIST-UI-7 accessibility', () {
    testWidgets('the search field is named even when it holds a query', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(
        tester,
        history: _FakeHistoryRepository(items: [_standardEntry()]),
      );

      expect(
        find.bySemanticsLabel('Search your history'),
        findsAtLeastNWidgets(1),
      );
      await tester.enterText(find.byType(TextField), 'everyday');
      await tester.pumpAndSettle();
      // The hint is gone now; the label must not have gone with it.
      expect(
        find.bySemanticsLabel('Search your history'),
        findsAtLeastNWidgets(1),
      );
      handle.dispose();
    });

    testWidgets('the page is newest first however the records arrive', (
      tester,
    ) async {
      // Deliberately handed to the repository out of order, so passing this
      // cannot be an accident of the fixture already being sorted.
      await _pumpPage(
        tester,
        history: _FakeHistoryRepository(
          items: [
            _standardEntry(id: 'middle', at: DateTime(2026, 9, 4, 9)),
            _standardEntry(id: 'newest', at: DateTime(2026, 9, 5, 14)),
            _standardEntry(id: 'oldest', at: DateTime(2026, 8, 30, 18)),
          ],
        ),
      );

      // Read off the rendered cards rather than the model, so this fails if the
      // page ever hands the feed an order other than newest first.
      final rendered = tester
          .widgetList<HistoryCard>(find.byType(HistoryCard))
          .map((card) => card.item.stableId)
          .toList();
      expect(rendered, ['newest', 'middle', 'oldest']);
      expect(find.text('Sort'), findsNothing);
    });

    testWidgets('date grouping survives the removal of Sort', (tester) async {
      // Style A-Z used to suppress the headings entirely. With the control gone
      // the feed can only ever be chronological, so they must always be here.
      await _pumpPage(
        tester,
        history: _FakeHistoryRepository(
          items: [
            _standardEntry(id: 'recent', at: DateTime.now()),
            _standardEntry(
              id: 'old',
              at: DateTime.now().subtract(const Duration(days: 40)),
            ),
          ],
        ),
      );

      expect(find.text(HistoryDateGroup.today.label), findsOneWidget);
      expect(find.text(HistoryDateGroup.earlier.label), findsOneWidget);
    });

    testWidgets('no sort control is announced, because there is none', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(
        tester,
        history: _FakeHistoryRepository(items: [_standardEntry()]),
      );

      // The control used to carry the current order as its semantic value.
      // POLISH-P1 removed it rather than relabelling it, so nothing on the page
      // should announce an order — the date headings say when instead.
      expect(find.text('Sort'), findsNothing);
      expect(find.bySemanticsLabel('Sort'), findsNothing);
      expect(find.byIcon(Icons.swap_vert_rounded), findsNothing);
      handle.dispose();
    });

    testWidgets('filter groups are headers and selection is exposed', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(
        tester,
        history: _FakeHistoryRepository(items: [_standardEntry()]),
      );

      for (final group in ['TYPE', 'STATUS']) {
        expect(
          tester.getSemantics(find.text(group)),
          matchesSemantics(label: group, isHeader: true),
        );
      }

      await tester.tap(find.widgetWithText(FilterChip, 'Recommendations'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<FilterChip>(find.byType(FilterChip))
            .where((chip) => chip.selected)
            .length,
        // One in TYPE, one in STATUS — selection is state, not just a colour.
        2,
      );
      handle.dispose();
    });

    testWidgets('the loading placeholders announce once, not once each', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(
        tester,
        history: _FakeHistoryRepository(items: [_standardEntry()], hold: true),
        settle: false,
      );

      expect(find.byType(HistoryCardSkeleton), findsNWidgets(5));
      expect(find.bySemanticsLabel('Loading history'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('every interactive target clears the 48dp minimum', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(
        tester,
        history: _FakeHistoryRepository(items: [_standardEntry()]),
      );

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      // And inside the overflow, where the destructive action lives.
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('the destructive action is not signalled by colour alone', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        history: _FakeHistoryRepository(items: [_standardEntry()]),
      );
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      // Word, icon and colour — any one of the three carries it.
      expect(find.text('Delete'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    testWidgets('focus order follows the visual order down the page', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(
        tester,
        history: _FakeHistoryRepository(items: [_standardEntry()]),
      );

      final searchY = tester.getTopLeft(find.byType(TextField)).dy;
      final typeY = tester.getTopLeft(find.text('TYPE')).dy;
      final statusY = tester.getTopLeft(find.text('STATUS')).dy;
      final cardY = tester.getTopLeft(find.byType(HistoryCard)).dy;

      expect(searchY, lessThan(typeY));
      expect(typeY, lessThan(statusY));
      expect(statusY, lessThan(cardY));
      handle.dispose();
    });
  });

  group('HIST-UI-7 responsive', () {
    for (final (name, size) in <(String, Size)>[
      ('POCO X3 GT', Size(393, 873)),
      ('narrow Android', Size(320, 640)),
      ('short Android', Size(360, 540)),
    ]) {
      testWidgets('$name renders the feed without overflow', (tester) async {
        await _pumpPage(
          tester,
          history: _FakeHistoryRepository(items: [_standardEntry()]),
          size: size,
        );

        await _revealCard(tester);
        expect(find.byType(HistoryCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('doubling the text size does not break the card', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _pumpPage(
        tester,
        history: _FakeHistoryRepository(items: [_standardEntry()]),
        size: const Size(320, 640),
      );

      await _revealCard(tester);
      expect(find.byType(HistoryCard), findsOneWidget);
      // The thumbnail is a fixed footprint; only the text column may grow.
      expect(
        tester.getSize(find.byType(PrivateImage)),
        const Size(HistoryCard.thumbnailWidth, HistoryCard.thumbnailHeight),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a very long style name is truncated, not overflowed', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        history: _FakeHistoryRepository(
          items: [
            _standardEntry(
              style: const MakeupStyle(
                id: MakeupStyleId.everyday,
                code: 'everyday',
                name:
                    'An extraordinarily long historical style name that '
                    'could never fit on one line of a narrow phone',
                description: 'Long',
              ),
            ),
          ],
        ),
        size: const Size(320, 640),
      );

      await _revealCard(tester);
      final title = tester.widget<Text>(
        find.textContaining('An extraordinarily long'),
      );
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an open keyboard leaves the feed scrollable', (tester) async {
      await _pumpPage(
        tester,
        history: _FakeHistoryRepository(items: [_standardEntry()]),
        size: const Size(393, 873),
        viewInsetsBottom: 400,
      );

      await _revealCard(tester);
      expect(find.byType(HistoryCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('HIST-UI-7 theme', () {
    for (final (name, mode, platform) in <(String, ThemeMode, Brightness)>[
      ('Light', ThemeMode.light, Brightness.light),
      ('Dark', ThemeMode.dark, Brightness.dark),
      ('System Light', ThemeMode.system, Brightness.light),
      ('System Dark', ThemeMode.system, Brightness.dark),
    ]) {
      testWidgets('$name renders History and its empty state', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = platform;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

        await _pumpPage(
          tester,
          history: _FakeHistoryRepository(items: [_standardEntry()]),
          themeMode: mode,
        );
        expect(find.byType(HistoryCard), findsOneWidget);

        await tester.tap(find.widgetWithText(FilterChip, 'Favorites'));
        await tester.pumpAndSettle();
        expect(find.text('No favorites yet'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// Brings the first card into view on screens too short to show it at rest.
///
/// The feed is a lazy sliver: a row below the fold is not built at all, so on a
/// short device "not found" would otherwise be indistinguishable from "broken".
Future<void> _revealCard(WidgetTester tester) async {
  if (find.byType(HistoryCard).evaluate().isNotEmpty) return;
  await tester.scrollUntilVisible(
    find.byType(HistoryCard),
    200,
    scrollable: find.byType(Scrollable).first,
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required _FakeHistoryRepository history,
  bool settle = true,
  Size size = const Size(1000, 1600),
  double devicePixelRatio = 1,
  double viewInsetsBottom = 0,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = devicePixelRatio;
  if (viewInsetsBottom > 0) {
    tester.view.viewInsets = FakeViewPadding(bottom: viewInsetsBottom);
  }
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
          _EmptyKitRepository(),
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
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: const HistoryPage(),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

class _FakeHistoryRepository implements HistoryRepository {
  _FakeHistoryRepository({
    List<HistoryEntry> items = const [],
    this.failure,
    this.hold = false,
  }) : items = [...items];

  final List<HistoryEntry> items;
  HistoryFailure? failure;
  final bool hold;

  @override
  Future<HistoryPageResult> loadPage({
    required int offset,
    required int limit,
  }) async {
    if (hold) await Completer<void>().future;
    final currentFailure = failure;
    if (currentFailure != null) throw currentFailure;
    return HistoryPageResult(
      items: offset >= items.length ? const [] : items,
      hasMore: false,
      nextOffset: items.length,
    );
  }

  @override
  Future<void> deleteSession(String analysisId) async {}
}

class _EmptyKitRepository implements MakeupKitLibraryRepository {
  @override
  Future<KitHistoryPageResult> loadHistoryPage({
    required int offset,
    required int limit,
  }) async => const KitHistoryPageResult(items: [], hasMore: false);

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

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _everyday = MakeupStyleCatalog.styles[1];

HistoryEntry _standardEntry({
  MakeupStyle? style,
  String id = 'standard-analysis',
  DateTime? at,
}) {
  final activity = at ?? _occurredAt;
  final analysis = _analysis(id, activity.subtract(const Duration(hours: 1)));
  return HistoryEntry(
    analysis: analysis,
    thumbnailUrl: 'https://signed.example/standard-thumbnail',
    style: style ?? _everyday,
    status: HistoryCompletionStatus.recommendationReady,
    createdAt: analysis.createdAt,
    latestActivityAt: activity,
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
