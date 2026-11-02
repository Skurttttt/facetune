/**
 * What the model may return. There is deliberately no color or finish field:
 * the frozen palette already holds those, and a value the model cannot return
 * is one that can never be mistaken for the user's choice.
 */
const intensity = {
  type: "string",
  enum: ["sheer", "soft", "medium", "bold"],
};

export const CUSTOM_PALETTE_RECOMMENDATION_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["applications", "overallIntensity", "summary"],
  properties: {
    applications: {
      type: "array",
      minItems: 1,
      maxItems: 4,
      items: {
        type: "object",
        additionalProperties: false,
        required: [
          "categoryCode",
          "placement",
          "technique",
          "intensity",
          "reasoning",
        ],
        properties: {
          categoryCode: {
            type: "string",
            enum: ["blush", "eyeshadow", "eyeliner", "lipstick"],
          },
          placement: { type: "string", minLength: 3, maxLength: 220 },
          technique: { type: "string", minLength: 3, maxLength: 220 },
          intensity,
          reasoning: { type: "string", minLength: 3, maxLength: 240 },
        },
      },
    },
    overallIntensity: intensity,
    summary: { type: "string", minLength: 3, maxLength: 300 },
  },
};
