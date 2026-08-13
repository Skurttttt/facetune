import type { NormalizedKitPreviewPlan } from "./types.ts";

export const KIT_MAKEUP_PREVIEW_PROMPT_VERSION = "kit_makeup_preview_v1";

export function kitMakeupPreviewPrompt(
  style: string,
  plan: NormalizedKitPreviewPlan,
  variationNumber: number,
): string {
  return `
Edit the supplied selfie into a realistic cosmetic makeup preview using only the validated registered-product plan below. The original image is the sole identity and photographic reference. This is a local retouch of one photograph, not a new portrait of a similar person.

HIGHEST PRIORITY — IDENTITY
Preserve the same person's recognizable identity and original photographic characteristics as closely as possible. Preserve facial proportions, nose geometry, eye geometry and spacing, brow bone, jaw and chin shape, face shape, cheek structure, smile and expression, teeth, apparent age, gender presentation, hairstyle and hairline, pose, head angle, body shape, lighting direction and quality, camera angle, crop, clothing, and background.

Preserve freckles, moles, beauty marks, scars, birthmarks, pores, and fine lines. Do not beautify, reshape, symmetrize, age, de-age, smooth, airbrush, replace the face, change hair, expression, gaze, lighting, framing, or environment. If a cosmetic change cannot be applied without changing facial structure, apply less of it.

REGISTERED PRODUCTS ONLY
Apply only the listed selections. Each exact normalized HEX color is authoritative. Do not replace a shade with a more conventional, flattering, vivid, light, or dark alternative. Respect placement, technique, and intensity. Render finish only where visually meaningful: matte should avoid added shine; natural/satin/cream should remain restrained; dewy/glossy/radiant may reflect existing light; shimmer/metallic/glitter may add localized reflection without changing the base color. Do not invent makeup for absent categories.

Makeup must sit as a thin layer that follows existing light and shadows. Preserve real skin texture and skin-tone depth. Never label, imply, or depict an unrelated shade as a registered product.

Do not add text, labels, borders, watermarks, jewellery, accessories, filters, additional people, or cosmetics outside the plan. Do not alter dimensions or aspect ratio.

VARIATION
This is variation ${variationNumber}. Vary only blend softness or subtle placement interpretation within the exact validated plan. Never vary registered colors, product finishes, identity, framing, or lighting.

Return one edited image only.

Style: ${style}
Validated registered-product plan: ${JSON.stringify(plan)}
`.trim();
}
