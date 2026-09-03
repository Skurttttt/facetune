import 'package:flutter/material.dart';

import 'button_progress.dart';

/// A supporting action: real, but not the one the screen is asking for.
///
/// Mirrors [PrimaryButton]'s API exactly, so a screen can swap emphasis without
/// rewriting the call, and so there is one thing to learn rather than two.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.expand = true,
    this.showIcon = true,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Overrides the default glyph. Ignored when [showIcon] is false.
  final IconData? icon;

  /// Fill the available width. True by default.
  final bool expand;

  /// Draw an icon at all. See [PrimaryButton.showIcon] for why this is separate
  /// from passing `icon: null`.
  final bool showIcon;

  /// Show a spinner and refuse presses.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final child = isLoading
        ? OutlinedButton.icon(
            onPressed: null,
            icon: const ButtonProgress(),
            label: Text(label),
          )
        : showIcon
        ? OutlinedButton.icon(
            onPressed: effectiveOnPressed,
            icon: Icon(icon ?? Icons.arrow_forward_rounded),
            label: Text(label),
          )
        : OutlinedButton(onPressed: effectiveOnPressed, child: Text(label));

    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}
