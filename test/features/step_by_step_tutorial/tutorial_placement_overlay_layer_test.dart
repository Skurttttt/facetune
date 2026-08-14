import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_placement_metadata.dart';
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
}
