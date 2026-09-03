import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../feedback/app_progress.dart';

/// The ground shown while a private image is still decoding.
///
/// A quiet filled box rather than a shimmer. FaceTune's images are the point of
/// the product — a selfie, a generated look — and animating the space where a
/// face is about to appear draws the eye to the absence. The skeleton treatment
/// is right for lists of unknown content; it is wrong here.
///
/// The spinner is excluded from semantics: these placeholders appear inside
/// [PrivateImage], which already carries the image's own `semanticLabel`, and
/// announcing "loading" over the top of that says less, not more.
class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Center(child: AppProgress(size: AppProgressSize.small)),
  );
}

/// The ground shown when a private image cannot be loaded.
///
/// Deliberately understated, and deliberately silent about *why*. The usual
/// cause is an expired signed URL, which is neither the user's fault nor
/// something they can act on from here; the screens that can offer a real
/// recovery pass their own `errorChild` with the wording and the action. Naming
/// the underlying failure would leak how storage access works and help nobody.
class ImageUnavailable extends StatelessWidget {
  const ImageUnavailable({super.key, this.label = 'Image unavailable'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: AppColors.muted(context),
              size: AppIconSizes.md,
            ),
          ),
        ),
      ),
    );
  }
}
