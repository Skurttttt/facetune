/**
 * The response schema handed to the planner model.
 *
 * Structure is the first line of defence: the model is given no field
 * through which it could describe a finished makeup result, a per-step
 * result image, or a dependency on a previous step. `validation.ts` then
 * enforces the semantics the schema cannot express (ordering, ownership,
 * attribute scoping), because a response is never trusted merely because it
 * parsed.
 *
 * `steps` deliberately carries no `maxItems`. Production bisection in
 * V3-10F4.4 proved that `properties.steps.maxItems` — and only that — makes
 * `gemini-3.6-flash` reject the whole request with `400 INVALID_ARGUMENT`:
 * dropping every `maxItems` was accepted, dropping every `minItems` was not,
 * and dropping the bounds on `steps` alone was accepted while
 * `target_look_cues.maxItems` and `graphics.maxItems` stayed in the request.
 * Expressing the bound as a string is not a workaround either — the API
 * answers "value at properties.steps.minItems must be a number".
 *
 * The twelve-step ceiling is therefore NOT relaxed, only relocated: it is
 * enforced by `parseAndValidatePlan` before anything is persisted. See
 * `MAXIMUM_PLAN_STEPS` in `types.ts`.
 *
 * The union `type: ["string", "null"]` nullability below is CORRECT and was
 * positively cleared by the same bisection: rewriting it to
 * `anyOf: [<schema>, {"type": "null"}]` left the request rejected. Do not
 * "fix" it.
 */
export const TUTORIAL_V3_PLAN_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["steps"],
  properties: {
    steps: {
      type: "array",
      minItems: 1,
      items: {
        type: "object",
        additionalProperties: false,
        required: [
          "category",
          "where_to_apply",
          "direction",
          "technique",
          "face_attributes",
          "face_rationale",
          "target_rationale",
          "target_look_cues",
        ],
        properties: {
          category: {
            type: "string",
            enum: [
              "foundation",
              "concealer",
              "contour_bronzer",
              "blush",
              "highlighter",
              "eyebrow",
              "eyeshadow",
              "eyeliner",
              "lipstick",
              "lip_gloss",
              "final_look",
            ],
          },
          product_id: {
            type: ["string", "null"],
            description:
              "In Kit mode, the exact owned product id supplied in the input. Null in standard mode.",
          },
          product_name: { type: ["string", "null"] },
          shade_name: { type: ["string", "null"] },
          color_hex: {
            type: ["string", "null"],
            pattern: "^#[0-9A-Fa-f]{6}$",
          },
          finish: { type: ["string", "null"] },
          coverage: { type: ["string", "null"] },
          intensity: { type: ["string", "null"] },
          where_to_apply: { type: "string", minLength: 3, maxLength: 220 },
          direction: { type: "string", minLength: 3, maxLength: 220 },
          technique: { type: "string", minLength: 3, maxLength: 220 },
          amount: { type: ["string", "null"] },
          tool_suggestion: { type: ["string", "null"] },
          personalized_tip: { type: ["string", "null"] },
          avoid: { type: ["string", "null"] },
          face_attributes: {
            type: "object",
            additionalProperties: false,
            description:
              "Only the attributes relevant to this category, copied verbatim from the input.",
            properties: {
              face_shape: { type: ["string", "null"] },
              skin_tone: { type: ["string", "null"] },
              undertone: { type: ["string", "null"] },
              eye_shape: { type: ["string", "null"] },
              lip_shape: { type: ["string", "null"] },
            },
          },
          face_rationale: { type: "string", minLength: 10, maxLength: 320 },
          target_rationale: { type: "string", minLength: 10, maxLength: 320 },
          target_look_cues: {
            type: "array",
            minItems: 1,
            maxItems: 4,
            items: { type: "string", minLength: 3, maxLength: 160 },
          },
          guideline_visual_intent: {
            type: ["object", "null"],
            additionalProperties: false,
            required: ["description", "graphics"],
            properties: {
              description: {
                type: "string",
                minLength: 10,
                maxLength: 320,
                description:
                  "The instructional marks to draw on the untouched selfie. Never a description of applied makeup.",
              },
              graphics: {
                type: "array",
                minItems: 1,
                maxItems: 5,
                items: {
                  type: "string",
                  enum: [
                    "translucent_zone",
                    "arrow",
                    "path",
                    "soft_band",
                    "marker",
                  ],
                },
              },
            },
          },
        },
      },
    },
  },
} as const;
