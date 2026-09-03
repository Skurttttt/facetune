import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hosts a page that was pushed, so `impliesAppBarDismissal` is true and the
/// automatic back control appears exactly as it would in the app.
Future<void> _pumpPushed(
  WidgetTester tester,
  Widget page, {
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1,
  Size size = const Size(393, 873),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (context) => page)),
              child: const Text('Open'),
            ),
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
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  group('FaceTuneBackButton', () {
    testWidgets('renders a circular control at the accessible touch target', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: FaceTuneBackButton(onPressed: () {})),
        ),
      );

      final control = find.byType(FaceTuneBackButton);
      expect(control, findsOneWidget);
      final size = tester.getSize(control);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      expect(size.width, size.height);

      final material = tester.widget<Material>(
        find.descendant(of: control, matching: find.byType(Material)),
      );
      expect(material.shape, isA<CircleBorder>());

      final icon = tester.widget<Icon>(
        find.descendant(of: control, matching: find.byType(Icon)),
      );
      expect(icon.icon, Icons.chevron_left_rounded);
      expect(icon.size, inInclusiveRange(20, 22));
    });

    testWidgets('announces itself once as a button labelled Back', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: FaceTuneBackButton(onPressed: () {})),
        ),
      );

      final node = find.bySemanticsLabel('Back');
      expect(node, findsOneWidget);
      final semantics = tester.getSemantics(node);
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.label, 'Back');
      handle.dispose();
    });

    testWidgets('fires its callback exactly once per tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: FaceTuneBackButton(onPressed: () => taps++)),
        ),
      );

      await tester.tap(find.byType(FaceTuneBackButton));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets(
      'with no callback it pops the route, like the default control',
      (tester) async {
        await _pumpPushed(
          tester,
          const Scaffold(
            appBar: FaceTuneTopBar(title: 'Pushed'),
            body: Text('Pushed body'),
          ),
        );
        expect(find.text('Pushed body'), findsOneWidget);

        await tester.tap(find.byType(FaceTuneBackButton));
        await tester.pumpAndSettle();

        expect(find.text('Pushed body'), findsNothing);
        expect(find.text('Open'), findsOneWidget);
      },
    );

    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      testWidgets('draws from the $mode ColorScheme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: mode,
            home: Scaffold(body: FaceTuneBackButton(onPressed: () {})),
          ),
        );

        final context = tester.element(find.byType(FaceTuneBackButton));
        final theme = Theme.of(context);
        final material = tester.widget<Material>(
          find.descendant(
            of: find.byType(FaceTuneBackButton),
            matching: find.byType(Material),
          ),
        );
        expect(material.color, theme.colorScheme.surfaceContainerHighest);
        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byType(FaceTuneBackButton),
            matching: find.byType(Icon),
          ),
        );
        expect(icon.color, theme.appBarTheme.iconTheme?.color);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('keeps its geometry at 2x text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(body: FaceTuneBackButton(onPressed: () {})),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(FaceTuneBackButton)),
        const Size(44, 44),
      );
    });
  });

  group('FaceTuneTopBar', () {
    testWidgets('back only draws no title', (tester) async {
      await _pumpPushed(
        tester,
        const Scaffold(appBar: FaceTuneTopBar(), body: SizedBox()),
      );

      expect(find.byType(FaceTuneBackButton), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FaceTuneTopBar),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('back and title sit on the shared gutter', (tester) async {
      await _pumpPushed(
        tester,
        const Scaffold(
          appBar: FaceTuneTopBar(title: 'My Makeup Kit'),
          body: SizedBox(),
        ),
      );

      expect(find.text('My Makeup Kit'), findsOneWidget);
      expect(tester.getTopLeft(find.byType(FaceTuneBackButton)).dx, 20);
      expect(
        tester.getTopLeft(find.text('My Makeup Kit')).dx,
        greaterThan(tester.getBottomRight(find.byType(FaceTuneBackButton)).dx),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('back, title and a trailing action coexist without overflow', (
      tester,
    ) async {
      await _pumpPushed(
        tester,
        Scaffold(
          appBar: FaceTuneTopBar(
            title: 'Saved Looks',
            actions: <Widget>[
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.more_vert_rounded),
              ),
            ],
          ),
          body: const SizedBox(),
        ),
      );

      expect(find.byType(FaceTuneBackButton), findsOneWidget);
      expect(find.text('Saved Looks'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('one back semantics node, not two', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPushed(
        tester,
        const Scaffold(
          appBar: FaceTuneTopBar(title: 'Settings'),
          body: SizedBox(),
        ),
      );

      expect(find.bySemanticsLabel('Back'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      handle.dispose();
    });

    testWidgets('a screen that cannot pop shows no back control', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: FaceTuneTopBar(title: 'Home'),
            body: SizedBox(),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.byType(FaceTuneBackButton), findsNothing);
    });

    testWidgets('a long title truncates rather than overflowing', (
      tester,
    ) async {
      await _pumpPushed(
        tester,
        const Scaffold(
          appBar: FaceTuneTopBar(
            title: 'An extremely long screen title that cannot possibly fit',
          ),
          body: SizedBox(),
        ),
        textScale: 2,
        size: const Size(320, 640),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(FaceTuneBackButton), findsOneWidget);
    });
  });
}
