import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/user_settings.dart';
import '../../domain/errors/settings_failure.dart';
import '../../domain/repositories/settings_repository.dart';
import '../data_sources/settings_remote_data_source.dart';

class SupabaseSettingsRepository implements SettingsRepository {
  const SupabaseSettingsRepository(
    this._remote, {
    this.operationTimeout = const Duration(seconds: 20),
  });

  final SettingsRemoteDataSource _remote;
  final Duration operationTimeout;

  @override
  Future<UserSettings> load() async {
    _requireSession();
    try {
      final row = await _remote.selectSettings().timeout(operationTimeout);
      if (row == null) {
        throw const SettingsFailure(
          'Your preferences are not ready yet. Sign out and sign in again.',
          kind: SettingsFailureKind.unavailable,
        );
      }
      return _map(row);
    } catch (error) {
      if (error is SettingsFailure) rethrow;
      throw _failure(error);
    }
  }

  @override
  Future<UserSettings> updateTheme(AppThemePreference theme) => _update({
    'theme_mode': theme.name,
    'dark_mode': theme == AppThemePreference.dark,
  });

  @override
  Future<UserSettings> updateNotifications(bool enabled) =>
      _update({'notifications_enabled': enabled});

  @override
  Future<UserSettings> updateAnalyticsConsent(bool consented) =>
      _update({'analytics_consent': consented});

  Future<UserSettings> _update(Map<String, Object?> values) async {
    _requireSession();
    try {
      return _map(
        await _remote.updateSettings(values).timeout(operationTimeout),
      );
    } catch (error) {
      if (error is SettingsFailure) rethrow;
      throw _failure(error);
    }
  }

  void _requireSession() {
    if (_remote.currentUserId == null) {
      throw const SettingsFailure(
        'Your session expired. Sign in again.',
        kind: SettingsFailureKind.sessionExpired,
        retryable: false,
      );
    }
  }

  static UserSettings _map(Map<String, Object?> row) {
    final rawTheme = row['theme_mode'];
    final theme = AppThemePreference.values
        .where((value) => value.name == rawTheme)
        .firstOrNull;
    final legacyDark = row['dark_mode'];
    return UserSettings(
      userId: _requiredString(row, 'user_id'),
      theme:
          theme ??
          (legacyDark == true
              ? AppThemePreference.dark
              : AppThemePreference.system),
      notificationsEnabled: _requiredBool(row, 'notifications_enabled'),
      analyticsConsent: _requiredBool(row, 'analytics_consent'),
      createdAt: DateTime.parse(_requiredString(row, 'created_at')).toUtc(),
      updatedAt: DateTime.parse(_requiredString(row, 'updated_at')).toUtc(),
    );
  }

  static SettingsFailure _failure(Object error) {
    if (error is SocketException || error is TimeoutException) {
      return SettingsFailure(
        error is TimeoutException
            ? 'That request is taking too long. Please try again.'
            : 'Check your connection and try again.',
        kind: error is TimeoutException
            ? SettingsFailureKind.timeout
            : SettingsFailureKind.offline,
      );
    }
    if (error is AuthException) {
      return const SettingsFailure(
        'Your session expired. Sign in again.',
        kind: SettingsFailureKind.sessionExpired,
        retryable: false,
      );
    }
    if (error is PostgrestException && _isExpiredSession(error)) {
      return const SettingsFailure(
        'Your session expired. Sign in again.',
        kind: SettingsFailureKind.sessionExpired,
        retryable: false,
      );
    }
    if (error is PostgrestException) {
      return const SettingsFailure(
        'Your preferences could not be updated right now.',
        kind: SettingsFailureKind.unavailable,
      );
    }
    if (error is FormatException) {
      return const SettingsFailure(
        'Your saved preferences contain invalid data.',
        kind: SettingsFailureKind.invalidData,
        retryable: false,
      );
    }
    return const SettingsFailure(
      'Your preferences could not be loaded.',
      kind: SettingsFailureKind.unknown,
    );
  }

  static String _requiredString(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key is missing.');
    }
    return value;
  }

  static bool _requiredBool(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is! bool) throw FormatException('$key is invalid.');
    return value;
  }

  static bool _isExpiredSession(PostgrestException error) {
    final detail = '${error.code} ${error.message} ${error.details}'
        .toLowerCase();
    return error.code == 'PGRST301' ||
        (detail.contains('jwt') &&
            (detail.contains('expired') || detail.contains('invalid')));
  }
}
