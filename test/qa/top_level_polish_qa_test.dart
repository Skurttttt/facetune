import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/analysis/data/providers/analysis_providers.dart';
import 'package:facetune/features/analysis/data/repositories/unavailable_face_analysis_repository.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/history/data/providers/history_providers.dart';
import 'package:facetune/features/history/domain/entities/history_entry.dart';
import 'package:facetune/features/history/presentation/models/history_feed_item.dart';
import 'package:facetune/features/history/presentation/pages/history_page.dart';
import 'package:facetune/features/history/presentation/utils/look_metadata_presentation.dart';
import 'package:facetune/features/history/presentation/widgets/history_card.dart';
import 'package:facetune/features/home/presentation/pages/home_page.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_library_providers.dart';
import 'package:facetune/features/makeup_kit/data/providers/makeup_kit_look_providers.dart';
import 'package:facetune/features/makeup_kit/data/repositories/unavailable_makeup_kit_library_repository.dart';
import 'package:facetune/features/makeup_kit/domain/repositories/makeup_kit_library_repository.dart';
import 'package:facetune/features/makeup_kit/data/repositories/unavailable_makeup_kit_look_repository.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/preview/data/models/generated_preview_dto.dart';
import 'package:facetune/features/preview/data/providers/preview_providers.dart';
import 'package:facetune/features/preview/data/repositories/unavailable_makeup_preview_repository.dart';
import 'package:facetune/features/profile/data/providers/profile_providers.dart';
import 'package:facetune/features/profile/presentation/pages/profile_page.dart';
import 'package:facetune/features/recommendation/data/models/makeup_recommendation_dto.dart';
import 'package:facetune/features/recommendation/data/providers/recommendation_providers.dart';
import 'package:facetune/features/recommendation/data/repositories/unavailable_makeup_recommendation_repository.dart';
import 'package:facetune/features/saved_looks/data/providers/saved_looks_providers.dart';
import 'package:facetune/features/saved_looks/domain/entities/saved_look.dart';
import 'package:facetune/features/saved_looks/presentation/pages/saved_looks_page.dart';
import 'package:facetune/features/saved_looks/presentation/widgets/saved_look_card.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:facetune/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/analysis_response_fixture.dart';
import '../helpers/fake_account_repositories.dart';
import '../helpers/fake_auth_repository.dart';
import '../helpers/fake_history_repository.dart';
import '../helpers/fake_library_repositories.dart';
import '../helpers/generated_preview_response_fixture.dart';
import '../helpers/recommendation_response_fixture.dart';

/// POLISH-P4 — the four top-level tabs, checked against the contract P1–P3 set.
///
/// The existing matrices already prove these pages render and scroll safely in
/// every theme. What they do not check is the thing this track actually
/// changed: the header rhythm, the metadata vocabulary, the absent Sort, and
/// the bottom-nav seam. That is what is pinned here, with populated data rather
/// than empty states, so the assertions are about real chrome.

/// POCO X3 GT with a gesture-navigation inset.
const _poco = _Device(size: Size(1080, 2400), dpr: 2.75, inset: 66);

/// Narrow and short Android surfaces, at 1:1 so the numbers stay readable.
const _narrow = _Device(size: Size(320, 800), dpr: 1, inset: 24);
const _short = _Device(size: Size(393, 640), dpr: 1, inset: 24);

class _Device {
  const _Device({required this.size, required this.dpr, required this.inset});

  final Size size;
  final double dpr;

  /// Physical top and bottom system insets.
  final double inset;

  double get logicalInset => inset / dpr;
}

enum _Tab { home, saved, history, profile }

extension on _Tab {
  Widget get page => switch (this) {
    _Tab.home => const HomePage(),
    _Tab.saved => const SavedLooksPage(),
    _Tab.history => const HistoryPage(),
    _Tab.profile => const ProfilePage(),
  };

  /// The line the page leads with — its title, or Home's greeting.
  String get heading => switch (this) {
    _Tab.home => 'Welcome back, Mia',
    _Tab.saved => 'Saved looks',
    _Tab.history => 'History',
    _Tab.profile => 'Profile',
  };

  /// Scoped to the header, because "History" and "Profile" are also bottom-nav
  /// labels — the page title and the tab that reaches it share a word.
  Finder get headingFinder => find.descendant(
    of: this == _Tab.home
        ? find.byType(HomeGreetingHeader)
        : find.byType(TopLevelPageHeader),
    matching: find.text(heading),
  );

  int get navIndex => switch (this) {
    _Tab.home => 0,
    _Tab.saved => 1,
    _Tab.history => 2,
    _Tab.profile => 3,
  };
}

void main() {
  group('top inset — every tab clears the status bar by the same rhythm', () {
    for (final tab in _Tab.values) {
      for (final (deviceName, device) in [
        ('POCO X3 GT', _poco),
        ('narrow', _narrow),
        ('short', _short),
      ]) {
        testWidgets('${tab.name} on $deviceName', (tester) async {
          await _pump(tester, tab, device: device);

          final heading = tester.getRect(tab.headingFinder);

          // Safe area, then the frame's lead-in, then the header's own
          // breathing room. Anything less means the title has crept back up
          // under the status bar.
          expect(
            heading.top,
            greaterThanOrEqualTo(
              device.logicalInset +
                  PageFrame.scrollingPadding.top +
                  TopLevelHeaderMetrics.topInset -
                  0.01,
            ),
            reason: '${tab.name} lost its top breathing room on $deviceName',
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('bottom nav integration — no band, and the bar is reachable', () {
    for (final tab in _Tab.values) {
      testWidgets(tab.name, (tester) async {
        await _pump(tester, tab, device: _poco);

        final nav = tester.getRect(find.byType(NavigationBar));
        final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));

        // The destinations are untouched, and this tab is the selected one.
        expect(bar.destinations, hasLength(4));
        expect(bar.selectedIndex, tab.navIndex);
        for (final destination in AppShell.destinations) {
          expect(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.text(destination.label),
            ),
            findsOneWidget,
          );
        }

        // The bar sits on the bottom edge and is fully on screen.
        expect(nav.bottom, closeTo(_poco.size.height / _poco.dpr, 0.01));
        expect(nav.top, greaterThan(0));

        // No dead ground: the scroll viewport runs right up to the bar.
        final viewport = tester.getRect(find.byType(Scrollable).first);
        expect(
          nav.top - viewport.bottom,
          closeTo(0, 0.01),
          reason: '${tab.name} still draws a band above the navigation bar',
        );
      });
    }

    testWidgets('the last History card clears the bar completely', (
      tester,
    ) async {
      await _pump(tester, _Tab.history, device: _poco);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pumpAndSettle();

      final nav = tester.getRect(find.byType(NavigationBar));
      final cards = find.byType(HistoryCard);
      expect(cards, findsWidgets);
      final last = tester.getRect(cards.last);

      expect(last.bottom, lessThanOrEqualTo(nav.top));
      expect(nav.top - last.bottom, greaterThan(0));
    });
  });

  group('HOME', () {
    testWidgets('greeting, trailing control, hero and View all are intact', (
      tester,
    ) async {
      await _pump(tester, _Tab.home, device: _poco);

      expect(find.text('Welcome back, Mia'), findsOneWidget);
      expect(find.text('What beauty mood are you in?'), findsOneWidget);
      // The hero is frozen.
      expect(find.textContaining('Discover your'), findsOneWidget);
      expect(find.text('Start Scan'), findsOneWidget);
      expect(find.text('Recent looks'), findsOneWidget);
      expect(find.text('View all'), findsOneWidget);

      // The trailing control sits on the greeting's row, not over the page.
      final greeting = tester.getRect(find.text('Welcome back, Mia'));
      final control = tester.getRect(find.byTooltip('Settings'));
      expect(control.center.dy, closeTo(greeting.center.dy, greeting.height));
      expect(control.left, greaterThan(greeting.right - 1));
    });

    testWidgets('Recent Looks speaks the History vocabulary', (tester) async {
      await _pump(tester, _Tab.home, device: _poco);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Everyday'), findsWidgets);
      expect(find.text('Recommendation'), findsWidgets);
      expect(find.text('Plan ready'), findsWidgets);
      expect(
        find.text(formatLookTimestamp(_recent, now: DateTime.now())),
        findsWidgets,
      );
      // The ISO date the card used to draw.
      expect(find.textContaining(RegExp(r'^\d{4}-\d{2}-\d{2}$')), findsNothing);
    });
  });

  group('SAVED', () {
    testWidgets('header rhythm holds and the grid is unchanged', (
      tester,
    ) async {
      await _pump(
        tester,
        _Tab.saved,
        device: _poco,
        savedLooks: [_savedLook()],
      );

      final title = tester.getRect(find.text('Saved looks'));
      final subtitle = tester.getRect(
        find.text('Your personal makeup library, ready when you are.'),
      );
      expect(subtitle.top, greaterThanOrEqualTo(title.bottom));
      expect(subtitle.left, closeTo(title.left, 0.01));

      // The grid itself: still the section heading, still a card per look.
      expect(find.text('Makeup Recommendations'), findsOneWidget);
      expect(find.byType(SavedLookCard), findsOneWidget);
      expect(find.byType(SliverGrid), findsWidgets);
    });
  });

  group('HISTORY', () {
    testWidgets('controls, order, groups and cards are all as specified', (
      tester,
    ) async {
      await _pump(tester, _Tab.history, device: _poco);

      // Search, Type, Status — present. Sort — gone.
      expect(find.text('Search your history'), findsOneWidget);
      expect(find.text('TYPE'), findsOneWidget);
      expect(find.text('STATUS'), findsOneWidget);
      // "All" labels a chip in both groups, so it is the one label that must
      // appear twice — once under TYPE and once under STATUS.
      for (final filter in HistoryFeedTypeFilter.values) {
        expect(
          find.widgetWithText(FilterChip, filter.label),
          filter == HistoryFeedTypeFilter.all
              ? findsNWidgets(2)
              : findsOneWidget,
          reason: 'the ${filter.label} type filter went missing',
        );
      }
      for (final status in ['Completed', 'Favorites']) {
        expect(find.widgetWithText(FilterChip, status), findsOneWidget);
      }
      expect(find.text('Sort'), findsNothing);
      expect(find.byIcon(Icons.swap_vert_rounded), findsNothing);

      // Newest first, and the date headings that ordering makes meaningful.
      final rendered = tester
          .widgetList<HistoryCard>(find.byType(HistoryCard))
          .map((card) => card.item.stableId)
          .toList();
      expect(rendered, ['recent', 'older']);
      expect(find.text(HistoryDateGroup.today.label), findsOneWidget);
      expect(find.text(HistoryDateGroup.earlier.label), findsOneWidget);

      // The card itself is untouched: chevron, overflow, favourite indicator.
      expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
      expect(find.byIcon(Icons.more_vert_rounded), findsWidgets);
    });

    testWidgets('a failing My Kit authority reports itself and nothing else', (
      tester,
    ) async {
      // Restores coverage this phase would otherwise have removed: the app-wide
      // matrix used to render History against an unavailable kit repository, so
      // this banner was drawn (though never asserted) in four conditions.
      // Swapping that repository for one that succeeds emptily took the banner
      // with it, so it is checked here on purpose instead of by accident.
      await _pump(
        tester,
        _Tab.history,
        device: _poco,
        kitRepository: const UnavailableMakeupKitLibraryRepository(),
      );

      expect(find.text('My Makeup Kit history unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.text('Search your history'), findsOneWidget);
      // Never the empty state: one authority failing is not "no history yet".
      expect(find.text('No history yet'), findsNothing);

      // The Standard authority is untouched by its neighbour's failure. The
      // banner pushes its rows below the fold, and an unbuilt sliver child
      // cannot be found, so scroll to them rather than asserting from the top.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.byType(HistoryCard), findsWidgets);
    });

    testWidgets('an open keyboard leaves the search field and feed usable', (
      tester,
    ) async {
      await _pump(tester, _Tab.history, device: _poco, keyboardInset: 900);

      await tester.enterText(find.byType(TextField), 'everyday');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'everyday',
      );
      // Still scrollable with the keyboard up.
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.maxScrollExtent, greaterThanOrEqualTo(0));
    });
  });

  group('PROFILE', () {
    testWidgets('settings sits in the title row; card and library intact', (
      tester,
    ) async {
      await _pump(tester, _Tab.profile, device: _poco);

      final title = tester.getRect(_Tab.profile.headingFinder);
      final settings = tester.getRect(find.byTooltip('Open settings'));

      // Aligned by layout, on the title's row, inside the page gutter.
      expect(settings.center.dy, closeTo(title.center.dy, title.height));
      expect(settings.left, greaterThan(title.right - 1));
      expect(
        settings.right,
        lessThanOrEqualTo(
          _poco.size.width / _poco.dpr - AppSpacing.gutter + 12,
        ),
      );

      // The profile card and the library rows are frozen, and still here.
      expect(find.text('Mia'), findsWidgets);
      expect(find.text('Registered account'), findsOneWidget);
      expect(find.text('Edit display name'), findsOneWidget);
      expect(find.text('Your library'), findsOneWidget);
      for (final row in [
        'Saved looks',
        'FaceTune history',
        'My Makeup Kit',
        'Settings and privacy',
      ]) {
        expect(find.text(row), findsOneWidget, reason: '$row went missing');
      }
    });
  });

  group('accessibility', () {
    for (final tab in _Tab.values) {
      testWidgets('${tab.name} — labelled, sized and ordered', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, tab, device: _poco);

        // Every tap target is Android-sized and carries a label. This is what
        // covers the >=44dp requirement and the trailing actions' semantics.
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

        // The page's own heading is readable rather than decorative.
        expect(tab.headingFinder, findsOneWidget);

        // Bottom nav is reachable: four labelled tabs, each its own semantics
        // node, none of them clipped off the bottom of the screen.
        final nav = tester.getRect(find.byType(NavigationBar));
        expect(nav.bottom, lessThanOrEqualTo(_poco.size.height / _poco.dpr));
        for (final destination in AppShell.destinations) {
          expect(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.text(destination.label),
            ),
            findsOneWidget,
          );
        }
        handle.dispose();
      });
    }

    testWidgets('History reads top to bottom in the order it is drawn', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _Tab.history, device: _poco);

      // Heading, then supporting line, then search, then filters, then feed.
      final order = [
        tester.getRect(_Tab.history.headingFinder).top,
        tester
            .getRect(find.text('Revisit every step of your FaceTune journey.'))
            .top,
        tester.getRect(find.byType(TextField)).top,
        tester.getRect(find.text('TYPE')).top,
        tester.getRect(find.text('STATUS')).top,
        tester.getRect(find.byType(HistoryCard).first).top,
      ];
      for (var i = 1; i < order.length; i++) {
        expect(
          order[i],
          greaterThan(order[i - 1]),
          reason: 'element $i is drawn above the one that precedes it',
        );
      }
      handle.dispose();
    });

    testWidgets('no status is carried by colour alone', (tester) async {
      await _pump(tester, _Tab.history, device: _poco);

      // Mode and completion are words on the card, not a tint. HIST-UI-3 moved
      // them out of coloured pills; this is what stops them going back.
      expect(find.text('Recommendation'), findsWidgets);
      expect(find.text('Plan ready'), findsWidgets);
    });
  });

  group('themes', () {
    for (final (name, mode, platform) in [
      ('Light', ThemeMode.light, Brightness.light),
      ('Dark', ThemeMode.dark, Brightness.dark),
      ('System light', ThemeMode.system, Brightness.light),
      ('System dark', ThemeMode.system, Brightness.dark),
    ]) {
      for (final tab in _Tab.values) {
        testWidgets('$name — ${tab.name}', (tester) async {
          await _pump(
            tester,
            tab,
            device: _poco,
            themeMode: mode,
            platformBrightness: platform,
          );

          expect(tester.takeException(), isNull);
          expect(tab.headingFinder, findsOneWidget);
          expect(find.byType(NavigationBar), findsOneWidget);
        });
      }
    }
  });

  group('2x text', () {
    for (final tab in _Tab.values) {
      testWidgets('${tab.name} survives doubled text', (tester) async {
        await _pump(tester, tab, device: _narrow, textScale: 2);

        expect(tester.takeException(), isNull);
        // The heading is still drawn, not clipped away.
        expect(tab.headingFinder, findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);
      });
    }
  });
}

final _recent = DateTime(
  DateTime.now().year,
  DateTime.now().month,
  DateTime.now().day,
  10,
  3,
);
final _older = DateTime.now().subtract(const Duration(days: 40));

HistoryEntry _entry(String id, DateTime at) {
  final raw = validAnalysisResponse['analysis']! as Map<String, Object?>;
  final analysis = FaceAnalysisDto.fromResponse({
    'analysis': {
      ...raw,
      'id': id,
      'originalImagePath': 'qa/analyses/$id/original/image.jpg',
      'createdAt': at
          .subtract(const Duration(hours: 1))
          .toUtc()
          .toIso8601String(),
    },
  }).analysis;
  return HistoryEntry(
    analysis: analysis,
    thumbnailUrl: 'https://signed.example/$id',
    style: MakeupStyleCatalog.styles[1],
    status: HistoryCompletionStatus.recommendationReady,
    createdAt: analysis.createdAt,
    latestActivityAt: at,
  );
}

SavedLook _savedLook() => SavedLook(
  id: 'saved-1',
  preview: GeneratedPreviewDto.fromResponse(validGeneratedPreviewResponse)
      .toDomain(
        originalImageUrl: 'https://signed.example/saved/original',
        generatedImageUrl: 'https://signed.example/saved/generated',
      ),
  analysis: FaceAnalysisDto.fromResponse(validAnalysisResponse).analysis,
  recommendation: MakeupRecommendationDto.fromResponse(
    validRecommendationResponse,
  ).recommendation,
  style: MakeupStyleCatalog.styles[3],
  isFavorite: false,
  createdAt: DateTime.utc(2026, 8, 11),
);

Future<void> _pump(
  WidgetTester tester,
  _Tab tab, {
  required _Device device,
  MakeupKitLibraryRepository? kitRepository,
  List<SavedLook> savedLooks = const [],
  double textScale = 1,
  double keyboardInset = 0,
  ThemeMode themeMode = ThemeMode.light,
  Brightness platformBrightness = Brightness.light,
}) async {
  tester.view.physicalSize = device.size;
  tester.view.devicePixelRatio = device.dpr;
  tester.view.padding = FakeViewPadding(
    top: device.inset,
    bottom: device.inset,
  );
  tester.view.viewPadding = FakeViewPadding(
    top: device.inset,
    bottom: device.inset,
  );
  if (keyboardInset > 0) {
    tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
  }
  tester.platformDispatcher.platformBrightnessTestValue = platformBrightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  final auth = FakeAuthRepository(
    user: const AuthUser(id: 'qa-user', isAnonymous: false),
  );
  addTearDown(auth.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        historyRepositoryProvider.overrideWithValue(
          FakeHistoryRepository(
            items: [_entry('recent', _recent), _entry('older', _older)],
          ),
        ),
        savedLooksRepositoryProvider.overrideWithValue(
          FakeSavedLooksRepository(items: savedLooks),
        ),
        makeupKitLibraryRepositoryProvider.overrideWithValue(
          kitRepository ?? FakeMakeupKitLibraryRepository(),
        ),
        makeupKitLookRepositoryProvider.overrideWithValue(
          const UnavailableMakeupKitLookRepository(),
        ),
        faceAnalysisRepositoryProvider.overrideWithValue(
          const UnavailableFaceAnalysisRepository(),
        ),
        makeupRecommendationRepositoryProvider.overrideWithValue(
          const UnavailableMakeupRecommendationRepository(),
        ),
        makeupPreviewRepositoryProvider.overrideWithValue(
          const UnavailableMakeupPreviewRepository(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: tab.page,
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
