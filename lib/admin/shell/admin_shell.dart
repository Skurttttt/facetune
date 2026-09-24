import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/admin_routes.dart';
import '../theme/admin_theme.dart';
import '../theme/admin_tokens.dart';
import 'admin_breadcrumb.dart';
import 'admin_sidebar.dart';
import '../auth/presentation/admin_authorization_controller.dart';
import '../auth/presentation/admin_authorization_state.dart';

/// The protected application frame: section navigation, identity, sign-out,
/// and the current section's content.
///
/// Reached only through the router's authorized branch, and defensive about
/// it: in any other state it renders an empty frame, so a routing mistake
/// can never show the shell's controls to an unauthorized visitor. The shell
/// itself fetches nothing; every section owns its data through its phase
/// that owns its data.
///
/// Desktop-first. At [wideBreakpoint] and above the navigation is an
/// extended rail with labels; between [compactBreakpoint] and that it is a
/// compact rail; below it the navigation moves into a drawer behind the app
/// bar so a narrow window stays usable. Nothing animates beyond Material's
/// own focus and selection feedback.
///
/// WA-13.5-UI-2 fixed the frame's measurements and scroll ownership. The
/// shell owns exactly one scroll direction — vertical, for the section's
/// content — and never scrolls horizontally: a wide operational table brings
/// its own horizontal scroll inside its own container, so the page itself can
/// never slide sideways and strand the right-hand action column.
///
/// The sidebar and the top utility bar are frame furniture: they keep their
/// place while the content scrolls beneath them. Detailed sidebar and header
/// design belong to UI-3 and UI-4; UI-2 only sizes and colours the regions.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  static const double wideBreakpoint = 1100;
  static const double compactBreakpoint = 760;

  /// Expanded sidebar width (UI SOT section 11).
  static const double sidebarWidth = AdminShellMetrics.expandedWidth;

  /// Top utility bar height (UI SOT section 11).
  static const double topBarHeight = AdminShellMetrics.topBarHeight;

  /// The readable column for dashboards, detail pages and forms (UI SOT
  /// section 11). Operational tables stretch to this width and then scroll
  /// inside themselves rather than widening the page.
  static const double maxContentWidth = AdminShellMetrics.maxContentWidth;

  /// The inset from the frame to the section's content, by viewport width
  /// (UI SOT section 12).
  ///
  /// A single flat inset at every width was one of the defects UI-0 recorded:
  /// 24px is cramped on a 1920px display and wasteful at 800px.
  @visibleForTesting
  static double contentInsetFor(double width) {
    if (width >= 1440) return AdminSpacing.xxl; // 40
    if (width >= 1200) return AdminSpacing.xl; // 32
    if (width >= 1024) return AdminSpacing.lg; // 24
    if (width >= compactBreakpoint) return AdminSpacing.ml; // 20
    return AdminSpacing.md; // 16
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminAuthorizationControllerProvider);
    if (state is! AdminAuthorized) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final location = GoRouterState.of(context).uri.path;
    final selected = AdminSection.fromPath(location);
    final width = MediaQuery.sizeOf(context).width;
    final signOut = ref
        .read(adminAuthorizationControllerProvider.notifier)
        .signOut;

    void go(AdminSection section) {
      if (section.path != location) context.go(section.path);
    }

    final identity = _IdentityChip(
      label: state.identity.displayLabel,
      onSignOut: signOut,
    );

    final inset = contentInsetFor(width);
    final semantics = AdminSemanticColors.of(context);

    if (width < compactBreakpoint) {
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: topBarHeight,
          backgroundColor: semantics.surface,
          title: const _ProductName(),
          actions: [
            identity,
            const SizedBox(width: AdminSpacing.xs),
          ],
        ),
        drawer: NavigationDrawer(
          key: const Key('admin-nav-drawer'),
          backgroundColor: semantics.sidebarBackground,
          selectedIndex: selected?.index,
          onDestinationSelected: (index) {
            Navigator.of(context).pop();
            go(AdminSection.values[index]);
          },
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AdminSpacing.lg,
                AdminSpacing.md,
                AdminSpacing.lg,
                AdminSpacing.xs,
              ),
              child: _ProductName(),
            ),
            for (final section in AdminSection.values)
              NavigationDrawerDestination(
                key: Key('admin-nav-${section.name}'),
                icon: Icon(section.icon),
                selectedIcon: Icon(section.selectedIcon),
                label: Text(section.label),
              ),
          ],
        ),
        body: _Content(inset: inset, child: child),
      );
    }

    final extended = width >= wideBreakpoint;
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FocusTraversalGroup(
            child: Semantics(
              container: true,
              label: 'Admin sections',
              child: AdminSidebar(
                key: const Key('admin-nav-rail'),
                selected: selected,
                extended: extended,
                onSelect: go,
              ),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(location: location, trailing: identity),
                const Divider(height: 1, thickness: 1),
                Expanded(
                  child: _Content(inset: inset, child: child),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The global utility bar: context on the left, who you are and the way out
/// on the right.
///
/// It carries no page heading. Before UI-4 it repeated the section's name,
/// which the page already rendered as its own title — two headings for one
/// page. Now it shows the breadcrumb only where the trail says something the
/// page title does not.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.location, required this.trailing});

  final String location;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: AdminShell.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.lg),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          Expanded(child: AdminBreadcrumb(location: location)),
          trailing,
        ],
      ),
    );
  }
}

/// The section's content region.
///
/// Owns the frame's only scroll: one vertical [SingleChildScrollView]. There
/// is deliberately no horizontal scroll here — a table that is wider than the
/// column scrolls inside its own container, so the page never slides sideways
/// and the rightmost action column stays where the administrator left it.
class _Content extends StatelessWidget {
  const _Content({required this.inset, required this.child});

  /// The viewport-dependent inset from the frame, see
  /// [AdminShell.contentInsetFor].
  final double inset;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: Semantics(
        container: true,
        label: 'Section content',
        // Sections grow downward; the frame (rail, top bar) never scrolls.
        child: SingleChildScrollView(
          key: const Key('admin-content-scroll'),
          primary: true,
          padding: EdgeInsets.all(inset),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              key: const Key('admin-content-column'),
              constraints: const BoxConstraints(
                maxWidth: AdminShell.maxContentWidth,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _IdentityChip extends StatelessWidget {
  const _IdentityChip({required this.label, required this.onSignOut});

  final String label;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.account_circle_outlined,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AdminSpacing.xs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(
            label,
            key: const Key('admin-identity'),
            style: theme.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AdminSpacing.sm),
        TextButton.icon(
          key: const Key('admin-sign-out'),
          onPressed: onSignOut,
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}

class _ProductName extends StatelessWidget {
  const _ProductName();

  @override
  Widget build(BuildContext context) {
    return Text(
      'FaceTune Admin',
      style: Theme.of(context).textTheme.titleMedium,
      overflow: TextOverflow.ellipsis,
    );
  }
}
