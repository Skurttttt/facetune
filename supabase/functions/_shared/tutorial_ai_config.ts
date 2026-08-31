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
/// A separate responsibility from the canonical final preview: that one
/// produces the look, this one draws instructions over it. They happen to run
/// the same model in production — the deployed GEMINI_IMAGE_MODEL secret was
/// verified to be gemini-3.1-flash-image — so do not read the two as different
/// by default. An earlier version of this comment named gemini-3-pro-image,
/// which matches only the unreached in-code fallback in the preview functions,
/// not what production runs.
///
/// Overridable by env for a controlled rollout, never by a request.
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
//
// Bumped again to v4_3 by the V4-QA-2 representative gate. The shared sections
// changed for every category — explicit "what changed" framing, a
// minimum-useful-geometry rule, and the literal negative contract — and Blush,
// Eyeshadow, Eyeliner, and Lips additionally gained their visual-difference
// questions and absolute rules. One version covers all nine because every
// rendered prompt differs from v4_2; a per-category version would imply the
// untouched five render what they rendered before, and they do not.
//
// Bumped again to v4_4 by V4-QA-2B, after POCO X3 GT evidence showed the
// representative guidelines were readable but drifted toward standard makeup
// diagrams rather than the specific target. Shared: explicit image-role
// authorities, a declared CURRENT CATEGORY, the six questions a mark must
// answer, the named guide vocabulary, the full no-beautify/no-reshape contract,
// and a paired-feature rule. Per-category: expanded visual-difference questions
// for Blush, Eyeshadow, Eyeliner, and Lips, plus what a good and a bad result
// contain. The other five categories keep their own fragments verbatim.
//
// Bumped to v4_5 by V4-QA-2C. v4_4 fixed guideline-only compliance and identity
// preservation on device but still failed exact target fidelity: Blush FAIL,
// Eyeliner FAIL, Lips FAIL, Eyeshadow ACCEPTABLE. The cause was structural — the
// per-category description was generic and sat last before the drawing rules, so
// the model read a template and drew it. v4_5 adds a comparison-first working
// order, a target-bounds contract, a clause demoting that description to
// orientation, a mark-the-difference-not-the-anatomy rule, and a per-mark
// evidence check in final position; and rewrites the four representative
// fragments from category description into target extraction.
//
// Bumped to v4_6 by V4-QA-2D. v4_5 improved target fidelity on device — Eyeliner
// and Lips reached PASS, Eyeshadow ACCEPTABLE — but visible makeup appeared
// under the guides across several steps. The cause was contradictory wording
// rather than missing emphasis: v4_5 told the model IMAGE B was "the authority
// for what the <category> looks like ... and visible intensity", which grants
// appearance; and "render ... guides that would let someone reproduce that
// change" put "render" beside "reproduce". v4_6 restricts IMAGE B to WHERE and
// WHAT SHAPE, forbids copying any appearance from it, makes intensity
// information rather than something rendered, forbids a mark becoming a fill,
// adds a per-category ban for all nine, and ends with an erase-the-marks test.
// Blush additionally gains the footprint-versus-blending-route distinction.
//
// Bumped to v4_7 by V4-QA-3, which propagated the representative architecture to
// Foundation, Concealer, Contour/Bronzer, Highlighter, and Eyebrows. Each was
// rewritten from category description into target extraction and given its own
// visual-difference questions, absolute rules, and good/bad result descriptions
// — the same structural fix that the representative four needed. Each also names
// the specific conventional diagram it collapses into: the full-face perimeter,
// the under-eye triangle, the standard contour map, the five-point highlight
// map, and brow construction geometry. The four representative fragments are
// unchanged, so they remain a control for the v4_6 guideline-only fix.
export const TUTORIAL_GUIDELINE_PROMPT_VERSION = "tutorial_guideline_v4_7";

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
