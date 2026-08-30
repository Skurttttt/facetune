import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/tutorial/domain/catalog/tutorial_category_mapping.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('inventory category to tutorial category', () {
    test('maps every registered inventory category', () {
      for (final category in MakeupKitCategory.values) {
        expect(
          TutorialCategoryMapping.fromKitCategory(category),
          isA<TutorialCategory>(),
          reason: '${category.code} must have a tutorial home',
        );
      }
    });

    test('maps each inventory category to the expected tutorial step', () {
      const expected = <MakeupKitCategory, TutorialCategory>{
        MakeupKitCategory.foundation: TutorialCategory.foundation,
        MakeupKitCategory.concealer: TutorialCategory.concealer,
        MakeupKitCategory.contourBronzer: TutorialCategory.contourBronzer,
        MakeupKitCategory.blush: TutorialCategory.blush,
        MakeupKitCategory.highlighter: TutorialCategory.highlighter,
        MakeupKitCategory.eyebrow: TutorialCategory.eyebrows,
        MakeupKitCategory.eyeshadow: TutorialCategory.eyeshadow,
        MakeupKitCategory.eyeliner: TutorialCategory.eyeliner,
        MakeupKitCategory.lipstick: TutorialCategory.lips,
        MakeupKitCategory.lipGloss: TutorialCategory.lips,
      };
      expected.forEach((kit, tutorial) {
        expect(TutorialCategoryMapping.fromKitCategory(kit), tutorial);
      });
    });

    test('collapses lipstick and lip gloss into the single Lips step', () {
      expect(
        TutorialCategoryMapping.fromKitCategory(MakeupKitCategory.lipstick),
        TutorialCategory.lips,
      );
      expect(
        TutorialCategoryMapping.fromKitCategory(MakeupKitCategory.lipGloss),
        TutorialCategory.lips,
      );
      expect(
        TutorialCategoryMapping.kitCategoriesFor(TutorialCategory.lips),
        const <MakeupKitCategory>[
          MakeupKitCategory.lipstick,
          MakeupKitCategory.lipGloss,
        ],
      );
    });

    test('every other tutorial category has exactly one inventory source', () {
      for (final category in TutorialCategory.values) {
        if (category == TutorialCategory.lips) continue;
        expect(
          TutorialCategoryMapping.kitCategoriesFor(category),
          hasLength(1),
          reason: '${category.code} should map from one inventory category',
        );
      }
    });

    test(
      'reverse mapping covers the whole inventory vocabulary exactly once',
      () {
        final reversed = <MakeupKitCategory>[
          for (final category in TutorialCategory.values)
            ...TutorialCategoryMapping.kitCategoriesFor(category),
        ];
        expect(reversed.toSet(), MakeupKitCategory.values.toSet());
        expect(reversed, hasLength(MakeupKitCategory.values.length));
      },
    );
  });

  group('standard recommendation key to tutorial category', () {
    test('maps the frozen recommendation schema keys', () {
      const expected = <String, TutorialCategory>{
        'foundation': TutorialCategory.foundation,
        'concealer': TutorialCategory.concealer,
        'contour': TutorialCategory.contourBronzer,
        'highlight': TutorialCategory.highlighter,
        'blush': TutorialCategory.blush,
        'eyeshadow': TutorialCategory.eyeshadow,
        'eyebrow': TutorialCategory.eyebrows,
        'eyeliner': TutorialCategory.eyeliner,
        'lipstick': TutorialCategory.lips,
        'lipGloss': TutorialCategory.lips,
      };
      expected.forEach((key, tutorial) {
        expect(
          TutorialCategoryMapping.fromStandardRecommendationKey(key),
          tutorial,
          reason: 'recommendation key "$key"',
        );
      });
    });

    test('collapses lipstick and lipGloss keys into the Lips step', () {
      expect(
        TutorialCategoryMapping.standardRecommendationKeysFor(
          TutorialCategory.lips,
        ),
        const <String>['lipstick', 'lipGloss'],
      );
    });

    test('rejects keys outside the frozen recommendation vocabulary', () {
      for (final unsupported in <String>[
        'contour_bronzer',
        'highlighter',
        'eyebrows',
        'lips',
        'lip_gloss',
        'Radiance Layer',
        '',
      ]) {
        expect(
          TutorialCategoryMapping.fromStandardRecommendationKey(unsupported),
          isNull,
          reason: '"$unsupported" is not a recommendation plan key',
        );
      }
    });

    test('every tutorial category is reachable from a recommendation key', () {
      for (final category in TutorialCategory.values) {
        expect(
          TutorialCategoryMapping.standardRecommendationKeysFor(category),
          isNotEmpty,
          reason: '${category.code} must be reachable in Standard Mode',
        );
      }
    });
  });
}
