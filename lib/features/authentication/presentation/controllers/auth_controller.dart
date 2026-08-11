import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_availability_provider.dart';
import '../../data/providers/auth_repository_provider.dart';
import '../../domain/entities/auth_event.dart';
import '../../domain/errors/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(
      repository: ref.watch(authRepositoryProvider),
      isSupabaseAvailable: ref.watch(supabaseAvailableProvider),
    );
  },
);

class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required AuthRepository repository,
    required bool isSupabaseAvailable,
  }) : _repository = repository,
       super(_initialState(repository, isSupabaseAvailable)) {
    _subscription = _repository.authEvents.listen(
      (event) => unawaited(_handleAuthEvent(event)),
      onError: _handleAuthStreamError,
    );
  }

  final AuthRepository _repository;
  StreamSubscription<AuthEvent>? _subscription;
  int _authEventGeneration = 0;

  static AuthState _initialState(
    AuthRepository repository,
    bool isSupabaseAvailable,
  ) {
    if (!isSupabaseAvailable) {
      return const AuthState.configurationMissing();
    }
    final user = repository.currentUser;
    return user == null
        ? const AuthState.unauthenticated()
        : AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _run(AuthOperation.signIn, () async {
      final user = await _repository.signInWithEmail(
        email: email,
        password: password,
      );
      state = AuthState(status: AuthStatus.authenticated, user: user);
    });
  }

  Future<void> registerWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    await _run(AuthOperation.register, () async {
      final result = await _repository.registerWithEmail(
        displayName: displayName,
        email: email,
        password: password,
      );
      if (result.hasActiveSession) {
        state = AuthState(status: AuthStatus.authenticated, user: result.user);
      } else {
        state = const AuthState.unauthenticated().feedback(
          message: 'Check your email to confirm your account, then sign in.',
        );
      }
    });
  }

  Future<void> sendPasswordReset(String email) async {
    await _run(AuthOperation.resetEmail, () async {
      await _repository.sendPasswordReset(email);
      state = state.feedback(
        message: 'Password reset instructions are on their way.',
      );
    });
  }

  Future<void> updatePassword(String password) async {
    await _run(AuthOperation.updatePassword, () async {
      await _repository.updatePassword(password);
      state = AuthState(
        status: AuthStatus.authenticated,
        user: _repository.currentUser,
        notice: 'Your password has been updated.',
        feedbackId: state.feedbackId + 1,
      );
    });
  }

  Future<void> signInWithGoogle() async {
    await _run(AuthOperation.google, () async {
      await _repository.signInWithGoogle();
      state = state.feedback(message: 'Complete sign-in in your browser.');
    });
  }

  Future<void> continueAsGuest() async {
    await _run(AuthOperation.guest, () async {
      final user = await _repository.signInAnonymously();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    });
  }

  Future<void> signOut() async {
    ++_authEventGeneration;
    await _run(AuthOperation.signOut, () async {
      await _repository.signOut();
      state = const AuthState.unauthenticated();
    });
  }

  /// Recovers from a confirmed expired session.
  ///
  /// Unlike normal sign-out, this always clears local authentication state,
  /// even when the remote sign-out request cannot complete.
  Future<void> recoverExpiredSession() => _clearLocalSessionSafely();

  /// Leaves password-recovery mode without trapping the user on the form.
  Future<void> cancelPasswordRecovery() => _clearLocalSessionSafely();

  Future<void> _clearLocalSessionSafely() async {
    if (state.activeOperation == AuthOperation.signOut) {
      return;
    }
    ++_authEventGeneration;
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      activeOperation: AuthOperation.signOut,
    );
    try {
      await _repository.signOut();
    } on Object {
      // The server session is already known to be invalid. Local recovery must
      // not be blocked by a failed best-effort remote sign-out.
    } finally {
      if (mounted) {
        state = const AuthState.unauthenticated();
      }
    }
  }

  Future<void> _run(
    AuthOperation operation,
    Future<void> Function() action,
  ) async {
    if (state.isLoading) {
      return;
    }
    state = state.loading(operation);
    try {
      await action();
    } on AuthFailure catch (failure) {
      state = AuthState(
        status: state.status,
        user: state.user,
        errorMessage: failure.message,
        feedbackId: state.feedbackId + 1,
      );
    } on Object {
      state = AuthState(
        status: state.status,
        user: state.user,
        errorMessage: 'Something went wrong. Please try again.',
        feedbackId: state.feedbackId + 1,
      );
    }
  }

  Future<void> _handleAuthEvent(AuthEvent event) async {
    if (!mounted) {
      return;
    }
    final generation = ++_authEventGeneration;
    if (event.type == AuthEventType.signedOut) {
      state = const AuthState.unauthenticated();
      return;
    }
    final user = event.user;
    if (user == null) {
      if (event.type == AuthEventType.initialSession) {
        state = const AuthState.unauthenticated();
      }
      return;
    }

    final status = event.type == AuthEventType.passwordRecovery
        ? AuthStatus.passwordRecovery
        : AuthStatus.authenticated;
    state = AuthState(status: status, user: user);
    try {
      await _repository.bootstrapProfile(user);
    } on AuthFailure catch (failure) {
      if (mounted &&
          generation == _authEventGeneration &&
          state.status == status &&
          state.user?.id == user.id) {
        state = AuthState(
          status: status,
          user: user,
          errorMessage: failure.message,
          feedbackId: state.feedbackId + 1,
        );
      }
    } on Object {
      if (mounted &&
          generation == _authEventGeneration &&
          state.status == status &&
          state.user?.id == user.id) {
        state = AuthState(
          status: status,
          user: user,
          errorMessage: 'We could not finish preparing your account.',
          feedbackId: state.feedbackId + 1,
        );
      }
    }
  }

  void _handleAuthStreamError(Object error, StackTrace stackTrace) {
    if (!mounted) {
      return;
    }
    ++_authEventGeneration;
    final user = _repository.currentUser ?? state.user;
    final status = user == null
        ? AuthStatus.unauthenticated
        : state.status == AuthStatus.passwordRecovery
        ? AuthStatus.passwordRecovery
        : AuthStatus.authenticated;
    state = AuthState(
      status: status,
      user: user,
      errorMessage: 'We could not refresh your session. Please try again.',
      feedbackId: state.feedbackId + 1,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
