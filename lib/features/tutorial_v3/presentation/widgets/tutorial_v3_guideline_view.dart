import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../domain/entities/tutorial_v3_geometry.dart';
import '../painters/tutorial_v3_guideline_painter.dart';

/// The original selfie with its personalized guideline drawn on top.
///
/// ```text
/// Stack
/// ├── Image(originalSelfie)      ← displayed, never rewritten
/// └── CustomPaint(geometry)      ← Flutter-drawn, deterministic
/// ```
///
/// The overlay's alignment depends on knowing the ORIGINAL image's pixel
/// dimensions: geometry is normalized against that space, and
/// [TutorialV3GeometryTransform] needs the real aspect ratio to place it inside
/// whatever rect the image ends up occupying. So the image is resolved first,
/// and the painter is attached only once its intrinsic size is known — painting
/// against a guessed size would land the overlay in the wrong place on any
/// selfie that is not exactly the widget's shape.
///
/// [fit] and [alignment] are passed to the `Image` and to the transform from
/// the same fields, so the two can never disagree.
class TutorialV3GuidelineView extends StatefulWidget {
  const TutorialV3GuidelineView({
    required this.image,
    required this.geometry,
    super.key,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.semanticLabel,
  });

  /// The original selfie. An [ImageProvider] rather than a URL so this widget
  /// is decoupled from how the photograph is fetched — the page supplies a
  /// [NetworkImage] over a signed URL.
  final ImageProvider image;

  /// The validated geometry to draw, or null while it is being mapped, when it
  /// failed, or on the final look. A null overlay shows the selfie alone —
  /// which is exactly what "a missing guideline" should look like.
  final TutorialV3Geometry? geometry;

  final BoxFit fit;
  final Alignment alignment;

  final String? semanticLabel;

  @override
  State<TutorialV3GuidelineView> createState() =>
      _TutorialV3GuidelineViewState();
}

class _TutorialV3GuidelineViewState extends State<TutorialV3GuidelineView> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _imageSize;
  bool _failed = false;

  ImageProvider get _provider => widget.image;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(TutorialV3GuidelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _imageSize = null;
      _failed = false;
      _resolve();
    }
  }

  void _resolve() {
    final stream = _provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _detach();
    _stream = stream;
    _listener = ImageStreamListener(
      (image, _) {
        final size = Size(
          image.image.width.toDouble(),
          image.image.height.toDouble(),
        );
        image.dispose();
        if (!mounted) return;
        setState(() {
          _imageSize = size;
          _failed = false;
        });
      },
      onError: (error, stackTrace) {
        if (!mounted) return;
        setState(() => _failed = true);
      },
    );
    stream.addListener(_listener!);
  }

  void _detach() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const ColoredBox(
        color: AppColors.sand,
        child: Center(
          child: Icon(Icons.broken_image_outlined, size: AppIconSizes.lg),
        ),
      );
    }

    final imageSize = _imageSize;
    final geometry = widget.geometry;

    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The photograph itself. Displayed only — nothing here writes to it.
          Image(
            image: _provider,
            fit: widget.fit,
            alignment: widget.alignment,
            excludeFromSemantics: true,
            frameBuilder: (context, child, frame, synchronouslyLoaded) =>
                synchronouslyLoaded || frame != null
                ? child
                : const ColoredBox(color: AppColors.sand),
          ),
          if (geometry != null && imageSize != null)
            // The overlay is only attached once the real image dimensions are
            // known, so it is aligned from its very first frame.
            RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: TutorialV3GuidelinePainter(
                  geometry: geometry,
                  imageSize: imageSize,
                  fit: widget.fit,
                  alignment: widget.alignment,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
