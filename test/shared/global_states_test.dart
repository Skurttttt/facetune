import 'package:facetune/core/constants/app_constants.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_semantics.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  Widget child, {
  ThemeData? theme,
  double textScale = 1,
  bool scroll = true,
}) => MediaQuery(
  data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
  child: MaterialApp(
    theme: theme ?? AppTheme.lightTheme,
    home: Scaffold(body: scroll ? SingleChildScrollView(child: child) : child),
  ),
);

void _expectNoOverflow(WidgetTester tester) {
  expect(
    tester.takeException(),
    isNull,
    reason: 'a global state widget overflowed its constraints',
  );
}

void main() {
  group('app shell — navigation presentation, not navigation', () {
    test('the destinations and their order are unchanged', () {
      // The guard for this whole phase. UI-P2 may restyle the shell; it may
      // never move where a tab goes. If this list changes, a presentation
      // phase has silently become a routing change.
      expect(AppShell.destinations.map((d) => d.route).toList(), <String>[
        AppConstants.homeRoute,
        AppConstants.savedRoute,
        AppConstants.historyRoute,
        AppConstants.profileRoute,
      ]);
    });

    test('every destination distinguishes selected from unselected', () {
      // History used to be the only tab with no selected variant, so its icon
      // did not change and selection rested on the indicator pill alone.
      for (final destination in AppShell.destinations) {
        expect(
          destination.selectedIcon,
          isNot(destination.icon),
          reason: '${destination.label} cannot show selection by icon',
        );
      }
    });

    testWidgets('renders four labelled tabs in light and dark', (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const AppShell(index: 0, child: SizedBox.shrink()),
          ),
        );
        _expectNoOverflow(tester);
        expect(find.byType(NavigationBar), findsOneWidget);
        for (final destination in AppShell.destinations) {
          expect(find.text(destination.label), findsOneWidget);
        }
      }
    });

    testWidgets('labels stay visible regardless of selection', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AppShell(index: 2, child: SizedBox.shrink()),
        ),
      );
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.labelBehavior, NavigationDestinationLabelBehavior.alwaysShow);
      expect(bar.selectedIndex, 2);
    });

    testWidgets('the shell survives large text on a narrow screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const AppShell(index: 0, child: SizedBox.shrink()),
          ),
        ),
      );
      _expectNoOverflow(tester);
    });
  });

  group('status states carry their meaning', () {
    testWidgets('each intent resolves its own tone', (tester) async {
      final cases = <String, (Widget, AppSemanticRole)>{
        'empty': (
          const StatusState.empty(title: 'Nothing yet', message: 'm'),
          AppSemantics.light.info,
        ),
        'error': (
          const StatusState.error(title: 'It failed', message: 'm'),
          AppSemantics.light.danger,
        ),
        'success': (
          const StatusState.success(title: 'Saved', message: 'm'),
          AppSemantics.light.success,
        ),
        'info': (
          const StatusState.info(title: 'Heads up', message: 'm'),
          AppSemantics.light.info,
        ),
      };

      for (final entry in cases.entries) {
        await tester.pumpWidget(_host(entry.value.$1));
        final badge = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(StatusState),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = badge.decoration! as BoxDecoration;
        expect(
          decoration.color,
          entry.value.$2.surface,
          reason: '${entry.key} badge surface',
        );
        final icon = tester.widget<Icon>(
          find
              .descendant(
                of: find.byType(StatusState),
                matching: find.byType(Icon),
              )
              .first,
        );
        expect(
          icon.color,
          entry.value.$2.accent,
          reason: '${entry.key} badge icon',
        );
      }
    });

    testWidgets('an error and a success are not interchangeable', (
      tester,
    ) async {
      Future<Color?> badgeColour(Widget widget) async {
        await tester.pumpWidget(_host(widget));
        return ((tester
                    .widget<Container>(
                      find
                          .descendant(
                            of: find.byType(StatusState),
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration!)
                as BoxDecoration)
            .color;
      }

      final failure = await badgeColour(
        const StatusState.error(title: 'a', message: 'b'),
      );
      final win = await badgeColour(
        const StatusState.success(title: 'a', message: 'b'),
      );
      expect(failure, isNot(win));
    });

    testWidgets('an error announces itself, an empty state does not', (
      tester,
    ) async {
      // An error is the result of something the user just did. Silence there
      // leaves them waiting for feedback that never arrives.
      await tester.pumpWidget(
        _host(const StatusState.error(title: 'Failed', message: 'm')),
      );
      expect(
        tester
            .getSemantics(find.byType(StatusState))
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );

      await tester.pumpWidget(
        _host(const StatusState.empty(title: 'Nothing', message: 'm')),
      );
      expect(
        tester
            .getSemantics(find.byType(StatusState))
            .flagsCollection
            .isLiveRegion,
        isFalse,
      );
    });

    testWidgets('the default constructor is unchanged for existing callers', (
      tester,
    ) async {
      // 38 call sites still use this. It must keep rendering the info tone and
      // must not start announcing itself.
      await tester.pumpWidget(
        _host(const StatusState(title: 'Legacy', message: 'm')),
      );
      final icon = tester.widget<Icon>(
        find
            .descendant(
              of: find.byType(StatusState),
              matching: find.byType(Icon),
            )
            .first,
      );
      expect(icon.icon, Icons.auto_awesome_rounded);
      expect(icon.color, AppSemantics.light.info.accent);
      expect(
        tester
            .getSemantics(find.byType(StatusState))
            .flagsCollection
            .isLiveRegion,
        isFalse,
      );
    });

    testWidgets('actions still fire', (tester) async {
      var primary = false;
      var secondary = false;
      await tester.pumpWidget(
        _host(
          StatusState.error(
            title: 'Could not load',
            message: 'Check your connection.',
            actionLabel: 'Retry',
            onAction: () => primary = true,
            secondaryActionLabel: 'Go back',
            onSecondaryAction: () => secondary = true,
          ),
        ),
      );
      await tester.tap(find.text('Retry'));
      await tester.tap(find.text('Go back'));
      expect(primary, isTrue);
      expect(secondary, isTrue);
    });

    testWidgets('renders without overflow at 2x on a 320pt screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(
          _host(
            StatusState.error(
              title: 'Preview generation paused',
              message:
                  'Your session expired while the preview was generating. '
                  'Sign in again and the look you started is still waiting.',
              actionLabel: 'Sign in again',
              onAction: () {},
              secondaryActionLabel: 'Return to makeup plan',
              onSecondaryAction: () {},
            ),
            theme: theme,
            textScale: 2,
          ),
        );
        _expectNoOverflow(tester);
      }
    });
  });

  group('loading states are honest and inert', () {
    testWidgets('the shared spinner offers no determinate value', (
      tester,
    ) async {
      // AppProgress has no `value` parameter at all. Nothing FaceTune waits on
      // reports progress, so a fillable bar would be an invented number.
      await tester.pumpWidget(_host(const AppProgress()));
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, isNull);
    });

    testWidgets('LoadingState is indeterminate unless given real progress', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const LoadingState(label: 'Working…')));
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        isNull,
      );

      await tester.pumpWidget(
        _host(const LoadingState(label: 'Uploading…', progress: .5)),
      );
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        .5,
      );
    });

    testWidgets('an animating skeleton does not rebuild its ancestors', (
      tester,
    ) async {
      // This is the mechanism by which a loading animation could re-trigger
      // paid work: if the shimmer rebuilt the subtree above it, a page whose
      // build starts a generation would start one on every frame. The
      // controller must stay inside the skeleton.
      var ancestorBuilds = 0;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              ancestorBuilds++;
              return const SkeletonCard(imageHeight: 96);
            },
          ),
        ),
      );
      expect(ancestorBuilds, 1);

      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        ancestorBuilds,
        1,
        reason: 'the shimmer rebuilt the widget above it',
      );
    });

    testWidgets('a skeleton with no image promises no image', (tester) async {
      await tester.pumpWidget(_host(const SkeletonCard(imageHeight: 0)));
      _expectNoOverflow(tester);
      // Two text bars and nothing else — the tall block is omitted rather than
      // drawn at zero height with its gap left behind.
      final boxes = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(SkeletonCard),
          matching: find.byType(Container),
        ),
      );
      expect(boxes.length, 2);
    });

    testWidgets('a skeleton is announced once, not per bar', (tester) async {
      await tester.pumpWidget(_host(const SkeletonCard()));
      expect(find.bySemanticsLabel('Loading content'), findsOneWidget);
    });
  });

  group('transient feedback', () {
    /// Shows one snackbar in a freshly mounted app and settles its entry
    /// animation.
    ///
    /// The unique key forces a full remount rather than an in-place update:
    /// re-pumping the same tree leaves the previous snackbar mid-dismissal, and
    /// `find.byType(SnackBar)` then returns the *old* one — which made every
    /// assertion here read the previous case's colour.
    Future<SnackBar> showOne(
      WidgetTester tester, {
      required AppTone tone,
      ThemeData? theme,
      String? actionLabel,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          theme: theme ?? AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAppSnackBar(
                  context,
                  message: 'Something happened.',
                  tone: tone,
                  actionLabel: actionLabel,
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      return tester.widget<SnackBar>(find.byType(SnackBar).last);
    }

    testWidgets('each tone gets its own ground in light and dark', (
      tester,
    ) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        final palette = theme.extension<AppSemantics>()!;
        final expected = {
          AppTone.info: palette.info.feedbackSurface,
          AppTone.success: palette.success.feedbackSurface,
          AppTone.warning: palette.warning.feedbackSurface,
          AppTone.danger: palette.danger.feedbackSurface,
        };
        for (final entry in expected.entries) {
          final bar = await showOne(tester, tone: entry.key, theme: theme);
          expect(
            bar.backgroundColor,
            entry.value,
            reason: '${entry.key} under ${theme.brightness}',
          );
        }
      }
    });

    testWidgets('a failure is not styled like a confirmation', (tester) async {
      final failure = await showOne(tester, tone: AppTone.danger);
      final win = await showOne(tester, tone: AppTone.success);
      expect(failure.backgroundColor, isNot(win.backgroundColor));
    });

    testWidgets('an error stays on screen longer than a confirmation', (
      tester,
    ) async {
      final failure = await showOne(tester, tone: AppTone.danger);
      final win = await showOne(tester, tone: AppTone.success);
      expect(failure.duration, greaterThan(win.duration));
    });

    testWidgets('the label contrasts with its own ground', (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        final palette = theme.extension<AppSemantics>()!;
        final bar = await showOne(
          tester,
          tone: AppTone.danger,
          theme: theme,
          actionLabel: 'Retry',
        );
        expect(
          (bar.content as Text).style?.color,
          palette.danger.onFeedbackSurface,
        );
        expect(bar.action?.textColor, palette.danger.onFeedbackSurface);
      }
    });

    testWidgets('a second message replaces the first rather than queueing', (
      tester,
    ) async {
      // Queued snackbars mean the user reads a stale message while the current
      // one waits its turn.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAppSnackBar(
                  context,
                  message: 'Message ${DateTime.now()}',
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.tap(find.text('go'));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 10));
    });
  });

  group('confirmation dialogs', () {
    Future<bool?> show(
      WidgetTester tester, {
      required bool isDestructive,
    }) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await showConfirmationDialog(
                  context,
                  title: 'Delete this history session?',
                  message: 'This cannot be undone.',
                  isDestructive: isDestructive,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('a destructive confirm is visually distinct and named', (
      tester,
    ) async {
      await show(tester, isDestructive: true);
      // Not "Confirm": the label should say what is about to happen.
      expect(find.text('Delete'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      final button = tester.widget<FilledButton>(
        find.byWidgetPredicate((w) => w is FilledButton),
      );
      expect(button.style?.backgroundColor, isNotNull);
    });

    testWidgets('an ordinary confirm carries no alarm', (tester) async {
      await show(tester, isDestructive: false);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('dismissing never reads as confirmation', (tester) async {
      // A caller writes `if (result == true)`. Walking away must not delete
      // anything.
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await showConfirmationDialog(
                  context,
                  title: 'Delete?',
                  message: 'Gone for good.',
                  isDestructive: true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10)); // barrier
      await tester.pumpAndSettle();
      expect(result, isNot(true));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  group('common image states', () {
    testWidgets('the placeholder is quiet and indeterminate', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(height: 120, width: 120, child: ImagePlaceholder()),
          scroll: false,
        ),
      );
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        isNull,
      );
    });

    testWidgets('the failure state says nothing about why', (tester) async {
      // The usual cause is an expired signed URL. Naming that would leak how
      // storage access works and help the user not at all.
      await tester.pumpWidget(
        _host(
          const SizedBox(height: 120, width: 120, child: ImageUnavailable()),
          scroll: false,
        ),
      );
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(find.textContaining('url', findRichText: true), findsNothing);
      expect(find.textContaining('token', findRichText: true), findsNothing);
      expect(find.bySemanticsLabel('Image unavailable'), findsOneWidget);
    });

    testWidgets('both render in either theme without overflow', (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(
          _host(
            const SizedBox(
              height: 80,
              width: 80,
              child: Column(
                children: [
                  Expanded(child: ImagePlaceholder()),
                  Expanded(child: ImageUnavailable()),
                ],
              ),
            ),
            theme: theme,
            scroll: false,
          ),
        );
        _expectNoOverflow(tester);
      }
    });
  });
}
