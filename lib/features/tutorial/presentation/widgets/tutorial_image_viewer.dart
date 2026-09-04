import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../utils/tutorial_image_focus.dart';
import '../utils/tutorial_labels.dart';

/// A full-screen look at one image the tutorial already has.
///
/// Purely a way of showing an existing artifact larger. It takes a signed URL
/// that the caller is already displaying inline, so opening it resolves
/// nothing, signs nothing, downloads nothing new, and above all generates
/// nothing: the same [PrivateImage] and the same URL, in a bigger box.
///
/// [focus] decides where it opens. A complexion step opens on the whole face; an
/// eyeliner step opens on the eyes, because that is the wing the user is trying
/// to see. In every case the transform is a starting position on the complete
/// image — [InteractiveViewer] keeps the whole frame reachable by pinch and
/// pan, and double-tap returns to it — so facial context is never removed, only
/// scrolled past.
///
/// The surface is [ColorScheme.surface] rather than the black a photo viewer
/// usually reaches for, so the page follows the global Light/Dark/System theme
/// like every other screen. A guideline image is a document to read, not a
/// photograph to admire, and it is read beside a card that is also themed.
class TutorialImageViewer extends StatefulWidget {
  const TutorialImageViewer({
    required this.url,
    required this.title,
    required this.semanticLabel,
    this.focus = TutorialImageFocus.wholeFace,
    super.key,
  });

  /// Opens the viewer for [url] as a full-screen route.
  ///
  /// A route rather than a dialog so the system back gesture closes it, which
  /// is the return behaviour a full-screen image is expected to have on
  /// Android.
  static Future<void> open(
    BuildContext context, {
    required String url,
    required String title,
    required String semanticLabel,
    TutorialImageFocus focus = TutorialImageFocus.wholeFace,
  }) => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => TutorialImageViewer(
        url: url,
        title: title,
        semanticLabel: semanticLabel,
        focus: focus,
      ),
    ),
  );

  final String url;

  /// What the user is looking at — a guideline, or the final look. Shown so the
  /// two are never confusable once they fill the screen.
  final String title;

  final String semanticLabel;

  final TutorialImageFocus focus;

  @override
  State<TutorialImageViewer> createState() => _TutorialImageViewerState();
}

class _TutorialImageViewerState extends State<TutorialImageViewer> {
  final TransformationController _transformation = TransformationController();

  /// Whether the view is currently anywhere other than its opening position.
  ///
  /// Drives the reset affordance, which is only offered when it would do
  /// something. Tracked from the controller rather than from gestures because
  /// [InteractiveViewer] is also moved by its own inertia.
  bool _moved = false;

  @override
  void initState() {
    super.initState();
    _transformation.addListener(_onTransformChanged);
    // Applied after layout because the opening transform is expressed relative
    // to the viewport, and the viewport has no size until then.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reset();
    });
  }

  @override
  void dispose() {
    _transformation.removeListener(_onTransformChanged);
    _transformation.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final moved = _transformation.value != _openingTransform();
    if (moved != _moved) setState(() => _moved = moved);
  }

  /// The transform this viewer opens at, for the current viewport size.
  ///
  /// Scale about the focus point, expressed as a translation so the point named
  /// by [TutorialImageFocus.alignment] lands in the middle of the viewport. The
  /// arithmetic is the standard one for scaling about an arbitrary origin:
  /// scale first, then shift by how far the focus moved.
  Matrix4 _openingTransform() {
    final focus = widget.focus;
    if (!focus.isZoomed) return Matrix4.identity();
    final size = context.size;
    if (size == null) return Matrix4.identity();
    // Alignment is -1..1 across the box; convert to a fraction of the box.
    final originX = (focus.alignment.x + 1) / 2 * size.width;
    final originY = (focus.alignment.y + 1) / 2 * size.height;
    return Matrix4.identity()
      ..translateByDouble(
        originX - originX * focus.scale + (size.width / 2 - originX),
        originY - originY * focus.scale + (size.height / 2 - originY),
        0,
        1,
      )
      ..scaleByDouble(focus.scale, focus.scale, 1, 1);
  }

  /// Returns the view to the position it opened at.
  ///
  /// Instant rather than animated. A tween here would be motion for its own
  /// sake on a control whose entire purpose is "put it back", and the reset
  /// affordance is a labelled button, so a screen-reader user already knows
  /// what pressing it did.
  void _reset() {
    setState(() {
      _transformation.value = _openingTransform();
      _moved = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.title),
        leading: Semantics(
          button: true,
          label: TutorialLabels.close,
          excludeSemantics: true,
          child: IconButton(
            icon: const Icon(Icons.close),
            tooltip: TutorialLabels.close,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        actions: [
          if (_moved)
            IconButton(
              icon: const Icon(Icons.zoom_out_map),
              tooltip: TutorialLabels.resetView,
              onPressed: _reset,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                // Double-tap is the conventional "put it back" for a zoomable
                // image, and it is the only way out of a deep zoom that does
                // not require finding a button.
                onDoubleTap: _reset,
                child: InteractiveViewer(
                  transformationController: _transformation,
                  // Bounded so the image cannot be flung off-screen and lost.
                  // The whole frame is always reachable, which is what keeps
                  // the opening zoom a starting point rather than a crop.
                  constrained: true,
                  minScale: 1,
                  maxScale: 5,
                  child: PrivateImage(
                    url: widget.url,
                    // contain, not cover: a guideline is only useful whole, and
                    // cropping one to fill the screen would hide marks.
                    fit: BoxFit.contain,
                    // Decoded above layout size so a zoomed-in wing stays
                    // sharp. ResizeImage never upscales past the source, so
                    // this costs nothing on a small original.
                    decodeMultiplier: 3,
                    semanticLabel: widget.semanticLabel,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                TutorialLabels.viewerHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
