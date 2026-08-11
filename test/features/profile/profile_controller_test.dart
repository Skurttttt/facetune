import 'dart:typed_data';

import 'package:facetune/features/profile/domain/entities/avatar_image.dart';
import 'package:facetune/features/profile/domain/entities/user_profile.dart';
import 'package:facetune/features/profile/domain/errors/profile_failure.dart';
import 'package:facetune/features/profile/presentation/controllers/profile_controller.dart';
import 'package:facetune/features/profile/presentation/controllers/profile_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_account_repositories.dart';

void main() {
  group('ProfileController', () {
    test('loads the current user profile', () async {
      final repository = FakeProfileRepository();
      final controller = ProfileController(
        repository,
        const FakeAvatarPicker(),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.status, ProfileStatus.ready);
      expect(controller.state.profile?.displayName, 'Mia');
      expect(controller.state.profile?.authUserId, 'test-user');
      expect(controller.state.message, isNull);
    });

    test('reports a friendly profile load failure', () async {
      final controller = ProfileController(
        _FailingProfileRepository(failLoad: true),
        const FakeAvatarPicker(),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.status, ProfileStatus.failure);
      expect(controller.state.profile, isNull);
      expect(controller.state.message, 'Profile could not be loaded.');
    });

    test('updates and trims the display name', () async {
      final repository = FakeProfileRepository();
      final controller = ProfileController(
        repository,
        const FakeAvatarPicker(),
      );
      addTearDown(controller.dispose);
      await controller.load();

      await controller.updateDisplayName('  Mia Rose  ');

      expect(repository.profile.displayName, 'Mia Rose');
      expect(controller.state.profile?.displayName, 'Mia Rose');
      expect(controller.state.status, ProfileStatus.ready);
      expect(controller.state.activeOperation, isNull);
      expect(controller.state.feedback, 'Display name updated.');
    });

    test('keeps the loaded profile when a display-name update fails', () async {
      final repository = _FailingProfileRepository(failDisplayName: true);
      final controller = ProfileController(
        repository,
        const FakeAvatarPicker(),
      );
      addTearDown(controller.dispose);
      await controller.load();
      final original = controller.state.profile;

      await controller.updateDisplayName('New name');

      expect(controller.state.profile, same(original));
      expect(controller.state.activeOperation, isNull);
      expect(controller.state.feedback, 'Display name was not saved.');
    });

    test(
      'leaves the profile unchanged when avatar selection is cancelled',
      () async {
        final repository = FakeProfileRepository();
        final controller = ProfileController(
          repository,
          const FakeAvatarPicker(),
        );
        addTearDown(controller.dispose);
        await controller.load();
        final original = controller.state.profile;

        await controller.chooseAvatar();

        expect(controller.state.profile, same(original));
        expect(controller.state.activeOperation, isNull);
        expect(controller.state.feedback, isNull);
        expect(repository.profile.avatarPath, isNull);
      },
    );

    test('stores and exposes a selected private avatar', () async {
      final repository = FakeProfileRepository();
      final controller = ProfileController(
        repository,
        FakeAvatarPicker(
          avatar: AvatarImage(Uint8List.fromList(const [1, 2, 3])),
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      await controller.chooseAvatar();

      expect(controller.state.status, ProfileStatus.ready);
      expect(controller.state.profile?.avatarPath, 'test-user/avatar.jpg');
      expect(
        controller.state.profile?.avatarUrl,
        'https://signed.example/avatar',
      );
      expect(controller.state.activeOperation, isNull);
      expect(controller.state.feedback, 'Profile photo updated.');
    });

    test('keeps the previous avatar when replacement fails', () async {
      final repository = _FailingProfileRepository(failAvatar: true);
      final controller = ProfileController(
        repository,
        FakeAvatarPicker(
          avatar: AvatarImage(Uint8List.fromList(const [1, 2, 3])),
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();
      final original = controller.state.profile;

      await controller.chooseAvatar();

      expect(controller.state.profile, same(original));
      expect(controller.state.activeOperation, isNull);
      expect(controller.state.feedback, 'Profile photo was not saved.');
    });
  });
}

class _FailingProfileRepository extends FakeProfileRepository {
  _FailingProfileRepository({
    this.failLoad = false,
    this.failDisplayName = false,
    this.failAvatar = false,
  });

  final bool failLoad;
  final bool failDisplayName;
  final bool failAvatar;

  @override
  Future<UserProfile> load() {
    if (failLoad) {
      return Future.error(const ProfileFailure('Profile could not be loaded.'));
    }
    return super.load();
  }

  @override
  Future<UserProfile> updateDisplayName(String displayName) {
    if (failDisplayName) {
      return Future.error(const ProfileFailure('Display name was not saved.'));
    }
    return super.updateDisplayName(displayName);
  }

  @override
  Future<UserProfile> updateAvatar(AvatarImage avatar) {
    if (failAvatar) {
      return Future.error(const ProfileFailure('Profile photo was not saved.'));
    }
    return super.updateAvatar(avatar);
  }
}
