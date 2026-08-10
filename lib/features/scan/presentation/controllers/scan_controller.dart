import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/selfie_repository_provider.dart';
import '../../domain/entities/selfie_source.dart';
import '../../domain/errors/selfie_failure.dart';
import '../../domain/repositories/selfie_repository.dart';
import 'scan_state.dart';

final scanControllerProvider = StateNotifierProvider<ScanController, ScanState>(
  (ref) => ScanController(ref.watch(selfieRepositoryProvider)),
);

class ScanController extends StateNotifier<ScanState> {
  ScanController(this._repository) : super(const ScanState());

  final SelfieRepository _repository;

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
      final selfie = await _repository.acquire(source);
      if (selfie == null) {
        state = ScanState(
          stage: previous == null ? ScanStage.idle : ScanStage.previewReady,
          selfie: previous,
        );
        return;
      }
      if (previous != null) await _repository.discard(previous);
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

  void proceedToValidation() {
    if (state.selfie == null || state.isBusy) return;
    state = ScanState(
      stage: ScanStage.readyForValidation,
      selfie: state.selfie,
    );
  }

  Future<void> openSettings() => _repository.openPermissionSettings();
}
