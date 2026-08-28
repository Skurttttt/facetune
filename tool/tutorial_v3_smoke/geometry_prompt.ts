/**
 * V3-6R — geometry mapper prompt.
 *
 * The model is framed as a MEASURER, not an artist and not a planner. It is
 * shown the selfie and told exactly what instruction has already been decided,
 * and asked only: where on this face, in normalized coordinates.
 *
 * It cannot return an image, text, colour, opacity or style — there is no
 * field for any of those in the schema, and the prompt says so explicitly.
 */

export const GEOMETRY_PROMPT_VERSION = "v3-geometry-mapper-1";

export type GeometryRole =
  | "coverage_zone"
  | "placement_zone"
  | "application_path"
  | "blend_direction"
  | "boundary"
  | "exclusion"
  | "focus_marker";

export type PrimitiveKind =
  | "region"
  | "ellipse"
  | "polyline"
  | "arrow"
  | "marker";

/** Mirrors `TutorialV3GeometryCatalog._rolePrimitives` in Dart. */
export const ROLE_KINDS: Record<GeometryRole, PrimitiveKind[]> = {
  coverage_zone: ["region", "ellipse"],
  placement_zone: ["region", "ellipse"],
  application_path: ["polyline"],
  blend_direction: ["arrow"],
  boundary: ["polyline", "region"],
  exclusion: ["region", "ellipse"],
  focus_marker: ["marker"],
};

/** Mirrors `TutorialV3GeometryCatalog._categoryRoles` in Dart. */
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
};

export interface GeometrySpec {
  /** Fixture identity, used for evidence filenames. */
  id: string;
  category: string;
  whereToApply: string;
  direction: string;
  technique: string;
  coverage?: string | null;
  intensity?: string | null;
  faceAttributes: Record<string, string>;
}

function optional(label: string, value?: string | null): string[] {
  if (value === undefined || value === null || value.trim().length === 0) {
    return [];
  }
  return [`${label}: ${value}`];
}

export function geometryMapperPrompt(spec: GeometrySpec): string {
  const roles = CATEGORY_ROLES[spec.category] ?? [];
  const roleLines = roles.map(
    (role) => `- "${role}" — allowed kinds: ${ROLE_KINDS[role].join(", ")}`,
  );

  return [
    "You are a GEOMETRY MAPPER for a makeup tutorial.",
    "",
    "You are not designing makeup. You are not choosing placement strategy.",
    "You are not drawing anything, and you are not returning an image.",
    "",
    "The makeup decision has ALREADY been made and is written in the",
    "INSTRUCTION below. Your only job is to locate that instruction on the",
    "attached photograph and return its coordinates.",
    "",
    "=== THE PHOTOGRAPH ===",
    "The attached image is the person this tutorial is for. Look at THIS face:",
    "the coordinates you return must land on this individual's features, not on",
    "a generic or averaged face. Two different faces must produce different",
    "numbers.",
    "",
    "You must not modify, describe, beautify or reproduce the photograph.",
    "You return numbers only.",
    "",
    "=== COORDINATE SYSTEM ===",
    "All coordinates are normalized against the ORIGINAL image:",
    "  x = 0.0 at the left edge, 1.0 at the right edge",
    "  y = 0.0 at the TOP edge, 1.0 at the bottom edge",
    "  origin is the TOP-LEFT corner",
    'coordinate_space must be exactly "normalized_original_image".',
    "Every x and y must be between 0 and 1 inclusive. Never output a value",
    "outside that range, and never output NaN or infinity.",
    "",
    "=== THE INSTRUCTION TO LOCATE ===",
    `CATEGORY: ${spec.category}`,
    `WHERE: ${spec.whereToApply}`,
    `DIRECTION: ${spec.direction}`,
    `TECHNIQUE: ${spec.technique}`,
    ...optional("COVERAGE", spec.coverage),
    ...optional("INTENSITY", spec.intensity),
    "",
    "RELEVANT FACE CONTEXT (explains the placement; never overrides it):",
    ...Object.entries(spec.faceAttributes).map(
      ([key, value]) => `- ${key.replace(/_/g, " ")}: ${value}`,
    ),
    "",
    "=== WHAT TO RETURN ===",
    `For "${spec.category}" you may use ONLY these roles:`,
    ...roleLines,
    "",
    "Primitive shapes:",
    '- "region": a closed polygon, 3–24 vertices, field "vertices"',
    '- "ellipse": fields "center", "radius_x", "radius_y", optional "rotation" (radians)',
    '- "polyline": an open path, 2–32 vertices, field "vertices"',
    '- "arrow": fields "start" and "end" — must be clearly apart, not the same point',
    '- "marker": a single point, field "position"',
    "",
    "Return at most 24 primitives. Use the fewest that express the instruction",
    "clearly — a placement zone plus a direction arrow is usually enough.",
    "",
    "If the instruction describes TWO separate areas (for example one per",
    "cheek), return TWO separate primitives. Never merge them into one shape",
    "that spans the middle of the face.",
    "",
    "=== YOU MUST NOT RETURN ===",
    "- image data of any kind",
    "- SVG, HTML, or any markup",
    "- code of any language",
    "- text, labels, captions or names for the shapes",
    "- colours, opacity, stroke widths, fonts, gradients or blend modes",
    "- animation or timing",
    "- any field not named in the schema",
    "",
    "The application chooses every colour and style itself. Supplying any of",
    "the above would be rejected.",
    "",
    "Return only the JSON object described by the schema.",
  ].join("\n");
}
