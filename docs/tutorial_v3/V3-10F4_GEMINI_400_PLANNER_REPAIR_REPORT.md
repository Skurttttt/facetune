# V3-10F4 — Gemini 400 Planner Repair Report

**Phase:** V3-10F4 (corrective continuation of V3-10)
**Date:** 2026-08-29
**Branch:** `feature/step-by-step-tutorial-v3`
**Scope:** `plan-tutorial-v3` Gemini request + HTTP error classification

> **SUPERSEDED IN PART BY V3-10F4.1.** The `anyOf` nullability rewrite described
> in §6 was **reverted out of the working tree** by V3-10F4.1 and is **not**
> part of any deployment candidate. It remains a candidate only. Everything
> else in this report — the diagnostic parser, the error classification, the
> retry correction and their tests — is unchanged and still current. Read
> `docs/tutorial_v3/V3-10F4.1_EXACT_GEMINI_400_PROOF_REPORT.md` first.

---

## Classification

# FAIL — GEMINI 400 ROOT CAUSE OR REPAIR NOT PROVEN

The acceptance gate in §29 requires the exact Gemini 400 cause to be **proven**.
It is not. The planner discarded the Gemini error body, so the production log
`status=400` is the only surviving evidence, and that single number is
compatible with at least three different faults. This report ships the
instrumentation that makes the proof obtainable, the highest-confidence
candidate repair, and the error-classification correction the phase mandated
independently — but it does not claim a proof it does not have.

**Read §11 for the two commands that will produce the proof.**

---

## Source of Truth Read

`FACETUNE_STEP_BY_STEP_TUTORIAL_V3_SOURCE_OF_TRUTH.md` was read completely
(989 lines, §1–§36) before any file was inspected or edited, followed by
`FACETUNE_STEP_BY_STEP_TUTORIAL_V3_PHASE_PROMPTS.md` (1128 lines) and the
existing V3 reports.

No `V3-10F`, `V3-10F2` or `V3-10F3` report exists in `docs/tutorial_v3/`. The
V3-10F3 diagnosis survives only as the doc comment and assertions inside
`test/features/tutorial_v3/tutorial_v3_planner_failure_contract_test.dart`,
which were read in full.

---

## 1. Exact Failing Request

Reconstructed from `supabase/functions/plan-tutorial-v3/gemini_client.ts` and
`index.ts` at the commit that produced the production 400.

| Element | Value |
| --- | --- |
| Model | `TUTORIAL_V3_PLANNER_MODEL`, server default `gemini-3.6-flash` |
| Endpoint | `POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent` |
| Auth | `x-goog-api-key` header, server-side only |
| `contents` | 1 entry, `role: "user"`, 2 parts |
| part 1 | `text` — the planner prompt |
| part 2 | `inlineData` — the canonical final preview, base64, mime from path extension |
| Structured output | `responseMimeType: "application/json"` + `responseJsonSchema` |
| Other generationConfig | `maxOutputTokens: 8192`, `temperature: 0.2`, `topP: 0.9`, `candidateCount: 1` |
| Timeout | 60 s |
| Attempts | 2, retried only when `status === 429 || status >= 500` |

Schema constructs in `TUTORIAL_V3_PLAN_SCHEMA` before the repair:

```
type (string form)      properties      required      additionalProperties: false
enum (string)           minItems        maxItems      minLength      maxLength
pattern                 description
type: ["string","null"]        <-- union form
type: ["object","null"]        <-- union form
```

No secrets, prompts, user records or image data are reproduced here.

---

## 2. Exact Gemini Error

| Field | Value |
| --- | --- |
| HTTP status | `400` |
| Gemini error code | **NOT CAPTURED** |
| Gemini error status | **NOT CAPTURED** |
| `error.details[].reason` | **NOT CAPTURED** |
| Sanitized message | **NOT CAPTURED** |

The only production evidence is:

```
[plan-tutorial-v3] Gemini request failed status=400 attempt=1
[plan-tutorial-v3] request_failed code=gemini_upstream_error
```

The client called `response.json()` **only on success**. On failure it logged
the status and threw the body away unread. Nothing else in the request path
records it.

### Why the status alone is not a diagnosis

Verified live against `generativelanguage.googleapis.com` during this phase,
with a deliberately invalid placeholder key and no user data:

```
POST /v1beta/models/gemini-3.6-flash:generateContent   (bad key)
HTTP 400
{"error":{"code":400,"message":"API key not valid. Please pass a valid API key.",
  "status":"INVALID_ARGUMENT",
  "details":[{"@type":"...ErrorInfo","reason":"API_KEY_INVALID", ...}]}}
```

**An unusable API key returns HTTP 400, not 401 or 403.** So does an invalid
schema, and so does a billing/region precondition (`FAILED_PRECONDITION`). All
three are `400 INVALID_ARGUMENT`, and only `error.status` and
`error.details[].reason` separate them. Concluding "the schema is wrong"
from `status=400` alone would be a guess dressed as a diagnosis.

This same probe also established that **the API key is validated before the
request body**, which is why the failing schema cannot be reproduced locally
without a real key.

---

## 3. Root Cause

### 3.1 Proven

**Proven root cause: the planner is structurally incapable of reporting why
Gemini rejected it.** The error body is read only on the success path; the
failure path logs one integer. This is not a contributing factor to the
outage, it *is* the reason a one-line fault has cost multiple corrective
phases. That defect is fixed in this phase.

### 3.2 Highest-confidence candidate, not proven

The strongest available evidence is the repository's own production record.
Every V3/V2 Gemini call uses the identical model, endpoint, API version and
`responseJsonSchema` field, so the request contract is a controlled experiment
with one variable:

| Function | Nullability form | Other constructs | Production status |
| --- | --- | --- | --- |
| `analyze-face` | `anyOf` + `{type:"null"}` | `integer`, `minimum`, `maximum`, `boolean`, `enum` | WORKS |
| `generate-makeup-recommendation` | `anyOf` + `{type:"null"}` | `minLength`, `maxLength`, `pattern`, `enum` | WORKS |
| `generate-kit-makeup-recommendation` | — | `minItems`, `maxItems`, `pattern`, `minLength` | WORKS |
| `plan-tutorial-v2` | `anyOf` + `{type:"null"}` | `minItems`, `maxItems`, `minLength`, `maxLength` | WORKED |
| `map-tutorial-v3-guideline-geometry` | — | minimal set only | WORKS (V3-6R live PASS) |
| **`plan-tutorial-v3`** | **`type: ["string","null"]` union** | same as the above, combined | **HTTP 400** |

Every construct in the V3 planner schema is proven-accepted by this project's
own deployment **except one**: the JSON Schema union `type` array. It appears
nowhere else in this repository, and it appears in exactly the one request
Gemini rejected.

External reports corroborate that the Gemini API rejects `type` as an array
with `400 INVALID_ARGUMENT` (`"Proto field is not repeating, cannot start
list"`), though those reports concern the older `responseSchema` field and
Google's current structured-output documentation *does* list `{"type":
["string","null"]}` as supported for JSON Schema mode. **The documentation and
the field reports contradict each other**, which is precisely why this is
reported as a candidate rather than a proof.

Sources consulted:
[Gemini structured output docs](https://ai.google.dev/gemini-api/docs/structured-output),
[ResponseSchema and JSON Schema specs of "type" as array](https://discuss.ai.google.dev/t/responseschema-and-json-schema-specs-of-type-as-array/61211),
[Gemini rejects tool JSON schema with array of types](https://discuss.ai.google.dev/t/gemini-rejects-tool-json-schema-with-array-of-types/4580).

### 3.3 Candidates that remain open

Ranked, all consistent with `status=400`:

1. **Union `type` array** in `responseJsonSchema` (repaired here).
2. **`API_KEY_INVALID`** — the key was rotated, restricted or expired. §18
   notes the account was refunded; a re-issued key that was never written back
   to `supabase secrets` produces exactly this. Weakened, not eliminated, by
   the fact that reaching a Premium Preview requires the same key to work.
3. **`FAILED_PRECONDITION`** — billing/region state on the project.
4. **Request size** — the canonical preview is inlined as base64 with **no size
   guard** in `plan-tutorial-v3` (`analyze-face` caps its input at 10 MB;
   the planner and the geometry mapper cap nothing). An oversized preview
   would also be a 400. Left unrepaired: adding a cap without knowing it is the
   fault would be a speculative change, and it is recorded here as a follow-up.

The instrumentation added in this phase distinguishes all four on the next
request.

### 3.4 A prior report corrected

`docs/tutorial_v3/V3-6R_DETERMINISTIC_GEOMETRY_RENDERER_GATE.md` §10.4 and the
header comments in both geometry `schema.ts` files state that `type:
"integer"`, integer `enum`, `minimum`/`maximum` and `minItems`/`maxItems` "all
cause `400 INVALID_ARGUMENT` from this API". `analyze-face` ships
`{type:"integer", minimum:0, maximum:10}` and `{type:"number", minimum:0,
maximum:1}` in production, and `generate-kit-makeup-recommendation` ships
`minItems`/`maxItems`. That note removed a bundle of constructs at once and
attributed the fix to all of them; at least two of the four are demonstrably
fine. The note is not corrected in place (V3-6R is a historical record) but it
should not be treated as evidence.

---

## 4. Why Previous Tests Missed It

1. **No test exercised the request.** `prompt_test.ts` and `validation_test.ts`
   covered the prompt text and the response parser. Nothing built the HTTP
   body, so no test could observe the schema that was actually transmitted.
2. **The classification test asserted the bug verbatim.**
   `tutorial_v3_planner_failure_contract_test.dart` asserted the literal source
   text `const transient = response.status === 429 || response.status >= 500`
   and `response.status === 429 ? 503 : 502`. It passed *because* the defect was
   present, and would have failed had the defect been fixed. This is the exact
   anti-pattern §19 of the phase prompt warns about: a test that copies the
   implementation cannot disagree with it.
3. **The schema was never walked.** Nothing compared the planner's constructs
   against the set the project's own production functions prove.
4. **Nothing asserted retry counts**, so a deterministic failure being retried
   was invisible.

---

## 5. Files Changed

### Added

| File | Purpose |
| --- | --- |
| `supabase/functions/_shared/gemini_error.ts` | Bounded, redacted extraction of `error.status` / `error.details[].reason` / `error.message`; six-way failure classification; log-line builder; caller mapping |
| `supabase/functions/_shared/gemini_error_test.ts` | 14 tests: classification, redaction, bounding, log-injection resistance |
| `supabase/functions/plan-tutorial-v3/gemini_client_test.ts` | 15 tests: transmitted request contract, retry counts, full status mapping |
| `supabase/functions/plan-tutorial-v3/schema_test.ts` | 9 tests: no union types, Source-of-Truth field survival |
| `supabase/functions/map-tutorial-v3-guideline-geometry/gemini_client_test.ts` | 6 tests: same contract for the mapper |
| `tool/tutorial_v3_smoke/run_planner_schema_probe.ts` | Live construct-bisecting probe; sends no user data; never prints the key |
| `docs/tutorial_v3/V3-10F4_GEMINI_400_PLANNER_REPAIR_REPORT.md` | This report |

### Modified

| File | Change |
| --- | --- |
| `supabase/functions/plan-tutorial-v3/schema.ts` | Union `type` arrays → `anyOf` + `{type:"null"}` via a `nullable()` helper. No field added, removed or reshaped. |
| `supabase/functions/plan-tutorial-v3/gemini_client.ts` | Reads and classifies the error body; retries only genuinely transient verdicts |
| `supabase/functions/map-tutorial-v3-guideline-geometry/gemini_client.ts` | Same repair — it had the identical blind spot and would have made the next 400 equally undiagnosable |
| `test/features/tutorial_v3/tutorial_v3_planner_contract_test.dart` | "missing model is configuration, not an outage" now checks the classifier, not a string in a file that no longer owns the decision |
| `test/features/tutorial_v3/tutorial_v3_planner_failure_contract_test.dart` | Source-copy assertions replaced; now asserts the old heuristic is *absent* and that no mapping is both `configuration` and `retryable` |

Not touched: `index.ts`, `prompt.ts`, `validation.ts`, `types.ts`, any
migration, any Flutter feature code, My Makeup Kit, the premium preview
pipeline, `GEMINI_IMAGE_MODEL`.

---

## 6. Request Contract Before / After

Only the nullability encoding changed. Everything else is byte-identical.

**Before**

```json
"product_id": { "type": ["string", "null"], "description": "..." },
"color_hex":  { "type": ["string", "null"], "pattern": "^#[0-9A-Fa-f]{6}$" },
"guideline_visual_intent": {
  "type": ["object", "null"],
  "required": ["description", "graphics"], "properties": { ... }
}
```

**After**

```json
"product_id": { "description": "...", "anyOf": [{ "type": "string" }, { "type": "null" }] },
"color_hex":  { "anyOf": [{ "type": "string", "pattern": "^#[0-9A-Fa-f]{6}$" }, { "type": "null" }] },
"guideline_visual_intent": {
  "anyOf": [
    { "type": "object", "additionalProperties": false,
      "required": ["description", "graphics"], "properties": { ... } },
    { "type": "null" }
  ]
}
```

These are equivalent JSON Schema: they accept and reject exactly the same
documents. `validation.ts` already skips `null` attribute values
(`normalizeAttributes`), so no validator behaviour changes either.

---

## 7. Source-of-Truth Compatibility

Nothing was removed to make Gemini accept the request. Verified by
`schema_test.ts` rather than by inspection:

- **§31 full category coverage** — the `category` enum is asserted equal to
  `Object.keys(CATEGORY_RANKS)`: all ten product categories plus `final_look`.
- **§9 Step Spec** — `where_to_apply`, `direction`, `technique`, `coverage`,
  `intensity`, `finish`, `shade_name`, `color_hex`, `amount`,
  `tool_suggestion`, `personalized_tip`, `avoid`, `face_attributes`,
  `face_rationale`, `target_rationale`, `target_look_cues` and
  `guideline_visual_intent` are each asserted present.
- **§13 category personalization** — the eyeliner example still resolves: a
  subtle Natural liner and a dramatic Party wing differ through
  `where_to_apply`, `direction`, `technique`, `intensity`, `coverage` and
  `guideline_visual_intent.description`, all retained.
- **§12 attribute scoping** — `face_attributes` is still exactly the five V3
  attributes, asserted by name.
- **§15 no AI styling** — asserted that no `image`, `svg`, `html`, `opacity`,
  `stroke_width`, `font`, `gradient`, `blend_mode`, `result_image` or
  `previous_step` property exists.
- **§8 planner authority** — the planner remains the makeup decision-maker; the
  mapper's schema and prompt are unchanged and it still receives only the
  original selfie plus the persisted Step Spec.
- **§14 no canonical preview to the mapper** — asserted: the mapper request
  carries exactly one `inlineData` part.
- **§1 no intermediate results** — asserted: no result field is representable.

---

## 8. Error Classification

Implemented in `_shared/gemini_error.ts`, applied by both V3 clients.

| Condition | Kind | HTTP out | Code | Retryable |
| --- | --- | --- | --- | --- |
| 400, no credential/precondition marker | `invalid_request` | 500 | `gemini_invalid_request` | no |
| 400 + `reason` starting `API_KEY` | `credential` | 500 | `gemini_credential_rejected` | no |
| 400 + `UNAUTHENTICATED` / `PERMISSION_DENIED` | `credential` | 500 | `gemini_credential_rejected` | no |
| 400 + `FAILED_PRECONDITION` / `BILLING_DISABLED` / `SERVICE_DISABLED` | `precondition` | 500 | `gemini_account_precondition` | no |
| 401, 403 | `credential` | 500 | `gemini_credential_rejected` | no |
| 404 | `model_not_found` | 500 | `GEMINI_MODEL_NOT_FOUND` | no |
| 429 | `rate_limited` | 503 | `gemini_rate_limited` | yes |
| ≥ 500 | `upstream` | 502 | `gemini_upstream_error` | yes |
| `TimeoutError` | — | 504 | `gemini_timeout` | yes |
| network failure | — | 503 | `gemini_network_error` | yes |

A configuration fault now says *"The tutorial service is not configured
correctly."* — never *"temporarily unavailable"* — and carries
`retryable: false`, so the Flutter client stops offering a Retry that cannot
work. User-facing wording still exposes no technical detail. The Flutter
`_kindFor` mapping needed no change: a 500 already resolves to
`TutorialV3FailureKind.unknown` with a safe, bounded failure UI, the same as
`server_configuration`.

New server log line, bounded and redacted:

```
[plan-tutorial-v3] gemini_error status=400 api_status=INVALID_ARGUMENT \
  reason=API_KEY_INVALID kind=credential retryable=false attempt=1 \
  message="API key not valid. Please pass a valid API key."
```

---

## 9. Retry Policy

- Retry is driven by the classified verdict, not the raw status.
- Only `rate_limited` and `upstream` retry. **A 400 of any kind is attempted
  exactly once** — asserted by test, not by reading the code.
- 401/403/404 are attempted once.
- Bound is unchanged at 2 attempts with a 400 ms linear backoff. Timeout and
  network paths keep their existing single retry.
- The V3-6R transient 503 "high demand" is still absorbed by one retry
  (regression test in the geometry suite).
- V3-10F2 async guarantees are untouched: no new unbounded operation, no
  spinner path, no change to staleness or prefetch handling.

---

## 10. Security Review

| Item | State |
| --- | --- |
| `GEMINI_API_KEY` | server-side only; asserted absent from all of `lib/` |
| Key in transport | header only; asserted absent from URL and body |
| Key in logs | `AIza…` and any ≥40-char opaque run redacted before logging; asserted |
| Response body | never logged raw; only `status`, `error.status`, `details[].reason`, and a redacted ≤300-char message |
| Oversized body | > 16 KB is discarded unread |
| Log injection | `error.status` / `reason` stripped to `[A-Za-z0-9_]`, capped at 48 chars; asserted |
| Prompt / selfie / preview / signed URLs | never logged |
| `service_role` | not used, not read, not printed |
| RLS | unchanged; the planner still reads through the caller's JWT |
| Storage | unchanged; no bucket made public |
| `--no-verify-jwt` | not used |
| Secrets in tests | none. One **synthetic** non-credential string exists in `gemini_error_test.ts` solely to prove redaction works |
| Remote secrets | not set, not unset, not listed |

### OPEN HIGH-PRIORITY SECURITY ITEM

> The previously exposed legacy Supabase `service_role` credential remains an
> **OPEN HIGH-PRIORITY** release blocker until migrated or revoked. It was not
> used, rotated, inspected or printed in this phase. Production/release remains
> blocked until remediation is complete and verified without exposing secret
> values.

---

## 11. How To Obtain The Proof

Two options. Neither requires pasting a key to anyone, and neither puts it in
shell history if it is already exported in the operator's shell.

### Option A — local, no deployment, ~30 seconds (recommended first)

```bash
npx -y deno@2 run --allow-env --allow-net \
  tool/tutorial_v3_smoke/run_planner_schema_probe.ts
```

Sends nine tiny requests — no selfie, no canonical preview, no analysis, no
recommendation, one fixed synthetic sentence — varying only the schema:

```
no_schema_at_all               proves key, model, endpoint and billing
minimal_object                 proves responseJsonSchema is accepted at all
anyOf_nullable_string          the repaired form, in isolation
union_type_nullable_string     the suspect construct, in isolation
union_type_nullable_object     the suspect construct on an object
string_length_and_pattern      minLength / maxLength / pattern
array_item_bounds              minItems / maxItems
planner_schema_before_repair   the shape that produced the production 400
planner_schema_after_repair    the shape this phase ships
```

Each line prints `ACCEPTED` or `REJECTED status=… api_status=… reason=…
kind=… message="…"` through the same sanitizer production uses. If
`no_schema_at_all` is rejected, the fault was never the schema.

### Option B — deploy and read the logs

After deployment, the next failure logs `api_status`, `reason` and `kind`
directly.

---

## 12. Regression Tests

**`supabase/functions/_shared/gemini_error_test.ts`** — 14 tests

| Test | Proves |
| --- | --- |
| an invalid schema is a configuration fault, not an outage | 400 → `gemini_invalid_request`, non-retryable; explicitly asserts it is *not* `gemini_upstream_error` |
| an unusable API key arrives as 400 and is not an invalid request | `reason: API_KEY_INVALID` separates credential from schema at the same status |
| a billing or region precondition is its own category | `FAILED_PRECONDITION` → `gemini_account_precondition` |
| 401 and 403 are credential failures and are never retried | non-retryable, 500 |
| 404 stays a model-configuration fault | `GEMINI_MODEL_NOT_FOUND` preserved |
| 429 is a rate limit and stays retryable | 503, retryable, `configuration: false` |
| 5xx is a transient upstream failure | 500/502/503 → retryable upstream |
| a body that is not JSON still classifies from the status | HTML gateway page degrades safely |
| an oversized body is never read into a log line | > 16 KB discarded |
| a leaked credential in the message never reaches the log | `AIza…` redacted from detail *and* log line |
| inline base64 echoed back is redacted | long opaque runs redacted |
| the message is bounded and single-line | ≤ 304 chars, no newline |
| the log line carries the diagnosis and no payload | status, api_status, kind, retryable, attempt present |
| a hostile status field cannot inject into a log line | forged `error.status` cannot forge `reason=`/`kind=` |

**`supabase/functions/plan-tutorial-v3/gemini_client_test.ts`** — 15 tests

| Test | Proves |
| --- | --- |
| the request keeps the proven endpoint and structured-output contract | `/v1beta`, exact `generationConfig` key set, `application/json`, one text part + exactly one image |
| **no `type` union reaches the wire** | walks the schema **as serialized into the request body**, not the module — the direct regression test for this defect |
| the model name is URL-encoded into the endpoint | injection-safe endpoint construction |
| the API key travels in the header and never in the URL or body | secret containment |
| an invalid request fails permanently and is attempted once | **`attempts == 1`** for a 400 |
| a rejected API key is not reported as an invalid request | the two 400s stay distinguishable end to end |
| a billing precondition is its own permanent code | third 400 class |
| a missing model stays a configuration fault, once | 404 not retried |
| a rate limit is retried once, then reported as retryable | `attempts == 2`, 503 |
| a transient upstream failure is retried once and can succeed | 503 then 200 returns the plan |
| retries stay bounded at two attempts | no unbounded loop |
| a timeout is classified as a timeout, not an upstream error | 504 `gemini_timeout` |
| an unreachable network is its own retryable code | 503 `gemini_network_error` |
| a safety block is a refusal, not an outage | 422 `gemini_refusal` |
| a truncated plan is retryable and named | `plan_truncated` |

**`supabase/functions/plan-tutorial-v3/schema_test.ts`** — 9 tests
(no union `type` anywhere; every `type` is one of the seven primitives; every
optional field nullable via `anyOf` + null; no image/style/typography field;
category enum equals the canonical catalog; all Step Spec fields survive;
guideline graphics enum equals `ALLOWED_GRAPHICS`; face attributes are exactly
the five; bounded array with `additionalProperties: false`).

**`supabase/functions/map-tutorial-v3-guideline-geometry/gemini_client_test.ts`**
— 6 tests (exactly one image reaches the mapper, so the canonical preview
cannot be added by accident; 400 non-retryable and attempted once; credential
vs invalid-request separation; the V3-6R transient 503 still absorbed; rate
limit retryable / missing model not; image bytes in a response remain
`unexpected_image_output`).

**Dart**, two tests rewritten away from source-copying: the old heuristic must
be *absent*, and no mapping in the classifier may be both `configuration: true`
and `retryable: true`.

---

## 13. Verification

| Check | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed .` | **FAIL — pre-existing, not caused by this phase.** 18 files differ from the installed Dart SDK's formatter, 17 of which this phase never touched. The repository predates the current formatter version. Reformatting 17 unrelated files would violate "no unrelated formatting". |
| `flutter analyze` | **PASS** — No issues found (82.8 s) |
| `flutter test` | **PASS for this phase** — 4 failures, all pre-existing and reproduced with these changes removed (see below) |
| `npx -y deno@2 test ./supabase/functions/plan-tutorial-v3/` | **PASS** — 68 passed, 0 failed |
| `npx -y deno@2 test --allow-read ./supabase/functions/_shared/` | **PASS** — 19 passed, 0 failed |
| `npx -y deno@2 test --allow-read ./supabase/functions/map-tutorial-v3-guideline-geometry/` | **PASS** — 44 passed, 0 failed |
| `npx -y deno@2 test ./supabase/functions/map-tutorial-v3-guideline-geometry/` (no flag) | **FAIL — pre-existing.** `prompt_test.ts` reads `index.ts` at module load and needs `--allow-read`; reproduced on a clean checkout |
| `npx -y deno@2 test --allow-read ./tool/tutorial_v3_smoke/` | **PASS** — 46 passed, 0 failed |
| `git diff --check` | **PASS** — clean (CRLF advisories only, repository-wide) |
| `git status --short` | **PASS** — tracked-file set identical to session start plus the five intended edits |
| `flutter build apk --debug --dart-define-from-file=config/development.json` | **NOT RUN** — `flutter analyze` and the full `flutter test` suite both compiled the whole project; no Dart source outside two test files changed |

### The four Flutter failures, measured both ways

Measured with these changes removed, and again with them restored — the same
four, in the same tests:

| Test | Cause |
| --- | --- |
| `tutorial_v2_guideline_contract_test.dart:24` | `supabase/config.toml` has no `[functions.generate-tutorial-v2-guideline]` |
| `tutorial_v2_guideline_contract_test.dart:253` | `_shared/ai_quota.ts` has no `tutorial_v2_guideline` operation |
| `tutorial_v2_planner_contract_test.dart:182` | `supabase/config.toml` has no `[functions.plan-tutorial-v2]` |
| `tutorial_v3_geometry_mapper_contract_test.dart:331` | Test expects `[functions.map-tutorial-v3-guideline-geometry]\n`; the file has the section with **CRLF** endings |

The first three are untracked V2 WIP contract tests asserting a V2 registration
that the current V3 baseline deliberately does not carry. The fourth is a
line-ending artifact, not a missing registration — `supabase/config.toml` does
register the mapper with `verify_jwt = true`. None involve this phase's files.

---

## 14. Working-Tree Incident (disclosed)

During verification a `git stash push` of a path list containing an
**untracked** file failed with a pathspec error, and the `git stash pop` that
followed it therefore popped the unrelated pre-existing
`stash@{0}: "V2 WIP before Step-by-Step V3 restart"` instead.

**Nothing was lost.** The pop conflicted, so `stash@{0}` was kept and is still
present. Recovery performed:

- `supabase/config.toml`, `supabase/functions/_shared/ai_quota.ts`,
  `NOTES.md`, `supabase/functions/deno.lock` restored to `HEAD` — verified
  byte-identical to `HEAD` and reported unmodified by `git status`, matching
  their session-start state. `ai_quota.ts` at `HEAD` is the current V3 version
  (`tutorial_v3_plan`, `tutorial_v3_geometry`); the stash's copy was the older
  V2 one and would have regressed V3.
- Untracked V2 WIP paths the pop had written were restored from
  `stash@{0}^3` rather than left deleted.

Residual effect: the pop refreshed the untracked V2 WIP files in the working
tree from the stash. This is confined to untracked V2 content, is fully
recoverable from `stash@{0}`, and does not touch any tracked file, any V3
file, or any of this phase's work. No destructive git command
(`reset --hard`, `clean -fd`, `checkout -- .`, `restore .`, `push --force`)
was run at any point.

---

## 15. Remote Mutation

**NONE.**

No Edge Function deployed. No migration pushed. No schema altered. No Supabase
secret set, unset or listed. No database linked or reset. No `--prune`. The
only network calls were unauthenticated diagnostic probes to
`generativelanguage.googleapis.com` carrying a placeholder key and no user
data.

---

## 16. Deployment Required

# YES — PLAN-TUTORIAL-V3 MUST BE DEPLOYED FOR REAL GEMINI VERIFICATION

Run Option A in §11 first: it can confirm or refute the candidate root cause
locally, without deploying anything.

When authorized:

```bash
npx -y supabase functions deploy plan-tutorial-v3 --use-api
npx -y supabase functions deploy map-tutorial-v3-guideline-geometry --use-api
```

Explicit slugs. No `--prune`. No `--no-verify-jwt`. No secret mutation.

The mapper is listed because it received the same classification repair. If
only one deployment is wanted, `plan-tutorial-v3` is the one that unblocks the
tutorial; the mapper's repair is diagnostic hardening for the step that runs
immediately afterwards.

---

## 17. Acceptance

# FAIL — GEMINI 400 ROOT CAUSE OR REPAIR NOT PROVEN

Against §29:

| Gate | Status |
| --- | --- |
| exact Gemini 400 cause is proven | **NO** — the body was never captured; §11 gives the two ways to capture it |
| invalid request element is identified | PARTIAL — one construct identified as the only one not proven in this project's production; not confirmed against the live error |
| fix is minimal and Source-of-Truth compliant | YES |
| planner contract remains complete | YES — asserted field by field |
| error classification is corrected | YES |
| HTTP 400 is not incorrectly retried | YES — asserted by attempt count |
| no secrets are logged | YES — asserted |
| relevant regression tests exist | YES — 44 new tests |
| planner Deno tests pass | YES — 68/68 |
| geometry Deno tests pass | YES — 44/44 with `--allow-read` |
| Flutter analyze passes | YES |
| Flutter tests pass | YES for this phase — 4 pre-existing failures, reproduced without these changes |
| smoke tests pass | YES — 46/46 |
| `git diff --check` passes | YES |

The first gate fails, so the phase fails. The instrumentation, the
classification repair and the retry repair are complete and validated and are
worth keeping regardless of which of the four candidates the probe names.

---

## 18. Next Step

# BLOCKED — DO NOT DEPLOY

Not blocked on engineering — blocked on evidence. Run §11 Option A. Its output
will either confirm the union-`type` repair, or name `API_KEY_INVALID`,
`FAILED_PRECONDITION` or a size fault instead, in which case the correct repair
is different and this phase's schema change is merely harmless alignment.

Once the probe names the cause, this report's §2 and §3 should be completed
with the real payload and the classification re-checked before deployment is
authorized.

---

## 19. Follow-ups (not done, deliberately)

1. **No inline-image size guard** in `plan-tutorial-v3` or
   `map-tutorial-v3-guideline-geometry`. `analyze-face` caps at 10 MB. Worth
   adding once the root cause is known — speculative now.
2. **V3-6R §10.4's schema-construct claim is unreliable** (see §3.4). The
   geometry schema is more restricted than it needs to be, and its Dart-side
   validator carries constraints the schema could express. Not a defect —
   the validator is authoritative by design — but the stated reason is wrong.
3. **Four pre-existing Flutter test failures** and the repository-wide
   `dart format` drift are outside this phase.

## STOP

V3-11 not started. V3-QA not started. No deployment performed. No automatic
continuation.
