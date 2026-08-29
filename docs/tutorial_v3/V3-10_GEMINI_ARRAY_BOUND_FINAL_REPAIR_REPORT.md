# V3-10F4.4 — Gemini Array-Bound Final Repair

**Phase:** V3-10F4.4
**Date:** 2026-08-29
**Branch:** `feature/step-by-step-tutorial-v3`
**Project:** `usmlwaocafeqnspdsvmv`
**Status:** array-bound matrix deployed (`plan-tutorial-v3` v4) — awaiting one reproduction

---

## Source of Truth Read

`FACETUNE_STEP_BY_STEP_TUTORIAL_V3_SOURCE_OF_TRUTH.md` read completely (989
lines, §1–§36) earlier in this session before any inspection or edit, with the
phase prompts and the V3-10, V3-10F4, V3-10F4.1, V3-10F4.2 and V3-10F4.3
reports.

**Preflight:** branch exact, `git diff --check` clean, 22 tracked
modifications, `stash@{0}` read-only and untouched.

---

## Production Evidence (V3-10F4.3 matrix)

| Probe | Result |
| --- | --- |
| `minimal_text` | ACCEPTED |
| `json_mime` | ACCEPTED |
| `tiny_schema` | ACCEPTED |
| `full_schema` | **REJECTED** — 400 INVALID_ARGUMENT |
| `schema_anyof_nullable` | REJECTED |
| `schema_no_string_bounds` | REJECTED |
| **`schema_no_array_bounds`** | **ACCEPTED** |
| `schema_no_descriptions` | REJECTED |
| `schema_no_additional_properties` | REJECTED |
| `schema_no_guideline_intent` | REJECTED |
| `schema_no_face_attributes` | REJECTED |
| `schema_minimal_step` | ACCEPTED |

Verdict logged: `schema_construct`.

Request metrics: `model=gemini-3.6-flash body_bytes=888524 image_bytes=657749
image_mime=image/jpeg image_magic=ffd8ffe0 schema_bytes=2344 parts=2
contents=1`.

### What this settles

| Question | Answer |
| --- | --- |
| Model / project access | working — `minimal_text` accepted |
| JSON response MIME | working |
| Structured output capability | working — `tiny_schema` accepted |
| Image validity | `ffd8ffe0` is a genuine JPEG SOI+APP0; declared `image/jpeg` matches the bytes |
| Request size | 888 KB against a documented 20 MB ceiling — not the fault |
| Nullability encoding | **not the fix** — `schema_anyof_nullable` still rejected |
| String bounds, descriptions, `additionalProperties`, guideline intent, face attributes | none of them is the fault |
| Array bounds | **the fault** — the only broad variant the API accepted |

The long-running nullability hypothesis is now positively disproven, not merely
unproven. Removing it was the right call in V3-10F4.1.

---

## Array-Bound Inventory

| # | Schema path | Purpose | minItems | maxItems | Required by Source of Truth | Enforced by server validator today |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `steps` | the tutorial plan | 1 | 12 | §10 dynamic count; final look last; never filler | **min only** — `rawSteps.length === 0` rejected. **No upper bound.** |
| 2 | `steps[].target_look_cues` | what to look for in the target | 1 | 4 | §9 Step Spec | **min only** — `normalizeCues` returns null when empty. **No upper bound.** |
| 3 | `steps[].guideline_visual_intent.graphics` | allowed instructional marks | 1 | 5 | §6 allowed primitives | **min only** — `graphics.length === 0` rejected. **No upper bound.** |

### The finding that shapes the fix

**Every minimum is already enforced in `validation.ts`. No maximum is.**

So if the repair turns out to require deleting `maxItems` from the wire schema,
deleting it alone would silently drop three real product invariants — a plan
could come back with 40 steps, 20 cues or 15 graphics and be persisted. Per §8
and §13 the constraint must move to the authoritative validator, not vanish.
This is why the matrix below also tests whether the bound can be *kept* on the
wire in a form the API accepts.

---

## Probe Results

**PENDING — one reproduction required against v4.**

| Probe | Purpose | Result |
| --- | --- | --- |
| `bounds_full` | control; must be rejected or the run says nothing | pending |
| `bounds_no_minItems` | is `minItems` alone the offender? | pending |
| `bounds_no_maxItems` | is `maxItems` alone the offender? | pending |
| `bounds_as_strings` | are the bounds accepted as `int64` decimal strings? | pending |
| `bounds_off_steps` | is only the outer array's bound rejected? | pending |
| `bounds_off_cues` | is only `target_look_cues` rejected? | pending |
| `bounds_off_graphics` | is only `graphics` rejected? | pending |

### Why `bounds_as_strings` is in the matrix

`minItems`/`maxItems` are `int64` fields in Google's Schema proto, and proto
JSON accepts `int64` either as a number or as a quoted decimal string. If only
the quoted form is accepted, the constraint stays on the wire and nothing is
lost — the best available outcome. Note that `minLength`/`maxLength` are also
`int64` and were accepted as plain numbers (`schema_no_string_bounds` was
rejected while string bounds remained present), so this is a genuine question
rather than a foregone conclusion.

### Matrix discipline

Each variant differs from the schema production sends in **exactly one way**,
pinned by a test that strips `minItems`/`maxItems` from every variant and
asserts the remainder is byte-equal to the control. Nothing else — prompt,
model, image, MIME, nullability, string bounds, descriptions,
`additionalProperties`, guideline fields, face attributes, generation config —
varies. Seven probes, hard ceiling of eight, no image, `maxOutputTokens: 16`.

---

## Exact Root Cause

**PARTIALLY PROVEN.** The offending construct family is array bounds in
`responseJsonSchema`. The exact keyword and path are pending the matrix above.
Per §7 this report will not stop at "array bounds seem problematic".

---

## Wire Schema Fix

**PENDING** — will be the smallest change the evidence supports:

- if `bounds_as_strings` is accepted → serialize the bounds as strings; the
  constraint stays on the wire and nothing moves
- if only one keyword is rejected → drop only that keyword, keep the other
- if only one path is rejected → drop the bound only at that path
- if all array bounds are rejected → remove them from the wire schema through a
  deliberate adapter and enforce all three limits in `validation.ts`

In every branch the canonical domain contract stays intact; only the
Gemini-facing projection of it changes.

---

## Application Validation Preservation

**PENDING** — but the requirement is already fixed: whatever leaves the wire
schema must be enforced in `validation.ts` before persistence, with a paired
test (wire schema lacks the construct / a response violating the limit is
rejected). The three maximums are currently unenforced there and will be added
if the wire loses them.

---

## Source-of-Truth Compatibility

No planner behaviour has changed. The request contract deployed in v4 is
byte-identical to production before instrumentation: `index.ts`, `prompt.ts`,
`schema.ts`, `types.ts`, `validation.ts` and `_shared/ai_quota.ts` are
unchanged; only the non-2xx branch of `gemini_client.ts` and the temporary
`diagnostics.ts` differ. Master Planner → persisted Step Specs → geometry
mapper → Flutter `CustomPainter` untouched; all eleven categories, Standard and
Kit unaffected.

Explicitly not changed, per evidence: nullability encoding (§10 — disproven),
image handling (§11 — bytes and MIME verified good), prompt, model, endpoint,
generation config.

---

## Temporary Probe Removal

**NOT YET** — the matrix is this deployment's purpose. Per §14 it will be
deleted once the keyword and path are proven, keeping only the permanent error
parser, classification and bounded logging, with a test asserting the probe
path is absent from production.

---

## Security

| Item | State |
| --- | --- |
| `GEMINI_API_KEY` | server-side only; not read, printed, requested or retrieved |
| Probe inputs | one fixed sentence; **no image at all** in this matrix |
| Probe logging | probe name, status, `api_status`, sanitized ≤300-char message |
| `service_role` | not used, not read, not printed |
| Database / storage | unreachable from the probe module; pinned by test |
| RLS / `verify_jwt` | unchanged; `verify_jwt` remains true |

### OPEN HIGH-PRIORITY SECURITY ITEM

> The previously exposed legacy Supabase `service_role` credential remains an
> **OPEN HIGH-PRIORITY** release blocker until migrated or revoked. Not used,
> rotated, inspected or printed in this phase.

---

## Tests Added

Nine tests on the array-bound matrix:

| Test | Proves |
| --- | --- |
| the matrix is exactly the seven array-bound variants | scope is minimal, no generic re-run |
| the control variant is the schema production actually sends | deep-equals `TUTORIAL_V3_PLAN_SCHEMA` |
| each variant differs from the control in exactly one way | exact keyword counts per variant (3 bounds each) |
| the per-path variants target the three distinct arrays | steps / cues / graphics addressed independently; enum vocabulary survives |
| **no variant changes anything outside array bounds** | strips both keywords from every variant and asserts byte-equality with the control |
| probes carry no user data and no image | fixed prompt only; no style, prompt text, storage path or shade |
| probe output is bounded and small | `maxOutputTokens: 16`, ≤8 requests |
| a transport failure cannot crash the matrix | all seven degrade to `transport=` lines, matrix still ends |
| no probe writes anything or reads user state | no client, RPC, storage, env or `SERVICE_ROLE` reference |

Preserved from earlier phases: 400 / credential / precondition / 404 / 429 /
5xx / timeout classification, deterministic-400 attempted once, bounded retry,
secret redaction, request-contract equality, all planner fields, Standard, Kit.

---

## Verification

| Check | Result |
| --- | --- |
| `flutter analyze` | **PASS** — No issues found |
| `flutter test` | **PASS for this phase** — 4 failures, all pre-existing, identical to the V3-10F4 baseline |
| `npx -y deno@2 check ./supabase/functions/plan-tutorial-v3/index.ts` | **PASS** |
| Type-check of the deployment bundle | **PASS** |
| `npx -y deno@2 test --allow-read ./supabase/functions/plan-tutorial-v3/` | **PASS** — 80 passed, 0 failed |
| `npx -y deno@2 test ./supabase/functions/_shared/` | **PASS** — 19 passed, 0 failed |
| `npx -y deno@2 test --allow-read ./supabase/functions/map-tutorial-v3-guideline-geometry/` | **PASS** — 44 passed, 0 failed |
| `npx -y deno@2 test --allow-read ./tool/tutorial_v3_smoke/` | **PASS** — 55 passed, 0 failed |
| `git diff --check` | **PASS** — clean |
| `dart format` | **FAIL — pre-existing, repository-wide**; no unrelated file reformatted |

---

## Final Deployment

| Field | Value |
| --- | --- |
| Function | `plan-tutorial-v3` |
| Version | **3 → 4** |
| Status | **ACTIVE** |
| `verify_jwt` | true |
| Other functions | untouched; `map-tutorial-v3-guideline-geometry` still v1 |

Built from the verified production baseline plus the diagnostic surface only.
The undeployed V3-9/V3-10 working-tree changes were excluded again (§18).

---

## Real Device

**PENDING.**

---

## Production Drift

Unchanged and still deliberately undeployed:

| File | Change | Phase | In production? | Tested? | Security relevance | Needed before V3-QA? |
| --- | --- | --- | --- | --- | --- | --- |
| `plan-tutorial-v3/index.ts` | canonical-path source-mode gate (`/generated/` vs `/kit-generated/`) | V3-10 | No | Yes | **Yes** — stops a Kit session decomposing a standard preview | **Yes** |
| `plan-tutorial-v3/index.ts` | `planRows(..., ownedProducts)` | V3-9 | No | Yes | Medium | **Yes** |
| `plan-tutorial-v3/validation.ts` | Kit product snapshot built from owned inventory, not model text | V3-9 | No | Yes | **Yes** — stops a paraphrased shade being persisted | **Yes** |

---

## Acceptance

**FAIL — PLANNER INVALID_ARGUMENT REMAINS** (isolation narrowed to array
bounds; exact keyword and path pending)

## Next Step

**BLOCKED — DO NOT START V3-QA.** One reproduction against v4 completes the
isolation and settles whether the constraint can stay on the wire.

## STOP

V3-11 not started. V3-QA not started. Nothing merged. Nothing pushed.
