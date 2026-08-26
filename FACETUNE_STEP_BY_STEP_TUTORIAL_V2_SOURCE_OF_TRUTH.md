# FaceTune Step-by-Step Tutorial V2 — Source of Truth

**Status:** Authoritative V2 product + engineering specification  
**Target branch:** `feature/step-by-step-tutorial-v2`  
**Primary implementation agent:** Claude Code using Opus 5  
**App:** FaceTune — “Your AI Makeup Artist”  
**Stack:** Flutter + Dart + Riverpod + Clean Architecture + Supabase + Gemini via authenticated Supabase Edge Functions

---

# 0. Purpose

This document defines the new Step-by-Step Tutorial V2 for FaceTune.

V2 is a clean restart of the tutorial feature. It must preserve the stable FaceTune + My Makeup Kit system and must not recreate the V1 architecture merely with different prompts.

The user experience V2 must deliver is:

> Teach the user how to recreate the exact AI-generated makeup look they already selected, using personalized instructions, personalized visual placement guidelines, and a cumulative visual result after each step.

V2 must be dynamic. The tutorial must depend on:

1. the user's actual face attributes,
2. the selected makeup look,
3. the actual persisted makeup recommendation,
4. the canonical final AI makeup preview,
5. the user's owned products when My Makeup Kit mode is active.

The tutorial must never become a generic makeup course.

---

# 1. Protected Baseline

The clean restart point is the stable FaceTune + My Makeup Kit state on `main`.

The V2 implementation branch is:

`feature/step-by-step-tutorial-v2`

Never develop directly on `main`.

The previous V1 implementation is preserved on:

`feature/step-by-step-tutorial`

V1 is reference material only. Do not merge V1 wholesale into V2.

Before every implementation phase:

```bash
git status
git branch --show-current
```

Expected branch:

```text
feature/step-by-step-tutorial-v2
```

If the branch is not exactly the expected branch, STOP.

Do not:

- reset `main`
- force push
- delete branches
- rewrite Git history
- merge V1 into V2 wholesale
- discard unrelated work
- modify the V1 branch
- develop directly on `main`

---

# 2. Existing Systems That Must Remain Protected

V2 must preserve existing working FaceTune behavior.

Protected systems include:

- Authentication
- Home
- Capture / Upload Selfie
- Image Validation
- Gemini Face Analysis
- Makeup Style Selection
- Makeup Recommendation
- Premium AI Makeup Preview
- Result / History
- My Makeup Kit
- Kit recommendation
- Kit preview
- private Supabase storage
- RLS
- ownership validation
- existing Gemini key security

Do not casually modify the premium final-preview pipeline.

The existing premium final preview is the canonical final target for the tutorial.

---

# 3. Security Rules

Gemini API keys must never be exposed in Flutter, APK, logs, screenshots, generated docs, tests, or client-visible payloads.

Required AI architecture:

```text
Flutter
→ authenticated Supabase Edge Function
→ Gemini API
```

The project already has a server-side Gemini secret.

Never ask the user to reveal or paste the Gemini API key.

Never:

- disable RLS
- make a private bucket public to solve rendering
- trust client-supplied ownership
- overwrite the original selfie
- bypass server ownership validation
- store secrets in Dart source
- send service-role secrets to the client

Global Supabase CLI is not installed.

Always use:

```bash
npx -y supabase ...
```

not bare:

```bash
supabase ...
```

unless the environment is explicitly changed later.

---

# 4. Product Goal

The Step-by-Step Tutorial must accomplish all of the following:

- Teach the user how to recreate the selected AI-generated makeup look.
- Show the user where each makeup category/product should be applied.
- Show how the face should look after every makeup step.
- Teach makeup techniques personalized to the user's facial attributes.
- Progressively converge toward the exact selected final makeup preview.
- Never invent an unrelated makeup interpretation.

The user must be able to understand:

- WHAT to apply
- WHERE to apply it
- HOW to apply it
- WHICH DIRECTION to blend or draw
- HOW MUCH / what intensity to use
- WHAT the face should look like after the step

---

# 5. Canonical Tutorial Progression

Conceptual progression:

```text
Original Selfie
↓
Foundation Result
↓
Concealer Result
↓
Contour/Bronzer Result
↓
Blush Result
↓
Highlighter Result
↓
Brows Result
↓
Eyeshadow Result
↓
Eyeliner Result
↓
Lip Color Result
↓
Lip Gloss Result
↓
Canonical Final Look
```

This is NOT a fixed 11-step tutorial.

Categories are dynamic.

Examples:

```text
Natural Look
→ fewer steps

Soft Glam
→ medium number of steps

Full Glam
→ more steps
```

The planner determines the required categories from the actual selected look and recommendation.

Rules:

- Final Look is always last.
- Foundation, when present, appears early.
- Concealer follows an appropriate base step.
- Lip Gloss, when present with lip color, follows lip color.
- Missing or irrelevant categories may be omitted.
- My Makeup Kit mode may omit categories the user does not own if the recommendation cannot validly use them.
- The tutorial must not manufacture filler steps merely to reach a fixed count.

---

# 6. Canonical Final Target Rule

Every tutorial step must work toward the exact existing canonical final makeup preview.

The canonical final preview is not inspiration.

It is the target.

Strict rule:

> The AI is reconstructing the already-selected canonical final makeup target one category at a time.

Never ask the AI to:

- create a new makeup look
- reinterpret the selected style
- beautify unrelated facial areas
- change hair
- change face shape
- alter identity
- alter skin tone globally
- redesign eye makeup during a blush step
- redesign lips during an eyeliner step
- produce a second independent final look

The final tutorial step MUST reuse the existing canonical premium final preview.

Do not generate another “final” image.

---

# 7. Single Source of Truth Per Step

Every step must be driven by one shared persisted step specification.

Do not allow the written instructions, guideline visual, and result-generation prompt to independently invent placement or technique.

Conceptual model:

```text
TutorialV2StepSpec
{
  stepIndex
  category
  sourceMode

  faceAttributes
  selectedStyle

  recommendationId
  productId?
  productName?
  shadeName?
  colorHex?
  finish?

  whatToApply
  whereToApply
  direction
  technique
  intensity
  amount?
  toolSuggestion?
  personalizedTip?
  avoid?

  faceRationale
  targetLookCues

  previouslyCompletedCategories
  currentCategory
  cumulativeCategories

  guidelineInstruction
  resultInstruction

  planVersion
}
```

Exact implementation names may differ.

Core invariant:

```text
WRITTEN INSTRUCTION
=
GUIDELINE INTENT
=
RESULT GENERATION INTENT
=
CANONICAL TARGET
```

If these disagree, the implementation is wrong.

---

# 8. Personalization Inputs

The tutorial planner must use the existing Face Analysis attributes where relevant.

Known attributes include:

- face shape
- skin tone
- undertone
- eye shape
- lip shape
- hair color
- eye color

Examples of personalization:

- Blush placement may differ by face shape.
- Contour direction may differ by face shape.
- Eyeshadow placement may differ by eye shape.
- Eyeliner direction may differ by eye shape.
- Lip technique may differ by lip shape.
- Shade and intensity should respect the recommendation and canonical target.

The planner must explain the relevant face-based rationale internally/persistently so later debugging can answer:

> Why did this user receive this placement instruction?

Do not expose overly technical rationale to the user unless useful.

---

# 9. Selected Look Is Mandatory Context

The persisted selected style/look must reach:

- tutorial planner
- step specs
- guideline-generation prompt
- result-generation prompt
- persistence
- UI display where appropriate

Never use a fake or duplicate field merely because an older implementation once did.

Use the actual persisted style field used by the stable application.

Do not invent a parallel style source.

---

# 10. My Makeup Kit Rules

My Makeup Kit behavior is protected.

When tutorial source mode is Kit:

- AI may use only products the user actually owns.
- Selected product IDs must be validated server-side.
- Incomplete kits are valid.
- Do not invent missing products.
- Persist product snapshots so saved tutorials remain historically accurate even if the user's Kit changes later.
- Product name may be optional.
- Use existing color / finish / foundation metadata where available.
- The tutorial must use the actual selected Kit recommendation, not rerun product selection independently.

If a category is not part of the valid Kit recommendation, the tutorial planner may omit that category.

Do not recommend an unowned product inside Kit mode.

---

# 11. Standard Recommendation Mode

When source mode is not Kit, V2 may use the actual persisted standard recommendation.

The tutorial must not create a separate recommendation system.

The tutorial receives the recommendation as input and teaches the user how to apply it.

---

# 12. V2 Guideline Experience

The visual reference is the instructional style of a real face with:

- clear application zones
- directional arrows
- simple visual emphasis
- concise instructions
- personalized placement
- technique-specific guidance

V2 should reproduce the instructional meaning of that style.

Do NOT require AI-generated text inside image pixels.

Preferred architecture:

```text
Guideline image
=
face/base-state image
+
visual zones/arrows for CURRENT category only

Flutter UI
=
step number
+
category
+
Apply
+
Where
+
Direction
+
Technique
+
Tip
```

This avoids unreliable AI-rendered typography while preserving the desired personalized guideline experience.

Guideline images must not become beauty-result images.

A guideline image should teach placement.

A result image should show the cumulative makeup outcome.

Those are different assets with different purposes.

---

# 13. Guideline Image Rules

For each makeup step, the guideline side should show the face at the state immediately BEFORE applying the current category.

Examples:

```text
Foundation guideline
→ original selfie + foundation placement guidance

Blush guideline
→ previous cumulative result + blush placement guidance

Eyeliner guideline
→ previous cumulative result + eyeliner placement guidance
```

Guideline generation receives:

1. identity reference: original selfie
2. base visual state: previous cumulative result, or original selfie for first step
3. canonical final preview
4. current step spec
5. relevant face attributes
6. strict current-category lock

The guideline image may show:

- semi-transparent zones
- arrows
- paths
- soft bands
- dots only when genuinely useful
- numbered visual markers if rendered reliably

The guideline image must show ONLY the current category's application guidance.

Never show:

- arrows for unrelated makeup categories
- decorative lines
- generic face outlines with no instructional purpose
- instructions disconnected from the selected final look
- misleading precision
- AI-generated text that contradicts the persisted step spec

If the guideline visual cannot be generated reliably, fail safely and use the persisted written instruction rather than showing a confidently wrong guideline.

---

# 14. Result Image Architecture

Every cumulative result should be generated using multiple anchors.

Conceptual inputs:

```text
IMAGE A
Original selfie
Role: permanent identity reference

IMAGE B
Previous cumulative tutorial result
Role: continuity reference

IMAGE C
Canonical selected final preview
Role: exact final makeup target

DATA D
Current TutorialV2StepSpec
Role: current category and technique

DATA E
Cumulative completed-category plan
Role: what should already be present
```

The previous result is NOT the sole source image.

Strict generation intent:

> Preserve identity from IMAGE A. Preserve already-completed makeup from IMAGE B. Use IMAGE C as the exact target appearance. Apply only the current category defined by the step spec. Do not change unrelated categories.

This is designed to prevent recursive drift.

---

# 15. Category Lock Rule

For a current step such as Blush:

Allowed change:

- blush only

Must preserve:

- identity
- skin tone
- foundation already completed
- concealer already completed
- contour already completed
- brows if already completed
- eye makeup if already completed
- lips if already completed

Must NOT prematurely add future categories.

The result after Step N must visually represent:

```text
all categories completed through Step N
```

and not the final look prematurely.

---

# 16. No-Drift Rule

Every step must move closer to the canonical final look.

V2 must specifically defend against:

- identity drift
- skin/exposure drift
- face-shape drift
- hair drift
- eye-shape drift
- lip-shape drift
- global beautification
- style reinterpretation
- cumulative texture degradation
- category bleed
- premature application of future categories
- mismatch between penultimate result and final canonical result

Do not solve drift merely by upgrading the model.

Fix architecture and prompting first.

---

# 17. Tutorial Generation Strategy

Use the HYBRID approach.

At tutorial start:

1. validate source records and ownership
2. create or load Tutorial V2 session
3. generate the complete personalized tutorial plan and all written step specs first
4. persist the plan
5. show the tutorial shell/text as soon as plan is ready
6. generate the current step's guideline + result assets
7. while the user views current step, pre-generate the NEXT step only
8. persist/cache completed assets
9. do not generate the entire tutorial upfront unless a deliberate future optimization proves useful
10. reuse cached completed steps when revisiting
11. final step reuses the canonical final preview

Benefits:

- lower initial wait
- lower abandoned-session cost
- less unnecessary AI generation
- smoother next-step experience
- persisted reproducibility
- easier debugging

Do not regenerate every tutorial every time the screen opens.

---

# 18. Tutorial UI

Preferred UI:

```text
STEP 4 OF 8

[ GUIDELINES ]  ← draggable slider →  [ RESULT ]

BLUSH

Apply:
Soft rose blush

Where:
Upper cheeks

Direction:
Upward toward the temples

Technique:
Soft circular blending

Tip:
Keep the strongest color toward the outer cheek.

← Previous Step                    Next Step →
```

The left side is the personalized guideline visualization.

The right side is the current cumulative result.

The slider is a comparison UI only.

Do not confuse the vertical slider divider or handle with makeup guidance.

Step text must come from the persisted step spec.

Do not generate different UI copy on every rebuild.

---

# 19. Dynamic Tutorial Length

The tutorial length must be derived from the selected look + actual recommendation.

Examples are illustrative, not hardcoded:

```text
Natural
≈ fewer steps

Soft Glam
≈ medium steps

Full Glam
≈ more steps
```

Do not hardcode:

```dart
totalSteps = 8;
```

The canonical persisted step list is the source of truth for total step count.

`session.total_steps` must equal the persisted canonical step count.

---

# 20. Persistence Strategy

Because the remote Supabase project may still contain V1 tutorial tables, V2 must not silently bind to them.

Preferred V2 isolation during development:

```text
tutorial_v2_sessions
tutorial_v2_steps
tutorial_v2_assets
```

Exact names may be adjusted only after inspecting current remote migrations.

Do not use `create table if not exists tutorial_sessions` and assume it created a new schema.

V2 persistence must include:

Session:
- id
- user_id
- analysis_id
- recommendation_id or kit recommendation id
- canonical final image reference
- source mode
- selected look
- total_steps
- plan_version
- status
- timestamps

Step:
- session_id
- step_index
- category
- persisted step spec
- product snapshot where relevant
- guideline status
- result status
- guideline asset reference
- result asset reference
- error/retry metadata
- timestamps

Assets may be a separate table or strongly typed columns depending on repository architecture.

All user-owned rows must use RLS and server ownership checks.

---

# 21. Session Versioning

V2 plans must be versioned.

Example:

```text
plan_version = 2
```

The exact representation is an implementation choice.

A V2 reader must reject or route away from incompatible V1 session data.

Do not silently reinterpret V1 rows as V2.

Do not silently rewrite old historical data.

---

# 22. AI Model Configuration

The requested tutorial model is:

```text
gemini-3.6-flash
```

However:

- Claude Code must verify the model identifier/capability in the actual integration environment before hardcoding.
- If the requested identifier is unavailable or does not support the required image workflow, STOP and report the exact incompatibility.
- Do not silently substitute a different model.
- The model must be configurable server-side.

Conceptual configuration:

```text
TUTORIAL_V2_PLANNER_MODEL
TUTORIAL_V2_GUIDELINE_MODEL
TUTORIAL_V2_RESULT_MODEL
TUTORIAL_V2_IMAGE_SIZE
```

These may initially resolve to the same model, but business logic must not depend on that.

A future model swap must not require rewriting:

- Flutter UI
- domain entities
- repositories
- persistence
- tutorial ordering
- product rules
- session state machine

---

# 23. Prompting Philosophy

Every AI call must define roles explicitly.

Planner:

> Build the personalized plan required to reconstruct the already-selected canonical final look.

Guideline generator:

> Show where and how to apply ONLY the current category on this specific face so the user can reproduce the canonical target.

Result generator:

> Reconstruct the already-selected canonical target progressively. Apply ONLY the current category while preserving identity and completed categories.

Critical phrases to enforce:

- “You are NOT creating a new makeup look.”
- “The canonical final preview is the exact target.”
- “Apply ONLY the current makeup category.”
- “Do not alter unrelated makeup categories.”
- “Do not perform unrelated beautification.”
- “Do not change identity.”
- “Do not add future tutorial categories early.”
- “Preserve previously completed categories.”
- “The written instruction and visual guideline must express the same placement intent.”

---

# 24. Planner Output Validation

Never blindly trust model JSON.

The server must validate:

- schema
- step indexes
- category vocabulary
- final step placement
- product IDs
- allowed owned products in Kit mode
- selected style presence
- required fields
- duplicate categories where forbidden
- impossible ordering
- total step count
- missing recommendation context
- unknown future category values

Invalid planner output must not be persisted as a valid tutorial.

Use bounded retries.

Do not create infinite retry loops.

---

# 25. Image Validation

Guideline and result generation must validate:

- image response exists
- expected media type
- image decodes
- file size is within bounds
- ownership/storage path is valid
- step/session ownership matches
- the generated asset is attached to the correct step

Result images must contain no:

- tutorial text
- arrows
- guide lines
- dots
- labels
- placement zones

Guideline images may contain visual guidance but should not contain critical textual instructions.

Flutter owns the critical instruction text.

---

# 26. Storage

Original selfies must never be overwritten.

Use deterministic, user-owned paths.

Conceptual structure:

```text
{userId}/analyses/{analysisId}/tutorial-v2/{sessionId}/
  step_0001_guideline.png
  step_0001_result.png
  step_0002_guideline.png
  step_0002_result.png
```

Exact naming may follow existing repository conventions.

Storage remains private where intended.

Use signed/private access patterns consistent with the stable app.

---

# 27. Retry / Idempotency

Generation must be idempotent where practical.

A retry should not create uncontrolled duplicate assets or duplicate steps.

Persist generation state:

```text
pending
generating
ready
failed
```

A step should know independently whether:

- guideline asset is ready
- result asset is ready

The UI must handle partial readiness.

---

# 28. Hybrid Prefetch State Machine

Conceptual behavior:

```text
Plan Ready
↓
Generate Step 1 assets
↓
Display Step 1
↓
Prefetch Step 2
↓
User opens Step 2
↓
Display cached Step 2 if ready
↓
Prefetch Step 3
...
```

Do not prefetch more than necessary without evidence.

Default target:

```text
current step + one next step
```

Avoid duplicate concurrent requests for the same step.

---

# 29. UI States

The tutorial must explicitly support:

- plan loading
- plan ready
- current guideline loading
- current result loading
- partial asset ready
- ready
- generation failed
- retry available
- stale/incompatible session
- network interruption
- user revisiting a cached step

Do not hide errors behind endless spinners.

---

# 30. No Fake Success

Do not claim:

- tutorial generated successfully
- guideline accurate
- target fidelity solved
- drift solved
- device behavior correct

merely because:

- unit tests pass
- JSON parses
- a widget renders
- an Edge Function returns 200

Physical-device visual QA is mandatory.

---

# 31. Visual QA Categories

Device QA must include representative steps:

- Foundation
- Concealer
- Contour/Bronzer
- Blush
- Eyeshadow
- Eyeliner
- Lip Color
- penultimate cumulative result
- final canonical result

For each representative step verify:

- guideline placement makes cosmetic sense
- guideline corresponds to written instruction
- written instruction corresponds to canonical final look
- result changes the correct category
- unrelated categories remain stable
- identity remains stable
- skin tone remains stable
- cumulative result moves closer to canonical target

---

# 32. Acceptance Criteria

V2 is not complete until all are true:

## Product
- Dynamic step count works.
- Steps are derived from selected look + recommendation.
- Instructions are personalized from face attributes.
- Kit mode uses only owned selected products.
- Final step is canonical final preview.

## Guidelines
- Guideline image teaches current category only.
- Direction/placement match the written step spec.
- Guidelines are connected to the selected final target.
- No random generic geometry.
- No unrelated-category arrows.

## Results
- Each result is cumulative.
- Current step applies the current category.
- Previous completed categories remain.
- Future categories do not appear early.
- Identity is preserved.
- Final transition does not suddenly jump to an unrelated target.

## Architecture
- Single persisted step spec drives text/guideline/result intent.
- AI keys remain server-side.
- RLS remains enabled.
- V2 session data is isolated/versioned.
- Models are server-configurable.
- Cached steps are reused.
- Final image is not regenerated.

## QA
- `flutter analyze` passes.
- automated tests pass.
- relevant Deno/Edge Function tests pass.
- physical device QA passes representative categories.
- no protected stable feature regresses.

---

# 33. Forbidden “Fixes”

Never solve V2 problems by:

- hardcoding one placement for all users
- using the same tutorial instructions for every face
- generating generic tutorial text unrelated to the selected look
- asking the result model to create a fresh style each step
- using only the previous AI result as the next identity source
- forcing confidence or pretending uncertain guidance is precise
- drawing fake static arrows just to make the UI look complete
- disabling validation
- disabling RLS
- making storage public
- exposing Gemini keys
- modifying premium final-preview behavior without evidence
- rewriting My Makeup Kit to make V2 easier
- installing MediaPipe, OpenCV, TensorFlow Lite, or real-time AR without explicit approval
- upgrading packages unrelated to the phase
- changing unrelated architecture “while we are here”
- automatically proceeding into the next phase

---

# 34. Engineering Execution Rule

A complete V2 phase prompt is explicit authorization to execute THAT phase.

Claude Code must:

1. read this source-of-truth file
2. inspect the current repository
3. verify Git branch/status
4. execute only the requested phase
5. run phase-relevant tests
6. return an implementation report
7. STOP

Do not ask:

> “Do you want me to proceed?”

when a complete phase prompt has already been supplied.

Do not automatically start the next phase.

---

# 35. Definition of Success

The Step-by-Step Tutorial V2 is successful when:

> A user can select a FaceTune makeup look, open a personalized tutorial, understand exactly what to apply and how to apply it to their own facial attributes, compare a personalized guideline visualization with the cumulative expected result for every dynamic step, and progress steadily toward the exact canonical final makeup preview without the tutorial drifting into a different face or different makeup look.

That is the product.

Everything else is implementation detail.
