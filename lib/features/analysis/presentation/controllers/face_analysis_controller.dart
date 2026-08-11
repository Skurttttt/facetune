import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../scan/domain/entities/local_image_validation.dart';
import '../../../scan/domain/entities/prepared_selfie.dart';
import '../../data/providers/analysis_providers.dart';
import '../../domain/entities/face_analysis.dart';
import '../../domain/errors/analysis_failure.dart';
import '../../domain/repositories/face_analysis_repository.dart';
import '../../domain/usecases/analyze_face.dart';
import 'face_analysis_state.dart';

final faceAnalysisControllerProvider =
    StateNotifierProvider<FaceAnalysisController, FaceAnalysisState>(
      (ref) => FaceAnalysisController(ref.watch(analyzeFaceProvider)),
    );

class FaceAnalysisController extends StateNotifier<FaceAnalysisState> {
  FaceAnalysisController(this._analyzeFace) : super(const FaceAnalysisState());

  final AnalyzeFace _analyzeFace;

  Future<void> analyze({
    required PreparedSelfie selfie,
    required LocalImageValidation localValidation,
  }) async {
    if (state.isBusy) return;
    state = const FaceAnalysisState(status: FaceAnalysisStatus.uploading);
    try {
      final analysis = await _analyzeFace(
        selfie: selfie,
        localValidation: localValidation,
        onProgress: (progress) {
          if (!mounted) return;
          state = FaceAnalysisState(
            status: switch (progress) {
              AnalysisProgress.uploading => FaceAnalysisStatus.uploading,
              AnalysisProgress.secureProcessing =>
                FaceAnalysisStatus.secureProcessing,
            },
          );
        },
      );
      if (mounted) {
        state = FaceAnalysisState(
          status: FaceAnalysisStatus.success,
          analysis: analysis,
        );
      }
    } on AnalysisFailure catch (failure) {
      if (mounted) state = FaceAnalysisState.failure(failure);
    }
  }

  void clear() => state = const FaceAnalysisState();

  void restore(FaceAnalysis analysis) {
    state = FaceAnalysisState(
      status: FaceAnalysisStatus.success,
      analysis: analysis,
    );
  }
}
