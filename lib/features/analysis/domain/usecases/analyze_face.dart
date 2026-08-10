import '../../../scan/domain/entities/local_image_validation.dart';
import '../../../scan/domain/entities/prepared_selfie.dart';
import '../entities/face_analysis.dart';
import '../repositories/face_analysis_repository.dart';

class AnalyzeFace {
  const AnalyzeFace(this._repository);

  final FaceAnalysisRepository _repository;

  Future<FaceAnalysis> call({
    required PreparedSelfie selfie,
    required LocalImageValidation localValidation,
    required void Function(AnalysisProgress progress) onProgress,
  }) {
    return _repository.analyze(
      selfie: selfie,
      localValidation: localValidation,
      onProgress: onProgress,
    );
  }
}
