# V3-10F4.3 — Gemini INVALID_ARGUMENT Final Resolution

**Phase:** V3-10F4.3 (root-cause isolation)
**Date:** 2026-08-29
**Branch:** `feature/step-by-step-tutorial-v3`
**Project:** `usmlwaocafeqnspdsvmv`
**Status:** probe matrix deployed (`plan-tutorial-v3` v3) — awaiting one real-device reproduction

---

## Source of Truth Read

`FACETUNE_STEP_BY_STEP_TUTORIAL_V3_SOURCE_OF_TRUTH.md` read completely (989
lines, §1–§36) earlier in this session before any inspection or edit, with
`FACETUNE_STEP_BY_STEP_TUTORIAL_V3_PHASE_PROMPTS.md` (1128 lines) and the
V3-10, V3-10F4, V3-10F4.1 and V3-10F4.2 reports.

**Preflight:** branch `feature/step-by-step-tutorial-v3` (exact),
`git diff --check` clean, 22 tracked modifications, `stash@{0}` read-only and
untouched. No destructive git command.

---

## Official Gemini Contract Verified

Checked against current Google documentation this phase.

| Item | Documented | Source |
| --- | --- | --- |
| Structured output on `gemini-3.6-flash` | supported | [Structured output](https://ai.google.dev/gemini-api/docs/structured-output) |
| Image input | supported: PNG, JPEG, WEBP, HEIC, HEIF | [Image understanding](https://ai.google.dev/gemini-api/docs/image-understanding) |
| Nullable via union type | **supported** — `{"type": ["string","null"]}` is documented for JSON Schema mode | Structured output |
| Inline request-size limit | **"Inline image data limits your total request size (text prompts, system instructions, and inline bytes) to 20MB."** | Image understanding |
| Schema complexity limit | **"Very large or deeply nested schemas may be rejected."** — no numeric limit published | Structured output |
| MIME/bytes mismatch behaviour | **not documented** | — |

The documentation therefore does **not** support the old nullability
hypothesis, which is why it was not applied. See "Why Other Hypotheses Were
Rejected".

---

## Original Production Error

| Field | Value |
| --- | --- |
| HTTP | `400` |
| API status | `INVALID_ARGUMENT` |
| Reason | `none` |
| Kind | `invalid_request` |
| Retryable | `false` |
| Attempt | `1` |
| Message | `"Request contains an invalid argument."` |

Client side: `status=500 code=gemini_invalid_request kind=unknown
retryable=false`.

**What this already proves.** `reason=none` with the generic message
eliminates the credential and precondition families outright: an unusable key
returns `reason=API_KEY_INVALID` with `"API key not valid. Please pass a valid
API key."`, and a billing/region fault returns `FAILED_PRECONDITION`. Neither
appeared. The request itself is malformed — but Gemini names nothing, so the
component must be isolated experimentally.

---

## Request Metadata (static analysis)

Measured locally from the real request builder. Sizes and structure only — no
prompt text, no image bytes, no user values.

| Field | Value |
| --- | --- |
| Model | `TUTORIAL_V3_PLANNER_MODEL`, default `gemini-3.6-flash` |
| API version / endpoint | `/v1beta/models/{model}:generateContent` |
| contents / roles / parts | 1 / `user` / 2 (text + `inlineData`) |
| Schema serialized bytes | **2 344** |
| Schema subschema nodes | **36** |
| Schema total properties | **28** |
| Schema max depth | **9** |
| Schema total enum values | **16** |
| Prompt bytes (standard mode) | **~4 249** |
| generationConfig keys | `responseMimeType`, `responseJsonSchema`, `maxOutputTokens`, `temperature`, `topP`, `candidateCount` |
| Image MIME derivation | `extensionFor` (writer) and `mimeTypeFor` (reader) agree: `png→png→image/png`, `webp→webp→image/webp`, else `jpg→image/jpeg` |

**Static conclusions.** The schema is small (2.3 KB) and shallow-ish (depth 9);
the prompt is 4.2 KB. Neither is plausibly "very large or deeply nested". The
MIME round-trip is consistent by construction, so a mismatch could only arise
if stored bytes disagree with the stored extension — which the deployed build
now measures directly via a 4-byte magic-number log. The only component not
measurable without a real request is the canonical preview, and therefore the
total request size against the documented 20 MB ceiling.

---

## Probe Results

**PENDING — awaiting one real-device reproduction against v3.**

| Probe | Result |
| --- | --- |
| `minimal_text` | pending |
| `json_mime` | pending |
| `tiny_schema` | pending |
| `full_schema` | pending |
| `full_config` | pending |
| `synthetic_image` | pending |

## Schema Bisection

**PENDING** — runs only if `tiny_schema` is accepted while `full_schema` is
rejected. Variants: `schema_anyof_nullable`, `schema_no_string_bounds`,
`schema_no_array_bounds`, `schema_no_descriptions`,
`schema_no_additional_properties`, `schema_no_guideline_intent`,
`schema_no_face_attributes`, `schema_minimal_step`.

---

## Exact Root Cause

**NOT YET PROVEN** — isolation instrumentation deployed, evidence pending.

---

## The Diagnostic Design

`supabase/functions/plan-tutorial-v3/diagnostics.ts` bisects the request
contract one dimension at a time against the live API, using the key already in
the function environment.

**Stage 1** walks from a bare text call up to the planner's exact
configuration, stopping at the first dimension that fails, and emits a verdict:

```
minimal_text    rejected -> verdict=model_or_project
json_mime       rejected -> verdict=response_mime
tiny_schema     rejected -> verdict=structured_output_unsupported
full_schema     rejected -> stage 2
full_config     rejected -> verdict=generation_config
synthetic_image rejected -> verdict=multimodal_shape
synthetic_image accepted -> verdict=request_payload_not_schema
```

That last verdict is the important one: if the exact schema, config and a
synthetic image are all accepted, the fault is in the real payload — size or
image bytes — and the `request_metrics` line already carries the numbers.

**Stage 2** runs only when a trivial schema is accepted but the real one is
not. Each variant differs from the full schema in exactly one way, so a single
`accepted` line names the construct. This is a targeted matrix over the
documented candidate set, not blind delta-debugging.

### Safety properties, each pinned by a test

| Property | Test |
| --- | --- |
| Probes carry no user data — fixed prompt, hard-coded 1x1 PNG | "probes carry no user data" |
| Probes never run on success, 429, 5xx, 404 or credential faults | "the diagnostic probes never run except on an invalid request" |
| The matrix stops at the first failing dimension | "the matrix stops at the first failing dimension" |
| Hard ceiling of 14 requests; 12 in the worst real branch | "the matrix is hard-bounded even if every probe is inconclusive" |
| A transport failure cannot crash the planner's own failure path | "a transport failure cannot crash the matrix" |
| No database, storage, env or Supabase access from the probe module | "no probe writes anything or reads user state" |
| The `anyOf` variant genuinely removes every union | "the anyOf variant really removes every union type" |
| Request measured before bisection; metrics carry no content | "an invalid request is measured before it is bisected" |
| The planner itself still asks Gemini exactly once for a 400 | "an invalid request fails permanently and is attempted once" |

The last one required correcting an assertion: "attempted once" now counts
requests carrying the real planner prompt, because the probe matrix shares the
endpoint. The contract being asserted is unchanged; the measurement is now
precise.

---

## Why Other Hypotheses Were Rejected

| Hypothesis | Status | Evidence |
| --- | --- | --- |
| Billing / quota | **Rejected** | `reason=none`, `INVALID_ARGUMENT`; a billing fault is `FAILED_PRECONDITION`, quota is `429 RESOURCE_EXHAUSTED` |
| Credential | **Rejected** | An invalid key returns `reason=API_KEY_INVALID` with a specific message; verified live in V3-10F4 |
| Nullable union (`type: ["string","null"]`) | **Not applied** | Current Google documentation explicitly documents this form as supported. Demoted from leading suspect to one probe variant among eight |
| Prompt semantics | **Not applied** | An HTTP 400 is a transport/contract fault. The prompt is 4.2 KB with no control characters; §15 forbids rewriting it without evidence |
| Schema size / depth | **Weakened** | 2.3 KB, 36 nodes, 28 properties, depth 9 — not plausibly "very large or deeply nested" |
| MIME derivation | **Weakened** | Writer and reader mappings are inverse by construction; the deployed build now logs the real 4-byte signature to catch stored-byte disagreement |
| Request size | **Open** | Cannot be measured without a real request; now logged as `body_bytes` / `image_bytes` against the documented 20 MB ceiling |
| Model / endpoint | **Open** | Probe 0 settles it in one request |
| generationConfig | **Open** | Probe 4 settles it |

---

## Diagnostic Probe Removal

**NOT YET REMOVED** — the probes are the current deployment's purpose. Per §22
they will be deleted once the root cause is proven, keeping only the permanent
error parser, classification and bounded logging. A regression test asserting
the probe path is absent from production will be added at that point.

---

## Source-of-Truth Compatibility

No planner behaviour changed. The request contract deployed in v3 is
**byte-identical to v2 and to production before it**: `index.ts`, `prompt.ts`,
`schema.ts`, `types.ts`, `validation.ts` and `_shared/ai_quota.ts` are all
unchanged. Only the non-2xx branch of `gemini_client.ts` differs, plus the new
`diagnostics.ts`. Master Planner → persisted Step Specs → geometry mapper →
Flutter `CustomPainter` is untouched; all eleven categories, Standard mode and
Kit mode are unaffected.

---

## Security

| Item | State |
| --- | --- |
| `GEMINI_API_KEY` | server-side only; not read, printed, requested or retrieved locally |
| Probe inputs | synthetic: one fixed sentence, one hard-coded 1x1 PNG |
| Probe logging | probe name, HTTP status, `api_status`, `reason`, sanitized ≤300-char message |
| Request metrics | sizes, MIME and a 4-byte magic number only — no content |
| `service_role` | not used, not read, not printed |
| Database / storage | probe module cannot reach either; pinned by test |
| RLS | unchanged |
| `verify_jwt` | remains `true` |
| Secrets in tests | none; only synthetic non-credential strings |

### OPEN HIGH-PRIORITY SECURITY ITEM

> The previously exposed legacy Supabase `service_role` credential remains an
> **OPEN HIGH-PRIORITY** release blocker until migrated or revoked. Not used,
> rotated, inspected or printed in this phase.

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
| `flutter build apk --debug` | **NOT RUN** — no non-test Dart changed; analyze and the full suite compiled the project |
| `dart format` | **FAIL — pre-existing, repository-wide**; no unrelated file reformatted |

---

## Deployment

```bash
npx -y supabase functions deploy plan-tutorial-v3 --use-api \
  --project-ref usmlwaocafeqnspdsvmv
```

| Field | Value |
| --- | --- |
| Function | `plan-tutorial-v3` |
| Version | **2 → 3** |
| Status | **ACTIVE** |
| `verify_jwt` | true |
| Other functions | untouched; `map-tutorial-v3-guideline-geometry` still v1 |

Built from the production baseline (git HEAD) plus the diagnostic surface only.
The undeployed V3-9/V3-10 working-tree changes were deliberately excluded again
(§18).

---

## Real Device

**PENDING** — one reproduction required.

---

## Production Drift

Unchanged from V3-10F4.2 and still deliberately undeployed:

| File | Change | Phase | In production? | Tested? | Security relevance | Needed before V3-QA? |
| --- | --- | --- | --- | --- | --- | --- |
| `plan-tutorial-v3/index.ts` | canonical-path source-mode gate (`/generated/` vs `/kit-generated/`) | V3-10 | **No** | Yes | **Yes** — prevents a Kit session decomposing a standard preview | **Yes** |
| `plan-tutorial-v3/index.ts` | `planRows(..., ownedProducts)` | V3-9 | **No** | Yes | Medium | **Yes** |
| `plan-tutorial-v3/validation.ts` | Kit product snapshot built from owned inventory, not model text | V3-9 | **No** | Yes | **Yes** — stops a paraphrased shade being persisted | **Yes** |

Deliberately excluded from the diagnostic deployments: the canonical-path gate
runs *before* the Gemini call and can fail a session with `409` first, which
would have destroyed the diagnosis.

---

## Acceptance

**FAIL — INVALID_ARGUMENT NOT RESOLVED** (isolation deployed, evidence pending)

## Next Step

**BLOCKED — DO NOT START V3-QA.** One real-device reproduction against v3 will
produce the probe matrix and name the failing component.

## STOP

V3-11 not started. V3-QA not started. Nothing merged. Nothing pushed.
