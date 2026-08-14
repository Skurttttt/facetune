import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../feedback/status_state.dart';
import 'private_image.dart';

/// Generic draggable left/right image comparison, extracted from
/// FaceTune's original Before/After preview slider so the same interaction
/// can be reused with different labels and images (see
/// `BeforeAfterComparison` and `PlacementResultComparison`).
///
/// The mechanic itself is unchanged from the original: the right image
/// fills the frame, and the left image is revealed over it up to
/// [_reveal] of the width, dragged or tapped by the user.
class ComparisonSlider extends StatefulWidget {
  const ComparisonSlider({
    required this.leftImageUrl,
    required this.rightImageUrl,
    required this.leftLabel,
    required this.rightLabel,
    required this.leftSemanticLabel,
    required this.rightSemanticLabel,
    required this.semanticsLabel,
    this.leftOverlay,
    super.key,
  });

  final String leftImageUrl;
  final String rightImageUrl;
  final String leftLabel;
  final String rightLabel;
  final String leftSemanticLabel;
  final String rightSemanticLabel;

  /// Describes the whole comparison image for screen readers, e.g. "Before
  /// and after makeup comparison".
  final String semanticsLabel;

  /// Optional content stacked on top of the left image, inside the same
  /// reveal clip — so it drags/reveals in sync with the left image rather
  /// than staying fixed. `null` for the existing Before/After preview;
  /// used by the tutorial's Placement/Result slider to draw instructional
  /// overlays (ST-6) on top of the Placement image.
  final Widget? leftOverlay;

  @override
  State<ComparisonSlider> createState() => _ComparisonSliderState();
}

class _ComparisonSliderState extends State<ComparisonSlider> {
  double _reveal = 0.5;

  void _updateFromPosition(double x, double width) {
    setState(() => _reveal = (x / width).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Semantics(
        label: widget.semanticsLabel,
        image: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) => _updateFromPosition(
                  details.localPosition.dx,
                  constraints.maxWidth,
                ),
                onTapDown: (details) => _updateFromPosition(
                  details.localPosition.dx,
                  constraints.maxWidth,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ComparisonImage(
                      url: widget.rightImageUrl,
                      semanticsLabel: widget.rightSemanticLabel,
                    ),
                    ClipRect(
                      clipper: _RevealClipper(_reveal),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _ComparisonImage(
                            url: widget.leftImageUrl,
                            semanticsLabel: widget.leftSemanticLabel,
                          ),
                          if (widget.leftOverlay != null) widget.leftOverlay!,
                        ],
                      ),
                    ),
                    Positioned(
                      left: constraints.maxWidth * _reveal - 1,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 2, color: Colors.white),
                    ),
                    Positioned(
                      left: constraints.maxWidth * _reveal - 22,
                      top: constraints.maxHeight / 2 - 22,
                      child: const CircleAvatar(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.rose,
                        child: Icon(Icons.compare_arrows_rounded),
                      ),
                    ),
                    Positioned(
                      left: AppSpacing.sm,
                      top: AppSpacing.sm,
                      child: _ImageLabel(widget.leftLabel),
                    ),
                    Positioned(
                      right: AppSpacing.sm,
                      top: AppSpacing.sm,
                      child: _ImageLabel(widget.rightLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      Semantics(
        label: 'Reveal ${widget.leftLabel} or ${widget.rightLabel} image',
        value:
            '${(_reveal * 100).round()} percent ${widget.leftLabel.toLowerCase()}',
        child: Slider(
          value: _reveal,
          onChanged: (value) => setState(() => _reveal = value),
        ),
      ),
    ],
  );
}

class _ComparisonImage extends StatelessWidget {
  const _ComparisonImage({required this.url, required this.semanticsLabel});

  final String url;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) => PrivateImage(
    url: url,
    semanticLabel: semanticsLabel,
    errorChild: const ColoredBox(
      color: AppColors.sand,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: StatusState(
            title: 'Image unavailable',
            message:
                'Return and reopen this result to refresh its private link.',
            icon: Icons.broken_image_outlined,
          ),
        ),
      ),
    ),
  );
}

class _RevealClipper extends CustomClipper<Rect> {
  const _RevealClipper(this.value);

  final double value;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * value, size.height);

  @override
  bool shouldReclip(_RevealClipper oldClipper) => oldClipper.value != value;
}

class _ImageLabel extends StatelessWidget {
  const _ImageLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    child: Text(label, style: const TextStyle(color: Colors.white)),
  );
}
