import 'package:facetune/features/tutorial/domain/catalog/tutorial_instruction_catalog.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_guide_type.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_instruction.dart';
import 'package:facetune/features/tutorial/presentation/utils/tutorial_labels.dart';
import 'package:facetune/features/tutorial/presentation/widgets/tutorial_guide_key.dart';
import 'package:facetune/features/tutorial/presentation/widgets/tutorial_instructions_card.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:facetune/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] under the real app theme, so these assert what the app
/// actually renders rather than a bare Material default.
Future<void> pump(
  WidgetTester tester,
  Widget child, {
  ThemeMode mode = ThemeMode.light,
  double textScale = 1,
  Size size = const Size(393, 873), // POCO X3 GT logical size.
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the guide key explains the marks', () {
    testWidgets('it renders a glyph and a name for each referenced type', (
      tester,
    ) async {
      await pump(
        tester,
        const TutorialGuideKey(types: TutorialGuideType.values),
      );

      expect(find.text(TutorialLabels.guideKey), findsOneWidget);
      for (final type in TutorialGuideType.values) {
        expect(find.text(type.symbol), findsOneWidget);
        expect(find.text(TutorialLabels.guideTypeName(type)), findsOneWidget);
      }
    });

    testWidgets('it lists only the types this step actually uses', (
      tester,
    ) async {
      await pump(
        tester,
        const TutorialGuideKey(
          types: <TutorialGuideType>[
            TutorialGuideType.startAnchor,
            TutorialGuideType.direction,
          ],
        ),
      );

      expect(
        find.text(TutorialLabels.guideTypeName(TutorialGuideType.startAnchor)),
        findsOneWidget,
      );
      expect(
        find.text(TutorialLabels.guideTypeName(TutorialGuideType.direction)),
        findsOneWidget,
      );
      // Showing a key entry for a mark that was never drawn would send the user
      // hunting for it.
      expect(
        find.text(TutorialLabels.guideTypeName(TutorialGuideType.blendZone)),
        findsNothing,
      );
    });

    testWidgets('an empty key renders nothing at all', (tester) async {
      await pump(tester, const TutorialGuideKey(types: <TutorialGuideType>[]));
      expect(find.text(TutorialLabels.guideKey), findsNothing);
    });

    testWidgets('meaning never rests on colour or glyph alone', (tester) async {
      await pump(
        tester,
        const TutorialGuideKey(types: TutorialGuideType.values),
      );
      // Every entry carries a spoken description, so a screen reader and a
      // colour-blind user both get the meaning.
      for (final type in TutorialGuideType.values) {
        expect(
          find.bySemanticsLabel(TutorialLabels.guideTypeSemantics(type)),
          findsOneWidget,
        );
      }
    });
  });

  group('instructions are numbered and tied to the guides', () {
    testWidgets('every category renders its numbered steps in order', (
      tester,
    ) async {
      for (final category in TutorialCategory.orderedVocabulary) {
        final instructions = TutorialInstructionCatalog.forCategory(category);
        await pump(
          tester,
          TutorialInstructionsCard(instructions: instructions),
        );

        expect(find.text(TutorialLabels.howToApply), findsOneWidget);
        for (final step in instructions.steps) {
          expect(find.text('${step.sequence}'), findsOneWidget);
          expect(find.text(step.shortTitle), findsOneWidget);
          expect(find.text(step.instruction), findsOneWidget);
        }
      }
    });

    testWidgets('each instruction shows its guide symbol beside it', (
      tester,
    ) async {
      final instructions = TutorialInstructionCatalog.forCategory(
        TutorialCategory.blush,
      );
      await pump(tester, TutorialInstructionsCard(instructions: instructions));

      for (final step in instructions.steps) {
        expect(find.text(step.guideType.symbol), findsWidgets);
      }
    });

    testWidgets('a screen reader hears the number, the guide, and the text', (
      tester,
    ) async {
      final instructions = TutorialInstructionCatalog.forCategory(
        TutorialCategory.eyeliner,
      );
      await pump(tester, TutorialInstructionsCard(instructions: instructions));

      final first = instructions.steps.first;
      expect(
        find.bySemanticsLabel(
          'Step ${first.sequence}. ${first.shortTitle}. '
          '${TutorialLabels.guideTypeSemantics(first.guideType)}. '
          '${first.instruction}',
        ),
        findsOneWidget,
      );
    });
  });

  group('the goal is shown only when it is authoritative', () {
    testWidgets('it renders when the recommendation supplied one', (
      tester,
    ) async {
      await pump(
        tester,
        TutorialInstructionsCard(
          instructions: TutorialInstructionCatalog.forCategory(
            TutorialCategory.blush,
          ),
          goal: 'Adds warmth while visually lifting the face.',
        ),
      );

      expect(find.text(TutorialLabels.yourGoal), findsOneWidget);
      expect(
        find.text('Adds warmth while visually lifting the face.'),
        findsOneWidget,
      );
    });

    testWidgets('it is absent rather than invented when there is none', (
      tester,
    ) async {
      await pump(
        tester,
        TutorialInstructionsCard(
          instructions: TutorialInstructionCatalog.forCategory(
            TutorialCategory.blush,
          ),
        ),
      );

      // My Makeup Kit has no reasoning field; the step still teaches, but it
      // does not manufacture a goal to fill the gap.
      expect(find.text(TutorialLabels.yourGoal), findsNothing);
      expect(find.text(TutorialLabels.howToApply), findsOneWidget);
    });

    testWidgets('a blank goal counts as no goal', (tester) async {
      await pump(
        tester,
        TutorialInstructionsCard(
          instructions: TutorialInstructionSequence.empty,
          goal: '   ',
        ),
      );
      expect(find.text(TutorialLabels.yourGoal), findsNothing);
    });
  });

  group('the catalog obeys the instruction contract', () {
    test('every category has 2 to 4 instructions, contiguously numbered', () {
      for (final category in TutorialCategory.orderedVocabulary) {
        final instructions = TutorialInstructionCatalog.forCategory(category);
        expect(
          instructions.matchesAuthoringGuidance,
          isTrue,
          reason: '${category.code} must sit inside the 2-4 target',
        );
        expect(
          instructions.steps.map((step) => step.sequence),
          List<int>.generate(instructions.length, (index) => index + 1),
        );
      }
    });

    test('no instruction references a guide its category never draws', () {
      // Each category's renderer prompt asks for a specific set of marks.
      // Referencing one outside that set would describe something absent.
      const permitted = <TutorialCategory, Set<TutorialGuideType>>{
        TutorialCategory.foundation: {
          TutorialGuideType.placementBoundary,
          TutorialGuideType.blendZone,
          TutorialGuideType.direction,
        },
        TutorialCategory.concealer: {
          TutorialGuideType.placementBoundary,
          TutorialGuideType.blendZone,
          TutorialGuideType.direction,
        },
        TutorialCategory.contourBronzer: {
          TutorialGuideType.placementBoundary,
          TutorialGuideType.blendZone,
          TutorialGuideType.direction,
        },
        TutorialCategory.blush: {
          TutorialGuideType.startAnchor,
          TutorialGuideType.placementBoundary,
          TutorialGuideType.direction,
        },
        TutorialCategory.highlighter: {
          TutorialGuideType.startAnchor,
          TutorialGuideType.placementBoundary,
        },
        TutorialCategory.eyebrows: {
          TutorialGuideType.startAnchor,
          TutorialGuideType.placementBoundary,
          TutorialGuideType.direction,
        },
        TutorialCategory.eyeshadow: {
          TutorialGuideType.placementBoundary,
          TutorialGuideType.blendZone,
          TutorialGuideType.direction,
        },
        TutorialCategory.eyeliner: {
          TutorialGuideType.startAnchor,
          TutorialGuideType.placementBoundary,
          TutorialGuideType.direction,
        },
        TutorialCategory.lips: {
          TutorialGuideType.startAnchor,
          TutorialGuideType.placementBoundary,
          TutorialGuideType.direction,
        },
      };

      for (final category in TutorialCategory.orderedVocabulary) {
        for (final type in TutorialInstructionCatalog.forCategory(
          category,
        ).referencedGuideTypes) {
          expect(
            permitted[category],
            contains(type),
            reason: '${category.code} instruction references ${type.code}',
          );
        }
      }
    });

    test('every instruction explicitly names the guide it acts on', () {
      const guideWords = <TutorialGuideType, String>{
        TutorialGuideType.startAnchor: 'dot',
        TutorialGuideType.placementBoundary: 'solid guide',
        TutorialGuideType.blendZone: 'dashed guide',
        TutorialGuideType.direction: 'arrow',
      };
      for (final category in TutorialCategory.orderedVocabulary) {
        for (final step in TutorialInstructionCatalog.forCategory(
          category,
        ).steps) {
          final copy = '${step.shortTitle} ${step.instruction}'.toLowerCase();
          expect(
            copy,
            contains(guideWords[step.guideType]),
            reason:
                '${category.code} step ${step.sequence} must name the '
                '${step.guideType.code} guide rather than rely on its glyph',
          );
        }
      }
    });

    test('every category identifies the facial region to inspect', () {
      const regionWords = <TutorialCategory, List<String>>{
        TutorialCategory.foundation: <String>['coverage', 'face'],
        TutorialCategory.concealer: <String>['eye', 'correction zone'],
        TutorialCategory.contourBronzer: <String>['cheekbone', 'jaw', 'nose'],
        TutorialCategory.blush: <String>['cheek', 'footprint'],
        TutorialCategory.highlighter: <String>['high point', 'trace'],
        TutorialCategory.eyebrows: <String>['brow', 'arch', 'tail'],
        TutorialCategory.eyeshadow: <String>['lid', 'crease', 'corner'],
        TutorialCategory.eyeliner: <String>[
          'lash line',
          'outer corner',
          'wing',
        ],
        TutorialCategory.lips: <String>['cupid', 'lower lip', 'lip corners'],
      };

      for (final category in TutorialCategory.orderedVocabulary) {
        final copy = TutorialInstructionCatalog.forCategory(category).steps
            .map((step) => '${step.shortTitle} ${step.instruction}')
            .join(' ')
            .toLowerCase();
        for (final region in regionWords[category]!) {
          expect(copy, contains(region), reason: '${category.code}: $region');
        }
      }
    });

    test('every instruction states a stopping point or transition', () {
      final transition = RegExp(
        r'\b(stop|until|edge|end|boundary|border|fade|only|meet|connect|keep|not|unless|within|before)\b',
      );
      for (final category in TutorialCategory.orderedVocabulary) {
        for (final step in TutorialInstructionCatalog.forCategory(
          category,
        ).steps) {
          expect(
            transition.hasMatch(step.instruction.toLowerCase()),
            isTrue,
            reason: '${category.code} step ${step.sequence}',
          );
        }
      }
    });
  });

  group('the tutorial inherits the global theme', () {
    for (final mode in <ThemeMode>[
      ThemeMode.light,
      ThemeMode.dark,
      ThemeMode.system,
    ]) {
      testWidgets('it renders under $mode without forcing its own', (
        tester,
      ) async {
        await pump(
          tester,
          Column(
            children: [
              const TutorialGuideKey(types: TutorialGuideType.values),
              TutorialInstructionsCard(
                instructions: TutorialInstructionCatalog.forCategory(
                  TutorialCategory.lips,
                ),
                goal: 'A fuller, more defined lip.',
              ),
            ],
          ),
          mode: mode,
        );

        expect(tester.takeException(), isNull);
        expect(find.text(TutorialLabels.guideKey), findsOneWidget);
        expect(find.text(TutorialLabels.yourGoal), findsOneWidget);
      });
    }

    testWidgets(
      'dark mode text is drawn from the dark scheme, not a fixed tint',
      (tester) async {
        await pump(
          tester,
          const TutorialGuideKey(types: TutorialGuideType.values),
          mode: ThemeMode.dark,
        );

        final label = tester.widget<Text>(find.text(TutorialLabels.guideKey));
        // AppColors.muted resolves to the lighter tone in dark mode; the fixed
        // `taupe` it replaced measured 3.4:1 on the dark surface.
        expect(label.style?.color, isNot(equals(AppColors.taupe)));
      },
    );
  });

  group('it survives small screens and large text', () {
    for (final scale in <double>[1.0, 1.5, 2.0]) {
      testWidgets('no overflow at text scale $scale', (tester) async {
        await pump(
          tester,
          Column(
            children: [
              const TutorialGuideKey(types: TutorialGuideType.values),
              TutorialInstructionsCard(
                instructions: TutorialInstructionCatalog.forCategory(
                  TutorialCategory.eyeshadow,
                ),
                goal: 'A soft wash of colour weighted to the outer corner.',
              ),
            ],
          ),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('it fits a 320-wide phone', (tester) async {
      await pump(
        tester,
        const TutorialGuideKey(types: TutorialGuideType.values),
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
