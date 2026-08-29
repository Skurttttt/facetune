# V3-10F4.5 — Final Gemini Planner Compatibility Repair

**Phase:** V3-10F4.5
**Date:** 2026-08-29
**Branch:** `feature/step-by-step-tutorial-v3`
**Project:** `usmlwaocafeqnspdsvmv`
**Deployed:** `plan-tutorial-v3` v4 → **v5, ACTIVE**
**Status:** repair deployed — awaiting real-device acceptance

---

## Source of Truth Read

`FACETUNE_STEP_BY_STEP_TUTORIAL_V3_SOURCE_OF_TRUTH.md` read completely (989
lines, §1–§36) earlier in this session before any inspection or edit, with the
phase prompts and every V3-10 / V3-10F4.x report.

**Preflight:** branch exact, `git diff --check` clean, `stash@{0}` read-only
and untouched, no destructive git command.

---

## Probe Semantics Verification

Before trusting the proof, the probe transformations were checked against their
names — a mislabelled probe would have produced a confident wrong answer.

| Probe | Actual transformation | Matches name |
| --- | --- | --- |
| `bounds_full` | unmodified `TUTORIAL_V3_PLAN_SCHEMA` | yes — deep-equality test |
| `bounds_no_minItems` | `withoutKeywords(copy(), ["minItems"])` | yes — 0 `minItems`, 3 `maxItems` |
| `bounds_no_maxItems` | `withoutKeywords(copy(), ["maxItems"])` | yes — 0 `maxItems`, 3 `minItems` |
| `bounds_off_steps` | deletes both bounds at `properties.steps` only | yes — `steps.minItems` undefined, `cues.maxItems` still 4 |
| `bounds_off_graphics` | deletes both bounds at `graphics` only | yes — `steps.maxItems` still 12 |

All nine matrix tests pass, including one that strips `minItems`/`maxItems`
from every variant and asserts the remainder is byte-equal to the control.

---

## Proven Root Cause

**`properties.steps.maxItems` in `responseJsonSchema` makes `gemini-3.6-flash`
reject the entire request with `400 INVALID_ARGUMENT`.**

The deduction is closed, not inferred:

1. `bounds_no_maxItems` ACCEPTED → removing `maxItems` is **sufficient**.
2. `bounds_no_minItems` REJECTED → removing `minItems` changes nothing;
   **`minItems` is innocent**.
3. `bounds_no_maxItems` was accepted *with `steps.minItems: 1` still present* →
   **`steps.minItems` is fine**.
4. `bounds_off_steps` was accepted *with `cues.maxItems: 4` and
   `graphics.maxItems: 5` still present* → **`maxItems` on those two arrays is
   fine**.
5. The only `maxItems` unaccounted for is `steps.maxItems`; `bounds_off_graphics`
   retained it and failed.

`bounds_as_strings` was rejected with *"value at properties.steps.minItems must
be a number"* — the quoted-`int64` workaround is closed off, and the error
independently names `properties.steps`.

`bounds_off_cues` returned a transport timeout. It is **not used as evidence**;
steps 1–5 close the proof without it.

---

## Wire Schema Before / After

**Before**

```
steps: { type: "array", minItems: 1, maxItems: 12, items: {...} }
```

**After**

```
steps: { type: "array", minItems: 1, items: {...} }
```

One line. Nothing else in the schema changed: `target_look_cues` keeps
`minItems: 1, maxItems: 4`; `graphics` keeps `minItems: 1, maxItems: 5`; the
union `type: ["string","null"]` nullability stays exactly as it was, because
the same bisection positively cleared it — rewriting it to `anyOf` left the
request rejected.

---

## Business Rule

**Maximum tutorial steps: 12.**

Twelve, not eleven, deliberately: it is the bound the previous contract
declared, and a bug fix is the wrong moment to change a product limit. Whether
11 (the category count) is the better number is a separate product decision.

---

## Runtime Validation

The ceiling did not disappear — it **moved to the authoritative validator**.

This mattered more than it looked. Before this change, `validation.ts` enforced
every array *minimum* (`rawSteps.length === 0`, empty `target_look_cues`, empty
`graphics`) but **no maximum at all**. The 12-step rule existed *only* as
`maxItems` in the wire schema. Deleting it from the wire without replacing it
would have converted a product invariant into nothing, and a runaway response
would have been persisted.

- `MAXIMUM_PLAN_STEPS = 12` in `types.ts` — the single authoritative home.
- `parseAndValidatePlan` rejects `rawSteps.length > MAXIMUM_PLAN_STEPS`
  immediately after the empty check and **before** the per-step walk, so an
  absurd response costs one comparison rather than hundreds of validations.
- Rejection uses the existing `PlanRejected` path, so it flows through the same
  bounded one-round repair the planner already had, and **nothing is persisted**.

```
Gemini-compatible wire schema → Gemini JSON → parse
  → step count ≤ 12 → all Source-of-Truth validation → persist
```

---

## Probe Removal

`diagnostics.ts` and `diagnostics_test.ts` deleted; the import and the
`runInvalidArgumentProbes(...)` call removed from `gemini_client.ts`. Verified
against the live download: **`diagnostics.ts` is no longer in production**.

Kept, because they are permanently useful and cost nothing on a working
tutorial:

- the shared Gemini error parser and six-way classification
- bounded, redacted diagnostic logging
- the `request_metrics` line on `invalid_request` only (sizes, MIME, four-byte
  signature — never content). This is what made the bisection possible and what
  makes the next one cheap.

A test pins that **no synthetic probe is reachable in production**: success is
exactly one request, and no failure class triggers extra calls.

---

## Request Contract Preservation

| Element | State |
| --- | --- |
| Prompt | unchanged |
| Model | unchanged — `gemini-3.6-flash` via `TUTORIAL_V3_PLANNER_MODEL` |
| Endpoint / API version | unchanged — `/v1beta/…:generateContent` |
| Image | unchanged — canonical preview, `image/jpeg`, verified `ffd8ffe0` |
| generationConfig | unchanged — same six keys, same values |
| Nullability | unchanged — union form, positively cleared |
| String bounds, descriptions, `additionalProperties` | unchanged |
| Categories, Step Spec fields | unchanged |

---

## Source-of-Truth Compatibility

All eleven categories remain representable; every Step Spec field survives
(`where_to_apply`, `direction`, `technique`, `coverage`, `intensity`, `finish`,
rationales, cues, tips, `guideline_visual_intent`); dynamic step count, final
look last, category ordering and uniqueness, face-attribute scoping, Standard
and Kit behaviour are all untouched. The planner remains the makeup
decision-maker; the mapper remains a spatial translator. No generative
guideline images, no MediaPipe/OpenCV/TFLite/AR.

---

## Security

| Item | State |
| --- | --- |
| `GEMINI_API_KEY` | server-side only; not read, printed or mutated |
| `service_role` | not used, not read, not printed |
| Logging | sizes, MIME, four-byte signature, sanitized ≤300-char error message |
| RLS / storage / `verify_jwt` | unchanged; `verify_jwt` remains true |
| Secrets | none set, unset or listed |
| Migrations | none run |

### OPEN HIGH-PRIORITY SECURITY ITEM

> The previously exposed legacy Supabase `service_role` credential remains an
> **OPEN HIGH-PRIORITY** release blocker until migrated or revoked.

---

## Tests Added

| Test | Proves |
| --- | --- |
| `the serialized request carries no steps.maxItems` | asserted on the **bytes Gemini receives**: `steps.maxItems` absent, `steps.minItems` 1, `cues.maxItems` 4, `graphics.maxItems` 5, nullability still the union form |
| `the step ceiling lives in the validator, not the wire schema` | the wire lacks it **and** `MAXIMUM_PLAN_STEPS === 12` — the pair, so neither reads as a relaxation alone |
| `a plan at the twelve-step ceiling is not rejected for its length` | 12 still passes the length gate |
| `a thirteen-step plan is rejected for its length` | exact reason string, refused on its own |
| `an absurd plan is refused before any step is examined` | 500 steps → one reason, nothing persisted |
| `a real dynamic plan well under the ceiling still validates` | §10 dynamic count unaffected |
| `an empty plan is still refused` | the pre-existing minimum survives |
| `no synthetic diagnostic probe is reachable in production` | success is one request; no failure class probes |
| `an invalid request is still measured for the next diagnosis` | metrics present, prompt/image/key absent |

One pre-existing Dart test was repaired, not weakened:
`the schema constrains graphics to the same set` scanned for the first literal
occurrence of `graphics`, which my new doc comment displaced, so it silently
read the *category* enum. It is now anchored on `graphics: {` with an explicit
guard.

---

## Verification

| Check | Result |
| --- | --- |
| `flutter analyze` | **PASS** — No issues found |
| `flutter test` | **PASS for this phase** — 4 failures, all pre-existing, identical to the V3-10F4 baseline |
| `npx -y deno@2 check ./supabase/functions/plan-tutorial-v3/index.ts` | **PASS** |
| Type-check of the deployment bundle | **PASS** |
| `npx -y deno@2 test --allow-read ./supabase/functions/plan-tutorial-v3/` | **PASS** — 78 passed, 0 failed |
| `npx -y deno@2 test ./supabase/functions/_shared/` | **PASS** — 19 passed, 0 failed |
| `npx -y deno@2 test --allow-read ./supabase/functions/map-tutorial-v3-guideline-geometry/` | **PASS** — 44 passed, 0 failed |
| `npx -y deno@2 test --allow-read ./tool/tutorial_v3_smoke/` | **PASS** — 55 passed, 0 failed |
| `git diff --check` | **PASS** — clean |
| `dart format` | **FAIL — pre-existing, repository-wide**; no unrelated file reformatted |

---

## Production Deployment Diff

Bundle diffed against a fresh download of the **then-current v4**, file by file:

| File | Change |
| --- | --- |
| `plan-tutorial-v3/schema.ts` | **`maxItems: 12` removed** from `properties.steps` (plus explanatory comment) |
| `plan-tutorial-v3/types.ts` | **`MAXIMUM_PLAN_STEPS = 12` added** |
| `plan-tutorial-v3/validation.ts` | **step-count ceiling enforced** in `parseAndValidatePlan` |
| `plan-tutorial-v3/gemini_client.ts` | probe import and call **removed** |
| `plan-tutorial-v3/diagnostics.ts` | **deleted** |
| `plan-tutorial-v3/index.ts` | unchanged |
| `plan-tutorial-v3/prompt.ts` | unchanged |
| `_shared/ai_quota.ts` | unchanged |
| `_shared/gemini_error.ts` | unchanged |

Substantive deltas, comments filtered: `schema.ts` `- maxItems: 12,` and
`gemini_client.ts` `- import { runInvalidArgumentProbes }…` / `- await
runInvalidArgumentProbes(apiKey, model);`. Nothing else.

### Drift guard

The candidate was audited for undeployed V3-9/V3-10 work. The first build
**did** pick up the V3-9 Kit product-snapshot rewrite, because it copied the
working tree's `validation.ts`. That was caught and corrected: the deployed
`validation.ts` was rebuilt from `git HEAD` plus the step ceiling alone, and a
line-by-line diff against HEAD now shows exactly the ceiling and nothing else.
`index.ts` was taken from HEAD and carries neither the canonical-path gate nor
`planRows(..., ownedProducts)`.

### Live verification of v5

Downloaded back from production after deploying:

- `diagnostics.ts` — **absent**
- `schema.ts` — `maxItems` appears only at cues (4) and graphics (5); none on `steps`
- `validation.ts` / `types.ts` — `MAXIMUM_PLAN_STEPS` present and enforced

---

## Deployment

| Field | Value |
| --- | --- |
| Function | `plan-tutorial-v3` |
| Previous version | 4 |
| New version | **5** |
| Status | **ACTIVE** |
| `verify_jwt` | true |
| Other functions | untouched; `map-tutorial-v3-guideline-geometry` still v1 |

No migration, no secret mutation, no other deployment, no `--prune`.

---

## Real Device Acceptance

**PENDING.**

| Check | Result |
| --- | --- |
| Planner accepted | pending |
| Plan generated / parsed / validated / persisted | pending |
| Step 1 visible | pending |
| Guideline overlay | pending |
| Step 2 / Step 3 / Previous | pending |

---

## Remaining Production Drift

Still undeployed, deliberately, and needing its own controlled review:

| File | Change | Phase | In production? | Tested? | Security relevance | Needed before V3-QA? |
| --- | --- | --- | --- | --- | --- | --- |
| `plan-tutorial-v3/index.ts` | canonical-path source-mode gate (`/generated/` vs `/kit-generated/`) | V3-10 | No | Yes | **Yes** — stops a Kit session decomposing a standard preview | **Yes** |
| `plan-tutorial-v3/index.ts` | `planRows(..., ownedProducts)` | V3-9 | No | Yes | Medium | **Yes** |
| `plan-tutorial-v3/validation.ts` | Kit product snapshot built from owned inventory, not model text | V3-9 | No | Yes | **Yes** — stops a paraphrased shade being persisted | **Yes** |

Note: `index.ts` and `validation.ts` in the working tree now contain this drift
**plus** the V3-10F4.5 fix. Production has the fix only. A future deployment of
the drift will carry the fix along with it, which is consistent.

---

## Known Release Blockers

1. **Legacy exposed `service_role` credential** — OPEN HIGH-PRIORITY, must be
   migrated or revoked before production/release.
2. **Production drift above** — the two Kit/path integrity changes are security
   relevant and are not live.
3. Four pre-existing Flutter test failures and repository-wide `dart format`
   drift, both outside this phase.

---

## Acceptance

**FAIL — GEMINI PLANNER INVALID_ARGUMENT REMAINS** *(pending real-device
confirmation; the proven defect is fixed and deployed, but no device run has
exercised v5 yet)*

## Next Step

**BLOCKED — DO NOT START V3-QA** until one real-device run confirms the planner
now succeeds.

## STOP

V3-11 not started. V3-QA not started. Nothing merged. Nothing pushed.
