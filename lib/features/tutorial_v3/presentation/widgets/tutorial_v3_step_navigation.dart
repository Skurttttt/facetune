import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';

/// ← Previous / Next → for the tutorial.
///
/// Both are always present so the row does not reflow as the user moves
/// through the plan; the unavailable one is disabled rather than removed,
/// which also keeps the screen reader's traversal order stable.
class TutorialV3StepNavigation extends StatelessWidget {
  const TutorialV3StepNavigation({
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: TextButton.icon(
          onPressed: canGoPrevious ? onPrevious : null,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Previous'),
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: FilledButton.icon(
          onPressed: canGoNext ? onNext : null,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Next'),
        ),
      ),
    ],
  );
}
