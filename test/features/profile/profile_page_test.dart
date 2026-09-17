import 'package:facetune/core/constants/app_constants.dart';
import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/subscription/data/providers/subscription_providers.dart';
import 'package:facetune/features/subscription/data/repositories/unavailable_subscription_repository.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/profile/data/providers/profile_providers.dart';
import 'package:facetune/features/profile/domain/entities/user_profile.dart';
import 'package:facetune/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
          subscriptionRepositoryProvider.overrideWithValue(
            const UnavailableSubscriptionRepository(),
          ),
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
          subscriptionRepositoryProvider.overrideWithValue(
            const UnavailableSubscriptionRepository(),
          ),
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

  testWidgets('offers plan navigation even when no entitlement is provisioned', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository(
      user: const AuthUser(id: 'unprovisioned-user', isAnonymous: false),
    );
    addTearDown(authRepository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseAvailableProvider.overrideWithValue(true),
          subscriptionRepositoryProvider.overrideWithValue(
            const UnavailableSubscriptionRepository(),
          ),
          authRepositoryProvider.overrideWithValue(authRepository),
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(
              profile: _profile(
                authUserId: 'unprovisioned-user',
                displayName: 'Mia Chen',
              ),
            ),
          ),
          avatarPickerProvider.overrideWithValue(const FakeAvatarPicker()),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const ProfilePage(),
              ),
              GoRoute(
                path: AppConstants.subscriptionRoute,
                builder: (context, state) => const Text('plans screen'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The authoritative card stays hidden without an entitlement, so the entry
    // below is the only way into the plan comparison screen.
    expect(
      find.byKey(const ValueKey('subscription-summary-card')),
      findsNothing,
    );
    final entry = find.text('Plans & Subscription');
    await tester.scrollUntilVisible(
      entry,
      80,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    expect(entry, findsOneWidget);

    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.text('plans screen'), findsOneWidget);
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
