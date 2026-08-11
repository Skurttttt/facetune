import 'package:facetune/app/app.dart';
import 'package:facetune/app/router/app_router.dart';
import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/authentication/presentation/pages/reset_password_page.dart';
import 'package:facetune/features/history/data/providers/history_providers.dart';
import 'package:facetune/features/profile/data/providers/profile_providers.dart';
import 'package:facetune/features/saved_looks/data/providers/saved_looks_providers.dart';
import 'package:facetune/features/saved_looks/data/repositories/unavailable_saved_looks_repository.dart';
import 'package:facetune/features/settings/data/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_account_repositories.dart';
import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_history_repository.dart';

void main() {
  testWidgets('password recovery can be cancelled safely', (tester) async {
    final repository = FakeAuthRepository(
      user: const AuthUser(id: 'test-user', isAnonymous: false),
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseAvailableProvider.overrideWithValue(true),
          authRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: ResetPasswordPage()),
      ),
    );

    await tester.tap(find.text('Cancel password reset'));
    await tester.pumpAndSettle();

    expect(repository.user, isNull);
  });

  testWidgets('unknown routes show a friendly recovery page', (tester) async {
    final authRepository = FakeAuthRepository(
      user: const AuthUser(id: 'test-user', isAnonymous: false),
    );
    final container = ProviderContainer(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(authRepository),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        historyRepositoryProvider.overrideWithValue(FakeHistoryRepository()),
        savedLooksRepositoryProvider.overrideWithValue(
          const UnavailableSavedLooksRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(authRepository.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FaceTuneApp(),
      ),
    );
    await tester.pumpAndSettle();

    container
        .read(appRouterProvider)
        .go('/private/internal-route?token=secret');
    await tester.pumpAndSettle();

    expect(find.text('Page unavailable'), findsWidgets);
    expect(find.text('That page could not be opened.'), findsOneWidget);
    expect(find.text('Return Home'), findsOneWidget);
    expect(find.textContaining('internal-route'), findsNothing);
    expect(find.textContaining('secret'), findsNothing);

    await tester.tap(find.text('Return Home'));
    await tester.pumpAndSettle();
    expect(find.text('Start Scan'), findsOneWidget);
  });
}
