import '../../domain/entities/auth_user.dart';

enum AuthStatus {
  unauthenticated,
  authenticated,
  passwordRecovery,
  configurationMissing,
}

enum AuthOperation {
  signIn,
  register,
  resetEmail,
  updatePassword,
  google,
  guest,
  signOut,
}

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.activeOperation,
    this.errorMessage,
    this.notice,
    this.feedbackId = 0,
  });

  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);

  const AuthState.configurationMissing()
    : this(status: AuthStatus.configurationMissing);

  final AuthStatus status;
  final AuthUser? user;
  final AuthOperation? activeOperation;
  final String? errorMessage;
  final String? notice;
  final int feedbackId;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated ||
      status == AuthStatus.passwordRecovery;

  bool get isLoading => activeOperation != null;

  AuthState loading(AuthOperation operation) => AuthState(
    status: status,
    user: user,
    activeOperation: operation,
    feedbackId: feedbackId,
  );

  AuthState feedback({String? error, String? message}) => AuthState(
    status: status,
    user: user,
    errorMessage: error,
    notice: message,
    feedbackId: feedbackId + 1,
  );
}
