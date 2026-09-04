import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../../../analysis/presentation/controllers/face_analysis_controller.dart';
import '../../../analysis/presentation/controllers/face_analysis_state.dart';
import '../../data/providers/live_camera_providers.dart';
import '../controllers/live_capture_state.dart';
import '../controllers/live_scan_providers.dart';
import '../controllers/live_scan_state.dart';
import '../utils/live_guidance.dart';
import '../widgets/live_check_details.dart';
import '../widgets/live_face_guide.dart';

/// The live scan screen: preview, one line of guidance, and a manual shutter.
///
/// **A single-purpose camera route.** It does one thing, so it is laid out like
/// a camera and not like a document: a fixed shell where the preview takes the
/// space that is left, the status is compact, and the shutter is pinned. There
/// is no gallery action here — that choice belongs to the screen the user came
/// from, and offering it again mid-camera invites them to abandon the thing they
/// just opened.
///
/// **The shutter is the only way a photograph is taken.** Reaching Ready
/// changes what this screen says and nothing else. It starts no timer. The app
/// waits here for as long as the user wants to fix their hair.
class LiveCameraPage extends ConsumerStatefulWidget {
  const LiveCameraPage({super.key});

  @override
  ConsumerState<LiveCameraPage> createState() => _LiveCameraPageState();
}

class _LiveCameraPageState extends ConsumerState<LiveCameraPage> {
  @override
  void initState() {
    super.initState();
    // Starting the *preview* is a lifecycle concern and costs nothing. It is
    // not paid work, and it is deliberately here rather than in `build` so a
    // rebuild cannot restart the session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(liveScanControllerProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(liveScanControllerProvider);
    final capture = ref.watch(liveCaptureControllerProvider);

    ref.listen<FaceAnalysisState>(faceAnalysisControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.status != FaceAnalysisStatus.success &&
          next.status == FaceAnalysisStatus.success &&
          context.mounted) {
        context.pushReplacement(AppConstants.analysisRoute);
      }
    });

    return Scaffold(
      appBar: const FaceTuneTopBar(title: 'New scan'),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The fixed shell needs a viewport, a status block and a shutter to
            // coexist. Below this the content genuinely cannot fit — at very
            // large text scales, or on an unusually short usable height — and a
            // scroll is the accessible answer rather than clipped copy or an
            // unreachable button.
            final scaled = MediaQuery.textScalerOf(context).scale(14);
            final needsScrollFallback =
                constraints.maxHeight < 520 || scaled > 22;
            return needsScrollFallback
                ? _ScrollFallbackShell(capture: capture, live: live)
                : _FixedShell(capture: capture, live: live);
          },
        ),
      ),
    );
  }
}

/// The normal path: nothing scrolls, and the preview gets the leftover space.
class _FixedShell extends StatelessWidget {
  const _FixedShell({required this.capture, required this.live});

  final LiveCaptureState capture;
  final LiveScanState live;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.gutter,
      AppSpacing.sm,
      AppSpacing.gutter,
      AppSpacing.md,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Expanded, not a fixed height or an aspect-ratio box: the camera is
        // the content of this screen, so it takes whatever the status and the
        // shutter do not need.
        Expanded(
          child: _Viewport(capture: capture, live: live),
        ),
        const SizedBox(height: AppSpacing.md),
        _Status(capture: capture, live: live),
        const SizedBox(height: AppSpacing.md),
        _CaptureAction(capture: capture, live: live),
      ],
    ),
  );
}

/// The accessibility fallback: the same content, scrollable.
///
/// Reached only when the fixed shell genuinely cannot fit. Non-scrolling is a
/// design goal for the normal path, never a reason to clip text or put the
/// shutter out of reach.
class _ScrollFallbackShell extends StatelessWidget {
  const _ScrollFallbackShell({required this.capture, required this.live});

  final LiveCaptureState capture;
  final LiveScanState live;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
    child: ListView(
      children: [
        const SizedBox(height: AppSpacing.sm),
        AspectRatio(
          aspectRatio: 3 / 4,
          child: _Viewport(capture: capture, live: live),
        ),
        const SizedBox(height: AppSpacing.md),
        _Status(capture: capture, live: live),
        const SizedBox(height: AppSpacing.md),
        _CaptureAction(capture: capture, live: live),
        const SizedBox(height: AppSpacing.md),
      ],
    ),
  );
}

/// The preview, or the captured still once one exists.
class _Viewport extends ConsumerWidget {
  const _Viewport({required this.capture, required this.live});

  final LiveCaptureState capture;
  final LiveScanState live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = AppTone.info.resolve(context);
    final selfie = capture.selfie;
    final showsPreview = capture.showsPreview && selfie == null;
    final preview = ref.watch(livePreviewProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: info.surface,
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showsPreview)
              Semantics(
                label: 'Live camera preview',
                image: true,
                child: _LivePreviewSurface(preview: preview),
              )
            else if (selfie != null)
              LayoutBuilder(
                builder: (context, constraints) => Image.file(
                  File(selfie.originalPath),
                  fit: BoxFit.cover,
                  cacheWidth: decodeWidthFor(context, constraints),
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            // Only over a live feed, and only once the camera is actually
            // showing something. Drawing an alignment guide over a frozen
            // photograph would suggest the framing can still be changed.
            if (showsPreview)
              LiveFaceGuide(isReady: live.isReady && !capture.isBusy),
            if (capture.isBusy)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.32),
                child: Center(
                  child: AppProgress(
                    size: AppProgressSize.large,
                    // Fixed white: this sits on a scrim over the user's own
                    // photo, whose brightness the theme knows nothing about.
                    color: Colors.white,
                    semanticLabel: capture.progressLabel ?? 'Working',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The live camera image itself.
///
/// **Visibility here depends on the camera, and on nothing else.** It is not
/// conditioned on a check state, a Ready state, the frame stream, or whether an
/// analysis is in flight — a camera that is open shows a picture, full stop.
/// The hotfix that produced this widget existed because the preview was gated
/// on a value captured before the camera was opened and never recomputed: the
/// screen painted a blank surface for the whole session while validation ran
/// perfectly behind it.
///
/// The camera's listenable is resolved *during build*, and the surface
/// additionally rebuilds on the controller's own notifications. Preview
/// geometry stays with `CameraPreview`, which applies the current camera
/// orientation to the sensor ratio itself.
class _LivePreviewSurface extends StatelessWidget {
  const _LivePreviewSurface({required this.preview});

  final LivePreview preview;

  @override
  Widget build(BuildContext context) {
    final listenable = preview.listenableOf();
    if (listenable == null) return _surface(context);
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) => _surface(context),
    );
  }

  Widget _surface(BuildContext context) {
    final child = preview.build(context);
    // `CameraPreview` owns its orientation-aware AspectRatio. A loose, centred
    // child lets that ratio letterbox honestly; no `cover`, scale, transform or
    // outer sensor-ratio constraint crops or distorts the field of view.
    return Center(child: child);
  }
}

/// One headline, one supporting line, and the collapsed check detail.
///
/// Deliberately compact. The camera is the content; this is a caption under it,
/// not a report competing with it.
class _Status extends StatelessWidget {
  const _Status({required this.capture, required this.live});

  final LiveCaptureState capture;
  final LiveScanState live;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (capture.stage == LiveCaptureStage.rejected) {
      return AppNotice(
        tone: AppTone.danger,
        title: 'Retake needed',
        message: capture.message ?? 'Please retake the photo.',
        liveRegion: true,
      );
    }
    if (capture.isBusy) {
      // The honest sequence, with no invented percentage: the app genuinely
      // does not know how far through an upload or a model call it is.
      return AppNotice(
        tone: AppTone.info,
        message: capture.progressLabel ?? 'Working…',
        liveRegion: true,
      );
    }

    final isReady = live.isReady;
    final body = LiveGuidance.body(live);
    final summary = LiveGuidance.checkSummary(live);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                LiveGuidance.title(live),
                style: theme.textTheme.titleMedium?.copyWith(
                  // Not colour alone: readiness is carried by the word
                  // "Ready", by the supporting line, and by the shutter's own
                  // semantic label.
                  color: isReady
                      ? AppTone.success.resolve(context).accent
                      : null,
                ),
              ),
              if (body != null)
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted(context),
                  ),
                ),
            ],
          ),
        ),
        if (summary != null)
          LiveCheckDetails(summary: summary, snapshot: live.snapshot),
      ],
    );
  }
}

/// The shutter. The only path to a photograph.
class _CaptureAction extends ConsumerWidget {
  const _CaptureAction({required this.capture, required this.live});

  final LiveCaptureState capture;
  final LiveScanState live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (capture.stage == LiveCaptureStage.rejected) {
      return PrimaryButton(
        key: const ValueKey('live-retake'),
        label: 'Retake photo',
        icon: Icons.camera_alt_outlined,
        onPressed: () =>
            ref.read(liveCaptureControllerProvider.notifier).retake(),
      );
    }

    // Disabled only while the sequence is already running, or while the camera
    // is not delivering frames. A merely imperfect frame does not lock the user
    // out of their own camera: local checks exist to save a paid call on an
    // obviously unusable frame, and the captured still is re-validated
    // regardless.
    final canCapture = !capture.isBusy && live.status == LiveScanStatus.running;

    return Semantics(
      button: true,
      enabled: canCapture,
      label: live.isReady ? 'Take photo. Checks are ready.' : 'Take photo',
      child: PrimaryButton(
        key: const ValueKey('live-shutter'),
        label: 'Take photo',
        icon: Icons.camera_alt_rounded,
        onPressed: canCapture
            ? () => ref.read(liveCaptureControllerProvider.notifier).capture()
            : null,
      ),
    );
  }
}
