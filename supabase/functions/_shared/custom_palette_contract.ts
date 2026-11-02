/**
 * The canonical Custom Color Palette contract (CCP-1), enforced server-side.
 *
 * Mirrors `lib/features/custom_palette/domain/`; a Dart test compares the two
 * catalogs so they cannot drift. The client's validation is a convenience: this
 * is the check that counts, and it never repairs a palette. It refuses it.
 */

export const CUSTOM_COLOR_PALETTE_SOURCE_MODE = "custom_color_palette";
export const CUSTOM_COLOR_PALETTE_CONTRACT_VERSION =
  "custom_color_palette_contract_v1";

/** The supported categories, in Tutorial application order. */
export const CUSTOM_PALETTE_CATEGORIES = [
  "blush",
  "eyeshadow",
  "eyeliner",
  "lipstick",
] as const;

export type CustomPaletteCategory = typeof CUSTOM_PALETTE_CATEGORIES[number];

export const CUSTOM_PALETTE_FINISHES: Readonly<
  Record<CustomPaletteCategory, readonly string[]>
> = {
  blush: ["matte", "satin", "shimmer"],
  eyeshadow: ["matte", "satin", "shimmer", "metallic", "glitter"],
  eyeliner: ["matte", "satin", "glossy"],
  lipstick: ["matte", "satin", "cream", "glossy"],
};

/** Every finish code the app knows, so "unknown" and "not allowed here" differ. */
const KNOWN_FINISHES: ReadonlySet<string> = new Set([
  "matte",
  "natural",
  "dewy",
  "satin",
  "radiant",
  "shimmer",
  "metallic",
  "glitter",
  "cream",
  "glossy",
]);

/** Base color value -> its one catalog label. */
export const CUSTOM_PALETTE_SWATCHES: Readonly<Record<string, string>> = {
  "#1B1B1B": "Black",
  "#3A3A3C": "Charcoal",
  "#5C3A21": "Brown",
  "#9C8574": "Taupe",
  "#D9A58B": "Nude",
  "#F5F2EC": "White",
  "#F2A07B": "Peach",
  "#E8636B": "Coral",
  "#E8711A": "Orange",
  "#C8102E": "Red",
  "#7A2E4A": "Berry",
  "#E75480": "Pink",
  "#C97B84": "Rose",
  "#B5179E": "Magenta",
  "#6B4358": "Plum",
  "#6A2FB5": "Violet",
  "#1F2F6B": "Navy",
  "#1F6FD6": "Blue",
  "#0F8B8D": "Teal",
  "#2E7D4F": "Green",
  "#6E7355": "Olive",
  "#C9A227": "Gold",
  "#8A5A34": "Bronze",
  "#B8BCC2": "Silver",
};

export const CUSTOM_PALETTE_STYLES: ReadonlySet<string> = new Set([
  "natural",
  "everyday",
  "office",
  "soft_glam",
  "full_glam",
  "bridal",
  "korean",
  "clean_girl",
  "party",
  "date_night",
  "no_makeup_makeup",
  "old_money",
]);

export type PaletteContractCode =
  | "invalid_palette_contract"
  | "invalid_request_id"
  | "invalid_analysis_id"
  | "invalid_style"
  | "palette_empty"
  | "selection_incomplete"
  | "invalid_color"
  | "invalid_base_color"
  | "unsupported_category"
  | "unsupported_finish"
  | "finish_not_applicable"
  | "duplicate_category";

/** A palette the contract refuses. Carries a code, never the offending value. */
export class PaletteContractError extends Error {
  constructor(readonly code: PaletteContractCode) {
    super(code);
    this.name = "PaletteContractError";
  }
}

/** One frozen category choice, exactly as it is persisted. */
export interface PaletteSelection {
  category_code: CustomPaletteCategory;
  base_color_value: string;
  adjusted_color_value: string;
  color_label: string;
  finish_code: string;
}

export interface CustomPaletteRequest {
  paletteRequestId: string;
  analysisId: string;
  style: string;
  derivedFromPaletteId: string | null;
  /** In canonical category order. */
  selections: PaletteSelection[];
}

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
// Canonical form only. Lowercase is malformed here, not normalized.
const canonicalHex = /^#[0-9A-F]{6}$/;

const REQUEST_KEYS = new Set([
  "paletteRequestId",
  "paletteVersion",
  "sourceMode",
  "analysisId",
  "style",
  "derivedFromPaletteId",
  "categorySelections",
]);
const SELECTION_KEYS = new Set([
  "categoryCode",
  "baseColorValue",
  "adjustedColorValue",
  "colorLabel",
  "finishCode",
]);

function plainObject(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function hasOnlyKeys(
  value: Record<string, unknown>,
  allowed: ReadonlySet<string>,
): boolean {
  return Object.keys(value).every((key) => allowed.has(key));
}

function parseSelection(value: unknown): PaletteSelection {
  const input = plainObject(value);
  if (!input || !hasOnlyKeys(input, SELECTION_KEYS)) {
    throw new PaletteContractError("invalid_palette_contract");
  }
  const code = input.categoryCode;
  if (
    typeof code !== "string" ||
    !(CUSTOM_PALETTE_CATEGORIES as readonly string[]).includes(code)
  ) {
    throw new PaletteContractError("unsupported_category");
  }
  const category = code as CustomPaletteCategory;
  const base = input.baseColorValue;
  const adjusted = input.adjustedColorValue;
  const finish = input.finishCode;
  if (
    base === null || base === undefined ||
    adjusted === null || adjusted === undefined ||
    finish === null || finish === undefined
  ) {
    throw new PaletteContractError("selection_incomplete");
  }
  if (
    typeof base !== "string" || !canonicalHex.test(base) ||
    typeof adjusted !== "string" || !canonicalHex.test(adjusted)
  ) {
    throw new PaletteContractError("invalid_color");
  }
  // The label must be the catalog's own, so no free text can ever reach a
  // prompt or a stored palette through it.
  const label = CUSTOM_PALETTE_SWATCHES[base];
  if (label === undefined || input.colorLabel !== label) {
    throw new PaletteContractError("invalid_base_color");
  }
  if (typeof finish !== "string" || !KNOWN_FINISHES.has(finish)) {
    throw new PaletteContractError("unsupported_finish");
  }
  if (!CUSTOM_PALETTE_FINISHES[category].includes(finish)) {
    throw new PaletteContractError("finish_not_applicable");
  }
  // Fixed key order: the digest below depends on it.
  return {
    category_code: category,
    base_color_value: base,
    adjusted_color_value: adjusted,
    color_label: label,
    finish_code: finish,
  };
}

/**
 * Validates a raw request body. The body must not name a user: ownership comes
 * from the JWT alone, so an unknown key such as `userId` is refused outright.
 */
export function parseCustomPaletteRequest(
  value: unknown,
): CustomPaletteRequest {
  const input = plainObject(value);
  if (
    !input ||
    !hasOnlyKeys(input, REQUEST_KEYS) ||
    input.paletteVersion !== CUSTOM_COLOR_PALETTE_CONTRACT_VERSION ||
    input.sourceMode !== CUSTOM_COLOR_PALETTE_SOURCE_MODE
  ) {
    throw new PaletteContractError("invalid_palette_contract");
  }
  const requestId = input.paletteRequestId;
  if (typeof requestId !== "string" || !uuidPattern.test(requestId)) {
    throw new PaletteContractError("invalid_request_id");
  }
  const analysisId = input.analysisId;
  if (typeof analysisId !== "string" || !uuidPattern.test(analysisId)) {
    throw new PaletteContractError("invalid_analysis_id");
  }
  const style = input.style;
  if (typeof style !== "string" || !CUSTOM_PALETTE_STYLES.has(style)) {
    throw new PaletteContractError("invalid_style");
  }
  const derived = input.derivedFromPaletteId ?? null;
  if (
    derived !== null &&
    (typeof derived !== "string" || !uuidPattern.test(derived))
  ) {
    throw new PaletteContractError("invalid_palette_contract");
  }
  const raw = input.categorySelections;
  if (!Array.isArray(raw)) {
    throw new PaletteContractError("invalid_palette_contract");
  }
  if (raw.length === 0) throw new PaletteContractError("palette_empty");

  const selections = raw.map(parseSelection);
  if (
    new Set(selections.map((s) => s.category_code)).size !== selections.length
  ) {
    throw new PaletteContractError("duplicate_category");
  }
  selections.sort((a, b) =>
    CUSTOM_PALETTE_CATEGORIES.indexOf(a.category_code) -
    CUSTOM_PALETTE_CATEGORIES.indexOf(b.category_code)
  );
  return {
    paletteRequestId: requestId,
    analysisId,
    style,
    derivedFromPaletteId: derived as string | null,
    selections,
  };
}

/** SHA-256 of the canonical palette, as lowercase hex. */
export async function paletteDigest(
  selections: readonly PaletteSelection[],
): Promise<string> {
  const bytes = new TextEncoder().encode(JSON.stringify(selections));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
