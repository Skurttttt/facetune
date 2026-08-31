# V4-QA-0 — BASELINE FREEZE & EVIDENCE CAPTURE

**Branch:** `feature/step-by-step-tutorial-v4-ai`
**HEAD:** `86d79c7` ("Guidelines need more improvements")
**Audit date:** 2026-08-31
**Scope:** read-only. No prompt, code, schema, RLS, storage, model, or UI change. No deployment.
No Gemini call was made. This document is the only file this phase created.

This report supersedes nothing in `V4_0_BASELINE_AUDIT.md` (2026-08-30); that document audited the
branch *before* the tutorial existed. This one freezes the tutorial as it exists now.

---

## 1. GIT BASELINE (PROVEN)

| Fact | Evidence |
| --- | --- |
| Branch | `git branch --show-current` -> `feature/step-by-step-tutorial-v4-ai` |
| HEAD | `86d79c7` |
| Working tree before | Clean except two untracked authority files: `FACETUNE_V4_TUTORIAL_QUALITY_PHASE_PROMPTS.md`, `FACETUNE_V4_TUTORIAL_QUALITY_SOURCE_OF_TRUTH.md` |
| Tutorial history | Entire V4 tutorial (V4-1 … V4-16) landed in one commit, `e593772` "Tutorial" — 101 files, 25,439 insertions. `86d79c7` then repaired the session upsert arbiter indexes. |

`86d79c7` is material evidence: it fixed a `42P10` that made **every tutorial open fail** at
`ON CONFLICT (canonical_generated_image_id)`. Any device observation taken before that commit
describes a system that could not open a tutorial at all.

---

## 2. VALIDATION RESULTS (THIS PHASE)

| Command | Result |
| --- | --- |
| `git branch --show-current` | `feature/step-by-step-tutorial-v4-ai` |
| `git status` | clean but for the two untracked authority `.md` files |
| `flutter analyze` | **No issues found!** (27.5s, exit 0) |
| `flutter test` | **All tests passed** — 764 tests, exit 0 |
| `dart format --output=none --set-exit-if-changed .` | 357 files, **0 changed**, exit 0 |

No Android build and no device run were performed: this phase changes no code, so neither would
prove anything new.

---

## 3. PROTECTED WORKING FLOW MAP (FROM REAL CODE)

```text
selfie -> analyses.original_image_path                          [IMAGE A]
   |
   +-- standard ------> recommendations -------> generated_images.storage_path      [IMAGE B]
   |                                             generate-makeup-preview
   |
   +-- my_makeup_kit -> kit_makeup_recommendations
                        (+ product_snapshot_json,
                           look_product_snapshot_items)
                                              -> kit_generated_images.storage_path  [IMAGE B]
                                                 generate-kit-makeup-preview
                                   |
                                   v
                    analyze-tutorial-manifest-v4        (A + B -> present/absent/uncertain)
                                   |
                        tutorial_v4_sessions
                        tutorial_v4_manifest_items
                        tutorial_v4_steps
                                   |
                                   v
                    generate-tutorial-step-v4           (A + B + one category -> guideline)
                                   |
                        face-images (private)
                                   |
                                   v
                    TutorialController -> TutorialPage
```

### Protected files / functions — DO NOT MODIFY without an explicit approved phase

**Edge Functions**

- `supabase/functions/generate-makeup-preview/**` — canonical preview, Standard Mode
- `supabase/functions/generate-kit-makeup-preview/**` — canonical preview, My Makeup Kit
- `supabase/functions/generate-makeup-recommendation/**`
- `supabase/functions/generate-kit-makeup-recommendation/**` (ownership + fabricated-product validation)
- `supabase/functions/analyze-face/**`
- `supabase/functions/_shared/ai_quota.ts`, `_shared/storage_ownership.ts`, `_shared/prompt_safety.ts`
- `supabase/functions/_shared/tutorial_source_resolver.ts` — server-authoritative resolution

**Migrations (all applied-state protected; no new migration is authorized in this track)**

- `20260830000100_tutorial_persistence.sql` — `tutorial_v4_sessions`, `tutorial_v4_manifest_items`,
  `tutorial_v4_steps`, `look_product_snapshot_items`, RLS, quota operations
- `20260831000100_tutorial_session_arbiter_indexes.sql` — the arbiter-index repair
- `20260813*` / `20260814*` — My Makeup Kit inventory, snapshots, hardening

**Flutter**

- `lib/features/preview/**`, `lib/features/recommendation/**`, `lib/features/makeup_kit/**`
- `lib/features/tutorial/data/**` and `lib/features/tutorial/domain/**` (session/manifest/step
  persistence contracts)

`verify_jwt = true` is set for both tutorial functions in `supabase/config.toml:18-22`.

---

## 4. CURRENT AI CONFIGURATION AND PROMPT VERSIONS (PROVEN FROM CODE)

| Responsibility | Model source | In-code default | Prompt version |
| --- | --- | --- | --- |
| Tutorial guideline | `GEMINI_TUTORIAL_MODEL` (`_shared/tutorial_ai_config.ts:19`) | `gemini-3.1-flash-image` | **`tutorial_guideline_v4_2`** (`tutorial_ai_config.ts:35`) |
| Tutorial manifest | `GEMINI_MANIFEST_MODEL` (`analyze-tutorial-manifest-v4/index.ts:126`) | `gemini-3.6-flash` | `tutorial_manifest_v4_1` + schema `tutorial_manifest_schema_v1` |
| Final preview (standard) | `GEMINI_IMAGE_MODEL` (`generate-makeup-preview/index.ts:301`) | **`gemini-3-pro-image`** | `makeup_preview_v2` |
| Final preview (kit) | `GEMINI_IMAGE_MODEL` (`generate-kit-makeup-preview/index.ts:299`) | **`gemini-3-pro-image`** | `makeup_preview_v2` |
| Face analysis | `GEMINI_MODEL` | `gemini-3.6-flash` | `face_analysis_v2` |
| Recommendation | `GEMINI_MODEL` | `gemini-3.6-flash` | `makeup_recommendation_v2` |

Tutorial resolution is centralized at `tutorial_ai_config.ts:27` as `"1K"`, persisted per step
(`tutorial_v4_steps.output_resolution`) and constrained by
`tutorial_v4_sessions_resolution_valid`. Nothing client-side can select a model, a resolution, or a
prompt version — the request body carries only `{tutorialSessionId, category}`
(`tutorial_remote_data_source.dart:215-220`).

Quota operations `tutorial_manifest_analysis` (20/h, 80/d) and `tutorial_step_generation`
(90/h, 360/d) exist in `_shared/ai_quota.ts` and
`20260830000100_tutorial_persistence.sql:750-786`.

---

## 5. CURRENT GUIDE VISUAL VOCABULARY

The prompt asks for a *class* of markings, not a controlled symbol set
(`generate-tutorial-step-v4/prompt.ts`):

> "thin outlines, boundary lines, directional arrows, or light hatching",
> "a single clearly artificial marker colour", "semi-transparent enough that the face beneath stays
> visible", "like annotations drawn on a printed photo".

Negative contract present and category-specific: nine `prohibition` strings in
`category_prompts.ts`, each phrased in that category's own vocabulary (e.g. eyeliner: *"Your marking
must sit beside or above the lash line as an annotation … and must never look like makeup."*).
`NO TEXT OF ANY KIND` is explicit. `PLACEMENT COMES FROM IMAGE B ONLY` is explicit.

**Gaps against the Quality SoT:**

| Quality SoT requirement | Status |
| --- | --- |
| §10 fixed four-symbol vocabulary (`●` start, `━` placement, `- -` blend, `→` direction) | **absent** — the prompt names marking *types*, not a stable symbol set, so no Flutter key can reliably describe what the model drew |
| §9 minimum-useful-geometry rule ("prefer 3 useful elements over 14 decorative") | **absent** — no instruction limits guide count |
| §8 "do not creatively reinterpret the target" | present in substance |

---

## 6. CURRENT UI INFORMATION HIERARCHY

`lib/features/tutorial/presentation/pages/tutorial_page.dart` renders, top to bottom:

```text
Step X of N                       (live region, bodySmall)
Category name                     (headlineMedium)
LinearProgressIndicator
[ guideline image, 3:4, ClipRRect ]
"Where to apply" / "How to apply"  <- Standard Mode ONLY
product card                       (Standard shades, or From your kit)
"Your final look"                  <- LAST STEP ONLY
Back | Next
"Draw this step again"
```

Against the §17 target, these are **absent**: Guide Key, numbered instructions (① ② ③), "Your goal"
micro-description, Show/Hide guidelines, category-aware zoom, and a "What do these guides mean?"
affordance. Verified by grep: no `guideKey`, `showGuide`, `Your goal` symbol anywhere in `lib/`.

Entry points exist only from `preview_result_page.dart:387` and
`makeup_kit_recommendation_entry_page.dart:464`. History and Saved Looks have no tutorial entry.

---

## 7. CURRENT THEME BEHAVIOR

**The tutorial does not force dark mode.** It renders inside `PageFrame` and reads
`Theme.of(context)`; the app's global `themeMode` (`lib/app/app.dart:16-24`, backed by
`themeModeProvider` with system/light/dark) governs it. That satisfies the core of §16.

Four sites nonetheless pin light-theme tokens instead of the theme-aware helpers the design system
already provides (`AppColors.muted(context)`, `AppColors.onTint`):

| Site | Token | Consequence in dark mode |
| --- | --- | --- |
| `tutorial_page.dart:151` | `AppColors.taupe` on "Step X of N" | 3.4:1 on `darkSurface` — below WCAG AA 4.5:1, per the project's own measurement in `app_tokens.dart:16-18` |
| `tutorial_page.dart:162` | `AppColors.sand` as progress track | light sand track on a dark surface |
| `tutorial_product_cards.dart:62` | `AppColors.taupe` in `_detailRow` | same 3.4:1 failure wherever `_detailRow` sits on a default card (Standard Mode) |
| `tutorial_product_cards.dart:38` | `AppColors.sand` swatch fallback / `taupeLight` border | cosmetic only |

`MyMakeupKitProductCard` is safe: it passes `AppCard(color: AppColors.petal)`, and `AppCard`
re-derives its foreground via `AppColors.onAccent` (`app_card.dart:22-45`).

**Classification: ACCEPTABLE** — inherits global theme correctly; four fixed tokens are real
dark-mode defects, two of them contrast failures.

---

## 8. CURRENT SHADE / FINISH / INTENSITY BEHAVIOR

Authority separation is correct and enforced server-side
(`generate-tutorial-step-v4/product_presentation.ts`): product wording travels in the JSON response
only and is never sent to the image model.

| Mode | Displayed | Source |
| --- | --- | --- |
| Standard | shade name, hex chip, finish, intensity | `StandardLookEntry` from the frozen recommendation |
| My Makeup Kit | product name (or category when unnamed), hex chip, shade label, finish, foundation depth, undertone | immutable `LookProductSnapshotItem` |

Nothing is invented. An unnamed kit product shows its category, not a plausible name
(`tutorial_product_cards.dart:150-155`). The hex is rendered as both swatch and text, and the
`Semantics` node reads "Shade <label>, hex code <hex>" — not colour-alone.

**Gaps:** §15.3's controlled `Soft / Medium / Bold` vocabulary is not applied — the raw upstream
`intensity` string is printed. My Makeup Kit shows no intensity at all (the snapshot has no such
field), which is truthful but leaves §37's "intensity shown where authoritative data exists"
partially unmet in kit mode.

**Classification: ACCEPTABLE.**

---

## 9. CURRENT FINAL-LOOK PRESENTATION

The canonical final preview is reused, never regenerated — `TutorialPageArgs.finalPreviewUrl`
carries the signed URL the caller already had. Correct per §21's cost rule.

But it renders only when `state.isLastStep && finalPreviewUrl != null`
(`tutorial_page.dart:186`). On steps 1..N-1 the user has no way to answer *"what am I trying to
reproduce?"*.

**Classification: FAIL against §21** ("Every tutorial step must provide easy access to the canonical
final preview").

---

## 10. CURRENT REGENERATE BEHAVIOR — MOST IMPORTANT FINDING

`TutorialController.regenerateCurrentStep()` exists, is explicit-only, counts telemetry, and
coalesces double taps. Client-side it is correct, and
`test/features/tutorial/tutorial_orchestration_test.dart:524` proves it against a *fake* repository.

The server does not implement it.

`generate-tutorial-step-v4/index.ts:158-177` returns an already-`ready` step verbatim
(`reused: true`) before any regeneration logic is reached. The request body has no force or
regenerate flag (`tutorial_remote_data_source.dart:215-220`). Two consequences follow:

1. **"Draw this step again" cannot draw again.** It round-trips and receives the identical stored
   guideline. `MAXIMUM_STEP_ATTEMPTS = 5` and the `generation_attempt` column — written specifically
   to bound redraws — are unreachable for a ready step.
2. **A prompt-version bump does not invalidate a rendered step.** The ready short-circuit reads
   `prompt_version` (line 152) and echoes it back (line 174) but never compares it against
   `TUTORIAL_GUIDELINE_PROMPT_VERSION`. The manifest path *does* perform exactly this comparison
   (`analyze-tutorial-manifest-v4/index.ts:192-195`), so the asymmetry is unlikely to be deliberate.

**This is a hard blocker for V4-QA-2 and V4-QA-3.** Those phases tune prompts and then judge the
result on device. With this behaviour, a tuned prompt is invisible on every existing session and
every already-drawn step, and there is no in-app way to redraw one. Prompt QA would be measuring
nothing.

**Classification: FAIL.** No fix attempted here — this phase authorizes no code change.

---

## 11. DYNAMIC MANIFEST EVIDENCE

Architecture is sound and matches the SoT:

- fixed vocabulary of nine, enforced by a JSON schema with `additionalProperties: false` and all
  nine keys `required` (`schema.ts`), then re-validated in `validation.ts` — an invented category is
  a hard `unsupported_category` failure, not a silent drop
- `uncertain` is never included, in either mode (`validation.ts`, `resolveManifest`)
- order is derived from the vocabulary array index *after* filtering, so exclusion cannot reorder
- kit inclusion = visually present **AND** product-backed; visible-but-unbacked yields
  `kit_preview_mismatch`
- prompt explicitly forbids inclusion by style, face shape, or supporting context, and states
  "Do not assume every category was used"
- accepted manifests are reused, keyed on prompt + schema version

**Runtime evidence: NOT TESTED.** No manifest output for any style is recorded in this repository —
no Full Glam, Soft Glam, or Natural result, and no absent-category or uncertain-category
observation. Per the phase rule, dynamic-manifest quality is *not* inferred from Full Glam or from
anything else. This is V4-QA-6's work.

---

## 12. REPRESENTATIVE CATEGORY FINDINGS

No guideline image produced by this system exists in the repository, and no device evidence was
supplied to this phase. Every *visual* verdict below is therefore **NOT TESTED**, and the assessment
that is available is of the prompt contract that produces the image.

| Category | Prompt contract | Visual output |
| --- | --- | --- |
| **Blush** | ACCEPTABLE — names cheekbone/apple, blend direction, and "the exact extent, height, and angle visible in the FINAL image rather than any standard placement". Prohibition is concrete (pink/peach/coral/red). Missing: §7.4's *strongest concentration*, and any minimum-element limit. | **NOT TESTED** |
| **Eyeshadow** | ACCEPTABLE — enumerates lid / crease / outer-V / inner corner / lower lash line and inter-zone blending; "Mark only the zones you can see were used" resists the full-textbook default. Missing: §7.7 bilateral consistency, and intensity. | **NOT TESTED** |
| **Eyeliner** | ACCEPTABLE — the strongest of the nine: start, path, thickness change, endpoint, wing direction/length/curvature, lower lash line separately. Its prohibition uniquely tells the model *where* to put the mark ("beside or above the lash line"), which is the one category where an annotation is most easily mistaken for the product. | **NOT TESTED** |
| **Lips** | ACCEPTABLE — natural border vs target border, Cupid's bow, both corners, lower boundary, overline direction and extent. Closest match to §7.9 of any category. | **NOT TESTED** |
| Foundation | ACCEPTABLE — perimeter, fade boundaries, deliberately-uncovered areas. §7.1's warning against outlining the whole face by default is **not** stated. | **NOT TESTED** |
| Concealer | ACCEPTABLE — "discrete zones", explicitly not the whole face. | **NOT TESTED** |
| Contour / Bronzer | ACCEPTABLE — "only those you can genuinely see"; §7.3's "do not draw the standard 3-shape map" is implied but not stated. | **NOT TESTED** |
| Highlighter | ACCEPTABLE — "Keep each outline tight"; "Draw the boundary of where the light sits; never draw the light itself" is the sharpest prohibition in the set. | **NOT TESTED** |
| Eyebrows | ACCEPTABLE — start / arch / tail / stroke direction. §7.6's warning against "architectural-looking cross-lines" is **not** stated. | **NOT TESTED** |

Cross-cutting prompt gaps, all nine categories: no minimum-useful-geometry limit (§9), no fixed
symbol vocabulary (§10), no bilateral-consistency rule (§26).

The commit message `86d79c7` "Guidelines need more improvements" is the only recorded signal that
device output was judged inadequate. It carries no category, no screenshot, and no described
failure mode, so it cannot ground a finding.

---

## 13. UNPROVEN ASSUMPTIONS AND OPEN DECISIONS

### D1 — Final-preview model contradicts the hard lock (needs a user decision)

Every authority file locks the final preview to `gemini-3.1-flash-image`. The code does not:

```text
generate-makeup-preview/index.ts:301-302      GEMINI_IMAGE_MODEL || "gemini-3-pro-image"
generate-kit-makeup-preview/index.ts:299-300  GEMINI_IMAGE_MODEL || "gemini-3-pro-image"
```

`e593772` changed both defaults *from* `gemini-3.1-flash-image` *to* `gemini-3-pro-image`, matching
the V4 SoT text as it read at the time. That text now reads `gemini-3.1-flash-image`.
`docs/GEMINI_MAKEUP_PREVIEW_SETUP.md:8-16` records production as `gemini-3.1-flash-image` and
warns that the in-code fallback no longer matches. `NOTES.md` lists `gemini-3.1-flash-image`.

So: if `GEMINI_IMAGE_MODEL` is set in project `usmlwaocafeqnspdsvmv`, production is on-lock and the
fallback is a latent hazard — unsetting the secret would silently switch the canonical preview
model. If it is unset, production is already off-lock and every canonical preview in the system was
rendered by the wrong model.

**Not changed by this phase.** §3.1 forbids touching the final-preview model, and the phase forbids
code changes. Resolving this requires reading the deployed secret, or reading `model_name` on a
recent `generated_images` row. **STOP point: this needs your decision before V4-QA-2.**

`_shared/tutorial_ai_config.ts:14` also asserts in a comment that the final-preview model is
`gemini-3-pro-image` — whichever way D1 resolves, one of these statements is wrong.

### D2 — `1K` is configured but unverified

`gemini_client.ts:151-160` sends `generationConfig.imageConfig.imageSize = "1K"` and the code's own
comment marks the request shape **UNVERIFIED** against the live API. If Gemini ignores or rejects
the field, "every step is 1K" is an unproven claim, and the locked baseline rests on it. Settling
this needs one live response inspected, or the stored byte dimensions of an existing guideline.

### D3 — Deployed state unknown

Neither the deployed function versions nor whether `20260830000100` and `20260831000100` are applied
to the live project were verified. No network call was made. Local migration files are not proof of
deployed state, and `86d79c7` exists precisely because a migration defect only surfaced at runtime.

### D4 — No device evidence exists in the repository

Repo-wide search found no screenshots or captured outputs. The phase requires confirming "real
device evidence showing final preview + tutorial steps working"; that evidence has not been
supplied and could not be manufactured without a paid generation, which this phase forbids.

---

## 14. V4-QA-1 IMPLEMENTATION BOUNDARY (EXPLICIT)

V4-QA-1 is "Instruction & Guide Contract": typed contracts only, no migration, no prompt behaviour
change.

**In scope — the smallest surfaces:**

- new `lib/features/tutorial/domain/entities/` types for a guide symbol, a numbered instruction, and
  a goal line
- `lib/features/tutorial/presentation/utils/tutorial_labels.dart` — the existing home for all
  user-facing copy
- optionally `lib/features/tutorial/presentation/widgets/` for a Guide Key widget shell

**Out of scope for V4-QA-1** (named so they are not smuggled in): `prompt.ts`, `category_prompts.ts`,
`tutorial_ai_config.ts` (prompt version), any migration, any Edge Function, any theme token, the
final-preview functions.

**Surfaces later quality phases will need, recorded now:**

| Phase | Surface |
| --- | --- |
| V4-QA-2 / QA-3 | `generate-tutorial-step-v4/category_prompts.ts`, `prompt.ts`, and the version constant in `_shared/tutorial_ai_config.ts:35` — **blocked by §10 until a rendered step can be invalidated or redrawn** |
| V4-QA-4 | `tutorial_page.dart:151,162`, `tutorial_product_cards.dart:38,62` (theme tokens); `tutorial_page.dart:_instructions` (kit mode shows nothing — `validated_look_plan.dart:118-122` returns an empty list for `MyMakeupKitLookPlanSource`) |
| V4-QA-5 | `tutorial_page.dart:186` (final look on every step); category-aware zoom is Flutter-side cropping of the existing asset only |
| V4-QA-6 | no code — controlled multi-style runs against `analyze-tutorial-manifest-v4` |

Note for V4-QA-5: the guideline is a **flattened AI image**. There is no overlay layer, so a true
Show/Hide Guidelines toggle cannot be built from the current asset without a second stored image or
a new rendering architecture. §18 forbids faking it and §19 forbids resurrecting a V3-style overlay
pipeline. This must be decided, not implemented by assumption.

---

## 15. FINDINGS SUMMARY

| # | Finding | Class |
| --- | --- | --- |
| F1 | Ready-step short-circuit ignores `prompt_version` and has no force path — redraw is a no-op, prompt changes are invisible | **FAIL** (blocks QA-2/QA-3) |
| F2 | Final-preview in-code default `gemini-3-pro-image` contradicts the locked `gemini-3.1-flash-image` | **FAIL** (needs decision) |
| F3 | `imageConfig.imageSize: "1K"` unverified against the live API | **NOT TESTED** |
| F4 | My Makeup Kit steps render no instruction text at all | **FAIL** |
| F5 | Final look shown only on the last step | **FAIL** |
| F6 | Four fixed light-theme tokens; two are dark-mode contrast failures | **ACCEPTABLE** |
| F7 | Guide Key, numbered instructions, goal line, show/hide, zoom all absent | **ACCEPTABLE** (baseline, QA-4/QA-5 scope) |
| F8 | No minimum-useful-geometry rule, no fixed symbol vocabulary, no bilateral-consistency rule in any category prompt | **ACCEPTABLE** (QA-2 scope) |
| F9 | Manifest reuse is version-gated; step reuse is not | **FAIL** (same root cause as F1) |
| F10 | Guideline visual quality, all nine categories | **NOT TESTED** |
| F11 | Dynamic manifest across styles | **NOT TESTED** |
| F12 | Deployed function versions and applied migrations | **NOT TESTED** |
| — | Category isolation, guideline-only negative contract, IMAGE B authority, no-text rule, server-authoritative input, product-authority separation, cost/idempotency guards, RLS | **PASS** (contract level) |

---

## 16. WHAT DID NOT CHANGE

No prompt, prompt version, model, resolution, schema, migration, RLS policy, storage setting,
session architecture, manifest architecture, theme, or UI was modified. No function was deployed.
No Gemini request was issued. No commit, push, merge, or rebase was performed.
