import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('supports exactly the ten documented categories with unique codes', () {
    expect(MakeupKitCategory.values.map((category) => category.code), [
      'foundation',
      'concealer',
      'blush',
      'highlighter',
      'eyeshadow',
      'lipstick',
      'lip_gloss',
      'contour_bronzer',
      'eyebrow',
      'eyeliner',
    ]);
    expect(
      MakeupKitCategory.values.map((category) => category.code).toSet(),
      hasLength(MakeupKitCategory.values.length),
    );
  });

  test('fromCode round-trips every category code', () {
    for (final category in MakeupKitCategory.values) {
      expect(MakeupKitCategory.fromCode(category.code), category);
    }
  });

  test('fromCode returns null for an unsupported code', () {
    expect(MakeupKitCategory.fromCode('mascara'), isNull);
    expect(MakeupKitCategory.fromCode(''), isNull);
  });
}
