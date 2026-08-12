import 'dart:async';

import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/settings/data/data_sources/settings_remote_data_source.dart';
import 'package:facetune/features/settings/data/providers/settings_providers.dart';
import 'package:facetune/features/settings/data/repositories/supabase_settings_repository.dart';
import 'package:facetune/features/settings/domain/entities/user_settings.dart';
import 'package:facetune/features/settings/domain/errors/settings_failure.dart';
import 'package:facetune/features/settings/presentation/controllers/settings_controller.dart';
import 'package:facetune/features/settings/presentation/controllers/settings_state.dart';
import 'package:facetune/features/settings/presentation/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_account_repositories.dart';
import '../../helpers/fake_auth_repository.dart';

void main() {
  group('settings resilience', () {
    test(
      'repository classifies a stalled load as a retryable timeout',
      () async {
        final repository = SupabaseSettingsRepository(
          _HangingSettingsRemoteDataSource(),
          operationTimeout: const Duration(milliseconds: 5),
        );

        await expectLater(
          repository.load(),
          throwsA(
            isA<SettingsFailure>()
                .having(
                  (failure) => failure.kind,
                  'kind',
                  SettingsFailureKind.timeout,
                )
                .having((failure) => failure.retryable, 'retryable', isTrue),
          ),
        );
      },
    );

    test('unexpected update errors roll back and clear busy state', () async {
      final controller = SettingsController(_UnexpectedSettingsRepository());
      addTearDown(controller.dispose);
      await controller.load();
      final originalTheme = controller.state.settings.theme;

      await controller.updateTheme(AppThemePreference.dark);

      expect(controller.state.status, SettingsStatus.ready);
      expect(controller.state.settings.theme, originalTheme);
      expect(controller.state.activeOperation, isNull);
      expect(controller.state.feedbackIsError, isTrue);
      expect(controller.state.feedback, contains('could not be saved'));
      expect(controller.state.feedback, isNot(contains('raw database')));
    });

    testWidgets('expired settings session offers a sign-in recovery action', (
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
            settingsRepositoryProvider.overrideWithValue(
              _ExpiredSettingsRepository(),
            ),
            appVersionProvider.overrideWith((ref) async => '1.0.0+1'),
          ],
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in again'), findsOneWidget);
      await tester.tap(find.text('Sign in again'));
      await tester.pumpAndSettle();

      expect(authRepository.user, isNull);
    });

    testWidgets('retryable settings failure still exposes sign out', (
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
            settingsRepositoryProvider.overrideWithValue(
              _RetryableSettingsRepository(),
            ),
            appVersionProvider.overrideWith((ref) async => '1.0.0+1'),
          ],
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('a signed-out account never waits on an unresolved loader', (
      tester,
    ) async {
      final authRepository = FakeAuthRepository();
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

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Settings unavailable'), findsOneWidget);
      expect(find.text('Sign in again'), findsOneWidget);
    });
  });
}

class _HangingSettingsRemoteDataSource implements SettingsRemoteDataSource {
  @override
  String? get currentUserId => 'test-user';

  @override
  Future<Map<String, Object?>?> selectSettings() =>
      Completer<Map<String, Object?>?>().future;

  @override
  Future<Map<String, Object?>> updateSettings(Map<String, Object?> values) =>
      throw UnimplementedError();
}

class _UnexpectedSettingsRepository extends FakeSettingsRepository {
  @override
  Future<UserSettings> updateTheme(AppThemePreference theme) =>
      Future<UserSettings>.error(StateError('raw database internals'));
}

class _ExpiredSettingsRepository extends FakeSettingsRepository {
  @override
  Future<UserSettings> load() => Future<UserSettings>.error(
    const SettingsFailure(
      'Your session expired. Sign in again.',
      kind: SettingsFailureKind.sessionExpired,
      retryable: false,
    ),
  );
}

class _RetryableSettingsRepository extends FakeSettingsRepository {
  @override
  Future<UserSettings> load() => Future<UserSettings>.error(
    const SettingsFailure(
      'Your preferences could not be loaded. Please try again.',
      kind: SettingsFailureKind.unavailable,
    ),
  );
}
