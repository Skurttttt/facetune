import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../domain/entities/tutorial_placement_metadata.dart';

/// Paints a [TutorialPlacementMetadata]'s overlays on top of whatever it is
/// stacked over (a placement image), scaled to fill this widget's box.
///
/// Every [TutorialPlacementOverlay.points] entry is normalized `0.0`–`1.0`
/// (guide-independent of screen size — see the domain type's doc comment),
/// so this widget maps them to the actual displayed box size at paint
/// time via [LayoutBuilder]/[CustomPainter.size] rather than ever reading a
/// fixed pixel coordinate from the overlay data itself.
class TutorialPlacementOverlayLayer extends StatelessWidget {
  const TutorialPlacementOverlayLayer({required this.metadata, super.key});

  final TutorialPlacementMetadata metadata;

  @override
  Widget build(BuildContext context) {
    if (metadata.overlays.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) => CustomPaint(
        size: Size(constraints.maxWidth, constraints.maxHeight),
        painter: _PlacementOverlayPainter(metadata.overlays),
      ),
    );
  }
}

class _PlacementOverlayPainter extends CustomPainter {
  const _PlacementOverlayPainter(this.overlays);

  final List<TutorialPlacementOverlay> overlays;

  static const _defaultZoneColor = AppColors.rose;
  static const _defaultStrokeColor = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    for (final overlay in overlays) {
      final points = overlay.points
          .map((point) => Offset(point.x * size.width, point.y * size.height))
          .toList(growable: false);
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
          );
        case TutorialPlacementOverlayType.line:
          _paintPolyline(
            canvas,
            points,
            _colorFor(overlay, _defaultStrokeColor),
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
          _paintLabel(canvas, points.first, overlay.label);
      }
    }
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

  void _paintBoundary(Canvas canvas, List<Offset> points, Color color) {
    final stroke = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      points.length < 3
          ? (Path()..addPolygon(points, false))
          : _closedPath(points),
      stroke,
    );
  }

  void _paintPolyline(Canvas canvas, List<Offset> points, Color color) {
    final stroke = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
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
      ..strokeWidth = 2.5
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

  void _paintLabel(Canvas canvas, Offset anchor, String? text) {
    if (text == null || text.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const padding = 4.0;
    final rect = Rect.fromLTWH(
      anchor.dx,
      anchor.dy,
      painter.width + padding * 2,
      painter.height + padding * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
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
      !identical(oldDelegate.overlays, overlays);
}
