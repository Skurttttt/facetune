import '../entities/local_image_validation.dart';

enum SecureImageCheck {
  exactlyOneVisibleFace,
  sufficientLighting,
  acceptableSharpness,
  faceVisible,
  faceFramed,
}

enum SecureValidationDecision { accepted, rejected, reviewRequired }

enum SecureValidationIssue {
  noFace,
  multipleFaces,
  insufficientLighting,
  excessiveBlur,
  faceObscured,
  poorFraming,
}

class SecureImageValidationRequest {
  const SecureImageValidationRequest({
    required this.storagePath,
    required this.localValidation,
  });

  static const schemaVersion = 1;
  static const requestedChecks = SecureImageCheck.values;

  final String storagePath;
  final LocalImageValidation localValidation;

  Map<String, Object> toJson() => {
    'schemaVersion': schemaVersion,
    'storagePath': storagePath,
    'mimeType': localValidation.mimeType,
    'byteSize': localValidation.uploadSizeBytes,
    'width': localValidation.width,
    'height': localValidation.height,
    'checks': requestedChecks.map((check) => check.name).toList(),
  };
}

class SecureImageValidationResponse {
  const SecureImageValidationResponse({
    required this.decision,
    required this.issues,
  });

  final SecureValidationDecision decision;
  final List<SecureValidationIssue> issues;
}
