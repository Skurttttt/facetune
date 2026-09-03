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
  });

  final String label;
  final bool isLoading;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => PrimaryButton(
    label: label,
    icon: icon,
    // PrimaryButton disables itself while loading, so a double tap cannot fire
    // a second registration.
    isLoading: isLoading,
    onPressed: onPressed,
  );
}
