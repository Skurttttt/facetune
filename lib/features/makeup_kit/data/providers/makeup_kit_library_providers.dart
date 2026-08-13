import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_availability_provider.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../../domain/repositories/makeup_kit_library_repository.dart';
import '../data_sources/makeup_kit_library_remote_data_source.dart';
import '../repositories/supabase_makeup_kit_library_repository.dart';
import '../repositories/unavailable_makeup_kit_library_repository.dart';

final makeupKitLibraryRevisionProvider = StateProvider<int>((ref) => 0);

final makeupKitLibraryRepositoryProvider = Provider<MakeupKitLibraryRepository>(
  (ref) {
    if (!ref.watch(supabaseAvailableProvider)) {
      return const UnavailableMakeupKitLibraryRepository();
    }
    return SupabaseMakeupKitLibraryRepository(
      SupabaseMakeupKitLibraryRemoteDataSource(
        ref.watch(supabaseClientProvider),
      ),
    );
  },
);
