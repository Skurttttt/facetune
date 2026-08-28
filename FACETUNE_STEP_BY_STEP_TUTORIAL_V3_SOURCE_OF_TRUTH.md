# FaceTune Step-by-Step Tutorial V3 — Source of Truth

**Status:** Authoritative V3 specification — deterministic personalized geometry renderer architecture  
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
- AI-generated replacement selfie for tutorial steps

Every non-final step displays the **original selfie unchanged** with a **personalized deterministic guideline overlay** rendered by Flutter.

Core flow:

```text
USER SELFIE
+ FACE ANALYSIS
+ SELECTED LOOK
+ PERSISTED RECOMMENDATION
+ CANONICAL FINAL PREVIEW
        ↓
MASTER TUTORIAL PLANNER
        ↓
VALIDATED + PERSISTED PERSONALIZED STEP SPEC
        ↓
ORIGINAL SELFIE
+ CURRENT STEP SPEC
+ SCOPED RELEVANT FACE ATTRIBUTES
        ↓
AI GEOMETRY MAPPER
        ↓
VALIDATED NORMALIZED GEOMETRY JSON
        ↓
FLUTTER DETERMINISTIC OVERLAY RENDERER
        ↓
ORIGINAL JPG + TRANSPARENT PERSONALIZED GUIDELINE OVERLAY
```

The original selfie pixels remain authoritative and immutable.

The geometry mapper never returns a replacement face image.

A previous guideline overlay must NEVER become an AI input for the next step.

This removes recursive visual drift and generative surface corruption by design.

## 2. Product Goal

The tutorial must teach the user:

- WHAT to apply
- WHERE to apply it
- DIRECTION
- TECHNIQUE
- INTENSITY / COVERAGE
- WHY that placement suits their face
- how the step contributes to the exact selected final look

The tutorial must be dynamic and personalized. It is not a generic makeup course and it must not reduce to one static overlay template per category.

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

Required AI architecture:

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
- use `service_role` from Flutter
- print, log, echo, or persist privileged credentials in test output

Use:

`npx -y supabase ...`

not bare `supabase`.

### Open security release blocker

The previously exposed legacy Supabase `service_role` credential remains an **OPEN HIGH-PRIORITY SECURITY ITEM** until it is migrated/revoked. It grants RLS-bypass privileges.

This does not change renderer feasibility results, but production/release is blocked until credential remediation is complete and verified without exposing secret values.

## 5. Canonical Final Look

The existing premium final preview is the exact tutorial destination.

Every step must answer:

> How should THIS user apply THIS category to reproduce THIS exact selected final look?

The canonical final preview:
- is not inspiration only
- must not be modified
- must not be regenerated for tutorial use
- remains visible as the target reference
- is an input to the **Master Tutorial Planner**
- is **NOT** sent to the geometry mapper

Final step:

```text
FINAL LOOK
[existing canonical premium final preview]
```

No new final image.

## 6. Strict No-Makeup Guideline Rule

Guideline overlays teach placement only.

Foundation:
- coverage regions
- eye/lip exclusions when required
- blending direction
- NO visible applied foundation

Concealer:
- placement regions
- tap/blend direction
- NO visible concealer result

Blush:
- personalized cheek regions
- blend direction
- NO finished blush appearance

Contour/Bronzer:
- cheek/temple/jaw guidance
- NO finished contour/bronzer appearance

Highlighter:
- localized highlight bands/regions
- NO finished highlighter appearance

Eyeshadow:
- lid/crease/outer-zone guidance
- NO finished eyeshadow appearance

Eyebrow:
- brow application/stroke paths
- NO finished brow fill

Eyeliner:
- path/wing direction
- NO finished eyeliner

Lip Color:
- lip boundary/coverage guidance
- NO finished lipstick

Lip Gloss:
- lip application region/path
- NO finished glossy lip appearance

Allowed visual primitives:
- translucent regions
- ellipses
- arrows
- polylines/paths
- soft bands produced deterministically by Flutter
- minimal markers
- explicit exclusion regions

Forbidden:
- AI-generated replacement face image
- finished makeup appearance
- unrelated category guidance
- beautification
- retouching
- intentional facial alteration
- generated tutorial typography relied on for correctness
- AI-controlled colors/opacities/fonts/gradients/blend modes

## 7. Independent Steps

Correct:

```text
Original Selfie + Step 1 Spec + Scoped Attributes → Step 1 Geometry
Original Selfie + Step 2 Spec + Scoped Attributes → Step 2 Geometry
Original Selfie + Step 3 Spec + Scoped Attributes → Step 3 Geometry
```

The canonical final preview influences these steps **through the persisted Step Specs created by the Master Planner**, not by being sent directly to the geometry mapper.

Forbidden:

```text
Step 1 Geometry → Step 2 Geometry → Step 3 Geometry
Step 1 Composite Image → Step 2 AI Input
```

Guideline geometry is a terminal instructional artifact for the current step, not an AI input to later steps.

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

Persist it before geometry mapping.

Individual geometry calls are not allowed to invent different:
- placement
- direction
- intensity
- product
- technique
- rationale
- selected look

The planner is the makeup decision-maker.

The geometry mapper is only a spatial translator.

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
GUIDELINE VISUAL INTENT
=
SELECTED LOOK
=
CANONICAL TARGET
```

The geometry mapper must not reinterpret this invariant. It receives the minimum sufficient subset needed to place the already-decided instruction on the actual face image.

## 10. Dynamic Step Count

No fixed number of steps.

Natural may have fewer.
Soft Glam may have more.
Full Glam may have more still.

Rules:
- Final Look always last
- Foundation early when present
- Lip Gloss after Lip Color when both exist
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

This personalization is encoded by the planner into the persisted Step Spec.

The geometry mapper must produce different geometry when different valid Step Specs require different placement. It must not use one static coordinate template per category.

## 12. Category-Specific Attributes

Preferred primary relevance:

| Category | Attributes |
|---|---|
| Foundation | skin tone, undertone, selected look |
| Concealer | eye shape, skin tone, selected look |
| Contour/Bronzer | face shape, selected look |
| Blush | face shape, selected look |
| Highlighter | face shape, selected look |
| Eyebrow | brow/face context if available, selected look |
| Eyeshadow | eye shape, selected look |
| Eyeliner | eye shape, selected look |
| Lip Color/Gloss | lip shape, selected look |

Do not flood every geometry request with irrelevant attributes.

The mapper receives only relevant scoped attributes plus the authoritative current Step Spec.

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

## 14. Geometry Mapper Philosophy

For every non-final step, the geometry mapper must follow this intent:

> You are a spatial geometry mapper, not a makeup artist. The makeup decision has already been made and persisted in the current Step Spec. Locate that exact instruction on the supplied original selfie and return only normalized structured geometry. Do not redesign the makeup, do not choose a different placement, and do not output an image.

> The original selfie defines the coordinate space. Return geometry for the CURRENT category only. The Step Spec is authoritative. Relevant face attributes may help locate facial regions but may not override or reinterpret the Step Spec.

> Return strict structured data only. Do not return prose, SVG, HTML, Flutter code, image bytes, colors, opacity, typography, or arbitrary styling.

The canonical final preview is **not** part of the geometry request.

## 15. No AI Typography and No AI Styling

Critical text is rendered by Flutter.

AI geometry output contains only:
- normalized coordinates
- primitive kind
- semantic role
- geometry parameters required by the schema

Flutter renders:
- Apply
- Where
- Direction
- Technique
- Why this placement
- Tip
- Step number
- Product/shade

The model must not control:
- color
- hex/RGB
- opacity
- stroke width
- font
- text labels
- shadow
- gradient
- animation
- blend mode

Do not make correctness depend on AI-rendered words or AI-selected visual style.

## 16. Target Reference UI

Preferred step UI:

```text
STEP 4 OF 8
BLUSH

[ ORIGINAL SELFIE + PERSONALIZED FLUTTER GUIDELINE OVERLAY ]

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
- blush → cheek-focused canonical view
- eyeshadow → eye-focused canonical view
- lips → lip-focused canonical view

Strict rule:
- never ask AI to redraw the target crop
- derive any crop from the actual canonical final preview
- use full canonical preview until a reliable non-generative crop method exists
- target crops affect UI/reference only, not geometry-mapper image inputs

## 18. Geometry Contract

Geometry uses normalized original-image coordinates:

```text
x ∈ [0.0, 1.0]
y ∈ [0.0, 1.0]
origin = top-left
```

Required top-level contract conceptually:

```json
{
  "version": 1,
  "category": "blush",
  "coordinateSpace": "normalized_original_image",
  "primitives": []
}
```

Approved primitive families:
- `region`
- `ellipse`
- `polyline`
- `arrow`
- `marker`

Approved semantic roles include:
- `coverage_zone`
- `placement_zone`
- `application_path`
- `blend_direction`
- `boundary`
- `exclusion`
- `focus_marker`

Exact names may differ if the implemented domain uses safer conventions, but the architecture must remain strict and discriminated.

## 19. Geometry Validation

Treat Gemini output as untrusted input.

Reject geometry when:
- version unsupported
- category mismatches current Step Spec
- coordinate space incorrect
- primitive kind unknown
- semantic role unknown
- coordinate is NaN/infinite
- coordinate outside `[0,1]`
- primitive count exceeds strict bound
- total point count exceeds strict bound
- region malformed
- polygon too small
- ellipse radius invalid
- arrow zero-length
- path absurdly long or malformed
- unsupported category/primitive combination
- unknown styling/text/code fields appear

Do not silently clamp invalid AI coordinates.

Invalid model output must fail validation and use bounded retry/failure behavior.

## 20. Category-to-Primitive Rules

Define explicit allowed primitive families by canonical category.

Examples:

Foundation:
- region
- arrow
- marker/exclusion where justified

Concealer:
- region or ellipse
- arrow
- marker for targeted spots where Step Spec requires them

Blush:
- ellipse or region
- arrow

Highlighter:
- region or polyline
- marker where justified

Eyeshadow:
- region
- polyline
- arrow

Lip Color:
- polyline
- region
- arrow

Lip Gloss:
- region
- polyline
- marker/arrow where justified

Contour/Bronzer:
- region
- polyline
- arrow

Eyebrow:
- polyline
- arrow
- marker

Eyeliner:
- polyline
- arrow
- marker

Inspect actual category requirements before locking exact combinations.

## 21. Flutter Deterministic Renderer

Render overlays using native Flutter, preferably `CustomPainter` or an equally deterministic mechanism.

Conceptually:

```text
Stack
├── Image(originalSelfie)
└── CustomPaint(validatedGuidelineGeometry)
```

The renderer must never:
- rewrite selfie bytes
- save over the selfie
- ask Gemini for a replacement selfie
- flatten into the original source file
- depend on SVG/HTML generated by Gemini

For temporary QA evidence, a composite screenshot/export may be produced separately, but the source image bytes remain unchanged.

## 22. Image-Space Transform

Normalized geometry refers to the ORIGINAL IMAGE coordinate space.

Flutter must correctly map it into the actual displayed image rectangle under:
- `BoxFit.contain`
- `BoxFit.cover` if used
- alignment
- letterboxing
- cropping
- device-size differences

Use tested Flutter image-fit math such as `applyBoxFit` and `Alignment.inscribe` or an equivalent proven transform.

Do not assume the image fills the widget.

Inspect actual selfie orientation/mirroring behavior. Do not invent transforms.

## 23. Hybrid Geometry Strategy

At tutorial start:

1. validate source/ownership
2. generate/load complete plan
3. validate + persist all Step Specs
4. show text/tutorial shell
5. map/generate geometry for current step
6. validate/persist/cache geometry
7. prefetch NEXT step geometry only
8. revisiting uses cached validated geometry
9. final step requires no geometry-mapping call

Default prefetch depth = 1.

No image generation occurs for non-final tutorial guidelines.

## 24. Persistence Isolation

Do not silently reuse V1/V2 tutorial schema.

Inspect current remote state first.

Existing V3 objects may include:

```text
tutorial_v3_sessions
tutorial_v3_steps
```

Production geometry persistence should store a validated geometry snapshot/reference associated with the analysis/session/step.

Do not assume the old `guideline asset path` representation remains sufficient.

Before schema changes, inspect current V3 migration/state and design the smallest backward-safe V3-specific evolution.

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
- geometry status
- validated geometry payload/version or safe reference
- retry/error metadata

RLS and server ownership checks are mandatory.

## 25. Versioning

V3 plans must be versioned, e.g. `plan_version = 3` unless current implementation already uses a specific compatible value.

Geometry must also have its own explicit schema/version.

V3 must not silently interpret V1/V2 rows as V3.

Do not rewrite historical V1/V2 data.

## 26. Model Responsibilities

### Planner model

Server-configurable, currently:

`TUTORIAL_V3_PLANNER_MODEL = gemini-3.6-flash`

Responsibility:

```text
face analysis + selected look + recommendation + canonical final preview
→ validated personalized structured plan
```

### Geometry model

Server-configurable:

`TUTORIAL_V3_GEOMETRY_MODEL = gemini-3.6-flash`

Responsibility:

```text
original selfie + persisted Step Spec + scoped face attributes
→ strict normalized geometry JSON
```

The geometry model returns **text/JSON structured output, not image bytes**.

### Premium final preview model

Remains separate and unchanged.

Do not use tutorial geometry work to modify `GEMINI_IMAGE_MODEL` or the premium preview pipeline.

## 27. Historical Renderer Decisions

The following experiments are authoritative evidence and must not be casually resurrected:

### V3-6A.1 — Two-image generative guideline renderer

```text
Original Selfie
+ Canonical Final Preview
+ Step Spec
→ AI-generated guideline image
```

Result: **REJECTED**.

Observed repeated cross-category makeup/style transfer from the canonical target despite three prompt variants.

### V3-6A.2 — Single-image generative guideline renderer

```text
Original Selfie
+ Step Spec
→ AI-generated guideline image
```

Result: **REJECTED**.

Cross-category transfer disappeared, but region-fill annotation altered the facial surface: foundation lightened/repainted skin and lip guidance recolored/desaturated lips despite explicit prohibitions.

Blush geometry improved when Step Spec wording became spatially explicit, and eyeliner path behavior was strong. These findings support geometry mapping, not full-image regeneration.

### Current decision

```text
AI decides/returns WHERE as validated geometry.
Flutter draws HOW it looks.
Original selfie remains untouched.
```

Do not create V3-6A.3 or continue generative-image prompt tuning without explicit architectural approval.

## 28. Failure Behavior

If geometry mapping fails:
- keep the persisted Step Spec
- mark geometry failure
- allow bounded retry
- do not substitute a universal static overlay
- do not display the original selfie alone as a “successful guideline”
- do not use another step/user's geometry
- do not fall back to AI-generated replacement images

A missing guideline is better than a confidently wrong one.

Dynamic deterministic Flutter overlays are **not** “fake static arrows.”

Forbidden static behavior means reusing universal coordinates disconnected from the current user/Step Spec.

Required behavior means personalized geometry is generated from the current selfie + authoritative Step Spec and then rendered deterministically.

## 29. Storage and Data Lifecycle

Never overwrite original selfie or canonical preview.

Geometry is small structured data and should not require one generated JPG per tutorial step.

Production may persist validated geometry in database JSON or another V3-specific safe structure after schema review.

If QA composite screenshots are created, treat them as disposable/non-authoritative evidence unless explicitly designed as a product cache.

History deletion must still remove any analysis-owned tutorial data/assets under the existing deletion lifecycle.

Private storage remains private.

## 30. Idempotency

Persist/derive states such as:

```text
pending
mapping
ready
failed
```

Reuse ready geometry when compatible.

Prevent duplicate concurrent mapping for the same `(sessionId, stepIndex, geometryVersion)`.

A ready geometry payload must be deterministic input to Flutter rendering.

## 31. Full Category Coverage

The canonical makeup catalog must remain aligned with the actual project codes.

Current product categories include:
- Foundation
- Concealer
- Blush
- Highlighter
- Eyeshadow
- Lipstick / Lip Color
- Lip Gloss
- Contour / Bronzer
- Eyebrow
- Eyeliner

Do not permanently rename or fork category codes inside V3.

The geometry architecture must represent all canonical categories before final acceptance.

## 32. Device QA

Automated tests do not prove visual usefulness.

Test all canonical categories.

For each guideline verify:
1. original selfie underneath is unchanged
2. only current category is taught
3. placement matches persisted Step Spec
4. face personalization makes sense
5. selected-look personalization remains encoded by the Step Spec
6. connection to canonical target is clear in tutorial context
7. zones/arrows/paths are understandable
8. no AI typography is required
9. overlay is visually instructional, not cosmetic-looking
10. no clipping/coordinate drift/BoxFit misalignment occurs

Also test personalization differentials:
- same look + different face attributes → appropriately different Step Specs/geometry
- same user + different selected look → appropriately different Step Specs/geometry

Do not fake differential behavior with random coordinate offsets.

## 33. Acceptance Criteria

V3 is successful when:
- one full dynamic plan is persisted
- selected look + recommendation drive every step
- face attributes alter instructions appropriately
- Kit mode uses only owned selected products
- every non-final guideline uses the original selfie unchanged
- no intermediate makeup Results exist
- no previous guideline becomes an AI input
- geometry matches the persisted Step Spec
- geometry is personalized rather than universal/static
- Flutter renders the overlay deterministically
- canonical target remains visible in the tutorial UI
- Flutter text is deterministic from Step Spec
- final screen reuses exact premium final preview
- RLS/security remain intact
- original image hash/pixels remain unchanged
- automated + physical-device QA pass
- all canonical categories are representable
- stable FaceTune/My Makeup Kit do not regress
- exposed legacy `service_role` remediation is complete before production/release

## 34. Forbidden Fixes

Never:
- reintroduce cumulative makeup generation
- feed previous guidelines into later steps
- reintroduce AI-generated replacement guideline selfies without explicit architecture approval
- send canonical final preview to geometry mapper
- hardcode universal placement coordinates
- generate generic instructions disconnected from target
- let geometry mapping invent different makeup instructions
- generate a new final look
- depend on AI typography
- allow AI to control overlay styling
- accept free-form SVG/HTML/code from Gemini
- silently clamp invalid geometry
- fake personalization
- disable validation/RLS
- make storage public
- expose secrets
- weaken Kit rules
- modify premium preview without evidence
- introduce MediaPipe/OpenCV/TFLite/AR without explicit approval
- update unrelated packages during feature phases
- automatically continue to the next phase

## 35. Execution Rule

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

## 36. Definition of Success

> A user selects a FaceTune makeup look and receives a dynamic, face-personalized tutorial where every step uses the unchanged original selfie with a precise personalized guideline overlay derived from the authoritative Step Spec, explains exactly what to apply and how, keeps the exact canonical final look visible as the destination, and never generates intermediate makeup appearances that can drift away from the selected result.
