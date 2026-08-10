import 'dart:io';

import 'package:facetune/features/scan/data/repositories/flutter_image_validation_repository.dart';
import 'package:facetune/features/scan/domain/entities/prepared_selfie.dart';
import 'package:facetune/features/scan/domain/entities/selfie_source.dart';
import 'package:facetune/features/scan/domain/errors/image_validation_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rejects a JPEG signature whose image data cannot be decoded', () async {
    final directory = await Directory.systemTemp.createTemp(
      'facetune_validation_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final corruptBytes = <int>[
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
      0,
      0,
      0,
      0,
    ];
    final original = File('${directory.path}/original.jpg');
    final upload = File('${directory.path}/upload.jpg');
    await original.writeAsBytes(corruptBytes);
    await upload.writeAsBytes(corruptBytes);
    final selfie = PreparedSelfie(
      originalPath: original.path,
      uploadPath: upload.path,
      originalSizeBytes: corruptBytes.length,
      uploadSizeBytes: corruptBytes.length,
      source: SelfieSource.gallery,
    );

    expect(
      () => const FlutterImageValidationRepository().validateLocal(selfie),
      throwsA(
        isA<ImageValidationFailure>().having(
          (failure) => failure.type,
          'type',
          ImageValidationFailureType.corruptImage,
        ),
      ),
    );
  });

  test('rejects a missing local original', () async {
    const selfie = PreparedSelfie(
      originalPath: 'missing-original.jpg',
      uploadPath: 'missing-upload.jpg',
      originalSizeBytes: 1,
      uploadSizeBytes: 1,
      source: SelfieSource.gallery,
    );

    expect(
      () => const FlutterImageValidationRepository().validateLocal(selfie),
      throwsA(
        isA<ImageValidationFailure>().having(
          (failure) => failure.type,
          'type',
          ImageValidationFailureType.missingFile,
        ),
      ),
    );
  });
}
