import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';

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
  Widget build(BuildContext context) {
    return PrimaryButton(
      label: isLoading ? 'Please wait…' : label,
      icon: icon,
      onPressed: isLoading ? null : onPressed,
    );
  }
}
