/// Overlay primitive kinds a placement image can be annotated with.
///
/// See FACETUNE_STEP_BY_STEP_TUTORIAL_GUIDE.md §6-7 for the category-specific
/// overlay catalog these render (translucent zones, blend-direction arrows,
/// eyeshadow shade zones, lash-line paths, and similar).
///
/// [code] is the stable identifier persisted inside
/// `tutorial_steps.placement_metadata_json`. It is spelled out explicitly
/// rather than derived from the Dart member name, matching every other
/// persisted enum in this codebase (e.g. `MakeupKitCategory.code`) — a
/// future rename of an enum member must not silently change stored data.
enum TutorialPlacementOverlayType {
  zone('zone'),
  line('line'),
  arrow('arrow'),
  dot('dot'),
  boundary('boundary'),
  label('label');

  const TutorialPlacementOverlayType(this.code);

  final String code;

  static TutorialPlacementOverlayType? fromCode(String code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// A single point in an overlay, normalized to the `0.0`–`1.0` range of the
/// placement image's width/height.
///
/// Normalized rather than pixel coordinates so overlays stay valid
/// regardless of the configurable tutorial image resolution
/// (guide §5.2 — 512px initially, movable to 1K later without restructuring
/// the feature).
class TutorialPlacementPoint {
  const TutorialPlacementPoint(this.x, this.y);

  final double x;
  final double y;
}

/// One instructional overlay drawn on top of a step's placement image.
///
/// Rendering is out of scope for this phase; this is a data contract only,
/// consistent with FACETUNE_STEP_BY_STEP_TUTORIAL_GUIDE.md §6, which
/// requires the overlay system to be "data-driven and category-specific"
/// and rendered by FaceTune rather than paid for as a second Gemini image.
class TutorialPlacementOverlay {
  const TutorialPlacementOverlay({
    required this.type,
    required this.points,
    this.label,
    this.colorHex,
  });

  final TutorialPlacementOverlayType type;
  final List<TutorialPlacementPoint> points;
  final String? label;
  final String? colorHex;
}

/// The full set of overlays for one tutorial step's placement image.
class TutorialPlacementMetadata {
  const TutorialPlacementMetadata({required this.overlays});

  final List<TutorialPlacementOverlay> overlays;
}
