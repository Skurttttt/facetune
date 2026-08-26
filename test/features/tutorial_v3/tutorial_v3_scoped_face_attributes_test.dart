import 'package:facetune/features/analysis/domain/entities/facial_attributes.dart';
import 'package:facetune/features/tutorial_v3/domain/catalog/tutorial_v3_category_catalog.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_category.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_face_attribute.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_scoped_face_attributes.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_v3_fixtures.dart';

void main() {
  test('scoping never widens beyond the category table', () {
    for (final category in TutorialV3Category.values) {
      final scoped = TutorialV3ScopedFaceAttributes.scope(
        testFacialAttributes,
        category,
      );
      expect(
        scoped.presentAttributes,
        TutorialV3CategoryCatalog.relevantAttributes(category),
        reason: 'scope mismatch for ${category.code}',
      );
    }
  });

  test('a blush step carries face shape and nothing else', () {
    final scoped = TutorialV3ScopedFaceAttributes.scope(
      testFacialAttributes,
      TutorialV3Category.blush,
    );

    expect(scoped.faceShape, FaceShape.round);
    expect(scoped.skinTone, isNull);
    expect(scoped.undertone, isNull);
    expect(scoped.eyeShape, isNull);
    expect(scoped.lipShape, isNull);
  });

  test('a foundation step carries skin tone and undertone only', () {
    final scoped = TutorialV3ScopedFaceAttributes.scope(
      testFacialAttributes,
      TutorialV3Category.foundation,
    );

    expect(scoped.skinTone, SkinTone.medium);
    expect(scoped.undertone, Undertone.warm);
    expect(scoped.faceShape, isNull);
    expect(scoped.eyeShape, isNull);
    expect(scoped.lipShape, isNull);
  });

  test('an eyeshadow step carries eye shape only', () {
    final scoped = TutorialV3ScopedFaceAttributes.scope(
      testFacialAttributes,
      TutorialV3Category.eyeshadow,
    );

    expect(scoped.presentAttributes, {TutorialV3FaceAttribute.eyeShape});
    expect(scoped.eyeShape, EyeShape.almond);
  });

  test('the final look scopes to nothing', () {
    final scoped = TutorialV3ScopedFaceAttributes.scope(
      testFacialAttributes,
      TutorialV3Category.finalLook,
    );

    expect(scoped.isEmpty, isTrue);
    expect(scoped.isNotEmpty, isFalse);
    expect(scoped.presentAttributes, isEmpty);
  });

  test('hair and eye color are never carried into a step', () {
    for (final category in TutorialV3Category.values) {
      final scoped = TutorialV3ScopedFaceAttributes.scope(
        testFacialAttributes,
        category,
      );
      expect(
        scoped.presentAttributes.length,
        lessThanOrEqualTo(TutorialV3FaceAttribute.values.length),
      );
    }
    expect(
      TutorialV3FaceAttribute.values.map((a) => a.code),
      isNot(contains('hair_color')),
    );
    expect(
      TutorialV3FaceAttribute.values.map((a) => a.code),
      isNot(contains('eye_color')),
    );
  });
}
