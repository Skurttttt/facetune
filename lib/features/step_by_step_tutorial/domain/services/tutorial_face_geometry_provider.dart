import '../entities/tutorial_face_geometry.dart';

/// Tutorial-only boundary for retrieving real normalized face geometry.
///
/// Implementations must check approved, existing FaceTune data first. Returning
/// `null` is the correct result when no exact geometry exists. Implementations
/// must not turn semantic face attributes into pretend landmarks, and this
/// abstraction does not authorize MediaPipe, OpenCV, TFLite, or another face
/// analysis stack.
abstract interface class TutorialFaceGeometryProvider {
  Future<TutorialFaceGeometry?> loadForAnalysis(String analysisId);
}
