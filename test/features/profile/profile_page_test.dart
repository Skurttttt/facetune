import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/profile/data/providers/profile_providers.dart';
import 'package:facetune/features/profile/domain/entities/user_profile.dart';
import 'package:facetune/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_account_repositories.dart';
import '../../helpers/fake_auth_repository.dart';

void main() {
  testWidgets('shows registered account information and library shortcuts', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository(
      user: const AuthUser(
        id: 'registered-user',
        email: 'mia@example.com',
        displayName: 'Mia Chen',
        isAnonymous: false,
      ),
    );
    addTearDown(authRepository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseAvailableProvider.overrideWithValue(true),
          authRepositoryProvider.overrideWithValue(authRepository),
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(
              profile: _profile(
                authUserId: 'registered-user',
                displayName: 'Mia Chen',
              ),
            ),
          ),
          avatarPickerProvider.overrideWithValue(const FakeAvatarPicker()),
        ],
        child: const MaterialApp(home: ProfilePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mia Chen'), findsOneWidget);
    expect(find.text('mia@example.com'), findsOneWidget);
    expect(find.text('Registered account'), findsOneWidget);
    expect(find.text('Saved looks'), findsOneWidget);
    expect(find.text('FaceTune history'), findsOneWidget);
    expect(find.text('Your guest account is temporary'), findsNothing);
  });

  testWidgets('truthfully explains temporary guest account behavior', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository(
      user: const AuthUser(id: 'guest-user', isAnonymous: true),
    );
    addTearDown(authRepository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseAvailableProvider.overrideWithValue(true),
          authRepositoryProvider.overrideWithValue(authRepository),
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(
              profile: _profile(authUserId: 'guest-user', displayName: null),
            ),
          ),
          avatarPickerProvider.overrideWithValue(const FakeAvatarPicker()),
        ],
        child: const MaterialApp(home: ProfilePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('No email linked'), findsOneWidget);
    expect(find.text('Guest account'), findsOneWidget);
    expect(find.text('Your guest account is temporary'), findsOneWidget);
    expect(
      find.textContaining('Signing out or clearing app data'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Safe account transfer is not available'),
      findsOneWidget,
    );
  });
}

UserProfile _profile({
  required String authUserId,
  required String? displayName,
}) => UserProfile(
  id: 'profile-$authUserId',
  authUserId: authUserId,
  displayName: displayName,
  createdAt: DateTime.utc(2026, 8, 11),
  updatedAt: DateTime.utc(2026, 8, 11),
);
