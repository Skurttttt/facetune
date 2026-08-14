import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';

/// The additive CTA that opens the Step-by-Step Tutorial for an already
/// generated look. Used from both the standard result page and the My
/// Makeup Kit result page — see ARCHITECTURE_NOTES.md's ST-4 section for
/// why a single shared button covers Saved Looks and History too.
class HowToApplyLookButton extends StatelessWidget {
  const HowToApplyLookButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SecondaryButton(
    label: 'How to Apply This Look',
    icon: Icons.auto_stories_outlined,
    onPressed: onPressed,
  );
}
