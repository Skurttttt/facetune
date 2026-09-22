import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_availability_provider.dart';
import '../../../features/authentication/data/providers/auth_repository_provider.dart';
import '../../../features/authentication/domain/entities/auth_event.dart';
import '../../../features/authentication/domain/errors/auth_failure.dart';
import '../../../features/authentication/domain/repositories/auth_repository.dart';
import '../../../features/subscription/domain/errors/subscription_error_code.dart';
import '../data/admin_session_gateway_provider.dart';
import '../domain/admin_auth_failure.dart';
import '../domain/admin_session_gateway.dart';
import 'admin_authorization_state.dart';

final adminAuthorizationControllerProvider =
    StateNotifierProvider<
      AdminAuthorizationController,
      AdminAuthorizationState
    >((ref) {
      return AdminAuthorizationController(
        authRepository: ref.watch(authRepositoryProvider),
        gateway: ref.watch(adminSessionGatewayProvider),
        isSupabaseAvailable: ref.watch(supabaseAvailableProvider),
      );
    });

/// Sign-in form state, separate from the authorization decision.
final adminSignInStatusProvider =
    StateNotifierProvider<AdminSignInStatusController, AdminSignInState>(
      (ref) => AdminSignInStatusController(),
    );

class AdminSignInState {
  const AdminSignInState(this.status, {this.errorMessage});

  final AdminSignInStatus status;
  final String? errorMessage;

  bool get isSubmitting => status == AdminSignInStatus.submitting;
}

class AdminSignInStatusController extends StateNotifier<AdminSignInState> {
  AdminSignInStatusController()
    : super(const AdminSignInState(AdminSignInStatus.idle));

  void submitting() =>
      state = const AdminSignInState(AdminSignInStatus.submitting);

  void failed(String message) =>
      state = AdminSignInState(AdminSignInStatus.failed, errorMessage: message);

  void reset() => state = const AdminSignInState(AdminSignInStatus.idle);
}

/// Owns the Web Admin's authorization state.
///
/// Authentication (who is signed in) comes from the existing FaceTune
/// [AuthRepository] — the same Supabase Auth the consumer app uses, so no
/// second auth system exists. Authorization (is this an admin) comes only
/// from [AdminSessionGateway], i.e. from the server, and is re-asked:
///
///   * at start-up, when a persisted session exists;
///   * after every sign-in;
///   * on every token refresh, so a revocation takes effect within the
///     token lifetime without a new build or a manual reload;
///   * on demand via [refresh].
///
/// A sign-out, an expired session, or a server refusal all leave the state
/// with no identity. Nothing in this class reads a local flag, an email, or a
/// JWT claim to decide.
class AdminAuthorizationController
    extends StateNotifier<AdminAuthorizationState> {
  AdminAuthorizationController({
    required AuthRepository authRepository,
    required AdminSessionGateway gateway,
    required bool isSupabaseAvailable,
  }) : _authRepository = authRepository,
       _gateway = gateway,
       super(
         isSupabaseAvailable
             ? const AdminAuthorizationPending()
             : const AdminConfigurationMissing(),
       ) {
    if (!isSupabaseAvailable) return;
    _subscription = _authRepository.authEvents.listen(
      (event) => unawaited(_handleAuthEvent(event)),
      onError: (Object _) {},
    );
    unawaited(_resolveInitialSession());
  }

  final AuthRepository _authRepository;
  final AdminSessionGateway _gateway;
  StreamSubscription<AuthEvent>? _subscription;
  int _generation = 0;

  Future<void> _resolveInitialSession() async {
    if (_authRepository.currentUser == null) {
      state = const AdminUnauthenticated();
      return;
    }
    await _verify();
  }

  Future<void> _handleAuthEvent(AuthEvent event) async {
    switch (event.type) {
      case AuthEventType.signedOut:
        _generation++;
        // Keep the "session expired" explanation when the sign-out is the
        // one this controller itself issued after the server refused the
        // session; only a fresh sign-out replaces it.
        if (state is! AdminUnauthenticated) {
          state = const AdminUnauthenticated();
        }
      case AuthEventType.signedIn:
      case AuthEventType.initialSession:
      case AuthEventType.tokenRefreshed:
      case AuthEventType.userUpdated:
        if (event.user == null) {
          if (state is! AdminUnauthenticated) {
            state = const AdminUnauthenticated();
          }
          return;
        }
        await _verify();
      case AuthEventType.passwordRecovery:
        // Not an admin flow. The consumer app owns password recovery.
        break;
    }
  }

  /// Signs in with the project's email/password auth, then asks the server
  /// whether the resulting session is administrative. A successful password
  /// never by itself authorizes anything.
  Future<void> signInWithEmail({
    required String email,
    required String password,
    required AdminSignInStatusController signIn,
  }) async {
    signIn.submitting();
    try {
      await _authRepository.signInWithEmail(email: email, password: password);
      signIn.reset();
      // The signedIn event also triggers a verify; the generation guard makes
      // whichever finishes second a no-op.
      await _verify();
    } on AuthFailure catch (failure) {
      signIn.failed(failure.message);
    } catch (_) {
      signIn.failed('Sign-in failed. Please try again.');
    }
  }

  /// Re-asks the server. Used by the retry action after a backend failure and
  /// by later phases when a protected call answers 401/403 mid-session.
  Future<void> refresh() => _verify();

  Future<void> signOut() async {
    _generation++;
    try {
      await _authRepository.signOut();
    } finally {
      state = const AdminUnauthenticated();
    }
  }

  /// Called by later phases when a protected server call answers
  /// [SubscriptionErrorCode.authRequired] or
  /// [SubscriptionErrorCode.adminUnauthorized] mid-session: the server's
  /// latest word wins immediately, before any re-verification round-trip.
  void handleServerRefusal(AdminAuthFailure failure) {
    if (failure.isUnauthenticated) {
      _generation++;
      state = const AdminUnauthenticated(sessionExpired: true);
      unawaited(_authRepository.signOut().catchError((_) {}));
    } else if (failure.isUnauthorized) {
      _generation++;
      state = const AdminUnauthorized();
    }
  }

  Future<void> _verify() async {
    final generation = ++_generation;
    final hadIdentity = state is AdminAuthorized;
    if (!hadIdentity) state = const AdminAuthorizationPending();
    try {
      final identity = await _gateway.verifyAdminSession();
      if (generation != _generation) return;
      state = AdminAuthorized(identity);
    } on AdminAuthFailure catch (failure) {
      if (generation != _generation) return;
      if (failure.isUnauthenticated) {
        state = AdminUnauthenticated(
          sessionExpired: hadIdentity || _authRepository.currentUser != null,
        );
        // A session the server no longer accepts is not kept around locally.
        unawaited(_authRepository.signOut().catchError((_) {}));
      } else if (failure.isUnauthorized) {
        state = const AdminUnauthorized();
      } else {
        state = AdminAuthorizationFailed(
          failure.code,
          retryable: failure.retryable,
        );
      }
    } catch (_) {
      if (generation != _generation) return;
      state = const AdminAuthorizationFailed(
        SubscriptionErrorCode.temporaryBackendFailure,
        retryable: true,
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
