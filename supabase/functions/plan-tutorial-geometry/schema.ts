/** Canonical step categories, matching `TutorialStepCategory.code` on the
 * Flutter side and `tutorial_steps_category_valid` in
 * 20260814000300_tutorial_sessions_steps.sql exactly, minus `final_look`
 * (the final step reuses an existing preview and is never an application
 * placement step -- `PersonalizedTutorialPlacementRules` already encodes
 * the identical exclusion on the Flutter side). */
export const CANONICAL_TUTORIAL_CATEGORIES = [
  "foundation",
  "concealer",
  "contour",
  "highlighter",
  "blush",
  "eyeshadow",
  "eyebrow",
  "eyeliner",
  "lipstick",
  "lip_gloss",
] as const;

/** Matches `TutorialDirection.values.map((v) => v.name)` on the Flutter side
 * (`personalized_tutorial.dart`) exactly -- camelCase, not snake_case,
 * because that is the literal string `PersonalizedTutorialStepSpecCodec`
 * already persists for `personalized_spec_json.how.direction`. Using the
 * same vocabulary here means a later phase can map this plan's `direction`
 * onto `TutorialDirection` with a plain string match, no case conversion. */
export const TUTORIAL_DIRECTION_VALUES = [
  "none",
  "outward",
  "upward",
  "upwardOutward",
  "inward",
  "downward",
  "horizontal",
  "followBoundary",
] as const;

/** Matches `TutorialIntensity.values.map((v) => v.name)` for the same
 * reason as `TUTORIAL_DIRECTION_VALUES`. */
export const TUTORIAL_INTENSITY_VALUES = [
  "sheer",
  "light",
  "medium",
  "strong",
] as const;

const GEOMETRY_POINT_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["x", "y"],
  properties: {
    x: { type: "number", minimum: 0, maximum: 1 },
    y: { type: "number", minimum: 0, maximum: 1 },
  },
};

const GEOMETRY_ZONE_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["shape", "points", "confidence"],
  properties: {
    shape: {
      type: "string",
      enum: ["ellipse", "polygon", "soft_band", "region"],
    },
    points: { type: "array", items: GEOMETRY_POINT_SCHEMA },
    confidence: { type: "number", minimum: 0, maximum: 1 },
  },
};

const GEOMETRY_PATH_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["points", "confidence"],
  properties: {
    points: { type: "array", items: GEOMETRY_POINT_SCHEMA },
    confidence: { type: "number", minimum: 0, maximum: 1 },
  },
};

const GEOMETRY_ARROW_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["from", "to", "confidence"],
  properties: {
    from: GEOMETRY_POINT_SCHEMA,
    to: GEOMETRY_POINT_SCHEMA,
    confidence: { type: "number", minimum: 0, maximum: 1 },
  },
};

export const TUTORIAL_GEOMETRY_PLAN_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["steps"],
  properties: {
    steps: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: [
          "category",
          "placement",
          "direction",
          "intensity",
          "technique",
          "confidence",
          "colorHex",
          "finish",
          "zones",
          "paths",
          "arrows",
        ],
        properties: {
          category: { type: "string", enum: CANONICAL_TUTORIAL_CATEGORIES },
          placement: { type: "string" },
          direction: { type: "string", enum: TUTORIAL_DIRECTION_VALUES },
          intensity: { type: "string", enum: TUTORIAL_INTENSITY_VALUES },
          technique: { type: "string" },
          confidence: { type: "number", minimum: 0, maximum: 1 },
          colorHex: { anyOf: [{ type: "string" }, { type: "null" }] },
          finish: { anyOf: [{ type: "string" }, { type: "null" }] },
          zones: { type: "array", items: GEOMETRY_ZONE_SCHEMA },
          paths: { type: "array", items: GEOMETRY_PATH_SCHEMA },
          arrows: { type: "array", items: GEOMETRY_ARROW_SCHEMA },
        },
      },
    },
  },
};
