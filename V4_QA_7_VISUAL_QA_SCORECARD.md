# V4-QA-7 — Visual QA Scorecard

**Branch:** `feature/step-by-step-tutorial-v4-ai` · **Baseline:** `85f5f71`
**Tutorial guideline prompt:** `tutorial_guideline_v4_7` · **Manifest prompt:** `tutorial_manifest_v4_1`
**Model:** `gemini-3.1-flash-image` · **Resolution:** `1K`

A repeatable process for judging one generated tutorial step. Fill one card per
step, per look, per device session.

---

## Verdicts

Three values only. No percentages.

| Verdict | Meaning |
|---|---|
| **PASS** | Meets the contract. Nothing a user would notice as wrong. |
| **ACCEPTABLE** | Usable, with a flaw worth recording. Ships, but is evidence if it recurs. |
| **FAIL** | Breaks the contract, or would mislead the user. Blocks the gate. |

**Do not record an accuracy percentage** unless the sample and the counting
method are written down beside it. "92% identity preserved" from four images is
a fabricated metric.

## What is and is not automatable

Automated tests already cover, and will keep covering: prompt clauses, contract
shapes, types, category vocabulary, inclusion logic, ordering, UI behaviour,
theming, and AI call counts. **None of that is evidence about how an image
looks.**

Every dimension below except the three marked *(contract-checked)* requires a
human to look at the image. A test can prove the prompt asked for identity
preservation; only a person can see whether the face survived.

---

## The card

```text
LOOK:                          (style)
MODE:                          Standard | My Makeup Kit
CANONICAL PREVIEW ID:
CATEGORY:
PROMPT VERSION:                tutorial_guideline_v4_7
ATTEMPT:                       n of 5
DEVICE:                        POCO X3 GT
THEME:                         Light | Dark | System
REVIEWER:
DATE:
```

| # | Dimension | Question the reviewer answers | Verdict |
|---|---|---|---|
| 1 | **Final-preview fidelity** | Do the marks describe *this* look, or a textbook version of the category? | |
| 2 | **Category isolation** | Is anything marked that belongs to another category? | |
| 3 | **Guideline-only compliance** | Erase every mark: is the face bare? Any pigment, glow, smoothing, or fill = **FAIL**. | |
| 4 | **Identity preservation** | Same person, pose, expression, skin texture, hair, background? | |
| 5 | **Placement accuracy** | Are the marks where the preview actually shows the product? | |
| 6 | **Direction accuracy** | Does each arrow point the way the product should actually move? | |
| 7 | **Shape fidelity** | Do boundaries follow the real footprint, not a generic shape? | |
| 8 | **Simplicity** | Fewest marks that teach it, or decorative geometry? | |
| 9 | **Instruction ↔ Guide agreement** | Does every HOW TO APPLY line reference a mark that is actually drawn? | |
| 10 | **Shade accuracy** *(contract-checked)* | Does the shown shade/hex match the validated source, unaltered? | |
| 11 | **Finish accuracy** *(contract-checked)* | Finish shown as recorded, or omitted when absent? | |
| 12 | **Intensity accuracy** *(contract-checked)* | Intensity from the controlled vocabulary, or absent? | |
| 13 | **Bilateral consistency** | Paired features marked coherently, following the real head angle? | |
| 14 | **Readability** | Legible on a 393pt phone, in Light *and* Dark? | |
| 15 | **Final-look usability** | Could the user actually reproduce the look from this step? | |

```text
OVERALL:                       PASS | ACCEPTABLE | FAIL
BLOCKING ISSUE (if FAIL):
NOTES:
```

### Gate rules

- **Any FAIL on #3 (guideline-only) is a global FAIL.** It is binary; there is
  no acceptable amount of visible makeup. This is the invariant that caused the
  QA-4B annotation experiment to be rejected.
- A FAIL on #4 (identity) blocks the step.
- ACCEPTABLE on #5–#8 is tolerable individually; three or more on one category
  is evidence of a prompt problem, not a one-off.
- #10–#12 are contract-checked, so a FAIL there is a code defect rather than a
  model defect — it means presentation altered validated data.

### Turning ACCEPTABLE into action

One ACCEPTABLE is a note. The threshold for changing anything is **the same
dimension failing on the same category across at least three separate
generations**. Below that, do not retune the prompt: a single ambiguous sample
is how a prompt gets optimised into a corner.

Any prompt change that follows must bump the version
(`tutorial_guideline_v4_7` → `v4_8`), because caching and regression evidence
key on it.

---

## Regeneration feedback — what shipped

The user-facing half of this phase is a **confirmation step** on "Draw this step
again", not an analytics pipeline.

**Before:** one tap spent a paid AI generation immediately.
**After:** a sheet explains what redrawing does, optionally lets the user name a
reason, and requires an explicit second tap to proceed. Cancelling costs
nothing.

Reasons offered: *Placement looks wrong · Guide is unclear · Face changed · Too
many guidelines · Try another version.*

### What the reason is, and is not

The selected reason **is not persisted, not logged, not transmitted, and does
not change the prompt, the model, or the resolution.** It exists to make the
choice deliberate before spending a generation.

That is a deliberate limitation, not an oversight — see the database gate below.
**Do not describe this as feedback collection or analytics.** Nothing is
collected.

### Database gate — persistence DEFERRED, with evidence

Persisting a reason would require a schema migration, which this phase forbids
without explicit approval. The evidence:

- `tutorial_v4_steps` has no column for user feedback. `failure_code` is
  server-written technical state (`unchanged_guideline`, `storage_upload_failed`,
  …) under a not-blank check constraint, written only by the Edge Function.
  Reusing it for a user-chosen reason would corrupt its meaning and is not
  client-writable.
- `ai_usage_events` records `user_id`, `operation`, `created_at`, with
  `operation` under a check constraint and **no metadata column**.

So a reason cannot be stored anywhere today. **No migration was created.** If
you later want real feedback analytics, that is a separate, explicitly approved
phase — and it should be designed as such rather than smuggled into a column
that means something else.

### Safety properties preserved

- No automatic retry for visual quality. The existing single technical retry for
  transient failures is untouched.
- Regeneration stays explicit and user-initiated; the sheet makes it *more* so.
- Server cap of 5 attempts per step, quota, and in-flight coalescing unchanged.
- No private image content, signed URL, or prompt is logged.
- Model and resolution unchanged.
