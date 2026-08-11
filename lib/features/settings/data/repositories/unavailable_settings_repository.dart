import '../../domain/entities/user_settings.dart';
import '../../domain/errors/settings_failure.dart';
import '../../domain/repositories/settings_repository.dart';

class UnavailableSettingsRepository implements SettingsRepository {
  const UnavailableSettingsRepository();

  @override
  Future<UserSettings> load() => throw const SettingsFailure(
    'Settings are unavailable in this build.',
    kind: SettingsFailureKind.unavailable,
    retryable: false,
  );

  @override
  Future<UserSettings> updateAnalyticsConsent(bool consented) =>
      throw const SettingsFailure(
        'Settings are unavailable in this build.',
        kind: SettingsFailureKind.unavailable,
        retryable: false,
      );

  @override
  Future<UserSettings> updateNotifications(bool enabled) =>
      throw const SettingsFailure(
        'Settings are unavailable in this build.',
        kind: SettingsFailureKind.unavailable,
        retryable: false,
      );

  @override
  Future<UserSettings> updateTheme(AppThemePreference theme) =>
      throw const SettingsFailure(
        'Settings are unavailable in this build.',
        kind: SettingsFailureKind.unavailable,
        retryable: false,
      );
}
