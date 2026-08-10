import 'auth_user.dart';

class RegistrationResult {
  const RegistrationResult({
    required this.user,
    required this.hasActiveSession,
  });

  final AuthUser user;
  final bool hasActiveSession;
}
