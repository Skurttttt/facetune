import '../../domain/repositories/tutorial_v3_planner.dart';
import '../data_sources/tutorial_v3_function_data_source.dart';

/// Plans a tutorial through the `plan-tutorial-v3` Edge Function.
///
/// The response body is intentionally discarded. The function has already
/// written the plan through `persist_tutorial_v3_plan`, so the caller reloads
/// the session from the database rather than reconstructing it from a payload
/// that would then have to be trusted and validated a second time.
class SupabaseTutorialV3Planner implements TutorialV3Planner {
  const SupabaseTutorialV3Planner(this._functions);

  final TutorialV3FunctionDataSource _functions;

  @override
  Future<void> plan({required String sessionId}) async {
    await _functions.plan(sessionId: sessionId);
  }
}
