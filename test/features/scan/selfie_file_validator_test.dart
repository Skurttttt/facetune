import 'dart:typed_data';

import 'package:facetune/features/scan/domain/errors/selfie_failure.dart';
import 'package:facetune/features/scan/domain/services/selfie_file_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = SelfieFileValidator(maximumBytes: 100);

  test('accepts a JPEG with a supported extension', () {
    final header = Uint8List.fromList([
      0xff,
      0xd8,
      0xff,
      0xe0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
    ]);

    expect(
      () => validator.validate(path: 'selfie.jpg', size: 50, header: header),
      returnsNormally,
    );
  });

  test('rejects an image over the configured size limit', () {
    final header = Uint8List.fromList(List<int>.filled(12, 0));

    expect(
      () => validator.validate(path: 'selfie.jpg', size: 101, header: header),
      throwsA(
        isA<SelfieFailure>().having(
          (failure) => failure.type,
          'type',
          SelfieFailureType.fileTooLarge,
        ),
      ),
    );
  });

  test('rejects content whose signature does not match an image', () {
    final header = Uint8List.fromList(List<int>.filled(12, 0));

    expect(
      () => validator.validate(path: 'selfie.jpg', size: 50, header: header),
      throwsA(
        isA<SelfieFailure>().having(
          (failure) => failure.type,
          'type',
          SelfieFailureType.unsupportedType,
        ),
      ),
    );
  });
}
