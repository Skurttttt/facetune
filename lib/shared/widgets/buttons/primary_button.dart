import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import 'button_progress.dart';

/// The highest-emphasis action on a screen. One per screen, ideally.
///
/// Every parameter added beyond `label`/`onPressed`/`icon` is optional and
/// defaults to the previous behaviour, so this stays a drop-in for the call
/// sites that already exist. That matters: UI-P1 is a foundation phase and must
/// not force a diff into feature code.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
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

  /// Fill the available width. True by default, which is what a screen's
  /// committing action normally wants.
  ///
  /// Set false where the button sits beside other content — inside a row, or as
  /// one of several inline choices — and a full-width block would misrepresent
  /// its importance.
  final bool expand;

  /// Draw an icon at all.
  ///
  /// The default is true, and `icon` defaulting to a decorative sparkle is why:
  /// omitting `icon` historically meant "use the sparkle", not "no icon", so
  /// there was no way to ask for a plain button. This flag is that way, without
  /// changing what omitting `icon` means for existing callers.
  final bool showIcon;

  /// Show a spinner and refuse presses.
  ///
  /// Disables the button regardless of [onPressed], so an in-flight action
  /// cannot be fired twice by an impatient double tap.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final child = isLoading
        ? FilledButton.icon(
            onPressed: null,
            icon: const ButtonProgress(),
            label: Text(label),
          )
        : showIcon
        ? FilledButton.icon(
            onPressed: effectiveOnPressed,
            icon: Icon(icon ?? Icons.auto_awesome_rounded),
            label: Text(label),
          )
        : FilledButton(onPressed: effectiveOnPressed, child: Text(label));

    // No extra Semantics wrapper: while loading the button is genuinely
    // disabled, which a screen reader already announces, and callers pair
    // `isLoading` with a label that says what is happening ("Saving…").
    // Wrapping would override the button's own label rather than add to it.
    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}

/// Fixed geometry shared by the button variants.
///
/// Not a token in `app_tokens.dart` because it is a component constant, not a
/// design scale — nothing outside a button should be reading it.
abstract final class AppButtonMetrics {
  static const minimumSize = Size(64, 56);
  static const radius = AppRadii.md;
}
