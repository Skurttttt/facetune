import '../../../preview/domain/errors/preview_failure.dart';
import '../../domain/entities/kit_generated_preview.dart';
import '../../domain/entities/kit_makeup_recommendation.dart';

enum MakeupKitLookStatus {
  idle,
  generatingRecommendation,
  generatingPreview,
  success,
  failure,
}

class MakeupKitLookState {
  const MakeupKitLookState({
    this.status = MakeupKitLookStatus.idle,
    this.recommendation,
    this.preview,
    this.previousPreview,
    this.message,
    this.retryable = false,
    this.failureType,
    this.technicalCode,
  });

  final MakeupKitLookStatus status;
  final KitMakeupRecommendation? recommendation;
  final KitGeneratedPreview? preview;
  final KitGeneratedPreview? previousPreview;
  final String? message;
  final bool retryable;
  final PreviewFailureType? failureType;
  final String? technicalCode;

  bool get isGenerating =>
      status == MakeupKitLookStatus.generatingRecommendation ||
      status == MakeupKitLookStatus.generatingPreview;
}
