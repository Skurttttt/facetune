# V4-QA-8 — End-to-End Quality Baseline Lock

**Branch:** `feature/step-by-step-tutorial-v4-ai` · **HEAD:** `85f5f71` (+ uncommitted QA-5/6B/7 work)
**Tutorial:** `gemini-3.1-flash-image` @ `1K` · prompt `tutorial_guideline_v4_7`
**Manifest:** prompt `tutorial_manifest_v4_1`
**Decision:** **BASELINE TECHNICALLY READY — PENDING POST-DEPLOY DEVICE SMOKE** (see §6).

> **Superseded (§5).** This document first recorded BASELINE REJECTED on the
> grounds that no device evidence existed. The user has since reported real
> POCO X3 GT testing as PASS with the app running smoothly, and the one
> technical restriction it identified — the final-preview model fallback (§4) —
> has been remediated and deployed. §5 is kept as the record of why the earlier
> decision was made; §6 carries the current one.

---

## 1. What a baseline lock asserts

Locking a baseline means asserting *this is the verified state we will measure
future changes against*. It is a claim about observed quality, not about code
health. That distinction decides this document.

Two layers exist, and only one of them has been verified:

| Layer | Status |
|---|---|
| **Deterministic** — contracts, types, inclusion logic, ordering, prompt clauses, UI behaviour, theming, AI-call counts, security | **Verified.** 915 automated tests, analyzer clean, APK builds. |
| **Visual** — does the generated image actually look right on a real face | **Not verified.** Zero generations reviewed across QA-5, QA-6, QA-6B, QA-7. |

Every one of the fifteen "required quality evidence" items in this phase is a
visual or device judgement, except the product-authority pair. A baseline cannot
be locked from the first row alone, and the phase says so directly: *do not
declare acceptance merely because tests are green.*

## 2. Journey status

### Standard Mode

| Stage | Deterministic | Device |
|---|---|---|
| Auth → Selfie → Analysis → Style | covered | **not run** |
| Brand-neutral recommendation | covered | **not run** |
| Final preview (`gemini-3.1-flash-image`) | see §4 caveat | **not run** |
| Dynamic manifest | covered (QA-6) | **not run** |
| Tutorial `1K` guideline | prompt contracts covered | **not run** |
| Guide Key · HOW TO APPLY | covered | **not run** |
| Shade / Finish / Intensity | covered | **not run** |
| Final-look reference | covered (QA-5) | **not run** |
| Reopen / reuse | covered (QA-6B cost tests) | **not run** |

### My Makeup Kit

Same shape. Owned-products-only recommendation, server validation, immutable
snapshot, manifest ∩ ownership, mismatch handling and exact product details are
all covered deterministically; none has been seen on a device.

**Incomplete kit:** covered as logic (visible-but-unowned raises
`kit_preview_mismatch`, and the planner refuses rather than silently dropping the
step). Never exercised on a device.

## 3. Regression guard

Each area has live automated coverage, all currently passing:

| Area | Evidence |
|---|---|
| authentication | `auth_controller`, `auth_guard`, `auth_recovery_ui`, `auth_resilience`, `auth_validators` |
| selfie flow | `scan_controller`, `selfie_file_validator`, `secure_image_validation_contract`, `flutter_image_validation_repository` |
| face analysis | `face_analysis_controller`, `face_analysis_dto`, `face_analysis_repository` |
| recommendation | `makeup_recommendation_controller`, `makeup_recommendation_dto` |
| final preview | `makeup_preview_controller`, `generated_preview_dto`, `image_validation_test.ts` |
| before/after | `results/` widget tests, `preview_result_page` render paths |
| save / history | `result_actions_controller`, `history_controller`, `supabase_history_repository`, `saved_looks_controller` |
| tutorial persistence | `tutorial_persistence_contract`, `tutorial_durability`, `tutorial_session_repository` |
| dynamic manifest | `tutorial_manifest`, `manifest_analyzer_contract`, `manifest_multi_style`, `validation_test.ts` |
| private storage | `storage_ownership_contract` (e2e), `v4_security_audit` |
| RLS | `v4_security_audit`, `makeup_kit_security_contract`, `tutorial_persistence_contract` |
| navigation | `e2e/scan_journey`, `e2e/makeup_kit_journey`, page-level route tests |

**No regression found in any area.**

## 4. Hard locks — one material caveat

| Lock | Status |
|---|---|
| Tutorial model | `GEMINI_TUTORIAL_MODEL` env, **falling back to `gemini-3.1-flash-image`** — safe by default |
| Tutorial resolution | `1K`, single definition, no `0.5K` anywhere |
| Tutorial prompt | `tutorial_guideline_v4_7` |
| Manifest prompt | `tutorial_manifest_v4_1` |
| **Final preview model** | ⚠️ **see below** |

### ✅ REMEDIATED — see §6. The finding as originally written follows.

### ⚠️ The final-preview model lock is not verifiable from this repository

`generate-makeup-preview/index.ts:301` and
`generate-kit-makeup-preview/index.ts:299` both read:

```ts
const model = Deno.env.get("GEMINI_IMAGE_MODEL")?.trim() ||
  "gemini-3-pro-image";
```

The in-code fallback is **`gemini-3-pro-image`** — not the locked
`gemini-3.1-flash-image`. Production is correct only because the deployed
`GEMINI_IMAGE_MODEL` secret is set to the flash model.

So this lock rests on unversioned runtime configuration. If that secret were
unset, rotated, or changed — or if the function were deployed to a fresh
environment — the final preview would silently switch models with **no code
change, no test failure, and no log that would look wrong**. Every downstream
tutorial baseline is measured against previews from that model.

The tutorial renderer does not have this problem: its fallback *is* the locked
model.

**Not changed here.** Altering a model default is a model change, which this
phase forbids. Recorded as the single highest-value remediation to authorise
next: make the preview fallback the locked model, or fail closed when the secret
is absent.

## 5. Quality decision

### `BASELINE REJECTED`

**This is not a statement that quality is bad.** Nothing in this track is
proven broken, no regression was found, and the deterministic layer is in good
shape. It is a statement that **the evidence required to lock a baseline has
not been gathered**, and a lock asserted without it would be a false record that
every future phase measured itself against.

The evidence gap, precisely:

- **No generated tutorial image has been visually reviewed in this entire
  track.** QA-5, QA-6B and QA-7 each closed *PENDING DEVICE VERIFICATION*; QA-6
  closed *PASS WITH RESTRICTIONS* with four of its six done-when items open for
  want of real multi-style samples.
- Guideline-only compliance, identity preservation, placement, and instruction
  agreement are the core of this baseline and are **human-judgement only**.
- Two device defects *were* reported by the user during this track — the Natural
  contour mismatch and the Everyday 6-vs-7 count — and **the fixes for both are
  themselves unverified on a device**. Locking now would lock two unconfirmed
  repairs.
- The final-preview model lock cannot be confirmed from the repository (§4).

`BASELINE ACCEPTED WITH RESTRICTIONS` was considered and rejected: a restriction
qualifies a baseline that exists. Here the entire evidential basis is missing,
which is absence of a baseline rather than a caveat on one.

### What flips this to accepted

Run the QA-7 scorecard on real generations, on the POCO X3 GT:

1. **Full Glam** and **one lighter style** (Natural or Everyday), Standard Mode —
   score all fifteen dimensions per step.
2. Cover the **representative four** (Blush, Eyeshadow, Eyeliner, Lips) and the
   **remaining five** (Foundation, Concealer, Contour/Bronzer, Highlighter,
   Eyebrows) at least once each.
3. **One My Makeup Kit** journey end to end, plus **one incomplete-kit** case
   showing the mismatch surfacing.
4. Confirm **absent-category omission** on a real manifest, in both the
   breakdown and the tutorial, with matching category sets.
5. **Light / Dark / System**, and readability at the device's default text size.
6. **Reopen** a saved look and confirm no regeneration (the response's
   `reused: true`, or an unchanged `generation_attempt`).
7. Confirm `GEMINI_IMAGE_MODEL` is set to `gemini-3.1-flash-image` in the
   deployed project.

With items 1–7 captured and no global FAIL, this becomes **BASELINE ACCEPTED**
or **ACCEPTED WITH RESTRICTIONS** depending on what the scorecards show. Only a
guideline-only or identity failure would make it a genuine rejection.

Do not begin a cost-optimisation or 0.5K phase before that: 0.5K is explicitly
gated on the 1K baseline being locked and approved, and it is not.

---

## 6. Remediation — final-preview model fallback lock

The single restriction §4 identified is fixed and deployed.

### What changed

`supabase/functions/_shared/final_preview_model.ts` (new) holds the one
definition:

```ts
export const FINAL_PREVIEW_MODEL = "gemini-3.1-flash-image";
```

Both preview functions now resolve through it. The environment variable
`GEMINI_IMAGE_MODEL` no longer *selects* a model — it only *validates* one:

| `GEMINI_IMAGE_MODEL` | Behaviour |
|---|---|
| absent | locked model (was: silently `gemini-3-pro-image`) |
| blank / whitespace | locked model |
| `gemini-3.1-flash-image` | locked model |
| anything else | **fails closed** before any Gemini request |

The third row is deliberately an error rather than a silent override. Quietly
ignoring a deliberate configuration would hide a real disagreement about what
production is running — the same class of bug being removed. The error names the
expected model only and never echoes the configured value, so a misconfigured
secret cannot be read back out of an API response.

### Deployed configuration verified

`GEMINI_IMAGE_MODEL` in the linked project (`facetune`) was confirmed to be
exactly `gemini-3.1-flash-image` by comparing the CLI's SHA-256 digest against
the hash of the expected string. No plaintext secret was read or printed.

**Production behaviour is therefore unchanged by this deployment.** The secret
already agreed with the lock; the fix removes the failure mode, not a current
fault.

### Deployed

`generate-makeup-preview` and `generate-kit-makeup-preview`, to project
`usmlwaocafeqnspdsvmv`. No other function was deployed.

### 6.1 Decision

**BASELINE TECHNICALLY READY — PENDING POST-DEPLOY DEVICE SMOKE**

Every technical condition is met: the locked model is enforced in both modes, no
Pro fallback remains in executable code, 932 tests pass, the APK builds, only the
two authorised functions were deployed, and the deployed secret is verified.

It is not called fully accepted because the required post-deploy evidence does
not exist yet: no preview has been generated *since* the deployment. That
evidence is one Standard preview, and one My Makeup Kit preview if readily
available:

- the preview still generates and the correct result appears;
- no unexpected error;
- the tutorial entry still works.

The full QA-8 visual matrix does **not** need repeating — this remediation
touched only model resolution, and the resolved model is unchanged in production.

With that smoke check clean, this becomes **BASELINE ACCEPTED**.
