import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../scan/domain/entities/local_image_validation.dart';
import '../../../scan/domain/entities/prepared_selfie.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../data/providers/analysis_providers.dart';
import '../../domain/entities/face_analysis.dart';
import '../../domain/errors/analysis_failure.dart';
import '../../domain/repositories/face_analysis_repository.dart';
import '../../domain/usecases/analyze_face.dart';
import 'face_analysis_state.dart';

final faceAnalysisControllerProvider =
    StateNotifierProvider<FaceAnalysisController, FaceAnalysisState>((ref) {
      ref.watch(authControllerProvider.select((state) => state.user?.id));
      return FaceAnalysisController(ref.watch(analyzeFaceProvider));
    });

class FaceAnalysisController extends StateNotifier<FaceAnalysisState> {
  FaceAnalysisController(this._analyzeFace) : super(const FaceAnalysisState());

  final AnalyzeFace _analyzeFace;
  int _operationGeneration = 0;

  Future<void> analyze({
    required PreparedSelfie selfie,
    required LocalImageValidation localValidation,
  }) async {
    if (state.isBusy) return;
    final operation = ++_operationGeneration;
    state = const FaceAnalysisState(status: FaceAnalysisStatus.uploading);
    try {
      final analysis = await _analyzeFace(
        selfie: selfie,
        localValidation: localValidation,
        onProgress: (progress) {
          if (!mounted || operation != _operationGeneration) return;
          state = FaceAnalysisState(
            status: switch (progress) {
              AnalysisProgress.uploading => FaceAnalysisStatus.uploading,
              AnalysisProgress.secureProcessing =>
                FaceAnalysisStatus.secureProcessing,
            },
          );
        },
      );
      if (mounted && operation == _operationGeneration) {
        state = FaceAnalysisState(
          status: FaceAnalysisStatus.success,
          analysis: analysis,
        );
      }
    } on AnalysisFailure catch (failure) {
      if (mounted && operation == _operationGeneration) {
        state = FaceAnalysisState.failure(failure);
      }
    } catch (_) {
      if (mounted && operation == _operationGeneration) {
        state = FaceAnalysisState.failure(
          const AnalysisFailure(
            AnalysisFailureType.server,
            'The analysis request could not be completed.',
            retryable: true,
          ),
        );
      }
    }
  }

  void clear() {
    _operationGeneration += 1;
    state = const FaceAnalysisState();
  }

  void restore(FaceAnalysis analysis) {
    _operationGeneration += 1;
    state = FaceAnalysisState(
      status: FaceAnalysisStatus.success,
      analysis: analysis,
    );
  }

  @override
  void dispose() {
    _operationGeneration += 1;
    super.dispose();
  }
}
