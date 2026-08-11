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
