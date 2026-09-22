import 'package:flutter/material.dart';

/// The administrative sections of the Web Admin, in navigation order.
///
/// Each later phase owns one section's data: WA-4 Dashboard, WA-5 Users,
/// WA-6 Entitlements and Usage, WA-10 Audit. Until then a section is a safe
/// route destination with a placeholder and nothing else.
enum AdminSection {
  dashboard(
    path: '/dashboard',
    label: 'Dashboard',
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard,
    summary: 'Operational overview of entitlements and usage.',
    arrivesIn: 'WA-4',
  ),
  users(
    path: '/users',
    label: 'Users',
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    summary: 'Find an account and see its current plan.',
    arrivesIn: 'WA-5',
  ),
  entitlements(
    path: '/entitlements',
    label: 'Entitlements',
    icon: Icons.verified_user_outlined,
    selectedIcon: Icons.verified_user,
    summary: 'Every entitlement: plan, status, provider, and allowance.',
    arrivesIn: 'WA-6',
  ),
  usage(
    path: '/usage',
    label: 'Usage',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    summary: 'AI Look ledger: reserved, committed, released.',
    arrivesIn: 'WA-6',
  ),
  audit(
    path: '/audit',
    label: 'Audit',
    icon: Icons.history_outlined,
    selectedIcon: Icons.history,
    summary: 'Who changed what, when, and why.',
    arrivesIn: 'WA-10',
  );

  const AdminSection({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.summary,
    required this.arrivesIn,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// One sentence for the placeholder; never a number, never a fake stat.
  final String summary;

  /// The phase that owns this section's data.
  final String arrivesIn;

  /// The section whose path is [path], or `null`.
  static AdminSection? fromPath(String path) {
    if (AdminRoutes.isUserDetailPath(path) ||
        AdminRoutes.isUserActionPath(path)) {
      return AdminSection.users;
    }
    for (final section in values) {
      if (section.path == path) return section;
    }
    return null;
  }
}

/// Route table of the Web Admin. Routes are navigation, not security: every
/// destination below `/` is gated by the router redirect, which consults only
/// the server-derived authorization state.
abstract final class AdminRoutes {
  static const String root = '/';
  static const String login = '/login';
  static const String loading = '/loading';
  static const String unauthorized = '/unauthorized';

  /// Query parameter carrying the protected path to return to after the
  /// server has answered. Only exact section paths are ever honoured.
  static const String returnToParameter = 'from';

  /// Reachable without an authorized admin session.
  static const Set<String> public = {login, loading, unauthorized};

  /// The landing section for an authorized admin.
  static String get home => AdminSection.dashboard.path;

  static final RegExp _userDetailPattern = RegExp(
    r'^/users/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static String userDetail(String userId) => '/users/$userId';

  /// WA-7: the Salon Pilot grant workflow for one account.
  static const String grantSalonPilotSegment = 'grant-salon-pilot';

  /// WA-8: the Salon Pilot allowance adjustment workflow for one account.
  static const String adjustAllowanceSegment = 'adjust-allowance';

  /// WA-9: the four Salon Pilot lifecycle workflows for one account.
  static const String extendExpirationSegment = 'extend-expiration';
  static const String suspendEntitlementSegment = 'suspend-entitlement';
  static const String reactivateEntitlementSegment = 'reactivate-entitlement';
  static const String revokeEntitlementSegment = 'revoke-entitlement';

  /// The per-account privileged workflows under `/users/:userId/…`.
  static final RegExp _userActionPattern = RegExp(
    r'^/users/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/(grant-salon-pilot|adjust-allowance|extend-expiration|suspend-entitlement|reactivate-entitlement|revoke-entitlement)$',
  );

  static String grantSalonPilot(String userId) =>
      '/users/$userId/$grantSalonPilotSegment';

  static String adjustAllowance(String userId) =>
      '/users/$userId/$adjustAllowanceSegment';

  static String extendExpiration(String userId) =>
      '/users/$userId/$extendExpirationSegment';

  static String suspendEntitlement(String userId) =>
      '/users/$userId/$suspendEntitlementSegment';

  static String reactivateEntitlement(String userId) =>
      '/users/$userId/$reactivateEntitlementSegment';

  static String revokeEntitlement(String userId) =>
      '/users/$userId/$revokeEntitlementSegment';

  /// Whether [path] is one of the per-account privileged workflows.
  static bool isUserActionPath(String path) =>
      _userActionPattern.hasMatch(path);

  static bool isGrantSalonPilotPath(String path) =>
      isUserActionPath(path) && path.endsWith('/$grantSalonPilotSegment');

  static bool isLifecyclePath(String path) =>
      isUserActionPath(path) &&
      (path.endsWith('/$extendExpirationSegment') ||
          path.endsWith('/$suspendEntitlementSegment') ||
          path.endsWith('/$reactivateEntitlementSegment') ||
          path.endsWith('/$revokeEntitlementSegment'));

  /// Query parameters the Entitlements and Usage sections accept as initial
  /// filters (WA-6). They are filters, not authority: the server re-checks
  /// the caller and validates every value.
  static const String userIdParameter = 'userId';
  static const String entitlementIdParameter = 'entitlementId';

  static String entitlementsForUser(String userId) => Uri(
    path: AdminSection.entitlements.path,
    queryParameters: {userIdParameter: userId},
  ).toString();

  static String usageForUser(String userId) => Uri(
    path: AdminSection.usage.path,
    queryParameters: {userIdParameter: userId},
  ).toString();

  static String usageForEntitlement(String entitlementId) => Uri(
    path: AdminSection.usage.path,
    queryParameters: {entitlementIdParameter: entitlementId},
  ).toString();

  static bool isUserDetailPath(String path) =>
      _userDetailPattern.hasMatch(path);

  /// [path] if it is a section an admin may be returned to, else `null`.
  static String? sanitizedReturnTo(String? path) =>
      path != null &&
          (AdminSection.values.any((section) => section.path == path) ||
              isUserDetailPath(path) ||
              isUserActionPath(path))
      ? path
      : null;
}
