import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_availability_provider.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../../domain/repositories/tutorial_v2_repository.dart';
import '../data_sources/tutorial_v2_remote_data_source.dart';
import '../repositories/supabase_tutorial_v2_repository.dart';
import '../repositories/unavailable_tutorial_v2_repository.dart';

final tutorialV2RepositoryProvider = Provider<TutorialV2Repository>((ref) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const UnavailableTutorialV2Repository();
  }
  return SupabaseTutorialV2Repository(
    SupabaseTutorialV2RemoteDataSource(ref.watch(supabaseClientProvider)),
  );
});
