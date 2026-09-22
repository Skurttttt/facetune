import '../../../features/subscription/domain/errors/subscription_error_code.dart';
import '../domain/admin_identity.dart';

/// Where the Web Admin stands with the server, as of the last server answer.
///
/// Sealed: every state the router and pages can be in is listed here, and
/// only `AdminAuthorizationController` produces them. There is no field a
/// page could set to become [AdminAuthorized]; the only path to it is a
/// successful `admin-session` response.
sealed class AdminAuthorizationState {
  const AdminAuthorizationState();

  /// True only for [AdminAuthorized]. Everything else renders no admin data.
  bool get isAuthorized => this is AdminAuthorized;

  /// True while the server has not yet answered for the current session.
  bool get isResolving => this is AdminAuthorizationPending;
}

/// Supabase is not configured for this build; the admin cannot start.
final class AdminConfigurationMissing extends AdminAuthorizationState {
  const AdminConfigurationMissing();
}

/// A server answer is outstanding. Pages must render nothing privileged.
final class AdminAuthorizationPending extends AdminAuthorizationState {
  const AdminAuthorizationPending();
}

/// No session. The login page is the only destination.
final class AdminUnauthenticated extends AdminAuthorizationState {
  const AdminUnauthenticated({this.sessionExpired = false});

  /// True when a previously valid session stopped being accepted by the
  /// server (expired, revoked token, signed out elsewhere).
  final bool sessionExpired;
}

/// A real session that the server says is not an administrator.
final class AdminUnauthorized extends AdminAuthorizationState {
  const AdminUnauthorized();
}

/// The server could not answer. Treated as not authorized until it can.
final class AdminAuthorizationFailed extends AdminAuthorizationState {
  const AdminAuthorizationFailed(this.code, {required this.retryable});

  final SubscriptionErrorCode code;
  final bool retryable;
}

/// The server verified this session as an active administrator.
final class AdminAuthorized extends AdminAuthorizationState {
  const AdminAuthorized(this.identity);

  final AdminIdentity identity;
}

/// Sign-in form feedback, kept apart from the authorization decision so a
/// failed password attempt never changes what the server has said.
enum AdminSignInStatus { idle, submitting, failed }
