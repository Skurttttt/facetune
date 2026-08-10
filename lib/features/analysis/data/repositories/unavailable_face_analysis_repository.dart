import '../../../scan/domain/entities/local_image_validation.dart';
import '../../../scan/domain/entities/prepared_selfie.dart';
import '../../domain/entities/face_analysis.dart';
import '../../domain/errors/analysis_failure.dart';
import '../../domain/repositories/face_analysis_repository.dart';

class UnavailableFaceAnalysisRepository implements FaceAnalysisRepository {
  const UnavailableFaceAnalysisRepository();

  @override
  Future<FaceAnalysis> analyze({
    required PreparedSelfie selfie,
    required LocalImageValidation localValidation,
    required void Function(AnalysisProgress progress) onProgress,
  }) {
    return Future.error(
      const AnalysisFailure(
        AnalysisFailureType.authentication,
        'Secure analysis is unavailable in this build.',
      ),
    );
  }
}
