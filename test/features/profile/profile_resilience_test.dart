import 'dart:async';
import 'dart:typed_data';

import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/profile/data/data_sources/profile_remote_data_source.dart';
import 'package:facetune/features/profile/data/providers/profile_providers.dart';
import 'package:facetune/features/profile/data/repositories/supabase_profile_repository.dart';
import 'package:facetune/features/profile/domain/entities/user_profile.dart';
import 'package:facetune/features/profile/domain/errors/profile_failure.dart';
import 'package:facetune/features/profile/presentation/controllers/profile_controller.dart';
import 'package:facetune/features/profile/presentation/controllers/profile_state.dart';
import 'package:facetune/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_account_repositories.dart';
import '../../helpers/fake_auth_repository.dart';

void main() {
  group('profile resilience', () {
    test(
      'repository classifies a stalled load as a retryable timeout',
      () async {
        final repository = SupabaseProfileRepository(
          _HangingProfileRemoteDataSource(),
          operationTimeout: const Duration(milliseconds: 5),
        );

        await expectLater(
          repository.load(),
          throwsA(
            isA<ProfileFailure>()
                .having(
                  (failure) => failure.kind,
                  'kind',
                  ProfileFailureKind.timeout,
                )
                .having((failure) => failure.retryable, 'retryable', isTrue),
          ),
        );
      },
    );

    test('repository reports a missing user as an expired session', () async {
      final repository = SupabaseProfileRepository(
        _HangingProfileRemoteDataSource(currentUserId: null),
      );

      await expectLater(
        repository.load(),
        throwsA(
          isA<ProfileFailure>()
              .having(
                (failure) => failure.kind,
                'kind',
                ProfileFailureKind.sessionExpired,
              )
              .having((failure) => failure.retryable, 'retryable', isFalse),
        ),
      );
    });

    test(
      'unexpected update errors clear busy state and hide internals',
      () async {
        final controller = ProfileController(
          _UnexpectedProfileRepository(),
          const FakeAvatarPicker(),
        );
        addTearDown(controller.dispose);
        await controller.load();

        await controller.updateDisplayName('Mia Rose');

        expect(controller.state.status, ProfileStatus.ready);
        expect(controller.state.activeOperation, isNull);
        expect(controller.state.feedbackIsError, isTrue);
        expect(controller.state.feedback, contains('could not be updated'));
        expect(controller.state.feedback, isNot(contains('raw database')));
      },
    );

    testWidgets('expired profile session offers a sign-in recovery action', (
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
            profileRepositoryProvider.overrideWithValue(
              _ExpiredProfileRepository(),
            ),
            avatarPickerProvider.overrideWithValue(const FakeAvatarPicker()),
          ],
          child: const MaterialApp(home: ProfilePage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in again'), findsOneWidget);
      await tester.tap(find.text('Sign in again'));
      await tester.pumpAndSettle();

      expect(authRepository.user, isNull);
    });
  });
}

class _HangingProfileRemoteDataSource implements ProfileRemoteDataSource {
  _HangingProfileRemoteDataSource({this.currentUserId = 'test-user'});

  @override
  final String? currentUserId;

  @override
  Future<Map<String, Object?>?> selectProfile() =>
      Completer<Map<String, Object?>?>().future;

  @override
  Future<String> createAvatarSignedUrl(String path) =>
      throw UnimplementedError();

  @override
  Future<Map<String, Object?>> updateAvatarPath(String path) =>
      throw UnimplementedError();

  @override
  Future<void> updateAuthDisplayName(String displayName) =>
      throw UnimplementedError();

  @override
  Future<Map<String, Object?>> updateDisplayName(String displayName) =>
      throw UnimplementedError();

  @override
  Future<void> uploadAvatar({required String path, required Uint8List bytes}) =>
      throw UnimplementedError();
}

class _UnexpectedProfileRepository extends FakeProfileRepository {
  @override
  Future<UserProfile> updateDisplayName(String displayName) =>
      Future<UserProfile>.error(StateError('raw database internals'));
}

class _ExpiredProfileRepository extends FakeProfileRepository {
  @override
  Future<UserProfile> load() => Future<UserProfile>.error(
    const ProfileFailure(
      'Your session expired. Sign in again.',
      kind: ProfileFailureKind.sessionExpired,
      retryable: false,
    ),
  );
}
