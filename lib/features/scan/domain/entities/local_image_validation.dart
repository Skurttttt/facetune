class LocalImageValidation {
  const LocalImageValidation({
    required this.mimeType,
    required this.width,
    required this.height,
    required this.originalSizeBytes,
    required this.uploadSizeBytes,
  });

  final String mimeType;
  final int width;
  final int height;
  final int originalSizeBytes;
  final int uploadSizeBytes;
}
