import '../../domain/entities/local_image_validation.dart';
import '../../domain/entities/prepared_selfie.dart';
import '../../domain/entities/selfie_source.dart';

enum ScanStage {
  idle,
  acquiring,
  previewReady,
  validatingLocal,
  validationFailed,
  readyForSecureValidation,
}

class ScanState {
  const ScanState({
    this.stage = ScanStage.idle,
    this.selfie,
    this.activeSource,
    this.localValidation,
    this.errorMessage,
    this.canOpenSettings = false,
    this.canRetryValidation = false,
  });

  final ScanStage stage;
  final PreparedSelfie? selfie;
  final SelfieSource? activeSource;
  final LocalImageValidation? localValidation;
  final String? errorMessage;
  final bool canOpenSettings;
  final bool canRetryValidation;

  bool get isBusy =>
      stage == ScanStage.acquiring || stage == ScanStage.validatingLocal;
}
