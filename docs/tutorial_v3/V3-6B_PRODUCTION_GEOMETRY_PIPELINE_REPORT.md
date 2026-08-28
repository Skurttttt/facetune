# V3-6B — Production Personalized Geometry Pipeline

**Branch:** `feature/step-by-step-tutorial-v3`
**Date:** 2026-08-28
**Precondition:** V3-6R — Personalized Deterministic Geometry Renderer Gate = **PASS**
**Status:** Implementation complete. **Nothing deployed, nothing applied, no remote mutation performed.**

---

## 1. What this phase built

The production server-side pipeline that turns a persisted V3 Step Spec into a
validated, personalized **geometry document**, stored against the step and
rendered by Flutter over the untouched original selfie.

The client sends **two identifiers and nothing else**. Every other input —
the analysis, the selfie, the Step Spec, the face attributes, the category, the
Kit product, the source mode, the plan and geometry versions — is resolved
server-side from persisted rows under the caller's own JWT.

**The canonical final preview is never sent to the mapper.** V3-6A.2 proved a
second reference image drives style transfer; the mapper does not need the
destination to locate an instruction.

---

## 2. Files changed

### New — Edge Function `supabase/functions/map-tutorial-v3-guideline-geometry/`

| File | Lines | Role |
|---|---|---|
| `types.ts` | 97 | `GEOMETRY_SCHEMA_VERSION`, `COORDINATE_SPACE`, `ROLE_KINDS`, `CATEGORY_ROLES`, `LIMITS`, `SCOPED_ATTRIBUTES`, `FunctionFailure` |
| `schema.ts` | 75 | Gemini `responseJsonSchema`, restricted to the construct set V3-6R proved accepted |
| `prompt.ts` | 131 | `GEOMETRY_PROMPT_VERSION = "v3-geometry-mapper-1"`, `geometryMapperPrompt()` |
| `validation.ts` | 340 | `parseAndValidateGeometry()` — strict, reject-never-repair |
| `gemini_client.ts` | 162 | `requestGeometry()` — one image in, JSON out, image bytes treated as a fault |
| `index.ts` | 640 | Orchestration: identity → context → integrity → claim → quota → map → validate → persist |
| `validation_test.ts` | 315 | 17 tests |
| `prompt_test.ts` | 250 | 21 tests |

### New — migration

- `supabase/migrations/20260828000100_tutorial_v3_geometry.sql` (403 lines) — **written, not applied**

### New — Dart tests

- `test/features/tutorial_v3/tutorial_v3_geometry_mapper_contract_test.dart` (27 tests)

### Modified

| File | Change |
|---|---|
| `lib/.../domain/repositories/tutorial_v3_repository.dart` | Added `TutorialV3GeometryOutcome.claimedAfterStaleGeometry`; `requiresMapping` / `replacedStaleGeometry` |
| `lib/.../data/repositories/supabase_tutorial_v3_repository.dart` | Sends the build's schema version with the claim; maps `replaced_schema_version` to the stale outcome |
| `lib/.../data/data_sources/tutorial_v3_remote_data_source.dart` | `claimGeometry({..., required int schemaVersion})` → `p_schema_version` |
| `supabase/functions/_shared/ai_quota.ts` | Added `"tutorial_v3_geometry"` (10 operations) |
| `supabase/config.toml` | `[functions.map-tutorial-v3-guideline-geometry] verify_jwt = true` |
| `supabase/functions/plan-tutorial-v3/{validation,validation_test}.ts` | `guideline_status` → `geometry_status` |
| `test/.../tutorial_v3_fixtures.dart` | `testGeometry()` / `testGeometryJson()`, catalog-driven so the fixture is legal for every category |
| `test/.../supabase_tutorial_v3_repository_test.dart` | Fake `claimGeometry` mirroring the RPC; geometry lifecycle group rewritten |
| `test/.../tutorial_v3_plan_validator_test.dart` | Step runtime-state group rewritten for geometry |
| `test/.../tutorial_v3_session_lifecycle_test.dart` | Ready steps carry documents, not paths |
| `test/.../tutorial_v3_persistence_contract_test.dart` | Live-schema invariants retargeted at the geometry migration |
| `test/.../tutorial_v3_security_contract_test.dart` | Storage-path group replaced by payload-safety + atomic-claim groups |
| `test/.../tutorial_v3_planner_contract_test.dart` | The TS↔SQL quota check now resolves the migration that *currently* owns the constraint |

---

## 3. Architecture

### 3.1 Client sends identifiers only

`index.ts` reads exactly `body.sessionId` and `body.stepIndex`. Twelve fields
that would let a caller steer the mapper are **refused with `400
unsupported_field`** rather than ignored, so no future client can start relying
on them:

```
prompt, stepSpec, step_spec_json, category, faceAttributes, selectedStyle,
analysisId, storagePath, imagePath, geometry, schemaVersion, planVersion,
productId, ownedProductIds, sourceMode, model
```

### 3.2 Server-resolved context

In order, each failure short-circuiting before any model call or quota spend:

1. **Authenticated user** — from the caller's JWT. `SUPABASE_ANON_KEY` only;
   `service_role` is never read or used.
2. **Session** — `tutorial_v3_sessions` under RLS; plan version checked
   (`incompatible_plan_version`).
3. **Step** — `tutorial_v3_steps` matched on session *and* index; final look
   refused.
4. **Step Spec** — decoded from the persisted `step_spec_json`. Its
   `category`, `selected_style_code` and `source_mode` must agree with the row
   and the session (`step_spec_mismatch`, `source_mode_mismatch`).
5. **Analysis + original selfie** — `analyses` under RLS; the path is validated
   segment-by-segment by `isOwnedOriginalPath` (`unsafe_storage_path`) before
   the download.
6. **Scoped face attributes** — only the attributes the category may reason
   about (`SCOPED_ATTRIBUTES`).
7. **Recommendation / Kit context** — `recommendation_mismatch` if the step's
   provenance disagrees with the session.
8. **Kit ownership** — re-read from `makeup_kit_products` and matched against
   the step's own `product_snapshot_json.product_id`. A product no longer owned
   returns `inventory_changed`. No client-supplied or domain-owned id set is
   trusted.

### 3.3 The mapper is not a second planner

The prompt frames the model as a **geometry mapper**: *"You are not designing
makeup. You are not choosing placement strategy. The makeup decision has
ALREADY been made."* It carries the Step Spec's `whereToApply`, `direction`,
`technique`, `coverage`, `intensity` and `visualDescription` verbatim, plus the
scoped attributes.

It deliberately **excludes** `selectedStyleCode`, `targetLookCues`,
`targetRationale` and `faceRationale` — style-transfer pressure in text form.
`prompt_test.ts` asserts none of the words *soft glam, selected look, target
look, rationale, cues, canonical, final preview, image 2, second image,
reference image, previous guideline, previous step* can appear.

Output is coordinates and roles only: no colours, opacity, stroke widths,
fonts, gradients, blend modes, text, markup, code, image data or animation.
**Flutter owns every visual decision.**

### 3.4 Persistence — smallest V3-specific evolution

`20260828000100_tutorial_v3_geometry.sql`:

- **Drops** the superseded image-asset model: `guideline_image_path`,
  `guideline_status`, `guideline_error`, their five constraints and the path
  uniqueness index. Not repurposed — reusing an image-path column for a JSON
  document would leave two competing sources of truth for one step's state.
  Safe: `tutorial_v3_steps` holds **0 rows**.
- **Adds** `geometry_status`, `geometry_json jsonb`,
  `geometry_schema_version integer`, `geometry_error`, plus six constraints:
  status vocabulary, final-look exclusion, ready-has-payload,
  unready-has-no-payload, `jsonb_typeof(...) = 'object'`, positive schema
  version — and a `(session_id, geometry_status)` index.
- **Retains and reuses** `attempt_count`, `model_name`, `prompt_version` —
  generic per-step generation metadata with no image-specific meaning.
- **Replaces** `persist_tutorial_v3_plan` (same SECURITY INVOKER posture,
  writes `geometry_status`).
- **Adds** `claim_tutorial_v3_geometry(uuid, integer, integer, integer)`.
- **Extends** the quota vocabulary to a strict superset of 10 operations,
  adding `tutorial_v3_geometry` at 120/h, 600/day.

**No historical applied migration was edited.** This is a forward migration.

### 3.5 Lifecycle

```
pending | failed ─claim─→ generating ─map─→ validate ─persist─→ ready
                              │
                              └─ any failure ─→ failed (attempt_count + 1)
```

`claim_tutorial_v3_geometry` decides in **one statement**, so two concurrent
callers cannot both win — the `UPDATE` itself carries the state guard, and a
loser gets `in_flight`. Outcomes: `not_found`, `final_look`, `reused`,
`in_flight`, `exhausted`, `claimed`.

Persisting is guarded by `.eq("geometry_status", "generating")`, so geometry
can only attach to a step this caller actually claimed. Every failure path
calls `releaseClaim`, so a claim is never left stuck.

Quota is consumed **only after the claim succeeds** — revisiting a finished
tutorial spends nothing.

### 3.6 Idempotency and version handling

`p_schema_version` is passed by the *calling build*. The RPC reuses a stored
document **only at that exact version**. Anything else is treated as stale: the
payload is discarded, the step is re-claimed, and the outcome carries
`replaced_schema_version`, which the repository surfaces as
`TutorialV3GeometryOutcome.claimedAfterStaleGeometry`.

This closes a real gap found while writing the tests: the original claim
function reused any `ready` row regardless of version, so a document written by
an older build would have been reused forever and rendered under a vocabulary
the painter does not know.

A claim always resets `geometry_json` and `geometry_schema_version` to `null`,
so a half-written or stale document can never survive into the next attempt.

### 3.7 Reject, never repair

`validation.ts` mirrors the Dart `TutorialV3GeometryValidator` exactly:

- Out-of-range coordinates are **rejected, never clamped** — a point at 1.4
  means the model misunderstood the space, and clamping draws a confidently
  wrong overlay.
- Unknown keys anywhere reject the document (`unsupported fields: ...`).
- A malformed primitive is never skipped.
- `category`, `schema_version` and `coordinate_space` on the returned document
  are rebuilt from the **server's** constants, so a model cannot smuggle
  different values through.

Range and count enforcement lives entirely in the validators because
V3-6R proved `type: "integer"`, integer `enum`, `minimum`/`maximum` and
`minItems`/`maxItems` all cause `400 INVALID_ARGUMENT` from Gemini.

### 3.8 No AI image output path

- `TUTORIAL_V3_GEOMETRY_MODEL` only. `GEMINI_IMAGE_MODEL`,
  `TUTORIAL_V3_GUIDELINE_MODEL` and `gemini-3.1-flash-image` appear nowhere in
  the function.
- `/v1beta/.../generateContent` with `responseJsonSchema` — the text contract.
- `inlineData` in a **response** raises `500 unexpected_image_output`.
- Storage is read from (the selfie) and never written to: no `.upload(`, no
  `.remove(`, no signed upload URL.
- The steps table has no image path column at all after this migration, so
  there is no object for a step to own, overwrite, or reference across users.

---

## 4. Tests

| Suite | Count | Result |
|---|---|---|
| `flutter analyze` (lib + test) | — | **0 issues** |
| `flutter test` | **608** | **all pass** (baseline was 569) |
| `deno test supabase/functions/map-tutorial-v3-guideline-geometry/` | **38** | all pass |
| `deno test supabase/functions/plan-tutorial-v3/` | 38 | all pass |
| `deno test --allow-read tool/tutorial_v3_smoke/` | 46 | all pass |
| `deno check .../map-tutorial-v3-guideline-geometry/index.ts` | — | clean |
| `git diff --check` | — | one pre-existing trailing space in the Source of Truth markdown; none in code |

### Checklist coverage

| Required test | Where |
|---|---|
| Ownership enforcement | `prompt_test.ts` "caller JWT drives every read, never service_role"; security contract "the claim runs as the caller" |
| Session / step context mismatch | `prompt_test.ts` "server resolves context from persisted records" (`step_spec_mismatch`); repository "a step is only reachable through its own session" |
| Source-mode mismatch | `prompt_test.ts` (`source_mode_mismatch`) |
| Kit ownership + snapshot integrity | `prompt_test.ts` "kit ownership is re-verified against live inventory"; mapper contract "Kit ownership is re-verified" |
| Exact Step Spec authority | mapper contract "the persisted Step Spec is the only instruction authority"; `prompt_test.ts` "every Step Spec field reaches the prompt" |
| Prompt contract | `prompt_test.ts` (11 tests) |
| Structured response parsing | `validation_test.ts` "accepts a valid document", "accepts a fenced response" |
| Invalid coordinate rejection | `validation_test.ts` "rejects out-of-range coordinates without clamping", "rejects non-finite and non-numeric coordinates" |
| Unknown primitive / role rejection | `validation_test.ts` "rejects unknown primitives and roles", "rejects a kind the role does not allow", "rejects a role the category does not allow" |
| Category mismatch | `validation_test.ts` "rejects a category mismatch"; plan validator "geometry must describe the category the step teaches"; repository "geometry for another category is refused" |
| Complexity limits | `validation_test.ts` "enforces complexity limits", "rejects invalid radii and zero-length arrows" |
| Idempotency (ready reuse) | repository "a completed step is reused, never regenerated", "reuse does not disturb the stored geometry"; mapper contract "quota is spent only after the claim succeeds" |
| Duplicate concurrent claims | repository "a second concurrent claim is refused"; security contract "the claim decides in one statement" |
| Retry / failure handling | repository "a failure keeps the spec, counts the attempt", "a failed step can be retried", "retries are bounded"; security contract "retries are bounded inside the database" |
| Stale / incompatible version | security contract "reuse is version-scoped"; repository "geometry from an older schema is replaced, never reused", "geometry from another schema version cannot be stored"; plan validator "a document written by an older build reads as stale" |
| No canonical preview to mapper | `prompt_test.ts` "no canonical preview or second image is referenced", "no canonical preview reaches the mapper"; mapper contract "exactly one image goes to the model" |
| No AI image output path | `prompt_test.ts` "image output from the model is treated as a fault"; mapper contract "the mapper never touches the image model variable", "storage is read from, never written to" |

---

## 5. Deviations and judgment calls

1. **Claim RPC signature changed during the phase.** Writing the stale-version
   tests exposed that reuse was not version-scoped. `p_schema_version` was
   added as a fourth parameter, and the Dart data source and repository were
   updated to pass it. The migration is unapplied, so this evolved the new
   object rather than adding a second one.

2. **`tutorial_v3_steps_geometry_unready_has_no_payload` was strengthened** to
   require `geometry_schema_version is null` as well, so an unready row cannot
   retain a version stamp with no document.

3. **The V3-4 planner contract test now resolves the current quota migration**
   instead of naming `20260827000200`. Hard-coding it would have made the
   TS↔SQL exactness check compare against a superseded definition every time a
   phase adds an operation.

4. **The V3-2 persistence and security contract tests were partially
   retargeted.** Assertions describing the *base* migration's structure
   (chronology, V1/V2 isolation, session shape) still read
   `20260827000100`. Assertions describing the schema **as it stands today**
   (status vocabulary, final-look exclusion, payload safety, per-step columns)
   now read `20260828000100`, because the columns they described are dropped.

5. **Formatting left as found.** `dart format` would rewrite 22 files, 19 of
   them V3 files this phase did not touch. Reformatting was out of scope and
   would have obscured the V3-6R work this phase was told to preserve.

---

## 6. Risks and open items

| # | Item | Severity | Notes |
|---|---|---|---|
| 1 | **Exposed legacy `service_role` credential** | **HIGH — UNRESOLVED** | Carried forward from V3-6A.2. Verification showed it had not been rotated. Not touched in this phase; the function uses `SUPABASE_ANON_KEY` only. **Still requires rotation outside Claude Code.** |
| 2 | Migration `20260828000100` is unapplied | Expected | Applying it drops three columns. Verified `tutorial_v3_steps` holds 0 rows before writing. Deploy phase must apply it **before** deploying the function. |
| 3 | Function not deployed | Expected | `TUTORIAL_V3_GEOMETRY_MODEL` must be set as a secret before first call. Note: `supabase secrets set/unset` redeploys **every** function — 9 are currently live. |
| 4 | Mapper behaviour under production prompts is unproven at scale | Medium | V3-6R validated 16/16 documents across 3 personalization variants, but that was the probe prompt. The production prompt differs (scoped attributes, no style fields). A post-deploy smoke pass is warranted. |
| 5 | `incompatible_geometry_version` branch is now unreachable | Low | Kept as a hard stop. Rendering under the wrong vocabulary is worse than a retryable error. |
| 6 | Probe function sources still on disk | Low | `tutorial-v3-single-image-guideline-probe/` and `map-tutorial-v3-guideline-geometry-probe/` remain locally (both already removed remotely). The smoke tool tests read them. Cleanup belongs to a later phase. |

---

## 7. Prohibitions honoured

- No Flutter tutorial screen, no prefetch, no V3-7 / V3-8 work, no premium
  preview changes.
- No remote mutation of any kind: nothing deployed, no migration pushed, no
  secret set or unset, no RLS change, no production data touched.
- No `service_role` read, printed, logged or used.
- JWT verification stays **on**.
- No historical applied migration edited.
- No original selfie overwritten — the function writes nothing to storage.
- No cumulative makeup-result generation; no previous-step dependency: every
  step maps from the original selfie and its own Step Spec alone.
- No generic universal placement: geometry is derived per-face from the scoped
  attributes and the personalized Step Spec.
- All V3-6R uncommitted work preserved; nothing reset, discarded or cleaned.

---

## 8. Acceptance

| Criterion | Status |
|---|---|
| Client sends identifiers only | Met |
| Server resolves all context from persisted rows | Met |
| Canonical preview is not an input to the mapper | Met |
| Kit ownership re-verified server-side | Met |
| `TUTORIAL_V3_GEOMETRY_MODEL`, prompt built server-side | Met |
| Mapper is not a second planner | Met |
| Smallest V3-specific persistence evolution; no ambiguous field reuse | Met |
| No historical applied migration edited | Met |
| Full lifecycle with atomic claim, strict validation, bounded retry | Met |
| Idempotent reuse; duplicate concurrent mapping prevented | Met |
| Stale / incompatible version handled explicitly | Met |
| Required tests written and passing | Met |

**V3-6B is complete. STOPPING HERE. V3-7 is not authorized and has not been started.**
