import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_category.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_geometry.dart';
import 'package:facetune/features/tutorial_v3/presentation/painters/tutorial_v3_guideline_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The overlay is only correct if a normalized point lands on the same part of
/// the photograph on every device. These pin that: the same geometry is mapped
/// through different canvas sizes, aspect ratios and fits, and checked against
/// the rect the image actually occupies.
void main() {
  const portrait = Size(1080, 1440); // 3:4, the shape selfies are captured in
  const square = Size(1024, 1024);
  const tall = Size(900, 1600); // 9:16

  TutorialV3GeometryTransform transform({
    Size imageSize = portrait,
    Size canvasSize = const Size(360, 640),
    BoxFit fit = BoxFit.contain,
    Alignment alignment = Alignment.center,
  }) => TutorialV3GeometryTransform(
    imageSize: imageSize,
    canvasSize: canvasSize,
    fit: fit,
    alignment: alignment,
  );

  group('destination rect', () {
    test('contain letterboxes a portrait image in a taller box', () {
      // 3:4 into 360x640 fits by width, leaving equal bands above and below.
      final rect = transform().destinationRect;

      expect(rect.width, closeTo(360, 0.01));
      expect(rect.height, closeTo(480, 0.01));
      expect(rect.top, closeTo(80, 0.01));
      expect(rect.bottom, closeTo(560, 0.01));
    });

    test('contain pillarboxes a portrait image in a wider box', () {
      final rect = transform(canvasSize: const Size(800, 480)).destinationRect;

      expect(rect.height, closeTo(480, 0.01));
      expect(rect.width, closeTo(360, 0.01));
      expect(rect.left, closeTo(220, 0.01));
    });

    test('cover fills the box and crops the overflow', () {
      final rect = transform(
        canvasSize: const Size(360, 640),
        fit: BoxFit.cover,
      ).destinationRect;

      expect(rect.width, greaterThanOrEqualTo(360));
      expect(rect.height, greaterThanOrEqualTo(640));
      // Centred, so the crop is symmetric.
      expect(rect.center.dx, closeTo(180, 0.01));
      expect(rect.center.dy, closeTo(320, 0.01));
    });

    test('alignment moves the letterboxed image', () {
      final top = transform(alignment: Alignment.topCenter).destinationRect;
      final bottom = transform(
        alignment: Alignment.bottomCenter,
      ).destinationRect;

      expect(top.top, closeTo(0, 0.01));
      expect(bottom.bottom, closeTo(640, 0.01));
    });

    test('fill uses the whole box regardless of aspect ratio', () {
      final rect = transform(fit: BoxFit.fill).destinationRect;

      expect(rect, const Rect.fromLTWH(0, 0, 360, 640));
    });
  });

  group('point mapping', () {
    test('the corners of the image map to the corners of its rect', () {
      final mapper = transform();
      final rect = mapper.destinationRect;

      expect(mapper.toCanvas(const NormalizedPoint(0, 0)), rect.topLeft);
      expect(mapper.toCanvas(const NormalizedPoint(1, 1)), rect.bottomRight);
    });

    test('the centre of the image maps to the centre of its rect', () {
      final mapper = transform();

      final centre = mapper.toCanvas(const NormalizedPoint(0.5, 0.5));
      expect(centre.dx, closeTo(mapper.destinationRect.center.dx, 0.01));
      expect(centre.dy, closeTo(mapper.destinationRect.center.dy, 0.01));
    });

    test('a point lands on the same fraction of the image at any size', () {
      // The invariant that makes persisted geometry device-independent.
      const point = NormalizedPoint(0.3, 0.62);
      for (final canvas in const [
        Size(320, 568), // small phone
        Size(360, 640),
        Size(430, 932), // large phone
        Size(834, 1112), // tablet
      ]) {
        final mapper = transform(canvasSize: canvas);
        final rect = mapper.destinationRect;
        final at = mapper.toCanvas(point);

        expect(
          (at.dx - rect.left) / rect.width,
          closeTo(0.3, 1e-9),
          reason: 'x drifted at $canvas',
        );
        expect(
          (at.dy - rect.top) / rect.height,
          closeTo(0.62, 1e-9),
          reason: 'y drifted at $canvas',
        );
      }
    });

    test('it holds across portrait aspect ratios too', () {
      const point = NormalizedPoint(0.75, 0.25);
      for (final image in const [portrait, square, tall]) {
        final mapper = transform(imageSize: image);
        final rect = mapper.destinationRect;
        final at = mapper.toCanvas(point);

        expect((at.dx - rect.left) / rect.width, closeTo(0.75, 1e-9));
        expect((at.dy - rect.top) / rect.height, closeTo(0.25, 1e-9));
      }
    });

    test('every mapped point stays inside the image rect under contain', () {
      final mapper = transform();
      final rect = mapper.destinationRect;

      for (var x = 0.0; x <= 1.0; x += 0.1) {
        for (var y = 0.0; y <= 1.0; y += 0.1) {
          final at = mapper.toCanvas(NormalizedPoint(x, y));
          expect(rect.inflate(0.001).contains(at), isTrue);
        }
      }
    });
  });

  group('radii and stroke scale', () {
    test('radii scale with the rect, not the canvas', () {
      final mapper = transform();
      final rect = mapper.destinationRect;

      final radii = mapper.toCanvasRadii(0.1, 0.05);

      expect(radii.dx, closeTo(rect.width * 0.1, 0.01));
      expect(radii.dy, closeTo(rect.height * 0.05, 0.01));
    });

    test('an ellipse keeps its shape relative to the image', () {
      // Equal normalized radii on a 3:4 image are taller than wide in pixels,
      // which is correct: the geometry is expressed in image space.
      final radii = transform().toCanvasRadii(0.1, 0.1);

      expect(radii.dy / radii.dx, closeTo(480 / 360, 1e-9));
    });

    test('the reference extent is the shorter edge of the image rect', () {
      expect(transform().referenceExtent, closeTo(360, 0.01));
      expect(
        transform(canvasSize: const Size(800, 480)).referenceExtent,
        closeTo(360, 0.01),
      );
    });

    test('stroke width grows with the display, keeping weight consistent', () {
      final small = transform(canvasSize: const Size(320, 568)).referenceExtent;
      final large = transform(
        canvasSize: const Size(834, 1112),
      ).referenceExtent;

      expect(large, greaterThan(small));
    });
  });

  group('painter repaint policy', () {
    TutorialV3GuidelinePainter painter({
      Size imageSize = portrait,
      BoxFit fit = BoxFit.contain,
    }) => TutorialV3GuidelinePainter(
      geometry: const TutorialV3Geometry(
        schemaVersion: tutorialV3GeometrySchemaVersion,
        category: TutorialV3Category.blush,
        coordinateSpace: tutorialV3CoordinateSpace,
        primitives: [],
      ),
      imageSize: imageSize,
      fit: fit,
    );

    test('it repaints when the image size changes', () {
      expect(
        painter().shouldRepaint(painter(imageSize: square)),
        isTrue,
        reason: 'a different selfie needs a different transform',
      );
    });

    test('it repaints when the fit changes', () {
      expect(painter().shouldRepaint(painter(fit: BoxFit.cover)), isTrue);
    });
  });
}
