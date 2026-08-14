import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_availability_provider.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../../domain/repositories/tutorial_repository.dart';
import '../../domain/usecases/get_or_create_tutorial_session.dart';
import '../data_sources/tutorial_remote_data_source.dart';
import '../repositories/supabase_tutorial_repository.dart';
import '../repositories/unavailable_tutorial_repository.dart';

final tutorialRepositoryProvider = Provider<TutorialRepository>((ref) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const UnavailableTutorialRepository();
  }
  return SupabaseTutorialRepository(
    SupabaseTutorialRemoteDataSource(ref.watch(supabaseClientProvider)),
  );
});

final getOrCreateTutorialSessionProvider = Provider(
  (ref) => GetOrCreateTutorialSession(ref.watch(tutorialRepositoryProvider)),
);
