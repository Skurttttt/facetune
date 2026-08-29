import {
  CATEGORY_ATTRIBUTES,
  CATEGORY_LABELS,
  type ProductSnapshot,
  type StepSpec,
} from "./types.ts";

export const TUTORIAL_V2_GUIDELINE_PROMPT_VERSION = "tutorial_v2_guideline_v1";

export type GuidelineInput = {
  spec: StepSpec;
  styleCode: string;
  attributes: Record<string, unknown>;
  product: ProductSnapshot | null;
  stepNumber: number;
  totalSteps: number;
  /** True when the base state is the untouched selfie (first step). */
  baseIsOriginalSelfie: boolean;
  /** Categories already applied in the base image; must stay untouched. */
  completedCategories: string[];
  /** Categories still ahead; must not appear. */
  futureCategories: string[];
};

function label(category: string): string {
  return CATEGORY_LABELS[category] ?? category;
}

/** Only the attributes that genuinely govern this category's placement. */
export function relevantAttributes(
  category: string,
  attributes: Record<string, unknown>,
): Record<string, unknown> {
  const keys = CATEGORY_ATTRIBUTES[category] ?? [];
  const selected: Record<string, unknown> = {};
  for (const key of keys) {
    if (attributes[key] !== undefined) selected[key] = attributes[key];
  }
  return selected;
}

/** The image roles, stated so the model cannot confuse target with base. */
function imageRoles(baseIsOriginalSelfie: boolean): string {
  return `
IMAGE ROLES — three images are attached, in this order.

IMAGE 1 — IDENTITY REFERENCE (the original selfie)
The definitive record of who this person is and how their face is built. Every
facial structure you render must match this image.

IMAGE 2 — BASE STATE (${
    baseIsOriginalSelfie
      ? "the original selfie, because this is the first step"
      : "the cumulative result of all previous steps"
  })
This is the face as it looks RIGHT NOW, immediately before the current step.
Your output must be this exact image with instructional guidance drawn on top.

IMAGE 3 — CANONICAL FINAL TARGET
The finished look this user has already chosen and already generated. It is not
inspiration and not a suggestion — it is the exact end state this tutorial is
working toward. Use it only to understand what the current category must
eventually look like. Do NOT copy its finished makeup into your output.
`.trim();
}

/** What may and may not be drawn. */
function annotationRules(): string {
  return `
WHAT TO DRAW
Draw instructional guidance on top of IMAGE 2 using only:
- translucent shaded zones showing exactly where the product goes
- directional arrows showing which way to blend, sweep, or draw
- thin paths or dashed lines showing a stroke's route
- soft gradient bands showing where coverage fades out
- small dots or ticks marking a start or end point, only where genuinely useful

Guidance must be clearly visible against the skin but must never hide the
underlying face.

DO NOT WRITE WORDS
Do not render text, numbers, labels, captions, legends, callouts, watermarks,
step numbers, or arrows with words attached. Every written instruction is
displayed separately by the app. Words rendered into this image are unreadable
at display size and will contradict the app's own text. Communicate purely
through zones, arrows, paths, and shading.
`.trim();
}

/** The instruction-fidelity rule: visualize the spec, do not reinterpret it. */
function fidelityRules(spec: StepSpec): string {
  return `
VISUALIZE THIS EXACT INSTRUCTION — DO NOT REINTERPRET IT
The written instruction below is already final and is already being shown to
the user. Your only job is to draw what it says.

  Apply:      ${spec.whatToApply}
  Where:      ${spec.whereToApply}
  Direction:  ${spec.direction}
  Technique:  ${spec.technique}
  Intensity:  ${spec.intensity}
${spec.amount ? `  Amount:     ${spec.amount}\n` : ""}${
    spec.toolSuggestion ? `  Tool:       ${spec.toolSuggestion}\n` : ""
  }${spec.avoid ? `  Avoid:      ${spec.avoid}\n` : ""}
Your zones must sit where "Where" says, and nowhere else. Your arrows must
point the way "Direction" says, and no other way. If the instruction says to
blend upward and outward toward the temples, the arrows point up and out toward
the temples — never toward the nose, never downward.

If you believe a different placement would look better, you are wrong for this
task. Draw the instruction as written.
`.trim();
}

/** The category lock: current category only. */
function categoryLock(input: GuidelineInput): string {
  const current = label(input.spec.category);
  const completed = input.completedCategories.map(label);
  const future = input.futureCategories.map(label);

  return `
CURRENT CATEGORY LOCK — ${current.toUpperCase()} ONLY
This image teaches ${current} and nothing else.

${
    completed.length > 0
      ? `Already applied in IMAGE 2 and must be left exactly as they are, with NO guidance drawn for them: ${
        completed.join(", ")
      }.`
      : "No makeup has been applied yet."
  }
${
    future.length > 0
      ? `Not yet reached. Do NOT apply them and do NOT draw guidance for them: ${
        future.join(", ")
      }.`
      : "No categories remain after this one."
  }

Drawing an arrow, zone, or marker for any category other than ${current} makes
this image wrong, even if the guidance would be correct in isolation.
`.trim();
}

/** The instructional-not-beauty rule. */
function notABeautyResult(input: GuidelineInput): string {
  const current = label(input.spec.category);
  return `
THIS IS AN INSTRUCTIONAL DIAGRAM, NOT A BEAUTY RESULT
Do NOT apply the finished ${current} to the face. The face in your output must
still look exactly like IMAGE 2 — un-made-up in this category — with guidance
drawn over it showing where the product WILL go.

A reader must be able to tell that ${current} has not been applied yet and that
the marks show where to put it. If your output looks like a finished makeup
photograph, it has failed.
`.trim();
}

/** Identity preservation, matching the protected preview pipeline's posture. */
function identityRules(): string {
  return `
PRESERVE IDENTITY AND FRAMING
Keep the same person, the same facial proportions, nose and eye geometry, brow
bone, jaw and chin shape, cheek structure, expression, gaze, apparent age,
hairstyle and hairline, pose, head angle, lighting, camera angle, crop,
clothing, and background as IMAGE 2.

Do not beautify, slim, reshape, symmetrize, smooth, airbrush, or retouch
anything. Do not remove freckles, moles, scars, or pores. Do not change skin
tone. Do not add jewellery, lashes, filters, borders, or extra people. Do not
change the image dimensions or aspect ratio.

The only difference between IMAGE 2 and your output is the instructional
overlay.
`.trim();
}

/** The product line, when Kit mode supplied a validated owned product. */
function productLine(product: ProductSnapshot | null): string {
  if (!product) return "";
  const name = product.productName ? ` (${product.productName})` : "";
  const shade = product.colorLabel ? ` shade "${product.colorLabel}"` : "";
  return `
OWNED PRODUCT FOR THIS STEP
The user owns and will use this exact product${name}:${shade} colour
${product.colorHex}, ${product.finish} finish. Shade any zone you draw to
suggest this colour so the user can connect the guidance to the product in
their hand. Do not substitute a different colour or product.
`.trim();
}

/**
 * Builds the guideline prompt.
 *
 * Assembled from named sections rather than one long string so each rule can
 * be asserted independently in `prompt_test.ts`.
 */
export function tutorialV2GuidelinePrompt(input: GuidelineInput): string {
  const current = label(input.spec.category);
  const attributes = relevantAttributes(input.spec.category, input.attributes);

  const sections = [
    `You are creating one instructional makeup-placement diagram for a personalized
step-by-step tutorial. This is step ${input.stepNumber} of ${input.totalSteps}.`,

    `YOU ARE NOT CREATING A NEW MAKEUP LOOK.
The user has already chosen and already generated their final look. You are
teaching this specific person how to reproduce that exact look, one category at
a time. Do not design an alternative look and do not reinterpret the style.`,

    imageRoles(input.baseIsOriginalSelfie),
    fidelityRules(input.spec),
    categoryLock(input),
    notABeautyResult(input),
    annotationRules(),
    identityRules(),
    productLine(input.product),

    `PERSONALISE TO THIS FACE
Place the guidance according to this individual's own features as seen in
IMAGE 1, not a generic template. The attributes that govern ${current}
placement here are: ${JSON.stringify(attributes)}.
Reasoning already recorded for this step: ${input.spec.faceRationale}

What this step is reproducing from the final target: ${input.spec.targetLookCues}

Selected look: ${input.styleCode}`,

    `Return exactly one edited image and no text.`,
  ];

  return sections.filter((section) => section.length > 0).join("\n\n");
}
