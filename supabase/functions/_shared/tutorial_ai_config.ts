import {
  TUTORIAL_CATEGORIES,
  type TutorialCategory,
} from "./tutorial_vocabulary.ts";

/// The single server-side home for tutorial AI configuration.
///
/// SoT requires exactly one maintainable location for the model, the output
/// resolution, and the prompt version, so that no category can drift onto a
/// different model or resolution and no caller can select either. Everything
/// here is read server-side only; the client supplies none of it.

/// The locked guideline renderer.
///
/// Distinct from the canonical final-preview model (gemini-3-pro-image): that
/// one produces the look, this one draws instructions over it. Overridable by
/// env for a controlled rollout, never by a request.
export const TUTORIAL_GUIDELINE_MODEL =
  Deno.env.get("GEMINI_TUTORIAL_MODEL")?.trim() || "gemini-3.1-flash-image";

/// The locked initial-baseline output resolution for every generated step.
///
/// Fixed at 1K while the quality baseline is established. Resolutions are never
/// mixed within a tutorial — comparing steps rendered at different sizes would
/// make the baseline meaningless — and 0.5K is not an option until the 1K
/// baseline is locked and explicitly approved.
export const TUTORIAL_OUTPUT_RESOLUTION = "1K" as const;

// Bumped from v4_1 when the prompt gained per-category landmarks and a
// category-specific prohibition. Every category's rendered prompt changed,
// including the pilot, so reusing v4_1 would misreport what produced a step.
export const TUTORIAL_GUIDELINE_PROMPT_VERSION = "tutorial_guideline_v4_2";

/// Categories the renderer will generate.
///
/// V4-9 shipped one pilot category; V4-10 extends this to the full controlled
/// vocabulary, so every category the manifest includes can be rendered. This
/// stays an explicit set rather than "anything in the vocabulary" so a future
/// category added to the vocabulary cannot reach the model before someone has
/// written and reviewed its guidance.
export const RENDERABLE_CATEGORIES: ReadonlySet<TutorialCategory> = new Set<
  TutorialCategory
>(TUTORIAL_CATEGORIES);

export function isRenderableCategory(category: TutorialCategory): boolean {
  return RENDERABLE_CATEGORIES.has(category);
}

/// How long one generation may run, and how many attempts it gets.
///
/// One retry, and only for a technical failure that produced no usable image. A
/// model that returns a poor-but-valid guideline is not retried: that would
/// double the cost for a judgement the renderer cannot make.
export const GUIDELINE_REQUEST_TIMEOUT_MS = 90_000;
export const GUIDELINE_MAXIMUM_ATTEMPTS = 2;

/// How long a step may sit in `generating` before another request may take it
/// over.
///
/// Client cancellation never proves server cancellation, so an abandoned
/// request must not lock a step forever — but the window has to exceed the
/// request timeout, or two callers could generate concurrently.
export const GUIDELINE_LOCK_TIMEOUT_MS = GUIDELINE_REQUEST_TIMEOUT_MS + 30_000;

/// The private storage path for one rendered guideline.
///
/// Shaped to satisfy the `tutorial_v4_steps_guideline_path_owned` database check:
/// it must begin with the owner's uuid and contain a `/tutorials/` segment,
/// which is what keeps a guideline from ever colliding with the original selfie
/// (`/original/`) or the canonical preview (`/generated/`).
///
/// The attempt number is part of the name, so a regeneration writes a new
/// object instead of overwriting the previous one — the bucket has no update
/// policy by design.
export function guidelineStoragePath(options: {
  userId: string;
  analysisId: string;
  tutorialSessionId: string;
  category: TutorialCategory;
  attempt: number;
  extension: string;
}): string {
  const padded = options.attempt.toString().padStart(4, "0");
  return `${options.userId}/analyses/${options.analysisId}/tutorials/` +
    `${options.tutorialSessionId}/${options.category}_${padded}.${options.extension}`;
}

/// The most times one step may ever be drawn.
///
/// The status lock prevents simultaneous duplicates and the account quota
/// bounds total spend, but neither stops one user redrawing a single step
/// repeatedly over time. This caps the cost of any individual step, and the
/// count is persisted on the row so it survives app restarts.
export const MAXIMUM_STEP_ATTEMPTS = 5;
