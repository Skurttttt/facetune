import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_remote_data_source.dart';

abstract interface class ProfileRemoteDataSource {
  String? get currentUserId;

  Future<Map<String, Object?>?> selectProfile();

  Future<Map<String, Object?>> updateDisplayName(String displayName);

  Future<void> updateAuthDisplayName(String displayName);

  Future<void> uploadAvatar({required String path, required Uint8List bytes});

  Future<Map<String, Object?>> updateAvatarPath(String path);

  Future<String> createAvatarSignedUrl(String path);
}

class SupabaseProfileRemoteDataSource extends SupabaseRemoteDataSource
    implements ProfileRemoteDataSource {
  const SupabaseProfileRemoteDataSource(super.client);

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  Future<Map<String, Object?>?> selectProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;
    final row = await client
        .from('profiles')
        .select('*')
        .eq('auth_user_id', userId)
        .maybeSingle();
    return row == null ? null : _row(row);
  }

  @override
  Future<Map<String, Object?>> updateDisplayName(String displayName) async {
    final userId = currentUserId;
    if (userId == null) throw const AuthException('No active session.');
    return _row(
      await client
          .from('profiles')
          .update({'display_name': displayName})
          .eq('auth_user_id', userId)
          .select('*')
          .single(),
    );
  }

  @override
  Future<void> updateAuthDisplayName(String displayName) async {
    await client.auth.updateUser(
      UserAttributes(data: {'display_name': displayName}),
    );
  }

  @override
  Future<void> uploadAvatar({required String path, required Uint8List bytes}) =>
      client.storage
          .from('profile-avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

  @override
  Future<Map<String, Object?>> updateAvatarPath(String path) async {
    final userId = currentUserId;
    if (userId == null) throw const AuthException('No active session.');
    return _row(
      await client
          .from('profiles')
          .update({'avatar_path': path})
          .eq('auth_user_id', userId)
          .select('*')
          .single(),
    );
  }

  @override
  Future<String> createAvatarSignedUrl(String path) =>
      client.storage.from('profile-avatars').createSignedUrl(path, 3600);

  static Map<String, Object?> _row(Map row) =>
      row.map((key, value) => MapEntry(key.toString(), value));
}
