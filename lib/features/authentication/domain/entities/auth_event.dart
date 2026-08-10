import 'auth_user.dart';

enum AuthEventType {
  initialSession,
  signedIn,
  signedOut,
  passwordRecovery,
  tokenRefreshed,
  userUpdated,
}

class AuthEvent {
  const AuthEvent({required this.type, this.user});

  final AuthEventType type;
  final AuthUser? user;
}
