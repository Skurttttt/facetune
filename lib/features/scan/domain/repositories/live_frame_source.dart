import '../entities/live_frame.dart';

/// A stream of camera frames for local analysis.
///
/// The seam between the validator and the camera plugin. The domain and its
/// tests depend on this interface only, so the concurrency and state rules can
/// be driven by a synthetic source and proven without a device — and so the
/// plugin can be replaced without touching any of it.
///
/// The concrete `camera`-backed implementation is LSEP-4's work, together with
/// the preview surface and the shutter. LSEP-3 deliberately ships the port and
/// nothing behind it.
///
/// **Contract for any implementation.**
///
///  * [frames] is a broadcast-safe stream of transient frames. Emitting is
///    allowed to outpace the consumer; the consumer drops what it cannot use.
///    An implementation must never buffer frames on the consumer's behalf.
///  * A frame's buffer may be reused by the platform after the listener
///    returns, so a consumer must not retain it.
///  * [sequence] on each frame increases monotonically within one session.
///  * No implementation may persist, upload, log, or otherwise copy frame bytes
///    anywhere. Frames are analysed and dropped.
///  * [dispose] releases the camera. It must be safe to call more than once.
abstract interface class LiveFrameSource {
  Stream<LiveFrame> get frames;

  /// Begins delivering frames. Safe to call when already started.
  Future<void> start();

  /// Stops delivery without releasing the camera.
  Future<void> stop();

  /// Stops delivery and releases every underlying resource.
  Future<void> dispose();
}
