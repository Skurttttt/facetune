import 'dart:async';

import 'package:facetune/features/authentication/domain/entities/auth_event.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/authentication/domain/entities/registration_result.dart';
import 'package:facetune/features/authentication/domain/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user});

  AuthUser? user;
  final _events = StreamController<AuthEvent>.broadcast();

  @override
  Stream<AuthEvent> get authEvents => _events.stream;

  @override
  AuthUser? get currentUser => user;

  @override
  Future<void> bootstrapProfile(AuthUser user) async {}

  @override
  Future<RegistrationResult> registerWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    user = AuthUser(
      id: 'registered-user',
      email: email,
      displayName: displayName,
      isAnonymous: false,
    );
    return RegistrationResult(user: user!, hasActiveSession: true);
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<AuthUser> signInAnonymously() async {
    user = const AuthUser(id: 'guest', isAnonymous: true);
    return user!;
  }

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    user = AuthUser(id: 'user', email: email, isAnonymous: false);
    return user!;
  }

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {
    user = null;
    _events.add(const AuthEvent(type: AuthEventType.signedOut));
  }

  @override
  Future<void> updatePassword(String password) async {}

  Future<void> dispose() => _events.close();
}
