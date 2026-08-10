import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:facetune/features/authentication/presentation/controllers/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_auth_repository.dart';

void main() {
  test('restores an existing authenticated session', () {
    final repository = FakeAuthRepository(
      user: const AuthUser(
        id: 'existing-user',
        email: 'mia@example.com',
        isAnonymous: false,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repository.dispose();
    });

    final state = container.read(authControllerProvider);

    expect(state.status, AuthStatus.authenticated);
    expect(state.user?.email, 'mia@example.com');
  });

  test('sign out clears the authenticated state', () async {
    final repository = FakeAuthRepository(
      user: const AuthUser(id: 'existing-user', isAnonymous: false),
    );
    final container = ProviderContainer(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repository.dispose();
    });

    await container.read(authControllerProvider.notifier).signOut();

    expect(
      container.read(authControllerProvider).status,
      AuthStatus.unauthenticated,
    );
  });
}
