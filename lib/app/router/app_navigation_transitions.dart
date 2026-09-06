import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_tokens.dart';

/// The two route-motion families used by FaceTune navigation.
abstract final class AppNavigationMotion {
  static const topLevelDuration = Duration(milliseconds: 180);
  static const journeyDuration = Duration(milliseconds: 230);
  static const journeyOffset = 10.0;
}

/// Keeps every top-level branch mounted and crossfades only their opacity.
///
/// The branch Navigators remain in one Stack, so their route stacks, page
/// States, and ScrollControllers survive ordinary tab switches. Hidden branches
/// cannot receive input or semantics, and their tickers are paused.
class TopLevelBranchContainer extends StatelessWidget {
  const TopLevelBranchContainer({
    required this.currentIndex,
    required this.children,
    super.key,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppNavigationMotion.topLevelDuration;

    return Stack(
      fit: StackFit.expand,
      children: [
        for (final (index, child) in children.indexed)
          AnimatedOpacity(
            key: ValueKey('top-level-branch-$index'),
            opacity: index == currentIndex ? 1 : 0,
            duration: duration,
            curve: AppCurves.standard,
            child: IgnorePointer(
              ignoring: index != currentIndex,
              child: ExcludeSemantics(
                excluding: index != currentIndex,
                child: TickerMode(enabled: index == currentIndex, child: child),
              ),
            ),
          ),
      ],
    );
  }
}

/// Adapter used directly by [StatefulShellRoute.navigatorContainerBuilder].
Widget buildTopLevelBranchContainer(
  BuildContext context,
  StatefulNavigationShell navigationShell,
  List<Widget> children,
) => TopLevelBranchContainer(
  currentIndex: navigationShell.currentIndex,
  children: children,
);

/// Builds one hierarchical journey page with restrained, directional motion.
CustomTransitionPage<void> buildJourneyPage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  final duration = reduceMotion
      ? Duration.zero
      : AppNavigationMotion.journeyDuration;

  return CustomTransitionPage<void>(
    key: state.pageKey,
    name: state.name,
    arguments: state.extra,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        reduceMotion
        ? child
        : JourneyPageTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            child: child,
          ),
    child: child,
  );
}

/// Exact-pixel journey motion driven only by the route's own animations.
///
/// Forward pages enter from +10dp while fading in. On pop, the page underneath
/// returns from -10dp and the outgoing page fades while moving +10dp. A small
/// secondary fade keeps the outgoing surface present instead of producing a
/// flash between opaque pages.
class JourneyPageTransition extends AnimatedWidget {
  JourneyPageTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
    super.key,
  }) : super(listenable: Listenable.merge([animation, secondaryAnimation]));

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final primary = AppCurves.standard.transform(animation.value);
    final secondary = AppCurves.standard.transform(secondaryAnimation.value);
    final returning = secondaryAnimation.status == AnimationStatus.reverse;
    final forwardOffset = AppNavigationMotion.journeyOffset * (1 - primary);
    final backOffset = returning
        ? -AppNavigationMotion.journeyOffset * secondary
        : 0.0;
    final secondaryOpacity = returning ? 1 - secondary : 1 - (secondary * 0.06);
    final opacity = (primary * secondaryOpacity).clamp(0.0, 1.0);

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(forwardOffset + backOffset, 0),
        child: child,
      ),
    );
  }
}
