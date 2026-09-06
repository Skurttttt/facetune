import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';

/// One tab in the app shell.
///
/// A record of the route and its presentation, so the destinations are data
/// rather than a list literal buried in a callback. `AppShell.destinations` is
/// public specifically so a test can assert the routes and their order are
/// unchanged — this file is presentation, and it must never become the place
/// navigation quietly moves.
typedef AppDestination = ({
  String route,
  IconData icon,
  IconData selectedIcon,
  String label,
});

/// The persistent bottom navigation the four top-level screens sit in.
class AppShell extends StatelessWidget {
  const AppShell({
    required this.child,
    required this.index,
    super.key,
    this.onDestinationSelected,
  });

  final Widget child;
  final int index;
  final ValueChanged<int>? onDestinationSelected;

  /// The tabs, in order. Order is the contract: [index] is a position in this
  /// list, and every caller passes a literal.
  static const List<AppDestination> destinations = [
    (
      route: AppConstants.homeRoute,
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    ),
    (
      route: AppConstants.savedRoute,
      icon: Icons.favorite_border_rounded,
      selectedIcon: Icons.favorite_rounded,
      label: 'Saved',
    ),
    (
      route: AppConstants.historyRoute,
      // Previously the only destination with no selected variant, so its icon
      // did not change on selection and the state was carried by the indicator
      // pill alone. The filled counterpart of the same glyph keeps selection
      // legible without relying on a single background tint.
      icon: Icons.history_outlined,
      selectedIcon: Icons.history_rounded,
      label: 'History',
    ),
    (
      route: AppConstants.profileRoute,
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Top-level pages historically wrapped themselves in AppShell. Keep those
    // call sites harmless when the router's persistent shell is already above
    // them, while preserving direct page/widget-test presentation.
    if (_AppShellScope.maybeOf(context)) return child;

    return _AppShellScope(
      child: Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          // Labels always shown. Hiding the unselected ones saves a few points of
          // height and costs every user who does not recognise the glyph — and
          // three of these four are ambiguous without their word.
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected:
              onDestinationSelected ??
              (value) => context.go(destinations[value].route),
          destinations: [
            for (final destination in destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
                tooltip: destination.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _AppShellScope extends InheritedWidget {
  const _AppShellScope({required super.child});

  static bool maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_AppShellScope>() != null;

  @override
  bool updateShouldNotify(_AppShellScope oldWidget) => false;
}
