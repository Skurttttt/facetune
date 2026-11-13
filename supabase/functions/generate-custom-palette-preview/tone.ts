/**
 * A plain-words description of a color's lightness and saturation.
 *
 * Image and vision models read a hex value loosely, and CCP-10 Stage 1 showed a
 * near-black palette rendered materially brighter and still judged consistent. Both
 * the preview and the validator therefore see the same description beside the hex.
 *
 * This describes; it never decides. No acceptance rule reads these words, and they
 * claim no colorimetric tolerance. Saturation uses chroma rather than HSL
 * saturation, because HSL calls near-black colors "saturated", which would tell a
 * model the opposite of what a person sees.
 */
export interface ColorTone {
  lightness: "very dark" | "dark" | "medium" | "light" | "very light";
  saturation: "muted" | "moderate" | "vivid";
}

export function colorTone(hex: string): ColorTone {
  const [r, g, b] = [1, 3, 5].map((i) =>
    parseInt(hex.slice(i, i + 2), 16) / 255
  );
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const lightness = (max + min) / 2;
  const chroma = max - min;
  return {
    lightness: lightness <= 0.15
      ? "very dark"
      : lightness <= 0.35
      ? "dark"
      : lightness <= 0.65
      ? "medium"
      : lightness <= 0.85
      ? "light"
      : "very light",
    saturation: chroma < 0.15 ? "muted" : chroma < 0.45 ? "moderate" : "vivid",
  };
}

export function describeTone(hex: string): string {
  const tone = colorTone(hex);
  return `${tone.lightness}, ${tone.saturation}`;
}
