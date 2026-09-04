import 'package:facetune/features/results/presentation/widgets/result_shell.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shell both result modes are built from.
///
/// These tests pin the presentation contract itself: whatever Standard and My
/// Makeup Kit put inside it, the header, the tabs and the bottom CTA behave the
/// same way for both. The mode-specific tests then only have to prove they used
/// this shell and passed their own authority's data into it.
Widget _host(Widget child, {ThemeMode themeMode = ThemeMode.light}) =>
    MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('ResultHeader', () {
    testWidgets('without a badge it is just the look and its metadata', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ResultHeader(
            styleName: 'Soft Glam',
            metadata: 'Soft intensity · Warm undertone',
          ),
        ),
      );

      expect(find.text('Soft Glam'), findsOneWidget);
      expect(find.text('Soft intensity · Warm undertone'), findsOneWidget);
      expect(find.byType(ResultModeBadge), findsNothing);
    });

    testWidgets('a badge sits above the title, not in place of it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ResultHeader(
            badge: ResultModeBadge(
              label: 'My Makeup Kit',
              icon: Icons.inventory_2_outlined,
            ),
            styleName: 'Old Money',
            metadata: '3 owned products · Soft intensity',
          ),
        ),
      );

      final badge = find.byType(ResultModeBadge);
      final title = find.text('Old Money');
      expect(badge, findsOneWidget);
      expect(
        tester.getRect(badge).bottom,
        lessThanOrEqualTo(tester.getRect(title).top),
      );

      // Secondary to the style name, not another heading competing with it.
      final titleStyle = tester.widget<Text>(title).style;
      final badgeStyle = tester
          .widget<Text>(find.descendant(of: badge, matching: find.byType(Text)))
          .style;
      expect(badgeStyle!.fontSize, lessThan(titleStyle!.fontSize!));
    });

    testWidgets('the badge announces itself once, as its label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const ResultModeBadge(
            label: 'My Makeup Kit',
            icon: Icons.inventory_2_outlined,
          ),
        ),
      );

      expect(find.bySemanticsLabel('My Makeup Kit'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a long style name and long metadata do not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          const ResultHeader(
            badge: ResultModeBadge(
              label: 'My Makeup Kit',
              icon: Icons.inventory_2_outlined,
            ),
            styleName: 'Luminous Editorial Evening Statement Glam',
            metadata:
                '12 owned products · Medium intensity · Warm neutral undertone',
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('ResultSections', () {
    Widget sections() => const ResultSections(
      overview: Text('overview body'),
      makeup: Text('makeup body'),
      profile: Text('profile body'),
    );

    testWidgets('offers the same three tabs, Overview first', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(sections()));

      expect(find.byKey(const ValueKey('result-section-tabs')), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Makeup'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.bySemanticsLabel('Overview tab'), findsOneWidget);
      expect(find.bySemanticsLabel('Makeup tab'), findsOneWidget);
      expect(find.bySemanticsLabel('Profile tab'), findsOneWidget);

      expect(find.text('overview body'), findsOneWidget);
      expect(find.text('profile body'), findsNothing);
      handle.dispose();
    });

    testWidgets('switching sections shows one body at a time', (tester) async {
      await tester.pumpWidget(_host(sections()));

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('profile body'), findsOneWidget);
      expect(find.text('overview body'), findsNothing);

      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();
      expect(find.text('overview body'), findsOneWidget);
      expect(find.text('profile body'), findsNothing);
    });

    testWidgets('the makeup child is never unmounted by a tab switch', (
      tester,
    ) async {
      // The AI-cost lock. Both modes ensure their accepted manifest from that
      // subtree's initState, so a rebuild that unmounted it would let a user
      // pay for the analysis again by switching tabs.
      await tester.pumpWidget(_host(sections()));
      // `skipOffstage: false`, because the subtree is mounted but not painted
      // — which is precisely the state being asserted.
      final mounted = find.text('makeup body', skipOffstage: false);
      // `.first` is the nearest ancestor: the shell's own Offstage, not the
      // ones Scaffold and Overlay wrap the whole route in.
      final offstage = find
          .ancestor(of: mounted, matching: find.byType(Offstage))
          .first;

      expect(mounted, findsOneWidget);
      expect(tester.widget<Offstage>(offstage).offstage, isTrue);

      await tester.tap(find.text('Makeup'));
      await tester.pumpAndSettle();
      expect(tester.widget<Offstage>(offstage).offstage, isFalse);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      // Still mounted, just not painted.
      expect(mounted, findsOneWidget);
      expect(tester.widget<Offstage>(offstage).offstage, isTrue);
    });
  });

  group('ResultBottomCta', () {
    testWidgets('is one primary button in a bounded strip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: ResultBottomCta(
              label: 'Show me how',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(PrimaryButton), findsOneWidget);
      expect(find.byType(SecondaryButton), findsNothing);
      expect(
        find.byKey(const ValueKey('result-show-tutorial')),
        findsOneWidget,
      );
      expect(find.text('Show me how'), findsOneWidget);
    });

    testWidgets('fires its callback exactly once', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: ResultBottomCta(
              label: 'Show me how',
              onPressed: () => taps++,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('result-show-tutorial')));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      testWidgets('draws from the $mode scheme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: mode,
            home: Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: ResultBottomCta(
                label: 'Show me how',
                onPressed: () {},
              ),
            ),
          ),
        );

        final context = tester.element(find.byType(ResultBottomCta));
        final material = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(ResultBottomCta),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(material.color, Theme.of(context).scaffoldBackgroundColor);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
