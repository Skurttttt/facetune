import 'package:facetune/features/profile/domain/entities/avatar_image.dart';
import 'package:facetune/features/profile/domain/entities/user_profile.dart';
import 'package:facetune/features/profile/domain/repositories/profile_repository.dart';
import 'package:facetune/features/profile/domain/services/avatar_picker.dart';
import 'package:facetune/features/settings/domain/entities/user_settings.dart';
import 'package:facetune/features/settings/domain/repositories/settings_repository.dart';

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({UserProfile? profile})
    : profile =
          profile ??
          UserProfile(
            id: 'profile-id',
            authUserId: 'test-user',
            displayName: 'Mia',
            createdAt: DateTime.utc(2026, 8, 11),
            updatedAt: DateTime.utc(2026, 8, 11),
          );

  UserProfile profile;

  @override
  Future<UserProfile> load() async => profile;

  @override
  Future<UserProfile> updateDisplayName(String displayName) async {
    profile = UserProfile(
      id: profile.id,
      authUserId: profile.authUserId,
      displayName: displayName.trim(),
      avatarPath: profile.avatarPath,
      avatarUrl: profile.avatarUrl,
      createdAt: profile.createdAt,
      updatedAt: DateTime.utc(2026, 8, 11, 1),
    );
    return profile;
  }

  @override
  Future<UserProfile> updateAvatar(AvatarImage avatar) async {
    profile = UserProfile(
      id: profile.id,
      authUserId: profile.authUserId,
      displayName: profile.displayName,
      avatarPath: '${profile.authUserId}/avatar.jpg',
      avatarUrl: 'https://signed.example/avatar',
      createdAt: profile.createdAt,
      updatedAt: DateTime.utc(2026, 8, 11, 1),
    );
    return profile;
  }
}

class FakeAvatarPicker implements AvatarPicker {
  const FakeAvatarPicker({this.avatar});

  final AvatarImage? avatar;

  @override
  Future<AvatarImage?> pick() async => avatar;
}

class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({UserSettings? settings})
    : settings =
          settings ??
          UserSettings(
            userId: 'test-user',
            theme: AppThemePreference.system,
            notificationsEnabled: true,
            analyticsConsent: false,
            createdAt: DateTime.utc(2026, 8, 11),
            updatedAt: DateTime.utc(2026, 8, 11),
          );

  UserSettings settings;

  @override
  Future<UserSettings> load() async => settings;

  @override
  Future<UserSettings> updateAnalyticsConsent(bool consented) async =>
      settings = settings.copyWith(analyticsConsent: consented);

  @override
  Future<UserSettings> updateNotifications(bool enabled) async =>
      settings = settings.copyWith(notificationsEnabled: enabled);

  @override
  Future<UserSettings> updateTheme(AppThemePreference theme) async =>
      settings = settings.copyWith(theme: theme);
}
