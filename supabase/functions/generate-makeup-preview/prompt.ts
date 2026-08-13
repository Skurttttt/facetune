export const MAKEUP_PREVIEW_PROMPT_VERSION = "makeup_preview_v2";

export function makeupPreviewPrompt(
  style: string,
  recommendation: Record<string, unknown>,
  variationNumber: number,
): string {
  return `
Edit the supplied selfie into a realistic cosmetic makeup preview. The original image is the sole identity and photographic reference. This is a local retouch of one photograph, not a new portrait of a similar person.

HIGHEST PRIORITY — IDENTITY
Preserve the same person's recognizable identity and original photographic characteristics as closely as possible. Preserve facial proportions, nose geometry, eye geometry and spacing, brow bone, jaw and chin shape, face shape, cheek structure, smile and expression, teeth, apparent age, gender presentation, hairstyle and hairline, pose, head angle, body shape, lighting direction and quality, camera angle, focal characteristics, crop, clothing, and background.

Preserve identity-carrying skin detail: freckles, moles, beauty marks, scars, birthmarks, pores, and fine lines. These are not blemishes to correct.

Do not beautify, slim, reshape, symmetrize, age, de-age, smooth, airbrush, or otherwise retouch the face. Do not change hair, expression, gaze direction, or the environment. Do not replace the face. If you cannot apply a cosmetic change without altering underlying facial structure, apply less of it.

ONLY CHANGE
Visible cosmetic makeup: colour, placement, cosmetic texture, finish, and intensity, following the validated plan below. Makeup sits on the skin as a thin translucent layer and must follow the existing light direction and shadows in the photograph. Keep real skin texture visible through the makeup. Deeper skin tones must keep their depth — do not lighten skin under foundation.

Do not add text, labels, borders, watermarks, jewellery, lashes beyond the plan, accessories, filters, or additional people. Do not alter image dimensions or aspect ratio.

VARIATION
This is variation ${variationNumber}. Vary only the cosmetic interpretation within the plan — such as blend softness, placement emphasis, or finish. Never vary identity, framing, or lighting to create difference.

Return one edited image only.

Style: ${style}
Validated makeup plan: ${JSON.stringify(recommendation)}
`.trim();
}
