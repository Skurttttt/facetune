import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TutorialCategory vocabulary', () {
    test('contains exactly the nine supported categories', () {
      expect(TutorialCategory.values, hasLength(9));
      expect(
        TutorialCategory.values.map((category) => category.code).toList(),
        <String>[
          'foundation',
          'concealer',
          'contour_bronzer',
          'blush',
          'highlighter',
          'eyebrows',
          'eyeshadow',
          'eyeliner',
          'lips',
        ],
      );
    });

    test('round-trips through its stable wire code', () {
      for (final category in TutorialCategory.values) {
        expect(TutorialCategory.fromCode(category.code), category);
      }
    });

    test('rejects category names the AI might invent', () {
      for (final invented in <String>[
        'Cheek Sculpting Enhancement',
        'Eye Definition',
        'Radiance Layer',
        'lipstick',
        'lip_gloss',
        'contour',
        'highlight',
        'eyebrow',
        '',
      ]) {
        expect(
          TutorialCategory.fromCode(invented),
          isNull,
          reason: '"$invented" is outside the controlled vocabulary',
        );
      }
    });

    test('assigns a unique deterministic order to every category', () {
      final orders = TutorialCategory.values
          .map((category) => category.order)
          .toList();
      expect(orders.toSet(), hasLength(TutorialCategory.values.length));
      expect(orders, <int>[1, 2, 3, 4, 5, 6, 7, 8, 9]);
    });
  });

  group('deterministic ordering is independent of inclusion', () {
    test('orders the full vocabulary logically', () {
      expect(
        TutorialCategory.orderedVocabulary.map((c) => c.code).toList(),
        <String>[
          'foundation',
          'concealer',
          'contour_bronzer',
          'blush',
          'highlighter',
          'eyebrows',
          'eyeshadow',
          'eyeliner',
          'lips',
        ],
      );
    });

    test('preserves relative order when contour and highlighter drop out', () {
      final included = TutorialCategory.values.toSet()
        ..remove(TutorialCategory.contourBronzer)
        ..remove(TutorialCategory.highlighter);

      expect(
        TutorialCategory.orderedSubset(included).map((c) => c.code).toList(),
        <String>[
          'foundation',
          'concealer',
          'blush',
          'eyebrows',
          'eyeshadow',
          'eyeliner',
          'lips',
        ],
      );
    });

    test('ignores the iteration order of the input', () {
      const scrambled = <TutorialCategory>[
        TutorialCategory.lips,
        TutorialCategory.foundation,
        TutorialCategory.eyeliner,
        TutorialCategory.blush,
      ];
      const reversed = <TutorialCategory>[
        TutorialCategory.blush,
        TutorialCategory.eyeliner,
        TutorialCategory.foundation,
        TutorialCategory.lips,
      ];
      const expected = <TutorialCategory>[
        TutorialCategory.foundation,
        TutorialCategory.blush,
        TutorialCategory.eyeliner,
        TutorialCategory.lips,
      ];

      expect(TutorialCategory.orderedSubset(scrambled), expected);
      expect(TutorialCategory.orderedSubset(reversed), expected);
    });

    test('drops duplicates', () {
      expect(
        TutorialCategory.orderedSubset(const <TutorialCategory>[
          TutorialCategory.lips,
          TutorialCategory.lips,
          TutorialCategory.foundation,
        ]),
        const <TutorialCategory>[
          TutorialCategory.foundation,
          TutorialCategory.lips,
        ],
      );
    });

    test('handles an empty tutorial without error', () {
      expect(
        TutorialCategory.orderedSubset(const <TutorialCategory>[]),
        isEmpty,
      );
    });

    test('returns unmodifiable results', () {
      expect(
        () => TutorialCategory.orderedSubset(const <TutorialCategory>[
          TutorialCategory.lips,
        ]).add(TutorialCategory.blush),
        throwsUnsupportedError,
      );
    });
  });
}
