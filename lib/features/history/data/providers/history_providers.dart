import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_availability_provider.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../../domain/repositories/history_repository.dart';
import '../data_sources/history_remote_data_source.dart';
import '../repositories/supabase_history_repository.dart';
import '../repositories/unavailable_history_repository.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const UnavailableHistoryRepository();
  }
  return SupabaseHistoryRepository(
    SupabaseHistoryRemoteDataSource(ref.watch(supabaseClientProvider)),
  );
});
