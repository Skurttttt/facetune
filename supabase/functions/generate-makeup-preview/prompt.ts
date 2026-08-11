export const MAKEUP_PREVIEW_PROMPT_VERSION = "makeup_preview_v1";

export function makeupPreviewPrompt(
  style: string,
  recommendation: Record<string, unknown>,
  variationNumber: number,
): string {
  return `
Edit the supplied selfie into a realistic cosmetic makeup preview. The original image is the sole identity and photographic reference.

HIGHEST PRIORITY: preserve the same person's recognizable identity and original photographic characteristics as closely as possible. Preserve facial proportions, nose geometry, eye geometry, jaw, face shape, smile and expression, apparent age, gender presentation, hairstyle, pose, body shape, lighting, skin identity features, camera angle, crop, clothing, and background. Do not beautify, reshape, age, de-age, retouch, smooth away identity features, change hair, change expression, or alter the environment.

ONLY change visible cosmetic makeup: color, placement, cosmetic texture, finish, and intensity according to the validated plan below. Keep real skin texture and photorealistic detail. Do not add text, labels, borders, watermarks, accessories, or additional people. Return one edited image only.

Style: ${style}
Variation number: ${variationNumber}
Validated makeup plan: ${JSON.stringify(recommendation)}
`.trim();
}
