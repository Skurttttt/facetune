enum ImageValidationFailureType {
  missingFile,
  unsupportedType,
  emptyFile,
  fileTooLarge,
  corruptImage,
  dimensionsTooSmall,
  dimensionsTooLarge,
  extremeAspectRatio,
}

class ImageValidationFailure implements Exception {
  const ImageValidationFailure(this.type, this.message);

  final ImageValidationFailureType type;
  final String message;
}
