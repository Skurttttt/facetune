import 'package:flutter/material.dart';

import '../app/admin_routes.dart';

/// The compact context trail in the top utility bar (WA-13.5-UI-4).
///
/// Deliberately inert text, not links. A breadcrumb that navigates would be a
/// second opinion about where a path leads, and the router is the only one
/// allowed to have one; a breadcrumb that hid itself would be a second opinion
/// about what an administrator may see, and the server is the only one allowed
/// to have that. So this widget reads the location, prints it, and does
/// nothing else — no taps, no guards, no `go`.
///
/// It appears only when it says something the page does not: on a section root
/// the trail is one crumb identical to the page's own heading, so it is
/// omitted rather than duplicating it.
class AdminBreadcrumb extends StatelessWidget {
  const AdminBreadcrumb({super.key, required this.location});

  /// The current route path, from the router.
  final String location;

  /// The trail for [path], outermost first. Empty when there is nothing to
  /// add beyond the page's own title.
  static List<String> crumbsFor(String path) {
    final section = AdminSection.fromPath(path);
    if (section == null) return const [];

    // A section root needs no trail: the sidebar shows where you are and the
    // page header names it.
    if (path == section.path) return const [];

    final leaf = _leafFor(path);
    if (leaf == null) return const [];
    return [section.label, leaf];
  }

  static String? _leafFor(String path) {
    if (path == AdminRoutes.salonPilotResearch) return 'Salon Pilot research';
    if (AdminRoutes.isUserDetailPath(path)) return 'User detail';
    if (AdminRoutes.isAuditDetailPath(path)) return 'Event detail';
    if (AdminRoutes.isEntitlementHistoryPath(path)) return 'History';
    if (AdminRoutes.isUserActionPath(path)) {
      final segment = path.split('/').last;
      return switch (segment) {
        AdminRoutes.grantSalonPilotSegment => 'Grant Salon Pilot',
        AdminRoutes.adjustAllowanceSegment => 'Adjust allowance',
        AdminRoutes.extendExpirationSegment => 'Extend expiration',
        AdminRoutes.suspendEntitlementSegment => 'Suspend entitlement',
        AdminRoutes.reactivateEntitlementSegment => 'Reactivate entitlement',
        AdminRoutes.revokeEntitlementSegment => 'Revoke entitlement',
        _ => null,
      };
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final crumbs = crumbsFor(location);
    if (crumbs.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Text(
      crumbs.join('  /  '),
      key: const Key('admin-breadcrumb'),
      style: theme.textTheme.labelSmall,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}
