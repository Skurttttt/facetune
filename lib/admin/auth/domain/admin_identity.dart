import 'admin_role.dart';

/// A server-verified administrator: the answer `admin-session` gave for the
/// caller's own session, and nothing more.
///
/// Immutable and constructible only from a server response. There is no way
/// to build one with [role] other than [AdminRole.admin]; a normal user is
/// represented by the absence of an identity, never by an identity that says
/// "not admin".
class AdminIdentity {
  const AdminIdentity({required this.userId, required this.email})
    : role = AdminRole.admin;

  final String userId;
  final String? email;
  final AdminRole role;

  /// What the shell may show for "signed in as".
  String get displayLabel => email ?? userId;
}
