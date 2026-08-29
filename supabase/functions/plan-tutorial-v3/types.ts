export class FunctionFailure extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly retryable = false,
  ) {
    super(message);
  }
}

export const FINAL_LOOK = "final_look";

/**
 * The most steps a V3 plan may contain.
 *
 * This is the authoritative home of the rule. It used to live only as
 * `maxItems: 12` in the Gemini response schema, until V3-10F4.4 proved that
 * `properties.steps.maxItems` is exactly what made `gemini-3.6-flash` reject
 * the request with `400 INVALID_ARGUMENT`. Removing it from the wire without
 * enforcing it here would have quietly turned a product invariant into
 * nothing, so `parseAndValidatePlan` now rejects an over-long plan before any
 * of it is persisted.
 *
 * Twelve, not eleven, deliberately: it is the bound the previous contract
 * declared, and a bug fix is the wrong moment to change a product limit.
 * `CATEGORY_RANKS` has eleven entries and categories may not repeat, so
 * ordering and uniqueness already bind a valid plan below this — the ceiling
 * is the outer guard against a runaway response, not the working limit.
 */
export const MAXIMUM_PLAN_STEPS = 12;

/**
 * The categories a V3 tutorial may teach, in the only order they may appear.
 *
 * Mirrors `TutorialV3CategoryCatalog.canonicalOrder` in
 * `lib/features/tutorial_v3/domain/catalog/tutorial_v3_category_catalog.dart`
 * and the `tutorial_v3_steps_category_valid` check constraint. A plan omits
 * categories freely — the count is dynamic — but whatever it includes must
 * appear in this relative order.
 */
export const CATEGORY_RANKS: Record<string, number> = {
  foundation: 0,
  concealer: 1,
  contour_bronzer: 2,
  blush: 3,
  highlighter: 4,
  eyebrow: 5,
  eyeshadow: 6,
  eyeliner: 7,
  lipstick: 8,
  lip_gloss: 9,
  final_look: 10,
};

export const ALLOWED_CATEGORIES = new Set(Object.keys(CATEGORY_RANKS));

/** The persisted `makeup_style` codes, from `MakeupStyleCatalog`. */
export const ALLOWED_STYLES = new Set([
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

/**
 * The complete set of instructional marks a guideline may draw.
 *
 * Exhaustive by design: finished makeup, retouching, beautification and
 * typography are not members, so a plan has no way to ask for them. Mirrors
 * `TutorialV3GuidelineGraphic`.
 */
export const ALLOWED_GRAPHICS = new Set([
  "translucent_zone",
  "arrow",
  "path",
  "soft_band",
  "marker",
]);

/**
 * Which facial attributes each category may reason about.
 *
 * Mirrors `TutorialV3CategoryCatalog.relevantAttributes`. A step that carries
 * an attribute outside its scope is rejected: flooding a step with
 * irrelevant attributes is what makes personalization look fake.
 */
export const CATEGORY_ATTRIBUTES: Record<string, ReadonlySet<string>> = {
  foundation: new Set(["skin_tone", "undertone"]),
  concealer: new Set(["eye_shape", "skin_tone"]),
  contour_bronzer: new Set(["face_shape"]),
  blush: new Set(["face_shape"]),
  highlighter: new Set(["face_shape"]),
  eyebrow: new Set(["face_shape"]),
  eyeshadow: new Set(["eye_shape"]),
  eyeliner: new Set(["eye_shape"]),
  lipstick: new Set(["lip_shape"]),
  lip_gloss: new Set(["lip_shape"]),
  final_look: new Set<string>(),
};

export const ALLOWED_ATTRIBUTES = new Set([
  "face_shape",
  "skin_tone",
  "undertone",
  "eye_shape",
  "lip_shape",
]);

/** The only target reference mode a plan may currently use. */
export const FULL_CANONICAL_PREVIEW = "full_canonical_preview";

export type SourceMode = "standard" | "makeup_kit";

export interface OwnedProduct {
  productId: string;
  category: string;
  colorHex: string;
  finish: string;
  productName: string | null;
  colorLabel: string | null;
  foundationDepth: string | null;
  foundationUndertone: string | null;
}

export interface GuidelineVisualIntent {
  description: string;
  graphics: string[];
}

/**
 * One validated planned step.
 *
 * There is deliberately no result field of any kind. V3 generates no
 * intermediate makeup appearance, so a per-step result is not representable
 * here, in the schema, or in the database.
 */
export interface PlannedStep {
  stepIndex: number;
  category: string;
  productId: string | null;
  productName: string | null;
  shadeName: string | null;
  colorHex: string | null;
  finish: string | null;
  coverage: string | null;
  intensity: string | null;
  whereToApply: string;
  direction: string;
  technique: string;
  amount: string | null;
  toolSuggestion: string | null;
  personalizedTip: string | null;
  avoid: string | null;
  faceAttributes: Record<string, string>;
  faceRationale: string;
  targetRationale: string;
  targetLookCues: string[];
  guidelineVisualIntent: GuidelineVisualIntent | null;
}

export interface PlannedTutorial {
  steps: PlannedStep[];
}
