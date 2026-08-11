import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_availability_provider.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/services/avatar_picker.dart';
import '../data_sources/profile_remote_data_source.dart';
import '../repositories/supabase_profile_repository.dart';
import '../repositories/unavailable_profile_repository.dart';
import '../services/device_avatar_picker.dart';

final avatarPickerProvider = Provider<AvatarPicker>(
  (ref) => DeviceAvatarPicker(),
);

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const UnavailableProfileRepository();
  }
  return SupabaseProfileRepository(
    SupabaseProfileRemoteDataSource(ref.watch(supabaseClientProvider)),
  );
});
