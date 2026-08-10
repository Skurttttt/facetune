import '../../domain/entities/auth_event.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/registration_result.dart';
import '../../domain/errors/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

class UnavailableAuthRepository implements AuthRepository {
  const UnavailableAuthRepository();

  static const _failure = AuthFailure(
    'Authentication is not configured for this build.',
  );

  @override
  Stream<AuthEvent> get authEvents => const Stream.empty();

  @override
  AuthUser? get currentUser => null;

  @override
  Future<void> bootstrapProfile(AuthUser user) => Future.error(_failure);

  @override
  Future<RegistrationResult> registerWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) => Future.error(_failure);

  @override
  Future<void> sendPasswordReset(String email) => Future.error(_failure);

  @override
  Future<AuthUser> signInAnonymously() => Future.error(_failure);

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) => Future.error(_failure);

  @override
  Future<void> signInWithGoogle() => Future.error(_failure);

  @override
  Future<void> signOut() => Future.error(_failure);

  @override
  Future<void> updatePassword(String password) => Future.error(_failure);
}
