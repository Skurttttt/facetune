import 'package:facetune/features/makeup_kit/domain/catalog/makeup_kit_finish_catalog.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finish enum exposes unique stable codes', () {
    expect(
      MakeupKitFinish.values.map((finish) => finish.code).toSet(),
      hasLength(MakeupKitFinish.values.length),
    );
  });

  test('finish fromCode round-trips every finish code', () {
    for (final finish in MakeupKitFinish.values) {
      expect(MakeupKitFinish.fromCode(finish.code), finish);
    }
  });

  test('finish fromCode returns null for an unsupported code', () {
    expect(MakeupKitFinish.fromCode('holographic'), isNull);
  });

  test('allowed finishes match the documented catalog per category', () {
    const expected = {
      MakeupKitCategory.foundation: {
        MakeupKitFinish.matte,
        MakeupKitFinish.natural,
        MakeupKitFinish.dewy,
        MakeupKitFinish.satin,
      },
      MakeupKitCategory.concealer: {
        MakeupKitFinish.matte,
        MakeupKitFinish.natural,
        MakeupKitFinish.radiant,
      },
      MakeupKitCategory.blush: {
        MakeupKitFinish.matte,
        MakeupKitFinish.satin,
        MakeupKitFinish.shimmer,
      },
      MakeupKitCategory.highlighter: {
        MakeupKitFinish.natural,
        MakeupKitFinish.shimmer,
        MakeupKitFinish.metallic,
      },
      MakeupKitCategory.eyeshadow: {
        MakeupKitFinish.matte,
        MakeupKitFinish.satin,
        MakeupKitFinish.shimmer,
        MakeupKitFinish.metallic,
        MakeupKitFinish.glitter,
      },
      MakeupKitCategory.lipstick: {
        MakeupKitFinish.matte,
        MakeupKitFinish.satin,
        MakeupKitFinish.cream,
        MakeupKitFinish.glossy,
      },
      MakeupKitCategory.lipGloss: {
        MakeupKitFinish.glossy,
        MakeupKitFinish.shimmer,
      },
      MakeupKitCategory.contourBronzer: {
        MakeupKitFinish.matte,
        MakeupKitFinish.satin,
      },
      MakeupKitCategory.eyebrow: {
        MakeupKitFinish.matte,
        MakeupKitFinish.natural,
      },
      MakeupKitCategory.eyeliner: {
        MakeupKitFinish.matte,
        MakeupKitFinish.satin,
        MakeupKitFinish.glossy,
      },
    };

    for (final category in MakeupKitCategory.values) {
      expect(
        MakeupKitFinishCatalog.allowedFinishes(category),
        expected[category],
        reason: 'unexpected allowed finishes for $category',
      );
    }
  });

  test('isValidCombination accepts every documented pairing', () {
    for (final category in MakeupKitCategory.values) {
      for (final finish in MakeupKitFinishCatalog.allowedFinishes(category)) {
        expect(
          MakeupKitFinishCatalog.isValidCombination(category, finish),
          isTrue,
        );
      }
    }
  });

  test('isValidCombination rejects finishes outside a category catalog', () {
    expect(
      MakeupKitFinishCatalog.isValidCombination(
        MakeupKitCategory.lipstick,
        MakeupKitFinish.metallic,
      ),
      isFalse,
    );
    expect(
      MakeupKitFinishCatalog.isValidCombination(
        MakeupKitCategory.eyebrow,
        MakeupKitFinish.glitter,
      ),
      isFalse,
    );
    expect(
      MakeupKitFinishCatalog.isValidCombination(
        MakeupKitCategory.foundation,
        MakeupKitFinish.glossy,
      ),
      isFalse,
    );
  });

  test('every finish value is reachable from at least one category', () {
    final reachable = <MakeupKitFinish>{};
    for (final category in MakeupKitCategory.values) {
      reachable.addAll(MakeupKitFinishCatalog.allowedFinishes(category));
    }
    expect(reachable, MakeupKitFinish.values.toSet());
  });
}
