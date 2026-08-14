import '../entities/tutorial_placement_metadata.dart';
import '../entities/tutorial_step_category.dart';

/// Default, category-typical placement overlay for each makeup category
/// (FACETUNE_STEP_BY_STEP_TUTORIAL_GUIDE.md §7).
///
/// LIMITATION — read before relying on these coordinates for anything
/// user-facing beyond a rough visual guide: this app has no per-user face
/// landmark source. Gemini's face analysis (CODEX_MASTER_GUIDE.md §8)
/// returns categorical attributes (face shape, skin tone, ...), not pixel
/// or normalized landmark coordinates. The points below are therefore
/// illustrative approximations for a roughly front-facing, centered
/// portrait crop — not measured from any real face — and exist so the
/// tutorial viewer has *some* honest, conservative guidance to show today
/// rather than nothing. A future phase with real landmark data (from
/// Gemini or an on-device face-geometry source) should replace per-step
/// data with precise, user-specific coordinates; this catalog is the
/// fallback for when that per-step data does not exist, not a permanent
/// source of truth.
///
/// Every entry uses the same two general shapes practically all these
/// guides need: [TutorialPlacementOverlayType.zone] anchored by either one
/// point (a soft circle) or two points (a capsule between them), and short
/// [TutorialPlacementOverlayType.arrow]/[TutorialPlacementOverlayType.line]
/// segments for direction/path guidance. Kept deliberately simple per
/// guide §7's "avoid visual clutter" instruction — each category gets at
/// most a handful of overlays, not an anatomically exhaustive diagram.
abstract final class TutorialPlacementOverlayCatalog {
  /// Returns the default overlay set for [category], or an empty overlay
  /// list for categories with no placement guidance (currently only
  /// [TutorialStepCategory.finalLook], which has no single application
  /// zone of its own).
  static TutorialPlacementMetadata defaultFor(TutorialStepCategory category) {
    final overlays = _byCategory[category];
    return TutorialPlacementMetadata(overlays: overlays ?? const []);
  }

  static const _byCategory =
      <TutorialStepCategory, List<TutorialPlacementOverlay>>{
        TutorialStepCategory.foundation: [
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.zone,
            points: [
              TutorialPlacementPoint(0.5, 0.2),
              TutorialPlacementPoint(0.5, 0.8),
            ],
            label: 'Whole-face coverage',
          ),
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.arrow,
            points: [
              TutorialPlacementPoint(0.5, 0.5),
              TutorialPlacementPoint(0.68, 0.5),
            ],
            label: 'Blend outward',
          ),
        ],
        TutorialStepCategory.concealer: [
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.zone,
            points: [
              TutorialPlacementPoint(0.35, 0.42),
              TutorialPlacementPoint(0.45, 0.42),
            ],
            label: 'Under-eye',
          ),
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.zone,
            points: [
              TutorialPlacementPoint(0.55, 0.42),
              TutorialPlacementPoint(0.65, 0.42),
            ],
            label: 'Under-eye',
          ),
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.zone,
            points: [
              TutorialPlacementPoint(0.47, 0.62),
              TutorialPlacementPoint(0.53, 0.62),
            ],
            label: 'Chin',
          ),
        ],
        TutorialStepCategory.contour: [
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.zone,
            points: [
              TutorialPlacementPoint(0.22, 0.32),
              TutorialPlacementPoint(0.28, 0.4),
            ],
            label: 'Temple',
          ),
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.zone,
            points: [
              TutorialPlacementPoint(0.72, 0.32),
              TutorialPlacementPoint(0.78, 0.4),
            ],
            label: 'Temple',
          ),
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.zone,
            points: [
              TutorialPlacementPoint(0.28, 0.55),
              TutorialPlacementPoint(0.42, 0.6),
            ],
            label: 'Under cheekbone',
          ),
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.zone,
            points: [
              TutorialPlacementPoint(0.58, 0.55),
              TutorialPlacementPoint(0.72, 0.6),
            ],
            label: 'Under cheekbone',
          ),
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.arrow,
            points: [
              TutorialPlacementPoint(0.3, 0.58),
              TutorialPlacementPoint(0.42, 0.6),
            ],
            label: 'Blend along cheekbone',
          ),
        ],
        TutorialStepCategory.blush: [
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.zone,
            points: [
              TutorialPlacementPoint(0.32, 0.48),
              TutorialPlacementPoint(0.4, 0.44),
            ],
            label: 'Upper cheek',
          ),
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.zone,
            points: [
              TutorialPlacementPoint(0.6, 0.48),
              TutorialPlacementPoint(0.68, 0.44),
            ],
            label: 'Upper cheek',
          ),
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.arrow,
            points: [
              TutorialPlacementPoint(0.36, 0.48),
              TutorialPlacementPoint(0.3, 0.36),
            ],
            label: 'Blend toward temple',
          ),
        ],
        TutorialStepCategory.highlighter: [
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.dot,
            points: [TutorialPlacementPoint(0.35, 0.46)],
            label: 'Cheekbone',
          ),
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.dot,
            points: [TutorialPlacementPoint(0.65, 0.46)],
            label: 'Cheekbone',
          ),
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.dot,
            points: [TutorialPlacementPoint(0.5, 0.5)],
            label: 'Nose bridge',
          ),
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.dot,
            points: [TutorialPlacementPoint(0.5, 0.66)],
            label: "Cupid's bow",
          ),
        ],
        TutorialStepCategory.eyeshadow: [
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.zone,
            points: [
              TutorialPlacementPoint(0.38, 0.38),
              TutorialPlacementPoint(0.44, 0.4),
            ],
            label: 'Lid',
          ),
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.zone,
            points: [
              TutorialPlacementPoint(0.56, 0.38),
              TutorialPlacementPoint(0.62, 0.4),
            ],
            label: 'Lid',
          ),
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.line,
            points: [
              TutorialPlacementPoint(0.37, 0.35),
              TutorialPlacementPoint(0.45, 0.35),
            ],
            label: 'Crease',
          ),
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.line,
            points: [
              TutorialPlacementPoint(0.55, 0.35),
              TutorialPlacementPoint(0.63, 0.35),
            ],
            label: 'Crease',
          ),
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.dot,
            points: [TutorialPlacementPoint(0.4, 0.4)],
            label: 'Inner corner',
          ),
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.dot,
            points: [TutorialPlacementPoint(0.6, 0.4)],
            label: 'Inner corner',
          ),
        ],
        TutorialStepCategory.eyeliner: [
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.line,
            points: [
              TutorialPlacementPoint(0.37, 0.4),
              TutorialPlacementPoint(0.44, 0.39),
              TutorialPlacementPoint(0.47, 0.4),
            ],
            label: 'Lash line and wing',
          ),
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.line,
            points: [
              TutorialPlacementPoint(0.53, 0.4),
              TutorialPlacementPoint(0.56, 0.39),
              TutorialPlacementPoint(0.63, 0.4),
            ],
            label: 'Lash line and wing',
          ),
        ],
        TutorialStepCategory.eyebrow: [
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.arrow,
            points: [
              TutorialPlacementPoint(0.35, 0.32),
              TutorialPlacementPoint(0.44, 0.3),
            ],
            label: 'Fill direction',
          ),
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.arrow,
            points: [
              TutorialPlacementPoint(0.65, 0.32),
              TutorialPlacementPoint(0.56, 0.3),
            ],
            label: 'Fill direction',
          ),
        ],
        TutorialStepCategory.lipstick: [
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.boundary,
            points: [
              TutorialPlacementPoint(0.42, 0.66),
              TutorialPlacementPoint(0.5, 0.64),
              TutorialPlacementPoint(0.58, 0.66),
              TutorialPlacementPoint(0.5, 0.72),
            ],
            label: 'Lip boundary',
          ),
        ],
        TutorialStepCategory.lipGloss: [
          TutorialPlacementOverlay(
            type: TutorialPlacementOverlayType.boundary,
            points: [
              TutorialPlacementPoint(0.42, 0.66),
              TutorialPlacementPoint(0.5, 0.64),
              TutorialPlacementPoint(0.58, 0.66),
              TutorialPlacementPoint(0.5, 0.72),
            ],
            label: 'Lip boundary',
          ),
        ],
      };
}
