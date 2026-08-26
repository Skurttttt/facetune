import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every makeup category reuses the exact My Makeup Kit code', () {
    for (final category in TutorialV3Category.guidelineCategories) {
      final kitCategory = category.kitCategory;
      expect(kitCategory, isNotNull, reason: '${category.name} has no kit map');
      expect(category.code, kitCategory!.code);
    }
  });

  test('every Kit category is teachable by the tutorial', () {
    for (final kitCategory in MakeupKitCategory.values) {
      expect(
        TutorialV3Category.fromKitCategory(kitCategory),
        isNotNull,
        reason: '${kitCategory.code} cannot be taught',
      );
    }
  });

  test('final look is the only non-product category', () {
    final withoutKitCategory = TutorialV3Category.values
        .where((category) => category.kitCategory == null)
        .toList();

    expect(withoutKitCategory, [TutorialV3Category.finalLook]);
    expect(TutorialV3Category.finalLook.isFinalLook, isTrue);
  });

  test('guideline categories exclude the final look', () {
    expect(
      TutorialV3Category.guidelineCategories,
      isNot(contains(TutorialV3Category.finalLook)),
    );
    expect(
      TutorialV3Category.guidelineCategories.length,
      TutorialV3Category.values.length - 1,
    );
  });

  test('codes round-trip and are unique', () {
    final codes = TutorialV3Category.values
        .map((category) => category.code)
        .toSet();
    expect(codes.length, TutorialV3Category.values.length);

    for (final category in TutorialV3Category.values) {
      expect(TutorialV3Category.fromCode(category.code), category);
    }
    expect(TutorialV3Category.fromCode('foundation_result'), isNull);
  });
}
