import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/supabase/supabase_availability_provider.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../../domain/repositories/settings_repository.dart';
import '../data_sources/settings_remote_data_source.dart';
import '../repositories/supabase_settings_repository.dart';
import '../repositories/unavailable_settings_repository.dart';

final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const UnavailableSettingsRepository();
  }
  return SupabaseSettingsRepository(
    SupabaseSettingsRemoteDataSource(ref.watch(supabaseClientProvider)),
  );
});
