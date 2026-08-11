enum AppThemePreference { system, light, dark }

class UserSettings {
  const UserSettings({
    required this.userId,
    required this.theme,
    required this.notificationsEnabled,
    required this.analyticsConsent,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserSettings.defaults() => UserSettings(
    userId: '',
    theme: AppThemePreference.system,
    notificationsEnabled: true,
    analyticsConsent: false,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  final String userId;
  final AppThemePreference theme;
  final bool notificationsEnabled;
  final bool analyticsConsent;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserSettings copyWith({
    AppThemePreference? theme,
    bool? notificationsEnabled,
    bool? analyticsConsent,
  }) => UserSettings(
    userId: userId,
    theme: theme ?? this.theme,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    analyticsConsent: analyticsConsent ?? this.analyticsConsent,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
