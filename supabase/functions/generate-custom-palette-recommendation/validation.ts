import type { PaletteSelection } from "../_shared/custom_palette_contract.ts";
import {
  type CategoryApplication,
  type CustomPalettePlan,
  FunctionFailure,
  type Intensity,
} from "./types.ts";

const INTENSITIES: ReadonlySet<string> = new Set([
  "sheer",
  "soft",
  "medium",
  "bold",
]);
const ROOT_KEYS = new Set(["applications", "overallIntensity", "summary"]);
const APPLICATION_KEYS = new Set([
  "categoryCode",
  "placement",
  "technique",
  "intensity",
  "reasoning",
]);

/**
 * Words that assert a color. The prompt forbids naming colors, so any of these
 * in prose, other than the user's own base name, is treated as a contradiction.
 *
 * This list is a backstop rather than a proof of meaning, and it errs toward
 * refusing: a refused plan costs a retry, while an accepted one that says
 * "pink" beside a red palette tells the user the AI overrode them.
 */
const COLOR_WORDS = [
  "black",
  "charcoal",
  "brown",
  "taupe",
  "nude",
  "white",
  "peach",
  "coral",
  "orange",
  "red",
  "berry",
  "pink",
  "rose",
  "magenta",
  "plum",
  "violet",
  "navy",
  "blue",
  "teal",
  "green",
  "olive",
  "gold",
  "golden",
  "bronze",
  "silver",
  "purple",
  "lilac",
  "lavender",
  "burgundy",
  "maroon",
  "crimson",
  "scarlet",
  "fuchsia",
  "mauve",
  "beige",
  "gray",
  "grey",
  "yellow",
  "turquoise",
  "copper",
];

/**
 * Finish code -> the words that assert it. `natural` and `radiant` are absent:
 * neither is a CCP finish, and both are ordinary words in placement advice.
 */
const FINISH_WORDS: Readonly<Record<string, readonly string[]>> = {
  matte: ["matte"],
  satin: ["satin"],
  shimmer: ["shimmer", "shimmery"],
  metallic: ["metallic"],
  glitter: ["glitter", "glittery"],
  cream: ["cream", "creamy"],
  glossy: ["glossy", "gloss"],
};

const hexLike = /#[0-9a-f]{3,8}\b/i;

function invalid(code = "invalid_ai_response"): FunctionFailure {
  return new FunctionFailure(
    502,
    code,
    "The recommendation service returned an invalid response.",
    true,
  );
}

function record(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw invalid();
  }
  return value as Record<string, unknown>;
}

function text(
  input: Record<string, unknown>,
  key: string,
  maximum: number,
): string {
  const value = input[key];
  if (
    typeof value !== "string" || value.trim().length < 3 ||
    value.length > maximum
  ) {
    throw invalid();
  }
  return value.trim();
}

function intensity(input: Record<string, unknown>, key: string): Intensity {
  const value = input[key];
  if (typeof value !== "string" || !INTENSITIES.has(value)) throw invalid();
  return value as Intensity;
}

function allowedWords(selections: readonly PaletteSelection[]): Set<string> {
  const allowed = new Set<string>();
  for (const selection of selections) {
    allowed.add(selection.color_label.toLowerCase());
    for (const word of FINISH_WORDS[selection.finish_code] ?? []) {
      allowed.add(word);
    }
  }
  return allowed;
}

/** Refuses prose that asserts a color or finish the user did not choose. */
function assertNoConflict(
  prose: string,
  selections: readonly PaletteSelection[],
): void {
  if (hexLike.test(prose)) throw invalid("conflicting_palette_text");
  const allowed = allowedWords(selections);
  const lower = prose.toLowerCase();
  const asserted = [...COLOR_WORDS, ...Object.values(FINISH_WORDS).flat()];
  for (const word of asserted) {
    if (allowed.has(word)) continue;
    if (new RegExp(`\\b${word}\\b`).test(lower)) {
      throw invalid("conflicting_palette_text");
    }
  }
}

/**
 * Parses the model's plan against the frozen palette.
 *
 * Nothing the model returns can change the palette: the result holds no color
 * or finish, and a response that tries to supply one is refused, never merged.
 * Each category's prose is judged against that category's own choice, so a
 * blush described with the lipstick's finish is still a contradiction. The
 * summary spans the look, so it is judged against all of them.
 */
export function parseCustomPaletteRecommendation(
  value: string,
  selections: readonly PaletteSelection[],
): CustomPalettePlan {
  let parsed: unknown;
  try {
    parsed = JSON.parse(value);
  } catch {
    throw invalid();
  }
  const root = record(parsed);
  if (Object.keys(root).some((key) => !ROOT_KEYS.has(key))) {
    throw invalid("conflicting_palette_value");
  }
  if (!Array.isArray(root.applications)) throw invalid();

  const byCategory = new Map<string, CategoryApplication>();
  for (const entry of root.applications) {
    const input = record(entry);
    if (Object.keys(input).some((key) => !APPLICATION_KEYS.has(key))) {
      throw invalid("conflicting_palette_value");
    }
    const categoryCode = input.categoryCode;
    const selection = selections.find((s) => s.category_code === categoryCode);
    if (!selection || byCategory.has(selection.category_code)) throw invalid();
    const application: CategoryApplication = {
      categoryCode: selection.category_code,
      placement: text(input, "placement", 220),
      technique: text(input, "technique", 220),
      intensity: intensity(input, "intensity"),
      reasoning: text(input, "reasoning", 240),
    };
    assertNoConflict(
      [
        application.placement,
        application.technique,
        application.reasoning,
      ].join(" "),
      [selection],
    );
    byCategory.set(selection.category_code, application);
  }
  if (byCategory.size !== selections.length) throw invalid();

  const summary = text(root, "summary", 300);
  assertNoConflict(summary, selections);
  return {
    // Canonical order, whatever order the model answered in.
    applications: selections.map((s) => byCategory.get(s.category_code)!),
    overallIntensity: intensity(root, "overallIntensity"),
    summary,
  };
}
