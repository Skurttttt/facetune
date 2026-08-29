import '../../domain/entities/tutorial_v3_category.dart';
import '../../domain/entities/tutorial_v3_geometry.dart';
import '../../domain/errors/tutorial_v3_failure.dart';
import '../../domain/repositories/tutorial_v3_geometry_mapper.dart';
import '../../domain/validation/tutorial_v3_geometry_validator.dart';
import '../data_sources/tutorial_v3_function_data_source.dart';

/// Maps a step's geometry through the `map-tutorial-v3-guideline-geometry`
/// Edge Function and validates what comes back.
///
/// The server already validates before it persists. This validates again
/// because *this* build is the one that would draw the document, and a
/// renderer that trusts a response it did not check is a renderer that can be
/// made to draw anything.
class SupabaseTutorialV3GeometryMapper implements TutorialV3GeometryMapper {
  const SupabaseTutorialV3GeometryMapper(this._functions);

  final TutorialV3FunctionDataSource _functions;

  @override
  Future<TutorialV3Geometry> map({
    required String sessionId,
    required int stepIndex,
    required TutorialV3Category expectedCategory,
  }) async {
    final response = await _functions.mapGeometry(
      sessionId: sessionId,
      stepIndex: stepIndex,
    );

    final payload = response['geometry'];
    if (payload is! Map) {
      throw const TutorialV3Failure(
        'This step could not be prepared. Please try again.',
        kind: TutorialV3FailureKind.generation,
      );
    }

    // The expected category comes from the caller's persisted Step Spec, never
    // from the response, so a document for another category is rejected rather
    // than rendered over the wrong part of the face.
    return TutorialV3GeometryValidator.validate(
      payload.cast<String, Object?>(),
      expectedCategory: expectedCategory,
    );
  }
}
