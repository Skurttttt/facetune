import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/avatar_image.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/errors/profile_failure.dart';
import '../../domain/repositories/profile_repository.dart';
import '../data_sources/profile_remote_data_source.dart';

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository(
    this._remote, {
    this.operationTimeout = const Duration(seconds: 20),
  });

  final ProfileRemoteDataSource _remote;
  final Duration operationTimeout;

  @override
  Future<UserProfile> load() async {
    _requireUserId();
    try {
      final row = await _remote.selectProfile().timeout(operationTimeout);
      if (row == null) {
        throw const ProfileFailure(
          'Your profile is not ready yet. Sign out and sign in again.',
          kind: ProfileFailureKind.unavailable,
        );
      }
      return _map(row);
    } catch (error) {
      if (error is ProfileFailure) rethrow;
      throw _failure(error);
    }
  }

  @override
  Future<UserProfile> updateDisplayName(String displayName) async {
    _requireUserId();
    final normalized = displayName.trim();
    if (normalized.isEmpty || normalized.length > 80) {
      throw const ProfileFailure(
        'Enter a name between 1 and 80 characters.',
        kind: ProfileFailureKind.invalidData,
        retryable: false,
      );
    }
    try {
      final row = await _remote
          .updateDisplayName(normalized)
          .timeout(operationTimeout);
      try {
        await _remote
            .updateAuthDisplayName(normalized)
            .timeout(operationTimeout);
      } catch (_) {
        // The profile row is authoritative. Metadata synchronization is
        // best-effort and can be retried by a later account update.
      }
      return _map(row);
    } catch (error) {
      if (error is ProfileFailure) rethrow;
      throw _failure(error);
    }
  }

  @override
  Future<UserProfile> updateAvatar(AvatarImage avatar) async {
    final userId = _requireUserId();
    if (avatar.bytes.isEmpty || avatar.bytes.length > 2 * 1024 * 1024) {
      throw const ProfileFailure(
        'Choose a profile photo that can be prepared under 2 MB.',
        kind: ProfileFailureKind.invalidData,
        retryable: false,
      );
    }
    final path = '$userId/avatar.jpg';
    try {
      await _remote
          .uploadAvatar(path: path, bytes: avatar.bytes)
          .timeout(operationTimeout);
      return _map(
        await _remote.updateAvatarPath(path).timeout(operationTimeout),
      );
    } catch (error) {
      if (error is ProfileFailure) rethrow;
      throw _failure(error);
    }
  }

  String _requireUserId() {
    final userId = _remote.currentUserId;
    if (userId == null) {
      throw const ProfileFailure(
        'Your session expired. Sign in again.',
        kind: ProfileFailureKind.sessionExpired,
        retryable: false,
      );
    }
    return userId;
  }

  Future<UserProfile> _map(Map<String, Object?> row) async {
    final avatarPath = _optionalString(row['avatar_path']);
    String? avatarUrl;
    if (avatarPath != null) {
      try {
        avatarUrl = await _remote
            .createAvatarSignedUrl(avatarPath)
            .timeout(operationTimeout);
      } on StorageException {
        avatarUrl = null;
      }
    }
    return UserProfile(
      id: _requiredString(row, 'id'),
      authUserId: _requiredString(row, 'auth_user_id'),
      displayName: _optionalString(row['display_name']),
      avatarPath: avatarPath,
      avatarUrl: avatarUrl,
      createdAt: DateTime.parse(_requiredString(row, 'created_at')).toUtc(),
      updatedAt: DateTime.parse(_requiredString(row, 'updated_at')).toUtc(),
    );
  }

  static ProfileFailure _failure(Object error) {
    if (error is SocketException || error is TimeoutException) {
      return ProfileFailure(
        error is TimeoutException
            ? 'That request is taking too long. Please try again.'
            : 'Check your connection and try again.',
        kind: error is TimeoutException
            ? ProfileFailureKind.timeout
            : ProfileFailureKind.offline,
      );
    }
    if (error is AuthException) {
      return const ProfileFailure(
        'Your session expired. Sign in again.',
        kind: ProfileFailureKind.sessionExpired,
        retryable: false,
      );
    }
    if ((error is StorageException &&
            int.tryParse(error.statusCode.toString()) == 401) ||
        (error is PostgrestException && _isExpiredSession(error))) {
      return const ProfileFailure(
        'Your session expired. Sign in again.',
        kind: ProfileFailureKind.sessionExpired,
        retryable: false,
      );
    }
    if (error is PostgrestException || error is StorageException) {
      return const ProfileFailure(
        'Your profile could not be updated right now.',
        kind: ProfileFailureKind.unavailable,
      );
    }
    if (error is FormatException) {
      return const ProfileFailure(
        'Your profile contains incomplete account data.',
        kind: ProfileFailureKind.invalidData,
        retryable: false,
      );
    }
    return const ProfileFailure(
      'Your profile could not be loaded.',
      kind: ProfileFailureKind.unknown,
    );
  }

  static String _requiredString(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key is missing.');
    }
    return value;
  }

  static String? _optionalString(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static bool _isExpiredSession(PostgrestException error) {
    final detail = '${error.code} ${error.message} ${error.details}'
        .toLowerCase();
    return error.code == 'PGRST301' ||
        (detail.contains('jwt') &&
            (detail.contains('expired') || detail.contains('invalid')));
  }
}
