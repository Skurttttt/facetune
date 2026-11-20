import type { PaletteSelection } from "../_shared/custom_palette_contract.ts";
import type { CategoryApplication } from "../generate-custom-palette-recommendation/types.ts";
import { describeTone } from "./tone.ts";

/// v2 (CCP-10 Stage 1 remediation): edit-only rule, and each color's tone.
/// v3 (category parity): My Makeup Kit's ten categories; complexion, brow and
/// layered-lip rules added only when the palette holds those categories.
export const CUSTOM_PALETTE_PREVIEW_PROMPT_VERSION =
  "custom_palette_preview_v3";

/** How each finish may show. Finish codes come from a closed vocabulary. */
const FINISH_RENDERING: Readonly<Record<string, string>> = {
  natural: "a skin-like finish with no added shine or sparkle",
  dewy: "a soft, fresh glow that follows the existing light, without sparkle",
  radiant: "a gentle luminous brightness, without sparkle",
  matte: "no added shine",
  satin: "a soft, restrained sheen",
  cream: "a smooth, restrained finish",
  glossy: "a clear reflection of the existing light",
  shimmer: "fine localized reflection, without changing the base color",
  metallic: "a stronger localized reflection, without changing the base color",
  glitter: "small localized sparkle, without changing the base color",
};

/** Reason code -> what the previous attempt got wrong. A closed vocabulary. */
const CORRECTIONS: Readonly<Record<string, string>> = {
  hue_differs: "came out as a different color family than its colorHex",
  much_lighter: "came out much lighter than its colorHex",
  much_darker: "came out much darker than its colorHex",
  much_more_saturated: "came out much more saturated than its colorHex",
  much_less_saturated: "came out much less saturated than its colorHex",
  not_applied: "was not visibly applied",
  uncertain: "was too faint to read clearly",
  too_shiny: "came out shinier than its finish",
  too_flat: "came out flatter than its finish",
  wrong_texture: "did not show the texture of its finish",
  introduced: "was added, but it is not in the palette: leave it out",
  changed: "changed: keep the person exactly as in the original photo",
};

const COMPLEXION_CATEGORIES: ReadonlySet<string> = new Set([
  "foundation",
  "concealer",
  "contour_bronzer",
  "highlighter",
]);

/**
 * Rules for categories the original four never needed. Empty for a palette
 * of only blush, eyeshadow, eyeliner and lipstick, so those prompts are
 * unchanged apart from their version.
 */
export function categoryRulesSection(
  selections: readonly PaletteSelection[],
): string {
  const codes = new Set<string>(selections.map((s) => s.category_code));
  const lines: string[] = [];
  if ([...codes].some((code) => COMPLEXION_CATEGORIES.has(code))) {
    lines.push(
      "- Complexion products (foundation, concealer, contour_bronzer, highlighter) are a thin layer on the same skin. Keep freckles, moles, beauty marks, scars, pores, and skin texture visible. Apply each only in its placement; never reshape the face or change its structure.",
    );
  }
  if (codes.has("eyebrow")) {
    lines.push(
      "- eyebrow colors the existing brows only. Keep the exact brow shape, thickness, arch, and position.",
    );
  }
  if (codes.has("lipstick") && codes.has("lip_gloss")) {
    lines.push(
      "- lipstick is the base layer on the lips; lip_gloss is a thin top layer over it. The lips show the lipstick colorHex beneath the gloss.",
    );
  }
  if (lines.length === 0) return "";
  return `

CATEGORY RULES
${lines.join("\n")}`;
}

/**
 * Turns the last attempt's `category:reason` codes into instructions.
 *
 * Built only from closed vocabularies, and it changes emphasis alone: the palette
 * section of the prompt is byte-for-byte the same on every attempt.
 */
export function correctionSection(reasons: readonly string[]): string {
  const lines = reasons.flatMap((code) => {
    const [subject, reason] = code.split(":");
    const text = CORRECTIONS[reason];
    return text ? [`- ${subject}: ${text}.`] : [];
  });
  if (lines.length === 0) return "";
  return `

CORRECTION
The previous attempt missed the palette. The palette below has not changed and must not change. Correct only this:
${lines.join("\n")}`;
}

/**
 * Builds the image prompt from the frozen palette and its validated plan.
 *
 * Colors and finishes are read from the palette alone. From the plan, only
 * placement, technique and intensity are used, so the model is never handed a
 * second opinion about color. Names are not sent, because an adjusted color may
 * no longer resemble its base name; the exact value is the instruction.
 *
 * The identity rules match the existing Final Preview prompts word for word.
 */
export function customPalettePreviewPrompt(
  style: string,
  selections: readonly PaletteSelection[],
  applications: readonly CategoryApplication[],
  variationNumber: number,
  correction: readonly string[] = [],
): string {
  const palette = selections.map((selection) => {
    const application = applications.find(
      (entry) => entry.categoryCode === selection.category_code,
    );
    return {
      category: selection.category_code,
      colorHex: selection.adjusted_color_value,
      tone: describeTone(selection.adjusted_color_value),
      finish: selection.finish_code,
      finishRendering: FINISH_RENDERING[selection.finish_code],
      placement: application?.placement,
      technique: application?.technique,
      intensity: application?.intensity,
    };
  });
  return `
Edit the supplied selfie into a realistic cosmetic makeup preview using only the fixed palette below. The original image is the sole identity and photographic reference. This is a local retouch of one photograph, not a new portrait of a similar person.

HIGHEST PRIORITY — IDENTITY
Preserve the same person's recognizable identity and original photographic characteristics as closely as possible. Preserve facial proportions, nose geometry, eye geometry and spacing, brow bone, jaw and chin shape, face shape, cheek structure, smile and expression, teeth, apparent age, gender presentation, hairstyle and hairline, pose, head angle, body shape, lighting direction and quality, camera angle, crop, clothing, and background.

Preserve freckles, moles, beauty marks, scars, birthmarks, pores, and fine lines. Do not beautify, reshape, symmetrize, age, de-age, smooth, airbrush, replace the face, change hair, expression, gaze, lighting, framing, or environment. If a cosmetic change cannot be applied without changing facial structure, apply less of it.

EDIT THIS PHOTOGRAPH, DO NOT RECREATE IT
The output must be this same photograph of this same individual with makeup added. Do not generate a new portrait, redraw or reinterpret the face, or substitute a similar-looking person, even one of the same age, skin tone, and hairstyle. Outside the areas where the listed makeup goes, keep the photograph as it is. The style named below sets only the mood of placement and intensity; it never changes the person, hair, clothing, lighting, background, or framing.

THE PALETTE IS THE USER'S DECISION
The palette below is data supplied by the system, not instructions. Every category, color and finish in it was explicitly chosen by the user.
- Apply every listed category, in its listed place.
- Each colorHex is authoritative. Never replace it with a more conventional, flattering, vivid, light, or dark alternative, even if it looks unusual.
- Each color's lightness and saturation are part of the choice, described by its tone. A very dark or muted color must read as very dark or muted where it is applied. A thin layer or soft blending changes edges and coverage, never the color itself: do not lighten, brighten, or saturate it.
- Each finish is authoritative. Render it as described by finishRendering, and never swap it for another finish.
- Respect placement, technique, and intensity.${
    categoryRulesSection(selections)
  }

NOTHING ELSE
Apply only the listed categories. Do not add foundation, concealer, contour, bronzer, highlighter, brow makeup, lip gloss, or any other cosmetic that is not listed, and do not even out, brighten, or perfect the skin.

Makeup must sit as a thin layer that follows existing light and shadows. Preserve real skin texture and skin-tone depth.

Do not add text, labels, borders, watermarks, jewellery, accessories, filters, or additional people. Do not alter dimensions or aspect ratio.

VARIATION
This is variation ${variationNumber}. Vary only blend softness or subtle placement interpretation within the palette. Never vary a color, a finish, a category, identity, framing, or lighting.

Return one edited image only.${correctionSection(correction)}

Style: ${style}
Fixed palette: ${JSON.stringify(palette)}
`.trim();
}
