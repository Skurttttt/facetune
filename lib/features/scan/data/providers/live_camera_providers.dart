import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:camera/camera.dart' show CameraPreview;

import '../../domain/repositories/live_camera_session.dart';
import '../repositories/camera_live_session.dart';

/// The live camera session for the current screen.
///
/// `autoDispose` on purpose: the camera must be released the moment the screen
/// is gone, not whenever the app next rebuilds a provider graph. Holding a
/// camera open behind a closed screen is both a battery cost and a privacy
/// smell — the indicator light stays on.
final liveCameraSessionProvider = Provider.autoDispose<LiveCameraSession>((
  ref,
) {
  final session = CameraLiveSession();
  ref.onDispose(session.dispose);
  return session;
});

/// How the viewport renders and sizes the live preview.
///
/// **Everything here is resolved at build time, never captured.** The previous
/// version captured controller-derived readiness when the provider was first
/// read — during the page's first build, before the camera had opened. The
/// value stayed null for the life of the screen, so the viewport rendered
/// nothing while validation ran perfectly behind it.
///
/// Geometry belongs to `CameraPreview` itself. The plugin derives an
/// orientation-aware display ratio from the current `CameraValue`; wrapping it
/// in the controller's raw sensor ratio would force portrait previews into a
/// landscape box. The page only centres the geometry-owning widget, providing
/// honest letterboxing without cropping or scaling the field of view.
///
/// [listenable] is the mechanism that keeps preview visibility independent of
/// validation state: `CameraController` is a `ValueNotifier<CameraValue>`, so
/// the viewport rebuilds exactly when the camera's own state changes —
/// initialised, paused, errored — and never because a check went from amber to
/// green.
class LivePreview {
  const LivePreview({required this.build, this.listenableOf = _noListenable});

  static Listenable? _noListenable() => null;

  /// Builds the geometry-owning preview, or an empty box when it is not ready.
  final WidgetBuilder build;

  /// The camera's own state, so the viewport can rebuild when it changes.
  ///
  /// A getter because the controller does not exist when this object is created;
  /// capturing it then would capture null.
  final Listenable? Function() listenableOf;
}

/// Renders the plugin's preview surface.
///
/// Indirected through a provider so the camera screen can be widget-tested
/// without a device: a test overrides this with a placeholder, while production
/// reads the live controller. It also keeps `CameraPreview` — and the plugin
/// type it needs — out of the page itself.
final livePreviewProvider = Provider.autoDispose<LivePreview>((ref) {
  final session = ref.watch(liveCameraSessionProvider);
  if (session is! CameraLiveSession) {
    return LivePreview(build: (context) => const SizedBox.shrink());
  }
  return LivePreview(
    listenableOf: () => session.previewController,
    build: (context) {
      final controller = session.previewController;
      if (controller == null || !controller.value.isInitialized) {
        return const SizedBox.shrink();
      }
      return CameraPreview(controller);
    },
  );
});
