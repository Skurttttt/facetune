import 'package:facetune/features/settings/data/data_sources/settings_remote_data_source.dart';
import 'package:facetune/features/settings/data/repositories/supabase_settings_repository.dart';
import 'package:facetune/features/settings/domain/entities/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads the persisted three-mode theme and consent values', () async {
    final remote = _FakeSettingsRemoteDataSource();
    final repository = SupabaseSettingsRepository(remote);

    final settings = await repository.load();

    expect(settings.theme, AppThemePreference.system);
    expect(settings.notificationsEnabled, isTrue);
    expect(settings.analyticsConsent, isFalse);
  });

  test('theme updates also synchronize the legacy dark-mode field', () async {
    final remote = _FakeSettingsRemoteDataSource();
    final repository = SupabaseSettingsRepository(remote);

    final settings = await repository.updateTheme(AppThemePreference.dark);

    expect(remote.lastUpdate, {'theme_mode': 'dark', 'dark_mode': true});
    expect(settings.theme, AppThemePreference.dark);
  });
}

class _FakeSettingsRemoteDataSource implements SettingsRemoteDataSource {
  Map<String, Object?> data = {
    'user_id': 'user',
    'theme_mode': 'system',
    'dark_mode': false,
    'notifications_enabled': true,
    'analytics_consent': false,
    'created_at': '2026-08-11T00:00:00Z',
    'updated_at': '2026-08-11T00:00:00Z',
  };
  Map<String, Object?>? lastUpdate;

  @override
  String? get currentUserId => 'user';

  @override
  Future<Map<String, Object?>?> selectSettings() async => data;

  @override
  Future<Map<String, Object?>> updateSettings(
    Map<String, Object?> values,
  ) async {
    lastUpdate = values;
    data = {...data, ...values};
    return data;
  }
}
