import 'dart:io';

import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:facetune/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// POLISH-P3 — one header rhythm across the four top-level screens.
///
/// Before this, Home, Saved, History and Profile each decided their own top
/// inset, their own title-to-subtitle gap, and their own subtitle colour. The
/// component is the fix; these tests are what stop the four drifting again.
void main() {
  group('the header metrics are one decision', () {
    test('every value is an existing spacing token', () {
      // Not screenshot-derived numbers. If a header ever needs a value that is
      // not on the scale, that is a design conversation, not a constant.
      final scale = <double>{
        AppSpacing.xxs,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      };
      expect(scale, contains(TopLevelHeaderMetrics.topInset));
      expect(scale, contains(TopLevelHeaderMetrics.titleGap));
      expect(scale, contains(TopLevelHeaderMetrics.contentGap));
    });

    test('breathing room exceeds the frame lead-in it replaces', () {
      // The complaint P3 exists to fix: 8pt between the status bar and a 27pt
      // headline. The header's own inset has to be meaningfully more than that.
      expect(
        TopLevelHeaderMetrics.topInset,
        greaterThan(PageFrame.scrollingPadding.top),
      );
    });
  });

  group('TopLevelPageHeader', () {
    testWidgets('lays out title, subtitle and trailing action in one rhythm', (
      tester,
    ) async {
      await _pump(
        tester,
        const TopLevelPageHeader(
          title: 'History',
          subtitle: 'Revisit every step of your FaceTune journey.',
          trailing: Icon(Icons.settings_outlined, key: Key('trailing')),
        ),
      );

      final title = tester.getRect(find.text('History'));
      final subtitle = tester.getRect(
        find.text('Revisit every step of your FaceTune journey.'),
      );
      final trailing = tester.getRect(find.byKey(const Key('trailing')));

      // The trailing action belongs to the title row, not to the page.
      expect(trailing.center.dy, closeTo(title.center.dy, title.height));
      expect(trailing.left, greaterThan(title.left));
      // Subtitle sits below the title, and the title starts on the same left
      // edge as everything else in the column.
      expect(subtitle.top, greaterThanOrEqualTo(title.bottom));
      expect(subtitle.left, closeTo(title.left, 0.01));
    });

    testWidgets('a header with no subtitle draws no empty gap', (tester) async {
      await _pump(tester, const TopLevelPageHeader(title: 'Profile'));

      expect(find.byType(SizedBox), findsNothing);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('the subtitle is supporting copy, not a second title', (
      tester,
    ) async {
      await _pump(
        tester,
        const TopLevelPageHeader(title: 'Saved looks', subtitle: 'Supporting.'),
      );

      final context = tester.element(find.text('Supporting.'));
      final subtitle = tester.widget<Text>(find.text('Supporting.'));
      final title = tester.widget<Text>(find.text('Saved looks'));

      expect(subtitle.style?.color, AppColors.muted(context));
      expect(
        title.style?.fontSize,
        greaterThan(subtitle.style?.fontSize ?? double.infinity),
      );
    });
  });

  group('HomeGreetingHeader', () {
    testWidgets('shares the spacing family but keeps its own hierarchy', (
      tester,
    ) async {
      await _pump(
        tester,
        const Column(
          children: [
            TopLevelPageHeader(title: 'History', subtitle: 'Sub.'),
            HomeGreetingHeader(
              greeting: 'Welcome back, Kurt',
              supportingText: 'Sub.',
            ),
          ],
        ),
      );

      final page = tester.widget<Text>(find.text('History'));
      final greeting = tester.widget<Text>(find.text('Welcome back, Kurt'));

      // A dashboard greeting, quieter than a page title on purpose.
      expect(greeting.style?.fontSize, lessThan(page.style!.fontSize!));
      // P3 forbids reducing the page-title size to make room at the top.
      expect(page.style?.fontSize, 27);
    });

    testWidgets('a very long display name wraps instead of overflowing', (
      tester,
    ) async {
      await _pump(
        tester,
        HomeGreetingHeader(
          greeting: 'Welcome back, ${'Anastasia-Wilhelmina ' * 6}',
          supportingText: 'What beauty mood are you in?',
          trailing: IconButton.filledTonal(
            onPressed: () {},
            icon: const Icon(Icons.tune_rounded),
          ),
        ),
        width: 320,
      );

      expect(tester.takeException(), isNull);
      // The control keeps its place beside the greeting rather than being
      // pushed off the edge by it.
      final trailing = tester.getRect(find.byType(IconButton));
      expect(trailing.right, lessThanOrEqualTo(320));
      expect(find.text('What beauty mood are you in?'), findsOneWidget);
    });
  });

  group('the four pages share one header system', () {
    test('none of them hand-rolls a title row any more', () {
      const pages = {
        'Home': (
          'lib/features/home/presentation/pages/home_page.dart',
          'HomeGreetingHeader(',
        ),
        'Saved': (
          'lib/features/saved_looks/presentation/pages/saved_looks_page.dart',
          'TopLevelPageHeader(',
        ),
        'History': (
          'lib/features/history/presentation/pages/history_page.dart',
          'TopLevelPageHeader(',
        ),
        'Profile': (
          'lib/features/profile/presentation/pages/profile_page.dart',
          'TopLevelPageHeader(',
        ),
      };

      for (final MapEntry(key: tab, value: (path, component))
          in pages.entries) {
        final source = File(path).readAsStringSync();
        expect(source, contains(component), reason: '$tab bypasses the system');
        // Deliberately not asserted here: that the page never names a headline
        // token. Home's scan hero and Profile's avatar initials both use
        // `headlineMedium` legitimately, and a grep cannot tell those from a
        // title. The title's own size is pinned in the widget test above.

        // One SafeArea per page, and it is the page's own — not a second one
        // nested inside the header or the frame.
        expect(
          'SafeArea('.allMatches(source).length,
          1,
          reason: '$tab does not own exactly one SafeArea',
        );
        // Manual status-bar compensation is what the shared inset replaces.
        expect(
          source,
          isNot(contains('MediaQuery.of(context).padding.top')),
          reason: '$tab compensates for the status bar by hand',
        );
      }
    });

    test('the header supplies the inset, so the frame does not', () {
      final frame = File(
        'lib/shared/widgets/layout/page_frame.dart',
      ).readAsStringSync();
      // POLISH-P1 removed the bottom tail; the top stays a lead-in. If a top
      // inset ever moved in here, every non-header screen would pay it too.
      expect(frame, isNot(contains('TopLevelHeaderMetrics')));
    });
  });

  group('themes and text sizes', () {
    for (final (name, mode) in [
      ('Light', ThemeMode.light),
      ('Dark', ThemeMode.dark),
      ('System', ThemeMode.system),
    ]) {
      testWidgets('$name renders both headers without overflow', (
        tester,
      ) async {
        await _pump(
          tester,
          const Column(
            children: [
              TopLevelPageHeader(
                title: 'History',
                subtitle: 'Revisit every step of your FaceTune journey.',
                trailing: Icon(Icons.settings_outlined),
              ),
              HomeGreetingHeader(
                greeting: 'Welcome back, Kurt',
                supportingText: 'What beauty mood are you in?',
              ),
            ],
          ),
          themeMode: mode,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('History'), findsOneWidget);
        expect(find.text('Welcome back, Kurt'), findsOneWidget);
      });
    }

    for (final scale in [1.3, 2.0]) {
      testWidgets('${scale}x text on a narrow screen still fits', (
        tester,
      ) async {
        await _pump(
          tester,
          const TopLevelPageHeader(
            title: 'Saved looks',
            subtitle: 'Your personal makeup library, ready when you are.',
            trailing: Icon(Icons.settings_outlined),
          ),
          width: 320,
          textScale: scale,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Saved looks'), findsOneWidget);
        // Nothing is dropped to make room.
        expect(
          find.text('Your personal makeup library, ready when you are.'),
          findsOneWidget,
        );
      });
    }
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget header, {
  double width = 393,
  double textScale = 1,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: Scaffold(
        // The composition the four pages use: one SafeArea, then the frame,
        // then the header. Nothing else adds a top inset.
        body: SafeArea(
          child: PageFrame.scrolling(
            child: SingleChildScrollView(child: header),
          ),
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
