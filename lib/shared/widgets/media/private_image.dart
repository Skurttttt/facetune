import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Displays a private FaceTune image at the resolution the layout actually
/// needs.
///
/// Selfies and generated previews are stored at up to 2048x2048. Flutter decodes
/// to full source resolution by default, which costs roughly 16 MB of raster
/// memory per image no matter how small it is drawn, so a scrolling list of them
/// exhausts memory on mid-range devices. This widget measures its own box and
/// decodes to that size instead.
///
/// The decode constraint is the box's longer side, which keeps the aspect ratio
/// intact. FaceTune images are portrait or square, so constraining the longer
/// side still fully covers the box under [BoxFit.cover]. An unusually wide
/// source could decode slightly soft; that trade is deliberate, because the
/// alternative (constraining both axes) distorts the image.
class PrivateImage extends StatelessWidget {
  const PrivateImage({
    required this.url,
    super.key,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.errorChild,
    this.decodeMultiplier = 1,
  });

  final String url;
  final BoxFit fit;
  final String? semanticLabel;

  /// Shown when the image cannot be loaded. Defaults to a broken-image tile.
  final Widget? errorChild;

  /// How many times the layout size to decode at.
  ///
  /// One is right almost everywhere: the box is the size the image is drawn,
  /// so decoding larger only wastes memory. A zoomable viewer is the exception
  /// — it draws the image into a box of one size and then magnifies it, and a
  /// decode matched to the box goes soft the moment the user pinches.
  ///
  /// Raising it is bounded rather than open-ended. `Image.network`'s
  /// [cacheWidth] resizes through `ResizeImage`, which does not upscale, so a
  /// multiplier larger than the source allows simply decodes the source at its
  /// own resolution instead of inventing pixels.
  final int decodeMultiplier;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Image.network(
      url,
      fit: fit,
      semanticLabel: semanticLabel,
      cacheWidth: switch (decodeWidthFor(context, constraints)) {
        final width? => width * decodeMultiplier,
        null => null,
      },
      frameBuilder: (context, child, frame, synchronouslyLoaded) =>
          synchronouslyLoaded || frame != null
          ? child
          : ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
      errorBuilder: (context, error, stackTrace) =>
          errorChild ??
          ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(child: Icon(Icons.broken_image_outlined)),
          ),
    ),
  );
}

/// Physical pixel width to decode an image at so it fills [constraints].
///
/// Returns null when the box is unbounded, which leaves the source resolution
/// untouched rather than guessing a size.
int? decodeWidthFor(BuildContext context, BoxConstraints constraints) {
  final longestSide = math.max(constraints.maxWidth, constraints.maxHeight);
  if (!longestSide.isFinite || longestSide <= 0) return null;
  return (longestSide * MediaQuery.devicePixelRatioOf(context)).ceil();
}

/// Physical pixel width to decode an image drawn into a known [logicalSize] box.
int decodeWidthForSize(BuildContext context, double logicalSize) =>
    (logicalSize * MediaQuery.devicePixelRatioOf(context)).ceil();
