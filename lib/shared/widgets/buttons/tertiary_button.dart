import 'package:flutter/material.dart';

import 'button_progress.dart';

/// A low-emphasis action: available, but not being suggested.
///
/// The rung that was missing. UI-P0 found screens dropping to a bare
/// `TextButton` whenever they needed something quieter than [SecondaryButton],
/// because the shared set offered only two levels and both forced full width and
/// an icon. A bare `TextButton` then picks up whatever the framework defaults
/// to, which is how a third, unowned button style spread across the app.
///
/// Unlike the other two this defaults to **not** expanding and **not** drawing
/// an icon, because that is what a tertiary action almost always is: a few words
/// sitting inline next to something else.
class TertiaryButton extends StatelessWidget {
  const TertiaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.expand = false,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Optional glyph. Absent by default — there is no decorative fallback here.
  final IconData? icon;

  /// Fill the available width. False by default.
  final bool expand;

  /// Show a spinner and refuse presses.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final child = isLoading
        ? TextButton.icon(
            onPressed: null,
            icon: const ButtonProgress(size: 16),
            label: Text(label),
          )
        : icon != null
        ? TextButton.icon(
            onPressed: effectiveOnPressed,
            icon: Icon(icon),
            label: Text(label),
          )
        : TextButton(onPressed: effectiveOnPressed, child: Text(label));

    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}
