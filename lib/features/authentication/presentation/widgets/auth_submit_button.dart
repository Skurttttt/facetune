import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';

/// The commit action on an auth form.
///
/// Now shows a spinner in place of its icon while the request is in flight,
/// rather than replacing the label with "Please wait…". Keeping the label means
/// the button still says what it is doing at the moment the user most wants to
/// know — "Create account" with a spinner reads as *this* action running, where
/// "Please wait…" reads as the app having forgotten what was asked of it.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    super.key,
    this.icon = Icons.arrow_forward_rounded,
    this.loadingLabel,
  });

  final String label;
  final bool isLoading;

  /// Null disables the button, as it does for [PrimaryButton].
  final VoidCallback? onPressed;
  final IconData icon;

  /// What the button says while [isLoading] — the same action in progress
  /// ("Signing in…"), never a generic "Please wait…". Defaults to [label].
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) => PrimaryButton(
    label: isLoading ? loadingLabel ?? label : label,
    icon: icon,
    // PrimaryButton disables itself while loading, so a double tap cannot fire
    // a second registration.
    isLoading: isLoading,
    onPressed: onPressed,
  );
}
