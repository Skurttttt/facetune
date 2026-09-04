# LSEP-0 — Baseline Freeze & Feasibility Map

Date: 2026-09-04
Branch: `feature/live-scan-educational-palette`
HEAD: `0ba14fc` — "Final UI for Final Preview Standrad/Kit"
Working tree at entry and exit: clean except two untracked LSEP authority documents.
Phase type: **READ-ONLY**. No source, dependency, model, prompt, database, RLS, storage, or
deployment change was made. No paid AI call was issued.

---

## 0. Branch gate

```text
git branch --show-current   feature/live-scan-educational-palette   REQUIRED — PASS
git log -1 --oneline        0ba14fc Final UI for Final Preview Standrad/Kit
git status --short          ?? FACETUNE_LIVE_SCAN_EDUCATIONAL_PALETTE_PHASE_PROMPTS.md
                            ?? FACETUNE_LIVE_SCAN_EDUCATIONAL_PALETTE_SOURCE_OF_TRUTH.md
git diff --stat             (empty)
```

The branch already exists and is already checked out. No branch mutation was needed or
performed. The two untracked files are the authority documents for this track, not source.

---

## 1. Camera implementation — the decisive finding

### External, not in-app

FaceTune has **no in-app camera**. Capture is delegated to the operating system's camera
application through `image_picker`:

[device_selfie_repository.dart:36-44](lib/features/scan/data/repositories/device_selfie_repository.dart#L36-L44)

```dart
final selected = await _picker.pickImage(
  source: source == SelfieSource.camera ? ImageSource.camera : ImageSource.gallery,
  preferredCameraDevice: CameraDevice.front,
  requestFullMetadata: false,
);
```

`SelfieSource` is a two-value enum — `camera`, `gallery` — and both branches call the same
`pickImage`. The only difference is the intent handed to the OS and a runtime `CAMERA`
permission gate ahead of it.

### Camera dependencies

`pubspec.yaml` declares no camera plugin. `pubspec.lock` contains no `camera`, no
`google_mlkit_*`, no `tflite*`, no `opencv*`, no `mediapipe*`, no `firebase_ml*`.

The camera-adjacent dependencies that exist:

| Package | Version | Role |
| --- | --- | --- |
| `image_picker` | ^1.1.2 | Launches the OS camera/gallery, returns one still |
| `permission_handler` | ^12.0.1 | Runtime `CAMERA` permission |
| `flutter_image_compress` | ^2.4.0 | Post-capture JPEG re-encode |
| `path_provider` / `path` | — | Temp-file staging |

`android/app/src/main/AndroidManifest.xml` already declares
`<uses-permission android:name="android.permission.CAMERA" />`.

### Live-frame access

**None. Zero. Not partially, not through a workaround.**

`image_picker` returns one `XFile` after the OS camera app has already closed. There is no
preview surface inside FaceTune, no frame callback, no texture, no `startImageStream`
equivalent, and no path to one with the current dependency set.

**Feature A (Live Scan + Manual Capture) cannot be implemented on the current dependency
set.** This is not a design preference — the capability does not exist in the process. See
the dependency gate in section 9.

### Gallery picker

Same `pickImage` call with `ImageSource.gallery`. No album UI of FaceTune's own.

---

## 2. Local validator — what it actually checks

Two collaborating classes, both pure Dart, both free of any computer vision.

### `SelfieFileValidator`

[selfie_file_validator.dart](lib/features/scan/domain/services/selfie_file_validator.dart)

- rejects `size <= 0`
- rejects `size > maximumBytes` (default 20 MB; the upload copy is re-validated at 10 MB)
- `detectMimeType` reads the first 16 bytes and recognises JPEG (`FFD8`), PNG (`89504E47`),
  WebP (`RIFF`…`WEBP`), HEIC/HEIF (`ftyp` + `heic|heix|hevc|hevx|mif1|msf1`)
- requires the file extension to agree with the detected magic bytes

### `FlutterImageValidationRepository`

[flutter_image_validation_repository.dart:23-27](lib/features/scan/data/repositories/flutter_image_validation_repository.dart#L23-L27)

| Threshold | Value |
| --- | --- |
| `minimumDimension` | 480 px per side |
| `maximumDimension` | 12000 px per side |
| `maximumPixels` | 80,000,000 |
| `minimumAspectRatio` | 0.4 |
| `maximumAspectRatio` | 2.5 |

It decodes through `ui.instantiateImageCodec`, which doubles as a corruption check, and
validates the original and the compressed upload copy independently. The upload copy must be
`image/jpeg`.

### Capability matrix — the five LSEP live checks

| LSEP check | Local capability today |
| --- | --- |
| One person only | **ABSENT** |
| Face fully visible | **ABSENT** |
| Good / usable lighting | **ABSENT** |
| Sharp enough / no heavy blur | **ABSENT** |
| No extreme angle | **ABSENT** |

There is **no on-device face detection, luminance analysis, blur estimation, or pose
estimation anywhere in the repository.** The local layer validates a *file*, never a *face*.

---

## 3. Where face count, lighting, blur, visibility and framing actually happen

All five live inside the **single paid Gemini face-analysis call**, not in a separate
validation service.

[analyze-face/schema.ts](supabase/functions/analyze-face/schema.ts) — `validation` object:

```text
faceCount              integer 0..10
lightingAcceptable     boolean
sharpnessAcceptable    boolean
faceVisible            boolean
framingAcceptable      boolean
```

[analyze-face/prompt.ts](supabase/functions/analyze-face/prompt.ts) runs suitability as
"STEP 1" of the same prompt that classifies attributes in STEP 2 and calibrates confidence in
STEP 3. Prompt version `face_analysis_v2`.

The consequences that matter to this track:

1. **A quality rejection today costs a full paid analysis call.** The user uploads, the quota
   is consumed, Gemini runs, and only then is "too blurry" returned. On a 422 the function
   deletes the uploaded object
   ([index.ts](supabase/functions/analyze-face/index.ts)) but the spend is gone.
2. LSEP's local live validator is therefore **purely additive cost avoidance**. It does not
   replace or weaken the authoritative gate — the accepted still is still judged by the same
   server call.
3. The failure vocabulary already exists client-side and is already mapped to user copy in
   `_validationMessages` in
   [supabase_face_analysis_repository.dart](lib/features/analysis/data/repositories/supabase_face_analysis_repository.dart):
   `no_face`, `multiple_faces`, `face_obscured`, `insufficient_lighting`, `excessive_blur`,
   `poor_framing`, `low_confidence`. **LSEP guidance copy should reuse this vocabulary rather
   than invent a parallel one.**

### Dead contract — flagged, not touched

[secure_image_validation_contract.dart](lib/features/scan/domain/contracts/secure_image_validation_contract.dart)
declares `SecureImageValidationRequest` / `SecureImageValidationResponse` with a `checks`
array and a three-state decision. It is referenced only by its own test
(`test/features/scan/secure_image_validation_contract_test.dart`). The real invocation in
[analysis_remote_data_source.dart:63-79](lib/features/analysis/data/data_sources/analysis_remote_data_source.dart#L63-L79)
sends a smaller payload (`mimeType`, `byteSize`, `width`, `height`) and the Edge Function
ignores `localValidation` entirely. Not changed in this phase; noted because a later phase may
be tempted to "wire it up" and should decide deliberately.

---

## 4. Face-analysis trigger and the one-shot contract

### Trigger sites — exactly two, both explicit taps

Both in [scan_page.dart](lib/features/scan/presentation/pages/scan_page.dart):

- line 106 — the primary CTA, only reachable when `stage == readyForSecureValidation`
- line 148 — "Retry analysis" inside `_AnalysisError`

**Nothing calls `analyze()` from `build()`.** `AnalyzeFace` is reached only through
`FaceAnalysisController.analyze`, which is guarded by `if (state.isBusy) return;` and an
`_operationGeneration` epoch that discards stale async results.

### Current friction — the thing LSEP-5 removes

The scan screen requires **two deliberate taps after the photo exists**, for camera and
gallery alike:

```text
photo acquired  →  stage previewReady        →  button reads "Validate selfie"
                →  stage readyForSecureValidation → button reads "Analyze selfie"
                →  face analysis
```

`_primaryLabel` in scan_page.dart encodes exactly that. Between the two sits an
`AppNotice` announcing "Local checks passed", plus a permanent five-row `_GuidanceCard`
listing the same five checks LSEP wants to move into live guidance.

### Analysis identity and idempotency

[supabase_face_analysis_repository.dart](lib/features/analysis/data/repositories/supabase_face_analysis_repository.dart)
mints a **fresh `uuid.v4()` per `analyze()` call** for both the analysis id and the storage
object:

```dart
final analysisId = _uuid.v4();
final imageId = _uuid.v4();
final storagePath = '$userId/analyses/$analysisId/original/$imageId.jpg';
```

The Edge Function's idempotency short-circuit (`select * from analyses where id = analysisId`)
therefore **never fires for a client retry** — a retry is a new id, a new upload, and a new
paid call. That is defensible after a genuine failure, but it means a "Retry analysis" after a
*successful server call whose response was lost* double-charges. Spend is bounded only by
`consumeAiQuota(userClient, "face_analysis")`.

**Not a defect introduced by this track, and not in LSEP-0's scope to change.** Recorded
because LSEP-5's "exactly one analysis per accepted still" contract must not accidentally
weaken it, and because a later phase may want a stable per-accepted-still id.

---

## 5. Analysis reuse

| Path | Re-analyses? |
| --- | --- |
| Style A → back → Style B | **No.** `faceAnalysisControllerProvider` holds the success state; no style path calls `analyze()` |
| Reopen from History / Saved Looks | **No.** `restore(entry.analysis)` |
| New selfie acquired | Yes — `clear()` is called in `_acquire` when the source changed |
| "Start over" / Home entry | Yes — `clear()` / `invalidate(faceAnalysisControllerProvider)` |
| Widget rebuild, theme, orientation | **No.** Nothing in `build()` triggers analysis |

The reuse requirement of SoT §19 is **already satisfied**.

---

## 6. Recommendation contract

### Standard mode

[generate-makeup-recommendation](supabase/functions/generate-makeup-recommendation/)

| Aspect | Current value |
| --- | --- |
| Model | `Deno.env.get("GEMINI_MODEL")` → default `gemini-3.6-flash` |
| Prompt version | `makeup_recommendation_v2` |
| Generation config | `temperature 0.4`, `topP 0.9`, `maxOutputTokens 4096`, `candidateCount 1` |
| Retry | 2 attempts, 400 ms × attempt backoff, transient only |
| Timeout | 45 s |

Schema — 10 fixed categories (`foundation`, `concealer`, `contour`, `highlight`, `blush`,
`eyeshadow`, `eyebrow`, `eyeliner`, `lipstick`, `lipGloss`) plus `overallIntensity`. Each item:

```text
name        string 2..80
hex         "#RRGGBB" uppercase, or null
placement   string 3..220
technique   string 3..220
finish      string 2..80
intensity   enum sheer|soft|medium|bold
reasoning   string 3..240
```

### Existing reasoning fields

**Exactly one per item: `reasoning`, capped at 240 characters.** There is nothing else. The
LSEP §24 education contract (Your features / The effect / The style) has **no counterpart in
the current schema** and cannot be derived from `reasoning` without inventing content.

### The blocker LSEP-1 must plan around

[generate-makeup-recommendation/validation.ts](supabase/functions/generate-makeup-recommendation/validation.ts)
enforces **exact key counts**, not merely required keys:

```ts
if (Object.keys(input).length !== expectedKeys.size ||
    Object.keys(input).some((key) => !expectedKeys.has(key))) throw invalidResponse();
```

and the same pattern inside `item()` against `allowedItemKeys`. The JSON schema likewise sets
`additionalProperties: false`.

**Adding education fields is impossible without editing this validator and this schema in the
same change.** If only the prompt and schema were extended, the server would reject its own
model's output. Recorded now so LSEP-1 treats validator + schema + prompt as one atomic edit.

### My Makeup Kit mode

[generate-kit-makeup-recommendation](supabase/functions/generate-kit-makeup-recommendation/) —
prompt `kit_makeup_recommendation_v2`, a different shape entirely:
`{ selections[], overallIntensity, summary }`, each selection carrying `productId`, `category`,
`colorHex`, `finish`, `placement`, `technique`, `intensity`, `reasoning`. Owned-product IDs are
server-validated; user text is passed through `sanitizePromptText`.

**Two independent recommendation contracts exist.** Any education work must state explicitly
whether it covers one or both.

---

## 7. Recommendation persistence and historical compatibility

### No migration is required

```sql
recommendation_json jsonb not null default '{}'::jsonb,
constraint recommendations_payload_is_object check (jsonb_typeof(recommendation_json) = 'object')
```

The column accepts any JSON object. Additive education fields need **no schema change, no RLS
change, no storage change**.

### But the reuse key includes the prompt version

[generate-makeup-recommendation/index.ts](supabase/functions/generate-makeup-recommendation/index.ts):

```ts
.eq("analysis_id", payload.analysisId)
.eq("makeup_style", payload.style)
.eq("prompt_version", MAKEUP_RECOMMENDATION_PROMPT_VERSION)
```

Bumping `makeup_recommendation_v2` → `v3` means **every existing (analysis, style) pair pays
once more** the next time it is opened. This is a real, bounded, one-time cost, and it is not
a second AI call per look — the call count per look is unchanged. It must be reported to the
user before LSEP-1 proceeds, not discovered afterwards.

### Client decode

[makeup_recommendation_dto.dart](lib/features/recommendation/data/models/makeup_recommendation_dto.dart)
reads a fixed key list and ignores unknown keys, so a v3 payload decodes on old clients and
`_string(item, 'name')`-style strictness applies only to the keys it names. Education fields
must be read as **nullable** so v2 rows continue to decode — which satisfies SoT §28's
"show compact recommendation, do not invent, do not backfill with AI".

---

## 8. Placement / Technique — complete consumer map

### Data path — must be preserved end to end

| Location | Role |
| --- | --- |
| [makeup_recommendation.dart:4-15](lib/features/recommendation/domain/entities/makeup_recommendation.dart#L4-L15) | `MakeupRecommendationItem.placement` / `.technique` |
| [makeup_recommendation_dto.dart:30-31](lib/features/recommendation/data/models/makeup_recommendation_dto.dart#L30-L31) | Decode — currently **required** |
| [look_plan_convergence.dart:99-100](lib/features/tutorial/domain/catalog/look_plan_convergence.dart#L99-L100) | Standard → validated look plan |
| [standard_look_entry.dart:14-33](lib/features/tutorial/domain/entities/standard_look_entry.dart#L14-L33) | Tutorial supporting context |
| [tutorial_dtos.dart:260-261](lib/features/tutorial/data/models/tutorial_dtos.dart#L260-L261) | Tutorial decode |
| [kit_makeup_recommendation_dto.dart:28-29](lib/features/makeup_kit/data/models/kit_makeup_recommendation_dto.dart#L28-L29) | Kit selection decode |

### Presentation surfaces — exactly four

| # | Surface | File | LSEP disposition |
| --- | --- | --- | --- |
| 1 | **Personalized Palette** card | [recommendation_item_card.dart:47-48](lib/features/recommendation/presentation/widgets/recommendation_item_card.dart#L47-L48) | **HIDE — the only LSEP-2 target** |
| 2 | Result → Makeup Breakdown | [makeup_breakdown.dart:196-197](lib/features/results/presentation/widgets/makeup_breakdown.dart#L196-L197) | **PROTECTED** |
| 3 | Show Me How → product card | [tutorial_product_cards.dart:168-188](lib/features/tutorial/presentation/widgets/tutorial_product_cards.dart#L168-L188) | **PROTECTED** |
| 4 | Kit Result → owned-product breakdown | [kit_result_product_card.dart:79](lib/features/makeup_kit/presentation/widgets/kit_result_product_card.dart#L79) | **PROTECTED** |

Surface 4 is reached from `_RealizedKitBreakdown` inside the kit **Result** screen — it is the
kit-mode Makeup Breakdown, not a kit palette. Under UI Productionization SoT §8 the Makeup
Breakdown is a protected data authority, so it keeps Placement.

`REMOVE FROM PALETTE PRESENTATION ≠ REMOVE FROM SYSTEM DATA` is therefore satisfiable by a
**single-file presentation edit**, with the DTO and every downstream consumer untouched.

---

## 9. Palette UI and the Ready-for-preview block

### Standard mode

Route `/recommendation` → [makeup_recommendation_page.dart](lib/features/recommendation/presentation/pages/makeup_recommendation_page.dart),
titled "Your personalized palette", subtitled `{style} · {overallIntensity} intensity`.

It renders **all ten categories, all fully expanded, always**. Each `RecommendationItemCard`
shows: hex swatch, category label, shade name, intensity chip, `Placement:`, `Technique:`,
`Finish:`, then the `reasoning` line in muted text. There is **no progressive disclosure
anywhere** — SoT §29's collapsed default does not exist yet.

The tail of that ListView:

```text
StatusState( title: 'Ready for your preview',
             message: 'Identity preservation is prioritized, but AI results can
                       vary. You can generate another variation if needed.',
             icon: auto_awesome )
PrimaryButton( 'Generate makeup preview' → onGeneratePreview )
```

`onGeneratePreview` — defined at page level — guards against `MakeupPreviewStatus.generating`,
calls `makeupPreviewControllerProvider.notifier.generate(recommendation: …)`, then
`context.push(previewRoute)`. **LSEP-2 must preserve this callback verbatim** (SoT §30).

### My Makeup Kit mode — a scope question, not a decision

**Kit mode has no pre-preview palette screen at all.** Its route goes mode selection →
generating → Result. The kit "Recommended palette" (`KitProductPalette`) and the owned-product
breakdown both live *inside* the Result screen.

SoT §21/§22 speak of "Personalized Palette" in the singular. Only Standard has one.

```text
OPEN QUESTION FOR LSEP-2
Does "Educational Personalized Palette" cover:
  (a) Standard's /recommendation page only, or
  (b) Standard's page plus an equivalent education surface in the Kit Result?
Option (b) touches the accepted Result experience, which SoT §32 protects.
DO NOT DECIDE THIS INSIDE AN IMPLEMENTATION PHASE.
```

### Result → post-preview palette (protected, distinct)

[preview_result_page.dart:485-487](lib/features/preview/presentation/pages/preview_result_page.dart#L485-L487)
renders `SectionHeader('Recommended palette')` + `RecommendedPalette` — a horizontal swatch
strip carrying shade name only, **no placement or technique**. Not an LSEP target; named here
so the two "palettes" are never confused.

---

## 10. Protected subsystems — verified present and unchanged

| Lock | Location | Value |
| --- | --- | --- |
| Final preview model | `_shared/final_preview_model.ts` | `gemini-3.1-flash-image` — **hard-locked in code**; `GEMINI_IMAGE_MODEL` only validates and fails closed on disagreement |
| Tutorial guideline model | `_shared/tutorial_ai_config.ts` | `gemini-3.1-flash-image` — env-overridable via `GEMINI_TUTORIAL_MODEL` |
| Tutorial resolution | `_shared/tutorial_ai_config.ts` | `"1K"` const |
| Tutorial prompt | `_shared/tutorial_ai_config.ts` | `tutorial_guideline_v4_7` |
| Manifest prompt | `analyze-tutorial-manifest-v4/prompt.ts` | `tutorial_manifest_v4_1` |
| Face analysis model | `analyze-face/index.ts` | `GEMINI_MODEL` env, default `gemini-3.6-flash`, prompt `face_analysis_v2` |
| Recommendation model | `generate-makeup-recommendation/index.ts` | same `GEMINI_MODEL` env, default `gemini-3.6-flash` |

**Asymmetry worth noting:** the final-preview model is hard-locked with a fail-closed
configuration check, while the tutorial model is still an env override. Both currently resolve
to `gemini-3.1-flash-image`. Not changed here; flagged so no later phase reads the tutorial
override as permission to switch.

Also protected and confirmed intact: My Makeup Kit owned-only authority with server-side
product validation and immutable snapshots; RLS enabled on `recommendations` with own-row
select/insert policies and `anon` revoked; private `face-images` bucket with ownership-checked
paths; per-operation quota via `consumeAiQuota`.

---

## 11. DEPENDENCY GATE

```text
DEPENDENCY REQUIRED:
YES — Live Scan (Feature A) cannot be implemented without at least one new dependency.

MISSING CAPABILITY:
1. Live camera preview inside FaceTune with programmatic frame access.
   image_picker returns one still after the OS camera app has closed. There is no
   preview surface, no frame stream, and no workaround within current dependencies.
2. On-device face detection — face count, face visibility, head pose/angle.
   No detector of any kind exists in the repository.
```

### Capability split — this materially changes the cost of the feature

Once a camera plugin supplies frames, the five checks divide unevenly:

| Check | Needs a face detector? | Achievable in pure Dart from the Y plane? |
| --- | --- | --- |
| Good / usable lighting | No | **Yes** — mean and spread of luma |
| Sharp enough / no heavy blur | No | **Yes** — Laplacian or Tenengrad variance on a downsampled Y plane |
| Hold steady | No | **Yes** — frame-to-frame luma delta |
| One person only | **Yes** | No |
| Face fully visible | **Yes** | No |
| No extreme angle | **Yes** | No |

A reduced Live Scan — live preview, a fixed framing oval, plus lighting/blur/steadiness
guidance — is reachable with **one** dependency. Face count, visibility, and angle require a
**second**. This is a genuine product choice and belongs to the user, not to an implementation
phase.

### Proposed dependency A — `camera` (required for any Live Scan)

```text
PROPOSED DEPENDENCY:  camera (pub.dev, published by flutter.dev / Flutter team)
MISSING CAPABILITY:   live preview + startImageStream frame access

APK SIZE:      Small. Pulls AndroidX CameraX. Estimated low single-digit MB.
               MUST BE MEASURED against the current debug/release APK before adoption —
               no number here is verified.
PERFORMANCE:   The risk is not the plugin, it is the sampling policy. SoT §13 forbids
               validating every frame. Requires: controlled cadence, one expensive
               validation in flight, no unbounded queue, latest-result authority,
               stale-result rejection, explicit disposal. Must be measured on POCO X3 GT.
PRIVACY:       Frames stay in-process. SoT §14 compliance is an implementation
               obligation, not a property of the plugin: no upload, no Edge Function
               call, no logging of bytes, no signed URL, no unnecessary persistence.
SECURITY:      No network surface. No new secret. First-party Flutter team package.
LICENSE:       BSD-3-Clause (Flutter ecosystem standard). VERIFY at adoption.
ANDROID:       CameraX-based; POCO X3 GT is a mainstream device and is expected to be
               well supported. Front-camera selection must reproduce the existing
               preferredCameraDevice: CameraDevice.front behaviour.
MAINTENANCE:   Flutter-team maintained; among the best-supported plugins available.
ALTERNATIVES:  None that provide frame access. Staying on image_picker means Feature A
               is not implementable — that is a legitimate outcome the user may choose.
TEST PLAN:     Fake the camera controller behind a repository interface so widget tests
               drive synthetic frames. Cover: permission denied and permanently denied,
               controller init failure, disposal on route pop and on app background,
               stale-result rejection, guidance-state transitions, shutter enabled only
               on Ready, and — explicitly — NO AUTO CAPTURE.
```

### Proposed dependency B — a face detector (required for the remaining three checks)

```text
PROPOSED DEPENDENCY:  google_mlkit_face_detection, or equivalent
MISSING CAPABILITY:   face count, face visibility, head pose / extreme angle

*** STOP CONDITION — READ BEFORE PROPOSING THIS ***

CODEX_MASTER_GUIDE.md §3 and §31 prohibit MediaPipe, OpenCV, and TensorFlow Lite.
V4 Source of Truth §13 repeats the prohibition.
LSEP Source of Truth §15 additionally requires a STOP and a report for
"a new ML runtime, a new face detector, or a new camera plugin".

ML Kit face detection is not literally named in the prohibition list, but it is
unambiguously "a new face detector" and "a new ML runtime". It therefore requires
EXPLICIT USER APPROVAL and, in my reading, an explicit reconciliation with the
CODEX_MASTER_GUIDE prohibition — which was written to keep FaceTune's image
understanding in Gemini rather than in on-device CV.

I am reporting this, not recommending it, and not installing it.

APK SIZE:      Bundled model: large — commonly cited in the +16-20 MB range.
               Unbundled (Google Play Services): far smaller, but adds a Play Services
               dependency and a first-run model download. BOTH FIGURES MUST BE MEASURED.
PERFORMANCE:   Detection is the expensive operation. Cadence discipline from §13 applies
               with more force here. Must be measured on POCO X3 GT.
PRIVACY:       On-device inference; no frame leaves the device. Consistent with §14
               provided nothing is logged or persisted.
SECURITY:      No network surface for the bundled variant. The unbundled variant depends
               on Play Services availability and must fail safely when absent.
LICENSE:       Plugin Apache-2.0; the ML Kit SDK itself carries Google's own terms.
               VERIFY BOTH at adoption.
ANDROID:       Widely supported. Play-Services availability must be handled explicitly.
MAINTENANCE:   Community-maintained Flutter wrapper over a Google SDK — a weaker
               maintenance position than dependency A.
ALTERNATIVES:  (a) Ship Live Scan WITHOUT the three detector-dependent checks: live
                   preview, a static framing oval, and lighting/blur/steadiness guidance.
                   One dependency, no ML runtime, no guide conflict. Face count,
                   visibility and angle remain enforced by the existing server call
                   exactly as they are today — which is where they are enforced now.
               (b) Do not implement Feature A; keep OS camera capture and deliver
                   Feature B (Educational Palette) only.
               (c) Adopt a detector with explicit approval and an explicit amendment
                   to CODEX_MASTER_GUIDE §3/§31.
TEST PLAN:     Detector behind a domain interface with a fake; deterministic tests for
               zero faces, one face, multiple faces, occlusion, and extreme yaw/pitch.

NOTHING WAS INSTALLED. pubspec.yaml AND pubspec.lock ARE UNCHANGED.
```

---

## 12. Validation record

```text
git branch --show-current
PASS — feature/live-scan-educational-palette

git status --short
PASS — only the two untracked LSEP authority documents; no source modified

git diff --stat
PASS — empty

flutter analyze
2 issues found — both info-level, both PRE-EXISTING, both in test code:
  test/features/results/makeup_breakdown_test.dart:247:40  deprecated_member_use ('hasFlag')
  test/features/results/makeup_breakdown_test.dart:257:40  deprecated_member_use ('hasFlag')

Reported honestly rather than as "clean". These are not errors, are not in lib/, and
were not introduced by this phase — the working tree is untouched. They post-date the
UI-P7 lock, which recorded "No issues found" at 86f8b4e; HEAD is now 0ba14fc.
Fixing them is not authorized by LSEP-0.

flutter test / flutter build apk / flutter run
NOT RUN — LSEP-0 is read-only and authorizes no build or device work.
```

---

## 13. Done-when checklist

| Requirement | Status |
| --- | --- |
| Camera architecture known | **YES** — external OS camera via `image_picker`; no in-app camera |
| Live-frame feasibility known | **YES** — impossible today; requires `camera`; gate filed |
| Validator capability known | **YES** — file/format/dimension only; zero CV |
| Face-analysis trigger known | **YES** — two explicit taps in `scan_page.dart`; never from `build()` |
| Recommendation contract known | **YES** — v2, 10 categories, one 240-char `reasoning`; exact-key validator |
| Persistence known | **YES** — `jsonb`, no migration needed; prompt-version reuse key has a cost |
| Placement/Technique consumers known | **YES** — 6 data sites, 4 presentation surfaces, 1 is the LSEP-2 target |
| Protected surfaces identified | **YES** — all five AI locks verified in source |
| No source changed | **YES** — `git diff --stat` empty |

---

## 14. Decisions the user must make before LSEP-1 or LSEP-3

These are not implementation details. Each changes what gets built.

1. **Live Scan scope.** Full five-check Live Scan (needs a face detector, conflicts with
   CODEX_MASTER_GUIDE §3/§31), reduced Live Scan (one dependency, no ML runtime), or no
   Feature A at all.
2. **Recommendation prompt-version bump cost.** Education fields require
   `makeup_recommendation_v2 → v3`, which makes every existing (analysis, style) pair pay once
   more on next open. Calls per look are unchanged. Acceptable or not?
3. **Does the Educational Palette cover My Makeup Kit?** Kit has no pre-preview palette, and
   an education surface in the Kit Result touches the protected accepted Result experience.
4. **Ordering.** Feature B (LSEP-1/2) is implementable today with no new dependency. Feature A
   (LSEP-3/4/5) is blocked on decision 1. Running LSEP-1 and LSEP-2 first delivers value while
   decision 1 is open.

---

## 15. Recommended next phase

**LSEP-1 — Educational Recommendation Contract**, but only after decisions 2 and 3 above are
answered. LSEP-1 is not blocked on the camera dependency gate.

If decision 1 is answered first and the reduced Live Scan is chosen, LSEP-3 is equally
available as the next phase.

**No later phase was implemented. No Git mutation was performed.**
