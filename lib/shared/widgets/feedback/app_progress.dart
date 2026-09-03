import 'package:flutter/material.dart';

/// How much room a spinner has.
enum AppProgressSize {
  /// Inside a control, a list row, or a card corner.
  small(18, 2),

  /// A pagination footer, or a small region loading on its own.
  medium(24, 2.5),

  /// The focus of the screen. Usually reached through [LoadingState] rather
  /// than directly.
  large(36, 3);

  const AppProgressSize(this.dimension, this.stroke);

  final double dimension;
  final double stroke;
}

/// An indeterminate spinner.
///
/// FaceTune had three unrelated loading languages and this is the smallest of
/// them: twelve hand-rolled `CircularProgressIndicator`s across the feature
/// layer, most at `strokeWidth: 2`, one at the framework default, one hardcoded
/// white. Same idea, four appearances.
///
/// **Indeterminate only, by design.** There is no `value` parameter, because
/// the work this app waits on — a Gemini generation, a signed-URL fetch — reports
/// no progress. A bar that fills at a rate someone invented is a lie about how
/// long the wait will be, and the loading rules for this phase forbid it.
/// Genuine determinate progress belongs on [LoadingState], which takes a real
/// value or none at all.
class AppProgress extends StatelessWidget {
  const AppProgress({
    super.key,
    this.size = AppProgressSize.medium,
    this.color,
    this.semanticLabel,
  });

  final AppProgressSize size;

  /// Overrides the theme's indicator colour. Needed only where the spinner sits
  /// on a fixed ground the theme does not know about — over a photograph, say.
  final Color? color;

  /// What a screen reader announces.
  ///
  /// Usually null: a spinner beside its own explanatory text would otherwise be
  /// announced twice. Set it where the spinner is alone on screen and silence
  /// would leave the user with nothing.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final indicator = SizedBox.square(
      dimension: size.dimension,
      child: CircularProgressIndicator(strokeWidth: size.stroke, color: color),
    );

    if (semanticLabel == null) return ExcludeSemantics(child: indicator);
    return Semantics(
      container: true,
      liveRegion: true,
      label: semanticLabel,
      child: ExcludeSemantics(child: indicator),
    );
  }
}
