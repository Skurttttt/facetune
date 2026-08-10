import 'package:facetune/features/scan/domain/contracts/secure_image_validation_contract.dart';
import 'package:facetune/features/scan/domain/entities/local_image_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('secure request asks the backend for semantic checks only', () {
    const request = SecureImageValidationRequest(
      storagePath: 'users/user-id/analyses/analysis-id/original.jpg',
      localValidation: LocalImageValidation(
        mimeType: 'image/jpeg',
        width: 1080,
        height: 1440,
        originalSizeBytes: 1000,
        uploadSizeBytes: 700,
      ),
    );

    final json = request.toJson();

    expect(json['schemaVersion'], 1);
    expect(
      json['checks'],
      containsAll([
        'exactlyOneVisibleFace',
        'sufficientLighting',
        'acceptableSharpness',
        'faceVisible',
        'faceFramed',
      ]),
    );
    expect(json, isNot(contains('localPath')));
  });
}
