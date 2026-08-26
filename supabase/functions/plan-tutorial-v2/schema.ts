import { ALLOWED_INTENSITIES, CATEGORY_RANKS } from "./types.ts";

const nullableString = (maxLength: number) => ({
  anyOf: [
    { type: "string", minLength: 2, maxLength },
    { type: "null" },
  ],
});

const stepProperties = {
  category: { type: "string", enum: Object.keys(CATEGORY_RANKS) },
  title: { type: "string", minLength: 2, maxLength: 60 },
  whatToApply: { type: "string", minLength: 3, maxLength: 200 },
  whereToApply: { type: "string", minLength: 3, maxLength: 200 },
  direction: { type: "string", minLength: 3, maxLength: 200 },
  technique: { type: "string", minLength: 3, maxLength: 240 },
  intensity: { type: "string", enum: ALLOWED_INTENSITIES },
  faceRationale: { type: "string", minLength: 10, maxLength: 240 },
  targetLookCues: { type: "string", minLength: 3, maxLength: 240 },
  amount: nullableString(120),
  toolSuggestion: nullableString(120),
  personalizedTip: nullableString(200),
  avoid: nullableString(200),
  productId: {
    anyOf: [
      { type: "string", minLength: 1, maxLength: 64 },
      { type: "null" },
    ],
  },
};

const stepSchema = {
  type: "object",
  additionalProperties: false,
  // Every field is required so the model cannot silently drop one; the
  // optional ones are required to be present as explicit nulls.
  required: Object.keys(stepProperties),
  properties: stepProperties,
};

/**
 * The planner's structured output contract.
 *
 * `step_index` is deliberately absent: the server assigns indexes from array
 * order, so the model cannot claim a position that disagrees with the
 * sequence it actually produced.
 */
export const TUTORIAL_V2_PLAN_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["steps"],
  properties: {
    steps: {
      type: "array",
      // At minimum one makeup step plus the terminal final look. The upper
      // bound is every makeup category plus the final look.
      minItems: 2,
      maxItems: Object.keys(CATEGORY_RANKS).length,
      items: stepSchema,
    },
  },
};
