import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../domain/entities/auth_event.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/registration_result.dart';
import '../../domain/errors/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../data_sources/auth_remote_data_source.dart';
import '../mappers/auth_error_mapper.dart';

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._remoteDataSource);

  final AuthRemoteDataSource _remoteDataSource;

  @override
  AuthUser? get currentUser => _mapUser(_remoteDataSource.currentUser);

  @override
  Stream<AuthEvent> get authEvents {
    return _remoteDataSource.authStateChanges.map((state) {
      return AuthEvent(
        type: _mapEvent(state.event),
        user: _mapUser(state.session?.user),
      );
    });
  }

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _remoteDataSource.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = _requireUser(response.user);
      await bootstrapProfile(user);
      return user;
    } catch (error) {
      throw AuthErrorMapper.map(error);
    }
  }

  @override
  Future<RegistrationResult> registerWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _remoteDataSource.signUp(
        displayName: displayName.trim(),
        email: email.trim(),
        password: password,
      );
      final user = _requireUser(response.user);
      if (response.session != null) {
        await bootstrapProfile(user);
      }
      return RegistrationResult(
        user: user,
        hasActiveSession: response.session != null,
      );
    } catch (error) {
      throw AuthErrorMapper.map(error);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _remoteDataSource.resetPasswordForEmail(email.trim());
    } catch (error) {
      throw AuthErrorMapper.map(error);
    }
  }

  @override
  Future<void> updatePassword(String password) async {
    try {
      await _remoteDataSource.updatePassword(password);
    } catch (error) {
      throw AuthErrorMapper.map(error);
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      final launched = await _remoteDataSource.signInWithGoogle();
      if (!launched) {
        throw const AuthFailure(
          'Could not open Google sign-in. Please try again.',
        );
      }
    } catch (error) {
      throw AuthErrorMapper.map(error);
    }
  }

  @override
  Future<AuthUser> signInAnonymously() async {
    try {
      final response = await _remoteDataSource.signInAnonymously();
      final user = _requireUser(response.user);
      await bootstrapProfile(user);
      return user;
    } catch (error) {
      throw AuthErrorMapper.map(error);
    }
  }

  @override
  Future<void> bootstrapProfile(AuthUser user) async {
    try {
      final nativeUser = _remoteDataSource.currentUser;
      if (nativeUser == null || nativeUser.id != user.id) {
        throw const AuthFailure('Your session is no longer active.');
      }
      await _remoteDataSource.ensureProfile(nativeUser);
    } catch (error) {
      throw AuthErrorMapper.map(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _remoteDataSource.signOut();
    } catch (error) {
      throw AuthErrorMapper.map(error);
    }
  }

  static AuthUser _requireUser(User? user) {
    final mapped = _mapUser(user);
    if (mapped == null) {
      throw const AuthFailure(
        'No user session was returned. Please try again.',
      );
    }
    return mapped;
  }

  static AuthUser? _mapUser(User? user) {
    if (user == null) {
      return null;
    }
    final metadata = user.userMetadata;
    final rawName = metadata?['display_name'] ?? metadata?['full_name'];
    return AuthUser(
      id: user.id,
      email: user.email,
      displayName: rawName is String ? rawName : null,
      isAnonymous: user.isAnonymous,
    );
  }

  static AuthEventType _mapEvent(AuthChangeEvent event) {
    return switch (event) {
      AuthChangeEvent.initialSession => AuthEventType.initialSession,
      AuthChangeEvent.signedIn => AuthEventType.signedIn,
      AuthChangeEvent.signedOut => AuthEventType.signedOut,
      AuthChangeEvent.passwordRecovery => AuthEventType.passwordRecovery,
      AuthChangeEvent.tokenRefreshed => AuthEventType.tokenRefreshed,
      AuthChangeEvent.userUpdated => AuthEventType.userUpdated,
      _ => AuthEventType.initialSession,
    };
  }
}
