import type { TutorialCategory } from "../_shared/tutorial_vocabulary.ts";
import { sanitizePromptText } from "../_shared/prompt_safety.ts";
import { type CategoryGuidance, categoryGuidance } from "./category_prompts.ts";

export { TUTORIAL_GUIDELINE_PROMPT_VERSION } from "../_shared/tutorial_ai_config.ts";
export {
  categoryGuidance,
  REPRESENTATIVE_CATEGORIES,
} from "./category_prompts.ts";

/// Renders an optional bullet list as a titled block, or nothing at all.
///
/// Absence has to produce the empty string rather than an empty heading, so a
/// category outside the representative gate renders no trace of the section.
function block(title: string, lines: readonly string[] | undefined): string {
  if (lines === undefined || lines.length === 0) return "";
  return `\n\n${title}\n${lines.map((line) => `- ${line}`).join("\n")}`;
}

/// Builds the guideline-rendering prompt for one approved category.
///
/// One builder for all nine categories: the invariant rules — Image A is the
/// canvas, Image B is the placement authority, annotate rather than apply, no
/// text — are written once here, and only the category-specific questions,
/// landmarks, and prohibitions vary. Nine separate prompts would let those
/// invariants drift apart, and a rule weakened in one category would be
/// invisible.
///
/// The sections follow the composition the quality contract specifies: image
/// roles, canonical-preview authority, category isolation, the exact
/// visual-difference questions, minimum useful guide language, the
/// guideline-only negative contract, category-specific constraints, and output
/// constraints. They are separate named blocks rather than one paragraph
/// because a model that loses one rule in the middle of a wall of prose loses
/// it silently.
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
  // Rendered only for the categories that have been through the representative
  // quality gate. An absent block leaves the prompt as it was for the rest.
  const analysis = options.guidance.analysis === undefined ? "" : `

WHAT CHANGED — ANSWER THESE BEFORE YOU DRAW
${options.guidance.analysis}`;

  // Present for every category, not only the representative gate: V4-QA-2D's
  // regression was global, so the ban has to be too.
  const noMakeup = block(
    `NEVER RENDER ${options.category.toUpperCase()} ITSELF`,
    options.guidance.noMakeup,
  );
  const hardRules = block(
    `ABSOLUTE RULES FOR ${options.category.toUpperCase()}`,
    options.guidance.hardRules,
  );
  const prefer = block("WHAT A GOOD RESULT CONTAINS", options.guidance.prefer);
  const avoid = block("WHAT A BAD RESULT LOOKS LIKE", options.guidance.avoid);

  return `
Draw makeup application guidelines onto IMAGE A.

You are given two photographs of the SAME person.
IMAGE A is the ORIGINAL photograph, with no makeup applied. This is your CANVAS — the image you edit and return.
IMAGE B is the FINAL photograph, showing the finished makeup look. This is your REFERENCE — you never return it, and nothing about how it looks may appear in what you return.

IMAGE A is the ONLY visual base of your output. It is the authority for identity, face shape, skin, natural lips, natural eyelids, natural brows, natural cheeks, hairstyle, expression, pose, clothing, background, and lighting. All of those must survive unchanged.
IMAGE B is the authority for WHERE and WHAT SHAPE only: the position, boundary, extent, path, curve, start and end of the ${options.category}. It is never the authority for how anything should look.

IMAGE B IS A REFERENCE, NEVER A SOURCE OF APPEARANCE
- Do not copy pixels, colour, shading, texture, glow, gloss, pigment, darkness, saturation, or cosmetic finish from IMAGE B onto IMAGE A.
- Do not blend the two photographs, and do not partially recreate IMAGE B.
- Use IMAGE B only to work out WHERE the target makeup sits and HOW its shape differs from IMAGE A.
- Read the geometry from IMAGE B. Leave its appearance in IMAGE B.

You are NOT being asked to produce another beauty image. You are annotating a photograph, the way someone would draw on a printed photo to explain a technique.

CURRENT CATEGORY = ${options.category.toUpperCase()}

THE ONE THING YOU ARE DOING
Compare IMAGE A with IMAGE B to see exactly where ${options.category} was applied, then draw guideline markings on IMAGE A showing where and how to apply it. Determine what visibly changed in THIS category between the two photographs, and draw the minimum useful instructional guides on IMAGE A that would let a person reproduce that change themselves, later, with their own makeup. You are not reproducing the change; you are drawing the instructions for it.

WORK IN THIS ORDER
1. Look at IMAGE A and note how this feature appears with no makeup on it.
2. Look at IMAGE B and note how the same feature appears finished.
3. Compare the two, for ${options.category} only.
4. Identify the exact visible differences — what is present in IMAGE B that is not present in IMAGE A.
5. Fix in your mind the target's placement, bounds, extent, path, curve, and where it is strongest.
6. Discard every convention about ${options.category} that IMAGE B does not visibly support, however standard it is.
7. Only then draw, and draw only the marks that point at those exact visible differences. The marks indicate the differences; they never depict them.
Do not go straight from knowing the category to drawing a familiar diagram for it. The comparison happens first, and the comparison decides the marks.

FIND THE TARGET'S BOUNDS
Reason about the edges of what you can actually see, not about the name of a region. For the area this category occupies, establish: its highest visible point; its lowest; its innermost; its outermost; where it begins; where it ends; the dominant path or contour; where it visibly strengthens and weakens; and which of those edges differ from IMAGE A. Marking a named region is what produces a generic result — marking the bounds you have just established is what produces a faithful one. You do not need numeric coordinates; you do need to have looked.

PLACEMENT COMES FROM IMAGE B ONLY
- IMAGE B is the sole authority for where the markings go. Do not use a standard, textbook, or flattering placement. Do not substitute generic makeup placement.
- If IMAGE B shows this category placed higher, lower, wider, or narrower than usual, mark exactly what IMAGE B shows.
- Where a common makeup convention disagrees with what is visible in IMAGE B, follow IMAGE B.
- Face shape, eye shape, lip shape, and the chosen style may help you interpret what you see, but they never override it and never add a marking IMAGE B does not support.
- If a region is genuinely unclear in IMAGE B, mark the smaller, more conservative area rather than guessing.

ONLY THIS CATEGORY
- Analyse the current category only. Mark ${options.category} and nothing else. Ignore every other makeup category visible in IMAGE B, even if it is obvious.
- Do not mark foundation, concealer, contour, highlighter, brows, eyeshadow, eyeliner, or lips unless that IS the category named above.${analysis}

${options.guidance.landmarks}

THAT DESCRIPTION IS ORIENTATION, NOT INSTRUCTION
- The paragraph above tells you what this category generally involves so you know what to look for. It does not tell you what to draw.
- What you draw comes from the comparison you just made. Where the description mentions something IMAGE B does not show, leave it out.
- General makeup knowledge may help you interpret what you are seeing. It may never replace it, and it may never supply a mark on its own.

MARK THE DIFFERENCE, NOT THE ANATOMY
- The user does not need a diagram of their own face. They need to know what to change.
- Where IMAGE A already matches IMAGE B, little or no guidance is needed there.
- Where IMAGE A and IMAGE B differ, that difference is the whole point of the step, and it must be the clearest thing in your marking.
- Spend guide geometry on the change. Mark unchanged anatomy only where it is genuinely needed as a reference anchor for the change.

USE THE FEWEST GUIDES THAT TEACH IT
- Prefer a few meaningful guide elements over dense decorative geometry. Three marks that each teach something beat fourteen that look thorough.
- Every mark must have a teaching purpose. Before drawing one, it must answer at least one of: where do I start? where does the product go? what boundary do I follow? where do I stop? where do I blend or fade? which direction do I move?
- If a mark answers none of those, do not draw it. If an arrow does not correspond to a real direction the user should move the product, do not draw it.
- Do not add construction lines, cross-hairs, measurement ticks, symmetry axes, grids, or ornamental flourishes.

DRAW ONLY GUIDELINES
- Draw thin outlines, boundary lines, directional arrows, and small anchor dots that indicate the application area and blending direction.
- Keep to this simple visual language: a dot marks a start or anchor point; a solid line marks a placement boundary or path to follow; a dashed line marks a blend or fade zone; an arrow marks a direction to move.
- Use a single clearly artificial marker colour that could not be mistaken for cosmetics.
- The markings must sit ON TOP of the photograph, like annotations drawn on a printed photo.

GUIDE MARKS ARE LINES, NOT FILLS
- Instructional colour is allowed. Cosmetic colour is not. The difference is not the colour — it is whether the mark reads as a drawn line or as something worn on the face.
- Every mark must stay a line, a dot, a dash, an arrow, or an outlined boundary. Draw the edge of an area, never the area itself.
- Do not fill, wash, tint, shade, or soften a marked region. A translucent patch over the cheek, lid, or lips is makeup, not a guide, no matter what colour it is.
- Do not let a mark blur, glow, feather, or fade into the skin. Marks have crisp edges and sit clearly above the photograph.

TARGET INTENSITY IS INFORMATION, NOT SOMETHING YOU RENDER
- You may look at how strong or soft the target is, and let it inform where you put a boundary or an anchor, or how large the marked area is.
- You may NOT express intensity by making anything on the face pinker, darker, redder, brighter, glossier, or more saturated. Strength of target is never expressed as strength of colour.

NEVER APPLY MAKEUP
DO NOT APPLY MAKEUP.
DO NOT beautify.
DO NOT recolor the face.
DO NOT change other categories.
- Do NOT apply, paint, tint, blend, or simulate any actual ${options.category} pigment on the skin.
- Do NOT apply makeup even partially, even faintly, even as a hint of the finished result.
- Do NOT reproduce the finished makeup, and do NOT partially recreate the final beauty image.
- Do NOT transfer any makeup appearance from IMAGE B.
- Do NOT tint or recolour the cheeks or lips, add lipstick, gloss, saturation, or shine.
- Do NOT darken the lash line, add liner, or fill a wing.
- Do NOT add eyeshadow, darken or recolour the eyelid, or tint the crease.
- Do NOT add shimmer, glitter, glow, sheen, or brightening to any high point.
- Do NOT add contour shading or bronzed warmth, and do NOT sculpt or slim anything.
- Do NOT fill, darken, or thicken the eyebrows.
- Do NOT apply foundation, even out the complexion, brighten under-eyes, or conceal a blemish.
- Do NOT smooth the skin, retouch it, alter skin tone, or alter skin texture.
- Do NOT beautify the face, and do NOT reshape the face, eyes, nose, or mouth.
- Do NOT alter the hair, the clothing, the background, or the lighting.
- The face in your returned image must still look exactly like IMAGE A underneath the markings: same bare skin, same tone, same texture.
- If you cannot mark the area without colouring the skin, draw a simpler outline instead.

CATEGORY CONSTRAINTS
- ${options.guidance.prohibition}${noMakeup}${hardRules}${prefer}${avoid}

PAIRED FEATURES
- Where the feature appears on both sides of the face, mark both coherently.
- Follow the head angle and the real face in IMAGE A rather than forcing mirrored geometry, and preserve any genuine asymmetry visible in IMAGE B. Do not correct natural asymmetry, and do not invent one.

PRESERVE THE PHOTOGRAPH
Return IMAGE A unchanged apart from the added markings. Preserve identity, facial proportions, pose, head angle, expression, gaze, hairstyle, hairline, clothing, background, lighting, framing, crop, and aspect ratio. Do not beautify, smooth, reshape, symmetrize, re-light, or re-frame. Do not add or remove people or objects.

NO TEXT OF ANY KIND
- Do not write words, letters, numbers, labels, captions, legends, arrows with text, brand names, product names, shade names, colour codes, watermarks, or borders anywhere in the image.
- The image carries drawn markings only. All wording is shown outside the image by the app.

This is step ${options.stepPosition} of ${options.stepCount}.${
    options.productNote === null ? "" : `\n\n${options.productNote}`
  }

THE TEST YOUR IMAGE MUST PASS
Imagine erasing every guide mark you have drawn. What is left must be the original photograph, IMAGE A, with no makeup on it — bare skin, untinted cheeks, untinted lips, undarkened lash line, unshaded lids, unfilled brows. If anything cosmetic would still be visible after erasing the marks, you have applied makeup, and the image is wrong. There is no acceptable amount of it. Draw the marks; leave the face alone.

CHECK EVERY MARK BEFORE YOU DRAW IT
For each boundary, path, arrow, or anchor you are about to draw, you must be able to complete this sentence: "This mark exists because IMAGE B shows ______ compared with IMAGE A."
- If the blank can only be filled with "this is where this product usually goes", do not draw the mark.
- If IMAGE B does not visually justify it, leave it out.
- Being more faithful does not mean drawing more. If you are unsure, draw fewer marks in the right place rather than more in the usual place.
- Between a tidier diagram and a less tidy but more truthful one, choose the truthful one. This is instructional, not decorative.

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
