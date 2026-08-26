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

/** One step exactly as the planner is allowed to author it. */
export type PlannedStep = {
  category: string;
  title: string;
  whatToApply: string;
  whereToApply: string;
  direction: string;
  technique: string;
  intensity: string;
  faceRationale: string;
  targetLookCues: string;
  amount: string | null;
  toolSuggestion: string | null;
  personalizedTip: string | null;
  avoid: string | null;
  /** Kit mode only: which owned product this step teaches. */
  productId: string | null;
};

export type PlannedTutorial = {
  steps: PlannedStep[];
};

/** Point-in-time product data the server attaches; never authored by the AI. */
export type OwnedProduct = {
  productId: string;
  category: string;
  colorHex: string;
  finish: string;
  productName: string | null;
  colorLabel: string | null;
  foundationDepth: string | null;
  foundationUndertone: string | null;
};

/**
 * The tutorial categories a step may teach, with the canonical ordering rank
 * from the V2 Source of Truth (§5).
 *
 * This must stay identical to `TutorialV2Category` in
 * `lib/features/tutorial_v2/domain/entities/tutorial_v2_category.dart` and to
 * the `tutorial_v2_steps_category_valid` check constraint.
 */
export const CATEGORY_RANKS: Record<string, number> = {
  foundation: 10,
  concealer: 20,
  contour_bronzer: 30,
  blush: 40,
  highlighter: 50,
  eyebrow: 60,
  eyeshadow: 70,
  eyeliner: 80,
  lipstick: 90,
  lip_gloss: 100,
  final_look: 1000,
};

export const FINAL_LOOK = "final_look";

export const MAKEUP_CATEGORIES = Object.keys(CATEGORY_RANKS).filter(
  (category) => category !== FINAL_LOOK,
);

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

export const ALLOWED_INTENSITIES = ["sheer", "soft", "medium", "bold"];
