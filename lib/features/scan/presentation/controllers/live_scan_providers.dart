import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../analysis/presentation/controllers/face_analysis_controller.dart';
import '../../data/providers/image_validation_repository_provider.dart';
import '../../data/providers/live_camera_providers.dart';
import '../../data/providers/selfie_repository_provider.dart';
import 'live_capture_controller.dart';
import 'live_capture_state.dart';
import 'live_scan_controller.dart';
import 'live_scan_state.dart';

/// Live validation state for the camera screen.
///
/// `autoDispose` so the frame subscription and the camera are released with the
/// screen. See [LiveScanController] for the concurrency rules it enforces.
final liveScanControllerProvider =
    StateNotifierProvider.autoDispose<LiveScanController, LiveScanState>((ref) {
      return LiveScanController(source: ref.watch(liveCameraSessionProvider));
    });

/// The capture-to-analysis sequence for the camera screen.
///
/// Reads the shared [faceAnalysisControllerProvider] notifier rather than
/// owning its own, so a live-camera analysis lands in exactly the same state
/// the rest of the app already reads — History, the analysis screen, and the
/// recommendation flow are unchanged by where the still came from.
final liveCaptureControllerProvider =
    StateNotifierProvider.autoDispose<LiveCaptureController, LiveCaptureState>((
      ref,
    ) {
      return LiveCaptureController(
        session: ref.watch(liveCameraSessionProvider),
        selfies: ref.watch(selfieRepositoryProvider),
        validation: ref.watch(imageValidationRepositoryProvider),
        analysis: ref.watch(faceAnalysisControllerProvider.notifier),
      );
    });
