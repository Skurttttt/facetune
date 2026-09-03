import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';

class BeforeAfterComparison extends StatefulWidget {
  const BeforeAfterComparison({
    required this.originalImageUrl,
    required this.generatedImageUrl,
    super.key,
  });

  final String originalImageUrl;
  final String generatedImageUrl;

  @override
  State<BeforeAfterComparison> createState() => _BeforeAfterComparisonState();
}

class _BeforeAfterComparisonState extends State<BeforeAfterComparison> {
  /// How far an assistive-technology nudge moves the reveal.
  ///
  /// Ten steps across the image: coarse enough to cross it without a dozen
  /// gestures, fine enough to stop where the user means to.
  static const _nudgeStep = 0.1;

  double _reveal = 0.5;

  void _updateFromPosition(double x, double width) {
    setState(() => _reveal = (x / width).clamp(0.0, 1.0));
  }

  void _nudge(double delta) {
    setState(() => _reveal = (_reveal + delta).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) => Semantics(
    // The image is the control, and now the only one. A second slider drawn
    // beneath it showed the same number twice and gave the user two things to
    // operate for one outcome.
    //
    // `onIncrease`/`onDecrease` are what make removing it safe rather than a
    // downgrade: the visible slider was carrying the adjustable actions that a
    // screen reader or switch access needs, because a horizontal drag is not
    // something those users can perform. The actions move here, onto the same
    // single [_reveal] value — no second state, no second visible control.
    label: 'Before and after makeup comparison',
    hint: 'Drag across the image to compare',
    image: true,
    slider: true,
    value: '${(_reveal * 100).round()} percent before',
    increasedValue:
        '${((_reveal + _nudgeStep).clamp(0.0, 1.0) * 100).round()} percent before',
    decreasedValue:
        '${((_reveal - _nudgeStep).clamp(0.0, 1.0) * 100).round()} percent before',
    onIncrease: () => _nudge(_nudgeStep),
    onDecrease: () => _nudge(-_nudgeStep),
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
                _ResultImage(
                  url: widget.generatedImageUrl,
                  semanticsLabel: 'Generated makeup preview',
                ),
                ClipRect(
                  clipper: _RevealClipper(_reveal),
                  child: _ResultImage(
                    url: widget.originalImageUrl,
                    semanticsLabel: 'Original selfie',
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
                const Positioned(
                  left: AppSpacing.sm,
                  top: AppSpacing.sm,
                  child: _ImageLabel('Before'),
                ),
                const Positioned(
                  right: AppSpacing.sm,
                  top: AppSpacing.sm,
                  child: _ImageLabel('After'),
                ),
                // The instruction, on the thing it is about. It used to be
                // a sentence above the image, where it competed with the
                // result for first read and still left the affordance
                // undiscoverable for anyone who skimmed past it.
                //
                // Excluded from semantics on purpose: the comparison node
                // above already carries the full hint, and a reader that
                // announced both would say the same thing twice.
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: AppSpacing.sm,
                  child: ExcludeSemantics(
                    child: Center(
                      child: _ImageLabel(
                        'Drag to compare',
                        icon: Icons.compare_arrows_rounded,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ResultImage extends StatelessWidget {
  const _ResultImage({required this.url, required this.semanticsLabel});

  final String url;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) => PrivateImage(
    url: url,
    semanticLabel: semanticsLabel,
    // Was a full `StatusState` card on a fixed `AppColors.sand` ground: a light
    // block behind a themed card, which in dark mode put a dark card on a light
    // rectangle. It also nested a whole card inside a 3:4 image box, where its
    // title and body had nowhere to go.
    //
    // The shared image-failure state fits the box it is given and stays quiet
    // about the cause, which is almost always an expired signed URL — not
    // something the user can act on, and not something to describe to them.
    errorChild: const ImageUnavailable(
      label: 'Image unavailable. Reopen this result to refresh its link.',
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
  const _ImageLabel(this.label, {this.icon});

  final String label;

  /// Optional glyph before the label. Used by the comparison hint, where the
  /// arrows say "drag" faster than the words do — but never instead of them.
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xxs + 2,
    ),
    decoration: BoxDecoration(
      // Deepened from `black54`. These labels sit over a photograph whose
      // brightness is unknowable — a blown-out highlight can sit directly
      // behind them — so the scrim, not the image, has to carry the contrast.
      //
      // Measured against the worst case of a pure-white photo underneath:
      // `black54` composites to #757575 and gives white 4.61:1, which passes AA
      // by 0.11. This composites to #525252 and gives 7.81:1. The old value was
      // not wrong so much as it had no margin, and a photo is exactly the kind
      // of ground where margin is the point.
      color: Colors.black.withValues(alpha: .68),
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: AppIconSizes.sm, color: Colors.white),
          const SizedBox(width: AppSpacing.xxs + 2),
        ],
        Flexible(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}
