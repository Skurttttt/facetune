import 'package:facetune/features/makeup_kit/domain/entities/foundation_depth.dart';
import 'package:facetune/features/makeup_kit/domain/entities/foundation_undertone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('foundation depth exposes the five documented values', () {
    expect(FoundationDepth.values.map((depth) => depth.code), [
      'fair',
      'light',
      'medium',
      'tan',
      'deep',
    ]);
  });

  test('foundation depth fromCode round-trips and rejects unknown codes', () {
    for (final depth in FoundationDepth.values) {
      expect(FoundationDepth.fromCode(depth.code), depth);
    }
    expect(FoundationDepth.fromCode('extra_deep'), isNull);
  });

  test('foundation undertone exposes exactly cool, neutral, and warm', () {
    expect(FoundationUndertone.values.map((undertone) => undertone.code), [
      'cool',
      'neutral',
      'warm',
    ]);
  });

  test(
    'foundation undertone fromCode round-trips and rejects unknown codes',
    () {
      for (final undertone in FoundationUndertone.values) {
        expect(FoundationUndertone.fromCode(undertone.code), undertone);
      }
      expect(FoundationUndertone.fromCode('olive'), isNull);
    },
  );
}
