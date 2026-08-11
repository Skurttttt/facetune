import '../../../preview/domain/entities/generated_preview.dart';

abstract interface class ResultShareService {
  Future<void> share({
    required GeneratedPreview preview,
    required String styleName,
  });
}

class ResultShareFailure implements Exception {
  const ResultShareFailure(this.message);

  final String message;
}
