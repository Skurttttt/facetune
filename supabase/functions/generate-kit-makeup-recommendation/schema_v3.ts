import {
  ALL_ROLES,
  COMPLEXION_CATEGORIES,
  INTENSITIES,
  INVENTORY_CATEGORIES,
  OMISSION_REASONS,
} from "../_shared/kit_makeup_plan.ts";

/** The model's response contract for `kit_makeup_recommendation_v3`. Enums are
 * generated from the plan tables so the two cannot drift. */
export const KIT_MAKEUP_RECOMMENDATION_V3_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [
    "selections",
    "complexionOmissions",
    "overallIntensity",
    "summary",
  ],
  properties: {
    selections: {
      type: "array",
      minItems: 1,
      maxItems: 13,
      items: {
        type: "object",
        additionalProperties: false,
        required: [
          "productId",
          "category",
          "role",
          "placement",
          "technique",
          "intensity",
          "reasoning",
        ],
        properties: {
          productId: { type: "string" },
          category: { type: "string", enum: [...INVENTORY_CATEGORIES] },
          role: { type: "string", enum: [...ALL_ROLES] },
          placement: { type: "string", minLength: 3, maxLength: 220 },
          technique: { type: "string", minLength: 3, maxLength: 220 },
          intensity: { type: "string", enum: [...INTENSITIES] },
          reasoning: { type: "string", minLength: 3, maxLength: 240 },
        },
      },
    },
    complexionOmissions: {
      type: "array",
      maxItems: 4,
      items: {
        type: "object",
        additionalProperties: false,
        required: ["category", "reason"],
        properties: {
          category: { type: "string", enum: [...COMPLEXION_CATEGORIES] },
          reason: { type: "string", enum: [...OMISSION_REASONS] },
        },
      },
    },
    overallIntensity: { type: "string", enum: [...INTENSITIES] },
    summary: { type: "string", minLength: 3, maxLength: 300 },
  },
};
