const confidenceProperties = {
  faceShape: { type: "number", minimum: 0, maximum: 1 },
  skinTone: { type: "number", minimum: 0, maximum: 1 },
  undertone: { type: "number", minimum: 0, maximum: 1 },
  eyeShape: { type: "number", minimum: 0, maximum: 1 },
  lipShape: { type: "number", minimum: 0, maximum: 1 },
  hairColor: { type: "number", minimum: 0, maximum: 1 },
  eyeColor: { type: "number", minimum: 0, maximum: 1 },
};

const requiredAttributes = [
  "faceShape",
  "skinTone",
  "undertone",
  "eyeShape",
  "lipShape",
  "hairColor",
  "eyeColor",
];

export const FACE_ANALYSIS_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["imageValid", "validation", "analysis", "confidence"],
  properties: {
    imageValid: { type: "boolean" },
    validation: {
      type: "object",
      additionalProperties: false,
      required: [
        "faceCount",
        "lightingAcceptable",
        "sharpnessAcceptable",
        "faceVisible",
        "framingAcceptable",
      ],
      properties: {
        faceCount: { type: "integer", minimum: 0, maximum: 10 },
        lightingAcceptable: { type: "boolean" },
        sharpnessAcceptable: { type: "boolean" },
        faceVisible: { type: "boolean" },
        framingAcceptable: { type: "boolean" },
      },
    },
    analysis: {
      anyOf: [
        {
          type: "object",
          additionalProperties: false,
          required: requiredAttributes,
          properties: {
            faceShape: {
              type: "string",
              enum: [
                "oval",
                "round",
                "square",
                "heart",
                "oblong",
                "diamond",
                "triangle",
              ],
            },
            skinTone: {
              type: "string",
              enum: [
                "very_light",
                "light",
                "medium",
                "tan",
                "deep",
                "very_deep",
              ],
            },
            undertone: {
              type: "string",
              enum: ["warm", "cool", "neutral", "olive"],
            },
            eyeShape: {
              type: "string",
              enum: [
                "almond",
                "round",
                "hooded",
                "monolid",
                "upturned",
                "downturned",
                "deep_set",
                "protruding",
              ],
            },
            lipShape: {
              type: "string",
              enum: ["thin", "medium", "full", "heart_shaped", "wide", "round"],
            },
            hairColor: {
              type: "string",
              enum: [
                "black",
                "dark_brown",
                "brown",
                "light_brown",
                "blonde",
                "red",
                "gray",
                "white",
                "other",
              ],
            },
            eyeColor: {
              type: "string",
              enum: [
                "dark_brown",
                "brown",
                "hazel",
                "amber",
                "green",
                "blue",
                "gray",
                "other",
              ],
            },
          },
        },
        { type: "null" },
      ],
    },
    confidence: {
      anyOf: [
        {
          type: "object",
          additionalProperties: false,
          required: requiredAttributes,
          properties: confidenceProperties,
        },
        { type: "null" },
      ],
    },
  },
};
