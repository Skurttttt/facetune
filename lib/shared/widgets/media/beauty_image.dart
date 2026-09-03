import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import 'private_image.dart';

/// The bundled brand portrait.
///
/// **This is a placeholder.** `assets/images/beauty_portrait.png` is a ~2 MB
/// stock photograph standing in for brand art on the entry screen — the first
/// thing a new user ever sees. Replacing it needs an asset decision rather than
/// a code change, so UI-P1 leaves the image alone and only fixes how it is
/// decoded. Tracked for UI-P3.
///
/// The decode budget matters here even for one image: at 2048px source drawn
/// into a 250pt box, Flutter's default full-resolution decode costs roughly
/// 16 MB of raster memory to show a quarter-megapixel of pixels. [PrivateImage]
/// already solved this for network images; this applies the same measurement to
/// the bundled one.
class BeautyImage extends StatelessWidget {
  const BeautyImage({
    super.key,
    this.height = 260,
    this.radius = AppRadii.lg,
    this.alignment = Alignment.center,
    this.overlay,
  });
  final double height;
  final double radius;
  final Alignment alignment;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/beauty_portrait.png',
              fit: BoxFit.cover,
              alignment: alignment,
              cacheWidth: decodeWidthFor(context, constraints),
            ),
            ?overlay,
          ],
        ),
      ),
    ),
  );
}
