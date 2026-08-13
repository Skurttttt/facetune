export const KIT_MAKEUP_RECOMMENDATION_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["selections", "overallIntensity", "summary"],
  properties: {
    selections: {
      type: "array",
      minItems: 1,
      maxItems: 20,
      items: {
        type: "object",
        additionalProperties: false,
        required: [
          "productId",
          "category",
          "colorHex",
          "finish",
          "placement",
          "technique",
          "intensity",
          "reasoning",
        ],
        properties: {
          productId: { type: "string" },
          category: { type: "string" },
          colorHex: { type: "string", pattern: "^#[0-9A-F]{6}$" },
          finish: { type: "string" },
          placement: { type: "string", minLength: 3, maxLength: 220 },
          technique: { type: "string", minLength: 3, maxLength: 220 },
          intensity: {
            type: "string",
            enum: ["sheer", "soft", "medium", "bold"],
          },
          reasoning: { type: "string", minLength: 3, maxLength: 240 },
        },
      },
    },
    overallIntensity: {
      type: "string",
      enum: ["sheer", "soft", "medium", "bold"],
    },
    summary: { type: "string", minLength: 3, maxLength: 300 },
  },
};
