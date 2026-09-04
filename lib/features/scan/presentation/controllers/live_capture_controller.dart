import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../analysis/presentation/controllers/face_analysis_controller.dart';
import '../../domain/entities/prepared_selfie.dart';
import '../../domain/errors/image_validation_failure.dart';
import '../../domain/errors/selfie_failure.dart';
import '../../domain/repositories/image_validation_repository.dart';
import '../../domain/repositories/live_camera_session.dart';
import '../../domain/repositories/selfie_repository.dart';
import 'live_capture_state.dart';

/// Turns one deliberate shutter tap into at most one face analysis.
///
/// The whole sequence lives here rather than in the camera screen, so every
/// "exactly once" rule is provable without pumping a widget:
///
/// ```text
/// user taps  →  one still  →  prepare  →  final local validation
///                                              ├─ pass → analyse once
///                                              └─ fail → analyse never
/// ```
///
/// **No automatic entry point.** [capture] is called from an `onPressed` and
/// nowhere else. Nothing in this class observes readiness, and nothing here
/// starts a timer — a Ready state can sit untouched for as long as the user
/// likes and no photograph will be taken.
///
/// **Paid work never originates from a rebuild.** The only call into face
/// analysis is inside [capture], behind [LiveCaptureState.isBusy] and a
/// generation token, so a rebuild, a theme change, an orientation change, or a
/// new camera frame cannot reach it.
class LiveCaptureController extends StateNotifier<LiveCaptureState> {
  LiveCaptureController({
    required LiveCameraSession session,
    required SelfieRepository selfies,
    required ImageValidationRepository validation,
    required FaceAnalysisController analysis,
  }) : _session = session,
       _selfies = selfies,
       _validation = validation,
       _analysis = analysis,
       super(const LiveCaptureState());

  final LiveCameraSession _session;
  final SelfieRepository _selfies;
  final ImageValidationRepository _validation;
  final FaceAnalysisController _analysis;

  int _generation = 0;
  bool _disposed = false;

  /// Visible for tests.
  int get generation => _generation;

  /// Captures one still, validates it locally, and analyses it if it passes.
  ///
  /// Re-entrant taps are ignored rather than queued: a second photograph is not
  /// what a user means by tapping twice.
  Future<void> capture() async {
    if (_disposed || state.isBusy) return;
    final generation = ++_generation;

    // A previous rejected still is discarded before a new one replaces it, so a
    // retake never leaves an orphaned temporary file behind.
    final previous = state.selfie;
    state = const LiveCaptureState(stage: LiveCaptureStage.capturing);
    if (previous != null) unawaited(_discard(previous));

    String capturedPath;
    try {
      capturedPath = await _session.captureStill();
    } on SelfieFailure catch (failure) {
      _reject(generation, failure.message);
      return;
    } catch (_) {
      _reject(generation, 'The photo could not be taken. Please try again.');
      return;
    }
    if (_stale(generation)) return;

    PreparedSelfie selfie;
    state = state.copyWith(stage: LiveCaptureStage.preparing);
    try {
      selfie = await _selfies.prepareCaptured(capturedPath);
    } on SelfieFailure catch (failure) {
      _reject(generation, failure.message);
      return;
    } catch (_) {
      _reject(
        generation,
        'FaceTune could not prepare that photo. Please retake it.',
      );
      return;
    }
    if (_stale(generation)) {
      unawaited(_discard(selfie));
      return;
    }

    state = state.copyWith(stage: LiveCaptureStage.validating, selfie: selfie);

    // The captured still is the authoritative local gate. Live guidance was
    // only ever advisory, so a frame that looked fine a moment ago can still be
    // rejected here — and when it is, nothing paid happens.
    try {
      final localValidation = await _validation.validateLocal(selfie);
      if (_stale(generation)) return;

      state = state.copyWith(stage: LiveCaptureStage.analyzing);
      await _analysis.analyze(selfie: selfie, localValidation: localValidation);
      if (_stale(generation)) return;
      state = state.copyWith(stage: LiveCaptureStage.complete);
    } on ImageValidationFailure catch (failure) {
      _reject(generation, failure.message, selfie: selfie);
    } catch (_) {
      _reject(
        generation,
        'That photo could not be checked. Please retake it.',
        selfie: selfie,
      );
    }
  }

  /// Returns to the live preview after a rejection.
  Future<void> retake() async {
    if (_disposed) return;
    _generation += 1;
    final selfie = state.selfie;
    state = const LiveCaptureState();
    if (selfie != null) await _discard(selfie);
  }

  void _reject(int generation, String message, {PreparedSelfie? selfie}) {
    if (_stale(generation)) {
      if (selfie != null) unawaited(_discard(selfie));
      return;
    }
    // A rejected still is never uploaded, so its temporary files are dead
    // weight the moment the message is shown.
    if (selfie != null) unawaited(_discard(selfie));
    state = LiveCaptureState(
      stage: LiveCaptureStage.rejected,
      message: message,
    );
  }

  bool _stale(int generation) => _disposed || generation != _generation;

  Future<void> _discard(PreparedSelfie selfie) async {
    try {
      await _selfies.discard(selfie);
    } catch (_) {
      // Temporary-file cleanup must never strand the capture state machine.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    final selfie = state.selfie;
    if (selfie != null) unawaited(_discard(selfie));
    super.dispose();
  }
}
