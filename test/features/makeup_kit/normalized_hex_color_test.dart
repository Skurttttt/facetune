import 'package:facetune/features/makeup_kit/domain/value_objects/normalized_hex_color.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses an already-normalized value unchanged', () {
    expect(NormalizedHexColor.parse('#B86F72').value, '#B86F72');
  });

  test('normalizes lowercase digits to uppercase', () {
    expect(NormalizedHexColor.parse('#b86f72').value, '#B86F72');
  });

  test('adds a missing leading hash', () {
    expect(NormalizedHexColor.parse('C99578').value, '#C99578');
  });

  test('trims surrounding whitespace before validating', () {
    expect(NormalizedHexColor.parse('  #AABBCC  ').value, '#AABBCC');
  });

  test('two colors normalizing to the same value are equal', () {
    expect(
      NormalizedHexColor.parse('#aabbcc'),
      NormalizedHexColor.parse('AABBCC'),
    );
    expect(
      NormalizedHexColor.parse('#aabbcc').hashCode,
      NormalizedHexColor.parse('AABBCC').hashCode,
    );
  });

  test('toString returns the normalized value', () {
    expect(NormalizedHexColor.parse('#aabbcc').toString(), '#AABBCC');
  });

  test('rejects malformed input via parse', () {
    for (final invalid in [
      '',
      '#',
      '#ABC',
      '#GGGGGG',
      '#AABBCCDD',
      'not-a-color',
      '#AABBC',
    ]) {
      expect(
        () => NormalizedHexColor.parse(invalid),
        throwsFormatException,
        reason: 'expected "$invalid" to be rejected',
      );
    }
  });

  test('tryParse returns null for malformed input', () {
    expect(NormalizedHexColor.tryParse('#ZZZZZZ'), isNull);
    expect(NormalizedHexColor.tryParse('#AABBCC'), isNotNull);
  });

  test('isValid reports validity without throwing', () {
    expect(NormalizedHexColor.isValid('#B86F72'), isTrue);
    expect(NormalizedHexColor.isValid('b86f72'), isTrue);
    expect(NormalizedHexColor.isValid('#12345'), isFalse);
    expect(NormalizedHexColor.isValid('123456789'), isFalse);
  });
}
