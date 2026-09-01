# V4-QA-6 — Dynamic Manifest Multi-Style Validation

**Branch:** `feature/step-by-step-tutorial-v4-ai` · **Baseline:** `f3a30a8`
**Manifest prompt:** `tutorial_manifest_v4_1` · **Schema:** `tutorial_manifest_schema_v1`
**Manifest prompt changed by this phase:** NO

This phase is QA-first. It splits into a part that can be settled from the code
and a part that can only be settled from real looks. Both are recorded here so
the second half is a capture exercise rather than a fresh investigation.

---

## Part 1 — Settled statically

Covered by `test/features/tutorial/manifest_multi_style_test.dart` (19 tests),
alongside the existing `tutorial_manifest_test.dart`,
`manifest_analyzer_contract_test.dart`, and `validation_test.ts`.

### The style never reaches the analyzer

The strongest result of this phase, and stronger than the phase asked for. The
manifest analyzer is never told which style was requested:

- In **Standard Mode** the entire supporting context is the fixed string
  `"Standard Mode: no owned-product constraint."` — no style name, no shade
  names, no recommendation items.
- In **My Makeup Kit Mode** it is the list of categories the user owns a product
  for, explicitly labelled *"context only and never evidence of visual
  presence."*

`styleCode`, `makeup_style`, `full_glam` and `soft_glam` appear nowhere in
`analyze-tutorial-manifest-v4/index.ts`. A value that is never passed cannot be
consulted, so "style-template-driven" is not merely discouraged by prompt
wording — it is unreachable.

> **Doc drift found (no code fault).** The doc comment on
> `tutorialManifestPrompt` says `supportingContext` "carries the already-validated
> look plan". It does not; the code is *more* conservative than its comment. The
> comment is stale and worth correcting in a later Flutter/backend tidy — it was
> left alone here because QA-6 authorises no manifest prompt change.

### Inclusion is a pure function of the verdicts

`resolveManifest(verdicts, sourceMode, backedCategories)` — that is the whole
input surface. Standard: `included = present`. Kit: `included = present AND
owned`. `uncertain` is never included in either mode.

Proven behaviourally: identical verdicts planned under `full_glam`, `soft_glam`,
`natural`, and a nonexistent style code produce byte-identical step lists.

### No fixed-nine behaviour

- Every count 0–9 is representable; the empty look yields **no** steps, not a
  default set.
- A "Full Glam" label over three-category evidence yields **three** steps.
- No `length === 9` or `= 9` gate exists in the inclusion path. The only nine in
  the system is `TUTORIAL_CATEGORIES.length`, derived rather than written.
- Positions renumber to the included set: Highlighter, 5th of nine in the
  vocabulary, is "Step 2 of 3" in a three-category look.

### No arbitrary uncertain→present conversion

`uncertain` is excluded, preserved as `uncertain` rather than rewritten to
`absent`, and stays excluded at `visualConfidence` 0.0, 0.5, 0.94, 0.99 and 1.0.
No threshold exists anywhere.

### Kit intersects, never substitutes

Owning a product never manufactures a step for makeup that is not visible.
Visible-but-unowned raises `kit_preview_mismatch` and the planner refuses to
build — it does not quietly drop the unowned step.

**These fixtures are hand-written verdict sets, not recorded model output.**
Nothing above is evidence about how the model classifies a real photograph.

---

## Part 2 — Requires device evidence

What remains is the model's *classification accuracy* on real canonical
previews, which needs paid generations on the POCO X3 GT.

### Where to read the verdicts

The UI shows only included steps ("Step X of N"), so absent/uncertain verdicts
must be read from one of:

- the `analyze-tutorial-manifest-v4` response body — `items[]` carries
  `presence`, `visualConfidence`, `productBacked`, `included` per category;
- the `tutorial_v4_manifest_items` table for the session;
- the completion log line, for counts only:
  `[analyze-tutorial-manifest-v4] Completed model=… status=… included=N`.

### Capture matrix — one table per canonical preview

Copy this block per look. Do not fill a row from expectation; fill it from the
persisted verdict and from looking at the two images.

```text
LOOK:                    (style requested)
MODE:                    Standard | My Makeup Kit
CANONICAL PREVIEW ID:
MANIFEST STATUS:         accepted | kit_preview_mismatch
INCLUDED COUNT:
FINAL DETERMINISTIC ORDER:

| category         | presence  | included | visual rationale (what changed, A→B) | matched evidence? |
|------------------|-----------|----------|--------------------------------------|-------------------|
| foundation       |           |          |                                      |                   |
| concealer        |           |          |                                      |                   |
| contour_bronzer  |           |          |                                      |                   |
| blush            |           |          |                                      |                   |
| highlighter      |           |          |                                      |                   |
| eyebrows         |           |          |                                      |                   |
| eyeshadow        |           |          |                                      |                   |
| eyeliner         |           |          |                                      |                   |
| lips             |           |          |                                      |                   |

RECOMMENDATION CONTEXT CONSULTED:
  Standard → NO (architecturally: none is passed)
  My Kit   → owned-category list only, tie-breaker
```

### Minimum sample to close the gate

| # | Look | Mode | What it must demonstrate |
|---|------|------|--------------------------|
| 1 | Full Glam | Standard | a dense look; count is whatever is visible, not automatically 9 |
| 2 | Soft Glam | Standard | a middling count, different from #1 |
| 3 | Natural | Standard | a sparse look; **at least one supported category absent and omitted** |
| 4 | any | My Makeup Kit | visible ∩ owned; a step present in Standard dropped for lack of a product |
| 5 | any | My Makeup Kit | `kit_preview_mismatch` surfaced rather than silently reduced |

Plus, across the whole sample, **at least one observed `uncertain`** — and a
check that it produced no step.

### Gate criteria

- **PASS** — counts differ across looks, every included category is visibly
  justified, at least one absent omission and one uncertain observed, no look
  returns all nine merely because its style label is glamorous.
- **PASS WITH RESTRICTIONS** — the above holds but a specific category is
  repeatedly misclassified (name it, with the sample count).
- **FAIL** — a look returns a category the images do not support, or counts
  track the style label rather than the evidence.

Do not record an accuracy percentage unless the sample and counting method are
written down beside it.

### If a classification failure is found

A manifest prompt change is authorised **only** for a repeated, evidenced
failure — not one ambiguous sample. Any material change must bump
`TUTORIAL_MANIFEST_PROMPT_VERSION` (`tutorial_manifest_v4_1` → `v4_2`); reuse is
already gated on prompt and schema version, so stored manifests re-analyse
rather than silently persisting under the old wording.
