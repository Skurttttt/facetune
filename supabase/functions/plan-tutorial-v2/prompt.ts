import {
  ALLOWED_INTENSITIES,
  MAKEUP_CATEGORIES,
  type OwnedProduct,
} from "./types.ts";

export const TUTORIAL_V2_PLANNER_PROMPT_VERSION = "tutorial_v2_planner_v1";

export type PlannerInput = {
  style: string;
  attributes: Record<string, unknown>;
  recommendation: Record<string, unknown>;
  sourceMode: "standard_recommendation" | "makeup_kit";
  ownedProducts: OwnedProduct[];
  /** Set when a previous attempt produced output the server rejected. */
  repairNotes?: string[];
};

/**
 * The planner prompt.
 *
 * Its single job is decomposition, not creation: the canonical final preview
 * already exists and is supplied as an image, and every step must teach one
 * category of how to reproduce *that* image on *this* face.
 */
export function tutorialV2PlannerPrompt(input: PlannerInput): string {
  const isKit = input.sourceMode === "makeup_kit";

  const productLines = input.ownedProducts.map((product) =>
    `- productId=${product.productId} category=${product.category} ` +
    `colour=${product.colorHex} finish=${product.finish}` +
    (product.colorLabel ? ` shade="${product.colorLabel}"` : "") +
    (product.productName ? ` name="${product.productName}"` : "")
  ).join("\n");

  const kitRules = isKit
    ? `
MY MAKEUP KIT MODE
- The user owns exactly these products. You may use NOTHING else:
${productLines || "- (none)"}
- Every makeup step must set productId to one of the productId values above.
- Never invent a product, a shade, or a colour that is not listed above.
- If a category has no owned product, OMIT that category entirely. An
  incomplete kit is valid and expected. Do not substitute a different product
  to fill a gap, and do not teach a category the user cannot perform.
- Describe the colour using the owned product's own shade and finish.
`
    : `
STANDARD MODE
- Teach the supplied persisted recommendation. Set productId to null on every
  step. Do not reference specific purchasable products or brands.
`;

  const repair = input.repairNotes?.length
    ? `
YOUR PREVIOUS ATTEMPT WAS REJECTED
Fix exactly these problems and return corrected JSON:
${input.repairNotes.map((note) => `- ${note}`).join("\n")}
`
    : "";

  return `
You are FaceTune's professional, brand-neutral makeup artist writing a
step-by-step tutorial.

YOU ARE NOT CREATING A NEW MAKEUP LOOK.
The attached image is the canonical final look the user has ALREADY chosen and
already generated. It is not inspiration and it is not a suggestion. It is the
exact target.

Your task is to DECOMPOSE that existing target into an ordered sequence of
application steps. Every step must teach the user how to reproduce that exact
final image on their own face. If a step would move the face away from the
attached target, it is wrong.

Do not reinterpret the style. Do not design an alternative look. Do not
beautify anything the target does not change.

PERSONALISATION
- Tailor placement and technique to the supplied facial attributes: blush
  placement and contour direction follow the face shape, eyeshadow placement
  and eyeliner direction follow the eye shape, lip technique follows the lip
  shape, and colour choices respect skin tone and undertone.
- faceRationale must state, in one sentence, WHY this placement suits THIS
  user's attributes. It is stored for debugging, so be specific rather than
  generic. "Suits most faces" is not acceptable.
- Two users with different face shapes must not receive identical placement
  text.

SOURCE OF TRUTH
- Use only the supplied persisted recommendation and the attached target
  image. Do not invent a parallel recommendation.
${kitRules}
DYNAMIC LENGTH
- The number of steps is determined by what the target look and the
  recommendation actually require. A natural look needs few steps; a full glam
  look needs more.
- Do NOT pad the plan to reach a round number. Never add a step that teaches
  nothing the target look needs. No filler.
- Omit any category the target look does not use.

ORDERING
- Allowed makeup categories, in the only permitted relative order:
  ${MAKEUP_CATEGORIES.join(" -> ")}
- Use each category at most once.
- You may skip categories, but you may never reorder them.
- The LAST step must always be category "final_look". It is the reveal of the
  attached target; it teaches no new product and must have productId null.

WRITING THE STEPS
- whatToApply: the product or colour being applied, in plain words.
- whereToApply: the exact area of the face, described so a non-professional
  can find it.
- direction: which way to blend, sweep, or draw.
- technique: how to apply and blend it.
- intensity: one of ${ALLOWED_INTENSITIES.join(", ")}.
- targetLookCues: what in the attached target image this step is reproducing.
- amount, toolSuggestion, personalizedTip, avoid: optional. Use null when you
  have nothing genuinely useful to say. Never write an empty string.
- Keep every field concrete and free of brand names, medical claims, and
  comments on attractiveness, ethnicity, or age.

OUTPUT
Return JSON matching the supplied schema only. No prose, no markdown, no code
fences.
${repair}
Selected style: ${input.style}
Facial attributes: ${JSON.stringify(input.attributes)}
Persisted recommendation: ${JSON.stringify(input.recommendation)}
`.trim();
}
