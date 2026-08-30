import { TUTORIAL_CATEGORIES } from "./types.ts";

/** Bumped whenever the response shape changes in a way that invalidates a
 * previously accepted manifest. Persisted with every manifest so a stored
 * result can be recognised as stale rather than silently reused. */
export const TUTORIAL_MANIFEST_SCHEMA_VERSION = "tutorial_manifest_schema_v1";

const verdict = {
  type: "object",
  additionalProperties: false,
  required: ["presence", "visualConfidence"],
  properties: {
    presence: { type: "string", enum: ["present", "absent", "uncertain"] },
    visualConfidence: {
      anyOf: [
        { type: "number", minimum: 0, maximum: 1 },
        { type: "null" },
      ],
    },
  },
};

/// One fixed property per supported category, all required.
///
/// The model is asked to judge exactly this set — it cannot add a category
/// because `additionalProperties` is false, and it cannot quietly skip one
/// because every key is required. That makes "invented category" and "missing
/// verdict" both schema violations rather than things validation has to
/// reconstruct after the fact.
export const TUTORIAL_MANIFEST_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [...TUTORIAL_CATEGORIES],
  properties: Object.fromEntries(
    TUTORIAL_CATEGORIES.map((category) => [category, verdict]),
  ),
};
