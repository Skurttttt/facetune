import 'live_frame_source.dart';

/// A live camera that can also take one photograph.
///
/// Capture is deliberately a separate capability from [LiveFrameSource] rather
/// than a richer frame: analysing frames and producing a still are different
/// responsibilities with different privacy rules. Frames are transient and
/// never leave the device; the still is the one image that may enter the secure
/// pipeline, and only because a person pressed a button.
///
/// [captureStill] has no automatic caller anywhere in this feature, and must
/// never acquire one. There is no timer, no countdown, and no readiness
/// threshold that reaches it — the app waits in Ready indefinitely until the
/// user taps the shutter.
abstract interface class LiveCameraSession implements LiveFrameSource {
  /// Captures exactly one still and returns its temporary file path.
  ///
  /// One call, one photograph. Bursts are prohibited: the user chose a moment,
  /// and returning a different frame than the one they chose would break that.
  Future<String> captureStill();
}
