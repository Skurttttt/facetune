import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_availability_provider.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../domain/repositories/tutorial_v3_geometry_mapper.dart';
import '../../domain/repositories/tutorial_v3_planner.dart';
import '../../domain/repositories/tutorial_v3_repository.dart';
import '../../domain/services/tutorial_v3_geometry_coordinator.dart';
import '../../presentation/controllers/tutorial_v3_session_controller.dart';
import '../../presentation/controllers/tutorial_v3_session_state.dart';
import '../data_sources/tutorial_v3_function_data_source.dart';
import '../data_sources/tutorial_v3_remote_data_source.dart';
import '../repositories/supabase_tutorial_v3_geometry_mapper.dart';
import '../repositories/supabase_tutorial_v3_planner.dart';
import '../repositories/supabase_tutorial_v3_repository.dart';
import '../repositories/unavailable_tutorial_v3_repository.dart';
import '../repositories/unavailable_tutorial_v3_services.dart';

final tutorialV3RepositoryProvider = Provider<TutorialV3Repository>((ref) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const UnavailableTutorialV3Repository();
  }
  return SupabaseTutorialV3Repository(
    SupabaseTutorialV3RemoteDataSource(ref.watch(supabaseClientProvider)),
  );
});

final tutorialV3FunctionDataSourceProvider =
    Provider<TutorialV3FunctionDataSource>(
      (ref) => SupabaseTutorialV3FunctionDataSource(
        ref.watch(supabaseClientProvider),
      ),
    );

final tutorialV3PlannerProvider = Provider<TutorialV3Planner>((ref) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const UnavailableTutorialV3Planner();
  }
  return SupabaseTutorialV3Planner(
    ref.watch(tutorialV3FunctionDataSourceProvider),
  );
});

final tutorialV3GeometryMapperProvider = Provider<TutorialV3GeometryMapper>((
  ref,
) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const UnavailableTutorialV3GeometryMapper();
  }
  return SupabaseTutorialV3GeometryMapper(
    ref.watch(tutorialV3FunctionDataSourceProvider),
  );
});

/// The geometry cache lives here, above the controller.
///
/// Keeping it at provider scope is what makes leaving a tutorial and coming
/// back free: the controller can be disposed and rebuilt while the validated
/// documents stay in memory. It is rebuilt when the signed-in user changes, so
/// one account's geometry is never served to another.
final tutorialV3GeometryCoordinatorProvider =
    Provider<TutorialV3GeometryCoordinator>((ref) {
      ref.watch(authControllerProvider.select((state) => state.user?.id));
      return TutorialV3GeometryCoordinator(
        ref.watch(tutorialV3GeometryMapperProvider),
      );
    });

final tutorialV3SessionControllerProvider =
    StateNotifierProvider<TutorialV3SessionController, TutorialV3SessionState>((
      ref,
    ) {
      ref.watch(authControllerProvider.select((state) => state.user?.id));
      return TutorialV3SessionController(
        repository: ref.watch(tutorialV3RepositoryProvider),
        planner: ref.watch(tutorialV3PlannerProvider),
        coordinator: ref.watch(tutorialV3GeometryCoordinatorProvider),
      );
    });
