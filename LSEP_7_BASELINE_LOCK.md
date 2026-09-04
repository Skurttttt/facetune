# LSEP-7 — Production QA, Cost Audit & Baseline Lock

Date: 2026-09-04
Branch: `feature/live-scan-educational-palette`
Base revision: `ea7e5d9`
Artifact: `build/app/outputs/flutter-apk/app-debug.apk`
Artifact SHA-256: `7DBF2B011C027DD6A1B201F944E9FF94DE4EE2A1843A4408F4B6C8ECAAE15398`

## Decision

```text
LSEP BASELINE ACCEPTED — PENDING REAL DEVICE
```

Every lock in the phase's PASS list is satisfied and machine-checked. No
Android device or emulator was available at any point in LSEP-3 through LSEP-7,
so the entire performance section and both physical journeys are **unverified**,
not passed. The restriction is stated in full in section 9 and is the only thing
standing between this and unqualified acceptance.

---

## 1. Scope

LSEP-7 added no product code. It added two QA artifacts and one line of test
configuration:

| File | Purpose |
| --- | --- |
| `test/qa/lsep_baseline_lock_test.dart` | The lock, in one runnable file — 35 assertions |
| `test/qa/full_app_matrix_test.dart` | `LiveCameraPage` added to the existing theme/responsive matrix |

No defect was proven in this phase, so no remediation was performed or needed.

---

## 2. AI call audit

Every counter the phase requires, with the evidence that establishes it.

| Lock | Required | Result | Evidence |
| --- | --- | --- | --- |
| Live Gemini calls | 0 | **0** | No `supabase`, `http`, `functions.invoke`, `generativelanguage` or `gemini` reference exists on the live-frame path. Frames reach only `LiveFrameAnalyzer`, which is arithmetic over a luma plane. |
| Face analysis per accepted still | 1 | **1** | Camera: one `captureStill`, one analysis. Gallery: one selection, one analysis. Asserted for both paths with counting repositories. |
| Face analysis for rejected still | 0 | **0** | Asserted for both paths: a still that fails final local validation reaches the counter zero times. |
| Extra education AI call | 0 | **0** | `generate-makeup-recommendation/index.ts` contains exactly one `await requestGeminiRecommendation(`. No second operation, prompt version, or endpoint exists. |
| Final preview call count | unchanged | **unchanged** | `generate-makeup-preview` and `generate-kit-makeup-preview` are byte-identical to `ea7e5d9`; `git diff --name-only -- supabase/functions` lists only the recommendation function. |
| Manifest call count | unchanged | **unchanged** | `analyze-tutorial-manifest-v4` byte-identical. Existing manifest lifecycle counters in `preview_result_page_test.dart` pass. |
| Tutorial call count | unchanged | **unchanged** | `_shared/tutorial_ai_config.ts` and `generate-tutorial-step-v4` byte-identical. Tutorial suite passes. |

### Auto capture

```text
AUTO CAPTURE: NONE
```

Not asserted by convention but by construction, and checked three ways:

1. No `Timer(`, `Timer.periodic`, `Future.delayed`, `countdown` or `autoCapture`
   appears anywhere on the live path — ten files, comments excluded.
2. `captureStill()` has **exactly one caller** in the whole codebase:
   `LiveCaptureController.capture()`.
3. `capture()` has **exactly one caller**: the shutter's `onPressed`.

A widget test additionally sits in the Ready state for ten simulated seconds and
asserts zero captures.

---

## 3. Cost audit

```text
new paid calls = 0
```

The education fields ride on the recommendation call that already existed. No
model was switched, and none was switched for cost reasons.

### Token delta — `makeup_recommendation_v2` → `v3`

Estimated at four characters per token from constructed representative payloads.
These are estimates from measured character counts, **not** API-reported token
counts.

| | v2 | v3 | delta |
| --- | --- | --- | --- |
| Input prompt | ~589 tok | ~1,089 tok | **+500 per call** |
| Output, typical plan | ~1,049 tok | ~1,927 tok | **+878 (+84%)** |
| Output, worst case | ~2,399 tok | ~4,327 tok | +1,928 (+80%) |

The worst case is why `maxOutputTokens` moved from 4096 to 8192 in LSEP-1: a
plan with every field at its schema maximum exceeds the old ceiling, and the
failure mode is truncated JSON followed by a bounded retry — a second paid call
for a request that could never have fitted. Output is billed per token generated,
not per token allowed, so the headroom costs nothing on a typical plan.

### Incremental education cost

No currency figure is given. `FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_SOURCE_OF_TRUTH.md`
§42 forbids baking provider pricing into the project, and a rate quoted today
would be wrong by next quarter. Multiply the deltas above by current Google
pricing for the deployed `GEMINI_MODEL`.

### One-time re-pay

The recommendation reuse lookup keys on `prompt_version`. Moving to `v3` means
each existing `(analysis, style)` pair pays once more the next time it is
opened. Calls **per look** are unchanged at one. This was reported in LSEP-1
before the change was made.

### APK size — measured, both ways

| Build | Baseline | With `camera` | Delta |
| --- | --- | --- | --- |
| debug, all ABIs | 195,612,412 B | 219,652,520 B | +22.9 MB |
| **release, arm64-v8a** | **22,262,529 B** | **22,867,239 B** | **+604,710 B (0.58 MB, +2.7%)** |

The debug figure is misleading — unstripped native libraries for every ABI.
**0.58 MB is the shipping cost.** Both numbers come from real builds with the
dependency removed and restored, not from estimation.

---

## 4. Privacy and security QA

| Requirement | Result | Evidence |
| --- | --- | --- |
| No live frames to Gemini | **PASS** | No model or network symbol on the live path |
| No live frames to Supabase Storage | **PASS** | No `upload`, `createSignedUrl`, `storage` reference on the live path |
| No live image-byte or base64 logs | **PASS** | No `print(`, `debugPrint`, `base64`, `writeAsBytes` on the live path |
| Accepted still uses the existing secure pipeline | **PASS** | The captured still runs `_prepare(path, SelfieSource.camera)` — the same validation, compression and staging the picker path always used — then the same `validateLocal` and the same `analyze` |
| RLS unchanged | **PASS** | `supabase/migrations` byte-identical to `ea7e5d9` |
| Storage private | **PASS** | No storage policy touched; no bucket configuration in the diff |
| Auth / JWT unchanged | **PASS** | No authentication source in the diff; `analyze-face` untouched |

`LiveFrame` carries only the luma plane and is documented as transient. The
analyzer retains downsampled sample values for the motion delta and nothing else,
cleared on every session start and stop.

---

## 5. Educational QA

Asserted against the deployed prompt text, which is where the constraints live.

| Requirement | Result |
| --- | --- |
| Your features grounded in actual analysis | **PASS** — "Ground every sentence in the supplied facial attributes, the selected style, and the values you chose for this same category." |
| The effect grounded in actual recommendation | **PASS** — the effect section is scoped to "this specific shade, finish, and intensity" |
| The style grounded in selected style | **PASS** — scoped to the selected style "specifically, rather than describing the style in general" |
| No invented analysis | **PASS** — acne, blemishes, scarring, redness, dark circles, skin sensitivity, pores, wrinkles, age, cheekbone prominence, eye depth and lip asymmetry are prohibited by name; inventing a confidence value is prohibited |
| No invented product | **PASS** — brand, product line, retailer, and any shade or finish other than the chosen one are prohibited |
| No Placement on Palette | **PASS** — `item.placement` and the string `'Placement'` do not appear in `recommendation_item_card.dart` |
| No Technique on Palette | **PASS** — likewise for technique |
| No application instructions leaked into education | **PASS** — "Do not restate the placement or technique text." Where and how belong to Show Me How |

Absolute language (`perfect`, `guaranteed`, `always best`, `definitely`,
`flawless`, `ideal`) is prohibited, and medical, dermatological and corrective
claims are prohibited.

### The honest limitation

**No live `makeup_recommendation_v3` call has ever been made.** Every assertion
above is on the *contract* — the prompt, the schema, the validator, the decoder,
the UI. Whether the model actually writes grounded, non-repetitive, useful
education under this prompt is unproven, and no test can prove it. One real call
against a real analysis should be read by a human before this is trusted.

---

## 6. Theme and accessibility QA

`test/qa/full_app_matrix_test.dart` runs nine screens — now including
`LiveCameraPage` — across four conditions:

| Condition | Result |
| --- | --- |
| Light, 320 logical px, 2x text | **PASS** |
| Dark, POCO X3 GT size (393×873), default text | **PASS** |
| System light, POCO X3 GT size, default text | **PASS** |
| System dark, POCO X3 GT size, default text | **PASS** |

Every case renders, scrolls to its full extent without overflow, resolves to the
expected brightness, and exposes labelled Android-sized tap targets.

The new surfaces carry their own accessibility coverage: the Palette's disclosure
announces expanded/collapsed state; the shutter carries an explicit semantic
label; the framing oval is excluded from semantics because an alignment aid is
useless to a screen-reader user; guidance is a live region; each Beauty Profile
row reads as one sentence rather than three fragments; and check rows carry an
icon as well as colour.

**The POCO X3 GT rows are a 393×873 simulation, not physical evidence.**

---

## 7. Performance QA

```text
NOT MEASURED
```

Every item the phase lists — camera startup, validation responsiveness, guidance
stability, frame backlog, memory behaviour, shutter responsiveness, repeated
scans, resource disposal — requires a running camera on real hardware. No device
was connected (`flutter devices` shows Windows, Chrome and Edge; `adb devices`
is empty).

No performance claim is made. What *is* established, and is not the same thing:

- the drop-don't-queue rule holds under a synthetic burst — 200 frames delivered
  during one open analysis produce exactly one invocation and 199 drops;
- a superseded analysis is discarded and cannot overwrite a newer session;
- disposal releases the camera, verified through the real controller's disposal
  path.

The validation cadence (200 ms) and every threshold in `LiveValidationThresholds`
are labelled **PROVISIONAL** in source, with a test asserting that label is
present. They were chosen to be permissive and have never been calibrated against
a real sensor.

---

## 8. Journey evidence

Both required journeys are covered by deterministic automated evidence through to
preview generation, and by the pre-existing V4 suites from Result onward into
Show Me How.

```text
Camera  → live validation → Ready → manual capture → final still validation
        → face analysis (1) → Beauty Profile → Style → Educational Palette
        → Preview

Gallery → automatic local validation → face analysis (1) → Beauty Profile
        → Style → Educational Palette → Preview
```

Both are asserted to cost exactly one face analysis end to end, to build the
palette from the same accepted analysis, and to carry education through to the
palette intact. Both entry points are shown to produce identical profile values —
where the still came from changes nothing downstream.

Analysis reuse: style A → back → style B costs **zero** new analyses; four style
changes still cost one; re-requesting the same style reuses the recommendation.

Result, Makeup Breakdown, Tutorial, My Makeup Kit and History are covered by the
existing suites, which pass in full. **This is deterministic automated journey
evidence, not a claim of a physical tap-through.**

---

## 9. Validation record

```text
dart format .
PASS — 432 files, 0 changed

flutter analyze
PASS — No issues found

flutter test
PASS — 1,413 tests, 0 failures

flutter test test/qa/lsep_baseline_lock_test.dart
PASS — 35 lock assertions

flutter test test/qa/full_app_matrix_test.dart
PASS — 46 matrix checks

flutter build apk --debug --dart-define-from-file=config/development.json
PASS — app-debug.apk

flutter devices
Windows, Chrome, Edge only — no Android target

adb devices
empty

flutter run --dart-define-from-file=config/development.json
NOT RUN — no Android device or emulator available
```

`flutter analyze` reports **No issues found**. The two `hasFlag` deprecation
warnings present since before LSEP-0 were resolved in LSEP-6 as part of
producing the required Result regression pass; the fix was to the test's use of a
changed Flutter API, not to any product code.

---

## 10. Final lock

| Lock | Required | Actual | Status |
| --- | --- | --- | --- |
| Auto capture | NONE | NONE | **PASS** |
| Live Gemini | 0 | 0 | **PASS** |
| Face analysis per accepted still | 1 | 1 | **PASS** |
| Face analysis for rejected still | 0 | 0 | **PASS** |
| Extra education AI call | 0 | 0 | **PASS** |
| Final preview model | `gemini-3.1-flash-image` | `gemini-3.1-flash-image` | **PASS** |
| Tutorial model | `gemini-3.1-flash-image` | `gemini-3.1-flash-image` | **PASS** |
| Tutorial resolution | 1K | `"1K" as const` | **PASS** |
| Tutorial prompt | `tutorial_guideline_v4_7` | unchanged | **PASS** |
| Manifest prompt | `tutorial_manifest_v4_1` | unchanged | **PASS** |
| Face analysis model | current deployed | `GEMINI_MODEL` → `gemini-3.6-flash` | **PASS** |
| Recommendation model | current deployed | `GEMINI_MODEL` → `gemini-3.6-flash` | **PASS** |
| Placement data | PRESERVED | entity, DTO, validator, look plan, tutorial, Breakdown | **PASS** |
| Technique data | PRESERVED | same six surfaces | **PASS** |
| Palette placement | HIDDEN | absent from the card | **PASS** |
| Palette technique | HIDDEN | absent from the card | **PASS** |
| My Kit authority | PRESERVED | `kit_makeup_recommendation_v2` unchanged, owned-only, no standard fallback | **PASS** |
| Database / RLS / storage | NONE | `supabase/migrations` byte-identical | **PASS** |
| Dependencies | camera only | `camera ^0.12.0+2` + 5 transitive; no ML runtime | **PASS** |

---

## 11. Restrictions required to lift the decision

On a physical Android handset, preferably a POCO X3 GT, a human must:

1. **Camera journey.** New Scan → reach Ready → *wait without touching the
   shutter and confirm no photograph is taken* → choose an expression → tap →
   confirm the captured frame is the one chosen → confirm analysis runs once →
   Beauty Profile → Style → Palette → Preview → Result → Show me how.
2. **Gallery journey.** Choose a photo → confirm validation and analysis run with
   no further taps → the same path onward.
3. **Rejection paths.** Confirm a deliberately unusable photo — too dark, badly
   blurred — is rejected with an actual reason and that **no analysis is
   charged**.
4. **Calibrate.** Judge whether the provisional cadence and thresholds in
   `LiveValidationThresholds` behave sensibly on a real sensor, and replace them
   with measured values. This is the most likely thing to need adjustment.
5. **Observe performance.** Camera startup, guidance stability and flicker, frame
   backlog, memory across repeated scans, shutter responsiveness, and that the
   camera indicator goes out when the screen is left.
6. **Read one real v3 recommendation.** Confirm the three education sections are
   grounded, specific, non-repetitive across categories, and free of application
   instructions.
7. **Accessibility.** TalkBack traversal of the camera screen, the Palette
   disclosure, and the Beauty Profile.

Any failure reopens LSEP-7 for minimal remediation of the proven defect only.

---

## 12. Known limitations carried forward

- **No device evidence anywhere in LSEP-3 through LSEP-7.** The camera has never
  run. This is the single largest gap.
- **Thresholds and cadence are provisional** and explicitly labelled as such.
- **No live `makeup_recommendation_v3` call has been made.** Education quality is
  contractually constrained but empirically unobserved.
- **The Deno test suite has never been run** — `deno` is not installed on this
  machine. `generate-makeup-recommendation/validation_test.ts` was extended from
  2 to 11 cases in LSEP-1 and remains unverified locally. The Dart contract tests
  assert the same invariants at source level, which is the pattern this project
  already uses for exactly this reason.
- **Two intake paths carry duplicated orchestration.** `LiveCaptureController`
  and `ScanController` each hold a ~15-line validate-then-analyse tail. Both are
  individually tested and locked, but the "exactly one analysis" rule lives in
  two places rather than one. Consolidating them is a worthwhile follow-up and
  was deliberately not done inside a phase that did not authorize it.
- **My Makeup Kit has no Educational Palette.** Kit mode has no pre-preview
  palette surface at all, and adding one would touch the protected Result
  experience. LSEP-0 raised this as an open decision; it was never answered and
  the kit contract was left byte-identical.

---

## 13. Decision

```text
LSEP BASELINE ACCEPTED — PENDING REAL DEVICE
```
