import 'admin_auth_failure.dart';
import 'admin_identity.dart';

/// Asks the server whether the current session is administrative.
///
/// The only source of admin authority in the Web Admin. Implementations call
/// the protected `admin-session` Edge Function with the session's own JWT and
/// return what it concluded; they never inspect the JWT, a local flag, or an
/// email to decide.
abstract interface class AdminSessionGateway {
  /// Resolves to the caller's identity when the server says admin; throws
  /// [AdminAuthFailure] otherwise.
  Future<AdminIdentity> verifyAdminSession();
}
