import '../entities/auth_event.dart';
import '../entities/auth_user.dart';
import '../entities/registration_result.dart';

abstract interface class AuthRepository {
  AuthUser? get currentUser;

  Stream<AuthEvent> get authEvents;

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<RegistrationResult> registerWithEmail({
    required String displayName,
    required String email,
    required String password,
  });

  Future<void> sendPasswordReset(String email);

  Future<void> updatePassword(String password);

  Future<void> signInWithGoogle();

  Future<AuthUser> signInAnonymously();

  Future<void> bootstrapProfile(AuthUser user);

  Future<void> signOut();
}
