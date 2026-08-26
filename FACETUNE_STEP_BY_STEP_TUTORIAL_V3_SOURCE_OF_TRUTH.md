# FaceTune Step-by-Step Tutorial V3 — Source of Truth

**Status:** Authoritative V3 specification  
**Branch:** `feature/step-by-step-tutorial-v3`  
**Implementation agent:** Claude Code using Opus 5  
**Stack:** Flutter/Dart + Riverpod + Clean Architecture + Supabase + Gemini through authenticated Edge Functions

## 1. Core V3 Decision

V3 removes all intermediate makeup-result generation.

There is NO:

- Foundation Result
- Concealer Result
- Contour Result
- Blush Result
- Eyeshadow Result
- Eyeliner Result
- Lip Result

Every non-final step produces only a **personalized guideline image**.

Core flow:

```text
Original Selfie
+ Face Analysis
+ Selected Look
+ Persisted Recommendation
+ Canonical Final Preview
+ Current Persisted Step Spec
        ↓
Personalized Guideline Image
```

Every step starts again from the ORIGINAL SELFIE.

A generated guideline image must NEVER become the source image for the next step.

This removes recursive image drift by design.

## 2. Product Goal

The tutorial must teach the user:

- WHAT to apply
- WHERE to apply it
- DIRECTION
- TECHNIQUE
- INTENSITY / COVERAGE
- WHY that placement suits their face
- how the step contributes to the exact selected final look

The tutorial must be dynamic and personalized. It is not a generic makeup course.

## 3. Protected Baseline

Development happens only on:

`feature/step-by-step-tutorial-v3`

Before every phase:

```bash
git status
git branch --show-current
```

If the branch is not exactly `feature/step-by-step-tutorial-v3`, STOP.

Do not:
- develop on `main`
- modify V1/V2 branches
- reset/force-push/delete branches
- merge V1/V2 wholesale into V3
- discard unrelated work

Protect existing FaceTune:
- Auth
- Face Analysis
- Makeup Recommendation
- Premium AI Makeup Preview
- Result/History
- My Makeup Kit
- Kit recommendation/preview
- private storage
- RLS
- ownership validation
- Gemini secret architecture

## 4. Security

Required architecture:

```text
Flutter
→ authenticated Supabase Edge Function
→ Gemini API
```

Never expose Gemini keys to Flutter/APK/logs/client payloads.

Never:
- disable RLS
- make private buckets public
- trust arbitrary client storage paths
- overwrite original selfies
- bypass server-side ownership validation

Use:

`npx -y supabase ...`

not bare `supabase`.

## 5. Canonical Final Look

The existing premium final preview is the exact tutorial destination.

Every step must answer:

> How should THIS user apply THIS category to reproduce THIS exact selected final look?

The canonical final preview:
- is not inspiration only
- must not be modified
- must not be regenerated for tutorial use
- remains visible as the target reference

Final step:

```text
FINAL LOOK
[existing canonical premium final preview]
```

No new final image.

## 6. Strict No-Makeup Guideline Rule

Guideline images teach placement only.

Foundation:
- coverage zones
- blending direction
- NO visible applied foundation

Concealer:
- placement zones
- tap/blend direction
- NO visible concealer result

Blush:
- cheek zones
- blend direction
- NO finished blush appearance

Contour:
- cheek/temple/jaw guidance
- NO finished contour

Eyeshadow:
- lid/crease/outer-zone guidance
- NO finished eyeshadow

Eyeliner:
- path/wing direction
- NO finished eyeliner

Lips:
- coverage/outline guidance
- NO finished lipstick

Allowed guideline graphics:
- translucent zones
- arrows
- paths
- soft bands
- minimal markers

Forbidden:
- finished makeup appearance
- unrelated category guidance
- beautification
- retouching
- intentional facial alteration
- generated tutorial typography relied on for correctness

## 7. Independent Steps

Correct:

```text
Original Selfie + Step 1 Spec + Canonical Final → Step 1 Guideline
Original Selfie + Step 2 Spec + Canonical Final → Step 2 Guideline
Original Selfie + Step 3 Spec + Canonical Final → Step 3 Guideline
```

Forbidden:

```text
Step 1 Guideline → Step 2 Guideline → Step 3 Guideline
```

Guideline images are terminal instructional assets, not AI inputs.

## 8. One Master Tutorial Planner

Generate ONE complete tutorial plan first.

Inputs:

```text
Face Analysis
+ Selected Look
+ Persisted Recommendation
+ Canonical Final Preview
+ Source Mode
+ Owned Kit Products when applicable
```

Output:

`FULL VALIDATED TUTORIAL PLAN`

Persist it before guideline generation.

Individual guideline calls are not allowed to invent different:
- placement
- direction
- intensity
- product
- technique
- rationale

## 9. Canonical Step Spec

Conceptual structure:

```text
TutorialV3StepSpec
{
  stepIndex
  category
  sourceMode
  selectedStyle

  productId?
  productName?
  shadeName?
  colorHex?
  finish?

  coverage?
  intensity?

  whereToApply
  direction
  technique
  amount?
  toolSuggestion?
  personalizedTip?
  avoid?

  relevantFaceAttributes
  faceRationale
  targetRationale
  targetLookCues

  guidelineVisualIntent

  targetReferenceMode
  isFinalLook
  planVersion
}
```

Exact code names may differ.

Invariant:

```text
WRITTEN INSTRUCTION
=
GUIDELINE INTENT
=
SELECTED LOOK
=
CANONICAL TARGET
```

## 10. Dynamic Step Count

No fixed number of steps.

Natural may have fewer.
Soft Glam may have more.
Full Glam may have more still.

Rules:
- Final Look always last
- Foundation early when present
- Lip Gloss after lip color when both exist
- irrelevant/missing categories may be omitted
- Kit mode may omit unavailable categories
- never add filler steps

`total_steps` must equal persisted plan length.

## 11. Two-Level Personalization

### Selected Look controls
- category inclusion
- intensity
- finish
- coverage
- placement style
- technique
- aesthetic target

### Face Attributes control
how that selected look should be applied to this person.

Example:

```text
Soft Glam + Round Face
→ potentially higher/lifted blush placement

Soft Glam + Long Face
→ potentially more horizontal blush placement
```

Same look, different personalized application.

## 12. Category-Specific Attributes

Preferred primary relevance:

| Category | Attributes |
|---|---|
| Foundation | skin tone, undertone, selected look |
| Concealer | eye shape, skin tone, selected look |
| Contour/Bronzer | face shape, selected look |
| Blush | face shape, selected look |
| Highlighter | face shape, selected look |
| Brows | brow/face context if available, selected look |
| Eyeshadow | eye shape, selected look |
| Eyeliner | eye shape, selected look |
| Lip Color/Gloss | lip shape, selected look |

Do not flood every prompt with irrelevant attributes.

## 13. My Makeup Kit

Kit mode must:
- use existing persisted Kit recommendation
- use only owned validated selected products
- permit incomplete kits
- never invent missing products
- persist product snapshots
- avoid rerunning product selection inside tutorial logic
- omit unavailable categories when appropriate

Do not rewrite core My Makeup Kit behavior.

## 14. Guideline Prompt Philosophy

For every guideline generation:

> Preserve the original selfie and identity. Do not apply makeup. Do not retouch skin. Do not beautify. Do not intentionally alter lighting or facial features. Add only the instructional zones, arrows, paths, or markers required by the persisted Step Spec for the CURRENT category.

> The canonical final preview is an unmodified target reference. Use it only to understand the intended placement/style of the current category. Do not copy the finished makeup onto the selfie.

> Visualize the persisted Step Spec. Do not invent a different instruction.

## 15. No AI Typography

Critical text is rendered by Flutter.

AI guideline images should focus on:
- zones
- arrows
- paths
- markers

Flutter renders:
- Apply
- Where
- Direction
- Technique
- Why this placement
- Tip
- Step number
- Product/shade

Do not make correctness depend on AI-rendered words.

## 16. Target Reference UI

Preferred step UI:

```text
STEP 4 OF 8
BLUSH

[ LARGE PERSONALIZED GUIDELINE IMAGE ]

TARGET LOOK
[ exact canonical final preview thumbnail / expandable reference ]

APPLY
Soft rose blush

WHERE
Upper outer cheeks

DIRECTION
Upward toward temples

TECHNIQUE
Soft circular blending

WHY THIS PLACEMENT
Helps create lift for your face shape.

TIP
...

← Previous                         Next →
```

There is no Guidelines ↔ Result slider because there are no intermediate Results.

## 17. Category-Specific Target Reference

Desirable later, not required for MVP.

Examples:
- blush → cheek-focused target
- eyeshadow → eye-focused target
- lips → lip-focused target

Strict rule:
- never ask AI to redraw the target crop
- derive any crop from the actual canonical final preview
- use full canonical preview until a reliable non-generative crop method exists
- do not recreate V1 geometry complexity merely for thumbnails

## 18. Hybrid Generation Strategy

At tutorial start:

1. validate source/ownership
2. generate complete plan
3. validate + persist all Step Specs
4. show text/tutorial shell
5. generate current guideline
6. pre-generate NEXT guideline only
7. persist/cache completed guidelines
8. revisiting uses cache
9. final step requires no generation

Default prefetch depth = 1.

## 19. Persistence Isolation

Do not silently reuse V1/V2 tutorial schema.

Inspect remote state first.

Prefer V3-specific objects such as:

```text
tutorial_v3_sessions
tutorial_v3_steps
tutorial_v3_assets
```

V3 session persists:
- owner
- analysis
- recommendation / Kit recommendation
- source mode
- selected look
- canonical final preview
- total steps
- plan version
- status

V3 step persists:
- step index
- category
- validated Step Spec
- product snapshot if applicable
- guideline status
- guideline asset reference
- retry/error metadata

RLS and server ownership checks are mandatory.

## 20. Versioning

V3 plans must be versioned, e.g. `plan_version = 3`.

V3 must not silently interpret V1/V2 rows as V3.

Do not rewrite historical V1/V2 data.

## 21. Requested Guideline Model

Requested model:

`gemini-3.6-flash`

This is the desired V3 guideline model, but implementation MUST pass a capability gate.

Before hardcoding, verify the current project/API can actually do:

```text
source image(s) IN
+ instruction IN
→ image bytes OUT
```

Do not confuse this with:

```text
image IN
→ text/JSON OUT
```

If `gemini-3.6-flash` cannot return image output for this workflow:

**STOP AND REPORT THE EXACT INCOMPATIBILITY.**

Do not silently substitute another model.

Expose the model server-side:

`TUTORIAL_V3_GUIDELINE_MODEL`

A future model change must not require rewriting Flutter/domain/repository/persistence/planner/Kit logic.

## 22. Planner vs Guideline Model

Planner responsibility:

```text
face analysis + look + recommendation + canonical target
→ validated structured plan
```

Guideline responsibility:

```text
original selfie + canonical target + persisted Step Spec
→ guideline image
```

Keep them architecturally separate.

## 23. Validation

Planner output must be validated for:
- category vocabulary
- step order
- dynamic count
- selected look
- product ownership
- required fields
- final step
- plan version
- category-specific attribute relevance

Guideline responses must validate:
- response shape
- image bytes
- MIME type
- decodability
- size
- correct session/step
- safe storage destination

Use bounded retries only.

## 24. Failure Behavior

If guideline generation fails:
- keep Step Spec
- mark failure
- allow bounded retry
- do not fake static arrows
- do not show original selfie as “successful guideline”
- do not use another step/user's asset

A missing guideline is better than a confidently wrong one.

## 25. Storage

Never overwrite original selfie or canonical preview.

Prefer:

```text
{userId}/analyses/{analysisId}/tutorial-v3/{sessionId}/
  step_0001_guideline.png
```

Use actual repository conventions found during audit.

Storage remains private.

## 26. Idempotency

Persist states such as:

```text
pending
generating
ready
failed
```

Reuse ready assets.

Prevent duplicate concurrent generation for the same `(sessionId, stepIndex)`.

## 27. Device QA

Automated tests do not prove visual usefulness.

Test:
- Foundation
- Concealer
- Contour/Bronzer
- Blush
- Eyeshadow
- Eyeliner
- Lip Color

For each guideline verify:
1. identity remains recognizable
2. no finished makeup appearance is added
3. only current category is taught
4. placement makes cosmetic sense
5. image matches persisted Step Spec
6. face personalization makes sense
7. selected-look personalization makes sense
8. connection to canonical target is clear
9. arrows/zones are understandable
10. no AI typography is required

## 28. Acceptance Criteria

V3 is successful when:
- one full dynamic plan is persisted
- selected look + recommendation drive every step
- face attributes alter instructions appropriately
- Kit mode uses only owned selected products
- every guideline starts from original selfie
- no intermediate makeup Results exist
- no previous guideline becomes an AI input
- guideline image matches Step Spec
- canonical target remains visible
- Flutter text is deterministic from Step Spec
- final screen reuses exact premium final preview
- RLS/storage/security remain intact
- automated + physical-device QA pass
- stable FaceTune/My Makeup Kit do not regress

## 29. Forbidden Fixes

Never:
- reintroduce cumulative makeup generation
- feed previous guidelines into later steps
- hardcode universal placement
- generate generic instructions disconnected from target
- let each guideline call invent different instructions
- generate a new final look
- depend on AI typography
- fake personalization
- disable validation/RLS
- make storage public
- expose secrets
- weaken Kit rules
- modify premium preview without evidence
- introduce MediaPipe/OpenCV/TFLite/AR without explicit approval
- update unrelated packages during feature phases

## 30. Execution Rule

A complete V3 phase prompt authorizes THAT phase only.

Claude Code must:
1. read this file
2. inspect current repo
3. verify branch/status
4. execute only requested phase
5. run relevant tests
6. report files/architecture/tests/risks/status
7. STOP

Do not automatically proceed to the next phase.

## 31. Definition of Success

> A user selects a FaceTune makeup look and receives a dynamic, face-personalized tutorial where every step shows a clear guideline visualization on the original selfie, explains exactly what to apply and how, keeps the exact canonical final look visible as the destination, and never generates intermediate makeup appearances that can drift away from the selected result.
