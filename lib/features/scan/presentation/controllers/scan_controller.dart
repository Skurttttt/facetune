import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/image_validation_repository_provider.dart';
import '../../data/providers/selfie_repository_provider.dart';
import '../../domain/entities/selfie_source.dart';
import '../../domain/errors/image_validation_failure.dart';
import '../../domain/errors/selfie_failure.dart';
import '../../domain/repositories/image_validation_repository.dart';
import '../../domain/repositories/selfie_repository.dart';
import 'scan_state.dart';

final scanControllerProvider = StateNotifierProvider<ScanController, ScanState>(
  (ref) => ScanController(
    selfieRepository: ref.watch(selfieRepositoryProvider),
    validationRepository: ref.watch(imageValidationRepositoryProvider),
  ),
);

class ScanController extends StateNotifier<ScanState> {
  ScanController({
    required SelfieRepository selfieRepository,
    required ImageValidationRepository validationRepository,
  }) : _selfieRepository = selfieRepository,
       _validationRepository = validationRepository,
       super(const ScanState());

  final SelfieRepository _selfieRepository;
  final ImageValidationRepository _validationRepository;

  Future<void> takePhoto() => _acquire(SelfieSource.camera);

  Future<void> chooseFromGallery() => _acquire(SelfieSource.gallery);

  Future<void> _acquire(SelfieSource source) async {
    if (state.isBusy) return;
    final previous = state.selfie;
    state = ScanState(
      stage: ScanStage.acquiring,
      selfie: previous,
      activeSource: source,
    );
    try {
      final selfie = await _selfieRepository.acquire(source);
      if (selfie == null) {
        state = ScanState(
          stage: previous == null ? ScanStage.idle : ScanStage.previewReady,
          selfie: previous,
        );
        return;
      }
      if (previous != null) await _selfieRepository.discard(previous);
      state = ScanState(stage: ScanStage.previewReady, selfie: selfie);
    } on SelfieFailure catch (failure) {
      state = ScanState(
        stage: previous == null ? ScanStage.idle : ScanStage.previewReady,
        selfie: previous,
        errorMessage: failure.message,
        canOpenSettings: failure.canOpenSettings,
      );
    }
  }

  Future<void> validateForAnalysis() async {
    if (state.selfie == null || state.isBusy) return;
    final selfie = state.selfie!;
    state = ScanState(stage: ScanStage.validatingLocal, selfie: selfie);
    try {
      final result = await _validationRepository.validateLocal(selfie);
      state = ScanState(
        stage: ScanStage.readyForSecureValidation,
        selfie: selfie,
        localValidation: result,
      );
    } on ImageValidationFailure catch (failure) {
      state = ScanState(
        stage: ScanStage.validationFailed,
        selfie: selfie,
        errorMessage: failure.message,
        canRetryValidation: true,
      );
    }
  }

  Future<void> openSettings() => _selfieRepository.openPermissionSettings();
}
