import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_semantics.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  Widget child, {
  ThemeData? theme,
  double textScale = 1,
  Size size = const Size(393, 873),
}) => MediaQuery(
  data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
  child: MaterialApp(
    theme: theme ?? AppTheme.lightTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

/// Finds a button by its base class.
///
/// `find.byType` matches the exact runtime type, and `FilledButton.icon`
/// constructs a private `_FilledButtonWithIcon` subclass — so `byType` finds
/// nothing for any of the `.icon` variants these primitives use by default.
Finder _button<T extends ButtonStyleButton>() =>
    find.byWidgetPredicate((widget) => widget is T);

/// Fails if any render box overflowed while laying out.
void expectNoOverflow(WidgetTester tester) {
  expect(
    tester.takeException(),
    isNull,
    reason: 'a shared primitive overflowed its constraints',
  );
}

void main() {
  group('AppNotice carries meaning, not just colour', () {
    testWidgets('each tone paints its own surface, border and accent', (
      tester,
    ) async {
      for (final tone in AppTone.values) {
        await tester.pumpWidget(
          _host(AppNotice(tone: tone, message: 'Something happened.')),
        );

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(AppNotice),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = container.decoration! as BoxDecoration;
        final expected = tone == AppTone.info
            ? AppSemantics.light.info
            : tone == AppTone.success
            ? AppSemantics.light.success
            : tone == AppTone.warning
            ? AppSemantics.light.warning
            : AppSemantics.light.danger;

        expect(decoration.color, expected.surface, reason: '$tone surface');
        expect(
          (decoration.border! as Border).top.color,
          expected.border,
          reason: '$tone border',
        );
      }
    });

    testWidgets('success and danger are not interchangeable', (tester) async {
      // The exact defect this component was built to end: scan_page rendered
      // "Local checks passed" and "Analysis paused" on one identical surface.
      Future<BoxDecoration> decorationFor(AppTone tone) async {
        await tester.pumpWidget(_host(AppNotice(tone: tone, message: 'x')));
        return tester
                .widget<Container>(
                  find
                      .descendant(
                        of: find.byType(AppNotice),
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration!
            as BoxDecoration;
      }

      final success = await decorationFor(AppTone.success);
      final danger = await decorationFor(AppTone.danger);
      expect(success.color, isNot(danger.color));
    });

    testWidgets('the tone icon is shown and differs per tone', (tester) async {
      final seen = <IconData>{};
      for (final tone in AppTone.values) {
        await tester.pumpWidget(_host(AppNotice(tone: tone, message: 'x')));
        final icon = tester.widget<Icon>(
          find
              .descendant(
                of: find.byType(AppNotice),
                matching: find.byType(Icon),
              )
              .first,
        );
        seen.add(icon.icon!);
      }
      expect(seen, hasLength(AppTone.values.length));
    });

    testWidgets('a caller may override the icon but keeps the tone', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const AppNotice(
            tone: AppTone.danger,
            icon: Icons.cloud_off_outlined,
            message: 'Offline.',
          ),
        ),
      );
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      expect(find.byIcon(AppTone.danger.icon), findsNothing);
    });

    testWidgets('title, message and actions all render', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        _host(
          AppNotice(
            tone: AppTone.warning,
            title: 'Guest account',
            message: 'This account is temporary.',
            actions: [
              TertiaryButton(
                label: 'Learn more',
                onPressed: () => pressed = true,
              ),
            ],
          ),
        ),
      );

      expect(find.text('Guest account'), findsOneWidget);
      expect(find.text('This account is temporary.'), findsOneWidget);
      await tester.tap(find.text('Learn more'));
      expect(pressed, isTrue);
    });

    testWidgets('liveRegion is off unless asked for', (tester) async {
      await tester.pumpWidget(_host(const AppNotice(message: 'Ambient copy.')));
      final quiet = tester.getSemantics(find.byType(AppNotice).first);
      expect(quiet.flagsCollection.isLiveRegion, isFalse);

      await tester.pumpWidget(
        _host(const AppNotice(message: 'It failed.', liveRegion: true)),
      );
      final loud = tester.getSemantics(find.byType(AppNotice).first);
      expect(loud.flagsCollection.isLiveRegion, isTrue);
    });

    testWidgets('text stays on the role foreground in dark mode', (
      tester,
    ) async {
      // Without the foreground override the copy inherits the dark theme's
      // near-white onSurface and vanishes on the tinted surface.
      await tester.pumpWidget(
        _host(
          const AppNotice(tone: AppTone.danger, message: 'Analysis paused.'),
          theme: AppTheme.darkTheme,
        ),
      );
      final style = tester.widget<Text>(find.text('Analysis paused.')).style;
      expect(style?.color, AppSemantics.dark.danger.onSurface);
    });

    testWidgets('icon and text stack once the text is large', (tester) async {
      await tester.pumpWidget(
        _host(const AppNotice(message: 'Short.'), textScale: 1),
      );
      expect(
        find.descendant(of: find.byType(AppNotice), matching: find.byType(Row)),
        findsWidgets,
        reason: 'at default scale the icon sits beside the text',
      );

      await tester.pumpWidget(
        _host(const AppNotice(message: 'Short.'), textScale: 2),
      );
      expect(
        find.descendant(of: find.byType(AppNotice), matching: find.byType(Row)),
        findsNothing,
        reason: 'at 2x the icon moves above the text to recover width',
      );
    });

    testWidgets('no overflow on a 320pt screen at 2x text', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          const AppNotice(
            tone: AppTone.danger,
            title: 'We could not finish that',
            message:
                'Your session expired while the preview was generating. '
                'Sign in again and the look you started is still waiting.',
          ),
          textScale: 2,
          size: const Size(320, 640),
        ),
      );
      expectNoOverflow(tester);
    });
  });

  group('button variants', () {
    testWidgets('primary defaults to full width with an icon', (tester) async {
      await tester.pumpWidget(
        _host(PrimaryButton(label: 'Continue', onPressed: () {})),
      );
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(
        tester.getSize(_button<FilledButton>()).width,
        tester.getSize(find.byType(Scaffold)).width,
      );
    });

    testWidgets('expand:false stops it filling the row', (tester) async {
      await tester.pumpWidget(
        _host(
          Row(
            children: [
              PrimaryButton(label: 'Save', expand: false, onPressed: () {}),
            ],
          ),
        ),
      );
      expect(
        tester.getSize(_button<FilledButton>()).width,
        lessThan(tester.getSize(find.byType(Scaffold)).width),
      );
    });

    testWidgets('showIcon:false gives a plain button', (tester) async {
      await tester.pumpWidget(
        _host(PrimaryButton(label: 'Done', showIcon: false, onPressed: () {})),
      );
      // Omitting `icon` has always meant "use the sparkle", so this is the only
      // way to ask for none.
      expect(find.byType(Icon), findsNothing);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('loading shows a spinner and refuses presses', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          PrimaryButton(
            label: 'Saving…',
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      );

      expect(find.byType(ButtonProgress), findsOneWidget);
      await tester.tap(_button<FilledButton>());
      await tester.pump();
      expect(taps, 0, reason: 'an in-flight action must not fire twice');
      expect(
        tester.widget<FilledButton>(_button<FilledButton>()).onPressed,
        isNull,
      );
    });

    testWidgets('a null callback renders as disabled', (tester) async {
      await tester.pumpWidget(
        _host(const PrimaryButton(label: 'Blocked', onPressed: null)),
      );
      expect(
        tester.widget<FilledButton>(_button<FilledButton>()).onPressed,
        isNull,
      );
    });

    testWidgets('secondary mirrors the primary API', (tester) async {
      await tester.pumpWidget(
        _host(
          SecondaryButton(
            label: 'Back',
            showIcon: false,
            expand: false,
            onPressed: () {},
          ),
        ),
      );
      expect(_button<OutlinedButton>(), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('tertiary is inline and iconless by default', (tester) async {
      await tester.pumpWidget(
        _host(TertiaryButton(label: 'Skip', onPressed: () {})),
      );
      expect(_button<TextButton>(), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      // Measured against the screen, not the scroll view: a vertical
      // SingleChildScrollView shrink-wraps to a non-expanding child, so
      // comparing the two would compare the button against itself.
      expect(
        tester.getSize(_button<TextButton>()).width,
        lessThan(tester.getSize(find.byType(Scaffold)).width),
      );
    });

    testWidgets('buttons meet the 48dp touch minimum at default scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              PrimaryButton(label: 'A', onPressed: () {}),
              SecondaryButton(label: 'B', onPressed: () {}),
              TertiaryButton(label: 'C', onPressed: () {}),
            ],
          ),
        ),
      );
      expect(
        tester.getSize(_button<FilledButton>()).height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSize(_button<OutlinedButton>()).height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSize(_button<TextButton>()).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('no overflow at 2x text on a narrow screen', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          Column(
            children: [
              PrimaryButton(label: 'Generate makeup preview', onPressed: () {}),
              SecondaryButton(label: 'Choose from gallery', onPressed: () {}),
            ],
          ),
          textScale: 2,
          size: const Size(320, 640),
        ),
      );
      expectNoOverflow(tester);
    });
  });

  group('DetailRow', () {
    testWidgets('inline reads as one run of text', (tester) async {
      await tester.pumpWidget(
        _host(
          const DetailRow(label: 'Placement', value: 'Along the cheekbone'),
        ),
      );
      expect(find.byType(Text), findsOneWidget);
      expect(find.textContaining('Placement'), findsOneWidget);
      expect(find.textContaining('Along the cheekbone'), findsOneWidget);
    });

    testWidgets('columns uses a fixed label width at normal scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const DetailRow(
            label: 'Finish',
            value: 'Matte',
            layout: DetailRowLayout.columns,
          ),
        ),
      );
      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('columns falls back to inline under large text', (
      tester,
    ) async {
      // A fixed 104pt label column at 2x squeezes the value to a few characters
      // per line, which is the overflow risk UI-P0 flagged in the original.
      await tester.pumpWidget(
        _host(
          const DetailRow(
            label: 'Finish',
            value: 'Matte',
            layout: DetailRowLayout.columns,
          ),
          textScale: 2,
        ),
      );
      expect(find.byType(Row), findsNothing);
    });

    testWidgets('no overflow at 2x on a narrow screen', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          const Column(
            children: [
              DetailRow(
                label: 'Technique',
                value:
                    'Blend upward from the jaw with a dense brush, stopping '
                    'below the cheekbone.',
                layout: DetailRowLayout.columns,
              ),
            ],
          ),
          textScale: 2,
          size: const Size(320, 640),
        ),
      );
      expectNoOverflow(tester);
    });
  });

  group('AppColorSwatch', () {
    testWidgets('a labelled swatch announces its shade as one node', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const AppColorSwatch(
            color: Color(0xFFC46A7F),
            semanticLabel: 'Shade Warm Rose',
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(AppColorSwatch)).label,
        'Shade Warm Rose',
      );
    });

    testWidgets('an unlabelled swatch is decorative, not a silent node', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const AppColorSwatch(color: Color(0xFFC46A7F))),
      );
      expect(
        find.descendant(
          of: find.byType(AppColorSwatch),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a null colour draws a themed placeholder, not a guess', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const AppColorSwatch(color: null)));
      final decoration =
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byType(AppColorSwatch),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      expect(
        decoration.color,
        AppTheme.lightTheme.colorScheme.surfaceContainerHighest,
      );
    });

    testWidgets('the drawn colour is data and ignores the theme', (
      tester,
    ) async {
      const shade = Color(0xFFC46A7F);
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(
          _host(const AppColorSwatch(color: shade), theme: theme),
        );
        final decoration =
            tester
                    .widget<Container>(
                      find.descendant(
                        of: find.byType(AppColorSwatch),
                        matching: find.byType(Container),
                      ),
                    )
                    .decoration!
                as BoxDecoration;
        expect(decoration.color, shade);
      }
    });
  });

  group('input states render from the theme', () {
    testWidgets('an invalid field uses the brand error tone', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _host(
          Form(
            key: formKey,
            child: TextFormField(
              validator: (_) => 'Enter your email.',
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ),
        ),
      );

      formKey.currentState!.validate();
      await tester.pump();

      expect(find.text('Enter your email.'), findsOneWidget);
      final style = tester.widget<Text>(find.text('Enter your email.')).style;
      expect(
        style?.color,
        AppTheme.lightTheme.inputDecorationTheme.errorStyle?.color,
      );
    });

    testWidgets('a field inherits the shared decoration in both themes', (
      tester,
    ) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(
          _host(
            const TextField(decoration: InputDecoration(labelText: 'Name')),
            theme: theme,
          ),
        );
        expectNoOverflow(tester);
        expect(find.text('Name'), findsOneWidget);
      }
    });
  });
}
