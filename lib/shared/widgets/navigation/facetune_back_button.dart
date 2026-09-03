import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import 'facetune_nav_metrics.dart';

/// FaceTune's route-back control.
///
/// Presentation only, and deliberately so. It replaces how backward navigation
/// *looks* — a circular, theme-aware surface instead of a bare Material glyph —
/// while leaving what it *does* exactly where it was. With no [onPressed] it
/// calls `Navigator.maybePop`, which is precisely what the framework's own
/// `BackButton` calls, so swapping one for the other cannot change where a user
/// ends up or how the Android system back gesture behaves.
///
/// Use this for genuine backward movement in the route stack. A full-screen
/// viewer, a sheet or a dialog is dismissed, not navigated back from, and keeps
/// its close cross: making the two look alike would tell the user they do the
/// same thing when they do not.
class FaceTuneBackButton extends StatelessWidget {
  const FaceTuneBackButton({
    super.key,
    this.onPressed,
    this.semanticsLabel = defaultSemanticsLabel,
  });

  /// The label every instance announces unless a screen has a better word.
  static const defaultSemanticsLabel = 'Back';

  /// Where back goes. Omit to keep the framework default.
  final VoidCallback? onPressed;

  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The app separates surfaces with a hairline and a tint rather than a
    // shadow, so this reads the same two theme values every other bounded
    // surface does — and inherits both themes for free instead of hardcoding a
    // light-mode ring that disappears on a dark ground.
    final border = theme.dividerTheme.color ?? theme.dividerColor;
    final foreground =
        theme.appBarTheme.iconTheme?.color ?? theme.colorScheme.onSurface;

    // Merged into a single node so the control announces itself once, as a
    // button labelled "Back", with the tap action attached. The label is
    // stated here rather than left to a tooltip: a tooltip is a pointer
    // affordance, and this app is used with a finger and a screen reader.
    return MergeSemantics(
      child: Semantics(
        button: true,
        label: semanticsLabel,
        child: SizedBox.square(
          dimension: FaceTuneNavMetrics.touchTarget,
          child: Material(
            color: theme.colorScheme.surfaceContainerHighest,
            shape: CircleBorder(
              side: BorderSide(color: border, width: AppBorders.hairline),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed ?? () => Navigator.maybePop(context),
              child: Center(
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: FaceTuneNavMetrics.iconSize,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
