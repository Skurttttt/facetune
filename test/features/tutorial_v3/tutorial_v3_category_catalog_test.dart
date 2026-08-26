import 'package:facetune/features/tutorial_v3/domain/catalog/tutorial_v3_category_catalog.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_category.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_face_attribute.dart';
import 'package:flutter_test/flutter_test.dart';

int _rank(TutorialV3Category category) =>
    TutorialV3CategoryCatalog.orderRank(category);

void main() {
  test('the canonical order covers every category exactly once', () {
    expect(
      TutorialV3CategoryCatalog.canonicalOrder.toSet().length,
      TutorialV3CategoryCatalog.canonicalOrder.length,
    );
    expect(
      TutorialV3CategoryCatalog.canonicalOrder.toSet(),
      TutorialV3Category.values.toSet(),
    );
  });

  test('the final look ranks last', () {
    final finalRank = _rank(TutorialV3Category.finalLook);
    for (final category in TutorialV3Category.guidelineCategories) {
      expect(_rank(category), lessThan(finalRank));
    }
  });

  test('foundation ranks before every other application step', () {
    final foundationRank = _rank(TutorialV3Category.foundation);
    for (final category in TutorialV3Category.values) {
      if (category == TutorialV3Category.foundation) continue;
      expect(foundationRank, lessThan(_rank(category)));
    }
  });

  test('lip gloss ranks after lip color', () {
    expect(
      _rank(TutorialV3Category.lipstick),
      lessThan(_rank(TutorialV3Category.lipGloss)),
    );
  });

  test('every category has a declared attribute scope', () {
    for (final category in TutorialV3Category.values) {
      expect(
        TutorialV3CategoryCatalog.relevantAttributes(category),
        isNotNull,
        reason: '${category.code} has no declared scope',
      );
    }
  });

  test('the final look reasons about no facial attributes', () {
    expect(
      TutorialV3CategoryCatalog.relevantAttributes(
        TutorialV3Category.finalLook,
      ),
      isEmpty,
    );
  });

  test('every application category is personalized by something', () {
    for (final category in TutorialV3Category.guidelineCategories) {
      expect(
        TutorialV3CategoryCatalog.relevantAttributes(category),
        isNotEmpty,
        reason: '${category.code} has no personalizing attribute',
      );
    }
  });

  test('attribute relevance follows the category table', () {
    expect(
      TutorialV3CategoryCatalog.relevantAttributes(
        TutorialV3Category.foundation,
      ),
      {TutorialV3FaceAttribute.skinTone, TutorialV3FaceAttribute.undertone},
    );
    expect(
      TutorialV3CategoryCatalog.relevantAttributes(TutorialV3Category.blush),
      {TutorialV3FaceAttribute.faceShape},
    );
    expect(
      TutorialV3CategoryCatalog.relevantAttributes(
        TutorialV3Category.eyeshadow,
      ),
      {TutorialV3FaceAttribute.eyeShape},
    );
    expect(
      TutorialV3CategoryCatalog.relevantAttributes(TutorialV3Category.lipstick),
      {TutorialV3FaceAttribute.lipShape},
    );
  });

  test('eye categories do not reason about lip shape and vice versa', () {
    expect(
      TutorialV3CategoryCatalog.isRelevant(
        TutorialV3Category.eyeliner,
        TutorialV3FaceAttribute.lipShape,
      ),
      isFalse,
    );
    expect(
      TutorialV3CategoryCatalog.isRelevant(
        TutorialV3Category.lipGloss,
        TutorialV3FaceAttribute.eyeShape,
      ),
      isFalse,
    );
  });
}
