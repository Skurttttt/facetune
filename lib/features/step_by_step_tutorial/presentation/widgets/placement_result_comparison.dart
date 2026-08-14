import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../domain/entities/tutorial_placement_metadata.dart';
import 'tutorial_placement_overlay_layer.dart';

/// The tutorial's Placement/Result slider (guide §3.4): the same
/// drag-reveal interaction as the existing Before/After preview slider,
/// reused via the shared [ComparisonSlider] rather than duplicated. Left =
/// placement guidance for the current step; right = the completed step.
///
/// When [placementMetadata] has overlays, they are drawn on top of the
/// placement image (ST-6) via [TutorialPlacementOverlayLayer] — instead of
/// a second AI-generated image, per the guide's V1 cost strategy.
class PlacementResultComparison extends StatelessWidget {
  const PlacementResultComparison({
    required this.placementImageUrl,
    required this.resultImageUrl,
    this.placementMetadata,
    super.key,
  });

  final String placementImageUrl;
  final String resultImageUrl;
  final TutorialPlacementMetadata? placementMetadata;

  @override
  Widget build(BuildContext context) => ComparisonSlider(
    leftImageUrl: placementImageUrl,
    rightImageUrl: resultImageUrl,
    leftLabel: 'Placement',
    rightLabel: 'Result',
    leftSemanticLabel: 'Placement guidance for this step',
    rightSemanticLabel: 'Completed result for this step',
    semanticsLabel: 'Placement and result comparison for this tutorial step',
    leftOverlay: placementMetadata == null
        ? null
        : TutorialPlacementOverlayLayer(metadata: placementMetadata!),
  );
}
