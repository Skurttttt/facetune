import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/history/data/providers/history_providers.dart';
import 'package:facetune/features/history/domain/entities/history_entry.dart';
import 'package:facetune/features/history/presentation/models/history_feed_item.dart';
import 'package:facetune/features/history/presentation/utils/look_metadata_presentation.dart';
import 'package:facetune/features/history/presentation/widgets/history_card.dart';
import 'package:facetune/features/home/presentation/pages/home_page.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/profile/data/providers/profile_providers.dart';
import 'package:facetune/features/saved_looks/data/providers/saved_looks_providers.dart';
import 'package:facetune/features/saved_looks/data/repositories/unavailable_saved_looks_repository.dart';
import 'package:facetune/shared/widgets/media/private_image.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/analysis_response_fixture.dart';
import '../../helpers/fake_account_repositories.dart';
import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_history_repository.dart';

/// POLISH-P2 — Home Recent Looks speaks History's vocabulary.
///
/// Home used to render a style name over an ISO date (`2026-09-05`) while
/// History rendered a title, a mode, a supporting fact and `Sep 5 · 2:41 PM`.
/// These tests pin the four lines, the one formatter behind them, and the fact
/// that adopting them cost no extra fetch and no extra signing call.
void main() {
  group('the shared look metadata model', () {
    test('reads Standard\'s four lines from the Standard adapter', () {
      final metadata = lookMetadataOf(
        StandardHistoryFeedItem(_entry(at: DateTime(2026, 9, 4, 22, 3))),
        now: _now,
      );

      expect(metadata.title, 'Everyday');
      expect(metadata.modeLabel, 'Recommendation');
      expect(metadata.secondaryMetadata, 'Plan ready');
      expect(metadata.formattedDateTime, 'Sep 4 · 10:03 PM');
    });

    test('is a pure read — no image URL is touched to build it', () {
      // The record's thumbnail is a signed URL. Metadata that reached for it
      // would mean one signing call per line rendered.
      final item = StandardHistoryFeedItem(_entry());
      final metadata = lookMetadataOf(item, now: _now);

      expect([
        metadata.title,
        metadata.modeLabel,
        metadata.secondaryMetadata,
        metadata.formattedDateTime,
      ], everyElement(isNot(contains(item.thumbnailUrl))));
    });

    test('the year rule is the one History always had', () {
      expect(
        formatLookTimestamp(DateTime(2025, 9, 5, 14, 41), now: _now),
        'Sep 5, 2025 · 2:41 PM',
      );
      expect(
        formatLookTimestamp(DateTime(2026, 1, 9, 0, 5), now: _now),
        'Jan 9 · 12:05 AM',
      );
    });
  });

  group('Home Recent Looks', () {
    testWidgets('states the same four lines History states', (tester) async {
      await _pumpHome(tester, entries: [_entry(at: _thisYear)]);

      expect(find.text('Everyday'), findsOneWidget);
      expect(find.text('Recommendation'), findsOneWidget);
      expect(find.text('Plan ready'), findsOneWidget);
      // The History formatter's output, not an ISO date.
      expect(
        find.text(formatLookTimestamp(_thisYear, now: DateTime.now())),
        findsOneWidget,
      );
      expect(find.textContaining(RegExp(r'^\d{4}-\d{2}-\d{2}$')), findsNothing);
    });

    testWidgets('word for word what the History card would say', (
      tester,
    ) async {
      // The strongest form of the parity claim: build the History card from the
      // same record and compare the rendered strings rather than restating the
      // expected text twice and hoping the two lists stay in step.
      final entry = _entry(at: _thisYear);

      await _pumpHome(tester, entries: [entry]);
      final home = _visibleText(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryCard(
              item: StandardHistoryFeedItem(entry),
              isMutating: false,
              onOpen: () {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      final history = _visibleText(tester);

      for (final line in [
        'Everyday',
        'Recommendation',
        'Plan ready',
        formatLookTimestamp(_thisYear, now: DateTime.now()),
      ]) {
        expect(home, contains(line), reason: 'Home is missing "$line"');
        expect(history, contains(line), reason: 'History is missing "$line"');
      }
    });

    testWidgets('the tap target and the image source are unchanged', (
      tester,
    ) async {
      await _pumpHome(tester, entries: [_entry(at: _thisYear)]);

      // Still one signed image per card, still loaded the same way.
      final images = tester.widgetList<PrivateImage>(
        find.descendant(
          of: find.byType(Card),
          matching: find.byType(PrivateImage),
        ),
      );
      expect(images, hasLength(1));
      expect(images.single.url, 'https://signed.example/thumb');

      // The card is still a single tappable surface reaching History.
      expect(
        find.descendant(of: find.byType(Card), matching: find.byType(InkWell)),
        findsWidgets,
      );
      expect(find.text('View all'), findsOneWidget);
      expect(find.text('Start Scan'), findsOneWidget);
    });

    testWidgets('metadata costs no extra history fetch', (tester) async {
      final repository = FakeHistoryRepository(
        items: [
          _entry(at: _thisYear),
          _entry(id: 'second', at: _thisYear),
        ],
      );
      await _pumpHome(tester, repository: repository);

      expect(find.text('Recommendation'), findsNWidgets(2));
      // One page load for the dashboard, exactly as before P2.
      expect(repository.loadCount, 1);
    });
  });

  group('the taller caption still fits', () {
    // The tile gained two lines and gave the thumbnail 32 points to pay for
    // them. Its height is derived from the line boxes it draws, so the sums
    // have to hold at the sizes people actually read at.
    // On the tall surface, so the whole dashboard is in the tree and the only
    // thing under test is the caption's height against the text size.
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('no overflow at ${scale}x text', (tester) async {
        await _pumpHome(
          tester,
          entries: [_entry(at: _thisYear)],
          textScale: scale,
        );

        expect(tester.takeException(), isNull);
        // Every line is still drawn — nothing was dropped to make room.
        expect(find.text('Everyday'), findsOneWidget);
        expect(find.text('Recommendation'), findsOneWidget);
        expect(find.text('Plan ready'), findsOneWidget);
      });
    }

    testWidgets('and none on a POCO X3 GT once scrolled to', (tester) async {
      await _pumpHome(
        tester,
        entries: [_entry(at: _thisYear)],
        size: const Size(1080, 2400),
        devicePixelRatio: 2.75,
      );

      // Recent Looks sits below the fold on a 393pt-wide phone, and a sliver
      // that has not been built cannot be asserted on.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Everyday'), findsOneWidget);
      expect(find.text('Plan ready'), findsOneWidget);
    });
  });

  group('My Makeup Kit on Home', () {
    // Owned-product pluralisation is not restated here: it is already proven
    // against real kit fixtures in
    // test/features/history/history_card_test.dart ('owned product grammar
    // follows the real selection count'), and that is the same adapter Home
    // would read if its feed ever carried a kit record.
    testWidgets('is absent from Home, because the feed has no kit records', (
      tester,
    ) async {
      await _pumpHome(tester, entries: [_entry(at: _thisYear)]);

      // Not a gap to be filled by widening the datasource — a fact to report.
      expect(find.text('My Makeup Kit'), findsNothing);
      expect(find.textContaining('owned product'), findsNothing);
    });
  });
}

final _now = DateTime(2026, 9, 5, 14, 41);

/// A date in the current year, so the formatter's year suffix is not in play.
final _thisYear = DateTime(DateTime.now().year, 9, 4, 22, 3);

String _visibleText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? '')
    .join(' ');

HistoryEntry _entry({String id = 'analysis', DateTime? at}) {
  final activity = at ?? _now;
  final raw = validAnalysisResponse['analysis']! as Map<String, Object?>;
  final analysis = FaceAnalysisDto.fromResponse({
    'analysis': {
      ...raw,
      'id': id,
      'originalImagePath': 'home-user/analyses/$id/original/image.jpg',
      'createdAt': activity
          .subtract(const Duration(hours: 1))
          .toUtc()
          .toIso8601String(),
    },
  }).analysis;
  return HistoryEntry(
    analysis: analysis,
    thumbnailUrl: 'https://signed.example/thumb',
    style: MakeupStyleCatalog.styles[1],
    // The status whose Standard label is "Plan ready".
    status: HistoryCompletionStatus.recommendationReady,
    createdAt: analysis.createdAt,
    latestActivityAt: activity,
  );
}

Future<void> _pumpHome(
  WidgetTester tester, {
  List<HistoryEntry> entries = const [],
  FakeHistoryRepository? repository,
  double textScale = 1,
  Size size = const Size(1200, 2400),
  double devicePixelRatio = 1,
}) async {
  // Home is a tall dashboard; the default surface leaves Recent Looks off it.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final auth = FakeAuthRepository(
    user: const AuthUser(id: 'home-user', isAnonymous: false),
  );
  addTearDown(auth.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        historyRepositoryProvider.overrideWithValue(
          repository ?? FakeHistoryRepository(items: entries),
        ),
        savedLooksRepositoryProvider.overrideWithValue(
          const UnavailableSavedLooksRepository(),
        ),
      ],
      // The real theme, not a bare MaterialApp: `AppTheme` zeroes the card
      // margin, and the tile's height is derived from the line boxes it draws.
      // Under Material's default 4pt card margin the same content is 8pt too
      // tall, which would be this harness overflowing rather than the app.
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const HomePage(),
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
}
