import 'dart:async';

import 'package:facetune/features/authentication/data/data_sources/auth_remote_data_source.dart';
import 'package:facetune/features/authentication/data/repositories/supabase_auth_repository.dart';
import 'package:facetune/features/authentication/domain/entities/auth_event.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/authentication/domain/entities/registration_result.dart';
import 'package:facetune/features/authentication/domain/errors/auth_failure.dart';
import 'package:facetune/features/authentication/domain/repositories/auth_repository.dart';
import 'package:facetune/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:facetune/features/authentication/presentation/controllers/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
  group('authentication resilience', () {
    test(
      'repository turns a stalled sign-in into a friendly timeout',
      () async {
        final repository = SupabaseAuthRepository(
          _HangingAuthRemoteDataSource(),
          operationTimeout: const Duration(milliseconds: 5),
        );

        await expectLater(
          repository.signInWithEmail(
            email: 'mia@example.com',
            password: 'pass',
          ),
          throwsA(
            isA<AuthFailure>().having(
              (failure) => failure.message,
              'message',
              contains('taking too long'),
            ),
          ),
        );
      },
    );

    test('stale profile bootstrap cannot restore a signed-out user', () async {
      const user = AuthUser(id: 'user-1', isAnonymous: false);
      final repository = _ControllableAuthRepository(user: user)
        ..bootstrapCompleter = Completer<void>();
      final controller = AuthController(
        repository: repository,
        isSupabaseAvailable: true,
      );
      addTearDown(controller.dispose);
      addTearDown(repository.dispose);

      repository.emit(
        const AuthEvent(type: AuthEventType.signedIn, user: user),
      );
      await _flushEvents();
      repository.user = null;
      repository.emit(const AuthEvent(type: AuthEventType.signedOut));
      await _flushEvents();
      repository.bootstrapCompleter!.completeError(
        const AuthFailure('Internal bootstrap detail.'),
      );
      await _flushEvents();

      expect(controller.state.status, AuthStatus.unauthenticated);
      expect(controller.state.user, isNull);
      expect(controller.state.errorMessage, isNull);
    });

    test('auth stream errors use a safe state and friendly feedback', () async {
      const user = AuthUser(id: 'user-1', isAnonymous: false);
      final repository = _ControllableAuthRepository(user: user);
      final controller = AuthController(
        repository: repository,
        isSupabaseAvailable: true,
      );
      addTearDown(controller.dispose);
      addTearDown(repository.dispose);

      repository.emitError(StateError('raw transport internals'));
      await _flushEvents();

      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.state.user, user);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.errorMessage, contains('refresh your session'));
      expect(controller.state.errorMessage, isNot(contains('raw transport')));
    });

    test(
      'expired-session recovery clears local state if sign-out fails',
      () async {
        const user = AuthUser(id: 'user-1', isAnonymous: false);
        final repository = _ControllableAuthRepository(
          user: user,
          signOutError: StateError('private remote detail'),
        );
        final controller = AuthController(
          repository: repository,
          isSupabaseAvailable: true,
        );
        addTearDown(controller.dispose);
        addTearDown(repository.dispose);

        await controller.recoverExpiredSession();

        expect(repository.signOutCalls, 1);
        expect(controller.state.status, AuthStatus.unauthenticated);
        expect(controller.state.user, isNull);
        expect(controller.state.isLoading, isFalse);
        expect(controller.state.errorMessage, isNull);
      },
    );

    test('unexpected auth failures never leave an operation busy', () async {
      const user = AuthUser(id: 'user-1', isAnonymous: false);
      final repository = _ControllableAuthRepository(
        user: user,
        signOutError: StateError('private remote detail'),
      );
      final controller = AuthController(
        repository: repository,
        isSupabaseAvailable: true,
      );
      addTearDown(controller.dispose);
      addTearDown(repository.dispose);

      await controller.signOut();

      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.state.isLoading, isFalse);
      expect(
        controller.state.errorMessage,
        'Something went wrong. Please try again.',
      );
    });
  });
}

Future<void> _flushEvents() => Future<void>.delayed(Duration.zero);

class _HangingAuthRemoteDataSource implements AuthRemoteDataSource {
  @override
  supabase.User? get currentUser => null;

  @override
  Stream<supabase.AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<supabase.AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) => Completer<supabase.AuthResponse>().future;

  @override
  Future<void> ensureProfile(supabase.User user) => throw UnimplementedError();

  @override
  Future<void> resetPasswordForEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<supabase.AuthResponse> signInAnonymously() =>
      throw UnimplementedError();

  @override
  Future<bool> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();

  @override
  Future<supabase.AuthResponse> signUp({
    required String displayName,
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<supabase.UserResponse> updatePassword(String password) =>
      throw UnimplementedError();
}

class _ControllableAuthRepository implements AuthRepository {
  _ControllableAuthRepository({this.user, this.signOutError});

  final _events = StreamController<AuthEvent>.broadcast();
  final Object? signOutError;
  AuthUser? user;
  Completer<void>? bootstrapCompleter;
  int signOutCalls = 0;

  @override
  Stream<AuthEvent> get authEvents => _events.stream;

  @override
  AuthUser? get currentUser => user;

  void emit(AuthEvent event) => _events.add(event);

  void emitError(Object error) => _events.addError(error);

  Future<void> dispose() => _events.close();

  @override
  Future<void> bootstrapProfile(AuthUser user) =>
      bootstrapCompleter?.future ?? Future<void>.value();

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    final error = signOutError;
    if (error != null) throw error;
    user = null;
    emit(const AuthEvent(type: AuthEventType.signedOut));
  }

  @override
  Future<RegistrationResult> registerWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> sendPasswordReset(String email) => throw UnimplementedError();

  @override
  Future<AuthUser> signInAnonymously() => throw UnimplementedError();

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> updatePassword(String password) => throw UnimplementedError();
}
