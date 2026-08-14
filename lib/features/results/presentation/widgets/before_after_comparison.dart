import 'package:flutter/material.dart';

import '../../../../shared/widgets/media/comparison_slider.dart';

/// FaceTune's original final-preview comparison slider.
///
/// A thin, unchanged-behavior wrapper around the shared [ComparisonSlider]
/// mechanic (extracted in ST-5 so the tutorial feature's Placement/Result
/// slider — see `PlacementResultComparison` — can reuse the same drag/tap
/// interaction). The public API, labels ("Before"/"After"), and semantics
/// strings are exactly what they were before the extraction.
class BeforeAfterComparison extends StatelessWidget {
  const BeforeAfterComparison({
    required this.originalImageUrl,
    required this.generatedImageUrl,
    super.key,
  });

  final String originalImageUrl;
  final String generatedImageUrl;

  @override
  Widget build(BuildContext context) => ComparisonSlider(
    leftImageUrl: originalImageUrl,
    rightImageUrl: generatedImageUrl,
    leftLabel: 'Before',
    rightLabel: 'After',
    leftSemanticLabel: 'Original selfie',
    rightSemanticLabel: 'Generated makeup preview',
    semanticsLabel: 'Before and after makeup comparison',
  );
}
