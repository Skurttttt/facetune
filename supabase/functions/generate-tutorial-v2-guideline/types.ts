export type GeneratedImage = {
  bytes: Uint8Array;
  mimeType: "image/png" | "image/jpeg" | "image/webp";
};

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

/**
 * The authored half of one persisted step, read back from
 * `tutorial_v2_steps.step_spec_json`.
 *
 * This is the single source of truth the guideline must visualize. The image
 * model never authors any of these fields — it only renders what they already
 * say.
 */
export type StepSpec = {
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
};

export type ProductSnapshot = {
  productId: string;
  category: string;
  colorHex: string;
  finish: string;
  productName: string | null;
  colorLabel: string | null;
};

/** Human-readable category labels used inside the guideline prompt. */
export const CATEGORY_LABELS: Record<string, string> = {
  foundation: "Foundation",
  concealer: "Concealer",
  contour_bronzer: "Contour and Bronzer",
  blush: "Blush",
  highlighter: "Highlighter",
  eyebrow: "Brows",
  eyeshadow: "Eyeshadow",
  eyeliner: "Eyeliner",
  lipstick: "Lip Colour",
  lip_gloss: "Lip Gloss",
  final_look: "Final Look",
};

export const FINAL_LOOK = "final_look";

/**
 * Which facial attributes actually change how a category is applied.
 *
 * Sending every attribute for every category invites the model to justify
 * unrelated changes ("warm undertone, so I warmed the whole face"). Each
 * category gets only what genuinely governs its placement.
 */
export const CATEGORY_ATTRIBUTES: Record<string, string[]> = {
  foundation: ["skinTone", "undertone"],
  concealer: ["skinTone", "undertone"],
  contour_bronzer: ["faceShape", "skinTone"],
  blush: ["faceShape", "skinTone", "undertone"],
  highlighter: ["faceShape", "skinTone"],
  eyebrow: ["faceShape", "eyeShape"],
  eyeshadow: ["eyeShape", "eyeColor"],
  eyeliner: ["eyeShape"],
  lipstick: ["lipShape", "undertone"],
  lip_gloss: ["lipShape"],
};
