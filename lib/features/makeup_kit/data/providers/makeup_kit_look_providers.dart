import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_availability_provider.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../../domain/repositories/makeup_kit_look_repository.dart';
import '../data_sources/makeup_kit_look_remote_data_source.dart';
import '../repositories/supabase_makeup_kit_look_repository.dart';
import '../repositories/unavailable_makeup_kit_look_repository.dart';

final makeupKitLookRepositoryProvider = Provider<MakeupKitLookRepository>((
  ref,
) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const UnavailableMakeupKitLookRepository();
  }
  return SupabaseMakeupKitLookRepository(
    SupabaseMakeupKitLookRemoteDataSource(ref.watch(supabaseClientProvider)),
  );
});
