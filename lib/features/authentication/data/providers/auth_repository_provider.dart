import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_availability_provider.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../../domain/repositories/auth_repository.dart';
import '../data_sources/auth_remote_data_source.dart';
import '../repositories/supabase_auth_repository.dart';
import '../repositories/unavailable_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const UnavailableAuthRepository();
  }
  final dataSource = SupabaseAuthRemoteDataSource(
    ref.watch(supabaseClientProvider),
  );
  return SupabaseAuthRepository(dataSource);
});
