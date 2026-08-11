import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/history/data/providers/history_providers.dart';
import 'package:facetune/features/history/domain/errors/history_failure.dart';
import 'package:facetune/features/home/presentation/pages/home_page.dart';
import 'package:facetune/features/profile/data/providers/profile_providers.dart';
import 'package:facetune/features/saved_looks/data/providers/saved_looks_providers.dart';
import 'package:facetune/features/saved_looks/data/repositories/unavailable_saved_looks_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_account_repositories.dart';
import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_history_repository.dart';

void main() {
  testWidgets('home shows an honest empty library without fabricated advice', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository(
      user: const AuthUser(id: 'test-user', isAnonymous: false),
    );
    addTearDown(authRepository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseAvailableProvider.overrideWithValue(true),
          authRepositoryProvider.overrideWithValue(authRepository),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          historyRepositoryProvider.overrideWithValue(
            FakeHistoryRepository(),
          ),
          savedLooksRepositoryProvider.overrideWithValue(
            const UnavailableSavedLooksRepository(),
          ),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start Scan'), findsOneWidget);
    expect(find.text('No recent looks yet'), findsOneWidget);
    expect(find.text('Warm tones will glow on you'), findsNothing);
    expect(find.text('Soft Glam'), findsNothing);
  });

  testWidgets('home keeps Start Scan available when history is offline', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository(
      user: const AuthUser(id: 'test-user', isAnonymous: false),
    );
    addTearDown(authRepository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseAvailableProvider.overrideWithValue(true),
          authRepositoryProvider.overrideWithValue(authRepository),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          historyRepositoryProvider.overrideWithValue(
            FakeHistoryRepository(
              failure: const HistoryFailure(
                'Check your internet connection and try again.',
              ),
            ),
          ),
          savedLooksRepositoryProvider.overrideWithValue(
            const UnavailableSavedLooksRepository(),
          ),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recent looks unavailable'), findsOneWidget);
    expect(find.text('Start Scan'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
