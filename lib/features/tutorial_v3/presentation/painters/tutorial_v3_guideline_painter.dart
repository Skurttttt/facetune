import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/tutorial_v3_geometry.dart';

/// Maps normalized ORIGINAL-image coordinates onto the rect the image actually
/// occupies on screen.
///
/// This is the piece that makes persisted geometry device-independent. The
/// model is told nothing about screen size or BoxFit; it answers in the
/// original image's own space, and this transform places that answer wherever
/// the image lands. It uses Flutter's own `applyBoxFit` + `Alignment.inscribe`
/// rather than hand-rolled arithmetic, so it matches exactly what the `Image`
/// widget above it did.
@immutable
class TutorialV3GeometryTransform {
  const TutorialV3GeometryTransform({
    required this.imageSize,
    required this.canvasSize,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });

  /// The original image's pixel dimensions — the space coordinates refer to.
  final Size imageSize;

  /// The box the image is being painted into.
  final Size canvasSize;

  final BoxFit fit;
  final Alignment alignment;

  /// The rect the image actually occupies inside [canvasSize].
  Rect get destinationRect {
    final fitted = applyBoxFit(fit, imageSize, canvasSize);
    return alignment.inscribe(fitted.destination, Offset.zero & canvasSize);
  }

  /// Maps one normalized point to a canvas offset.
  Offset toCanvas(NormalizedPoint point) {
    final rect = destinationRect;
    return Offset(
      rect.left + point.x * rect.width,
      rect.top + point.y * rect.height,
    );
  }

  /// Scales a normalized radius along each axis independently, so an ellipse
  /// keeps its proportions relative to the image rather than the screen.
  Offset toCanvasRadii(double radiusX, double radiusY) {
    final rect = destinationRect;
    return Offset(radiusX * rect.width, radiusY * rect.height);
  }

  /// The shortest destination edge, used for size-invariant stroke widths.
  double get referenceExtent {
    final rect = destinationRect;
    return math.min(rect.width, rect.height);
  }
}

/// The fixed visual treatment for each semantic role.
///
/// **Flutter owns all style.** The AI supplies shape and meaning only; every
/// colour, opacity and stroke width below is a product decision made here, so
/// a model can never alter the app's visual language.
@immutable
class TutorialV3RoleStyle {
  const TutorialV3RoleStyle({
    required this.stroke,
    required this.fill,
    this.strokeScale = 0.006,
    this.dashed = false,
  });

  final Color stroke;
  final Color? fill;

  /// Stroke width as a fraction of the destination's shorter edge, so the
  /// overlay reads the same on a phone and a tablet.
  final double strokeScale;

  final bool dashed;

  static const Map<TutorialV3GeometryRole, TutorialV3RoleStyle> byRole = {
    TutorialV3GeometryRole.coverageZone: TutorialV3RoleStyle(
      stroke: Color(0xCC29B6F6),
      fill: Color(0x3329B6F6),
    ),
    TutorialV3GeometryRole.placementZone: TutorialV3RoleStyle(
      stroke: Color(0xCC26C6DA),
      fill: Color(0x3826C6DA),
    ),
    TutorialV3GeometryRole.applicationPath: TutorialV3RoleStyle(
      stroke: Color(0xFF00E5FF),
      fill: null,
      strokeScale: 0.008,
    ),
    TutorialV3GeometryRole.blendDirection: TutorialV3RoleStyle(
      stroke: Color(0xFFFFFFFF),
      fill: null,
      strokeScale: 0.007,
    ),
    TutorialV3GeometryRole.boundary: TutorialV3RoleStyle(
      stroke: Color(0xFF80D8FF),
      fill: null,
      strokeScale: 0.005,
      dashed: true,
    ),
    TutorialV3GeometryRole.exclusion: TutorialV3RoleStyle(
      stroke: Color(0xCCFF7043),
      fill: Color(0x22FF7043),
      dashed: true,
    ),
    TutorialV3GeometryRole.focusMarker: TutorialV3RoleStyle(
      stroke: Color(0xFFFFFFFF),
      fill: Color(0x66FFFFFF),
    ),
  };

  static TutorialV3RoleStyle of(TutorialV3GeometryRole role) =>
      byRole[role] ??
      const TutorialV3RoleStyle(stroke: Color(0xFFFFFFFF), fill: null);
}

/// Draws validated geometry over the original selfie.
///
/// The painter never touches the photograph — it only paints on top of it. The
/// widget tree is a `Stack` of `Image` then `CustomPaint`, so the original
/// pixels are displayed untouched by construction.
class TutorialV3GuidelinePainter extends CustomPainter {
  const TutorialV3GuidelinePainter({
    required this.geometry,
    required this.imageSize,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });

  final TutorialV3Geometry geometry;
  final Size imageSize;
  final BoxFit fit;
  final Alignment alignment;

  @override
  void paint(Canvas canvas, Size size) {
    final transform = TutorialV3GeometryTransform(
      imageSize: imageSize,
      canvasSize: size,
      fit: fit,
      alignment: alignment,
    );
    final unit = transform.referenceExtent;

    for (final primitive in geometry.primitives) {
      final style = TutorialV3RoleStyle.of(primitive.role);
      final strokePaint = Paint()
        ..color = style.stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * style.strokeScale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;
      final fillPaint = style.fill == null
          ? null
          : (Paint()
              ..color = style.fill!
              ..style = PaintingStyle.fill
              ..isAntiAlias = true);

      switch (primitive) {
        case TutorialV3Region(:final vertices):
          final path = Path()
            ..addPolygon(
              vertices.map(transform.toCanvas).toList(growable: false),
              true,
            );
          if (fillPaint != null) canvas.drawPath(path, fillPaint);
          _strokePath(canvas, path, strokePaint, style.dashed, unit);

        case TutorialV3Ellipse(
          :final center,
          :final radiusX,
          :final radiusY,
          :final rotation,
        ):
          final middle = transform.toCanvas(center);
          final radii = transform.toCanvasRadii(radiusX, radiusY);
          canvas.save();
          canvas.translate(middle.dx, middle.dy);
          canvas.rotate(rotation);
          final rect = Rect.fromCenter(
            center: Offset.zero,
            width: radii.dx * 2,
            height: radii.dy * 2,
          );
          if (fillPaint != null) canvas.drawOval(rect, fillPaint);
          canvas.drawOval(rect, strokePaint);
          canvas.restore();

        case TutorialV3Polyline(:final vertices):
          final points = vertices
              .map(transform.toCanvas)
              .toList(growable: false);
          final path = Path()..moveTo(points.first.dx, points.first.dy);
          for (final point in points.skip(1)) {
            path.lineTo(point.dx, point.dy);
          }
          _strokePath(canvas, path, strokePaint, style.dashed, unit);

        case TutorialV3Arrow(:final start, :final end):
          _drawArrow(
            canvas,
            transform.toCanvas(start),
            transform.toCanvas(end),
            strokePaint,
            unit,
          );

        case TutorialV3Marker(:final position):
          final at = transform.toCanvas(position);
          final radius = unit * 0.012;
          if (fillPaint != null) canvas.drawCircle(at, radius, fillPaint);
          canvas.drawCircle(at, radius, strokePaint);
      }
    }
  }

  void _strokePath(
    Canvas canvas,
    Path path,
    Paint paint,
    bool dashed,
    double unit,
  ) {
    if (!dashed) {
      canvas.drawPath(path, paint);
      return;
    }
    final dash = unit * 0.02;
    final gap = unit * 0.014;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  void _drawArrow(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double unit,
  ) {
    canvas.drawLine(start, end, paint);
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    final head = unit * 0.028;
    const spread = math.pi / 7;
    final left = Offset(
      end.dx - head * math.cos(angle - spread),
      end.dy - head * math.sin(angle - spread),
    );
    final right = Offset(
      end.dx - head * math.cos(angle + spread),
      end.dy - head * math.sin(angle + spread),
    );
    canvas.drawLine(end, left, paint);
    canvas.drawLine(end, right, paint);
  }

  @override
  bool shouldRepaint(TutorialV3GuidelinePainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.imageSize != imageSize ||
      oldDelegate.fit != fit ||
      oldDelegate.alignment != alignment;
}
