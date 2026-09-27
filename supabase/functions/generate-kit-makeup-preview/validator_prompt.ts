import { TUTORIAL_CATEGORIES } from "../_shared/tutorial_vocabulary.ts";
import type { TutorialCategory } from "../_shared/tutorial_vocabulary.ts";

/**
 * What counts as each cosmetic. Server-owned, and deliberately phrased as the
 * effect on the face — retouching that imitates a product counts as that
 * product, because that is what the Tutorial analyzer will later see.
 */
export const CATEGORY_DEFINITIONS: Readonly<Record<TutorialCategory, string>> =
  {
    foundation:
      "an added base that evens or unifies the skin tone, or skin smoothing, blurring, airbrushing, or pore erasing that reads as foundation",
    concealer:
      "localized coverage of spots, blemishes, redness, or discoloration, or brightening and correction of the under-eye area",
    contour_bronzer:
      "added shading under the cheekbones, along the jaw, at the temples, or on the nose, or added bronzed warmth",
    blush: "added colour or flush on the cheeks",
    highlighter:
      "added sheen, glow, shimmer, or brightness on the cheekbones, brow bone, nose, or cupid's bow",
    eyebrows:
      "eyebrows that are filled, darkened, tinted, thickened, or reshaped by a product",
    eyeshadow:
      "added colour, shimmer, or shading on the eyelids, the crease, or around the eyes",
    eyeliner:
      "a drawn, smudged, tightlined, or winged line, or a darkened lash line",
    lips: "lipstick, tint, gloss, or liner, or a changed lip colour",
  };

/**
 * The validator's instructions. The model is never told the plan: it
 * classifies what it sees in both photographs, and the server alone compares
 * that with the plan. A classifier that knew what was expected would be
 * steered toward confirming it.
 */
export function kitPreviewValidatorSystemInstruction(): string {
  const definitions = TUTORIAL_CATEGORIES.map((category) =>
    `- ${category}: ${CATEGORY_DEFINITIONS[category]}`
  ).join("\n");
  return `
You are a strict makeup inspector comparing two photographs of the same person. The FIRST image is the ORIGINAL selfie. The SECOND image is an EDITED candidate.

For each cosmetic category below, report whether that cosmetic is visibly present in the ORIGINAL and whether it is visibly present in the CANDIDATE:
${definitions}

Rules:
- A person's natural features are not makeup. Natural brow hair, natural lip colour, and naturally even or glowing skin are "absent" unless a product or retouching visibly adds to them.
- Report "present" only when you can see the effect. Report "absent" only when you can see that it is not there. Otherwise report "uncertain".
- Compare the two images directly. An effect that is stronger in the CANDIDATE than in the ORIGINAL is present in the CANDIDATE.
- Evidence is one short, concrete sentence about what you see. Never describe the person's identity, age, ethnicity, or attractiveness.
- identity is "preserved" when the CANDIDATE is clearly the same person with the same face shape, features, expression, pose, hair, and background; "changed" when any of those differ; otherwise "uncertain".
- Report every category exactly once. Return JSON matching the supplied schema only.
`.trim();
}

export const KIT_PREVIEW_VALIDATOR_USER_TEXT =
  "Image 1 is the ORIGINAL. Image 2 is the CANDIDATE. Classify every category.";

const presence = { type: "string", enum: ["present", "absent", "uncertain"] };

export const KIT_PREVIEW_VALIDATOR_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["categories", "identity"],
  properties: {
    categories: {
      type: "array",
      minItems: TUTORIAL_CATEGORIES.length,
      maxItems: TUTORIAL_CATEGORIES.length,
      items: {
        type: "object",
        additionalProperties: false,
        required: ["category", "inOriginal", "inCandidate", "evidence"],
        properties: {
          category: { type: "string", enum: [...TUTORIAL_CATEGORIES] },
          inOriginal: presence,
          inCandidate: presence,
          evidence: { type: "string", minLength: 3, maxLength: 200 },
        },
      },
    },
    identity: {
      type: "string",
      enum: ["preserved", "changed", "uncertain"],
    },
  },
};
