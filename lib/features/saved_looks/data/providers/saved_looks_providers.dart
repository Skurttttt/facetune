import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_availability_provider.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../../domain/repositories/saved_looks_repository.dart';
import '../data_sources/saved_looks_remote_data_source.dart';
import '../repositories/supabase_saved_looks_repository.dart';
import '../repositories/unavailable_saved_looks_repository.dart';

final savedLooksRevisionProvider = StateProvider<int>((ref) => 0);

final savedLooksRepositoryProvider = Provider<SavedLooksRepository>((ref) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const UnavailableSavedLooksRepository();
  }
  return SupabaseSavedLooksRepository(
    SupabaseSavedLooksRemoteDataSource(ref.watch(supabaseClientProvider)),
  );
});
