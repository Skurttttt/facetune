import '../entities/tutorial_v3_category.dart';
import '../entities/tutorial_v3_geometry.dart';

/// Asks the server to map geometry for one already-planned step.
///
/// The port takes **identifiers only**. Everything the mapping depends on —
/// the original selfie, the persisted Step Spec, the scoped face attributes,
/// the Kit product, the source mode — is resolved server-side from persisted
/// rows under the caller's own JWT. There is deliberately no parameter here
/// for a prompt, a spec, an image, or another step's geometry, because none of
/// those may ever come from the client.
///
/// [expectedCategory] is not sent. It comes from the caller's own persisted
/// Step Spec and is used to check the returned document describes the step it
/// was asked about.
abstract interface class TutorialV3GeometryMapper {
  /// Returns validated geometry for the step, whether the server mapped it
  /// now or reused what it had already stored.
  ///
  /// Throws `TutorialV3Failure` when the step cannot be prepared. The server's
  /// own retry verdict is preserved, so a validation failure is not retried
  /// into the step's bounded attempt budget.
  Future<TutorialV3Geometry> map({
    required String sessionId,
    required int stepIndex,
    required TutorialV3Category expectedCategory,
  });
}
