import '../../domain/entities/generated_preview.dart';

enum MakeupPreviewStatus { idle, generating, success, failure }

class MakeupPreviewState {
  const MakeupPreviewState({
    this.status = MakeupPreviewStatus.idle,
    this.preview,
    this.message,
    this.retryable = false,
    this.technicalCode,
  });

  final MakeupPreviewStatus status;
  final GeneratedPreview? preview;
  final String? message;
  final bool retryable;
  final String? technicalCode;
}
