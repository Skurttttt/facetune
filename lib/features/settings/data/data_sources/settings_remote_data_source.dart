import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/supabase_remote_data_source.dart';

abstract interface class SettingsRemoteDataSource {
  String? get currentUserId;

  Future<Map<String, Object?>?> selectSettings();

  Future<Map<String, Object?>> updateSettings(Map<String, Object?> values);
}

class SupabaseSettingsRemoteDataSource extends SupabaseRemoteDataSource
    implements SettingsRemoteDataSource {
  const SupabaseSettingsRemoteDataSource(super.client);

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  Future<Map<String, Object?>?> selectSettings() async {
    final userId = currentUserId;
    if (userId == null) return null;
    final row = await client
        .from('user_settings')
        .select('*')
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : _row(row);
  }

  @override
  Future<Map<String, Object?>> updateSettings(
    Map<String, Object?> values,
  ) async {
    final userId = currentUserId;
    if (userId == null) throw const AuthException('No active session.');
    return _row(
      await client
          .from('user_settings')
          .update(values)
          .eq('user_id', userId)
          .select('*')
          .single(),
    );
  }

  static Map<String, Object?> _row(Map row) =>
      row.map((key, value) => MapEntry(key.toString(), value));
}
