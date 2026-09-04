/** The three education subsections, in the order the Palette reads them.
 *
 * Each is capped at the same 240 characters as `reasoning`, which is the
 * project's existing budget for one explanatory sentence or two. The cap is
 * not cosmetic: ten categories times three unbounded strings is what would
 * push one response past the output-token limit and truncate the JSON.
 */
const educationProperties = {
  features: { type: "string", minLength: 20, maxLength: 240 },
  effect: { type: "string", minLength: 20, maxLength: 240 },
  style: { type: "string", minLength: 20, maxLength: 240 },
};

const educationSchema = {
  type: "object",
  additionalProperties: false,
  required: Object.keys(educationProperties),
  properties: educationProperties,
};

const itemProperties = {
  name: { type: "string", minLength: 2, maxLength: 80 },
  hex: {
    anyOf: [
      { type: "string", pattern: "^#[0-9A-F]{6}$" },
      { type: "null" },
    ],
  },
  placement: { type: "string", minLength: 3, maxLength: 220 },
  technique: { type: "string", minLength: 3, maxLength: 220 },
  finish: { type: "string", minLength: 2, maxLength: 80 },
  intensity: { type: "string", enum: ["sheer", "soft", "medium", "bold"] },
  reasoning: { type: "string", minLength: 3, maxLength: 240 },
  education: educationSchema,
};

const itemSchema = {
  type: "object",
  additionalProperties: false,
  required: Object.keys(itemProperties),
  properties: itemProperties,
};

const categories = [
  "foundation",
  "concealer",
  "contour",
  "highlight",
  "blush",
  "eyeshadow",
  "eyebrow",
  "eyeliner",
  "lipstick",
  "lipGloss",
];

export const MAKEUP_RECOMMENDATION_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [...categories, "overallIntensity"],
  properties: {
    ...Object.fromEntries(categories.map((category) => [category, itemSchema])),
    overallIntensity: {
      type: "string",
      enum: ["sheer", "soft", "medium", "bold"],
    },
  },
};
