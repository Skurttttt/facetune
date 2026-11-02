/// The guideline renderer's context for a Custom Color Palette step.
///
/// Fills the same background slot a kit step's product note uses, so the protected
/// guideline prompt is unchanged. Built only from closed vocabularies: a validated
/// hex value and a finish code.
export function paletteNote(
  selections: ReadonlyArray<{ colorHex: string; finish: string }>,
): string | null {
  if (selections.length === 0) return null;
  const described = selections
    .map((s) => `${s.colorHex} (${s.finish} finish)`)
    .join(" and ");
  return `CONTEXT ONLY: the person chose ${described}. This tells you the ` +
    `finish, not the position. It does NOT change where the markings go — ` +
    `IMAGE B remains the only placement authority. Do not paint this shade ` +
    `onto the skin and do not write it in the image.`;
}
