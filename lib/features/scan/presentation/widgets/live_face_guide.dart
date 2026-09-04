import 'package:flutter/material.dart';

import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';

/// A framing oval drawn over the live preview.
///
/// The reduced Live Scan has no face detector, so this guide is honest about
/// what it is: an alignment aid the user positions themselves inside, not a
/// detection result. It never turns green because a face was *found* — only
/// because the measurable checks passed.
///
/// Decoration only. It is excluded from semantics: a screen-reader user cannot
/// use a drawn oval to aim a camera, and announcing it would add noise between
/// them and the guidance line that actually helps.
class LiveFaceGuide extends StatelessWidget {
  const LiveFaceGuide({required this.isReady, super.key});

  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final tone = (isReady ? AppTone.success : AppTone.info).resolve(context);
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Center(
          // A portrait ellipse, not a circle. A head is taller than it is wide,
          // and a perfect circle reads as a reticle — something that has locked
          // onto a face. Nothing here has detected anything.
          //
          // LSEP-4A also pulled it back visually: it used to be a heavy ring
          // occupying most of the frame, which competed with the face it was
          // supposed to be helping the user position.
          child: FractionallySizedBox(
            widthFactor: 0.58,
            heightFactor: 0.72,
            child: AnimatedContainer(
              duration: AppDurations.standard,
              curve: AppCurves.standard,
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.all(Radius.elliptical(1000, 1000)),
                border: Border.all(
                  // A hairline, and faint. It is an alignment hint, and it sits
                  // over the user's own face — the face should win.
                  color: tone.accent.withValues(alpha: isReady ? 0.55 : 0.34),
                  width: AppBorders.hairline,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
