export const TUTORIAL_STEP_PROMPT_VERSION = "tutorial_step_v1";

/**
 * Builds the Gemini prompt for one tutorial step's Result image.
 *
 * Unlike `generate-makeup-preview`'s prompt (which describes a complete,
 * validated makeup plan applied all at once), this describes exactly one
 * incremental step layered on top of a reference image that already shows
 * every previous step applied (guide §3.2 — cumulative application). The
 * reference image(s) themselves, not a text description, are the source of
 * truth for what "already applied" looks like: the prompt never lists
 * prior steps' colors/products, so there is nothing here that can drift
 * out of sync with what the reference images actually show.
 *
 * [isFirstStep] selects between two request shapes (roadmap ST-9 task 8):
 * - step 1: one reference image (the original selfie), no makeup yet.
 * - step N>1: two reference images — the original selfie first (an
 *   identity anchor, resisting drift across repeated edits) and step
 *   N-1's own Result second (the cumulative makeup state to build on).
 *   The caller (`gemini_client.ts`) is responsible for actually attaching
 *   both images in that order; this function only describes them.
 */
export function tutorialStepPrompt(params: {
  isFirstStep: boolean;
  stepNumber: number;
  totalSteps: number;
  categoryLabel: string;
  instruction: Record<string, unknown>;
}): string {
  const { isFirstStep, stepNumber, totalSteps, categoryLabel, instruction } =
    params;
  const cumulativeState = isFirstStep
    ? "CUMULATIVE STATE\nThe (only) reference image shows this person with no makeup applied yet. This is the first step of the tutorial."
    : `CUMULATIVE STATE\nTwo reference images are provided. The FIRST reference image is this person's original, makeup-free photograph — use it only to anchor identity, facial geometry, and skin tone, and to resist drift across repeated edits; its lack of makeup is not an instruction to remove anything. The SECOND reference image shows this person's makeup fully applied through the previous ${
      stepNumber - 1
    } step${
      stepNumber - 1 === 1 ? "" : "s"
    } of this tutorial — this is the cumulative state to build on. Base the edit on the SECOND image and preserve every part of the makeup it shows exactly as shown — do not remove, fade, blend away, or otherwise alter it — while using the FIRST image to keep identity, geometry, and skin tone anchored.`;

  return `
Edit the supplied reference photograph${
    isFirstStep ? "" : "s"
  } to show one additional step of a cosmetic makeup tutorial being applied to the same person. This is a local retouch of one photograph, not a new portrait of a similar person.

HIGHEST PRIORITY — IDENTITY
Preserve the same person's recognizable identity and original photographic characteristics as closely as possible. Preserve facial proportions, nose geometry, eye geometry and spacing, brow bone, jaw and chin shape, face shape, cheek structure, smile and expression, teeth, apparent age, gender presentation, hairstyle and hairline, pose, head angle, body shape, lighting direction and quality, camera angle, focal characteristics, crop, clothing, and background.

Preserve identity-carrying skin detail: freckles, moles, beauty marks, scars, birthmarks, pores, and fine lines. These are not blemishes to correct. Keep skin texture realistic — do not smooth, airbrush, or otherwise retouch skin beyond the described makeup. Deeper skin tones must keep their depth — do not lighten skin under any product.

Do not beautify, slim, reshape, symmetrize, age, de-age, or otherwise alter facial structure. Do not change hair, expression, gaze direction, or the environment. Do not replace the face. If you cannot apply the described change without altering underlying facial structure, apply less of it.

${cumulativeState}

ONLY CHANGE
Apply exactly one new cosmetic step on top of the cumulative state described above: ${categoryLabel}. Do not add any product, color, placement, or region not described in the step instruction below. Makeup sits on the skin as a thin translucent layer and must follow the existing light direction and shadows in the photograph.

This is step ${stepNumber} of ${totalSteps} in the tutorial.

Do not add text, labels, borders, watermarks, jewellery, lashes beyond the instruction, accessories, filters, or additional people. Do not alter image dimensions or aspect ratio.

Return one edited image only.

Step instruction: ${JSON.stringify(instruction)}
`.trim();
}
