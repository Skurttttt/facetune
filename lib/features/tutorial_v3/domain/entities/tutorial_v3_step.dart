import 'tutorial_v3_geometry.dart';
import 'tutorial_v3_geometry_status.dart';
import 'tutorial_v3_step_spec.dart';

/// A persisted step: its validated Step Spec plus the runtime state of its
/// mapped geometry.
///
/// The two are separate on purpose. A failed mapping never rewrites the spec,
/// so retrying reuses the same instruction rather than re-planning, and ready
/// geometry is reused rather than re-mapped when the user revisits the step.
///
/// There is no image path here. V3 stores coordinates, not pixels: Flutter
/// renders the overlay from [geometry] over the untouched original selfie.
class TutorialV3Step {
  const TutorialV3Step({
    required this.spec,
    required this.geometryStatus,
    this.geometry,
    this.geometrySchemaVersion,
    this.attemptCount = 0,
    this.lastErrorCode,
  });

  /// A step that has been planned but not yet mapped.
  factory TutorialV3Step.planned(TutorialV3StepSpec spec) => TutorialV3Step(
    spec: spec,
    geometryStatus: spec.isFinalLook
        ? TutorialV3GeometryStatus.notRequired
        : TutorialV3GeometryStatus.pending,
  );

  final TutorialV3StepSpec spec;
  final TutorialV3GeometryStatus geometryStatus;

  /// The validated geometry, present only when the status is ready.
  ///
  /// It is decoded through `TutorialV3GeometryValidator`, so a document that
  /// would not pass validation never becomes a non-null value here.
  final TutorialV3Geometry? geometry;

  /// The schema version the stored document was written against.
  ///
  /// Kept alongside [geometry] so a row written by a future build can be
  /// recognised as incompatible instead of being rendered with this build's
  /// assumptions.
  final int? geometrySchemaVersion;

  /// How many mapping attempts have been made, for bounded retry.
  final int attemptCount;

  /// The last failure code, kept so a retry can be reported honestly rather
  /// than silently substituting a placeholder overlay.
  final String? lastErrorCode;

  int get stepIndex => spec.stepIndex;

  bool get isFinalLook => spec.isFinalLook;

  /// Whether this step can be rendered with its overlay.
  bool get hasGeometry =>
      geometryStatus == TutorialV3GeometryStatus.ready && geometry != null;

  /// Whether stored geometry exists but was written against a schema this
  /// build cannot render.
  ///
  /// Surfaced explicitly rather than silently re-mapped, so a caller can
  /// choose to refresh instead of the app quietly discarding stored work.
  bool get hasStaleGeometry =>
      geometrySchemaVersion != null &&
      geometrySchemaVersion != tutorialV3GeometrySchemaVersion;
}
