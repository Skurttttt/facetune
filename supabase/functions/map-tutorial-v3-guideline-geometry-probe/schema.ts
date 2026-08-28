/**
 * The response schema handed to the geometry model.
 *
 * Deliberately restricted to the JSON-Schema constructs this project has
 * PROVEN the API accepts — the same set `generate-makeup-recommendation` uses
 * in production: `type`, `properties`, `required`, `additionalProperties`,
 * string `enum`, and `anyOf`.
 *
 * An earlier version of this file also used `type: "integer"`, integer `enum`,
 * `minimum`/`maximum` and `minItems`/`maxItems`. Every request was rejected
 * with `400 INVALID_ARGUMENT`, so those constructs are not usable here.
 *
 * Numeric ranges, vertex counts, primitive counts and role/kind compatibility
 * are therefore NOT expressed in the schema. They are enforced — strictly, and
 * without clamping — by `TutorialV3GeometryValidator` in Dart. The schema's
 * job is to pin the vocabulary and to make clear there is no field for text,
 * colour, style or image data.
 */

const pointSchema = {
  type: "object",
  additionalProperties: false,
  required: ["x", "y"],
  properties: {
    x: { type: "number" },
    y: { type: "number" },
  },
};

const primitiveSchema = {
  type: "object",
  additionalProperties: false,
  required: ["kind", "role"],
  properties: {
    kind: {
      type: "string",
      enum: ["region", "ellipse", "polyline", "arrow", "marker"],
    },
    role: {
      type: "string",
      enum: [
        "coverage_zone",
        "placement_zone",
        "application_path",
        "blend_direction",
        "boundary",
        "exclusion",
        "focus_marker",
      ],
    },
    vertices: { type: "array", items: pointSchema },
    center: pointSchema,
    radius_x: { type: "number" },
    radius_y: { type: "number" },
    rotation: { type: "number" },
    start: pointSchema,
    end: pointSchema,
    position: pointSchema,
  },
};

export const TUTORIAL_V3_GEOMETRY_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["schema_version", "category", "coordinate_space", "primitives"],
  properties: {
    schema_version: { type: "number" },
    category: { type: "string" },
    coordinate_space: {
      type: "string",
      enum: ["normalized_original_image"],
    },
    primitives: { type: "array", items: primitiveSchema },
  },
} as const;
