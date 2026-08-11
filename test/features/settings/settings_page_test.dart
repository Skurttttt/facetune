import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/settings/data/providers/settings_providers.dart';
import 'package:facetune/features/settings/presentation/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_account_repositories.dart';
import '../../helpers/fake_auth_repository.dart';

void main() {
  testWidgets('shows the app version and honest preference placeholders', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository(
      user: const AuthUser(
        id: 'registered-user',
        email: 'mia@example.com',
        isAnonymous: false,
      ),
    );
    addTearDown(authRepository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseAvailableProvider.overrideWithValue(true),
          authRepositoryProvider.overrideWithValue(authRepository),
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository(),
          ),
          appVersionProvider.overrideWith((ref) async => '9.8.7+42'),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Notification preference'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text(
        'Saved for future use. FaceTune does not send notifications yet.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Stores your consent choice. No analytics SDK is active.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('About FaceTune'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Version 9.8.7+42'), findsOneWidget);
    expect(find.text('Publication pending'), findsOneWidget);

    await tester.ensureVisible(find.text('Privacy policy'));
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();

    expect(find.textContaining('has not been published yet'), findsOneWidget);
    expect(
      find.textContaining('does not represent a legal policy'),
      findsOneWidget,
    );
  });

  testWidgets('warns a guest before signing out and cancel preserves session', (
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
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository(),
          ),
          appVersionProvider.overrideWith((ref) async => '1.0.0+1'),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('preferences belong to your temporary guest account'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Sign out'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out of guest account?'), findsOneWidget);
    expect(
      find.textContaining('does not delete backend records'),
      findsOneWidget,
    );
    expect(
      find.textContaining('cannot currently be recovered or transferred'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(authRepository.currentUser?.isAnonymous, isTrue);
    expect(find.text('Sign out of guest account?'), findsNothing);
  });
}
