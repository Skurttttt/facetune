import 'dart:io';

import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:facetune/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// POLISH-P1(B) — the band above the global bottom navigation.
///
/// POLISH-P0 measured 64 logical points of empty ground between the last card
/// and the navigation bar on all four top-level tabs, and traced it to two
/// stacked clearances: `PageFrame`'s bottom tail, which sits *outside* the
/// scroll viewport and so could never scroll away, plus each page's own
/// trailing sliver. In dark mode the strip drew the scaffold ground
/// (`darkSurface`) against the lighter navigation surface (`darkCard`), which
/// is what made it read as black rather than as whitespace.
///
/// These tests pin the fix from both ends: the geometry the shell now produces,
/// and the fact that all four pages take the frame variant that produces it.
void main() {
  group('PageFrame.scrolling', () {
    test('keeps the gutter and the lead-in, and drops the bottom tail', () {
      // The gutter is the one value that must not move — it is what makes the
      // four tabs read as one app.
      expect(PageFrame.scrollingPadding.left, AppSpacing.gutter);
      expect(PageFrame.scrollingPadding.right, AppSpacing.gutter);
      expect(PageFrame.scrollingPadding.left, PageFrame.defaultPadding.left);
      expect(PageFrame.scrollingPadding.top, PageFrame.defaultPadding.top);

      // The whole of the fix.
      expect(PageFrame.scrollingPadding.bottom, 0);
      expect(PageFrame.defaultPadding.bottom, AppSpacing.xl);
    });

    test('the default frame is untouched, because 16 screens still use it', () {
      // The tail is correct for a non-scrolling screen; only a scroll view
      // turns it into dead ground. Changing the default would have moved every
      // page in the app to fix four.
      expect(
        PageFrame.defaultPadding,
        const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.xs,
          AppSpacing.gutter,
          AppSpacing.xl,
        ),
      );
    });
  });

  group('the shell leaves no band above the navigation bar', () {
    /// POCO X3 GT, with a gesture-navigation inset at the bottom.
    Future<void> pumpShell(WidgetTester tester, {required ThemeData theme}) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      tester.view.padding = const FakeViewPadding(top: 66, bottom: 66);
      tester.view.viewPadding = const FakeViewPadding(top: 66, bottom: 66);
      addTearDown(tester.view.reset);

      return tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: AppShell(
            index: 2,
            child: SafeArea(
              child: PageFrame.scrolling(
                child: CustomScrollView(
                  slivers: [
                    SliverList.list(
                      children: [
                        for (var i = 0; i < 14; i++)
                          const SizedBox(height: 110, child: Card()),
                        const SizedBox(
                          height: 110,
                          child: Card(child: Text('LAST')),
                        ),
                      ],
                    ),
                    // The trailing gap every one of the four pages appends.
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.xl),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('the scroll viewport runs all the way to the bar', (
      tester,
    ) async {
      await pumpShell(tester, theme: AppTheme.darkTheme);

      final viewport = tester.getRect(find.byType(CustomScrollView));
      final nav = tester.getRect(find.byType(NavigationBar));

      // This is the band. Before the fix it was AppSpacing.xl of scaffold
      // ground that no amount of scrolling could reach.
      expect(
        nav.top - viewport.bottom,
        0,
        reason: 'dead ground between the viewport and the navigation bar',
      );
    });

    testWidgets('the last item clears the bar by one spacing step', (
      tester,
    ) async {
      await pumpShell(tester, theme: AppTheme.darkTheme);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
      await tester.pumpAndSettle();

      final last = tester.getRect(find.text('LAST'));
      final nav = tester.getRect(find.byType(NavigationBar));
      final clearance = nav.top - last.bottom;

      // Fully visible: nothing of the last card is under the bar.
      expect(last.bottom, lessThanOrEqualTo(nav.top));
      // Present, and exactly the page's own trailing sliver — not a fake
      // spacer, and not the doubled 64 the audit measured.
      expect(clearance, closeTo(AppSpacing.xl, 0.01));
    });

    testWidgets('the body is not asked to inset itself for the bar', (
      tester,
    ) async {
      await pumpShell(tester, theme: AppTheme.darkTheme);

      // Scaffold already removes it, so a bottom SafeArea in the body is a
      // no-op. Anything non-zero here would mean a second widget had started
      // paying for the same inset the navigation bar already pays for.
      final media = MediaQuery.of(tester.element(find.byType(PageFrame)));
      expect(media.padding.bottom, 0);

      // The bar itself still honours the system inset: its own SafeArea adds
      // 24 (66 physical / 2.75) under the themed 72.
      final nav = tester.getRect(find.byType(NavigationBar));
      expect(nav.height, closeTo(96, 0.01));
    });

    testWidgets('and the same holds in the light theme', (tester) async {
      await pumpShell(tester, theme: AppTheme.lightTheme);

      final viewport = tester.getRect(find.byType(CustomScrollView));
      final nav = tester.getRect(find.byType(NavigationBar));
      expect(nav.top - viewport.bottom, 0);
    });
  });

  test('all four top-level pages take the scrolling frame', () {
    // A source assertion rather than four provider-wired pumps: what needs
    // proving is that no tab was left behind, and that is a fact about the
    // call sites. The rendered geometry is proven above, once.
    const pages = {
      'Home': 'lib/features/home/presentation/pages/home_page.dart',
      'Saved':
          'lib/features/saved_looks/presentation/pages/saved_looks_page.dart',
      'History': 'lib/features/history/presentation/pages/history_page.dart',
      'Profile': 'lib/features/profile/presentation/pages/profile_page.dart',
    };

    for (final MapEntry(key: tab, value: path) in pages.entries) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains('PageFrame.scrolling('),
        reason: '$tab does not use the scrolling frame',
      );
      expect(
        source,
        isNot(contains('child: PageFrame(')),
        reason: '$tab still wraps its scroll view in the default frame',
      );
      // The trailing gap belongs to the page, and one step is all it is.
      expect(
        source,
        contains('SizedBox(height: AppSpacing.xl)'),
        reason: '$tab has no trailing clearance of its own',
      );
      expect(
        source,
        isNot(contains('AppSpacing.xl * ')),
        reason: '$tab multiplies a spacing token into an oversized spacer',
      );
    }
  });
}
