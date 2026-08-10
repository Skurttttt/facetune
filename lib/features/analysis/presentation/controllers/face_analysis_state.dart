import '../../domain/entities/face_analysis.dart';
import '../../domain/errors/analysis_failure.dart';

enum FaceAnalysisStatus {
  idle,
  uploading,
  secureProcessing,
  success,
  validationFailure,
  authenticationFailure,
  networkFailure,
  serverFailure,
  geminiFailure,
}

class FaceAnalysisState {
  const FaceAnalysisState({
    this.status = FaceAnalysisStatus.idle,
    this.analysis,
    this.message,
    this.retryable = false,
  });

  final FaceAnalysisStatus status;
  final FaceAnalysis? analysis;
  final String? message;
  final bool retryable;

  bool get isBusy =>
      status == FaceAnalysisStatus.uploading ||
      status == FaceAnalysisStatus.secureProcessing;

  factory FaceAnalysisState.failure(AnalysisFailure failure) {
    final status = switch (failure.type) {
      AnalysisFailureType.authentication =>
        FaceAnalysisStatus.authenticationFailure,
      AnalysisFailureType.validation => FaceAnalysisStatus.validationFailure,
      AnalysisFailureType.timeout ||
      AnalysisFailureType.network => FaceAnalysisStatus.networkFailure,
      AnalysisFailureType.gemini => FaceAnalysisStatus.geminiFailure,
      AnalysisFailureType.server => FaceAnalysisStatus.serverFailure,
    };
    return FaceAnalysisState(
      status: status,
      message: failure.message,
      retryable: failure.retryable,
    );
  }
}
