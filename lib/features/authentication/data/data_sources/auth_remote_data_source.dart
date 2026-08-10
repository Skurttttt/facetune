import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/data/supabase_remote_data_source.dart';

abstract interface class AuthRemoteDataSource {
  User? get currentUser;

  Stream<AuthState> get authStateChanges;

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  });

  Future<AuthResponse> signUp({
    required String displayName,
    required String email,
    required String password,
  });

  Future<void> resetPasswordForEmail(String email);

  Future<UserResponse> updatePassword(String password);

  Future<bool> signInWithGoogle();

  Future<AuthResponse> signInAnonymously();

  Future<void> ensureProfile(User user);

  Future<void> signOut();
}

class SupabaseAuthRemoteDataSource extends SupabaseRemoteDataSource
    implements AuthRemoteDataSource {
  const SupabaseAuthRemoteDataSource(super.client);

  @override
  User? get currentUser => client.auth.currentUser;

  @override
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<AuthResponse> signUp({
    required String displayName,
    required String email,
    required String password,
  }) {
    return client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
      emailRedirectTo: AppConstants.authCallbackUrl,
    );
  }

  @override
  Future<void> resetPasswordForEmail(String email) {
    return client.auth.resetPasswordForEmail(
      email,
      redirectTo: AppConstants.passwordResetCallbackUrl,
    );
  }

  @override
  Future<UserResponse> updatePassword(String password) {
    return client.auth.updateUser(UserAttributes(password: password));
  }

  @override
  Future<bool> signInWithGoogle() {
    return client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AppConstants.authCallbackUrl,
    );
  }

  @override
  Future<AuthResponse> signInAnonymously() {
    return client.auth.signInAnonymously(data: const {'account_type': 'guest'});
  }

  @override
  Future<void> ensureProfile(User user) async {
    final metadata = user.userMetadata;
    final rawName = metadata?['display_name'] ?? metadata?['full_name'];
    final displayName = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim()
        : null;

    await client.from('profiles').upsert({
      'auth_user_id': user.id,
      'display_name': displayName,
    }, onConflict: 'auth_user_id');
    await client.from('user_settings').upsert({
      'user_id': user.id,
    }, onConflict: 'user_id');
  }

  @override
  Future<void> signOut() => client.auth.signOut();
}
