import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../utils/tutorial_labels.dart';

/// The tutorial's step navigation, as a persistent strip.
///
/// Belongs in `Scaffold.bottomNavigationBar`, never inside the scroll view and
/// never stacked over it. Until now these two buttons were the second-to-last
/// children of the page's `ListView`, which meant the only way to reach Next
/// was to scroll past the guideline, the key, the instructions and the
/// recommendation — on a step whose content is deliberately long. Worse, a
/// `ListView` builds lazily, so on a short screen the controls were not merely
/// off-screen but absent from the tree.
///
/// Placing it in the Scaffold's own slot rather than in a `Stack` is what makes
/// "no overlay" structural rather than a matter of padding: the body is
/// measured against the space left after this strip, so no scroll offset can
/// put content underneath it.
///
/// One strip serves all four cases — Standard regular, Standard final, My
/// Makeup Kit regular, My Makeup Kit final. It can, because navigation is
/// presentation: it reads two booleans and calls back. It holds no repository,
/// no controller, no session, and no product data, so sharing it between the
/// two modes shares a layout and nothing else.
///
/// Deliberately the same construction as `ResultBottomCta` — Material ground,
/// hairline top rule, `SafeArea(top: false)`, a height-hugging `Align`, and a
/// gutter-padded column capped at [PageFrame.defaultMaxWidth]. The result
/// screen and the tutorial are consecutive screens in one journey, and a
/// committing strip that changed shape between them would read as two products.
class TutorialBottomNavigation extends StatelessWidget {
  const TutorialBottomNavigation({
    required this.isLastStep,
    required this.canGoBack,
    required this.onBack,
    required this.onNext,
    required this.onFinish,
    super.key,
  });

  /// Whether the current runtime category is the last one this tutorial
  /// includes.
  ///
  /// Passed in rather than derived here, and derived by the caller from the
  /// accepted manifest's own category count. Nothing in this widget knows what
  /// a category is, which is what stops a footer from ever deciding that Lips
  /// means the end.
  final bool isLastStep;

  /// Whether there is a previous step to go back to.
  ///
  /// False on the first step, where Back is disabled rather than hidden: a
  /// control that disappears moves the one beside it, and Next moving under the
  /// user's thumb between step one and step two is worse than a dimmed button.
  final bool canGoBack;

  /// Previous tutorial category. Distinct from the top-bar close, which leaves
  /// the tutorial altogether.
  final VoidCallback onBack;

  final VoidCallback onNext;

  /// Existing completion behaviour, unchanged: the caller still decides what
  /// finishing means.
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: DecoratedBox(
        // Outside the safe area and outside the gutter, so the rule runs edge
        // to edge and reads as the boundary of the screen rather than as a
        // divider between two pieces of content.
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.dividerTheme.color ?? theme.dividerColor,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          // Not `PageFrame`: its `Center` expands to whatever height it is
          // offered, and in this slot that is the whole screen.
          // `heightFactor: 1` makes the strip hug its buttons.
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1,
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: PageFrame.defaultMaxWidth,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
                vertical: AppSpacing.sm,
              ),
              child: _controls(),
            ),
          ),
        ),
      ),
    );
  }

  /// Side by side, or stacked once they cannot share a line.
  ///
  /// The rule is carried over unchanged from where these buttons used to live,
  /// so a narrow screen and a large text size still get two full-width rows
  /// rather than two squeezed ones. `MainAxisSize.min` matters here in a way it
  /// did not inside the list: this slot offers the full screen height, and a
  /// `Column` that took it would push the tutorial off the top.
  Widget _controls() => LayoutBuilder(
    builder: (context, constraints) {
      final back = SecondaryButton(
        label: TutorialLabels.back,
        icon: Icons.arrow_back_rounded,
        onPressed: canGoBack ? onBack : null,
      );
      final next = PrimaryButton(
        label: isLastStep ? TutorialLabels.finish_ : TutorialLabels.next,
        icon: isLastStep ? Icons.check_rounded : Icons.arrow_forward_rounded,
        onPressed: isLastStep ? onFinish : onNext,
      );
      final scaledBodySize = MediaQuery.textScalerOf(context).scale(14);
      if (constraints.maxWidth < 360 || scaledBodySize > 20) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            back,
            const SizedBox(height: AppSpacing.xs),
            next,
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: back),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: next),
        ],
      );
    },
  );
}
