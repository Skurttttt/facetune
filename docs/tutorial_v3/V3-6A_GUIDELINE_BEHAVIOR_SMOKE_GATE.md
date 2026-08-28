# V3-6A — Two-Reference Behavioural Smoke Gate

**Phase:** V3-6, Stage A (behavioural gate — production pipeline NOT built)
**Date:** 2026-08-26
**Branch:** `feature/step-by-step-tutorial-v3`
**Approved guideline model:** `gemini-3.1-flash-image`
**Approved planner model:** `gemini-3.6-flash` (unchanged, already implemented in V3-4)

---

## Classification

# FAIL

**Superseded by V3-6A.1 (2026-08-27).** This document originally classified the
gate `INCONCLUSIVE` because `GEMINI_API_KEY` was unavailable locally. V3-6A.1
resolved that by deploying a temporary token-gated probe that borrowed the
server-side secret, and **executed the gate for real**: 12 guideline images
(4 categories × 3 prompt variants), all visually inspected.

**Result: FAIL. Winning variant: NONE.**

The blocking failure, reproduced in all three variants:

> Finished makeup from IMAGE 2 leaks onto IMAGE 1 in regions that are **not**
> the current category — a Foundation step returns with eyeshadow and liner, a
> Lip Colour step returns with cheek blush.

A second, independent failure: **Blush placement contradicted the Step Spec in
all three variants** (zones placed low and medial instead of upper-outer cheek).

Two important positives: **identity was preserved in all 12 images** — no face
swap, no identity blending, no wholesale merge of the two portraits — and the
instructional overlay vocabulary was genuinely good.

**Stage B (V3-6B) remains not started.** No production Edge Function,
persistence wiring, prefetch, storage, retry lifecycle or UI exists.

Full evidence, per-category verdicts and the options analysis are in
[`V3-6A.1_LIVE_SMOKE_PROBE_REPORT.md`](V3-6A.1_LIVE_SMOKE_PROBE_REPORT.md).

The sections below are retained as the historical record of how the gate was
designed and why it initially could not run.

---

## Why it could not be run

| Path attempted | Result |
| --- | --- |
| `GEMINI_API_KEY` in shell environment | absent |
| Local `.env` / config file | none — `config/development.json` holds only `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` |
| `npx -y supabase secrets list` | key exists **remotely** but is returned as a SHA-256 digest, not a value |
| Deploy a probe Edge Function to borrow the server-side key | rejected — deploying is a remote mutation this phase does not authorize, and it would also require a user JWT to invoke |

This is the same blocker recorded in V3-5 §"Scope and honesty statement". It is
an environment limitation, not a property of the model.

---

## What the gate is testing

```text
IMAGE 1   original selfie          the base; the output subject; must survive untouched
IMAGE 2   canonical final preview  reference only; must NOT be blended into IMAGE 1
TEXT      persisted Step Spec + scoped face attributes + strict visual rules
                                ↓
          original selfie + instructional overlays for the CURRENT category only
```

The unresolved question is not *"can this model return image bytes"* — V3-5
established that `gemini-3.1-flash-image` does exactly that in production
today. It is *"given two faces, will it annotate the first instead of blending
in the second"*. Face-blending is the natural default behaviour of an
image-editing model handed two portraits, and it is precisely what Source of
Truth §6 and §14 forbid.

---

## Infrastructure delivered

| File | Purpose |
| --- | --- |
| `tool/tutorial_v3_smoke/guideline_prompt.ts` | The prompt under evaluation: image-role hierarchy, Step Spec binding, per-category allow/forbid rules |
| `tool/tutorial_v3_smoke/fixtures.ts` | Four Step Specs (foundation, blush, eyeliner, lipstick) + stand-in canonical preview prompt |
| `tool/tutorial_v3_smoke/run_gate.ts` | Runner: two-image request, response parsing, image validation, evidence output |
| `tool/tutorial_v3_smoke/guideline_prompt_test.ts` | 19 prompt-contract tests, runnable with no API key |
| `tool/tutorial_v3_smoke/README.md` | How to run and how to read the result |

**Located in `tool/`, not `supabase/functions/`,** so `supabase functions
deploy` can never pick it up. Output goes to `build/tutorial_v3_gate/`, which
is gitignored — generated faces can never be committed (§16).

### Endpoint and request structure

```
POST https://generativelanguage.googleapis.com/v1/models/{model}:generateContent
x-goog-api-key: <server-side only, never logged>

{ "contents": [{ "role": "user", "parts": [
    { "text": "<guideline prompt>" },
    { "inlineData": { "mimeType": "...", "data": "<base64 IMAGE 1>" } },
    { "inlineData": { "mimeType": "...", "data": "<base64 IMAGE 2>" } }
] }] }
```

`/v1` (not `/v1beta`) and **no `generationConfig`**, matching the production
premium-preview client exactly — an unsupported field there returns 400 and
breaks generation outright.

**Part order is load-bearing.** IMAGE 1 first, IMAGE 2 second, matching the
roles the prompt assigns by position.

### Model configuration

Read from `TUTORIAL_V3_GUIDELINE_MODEL`, defaulting to
`gemini-3.1-flash-image`. `GEMINI_IMAGE_MODEL` is **not** consulted anywhere in
the harness, so a future V3 model change cannot disturb the premium preview.

### Image-role instructions

The role contract is stated **three times** — at the framing, inline where the
target is described, and again in the closing constraints. A single mention is
what allows drift on a long prompt; a contract test enforces at least three
mentions of each image.

IMAGE 1 preservation list: identity, facial proportions, skin tone and texture
including blemishes and lines, expression, gaze, hair, lighting, perspective,
background. IMAGE 2: *"Do NOT copy… Do NOT blend… Do NOT transfer the makeup,
colour, skin finish or styling… Do NOT output IMAGE 2, any part of IMAGE 2, or
a mixture of the two faces."*

### Category-specific constraints

Each category names the finished appearance it must not produce **and** the
neighbouring categories it must not stray into — e.g. eyeliner forbids
eyeshadow, mascara and any change to eye shape; foundation forbids smoothed or
retouched skin; lipstick forbids reshaped or over-lined lips.

### Face-attribute scoping

Each Step Spec carries only its category's relevant attributes, matching
`TutorialV3CategoryCatalog`: foundation → skin tone + undertone; blush → face
shape; eyeliner → eye shape; lipstick → lip shape. The block is explicitly
labelled *"explains the placement; never overrides the Step Spec"*.

### Test inputs

IMAGE 1 is `assets/images/beauty_portrait.png` — a stock-style portrait already
committed to the repository and used by `look_card.dart` and
`beauty_image.dart`. It is not a real user's private selfie, so no privacy
boundary is crossed.

IMAGE 2 is synthesised at run time by the same model from IMAGE 1 (mirroring
what the production preview pipeline does), or supplied with `--target=<path>`
if a real canonical preview is available.

---

## Per-category results — SUPERSEDED, see V3-6A.1

**These were executed in V3-6A.1 — all four FAILED.** The pending text below is
the original placeholder, kept as the historical record.

### CATEGORY: FOUNDATION
- **RESULT:** INCONCLUSIVE — not executed
- **IDENTITY:** not observed
- **MAKEUP TRANSFER:** not observed
- **STEP SPEC MATCH:** not observed
- **TARGET ALIGNMENT:** not observed
- **VISUAL USEFULNESS:** not observed
- **NOTES:** Tests broad coverage. Highest risk of the model "helpfully" evening out skin tone instead of drawing a coverage region.

### CATEGORY: BLUSH
- **RESULT:** INCONCLUSIVE — not executed
- **IDENTITY:** not observed
- **MAKEUP TRANSFER:** not observed
- **STEP SPEC MATCH:** not observed
- **TARGET ALIGNMENT:** not observed
- **VISUAL USEFULNESS:** not observed
- **NOTES:** Tests localized placement plus directional blending. Highest risk of literal colour transfer from IMAGE 2's cheeks.

### CATEGORY: EYELINER
- **RESULT:** INCONCLUSIVE — not executed
- **IDENTITY:** not observed
- **MAKEUP TRANSFER:** not observed
- **STEP SPEC MATCH:** not observed
- **TARGET ALIGNMENT:** not observed
- **VISUAL USEFULNESS:** not observed
- **NOTES:** Tests precision at small scale. Highest risk of drawing an actual liner rather than a path, and of category bleed into eyeshadow/mascara.

### CATEGORY: LIP COLOR
- **RESULT:** INCONCLUSIVE — not executed
- **IDENTITY:** not observed
- **MAKEUP TRANSFER:** not observed
- **STEP SPEC MATCH:** not observed
- **TARGET ALIGNMENT:** not observed
- **VISUAL USEFULNESS:** not observed
- **NOTES:** Tests a bounded region with a hard border. Highest risk of filling the lips with colour instead of outlining them.

---

## Prompt iterations

**One iteration so far, unvalidated against live output.** Iterating a prompt
requires seeing what the model actually does; that has not been possible. The
19 contract tests confirm the prompt *says* the right things, which is a
necessary but not sufficient condition.

If the first live run fails on makeup transfer, the highest-value knobs are, in
order: moving the IMAGE 2 role statement immediately adjacent to the image part
rather than only in the preamble; describing overlays in an explicitly
non-photographic register ("semi-transparent diagram layer"); and, if that
fails, dropping IMAGE 2 entirely and passing the target only as the Step Spec's
`targetLookCues` text — accepting weaker target grounding in exchange for
eliminating the blending failure mode.

---

## Automated evidence produced today

| Command | Result |
| --- | --- |
| `npx -y deno@2 test tool/tutorial_v3_smoke/` | **19 passed, 0 failed** |
| `npx -y deno@2 check tool/tutorial_v3_smoke/run_gate.ts` | clean |
| `run_gate.ts` without a key | exits 2 with a clear message; no partial output |

These verify the prompt contract and the harness. **They are explicitly not a
PASS** and were not treated as one.

---

## How to complete this gate

```bash
# 1. Generate the evidence (needs a Gemini API key with image-model access)
GEMINI_API_KEY=... npx -y deno@2 run \
  --allow-env --allow-net --allow-read --allow-write \
  tool/tutorial_v3_smoke/run_gate.ts

# 2. Look at the four images in build/tutorial_v3_gate/
```

Then judge each image against §14 — identity preserved, no finished makeup,
current category only, Step Spec match, target alignment, IMAGE 2 not blended,
no typography, genuinely useful — and record the verdict in the per-category
sections above.

- **All four acceptable → PASS**, and V3-6B may proceed.
- **Consistent failure of a fundamental invariant → FAIL.** Stop; do not weaken
  the no-makeup rule to obtain a pass, and do not substitute a model.
- Anything in between → iterate the prompt and re-run before classifying.

To supply a real canonical preview instead of a synthesised one, add
`--target=<path to a downloaded preview>`.

---

## Acceptance

| # | Requirement | Status |
| --- | --- | --- |
| Stage A | Behavioural gate executed | ❌ **not executed** — no API key in this environment |
| — | Smoke-test infrastructure built (§8 fallback) | ✅ complete and runnable |
| — | Four required categories covered | ✅ specs written; ⏳ unexecuted |
| — | Two-image role hierarchy established | ✅ stated three times, contract-tested |
| — | Category lock + per-category rules | ✅ contract-tested |
| — | Face-attribute scoping | ✅ contract-tested |
| — | No private images committed | ✅ committed stock asset; output gitignored |
| — | No model substituted | ✅ approved model used, from the V3-specific variable |
| Stage B | Production pipeline | ⛔ **not started**, per §17 |

**V3-6A: INCONCLUSIVE. V3-6B is blocked.**

## STOP
