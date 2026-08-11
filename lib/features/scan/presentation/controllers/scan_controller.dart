import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../data/providers/image_validation_repository_provider.dart';
import '../../data/providers/selfie_repository_provider.dart';
import '../../domain/entities/prepared_selfie.dart';
import '../../domain/entities/selfie_source.dart';
import '../../domain/errors/image_validation_failure.dart';
import '../../domain/errors/selfie_failure.dart';
import '../../domain/repositories/image_validation_repository.dart';
import '../../domain/repositories/selfie_repository.dart';
import 'scan_state.dart';

final scanControllerProvider = StateNotifierProvider<ScanController, ScanState>(
  (ref) {
    ref.watch(authControllerProvider.select((state) => state.user?.id));
    return ScanController(
      selfieRepository: ref.watch(selfieRepositoryProvider),
      validationRepository: ref.watch(imageValidationRepositoryProvider),
    );
  },
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
  int _operationGeneration = 0;

  Future<bool> takePhoto() => _acquire(SelfieSource.camera);

  Future<bool> chooseFromGallery() => _acquire(SelfieSource.gallery);

  Future<bool> _acquire(SelfieSource source) async {
    if (state.isBusy) return false;
    final operation = ++_operationGeneration;
    final previousState = state;
    final previous = previousState.selfie;
    state = ScanState(
      stage: ScanStage.acquiring,
      selfie: previous,
      activeSource: source,
      localValidation: previousState.localValidation,
    );
    try {
      final selfie = await _selfieRepository.acquire(source);
      if (!mounted || operation != _operationGeneration) {
        if (selfie != null) await _discardBestEffort(selfie);
        return false;
      }
      if (selfie == null) {
        state = previousState;
        return false;
      }
      state = ScanState(stage: ScanStage.previewReady, selfie: selfie);
      if (previous != null && previous.uploadPath != selfie.uploadPath) {
        unawaited(_discardBestEffort(previous));
      }
      return true;
    } on SelfieFailure catch (failure) {
      if (mounted && operation == _operationGeneration) {
        state = _withError(
          previousState,
          failure.message,
          canOpenSettings: failure.canOpenSettings,
        );
      }
      return false;
    } catch (_) {
      if (mounted && operation == _operationGeneration) {
        state = _withError(
          previousState,
          'FaceTune could not open that image source. Please try again.',
        );
      }
      return false;
    }
  }

  Future<void> validateForAnalysis() async {
    if (state.selfie == null || state.isBusy) return;
    final operation = ++_operationGeneration;
    final selfie = state.selfie!;
    state = ScanState(stage: ScanStage.validatingLocal, selfie: selfie);
    try {
      final result = await _validationRepository.validateLocal(selfie);
      if (!mounted || operation != _operationGeneration) return;
      state = ScanState(
        stage: ScanStage.readyForSecureValidation,
        selfie: selfie,
        localValidation: result,
      );
    } on ImageValidationFailure catch (failure) {
      if (mounted && operation == _operationGeneration) {
        state = ScanState(
          stage: ScanStage.validationFailed,
          selfie: selfie,
          errorMessage: failure.message,
          canReselect: true,
        );
      }
    } catch (_) {
      if (mounted && operation == _operationGeneration) {
        state = ScanState(
          stage: ScanStage.validationFailed,
          selfie: selfie,
          errorMessage:
              'FaceTune could not validate that image. Choose another photo.',
          canReselect: true,
        );
      }
    }
  }

  Future<void> openSettings() async {
    try {
      final opened = await _selfieRepository.openPermissionSettings();
      if (mounted && !opened) {
        state = _withError(
          state,
          'FaceTune could not open Settings. Open app permissions from your device settings.',
          canOpenSettings: true,
        );
      }
    } catch (_) {
      if (mounted) {
        state = _withError(
          state,
          'FaceTune could not open Settings. Open app permissions from your device settings.',
          canOpenSettings: true,
        );
      }
    }
  }

  Future<void> beginNewScan() async {
    _operationGeneration += 1;
    final selfie = state.selfie;
    state = const ScanState();
    if (selfie != null) await _discardBestEffort(selfie);
  }

  ScanState _withError(
    ScanState previous,
    String message, {
    bool canOpenSettings = false,
  }) => ScanState(
    stage: previous.stage,
    selfie: previous.selfie,
    activeSource: previous.activeSource,
    localValidation: previous.localValidation,
    errorMessage: message,
    canOpenSettings: canOpenSettings,
    canRetryValidation: previous.canRetryValidation,
    canReselect: previous.canReselect,
  );

  Future<void> _discardBestEffort(PreparedSelfie selfie) async {
    try {
      await _selfieRepository.discard(selfie);
    } catch (_) {
      // Temporary-file cleanup must never strand the scan state machine.
    }
  }

  @override
  void dispose() {
    _operationGeneration += 1;
    final selfie = state.selfie;
    if (selfie != null) unawaited(_discardBestEffort(selfie));
    super.dispose();
  }
}
