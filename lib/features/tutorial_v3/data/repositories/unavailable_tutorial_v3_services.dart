import '../../domain/entities/tutorial_v3_category.dart';
import '../../domain/entities/tutorial_v3_geometry.dart';
import '../../domain/errors/tutorial_v3_failure.dart';
import '../../domain/repositories/tutorial_v3_geometry_mapper.dart';
import '../../domain/repositories/tutorial_v3_planner.dart';

const _unavailable = TutorialV3Failure(
  'Tutorials are unavailable right now. Please try again later.',
  kind: TutorialV3FailureKind.unavailable,
);

/// Stand-in used when the Supabase runtime is not configured.
///
/// Fails loudly and retryably rather than pretending to plan, so a
/// misconfigured build cannot present an empty tutorial as a real one.
class UnavailableTutorialV3Planner implements TutorialV3Planner {
  const UnavailableTutorialV3Planner();

  @override
  Future<void> plan({required String sessionId}) => throw _unavailable;
}

/// Stand-in used when the Supabase runtime is not configured.
class UnavailableTutorialV3GeometryMapper implements TutorialV3GeometryMapper {
  const UnavailableTutorialV3GeometryMapper();

  @override
  Future<TutorialV3Geometry> map({
    required String sessionId,
    required int stepIndex,
    required TutorialV3Category expectedCategory,
  }) => throw _unavailable;
}
