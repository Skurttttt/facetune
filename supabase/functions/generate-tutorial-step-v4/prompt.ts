import type { TutorialCategory } from "../_shared/tutorial_vocabulary.ts";
import { sanitizePromptText } from "../_shared/prompt_safety.ts";
import { type CategoryGuidance, categoryGuidance } from "./category_prompts.ts";

export { TUTORIAL_GUIDELINE_PROMPT_VERSION } from "../_shared/tutorial_ai_config.ts";
export { categoryGuidance } from "./category_prompts.ts";

/// Builds the guideline-rendering prompt for one approved category.
///
/// One builder for all nine categories: the invariant rules — Image A is the
/// canvas, Image B is the placement authority, annotate rather than apply, no
/// text — are written once here, and only the category-specific landmarks and
/// prohibition vary. Nine separate prompts would let those invariants drift
/// apart, and a rule weakened in one category would be invisible.
///
/// [productNote] carries validated owned-product context in My Makeup Kit mode.
/// It exists so the marking style can suit the finish, and the prompt states
/// plainly that it never affects placement.
export function tutorialGuidelinePrompt(options: {
  category: TutorialCategory;
  guidance: CategoryGuidance;
  stepPosition: number;
  stepCount: number;
  productNote: string | null;
}): string {
  return `
Draw makeup application guidelines onto IMAGE A.

You are given two photographs of the SAME person.
IMAGE A is the ORIGINAL photograph, with no makeup applied. This is your CANVAS — the image you edit and return.
IMAGE B is the FINAL photograph, showing the finished makeup look. This is your REFERENCE — you never return it and never copy its colour onto the face.

THE ONE THING YOU ARE DOING
Compare IMAGE A with IMAGE B to see exactly where ${options.category} was applied, then draw guideline markings on IMAGE A showing where and how to apply it.

${options.guidance.landmarks}

DRAW ONLY GUIDELINES
- Draw thin outlines, boundary lines, directional arrows, or light hatching that indicate the application area and blending direction.
- Use a single clearly artificial marker colour that could not be mistaken for cosmetics. Keep every marking semi-transparent enough that the face beneath stays visible.
- The markings must sit ON TOP of the photograph, like annotations drawn on a printed photo.

NEVER APPLY MAKEUP
- Do NOT apply, paint, tint, blend, or simulate any actual ${options.category} pigment on the skin.
- ${options.guidance.prohibition}
- The face in your returned image must still look exactly like IMAGE A underneath the markings: same bare skin, same tone, same texture.
- If you cannot mark the area without colouring the skin, draw a simpler outline instead.

ONLY THIS CATEGORY
- Mark ${options.category} and nothing else. Ignore every other makeup category visible in IMAGE B, even if it is obvious.
- Do not mark foundation, concealer, contour, highlighter, brows, eyeshadow, eyeliner, or lips unless that IS the category named above.

PLACEMENT COMES FROM IMAGE B ONLY
- IMAGE B is the sole authority for where the markings go. Do not use a standard, textbook, or flattering placement.
- If IMAGE B shows this category placed higher, lower, wider, or narrower than usual, mark exactly what IMAGE B shows.
- Face shape, eye shape, lip shape, and the chosen style may help you interpret what you see, but they never override it and never add a marking IMAGE B does not support.
- If a region is genuinely unclear in IMAGE B, mark the smaller, more conservative area rather than guessing.

PRESERVE THE PHOTOGRAPH
Return IMAGE A unchanged apart from the added markings. Preserve identity, facial proportions, pose, head angle, expression, gaze, hairstyle, hairline, clothing, background, lighting, framing, crop, and aspect ratio. Do not beautify, smooth, reshape, symmetrize, re-light, or re-frame. Do not add or remove people or objects.

NO TEXT OF ANY KIND
- Do not write words, letters, numbers, labels, captions, legends, arrows with text, brand names, product names, shade names, colour codes, watermarks, or borders anywhere in the image.
- The image carries drawn markings only. All wording is shown outside the image by the app.

This is step ${options.stepPosition} of ${options.stepCount}.${
    options.productNote === null ? "" : `\n\n${options.productNote}`
  }

Return exactly one edited image.
`.trim();
}

/// Renders validated owned-product context as a technique note.
///
/// Deliberately phrased as background and explicitly subordinated to IMAGE B,
/// because product metadata must never override visual placement authority. The
/// shade is mentioned only so the marking style can suit the finish; it must not
/// be painted onto the face, and it must not be written into the image.
///
/// Nothing is invented: a product with no colour label is described by its
/// finish alone rather than being given a plausible-sounding shade name.
export function productNote(
  products: Array<{
    productName: string | null;
    colorLabel: string | null;
    finish: string;
  }>,
): string | null {
  if (products.length === 0) return null;
  const described = products
    .map((product) => {
      // The shade label is free user text, so it is sanitized before it can
      // reach the model. A label that reads like an instruction is dropped
      // entirely and described neutrally instead — losing a shade name costs
      // nothing, while letting one redirect the renderer would defeat the
      // guideline-only rules above.
      const shade = sanitizePromptText(product.colorLabel) ?? "an owned shade";
      // `finish` comes from a database check constraint, not from free text.
      return `${shade} (${product.finish} finish)`;
    })
    .join(" and ");
  return `CONTEXT ONLY: the person used ${described}. This tells you the ` +
    `finish, not the position. It does NOT change where the markings go — ` +
    `IMAGE B remains the only placement authority. Do not paint this shade ` +
    `onto the skin and do not write it in the image.`;
}

/// Convenience wrapper kept for callers that only have the category.
export function categoryIntent(category: TutorialCategory): string | null {
  return categoryGuidance(category)?.landmarks ?? null;
}
