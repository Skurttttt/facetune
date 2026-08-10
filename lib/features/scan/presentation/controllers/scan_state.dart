import '../../domain/entities/prepared_selfie.dart';
import '../../domain/entities/selfie_source.dart';

enum ScanStage { idle, acquiring, preparing, previewReady, readyForValidation }

class ScanState {
  const ScanState({
    this.stage = ScanStage.idle,
    this.selfie,
    this.activeSource,
    this.errorMessage,
    this.canOpenSettings = false,
  });

  final ScanStage stage;
  final PreparedSelfie? selfie;
  final SelfieSource? activeSource;
  final String? errorMessage;
  final bool canOpenSettings;

  bool get isBusy =>
      stage == ScanStage.acquiring || stage == ScanStage.preparing;
}
