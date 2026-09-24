import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/presentation/admin_authorization_controller.dart';
import '../auth/presentation/admin_authorization_state.dart';
import '../auth/presentation/pages/admin_loading_page.dart';
import '../auth/presentation/pages/admin_login_page.dart';
import '../auth/presentation/pages/admin_unauthorized_page.dart';
import '../dashboard/presentation/pages/admin_dashboard_page.dart';
import '../audit/domain/admin_audit_models.dart';
import '../audit/presentation/pages/admin_audit_detail_page.dart';
import '../audit/presentation/pages/admin_audit_page.dart';
import '../audit/presentation/pages/admin_entitlement_history_page.dart';
import '../salon_pilot/presentation/pages/admin_adjust_allowance_page.dart';
import '../salon_pilot/presentation/pages/admin_grant_salon_pilot_page.dart';
import '../salon_pilot/domain/admin_salon_pilot_models.dart';
import '../salon_pilot/presentation/pages/admin_lifecycle_page.dart';
import '../entitlements/domain/admin_entitlement_models.dart';
import '../entitlements/presentation/pages/admin_entitlements_page.dart';
import '../research/presentation/pages/admin_salon_pilot_research_page.dart';
import '../shared/admin_wire.dart';
import '../shell/admin_shell.dart';
import '../usage/domain/admin_usage_models.dart';
import '../usage/presentation/pages/admin_usage_page.dart';
import '../users/presentation/pages/admin_user_detail_page.dart';
import '../users/presentation/pages/admin_users_page.dart';
import 'admin_routes.dart';

final adminRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AdminRouterRefreshNotifier();
  ref
    ..onDispose(refresh.dispose)
    ..listen<AdminAuthorizationState>(adminAuthorizationControllerProvider, (
      previous,
      next,
    ) {
      if (previous.runtimeType != next.runtimeType ||
          previous is AdminUnauthenticated && next is AdminUnauthenticated ||
          previous is AdminAuthorized &&
              next is AdminAuthorized &&
              previous.identity.userId != next.identity.userId) {
        refresh.refresh();
      }
    });

  return GoRouter(
    initialLocation: AdminRoutes.root,
    refreshListenable: refresh,
    redirect: (context, state) =>
        redirectFor(ref.read(adminAuthorizationControllerProvider), state.uri),
    routes: [
      GoRoute(
        path: AdminRoutes.login,
        builder: (context, state) => const AdminLoginPage(),
      ),
      GoRoute(
        path: AdminRoutes.loading,
        builder: (context, state) => const AdminLoadingPage(),
      ),
      GoRoute(
        path: AdminRoutes.unauthorized,
        builder: (context, state) => const AdminUnauthorizedPage(),
      ),
      // The protected frame, composed into every section route.
      //
      // Deliberately not a `ShellRoute`: that nests a second Navigator, and
      // each nested route is its own focus scope, so a keyboard user whose
      // focus sits in the section content can never Tab to the rail. One
      // Navigator keeps the rail, the identity chip, and the content in one
      // traversal order. `NoTransitionPage` keeps the frame visually fixed
      // across section changes, which is what an internal tool should do.
      for (final section in AdminSection.values)
        GoRoute(
          path: section.path,
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: AdminShell(
              child: sectionPage(section, state.uri.queryParameters),
            ),
          ),
        ),
      GoRoute(
        path: AdminRoutes.salonPilotResearch,
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const AdminShell(child: AdminSalonPilotResearchPage()),
        ),
      ),
      GoRoute(
        path: '${AdminSection.users.path}/:userId',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: AdminShell(
            child: AdminUserDetailPage(userId: state.pathParameters['userId']!),
          ),
        ),
      ),
      GoRoute(
        path: '${AdminSection.audit.path}/:eventId',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: AdminShell(
            child: AdminAuditDetailPage(
              eventId: state.pathParameters['eventId']!,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '${AdminSection.entitlements.path}/:entitlementId/history',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: AdminShell(
            child: AdminEntitlementHistoryPage(
              entitlementId: state.pathParameters['entitlementId']!,
            ),
          ),
        ),
      ),
      GoRoute(
        path:
            '${AdminSection.users.path}/:userId/${AdminRoutes.grantSalonPilotSegment}',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: AdminShell(
            child: AdminGrantSalonPilotPage(
              userId: state.pathParameters['userId']!,
            ),
          ),
        ),
      ),
      GoRoute(
        path:
            '${AdminSection.users.path}/:userId/${AdminRoutes.adjustAllowanceSegment}',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: AdminShell(
            child: AdminAdjustAllowancePage(
              userId: state.pathParameters['userId']!,
            ),
          ),
        ),
      ),
      for (final lifecycle in <(String, SalonPilotLifecycleAction)>[
        (
          AdminRoutes.extendExpirationSegment,
          SalonPilotLifecycleAction.extendExpiration,
        ),
        (
          AdminRoutes.suspendEntitlementSegment,
          SalonPilotLifecycleAction.suspend,
        ),
        (
          AdminRoutes.reactivateEntitlementSegment,
          SalonPilotLifecycleAction.reactivate,
        ),
        (
          AdminRoutes.revokeEntitlementSegment,
          SalonPilotLifecycleAction.revoke,
        ),
      ])
        GoRoute(
          path: '${AdminSection.users.path}/:userId/${lifecycle.$1}',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: AdminShell(
              child: AdminLifecyclePage(
                userId: state.pathParameters['userId']!,
                action: lifecycle.$2,
              ),
            ),
          ),
        ),
    ],
  );
});

/// The content for each delivered section. Exposed for route tests.
///
/// [query] carries the optional initial filters of the Entitlements and Usage
/// sections. Only well-formed UUIDs are honoured; anything else is ignored
/// and the section opens unfiltered.
@visibleForTesting
Widget sectionPage(
  AdminSection section, [
  Map<String, String> query = const {},
]) => switch (section) {
  AdminSection.dashboard => const AdminDashboardPage(),
  AdminSection.users => const AdminUsersPage(),
  AdminSection.entitlements => AdminEntitlementsPage(
    initialFilters: AdminEntitlementFilters(
      userId: normalizeUuid(query[AdminRoutes.userIdParameter]),
    ),
  ),
  AdminSection.usage => AdminUsagePage(
    initialFilters: AdminUsageFilters(
      userId: normalizeUuid(query[AdminRoutes.userIdParameter]),
      entitlementId: normalizeUuid(query[AdminRoutes.entitlementIdParameter]),
    ),
  ),
  AdminSection.audit => AdminAuditPage(
    initialFilters: AdminAuditFilters(
      adminUserId: normalizeUuid(query[AdminRoutes.adminUserIdParameter]),
      targetUserId: normalizeUuid(query[AdminRoutes.userIdParameter]),
      targetEntitlementId: normalizeUuid(
        query[AdminRoutes.entitlementIdParameter],
      ),
    ),
  ),
};

/// The routing decision, as a pure function of the server-derived state and
/// the requested location.
///
/// Returns the location to redirect to, or `null` to allow [uri]. Exposed so
/// it can be tested exhaustively without a widget tree.
///
/// A protected path requested before the server has answered (a browser
/// refresh on `/users`, a bookmarked deep link) is carried through the
/// loading and login pages as `?from=` and restored once the session is
/// authorized. Only exact section paths are honoured, so the parameter can
/// never send anyone outside the admin's own sections.
@visibleForTesting
String? redirectFor(AdminAuthorizationState state, Uri uri) {
  final location = uri.path;
  final isPublic = AdminRoutes.public.contains(location);
  final requested = AdminRoutes.sanitizedReturnTo(location);
  final carried = AdminRoutes.sanitizedReturnTo(
    uri.queryParameters[AdminRoutes.returnToParameter],
  );

  String withReturnTo(String target, String? returnTo) => returnTo == null
      ? target
      : Uri(
          path: target,
          queryParameters: {AdminRoutes.returnToParameter: returnTo},
        ).toString();

  return switch (state) {
    // Nothing privileged may render until the server has answered.
    AdminAuthorizationPending() =>
      location == AdminRoutes.loading
          ? null
          : withReturnTo(AdminRoutes.loading, requested ?? carried),
    AdminUnauthenticated() =>
      location == AdminRoutes.login
          ? null
          : withReturnTo(AdminRoutes.login, requested ?? carried),
    AdminUnauthorized() ||
    AdminAuthorizationFailed() ||
    AdminConfigurationMissing() =>
      location == AdminRoutes.unauthorized ? null : AdminRoutes.unauthorized,
    AdminAuthorized() =>
      isPublic
          ? (carried ?? AdminRoutes.home)
          : requested != null
          ? null
          : AdminRoutes.home,
  };
}

class _AdminRouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
