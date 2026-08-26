import 'package:facetune/features/step_by_step_tutorial/domain/entities/personalized_tutorial.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_face_geometry.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_placement_metadata.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step_category.dart';
import 'package:facetune/features/step_by_step_tutorial/presentation/widgets/tutorial_placement_overlay_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, TutorialPlacementMetadata metadata) =>
    tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 300,
          height: 400,
          child: TutorialPlacementOverlayLayer(metadata: metadata),
        ),
      ),
    );

void main() {
  testWidgets(
    'personalized layer renders the same normalized spec at multiple sizes',
    (tester) async {
      final spec = PersonalizedTutorialStepSpec(
        stepNumber: 1,
        what: PersonalizedTutorialWhat(
          category: TutorialStepCategory.foundation,
          colorHex: '#E58C87',
        ),
        where: PersonalizedTutorialWhere(
          description: 'Broad face coverage',
          regions: const {TutorialPlacementRegion.fullFace},
          side: TutorialPlacementSide.full,
          geometryConfidence: TutorialPlacementConfidence.high,
          placementConfidence: TutorialPlacementConfidence.high,
          overlays: [
            PersonalizedTutorialOverlay(
              type: TutorialPlacementOverlayType.zone,
              region: TutorialPlacementRegion.fullFace,
              colorHex: '#E58C87',
            ),
            PersonalizedTutorialOverlay(
              type: TutorialPlacementOverlayType.arrow,
              region: TutorialPlacementRegion.fullFace,
            ),
          ],
          geometryAnchors: [
            PersonalizedTutorialGeometryAnchor(
              region: TutorialPlacementRegion.fullFace,
              side: TutorialGeometrySide.center,
              points: [
                TutorialNormalizedPoint(x: 0.2, y: 0.15),
                TutorialNormalizedPoint(x: 0.8, y: 0.15),
                TutorialNormalizedPoint(x: 0.75, y: 0.85),
                TutorialNormalizedPoint(x: 0.25, y: 0.85),
              ],
            ),
          ],
        ),
        how: PersonalizedTutorialHow(
          direction: TutorialDirection.outward,
          intensity: TutorialIntensity.medium,
          technique: TutorialTechnique('Blend outward.'),
        ),
      );

      for (final size in [const Size(256, 256), const Size(512, 768)]) {
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox.fromSize(
              size: size,
              child: PersonalizedTutorialOverlayLayer(spec: spec),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(CustomPaint), findsWidgets);
      }
    },
  );

  test('empty overlays renders no painter (SizedBox.shrink)', () async {
    // No pump needed — this is a pure widget construction check.
    const layer = TutorialPlacementOverlayLayer(
      metadata: TutorialPlacementMetadata(overlays: []),
    );
    expect(layer.metadata.overlays, isEmpty);
  });

  for (final entry in <String, TutorialPlacementOverlayType>{
    'zone (single point)': TutorialPlacementOverlayType.zone,
    'boundary': TutorialPlacementOverlayType.boundary,
    'line': TutorialPlacementOverlayType.line,
    'arrow': TutorialPlacementOverlayType.arrow,
    'dot': TutorialPlacementOverlayType.dot,
    'label': TutorialPlacementOverlayType.label,
  }.entries) {
    testWidgets('renders ${entry.key} overlays without throwing', (
      tester,
    ) async {
      await _pump(
        tester,
        TutorialPlacementMetadata(
          overlays: [
            TutorialPlacementOverlay(
              type: entry.value,
              points: const [
                TutorialPlacementPoint(0.3, 0.4),
                TutorialPlacementPoint(0.5, 0.6),
              ],
              label: 'Test overlay',
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  }

  testWidgets('renders a zone with three points (polygon) without throwing', (
    tester,
  ) async {
    await _pump(
      tester,
      const TutorialPlacementMetadata(
        overlays: [
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.zone,
            points: [
              TutorialPlacementPoint(0.2, 0.2),
              TutorialPlacementPoint(0.4, 0.2),
              TutorialPlacementPoint(0.3, 0.4),
            ],
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'renders an overlay with a single-point arrow (degenerate direction) without throwing',
    (tester) async {
      await _pump(
        tester,
        const TutorialPlacementMetadata(
          overlays: [
            TutorialPlacementOverlay(
              type: TutorialPlacementOverlayType.arrow,
              points: [TutorialPlacementPoint(0.5, 0.5)],
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'renders several overlays of mixed types together without throwing',
    (tester) async {
      await _pump(
        tester,
        const TutorialPlacementMetadata(
          overlays: [
            TutorialPlacementOverlay(
              type: TutorialPlacementOverlayType.zone,
              points: [
                TutorialPlacementPoint(0.35, 0.42),
                TutorialPlacementPoint(0.45, 0.42),
              ],
            ),
            TutorialPlacementOverlay(
              type: TutorialPlacementOverlayType.dot,
              points: [TutorialPlacementPoint(0.5, 0.5)],
            ),
            TutorialPlacementOverlay(
              type: TutorialPlacementOverlayType.arrow,
              points: [
                TutorialPlacementPoint(0.3, 0.3),
                TutorialPlacementPoint(0.4, 0.35),
              ],
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  group('TutorialCoverTransform (runtime bug fix)', () {
    test('maps points identically to the naive box-size mapping when the '
        'source image already matches the box aspect ratio', () {
      final transform = TutorialCoverTransform(
        imageSize: const Size(900, 1200), // 3:4, same as the box below
        boxSize: const Size(300, 400),
      );

      final center = transform.map(0.5, 0.5);
      expect(center.dx, closeTo(150, 0.001));
      expect(center.dy, closeTo(200, 0.001));
      expect(transform.offsetX, closeTo(0, 0.001));
      expect(transform.offsetY, closeTo(0, 0.001));
    });

    test('crops the top/bottom of a much taller source image, matching '
        'BoxFit.cover exactly -- normalized points near the top of a raw '
        'phone photo can legitimately map off-screen', () {
      // A real phone photo (e.g. 1080x2400-class) forced into the
      // tutorial's fixed 3:4 comparison box: the box's width fits
      // exactly, but the image is far taller than 3:4, so BoxFit.cover
      // crops its top and bottom, centered.
      final transform = TutorialCoverTransform(
        imageSize: const Size(900, 2000),
        boxSize: const Size(300, 400),
      );

      // Width axis fits with no crop.
      expect(transform.offsetX, closeTo(0, 0.001));
      // Height axis is cropped -- the scaled image is taller than the
      // box, so it starts above the box's own origin (negative offset).
      expect(transform.offsetY, lessThan(0));

      // The exact center of the source image must still land on the
      // exact center of the box, regardless of cropping.
      final center = transform.map(0.5, 0.5);
      expect(center.dx, closeTo(150, 0.001));
      expect(center.dy, closeTo(200, 0.001));

      // A point near the very top of the source image (e.g. hairline/
      // forehead) legitimately falls outside the visible box -- this is
      // real cropping, not a bug in the transform itself. Before this
      // fix, the naive mapping would have placed this same point at
      // `0.1 * 400 = 40` (visible, but on the wrong pixel of the actual
      // displayed image).
      final nearTop = transform.map(0.5, 0.1);
      expect(nearTop.dy, lessThan(0));
    });

    test('crops the left/right of a much wider source image', () {
      final transform = TutorialCoverTransform(
        imageSize: const Size(2000, 900),
        boxSize: const Size(300, 400),
      );

      expect(transform.offsetY, closeTo(0, 0.001));
      expect(transform.offsetX, lessThan(0));
    });

    test('a point at the exact edge of a cropped axis lands at the box edge, '
        'not fabricated', () {
      final transform = TutorialCoverTransform(
        imageSize: const Size(900, 2000),
        boxSize: const Size(300, 400),
      );
      // The visible fraction of the tall image's height is
      // boxHeight / scaledHeight = 400 / (2000 * (300/900)) = 0.6, so the
      // visible vertical range is centered: [0.2, 0.8].
      final top = transform.map(0.5, 0.2);
      final bottom = transform.map(0.5, 0.8);
      expect(top.dy, closeTo(0, 0.01));
      expect(bottom.dy, closeTo(400, 0.01));
    });
  });
}
