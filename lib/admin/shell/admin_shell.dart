import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_tokens.dart';
import '../app/admin_routes.dart';
import '../auth/presentation/admin_authorization_controller.dart';
import '../auth/presentation/admin_authorization_state.dart';

/// The protected application frame: section navigation, identity, sign-out,
/// and the current section's content.
///
/// Reached only through the router's authorized branch, and defensive about
/// it: in any other state it renders an empty frame, so a routing mistake
/// can never show the shell's controls to an unauthorized visitor. The shell
/// itself fetches nothing; every section is a placeholder until the phase
/// that owns its data.
///
/// Desktop-first. At [wideBreakpoint] and above the navigation is an
/// extended rail with labels; between [compactBreakpoint] and that it is a
/// compact rail; below it the navigation moves into a drawer behind the app
/// bar so a narrow window stays usable. Nothing animates beyond Material's
/// own focus and selection feedback.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  static const double wideBreakpoint = 1100;
  static const double compactBreakpoint = 760;

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

    if (width < compactBreakpoint) {
      return Scaffold(
        appBar: AppBar(
          title: const _ProductName(),
          actions: [
            identity,
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
        drawer: NavigationDrawer(
          key: const Key('admin-nav-drawer'),
          selectedIndex: selected?.index,
          onDestinationSelected: (index) {
            Navigator.of(context).pop();
            go(AdminSection.values[index]);
          },
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xs,
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
        body: _Content(child: child),
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
              child: NavigationRail(
                key: const Key('admin-nav-rail'),
                extended: extended,
                minExtendedWidth: 220,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                selectedIndex: selected?.index,
                onDestinationSelected: (index) =>
                    go(AdminSection.values[index]),
                leading: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                    horizontal: AppSpacing.xs,
                  ),
                  child: extended ? const _ProductName() : const _ProductMark(),
                ),
                destinations: [
                  for (final section in AdminSection.values)
                    NavigationRailDestination(
                      icon: Icon(
                        section.icon,
                        key: Key('admin-nav-${section.name}'),
                      ),
                      selectedIcon: Icon(
                        section.selectedIcon,
                        key: Key('admin-nav-${section.name}'),
                      ),
                      label: Text(section.label),
                    ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(section: selected, trailing: identity),
                const Divider(height: 1, thickness: 1),
                Expanded(child: _Content(child: child)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.section, required this.trailing});

  final AdminSection? section;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                section?.label ?? 'FaceTune Admin',
                key: const Key('admin-section-title'),
                style: theme.textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: Semantics(
        container: true,
        label: 'Section content',
        // Sections grow downward; the frame (rail, top bar) never scrolls.
        child: SingleChildScrollView(
          primary: true,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
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
        const SizedBox(width: AppSpacing.xs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(
            label,
            key: const Key('admin-identity'),
            style: theme.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
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

class _ProductMark extends StatelessWidget {
  const _ProductMark();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'FaceTune Admin',
      child: Icon(
        Icons.admin_panel_settings_outlined,
        semanticLabel: 'FaceTune Admin',
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
