import '../../../scan/domain/entities/local_image_validation.dart';
import '../../../scan/domain/entities/prepared_selfie.dart';
import '../entities/face_analysis.dart';

enum AnalysisProgress { uploading, secureProcessing }

abstract interface class FaceAnalysisRepository {
  Future<FaceAnalysis> analyze({
    required PreparedSelfie selfie,
    required LocalImageValidation localValidation,
    required void Function(AnalysisProgress progress) onProgress,
  });
}
