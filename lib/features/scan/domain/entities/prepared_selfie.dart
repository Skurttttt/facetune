import 'selfie_source.dart';

class PreparedSelfie {
  const PreparedSelfie({
    required this.originalPath,
    required this.uploadPath,
    required this.originalSizeBytes,
    required this.uploadSizeBytes,
    required this.source,
  });

  final String originalPath;
  final String uploadPath;
  final int originalSizeBytes;
  final int uploadSizeBytes;
  final SelfieSource source;
}
