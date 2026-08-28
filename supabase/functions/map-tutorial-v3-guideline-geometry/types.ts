export class FunctionFailure extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly retryable = false,
  ) {
    super(message);
  }
}

export const FINAL_LOOK = "final_look";

/** Must match `tutorialV3GeometrySchemaVersion` in Dart. */
export const GEOMETRY_SCHEMA_VERSION = 1;

/** Must match `tutorialV3CoordinateSpace` in Dart. */
export const COORDINATE_SPACE = "normalized_original_image";

export type PrimitiveKind =
  | "region"
  | "ellipse"
  | "polyline"
  | "arrow"
  | "marker";

export type GeometryRole =
  | "coverage_zone"
  | "placement_zone"
  | "application_path"
  | "blend_direction"
  | "boundary"
  | "exclusion"
  | "focus_marker";

/**
 * Mirrors `TutorialV3GeometryCatalog._rolePrimitives`.
 *
 * A direction must be an arrow; a path must be a polyline. Category-independent.
 */
export const ROLE_KINDS: Record<GeometryRole, PrimitiveKind[]> = {
  coverage_zone: ["region", "ellipse"],
  placement_zone: ["region", "ellipse"],
  application_path: ["polyline"],
  blend_direction: ["arrow"],
  boundary: ["polyline", "region"],
  exclusion: ["region", "ellipse"],
  focus_marker: ["marker"],
};

/**
 * Mirrors `TutorialV3GeometryCatalog._categoryRoles`.
 *
 * Keeps one step from teaching another category's technique: eyeliner cannot
 * emit a full-face coverage zone, foundation cannot emit a lash-line path.
 */
export const CATEGORY_ROLES: Record<string, GeometryRole[]> = {
  foundation: ["coverage_zone", "blend_direction", "exclusion"],
  concealer: ["placement_zone", "blend_direction", "focus_marker"],
  contour_bronzer: ["placement_zone", "blend_direction", "boundary"],
  blush: ["placement_zone", "blend_direction"],
  highlighter: ["placement_zone", "focus_marker"],
  eyebrow: ["application_path", "boundary", "blend_direction"],
  eyeshadow: ["placement_zone", "blend_direction", "boundary"],
  eyeliner: ["application_path", "blend_direction", "focus_marker"],
  lipstick: ["boundary", "coverage_zone", "application_path"],
  lip_gloss: ["placement_zone", "application_path", "focus_marker"],
  final_look: [],
};

/** Mirrors `TutorialV3GeometryCatalog` limits. */
export const LIMITS = {
  maxPrimitives: 24,
  minRegionVertices: 3,
  maxRegionVertices: 24,
  minPolylineVertices: 2,
  maxPolylineVertices: 32,
  minRadius: 0.005,
  maxRadius: 0.6,
  minArrowLength: 0.01,
} as const;

/** The attributes any V3 category may reason about. */
export const SCOPED_ATTRIBUTES: Record<string, string[]> = {
  foundation: ["skin_tone", "undertone"],
  concealer: ["eye_shape", "skin_tone"],
  contour_bronzer: ["face_shape"],
  blush: ["face_shape"],
  highlighter: ["face_shape"],
  eyebrow: ["face_shape"],
  eyeshadow: ["eye_shape"],
  eyeliner: ["eye_shape"],
  lipstick: ["lip_shape"],
  lip_gloss: ["lip_shape"],
};

export type SourceMode = "standard" | "makeup_kit";
