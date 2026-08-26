import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_placement_metadata.dart';
import 'package:facetune/features/step_by_step_tutorial/presentation/widgets/placement_result_comparison.dart';
import 'package:facetune/features/step_by_step_tutorial/presentation/widgets/tutorial_placement_overlay_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TutorialPlacementMetadata _metadataWithOverlays() =>
    const TutorialPlacementMetadata(
      overlays: [
        TutorialPlacementOverlay(
          type: TutorialPlacementOverlayType.zone,
          points: [
            TutorialPlacementPoint(0.3, 0.5),
            TutorialPlacementPoint(0.35, 0.55),
          ],
        ),
      ],
    );

void main() {
  testWidgets(
    'Result side never renders a Flutter overlay -- only Placement does '
    '(TF-3)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlacementResultComparison(
                placementImageUrl: 'https://signed.example/placement',
                resultImageUrl: 'https://signed.example/result',
                placementMetadata: _metadataWithOverlays(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Exactly one overlay layer exists in the whole widget tree -- there
      // is no `rightOverlay`/second overlay parameter anywhere in
      // `ComparisonSlider` for it to be duplicated onto the Result side.
      expect(find.byType(TutorialPlacementOverlayLayer), findsOneWidget);
    },
  );

  testWidgets(
    'no overlay layer exists at all when placementMetadata is absent',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlacementResultComparison(
                placementImageUrl: 'https://signed.example/placement',
                resultImageUrl: 'https://signed.example/result',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TutorialPlacementOverlayLayer), findsNothing);
    },
  );
}
