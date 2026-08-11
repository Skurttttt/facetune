import '../entities/user_settings.dart';

abstract interface class SettingsRepository {
  Future<UserSettings> load();

  Future<UserSettings> updateTheme(AppThemePreference theme);

  Future<UserSettings> updateNotifications(bool enabled);

  Future<UserSettings> updateAnalyticsConsent(bool consented);
}
