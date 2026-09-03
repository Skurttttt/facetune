import 'package:flutter/material.dart';

/// The spinner a button shows while its action is in flight.
///
/// Sized to sit in the slot an icon would occupy, so a button does not change
/// width when it starts loading — a button that resizes mid-press moves the
/// thing under the user's finger.
///
/// It inherits the button's foreground colour rather than naming one, so it
/// stays legible on the filled, outlined and text variants alike without any of
/// them having to configure it.
class ButtonProgress extends StatelessWidget {
  const ButtonProgress({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: DefaultTextStyle.of(context).style.color,
      ),
    ),
  );
}
