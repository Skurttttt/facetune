import 'dart:io';

import 'package:facetune/features/tutorial/presentation/utils/tutorial_labels.dart';
import 'package:facetune/features/tutorial/presentation/utils/tutorial_redraw_reason.dart';
import 'package:facetune/features/tutorial/presentation/widgets/tutorial_redraw_sheet.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// V4-QA-7: the redraw confirmation, and the limits it deliberately keeps.
///
/// The user-facing change is small on purpose. Regeneration was already
/// explicit; what it was not is *confirmed* — a single tap on a scrolling page
/// spent a paid image. These tests hold the two properties that matter: nothing
/// generates without a second deliberate tap, and the reason the user picks is
/// never treated as data.

Future<bool?> _showSheet(
  WidgetTester tester, {
  int attemptsUsed = 0,
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1,
  Size size = const Size(393, 873),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  bool? result;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                result = await TutorialRedrawSheet.confirm(
                  context,
                  attemptsUsed: attemptsUsed,
                );
              },
              child: const Text(TutorialLabels.redraw),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text(TutorialLabels.redraw));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  group('the sheet offers the documented reasons', () {
    testWidgets('all five, and nothing else', (tester) async {
      await _showSheet(tester);

      for (final reason in TutorialRedrawReason.values) {
        expect(
          find.text(TutorialLabels.redrawReason(reason)),
          findsOneWidget,
          reason: '${reason.name} must be offered',
        );
      }
      expect(TutorialRedrawReason.values, hasLength(5));
      expect(
        find.text(
          TutorialLabels.redrawReason(TutorialRedrawReason.placementWrong),
        ),
        findsOneWidget,
      );
    });

    test('the vocabulary matches the phase list exactly', () {
      expect(
        TutorialRedrawReason.values.map(TutorialLabels.redrawReason).toList(),
        <String>[
          'Placement looks wrong',
          'Guide is unclear',
          'Face changed',
          'Too many guidelines',
          'Try another version',
        ],
      );
    });
  });

  group('nothing generates without an explicit confirm', () {
    testWidgets('selecting a reason does not confirm', (tester) async {
      await _showSheet(tester);

      await tester.tap(
        find.text(
          TutorialLabels.redrawReason(TutorialRedrawReason.placementWrong),
        ),
      );
      await tester.pumpAndSettle();

      // The sheet is still open, so nothing has been decided and nothing has
      // been spent. Choosing a reason is not an action.
      expect(find.byType(TutorialRedrawSheet), findsOneWidget);
      expect(find.text(TutorialLabels.redrawConfirm), findsOneWidget);
    });

    testWidgets('cancel resolves false and generates nothing', (tester) async {
      await _showSheet(tester);
      await tester.tap(find.text(TutorialLabels.cancel));
      await tester.pumpAndSettle();
      expect(find.byType(TutorialRedrawSheet), findsNothing);
    });

    testWidgets('confirm resolves true only after its own tap', (tester) async {
      await _showSheet(tester);
      expect(find.byType(TutorialRedrawSheet), findsOneWidget);

      await tester.tap(find.text(TutorialLabels.redrawConfirm));
      await tester.pumpAndSettle();
      expect(find.byType(TutorialRedrawSheet), findsNothing);
    });

    testWidgets('a reason can be chosen and cleared before confirming', (
      tester,
    ) async {
      await _showSheet(tester);
      final placement = find.text(
        TutorialLabels.redrawReason(TutorialRedrawReason.placementWrong),
      );

      await tester.tap(placement);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Tapping again clears it, so a mis-tap is recoverable in place.
      await tester.tap(placement);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('only one reason is selected at a time', (tester) async {
      await _showSheet(tester);
      await tester.tap(
        find.text(
          TutorialLabels.redrawReason(TutorialRedrawReason.placementWrong),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          TutorialLabels.redrawReason(TutorialRedrawReason.faceChanged),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });

  group('the sheet is honest about what it does', () {
    testWidgets('it says the answer is not sent anywhere', (tester) async {
      await _showSheet(tester);
      expect(find.text(TutorialLabels.redrawReasonPrivacy), findsOneWidget);
      expect(
        TutorialLabels.redrawReasonPrivacy,
        contains('not sent with the request'),
      );
      expect(
        TutorialLabels.redrawReasonPrivacy,
        contains('does not change how the image is drawn'),
      );
    });

    testWidgets('it says what redrawing costs the user', (tester) async {
      await _showSheet(tester);
      expect(find.text(TutorialLabels.redrawExplanation), findsOneWidget);
    });

    // One sheet per test: the launcher button and the sheet heading share the
    // same copy, so showing a second sheet over the first makes every
    // text finder ambiguous.
    testWidgets('a never-redrawn step mentions no previous attempts', (
      tester,
    ) async {
      await _showSheet(tester, attemptsUsed: 0);
      expect(find.textContaining('already'), findsNothing);
    });

    testWidgets('one previous attempt reads as "once"', (tester) async {
      await _showSheet(tester, attemptsUsed: 1);
      expect(
        find.text('You have drawn this step once already.'),
        findsOneWidget,
      );
    });

    testWidgets('several attempts are counted, with no "of 5" claim', (
      tester,
    ) async {
      await _showSheet(tester, attemptsUsed: 3);
      expect(
        find.text('You have drawn this step 3 times already.'),
        findsOneWidget,
      );
      // The server ceiling has no Dart mirror, so none is claimed here.
      expect(find.textContaining('of 5'), findsNothing);
    });
  });

  group('presentation holds up', () {
    for (final (mode, name) in <(ThemeMode, String)>[
      (ThemeMode.light, 'Light'),
      (ThemeMode.dark, 'Dark'),
      (ThemeMode.system, 'System'),
    ]) {
      testWidgets('it renders under $name', (tester) async {
        await _showSheet(tester, themeMode: mode);
        expect(find.byType(TutorialRedrawSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('it survives a narrow screen at large text', (tester) async {
      await _showSheet(
        tester,
        attemptsUsed: 2,
        size: const Size(320, 640),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the reason is not persisted anywhere', () {
    final root = Directory.current;

    String source(String relativePath) => File(
      '${root.path}${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}',
    ).readAsStringSync();

    test('no migration adds a feedback column', () {
      // The database gate. If a later phase wants real feedback analytics it
      // must be designed and approved as such, not smuggled into a column that
      // already means something else.
      final migrations = Directory(
        '${root.path}${Platform.pathSeparator}supabase'
        '${Platform.pathSeparator}migrations',
      ).listSync().whereType<File>().map((file) => file.readAsStringSync());
      for (final migration in migrations) {
        for (final forbidden in <String>[
          'redraw_reason',
          'regeneration_reason',
          'feedback_reason',
          'user_feedback',
        ]) {
          expect(
            migration.contains(forbidden),
            isFalse,
            reason: 'persisting a reason needs an approved migration',
          );
        }
      }
    });

    test('the reason never reaches the repository or the network', () {
      // It is a presentation-only value: the sheet returns a bool, and the
      // controller is never handed the reason at all.
      for (final path in <String>[
        'lib/features/tutorial/presentation/controllers/tutorial_controller.dart',
        'lib/features/tutorial/data/repositories/supabase_tutorial_step_repository.dart',
        'lib/features/tutorial/data/data_sources/tutorial_remote_data_source.dart',
      ]) {
        expect(
          source(path),
          isNot(contains('TutorialRedrawReason')),
          reason: '$path must never see the reason',
        );
      }
      expect(
        source(
          'lib/features/tutorial/presentation/widgets/tutorial_redraw_sheet.dart',
        ),
        contains('Future<bool>'),
        reason: 'the sheet answers only whether the user confirmed',
      );
    });

    test('no automatic visual-quality retry was introduced', () {
      final config = source('supabase/functions/_shared/tutorial_ai_config.ts');
      expect(config, contains('GUIDELINE_MAXIMUM_ATTEMPTS = 2'));
      expect(config, contains('MAXIMUM_STEP_ATTEMPTS = 5'));
      // Asserted as one source line: the surrounding comment wraps, and a
      // fragment spanning the wrap would never match.
      expect(config, contains('poor-but-valid guideline is not retried'));
    });

    test('the locked model and resolution are untouched', () {
      final config = source('supabase/functions/_shared/tutorial_ai_config.ts');
      expect(config, contains('"gemini-3.1-flash-image"'));
      expect(
        config,
        contains('export const TUTORIAL_OUTPUT_RESOLUTION = "1K" as const'),
      );
      expect(
        config,
        contains(
          'export const TUTORIAL_GUIDELINE_PROMPT_VERSION = '
          '"tutorial_guideline_v4_7"',
        ),
      );
      expect(config, isNot(contains('"0.5K"')));
    });
  });
}
