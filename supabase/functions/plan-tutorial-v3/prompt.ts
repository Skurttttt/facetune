import {
  ALLOWED_GRAPHICS,
  CATEGORY_ATTRIBUTES,
  CATEGORY_RANKS,
  type OwnedProduct,
  type SourceMode,
} from "./types.ts";

export const TUTORIAL_V3_PLANNER_PROMPT_VERSION = "v3-planner-1";

export interface PlannerInput {
  style: string;
  sourceMode: SourceMode;
  attributes: Record<string, unknown>;
  recommendation: Record<string, unknown>;
  ownedProducts: OwnedProduct[];
  repairNotes?: string[];
}

function attributeScopeTable(): string {
  return Object.entries(CATEGORY_ATTRIBUTES)
    .filter(([category]) => category !== "final_look")
    .map(([category, attributes]) =>
      `- ${category}: ${[...attributes].join(", ")}`
    )
    .join("\n");
}

function categoryOrder(): string {
  return Object.entries(CATEGORY_RANKS)
    .sort((a, b) => a[1] - b[1])
    .map(([category]) => category)
    .join(" -> ");
}

function ownedProductLines(products: OwnedProduct[]): string {
  return products
    .map((product) => {
      const parts = [
        `product_id=${product.productId}`,
        `category=${product.category}`,
        `color_hex=${product.colorHex}`,
        `finish=${product.finish}`,
      ];
      if (product.productName) parts.push(`name=${product.productName}`);
      if (product.colorLabel) parts.push(`shade=${product.colorLabel}`);
      if (product.foundationDepth) {
        parts.push(`depth=${product.foundationDepth}`);
      }
      if (product.foundationUndertone) {
        parts.push(`undertone=${product.foundationUndertone}`);
      }
      return `- ${parts.join(" | ")}`;
    })
    .join("\n");
}

/**
 * Builds the master planner prompt.
 *
 * The attached image is the canonical premium final preview — the exact look
 * the user already chose and the tutorial's destination. The planner's job is
 * decomposition, not invention: it explains how *this* face reaches *that*
 * result, and it never proposes a different look.
 */
export function tutorialV3PlannerPrompt(input: PlannerInput): string {
  const isKit = input.sourceMode === "makeup_kit";

  const sections: string[] = [
    `You are a professional makeup artist writing a personalized, step-by-step application tutorial.`,
    ``,
    `The attached image is the FINAL LOOK this user has already selected and generated. It is the exact destination of this tutorial. Decompose it into the makeup-application steps this specific person should follow to reproduce it on their own face.`,
    ``,
    `SELECTED LOOK (mandatory, already chosen): ${input.style}`,
    `This look is fixed. Do not propose, substitute or drift toward a different look.`,
    ``,
    `THIS USER'S FACE ATTRIBUTES:`,
    JSON.stringify(input.attributes, null, 2),
    ``,
    `THE PERSISTED MAKEUP PLAN THIS LOOK WAS BUILT FROM:`,
    JSON.stringify(input.recommendation, null, 2),
    ``,
    `WHAT EACH STEP MUST ANSWER`,
    `How should THIS user apply THIS category to reproduce THIS exact final look?`,
    ``,
    `Two levels of personalization apply together:`,
    `1. The selected look decides which categories appear, and their intensity, finish, coverage and placement style.`,
    `2. The face attributes decide how that look should be applied to this particular face. The same look on a round face and a long face should produce genuinely different placement and direction, not the same sentence reworded.`,
    ``,
    `DYNAMIC LENGTH`,
    `There is no fixed number of steps. A Natural look needs few; a Full Glam look needs more. Include a category only when the selected look and the persisted plan genuinely call for it. Never pad the plan with filler steps, and never include a category just to make the tutorial longer.`,
    ``,
    `ORDER`,
    `Whatever categories you include must appear in this relative order:`,
    categoryOrder(),
    `The last step must always be "final_look".`,
    ``,
    `THE FINAL LOOK STEP`,
    `The final step has category "final_look". It reuses the attached image and teaches no application of its own. Give it only a target_rationale summarizing what the completed look achieves, plus the required face_rationale and target_look_cues fields. It must carry no product and no guideline_visual_intent.`,
    ``,
    `FACE ATTRIBUTE SCOPE`,
    `Each step may reference only the attributes relevant to its category, copied verbatim from the input. Leave every other attribute out.`,
    attributeScopeTable(),
    `The "final_look" step references no attributes.`,
    ``,
    `GUIDELINE VISUAL INTENT (every step except final_look)`,
    `Each step's guideline image will be drawn on the user's UNTOUCHED original selfie. It teaches placement only.`,
    `Describe the instructional marks to draw — where the zones sit, which way the arrows point, what path a line follows.`,
    `Never describe applied makeup, a finished result, retouched skin, or an improved face. The guideline shows WHERE to apply, never what it looks like once applied.`,
    `Choose marks only from: ${[...ALLOWED_GRAPHICS].join(", ")}.`,
    `Do not rely on any text, label or number being drawn inside the image.`,
    ``,
    `RATIONALES`,
    `- face_rationale: why this placement suits THIS face, naming the relevant attribute.`,
    `- target_rationale: how this step contributes to the attached final look.`,
    `- target_look_cues: what to look for in the attached image that this step produces.`,
    ``,
  ];

  if (isKit) {
    sections.push(
      `PRODUCTS — MY MAKEUP KIT MODE`,
      `This user owns exactly the products listed below. You may teach only these.`,
      ownedProductLines(input.ownedProducts),
      ``,
      `Rules:`,
      `- Every step except "final_look" must set product_id to one of the ids above, exactly as written.`,
      `- A step's category must match that product's category.`,
      `- Never invent a product, a shade or an id that is not listed.`,
      `- If the user owns nothing suitable for a category, omit that category entirely. An incomplete kit is expected and acceptable.`,
      ``,
    );
  } else {
    sections.push(
      `PRODUCTS — STANDARD MODE`,
      `The user owns no registered products for this tutorial. Set product_id to null on every step.`,
      `Describe the shade from the persisted makeup plan above using shade_name, color_hex and finish. Do not select products independently of that plan.`,
      ``,
    );
  }

  sections.push(
    `FORBIDDEN`,
    `- Do not describe generating, rendering or previewing a makeup result for any step.`,
    `- Do not make any step depend on a previous step's image; each step is taught from the untouched original selfie.`,
    `- Do not produce a new final look. The attached image is the only final look.`,
    `- Do not give generic universal placement that ignores this face.`,
    `- Do not repeat a category.`,
    ``,
    `Return JSON matching the provided schema, and nothing else.`,
  );

  if (input.repairNotes && input.repairNotes.length > 0) {
    sections.push(
      ``,
      `YOUR PREVIOUS RESPONSE WAS REJECTED. Fix exactly these problems and return the corrected plan:`,
      ...input.repairNotes.map((note) => `- ${note}`),
    );
  }

  return sections.join("\n");
}
