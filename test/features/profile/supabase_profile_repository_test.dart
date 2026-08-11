import 'dart:typed_data';

import 'package:facetune/features/profile/data/data_sources/profile_remote_data_source.dart';
import 'package:facetune/features/profile/data/repositories/supabase_profile_repository.dart';
import 'package:facetune/features/profile/domain/entities/avatar_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads profile data with a private signed avatar URL', () async {
    final remote = _FakeProfileRemoteDataSource();
    final repository = SupabaseProfileRepository(remote);

    final profile = await repository.load();

    expect(profile.displayName, 'Mia');
    expect(profile.avatarUrl, 'https://signed.example/user/avatar.jpg');
  });

  test(
    'display-name changes synchronize auth metadata and profile row',
    () async {
      final remote = _FakeProfileRemoteDataSource();
      final repository = SupabaseProfileRepository(remote);

      final profile = await repository.updateDisplayName('  Mia Rose  ');

      expect(remote.authDisplayName, 'Mia Rose');
      expect(remote.profileDisplayName, 'Mia Rose');
      expect(profile.displayName, 'Mia Rose');
    },
  );

  test('avatar replacement uses the stable owner path', () async {
    final remote = _FakeProfileRemoteDataSource();
    final repository = SupabaseProfileRepository(remote);

    await repository.updateAvatar(AvatarImage(Uint8List.fromList([1, 2, 3])));

    expect(remote.uploadedPath, 'user/avatar.jpg');
    expect(remote.avatarPath, 'user/avatar.jpg');
  });
}

class _FakeProfileRemoteDataSource implements ProfileRemoteDataSource {
  String? authDisplayName;
  String? profileDisplayName = 'Mia';
  String? uploadedPath;
  String? avatarPath = 'user/avatar.jpg';

  @override
  String? get currentUserId => 'user';

  Map<String, Object?> get row => {
    'id': 'profile-id',
    'auth_user_id': 'user',
    'display_name': profileDisplayName,
    'avatar_path': avatarPath,
    'created_at': '2026-08-11T00:00:00Z',
    'updated_at': '2026-08-11T00:00:00Z',
  };

  @override
  Future<Map<String, Object?>?> selectProfile() async => row;

  @override
  Future<void> updateAuthDisplayName(String displayName) async {
    authDisplayName = displayName;
  }

  @override
  Future<Map<String, Object?>> updateDisplayName(String displayName) async {
    profileDisplayName = displayName;
    return row;
  }

  @override
  Future<void> uploadAvatar({
    required String path,
    required Uint8List bytes,
  }) async {
    uploadedPath = path;
  }

  @override
  Future<Map<String, Object?>> updateAvatarPath(String path) async {
    avatarPath = path;
    return row;
  }

  @override
  Future<String> createAvatarSignedUrl(String path) async =>
      'https://signed.example/$path';
}
