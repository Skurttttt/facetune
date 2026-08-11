import '../../domain/entities/generated_preview.dart';
import '../../domain/errors/preview_failure.dart';

enum MakeupPreviewStatus { idle, generating, success, failure }

class MakeupPreviewState {
  const MakeupPreviewState({
    this.status = MakeupPreviewStatus.idle,
    this.preview,
    this.previousPreview,
    this.message,
    this.retryable = false,
    this.technicalCode,
    this.failureType,
  });

  final MakeupPreviewStatus status;
  final GeneratedPreview? preview;
  final GeneratedPreview? previousPreview;
  final String? message;
  final bool retryable;
  final String? technicalCode;
  final PreviewFailureType? failureType;
}
