import 'package:facetune/features/makeup_kit/domain/entities/foundation_depth.dart';
import 'package:facetune/features/makeup_kit/domain/entities/foundation_undertone.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_product.dart';
import 'package:facetune/features/makeup_kit/domain/errors/makeup_kit_failure.dart';
import 'package:facetune/features/makeup_kit/domain/validation/makeup_kit_product_validator.dart';
import 'package:facetune/features/makeup_kit/domain/value_objects/normalized_hex_color.dart';
import 'package:flutter_test/flutter_test.dart';

MakeupKitProductDraft _draft({
  MakeupKitCategory category = MakeupKitCategory.lipstick,
  String? productName,
  String color = '#B86F72',
  String? colorLabel,
  MakeupKitFinish finish = MakeupKitFinish.matte,
  FoundationDepth? foundationDepth,
  FoundationUndertone? foundationUndertone,
}) => MakeupKitProductDraft(
  category: category,
  productName: productName,
  color: NormalizedHexColor.parse(color),
  colorLabel: colorLabel,
  finish: finish,
  foundationDepth: foundationDepth,
  foundationUndertone: foundationUndertone,
);

void main() {
  test('accepts a valid non-foundation draft', () {
    expect(() => MakeupKitProductValidator.validate(_draft()), returnsNormally);
  });

  test('accepts a valid foundation draft with depth and undertone', () {
    expect(
      () => MakeupKitProductValidator.validate(
        _draft(
          category: MakeupKitCategory.foundation,
          finish: MakeupKitFinish.natural,
          foundationDepth: FoundationDepth.medium,
          foundationUndertone: FoundationUndertone.warm,
        ),
      ),
      returnsNormally,
    );
  });

  test('rejects a finish not valid for the category', () {
    expect(
      () => MakeupKitProductValidator.validate(
        _draft(
          category: MakeupKitCategory.eyebrow,
          finish: MakeupKitFinish.glitter,
        ),
      ),
      throwsA(
        isA<MakeupKitFailure>()
            .having((f) => f.kind, 'kind', MakeupKitFailureKind.validation)
            .having((f) => f.retryable, 'retryable', isFalse),
      ),
    );
  });

  test('rejects foundation depth on a non-foundation category', () {
    expect(
      () => MakeupKitProductValidator.validate(
        _draft(
          category: MakeupKitCategory.lipstick,
          foundationDepth: FoundationDepth.fair,
        ),
      ),
      throwsA(isA<MakeupKitFailure>()),
    );
  });

  test('rejects foundation undertone on a non-foundation category', () {
    expect(
      () => MakeupKitProductValidator.validate(
        _draft(
          category: MakeupKitCategory.blush,
          foundationUndertone: FoundationUndertone.cool,
        ),
      ),
      throwsA(isA<MakeupKitFailure>()),
    );
  });

  test('rejects a blank product name', () {
    expect(
      () => MakeupKitProductValidator.validate(_draft(productName: '   ')),
      throwsA(isA<MakeupKitFailure>()),
    );
  });

  test('rejects a blank color label', () {
    expect(
      () => MakeupKitProductValidator.validate(_draft(colorLabel: '   ')),
      throwsA(isA<MakeupKitFailure>()),
    );
  });

  test('accepts null optional fields', () {
    expect(
      () => MakeupKitProductValidator.validate(
        _draft(productName: null, colorLabel: null),
      ),
      returnsNormally,
    );
  });

  test('combines every violation into one failure message', () {
    try {
      MakeupKitProductValidator.validate(
        _draft(
          category: MakeupKitCategory.eyebrow,
          finish: MakeupKitFinish.glitter,
          productName: ' ',
        ),
      );
      fail('expected a MakeupKitFailure');
    } on MakeupKitFailure catch (failure) {
      expect(failure.message, contains('glitter'));
      expect(failure.message, contains('Product name'));
    }
  });
}
