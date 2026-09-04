import 'dart:async';

import 'package:camera/camera.dart';

import '../../domain/entities/live_frame.dart';
import '../../domain/errors/selfie_failure.dart';
import '../../domain/repositories/live_camera_session.dart';

/// The `camera` plugin behind [LiveCameraSession].
///
/// Converts platform image buffers into the narrow [LiveFrame] the validator
/// reads, and nothing else. Frames are handed straight to the stream and never
/// copied, stored, uploaded, or logged; the only bytes that outlive a callback
/// are the ones the plugin itself owns.
class CameraLiveSession implements LiveCameraSession {
  CameraLiveSession({
    Future<List<CameraDescription>> Function() availableCameras =
        _defaultAvailableCameras,
  }) : _availableCameras = availableCameras;

  static Future<List<CameraDescription>> _defaultAvailableCameras() =>
      availableCameras();

  final Future<List<CameraDescription>> Function() _availableCameras;
  final _frames = StreamController<LiveFrame>.broadcast();

  CameraController? _controller;
  bool _streaming = false;
  int _sequence = 0;

  /// The live controller, for the preview surface only.
  ///
  /// Null until [start] succeeds. Presentation reads this to render the plugin's
  /// preview widget; nothing else may touch it.
  CameraController? get previewController => _controller;

  @override
  Stream<LiveFrame> get frames => _frames.stream;

  @override
  Future<void> start() async {
    if (_streaming) return;
    final cameras = await _availableCameras();
    if (cameras.isEmpty) {
      throw const SelfieFailure(
        SelfieFailureType.preparationFailed,
        'No camera is available on this device.',
      );
    }
    // Front camera, matching the selfie intent the OS-picker path already
    // expressed with `preferredCameraDevice: CameraDevice.front`.
    final camera = cameras.firstWhere(
      (candidate) => candidate.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      camera,
      // Medium is deliberate. The preview only has to be judged by eye and the
      // validator only reads coarse luma statistics, so a higher preset would
      // cost memory and per-frame work for no gain in either. The captured
      // still is a separate, full-quality path.
      ResolutionPreset.medium,
      enableAudio: false,
      // The validator reads the luma plane directly. YUV420 exposes it as
      // plane 0 on Android without a conversion step.
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await controller.initialize();

    // Native zoom, read from the controller rather than assumed.
    //
    // 1.0 is not universally the wide end: some devices expose a minimum below
    // it, and starting anywhere other than the minimum silently crops the
    // sensor's field of view — the user frames a shot the camera is not
    // actually taking. Nothing else in this feature ever changes zoom: there is
    // no auto zoom, no face-tracked zoom, and no pinch handler.
    try {
      final minimumZoom = await controller.getMinZoomLevel();
      await controller.setZoomLevel(minimumZoom);
    } catch (_) {
      // A device that will not report or accept a zoom level keeps whatever it
      // opened with. Failing to widen the view must not fail the camera.
    }

    _controller = controller;
    await controller.startImageStream(_onImage);
    _streaming = true;
  }

  void _onImage(CameraImage image) {
    if (_frames.isClosed || image.planes.isEmpty) return;
    final plane = image.planes.first;
    _frames.add(
      LiveFrame(
        luma: plane.bytes,
        width: image.width,
        height: image.height,
        bytesPerRow: plane.bytesPerRow,
        sequence: _sequence++,
      ),
    );
  }

  @override
  Future<String> captureStill() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const SelfieFailure(
        SelfieFailureType.preparationFailed,
        'The camera is not ready yet. Try again in a moment.',
      );
    }
    // The stream is stopped before the shot because the plugin cannot deliver
    // frames and take a picture at once on Android. Stopping first also means
    // the validator is not measuring a frame that no longer matches what the
    // user is looking at.
    if (_streaming) {
      await controller.stopImageStream();
      _streaming = false;
    }
    final file = await controller.takePicture();
    return file.path;
  }

  @override
  Future<void> stop() async {
    final controller = _controller;
    if (controller == null) return;
    if (_streaming) {
      _streaming = false;
      try {
        await controller.stopImageStream();
      } catch (_) {
        // Never fatal, and never logged: a controller that is already torn down
        // throws here, failing to stop a stream must not strand the screen, and
        // nothing on the live path writes diagnostics that could carry frame
        // data into a log.
      }
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
    if (!_frames.isClosed) await _frames.close();
  }
}
