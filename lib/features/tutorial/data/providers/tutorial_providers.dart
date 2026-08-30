import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_availability_provider.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../../domain/repositories/look_plan_repository.dart';
import '../../domain/repositories/tutorial_manifest_repository.dart';
import '../../domain/repositories/tutorial_session_repository.dart';
import '../../domain/repositories/tutorial_step_repository.dart';
import '../../domain/usecases/resolve_tutorial_manifest.dart';
import '../data_sources/tutorial_remote_data_source.dart';
import '../repositories/supabase_tutorial_repositories.dart';
import '../repositories/supabase_tutorial_step_repository.dart';
import '../repositories/unavailable_tutorial_repositories.dart';
import '../../presentation/controllers/tutorial_controller.dart';
import '../../presentation/controllers/tutorial_state.dart';

final tutorialRemoteDataSourceProvider = Provider<TutorialRemoteDataSource?>((
  ref,
) {
  if (!ref.watch(supabaseAvailableProvider)) return null;
  return SupabaseTutorialRemoteDataSource(ref.watch(supabaseClientProvider));
});

final lookPlanRepositoryProvider = Provider<LookPlanRepository>((ref) {
  final remote = ref.watch(tutorialRemoteDataSourceProvider);
  if (remote == null) return const UnavailableLookPlanRepository();
  return SupabaseLookPlanRepository(remote);
});

final tutorialManifestRepositoryProvider = Provider<TutorialManifestRepository>(
  (ref) {
    final remote = ref.watch(tutorialRemoteDataSourceProvider);
    if (remote == null) return const UnavailableTutorialManifestRepository();
    return SupabaseTutorialManifestRepository(
      remote,
      ref.watch(lookPlanRepositoryProvider),
    );
  },
);

final tutorialSessionRepositoryProvider = Provider<TutorialSessionRepository>((
  ref,
) {
  final remote = ref.watch(tutorialRemoteDataSourceProvider);
  if (remote == null) return const UnavailableTutorialSessionRepository();
  return SupabaseTutorialSessionRepository(
    remote,
    ref.watch(lookPlanRepositoryProvider),
  );
});

/// Opening a tutorial goes through here so reuse is the default path.
///
/// Deliberately a plain Provider rather than a FutureProvider: a FutureProvider
/// runs on first watch, which would let a widget rebuild trigger paid manifest
/// analysis. Callers invoke this explicitly instead.
final resolveTutorialManifestProvider = Provider<ResolveTutorialManifest>((
  ref,
) {
  return ResolveTutorialManifest(
    manifestRepository: ref.watch(tutorialManifestRepositoryProvider),
    sessionRepository: ref.watch(tutorialSessionRepositoryProvider),
  );
});

final tutorialStepRepositoryProvider = Provider<TutorialStepRepository?>((ref) {
  final remote = ref.watch(tutorialRemoteDataSourceProvider);
  if (remote == null) return null;
  return SupabaseTutorialStepRepository(remote);
});

/// The orchestrator.
///
/// A `StateNotifierProvider`, not a `FutureProvider`: a FutureProvider runs on
/// first watch, which would let a widget build trigger paid manifest analysis.
/// This one starts idle and does nothing until a caller invokes `open()`.
final tutorialControllerProvider =
    StateNotifierProvider<TutorialController, TutorialViewState>((ref) {
      final steps = ref.watch(tutorialStepRepositoryProvider);
      return TutorialController(
        resolveManifest: ref.watch(resolveTutorialManifestProvider),
        steps: steps ?? const UnavailableTutorialStepRepository(),
      );
    });
