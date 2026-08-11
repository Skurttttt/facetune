import 'package:flutter/material.dart';

import '../../../../shared/widgets/feedback/status_state.dart';
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
  double _reveal = 0.5;

  void _updateFromPosition(double x, double width) {
    setState(() => _reveal = (x / width).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Semantics(
        label: 'Before and after makeup comparison',
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      Semantics(
        label: 'Reveal before or after image',
        value: '${(_reveal * 100).round()} percent before',
        child: Slider(
          value: _reveal,
          onChanged: (value) => setState(() => _reveal = value),
        ),
      ),
    ],
  );
}

class _ResultImage extends StatelessWidget {
  const _ResultImage({required this.url, required this.semanticsLabel});

  final String url;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) => Image.network(
    url,
    fit: BoxFit.cover,
    semanticLabel: semanticsLabel,
    frameBuilder: (context, child, frame, synchronouslyLoaded) {
      if (synchronouslyLoaded || frame != null) return child;
      return const ColoredBox(
        color: AppColors.sand,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    },
    errorBuilder: (context, error, stackTrace) => const ColoredBox(
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
