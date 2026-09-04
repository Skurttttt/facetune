import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/results/presentation/widgets/makeup_breakdown.dart';
import 'package:facetune/features/tutorial/domain/catalog/realized_look_filter.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/tutorial/presentation/utils/tutorial_labels.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MakeupRecommendationItem _item(String name) => MakeupRecommendationItem(
  name: name,
  hex: '#B86F72',
  placement: '$name placement',
  technique: '$name technique',
  finish: 'Satin',
  intensity: 'Medium',
  reasoning: 'Why $name works',
);

RealizedCategoryGroup<RealizedStandardEntry> _group(
  TutorialCategory category,
  List<(String planKey, String name)> entries,
) => RealizedCategoryGroup(
  category: category,
  entries: [
    for (final (planKey, name) in entries)
      RealizedStandardEntry(
        category: category,
        planKey: planKey,
        item: _item(name),
      ),
  ],
);

/// A look whose Lips category is fed by two plan keys — the exact shape the
/// category invariant is about.
List<RealizedCategoryGroup<RealizedStandardEntry>> _everydayLook() => [
  _group(TutorialCategory.foundation, [('foundation', 'Soft Beige')]),
  _group(TutorialCategory.blush, [('blush', 'Warm Rose')]),
  _group(TutorialCategory.eyeshadow, [('eyeshadow', 'Champagne')]),
  _group(TutorialCategory.lips, [
    ('lipstick', 'Rosewood'),
    ('lipGloss', 'Clear Shine'),
  ]),
];

Widget _host(Widget child, {ThemeData? theme, double textScale = 1}) =>
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  group('category authority', () {
    testWidgets('renders exactly the categories it is handed', (tester) async {
      // The breakdown is a pure renderer. It must not add, drop, split, or
      // rename a category — the manifest decided the set upstream.
      final groups = _everydayLook();
      await tester.pumpWidget(_host(MakeupBreakdown(groups: groups)));

      for (final group in groups) {
        expect(
          find.text(TutorialLabels.categoryName(group.category)),
          findsOneWidget,
          reason: '${group.category.code} heading',
        );
      }

      // And nothing beyond them. A category the look does not contain must not
      // appear just because the recommendation once mentioned it.
      for (final absent in [
        TutorialCategory.contourBronzer,
        TutorialCategory.highlighter,
        TutorialCategory.concealer,
        TutorialCategory.eyeliner,
        TutorialCategory.eyebrows,
      ]) {
        expect(
          find.text(TutorialLabels.categoryName(absent)),
          findsNothing,
          reason: '${absent.code} is not in this look',
        );
      }
    });

    testWidgets('lipstick and lip gloss stay inside one Lips category', (
      tester,
    ) async {
      // BREAKDOWN CATEGORY IDS = TUTORIAL CATEGORY IDS. Two products feed the
      // Lips step, so this look is four categories — not five.
      await tester.pumpWidget(_host(MakeupBreakdown(groups: _everydayLook())));

      expect(
        find.text(TutorialLabels.categoryName(TutorialCategory.lips)),
        findsOneWidget,
        reason: 'the Lips category heading appears once, not once per product',
      );

      // Both products are present, each still labelled by its own plan key.
      expect(find.text('Lipstick'), findsOneWidget);
      expect(find.text('Lip Gloss'), findsOneWidget);

      // Neither product name is promoted to a category name.
      final categoryNames = TutorialCategory.values
          .map(TutorialLabels.categoryName)
          .toSet();
      expect(categoryNames.contains('Lipstick'), isFalse);
      expect(categoryNames.contains('Lip Gloss'), isFalse);
    });

    testWidgets('a multi-product category is one bounded card', (tester) async {
      // The visual half of the invariant. Before UI-P4 the Lips group rendered
      // as a loose heading followed by two separate cards, which on screen was
      // indistinguishable from two categories.
      await tester.pumpWidget(_host(MakeupBreakdown(groups: _everydayLook())));

      final lipsCard = find.ancestor(
        of: find.text(TutorialLabels.categoryName(TutorialCategory.lips)),
        matching: find.byType(Card),
      );
      expect(lipsCard, findsOneWidget);

      // Both product tiles live inside that one card.
      for (final product in ['Lipstick', 'Lip Gloss']) {
        expect(
          find.descendant(of: lipsCard, matching: find.text(product)),
          findsOneWidget,
          reason: '$product must sit inside the Lips card',
        );
      }
      // And the card states how many products it contains, so the section
      // cannot be read as a list of categories.
      expect(find.text('2 products'), findsOneWidget);
    });

    testWidgets('a single-product category shows no product sub-label', (
      tester,
    ) async {
      // "Contour & Bronzer" is titled with the canonical name; adding a
      // "Contour" sub-heading beneath it would invent a second level.
      await tester.pumpWidget(
        _host(
          MakeupBreakdown(
            groups: [
              _group(TutorialCategory.contourBronzer, [('contour', 'Taupe')]),
            ],
          ),
        ),
      );
      expect(
        find.text(TutorialLabels.categoryName(TutorialCategory.contourBronzer)),
        findsOneWidget,
      );
      expect(find.text('2 products'), findsNothing);
    });

    testWidgets('categories render in the order supplied', (tester) async {
      // Order is the domain's, never re-sorted here.
      final groups = _everydayLook();
      await tester.pumpWidget(_host(MakeupBreakdown(groups: groups)));

      final positions = [
        for (final group in groups)
          tester
              .getTopLeft(
                find.text(TutorialLabels.categoryName(group.category)),
              )
              .dy,
      ];
      for (var i = 1; i < positions.length; i++) {
        expect(
          positions[i],
          greaterThan(positions[i - 1]),
          reason: '${groups[i].category.code} moved out of order',
        );
      }
    });

    for (final categoryCount in <int>[6, 8, 9]) {
      testWidgets('renders a dynamic $categoryCount-category result', (
        tester,
      ) async {
        final groups = <RealizedCategoryGroup<RealizedStandardEntry>>[
          for (final category in TutorialCategory.values.take(categoryCount))
            _group(category, [
              ('item-${category.code}', 'Shade for ${category.code}'),
            ]),
        ];

        await tester.pumpWidget(_host(MakeupBreakdown(groups: groups)));

        expect(find.byType(ExpansionTile), findsNWidgets(categoryCount));
        for (final group in groups) {
          expect(
            find.text(TutorialLabels.categoryName(group.category)),
            findsOneWidget,
          );
        }
      });
    }

    testWidgets('an empty look renders nothing rather than a placeholder', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const MakeupBreakdown(groups: [])));
      expect(find.byType(Card), findsNothing);
    });
  });

  group('recommendation metadata is reproduced verbatim', () {
    testWidgets('shade, intensity and finish are shown as supplied', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          MakeupBreakdown(
            groups: [
              _group(TutorialCategory.blush, [('blush', 'Warm Rose')]),
            ],
          ),
        ),
      );
      expect(find.text('Warm Rose · Medium · Satin'), findsOneWidget);
    });

    testWidgets('placement, technique and reasoning survive expansion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          MakeupBreakdown(
            groups: [
              _group(TutorialCategory.blush, [('blush', 'Warm Rose')]),
            ],
          ),
        ),
      );

      // Located through the `Semantics` widget rather than
      // `find.bySemanticsLabel`, which matches a node's final *merged* label
      // and so misses a container whose label is combined with its children's.
      // Read through `flagsCollection` rather than the deprecated `hasFlag`.
      // Both were silent behaviour changes in the Flutter SDK: the assertions
      // below are the same ones, expressed in the API that still works.
      final expansion = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Blush makeup details',
      );
      expect(expansion, findsOneWidget);
      expect(
        tester
            .getSemantics(expansion)
            .flagsCollection
            .isExpanded
            .toBoolOrNull(),
        isFalse,
      );

      await tester.tap(
        find.text(TutorialLabels.categoryName(TutorialCategory.blush)),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .getSemantics(expansion)
            .flagsCollection
            .isExpanded
            .toBoolOrNull(),
        isTrue,
      );
      expect(find.textContaining('Warm Rose placement'), findsOneWidget);
      expect(find.textContaining('Warm Rose technique'), findsOneWidget);
      expect(find.textContaining('Why Warm Rose works'), findsOneWidget);
    });

    testWidgets('an absent shade draws no invented colour', (tester) async {
      const noShade = MakeupRecommendationItem(
        name: 'Unnamed',
        placement: 'p',
        technique: 't',
        finish: 'Matte',
        intensity: 'Light',
        reasoning: 'r',
      );
      await tester.pumpWidget(
        _host(
          MakeupBreakdown(
            groups: [
              RealizedCategoryGroup(
                category: TutorialCategory.blush,
                entries: const [
                  RealizedStandardEntry(
                    category: TutorialCategory.blush,
                    planKey: 'blush',
                    item: noShade,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Unnamed · Light · Matte'), findsOneWidget);
    });
  });

  group('presentation holds up', () {
    testWidgets('renders in light and dark without overflow', (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(
          _host(MakeupBreakdown(groups: _everydayLook()), theme: theme),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('survives large text on a narrow screen', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(MakeupBreakdown(groups: _everydayLook()), textScale: 2),
      );
      expect(tester.takeException(), isNull);
      // The category set is unchanged by text size.
      expect(
        find.text(TutorialLabels.categoryName(TutorialCategory.lips)),
        findsOneWidget,
      );
    });
  });
}
