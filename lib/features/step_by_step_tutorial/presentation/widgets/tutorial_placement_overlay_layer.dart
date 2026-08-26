import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../domain/entities/personalized_tutorial.dart';
import '../../domain/entities/tutorial_placement_metadata.dart';
import '../../domain/services/personalized_tutorial_overlay_metadata_renderer.dart';

/// Spec-driven entry point for personalized tutorial overlays.
class PersonalizedTutorialOverlayLayer extends StatelessWidget {
  const PersonalizedTutorialOverlayLayer({required this.spec, super.key});

  final PersonalizedTutorialStepSpec spec;

  @override
  Widget build(BuildContext context) => TutorialPlacementOverlayLayer(
    metadata: PersonalizedTutorialOverlayMetadataRenderer.build(spec),
  );
}

/// Paints a [TutorialPlacementMetadata]'s overlays on top of whatever it is
/// stacked over (a placement image), scaled to fill this widget's box.
///
/// Every [TutorialPlacementOverlay.points] entry is normalized `0.0`–`1.0`
/// relative to the *whole source image* — the same convention
/// `plan-tutorial-geometry` (TF-2) uses when it asks Gemini for coordinates,
/// and the same convention every other geometry primitive in this feature
/// already uses. This widget's box, however, is not guaranteed to show the
/// whole source image: [PlacementResultComparison] displays it with
/// `BoxFit.cover` inside a fixed-aspect-ratio box, which *crops* the source
/// image whenever its own aspect ratio differs from the box's (selfies are
/// only validated to fall within a broad 0.4–2.5 ratio range — see
/// `LocalImageValidation` — never guaranteed to already match the box).
/// Passing [imageUrl] (the same URL the sibling Placement image renders)
/// lets this widget resolve the source image's real intrinsic size and
/// reproduce the identical `BoxFit.cover` crop math internally, so a
/// normalized point maps onto the correct *visible* pixel — not onto the
/// naive assumption that this box's edges are the source image's edges.
/// [imageUrl] is optional: when it is `null`, or its size has not resolved
/// yet, this falls back to the previous full-box mapping (only exactly
/// correct when the source image already matches the box's own aspect
/// ratio), which is a safe degradation, never a crash or a fabricated
/// coordinate.
class TutorialPlacementOverlayLayer extends StatefulWidget {
  const TutorialPlacementOverlayLayer({
    required this.metadata,
    this.imageUrl,
    super.key,
  });

  final TutorialPlacementMetadata metadata;
  final String? imageUrl;

  @override
  State<TutorialPlacementOverlayLayer> createState() =>
      _TutorialPlacementOverlayLayerState();
}

class _TutorialPlacementOverlayLayerState
    extends State<TutorialPlacementOverlayLayer> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _resolveImageSize();
  }

  @override
  void didUpdateWidget(TutorialPlacementOverlayLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _imageSize = null;
      _resolveImageSize();
    }
  }

  void _resolveImageSize() {
    final url = widget.imageUrl;
    if (url == null) return;
    final stream = NetworkImage(url).resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (info, synchronousCall) {
        if (!mounted) return;
        setState(() {
          _imageSize = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
      },
      // A failed resolution (offline, expired signed URL, decode error)
      // just leaves `_imageSize` null -- the full-box fallback mapping
      // below, never a crash and never a fabricated size.
      onError: (error, stackTrace) {},
    );
    _detachListener();
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  void _detachListener() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) stream.removeListener(listener);
  }

  @override
  void dispose() {
    _detachListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.metadata.overlays.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) => CustomPaint(
        size: Size(constraints.maxWidth, constraints.maxHeight),
        painter: _PlacementOverlayPainter(widget.metadata.overlays, _imageSize),
      ),
    );
  }
}

/// Reproduces Flutter's own `BoxFit.cover` scale-and-center transform so a
/// point normalized `0.0`–`1.0` against a source image's *whole* extent
/// maps onto the correct visible pixel of a [boxSize] box showing that same
/// source image with `fit: BoxFit.cover` — the exact fit
/// `PrivateImage`/`Image.network` uses for the tutorial's Placement image.
///
/// `BoxFit.cover` scales [imageSize] up uniformly until it fills [boxSize]
/// on *both* axes, then centers it — cropping whichever axis overflows.
/// This class computes that same scale/offset once and applies it to every
/// point, rather than the naive (and only sometimes correct) assumption
/// that the box's own edges are the source image's edges.
///
/// Pure geometry, independent of Flutter's image-loading pipeline — kept
/// deliberately testable on its own (see
/// `tutorial_placement_overlay_layer_test.dart`) without needing to mock a
/// resolved [ImageStream].
class TutorialCoverTransform {
  TutorialCoverTransform({required this.imageSize, required this.boxSize})
    : assert(imageSize.width > 0 && imageSize.height > 0),
      _scale = math.max(
        boxSize.width / imageSize.width,
        boxSize.height / imageSize.height,
      );

  final Size imageSize;
  final Size boxSize;
  final double _scale;

  double get _scaledWidth => imageSize.width * _scale;
  double get _scaledHeight => imageSize.height * _scale;

  /// How far, in box-local pixels, the scaled image extends past the box on
  /// each axis. Zero on the axis `BoxFit.cover` fits exactly; negative
  /// (i.e. an inward offset) on the axis it crops, since the scaled image
  /// is centered and therefore starts before the box's own origin there.
  double get offsetX => (boxSize.width - _scaledWidth) / 2;
  double get offsetY => (boxSize.height - _scaledHeight) / 2;

  /// Maps a point normalized `0.0`–`1.0` against the whole source image to
  /// its visible position in box-local pixels.
  Offset map(double normalizedX, double normalizedY) => Offset(
    offsetX + normalizedX * _scaledWidth,
    offsetY + normalizedY * _scaledHeight,
  );
}

class _PlacementOverlayPainter extends CustomPainter {
  const _PlacementOverlayPainter(this.overlays, this.imageSize);

  final List<TutorialPlacementOverlay> overlays;

  /// The source image's real intrinsic size, when known — see the doc
  /// comment on [TutorialPlacementOverlayLayer.imageUrl] for why this is
  /// required to map a normalized point correctly whenever the source
  /// image doesn't already match this painter's own aspect ratio.
  final Size? imageSize;

  static const _defaultZoneColor = AppColors.rose;
  static const _defaultStrokeColor = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final mapPoint = _pointMapper(size);
    for (final overlay in overlays) {
      final points = overlay.points.map(mapPoint).toList(growable: false);
      if (points.isEmpty) continue;
      final shortestSide = math.min(size.width, size.height);
      switch (overlay.type) {
        case TutorialPlacementOverlayType.zone:
          _paintZone(
            canvas,
            points,
            _colorFor(overlay, _defaultZoneColor),
            shortestSide,
          );
        case TutorialPlacementOverlayType.boundary:
          _paintBoundary(
            canvas,
            points,
            _colorFor(overlay, _defaultStrokeColor),
            shortestSide,
          );
        case TutorialPlacementOverlayType.line:
          _paintPolyline(
            canvas,
            points,
            _colorFor(overlay, _defaultStrokeColor),
            shortestSide,
          );
        case TutorialPlacementOverlayType.arrow:
          _paintArrow(
            canvas,
            points,
            _colorFor(overlay, _defaultStrokeColor),
            shortestSide,
          );
        case TutorialPlacementOverlayType.dot:
          _paintDots(
            canvas,
            points,
            _colorFor(overlay, _defaultStrokeColor),
            shortestSide,
          );
        case TutorialPlacementOverlayType.label:
          _paintLabel(canvas, points.first, overlay.label, shortestSide);
      }
    }
  }

  /// Builds the normalized-point-to-canvas-offset function for this paint
  /// pass. When [imageSize] is unknown, this is the previous naive mapping
  /// (`point * size`) — only exactly correct when the source image already
  /// matches [size]'s own aspect ratio. When [imageSize] is known, this
  /// delegates to [TutorialCoverTransform], which reproduces the identical
  /// `BoxFit.cover` scale-and-center transform `Image.network(fit:
  /// BoxFit.cover)` applies, so a point normalized against the *whole*
  /// source image lands on the same visible pixel the image itself shows
  /// there — not on a pixel that was cropped away.
  Offset Function(TutorialPlacementPoint) _pointMapper(Size size) {
    final source = imageSize;
    if (source == null || source.width <= 0 || source.height <= 0) {
      return (point) => Offset(point.x * size.width, point.y * size.height);
    }
    final transform = TutorialCoverTransform(imageSize: source, boxSize: size);
    return (point) => transform.map(point.x, point.y);
  }

  /// A zone is a soft circle for one point, a rounded capsule between two
  /// points, or a filled polygon for three or more — see the doc comment
  /// on `TutorialPlacementOverlayCatalog` for why these three shapes cover
  /// the placement guides this app needs without per-category rendering
  /// code.
  void _paintZone(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double shortestSide,
  ) {
    final fill = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    if (points.length == 1) {
      canvas.drawCircle(points.first, shortestSide * 0.07, fill);
      return;
    }
    if (points.length == 2) {
      final capsule = Paint()
        ..color = color.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = shortestSide * 0.12;
      canvas.drawLine(points[0], points[1], capsule);
      return;
    }
    canvas.drawPath(_closedPath(points), fill);
  }

  void _paintBoundary(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double shortestSide,
  ) {
    final stroke = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = shortestSide * 0.006
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      points.length < 3
          ? (Path()..addPolygon(points, false))
          : _closedPath(points),
      stroke,
    );
  }

  void _paintPolyline(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double shortestSide,
  ) {
    final stroke = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = shortestSide * 0.006
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(Path()..addPolygon(points, false), stroke);
  }

  void _paintArrow(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double shortestSide,
  ) {
    final start = points.first;
    final end = points.last;
    final stroke = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = shortestSide * 0.006
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, stroke);

    final direction = end - start;
    if (direction.distance == 0) return;
    final angle = math.atan2(direction.dy, direction.dx);
    final headLength = shortestSide * 0.04;
    const headAngle = math.pi / 7;
    final left = end - Offset.fromDirection(angle - headAngle, headLength);
    final right = end - Offset.fromDirection(angle + headAngle, headLength);
    final head = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawPath(
      Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close(),
      head,
    );
  }

  void _paintDots(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double shortestSide,
  ) {
    final fill = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;
    final radius = shortestSide * 0.012;
    for (final point in points) {
      canvas.drawCircle(point, radius, fill);
    }
  }

  void _paintLabel(
    Canvas canvas,
    Offset anchor,
    String? text,
    double shortestSide,
  ) {
    if (text == null || text.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: Colors.white, fontSize: shortestSide * 0.032),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final padding = shortestSide * 0.012;
    final rect = Rect.fromLTWH(
      anchor.dx,
      anchor.dy,
      painter.width + padding * 2,
      painter.height + padding * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(shortestSide * 0.012)),
      Paint()..color = Colors.black54,
    );
    painter.paint(canvas, Offset(anchor.dx + padding, anchor.dy + padding));
  }

  Path _closedPath(List<Offset> points) => Path()..addPolygon(points, true);

  Color _colorFor(TutorialPlacementOverlay overlay, Color fallback) {
    final hex = overlay.colorHex;
    if (hex == null) return fallback;
    return Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);
  }

  @override
  bool shouldRepaint(covariant _PlacementOverlayPainter oldDelegate) =>
      !identical(oldDelegate.overlays, overlays) ||
      oldDelegate.imageSize != imageSize;
}
