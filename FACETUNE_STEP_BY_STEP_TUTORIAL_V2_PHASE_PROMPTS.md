# FaceTune Step-by-Step Tutorial V2 — Claude Code Opus 5 Phase Prompts

**Primary source of truth:** `FACETUNE_STEP_BY_STEP_TUTORIAL_V2_SOURCE_OF_TRUTH.md`  
**Required branch:** `feature/step-by-step-tutorial-v2`

---

# GLOBAL ROLE FOR EVERY PHASE

You are Claude Code using Opus 5.

For this project, act simultaneously as:

- Principal Software Engineer
- Senior Flutter Architect
- Senior Dart Engineer
- Senior Supabase/Postgres Engineer
- Senior AI Integration Engineer
- Multimodal Prompt Engineer
- Security Engineer
- QA / Test Architect
- Git Safety Engineer
- Mobile Performance Engineer
- Technical Product Engineer

Your job is not merely to make code compile.

Your job is to implement FaceTune Step-by-Step Tutorial V2 faithfully, safely, incrementally, and without damaging existing working systems.

Before every phase:

```bash
git status
git branch --show-current
```

Expected branch:

```text
feature/step-by-step-tutorial-v2
```

If not on that branch, STOP.

Read first:

```text
FACETUNE_STEP_BY_STEP_TUTORIAL_V2_SOURCE_OF_TRUTH.md
CODEX_MASTER_GUIDE.md
ARCHITECTURE_NOTES.md
```

Also inspect any current repository files relevant to the phase.

Do not rely only on old reports.

GLOBAL PROHIBITIONS:

- Never develop directly on `main`.
- Never modify `feature/step-by-step-tutorial`.
- Never reset or force push.
- Never delete branches.
- Never discard unrelated work.
- Never expose Gemini secrets.
- Never disable RLS.
- Never make private storage public.
- Never overwrite original selfies.
- Never weaken My Makeup Kit ownership validation.
- Never rewrite the premium final-preview pipeline casually.
- Never introduce MediaPipe/OpenCV/TFLite/real-time AR without explicit approval.
- Never auto-run the next phase.
- Never claim visual success without device evidence.

Supabase commands must use:

```bash
npx -y supabase ...
```

At phase completion:

1. summarize files changed
2. summarize architecture decisions
3. show tests run and results
4. list unresolved risks
5. state whether phase acceptance criteria were met
6. STOP

---

# V2-0 — Repository + Remote-State Revalidation

## Objective

Establish the exact current baseline before V2 implementation begins.

This phase is READ-ONLY except for creating/updating an audit report if needed.

## Execute

1. Verify Git branch/status.
2. Confirm V2 branch base against `main`.
3. Confirm stable FaceTune + My Makeup Kit tests remain green.
4. Inspect current Supabase migration history.
5. Inspect deployed Edge Functions.
6. Determine exact existing V1 tutorial tables/functions still present remotely.
7. Verify the actual persisted selected-style field used by the stable app.
8. Verify canonical final preview storage/persistence flow.
9. Verify standard recommendation and Kit recommendation persistence.
10. Verify original selfie source and ownership path.

Use read-only commands where appropriate:

```bash
git log --oneline --decorate --graph -n 30
git diff --stat main...HEAD
flutter analyze
flutter test
npx -y supabase migration list --linked
npx -y supabase functions list
```

## Deliverable

Create:

`docs/tutorial_v2/V2-0_BASELINE_AUDIT.md`

It must identify:

- exact V2 branch base
- clean/dirty state
- relevant schema
- existing V1 remote tutorial objects
- actual style field
- analysis/recommendation/final-preview relationships
- exact remote constraints V2 must coexist with

## Prohibitions

Do not create migrations.
Do not deploy functions.
Do not implement UI.
Do not modify stable app behavior.

## Stop

Return the audit report and STOP.

---

# V2-1 — Domain Contracts + Tutorial Plan Schema

## Objective

Create the V2 domain model and planner contract before any AI implementation.

The domain model must enforce the Source of Truth.

## Required Design

Create strongly typed V2 entities/value objects for:

- Tutorial V2 session
- Tutorial V2 plan
- Tutorial V2 step spec
- source mode
- category
- generation status
- product snapshot
- cumulative category state
- guideline instruction
- result instruction
- plan version

The shared Step Spec must contain enough information to drive:

1. written UI instruction
2. guideline generation
3. result generation

Do not create separate independent instruction systems.

## Required Rules

- dynamic step count
- final look always last
- no fixed 8/11 steps
- selected look mandatory
- face attributes available to planner
- recommendation mandatory
- Kit product rules preserved
- cumulative categories explicit
- current category explicit
- previous completed categories explicit
- final step marked as canonical reuse, not generation

## Testing

Add focused domain tests for:

- valid dynamic plans
- invalid ordering
- duplicate/future category issues
- Final Look last
- Kit product snapshot constraints
- cumulative category progression
- plan version behavior

## Prohibitions

No Supabase migration yet.
No Gemini calls yet.
No UI yet.

## Stop

Return implementation report and STOP.

---

# V2-2 — V2 Persistence + RLS Isolation

## Objective

Create isolated V2 persistence without breaking or silently reusing V1 tables.

## Precondition

Read `docs/tutorial_v2/V2-0_BASELINE_AUDIT.md`.

## Required Architecture

Prefer distinct V2 objects unless the audit proves another approach is safer.

Conceptual tables:

```text
tutorial_v2_sessions
tutorial_v2_steps
tutorial_v2_assets
```

Do not silently bind to old `tutorial_sessions` / `tutorial_steps`.

## Required Data

Session must persist:

- user ownership
- analysis reference
- recommendation or Kit recommendation reference
- source mode
- selected look
- canonical final preview reference
- total steps
- plan version
- status
- timestamps

Step must persist:

- session
- step index
- category
- serialized validated Step Spec
- product snapshot
- guideline status/reference
- result status/reference
- retry/error metadata

## Security

- RLS enabled
- owner-scoped SELECT/INSERT/UPDATE/DELETE as appropriate
- authenticated access only where intended
- server-side ownership validation remains required
- foreign keys must preserve safe history deletion behavior

## Migration Safety

Inspect existing migration naming and chronology.
Use a new migration.
Do not edit historical applied migrations.

## Testing

Add SQL/repository/security contract tests where repository conventions support them.

## Stop

Return migration + persistence report and STOP.

---

# V2-3 — Repository + Session Lifecycle

## Objective

Implement the Clean Architecture data layer for V2 session creation/loading without AI generation yet.

## Required Behavior

Implement:

- create session
- fetch session
- load persisted steps
- reject incompatible version
- identify stale/incomplete session
- persist canonical plan when later provided
- update generation statuses
- persist asset references
- idempotent reload behavior

A revisited tutorial must reuse valid persisted data.

Do not regenerate merely because the page reopened.

## Required State Model

Support:

```text
planning
plan_ready
generating
ready
failed
incompatible
```

or equivalent strongly typed states.

## Testing

Repository DTO/codec/domain conversion tests.
Ownership/path validation tests.
Stale/version mismatch tests.

## Stop

Return report and STOP.

---

# V2-4 — Personalized Tutorial Planner Edge Function

## Objective

Implement the server-side AI planner that creates the COMPLETE personalized tutorial plan before image generation.

## Inputs

Use server-verified records for:

- authenticated user
- original analysis
- face attributes
- selected style/look
- actual standard recommendation OR Kit recommendation
- owned products / validated Kit selected products when Kit mode
- canonical final preview reference/image when required for target interpretation

Never trust client-supplied recommendation/product ownership blindly.

## Model

Requested model:

`gemini-3.6-flash`

Before implementation, verify that the configured Gemini integration can call the requested model for this planner use case.

If unavailable:
STOP and report.
Do not silently substitute another model.

Make model configurable server-side.

## Planner Prompt Rules

The prompt must explicitly state:

- You are not creating a new makeup look.
- You are decomposing the existing canonical target.
- Every step must teach how to reproduce that exact target.
- Steps must be personalized to the user's face attributes.
- Use only the persisted recommendation.
- Kit mode may use only validated owned selected products.
- Dynamic number of steps.
- Final Look must be last.
- No generic filler steps.
- Output structured JSON only.

## Validation

Server validates planner JSON before persistence.

Validate:

- known categories
- sequential step index
- product ownership
- selected style
- required instructional fields
- cumulative category consistency
- final step
- total count

Use bounded retries only.

## Output

Persist the entire validated plan atomically/transactionally where practical.

## Tests

Prompt contract tests.
Parser/validator tests.
Kit ownership rejection tests.
Dynamic plan tests.
Malformed response tests.

## Stop

Return report and STOP.

---

# V2-5 — Guideline Image Generation

## Objective

Implement the personalized GUIDELINE image pipeline.

This phase does NOT implement cumulative result generation.

## Product Requirement

The guideline visual should resemble a professional personalized makeup tutorial:

- the user's face/base state
- application zone
- arrows/direction
- current category only
- visually understandable placement

Critical instruction text remains Flutter-rendered from the persisted Step Spec.

Do not depend on AI-generated typography inside pixels.

## Inputs

For current step:

```text
IMAGE A = original selfie / identity reference
IMAGE B = previous cumulative result or original for first step / base state
IMAGE C = canonical final preview / exact target
DATA D = current Step Spec
DATA E = relevant face attributes
```

## Prompt Intent

> Show where and how to apply ONLY the current category on this specific face so the user can reproduce the canonical target.

The guideline image should NOT apply the finished makeup category as a beauty result.

It is instructional.

It may use:

- semi-transparent zones
- directional arrows
- paths
- soft bands
- minimal markers

Do not show guidance for unrelated categories.

## Model

Use configurable:

`TUTORIAL_V2_GUIDELINE_MODEL`

Requested initial value: `gemini-3.6-flash`

Verify required image-generation/editing capability before hardcoding.

If unavailable, STOP and report.

## Storage

Store private per-user/session/step guideline assets.

Do not overwrite source images.

## Failure Rule

If a guideline image cannot be generated reliably:
mark guideline generation failed and keep written instructions available.
Do not show a confidently wrong fallback graphic.

## Tests

- prompt contract
- storage path ownership
- idempotent generation
- malformed image response
- wrong-step asset rejection
- retry bounds

## Device QA

This phase is not visually accepted until at least:
Foundation, Blush, Eyeshadow/Eyeliner, and Lip guidance are manually inspected.

## Stop

Return report and STOP.

---

# V2-6 — Canonical-Anchored Cumulative Result Generation

## Objective

Implement cumulative Result images without repeating V1 recursive-drift architecture.

## Inputs Per Step

```text
IMAGE A = original selfie
Role: permanent identity anchor

IMAGE B = previous cumulative result
Role: continuity anchor

IMAGE C = canonical final preview
Role: exact target

DATA D = current Step Spec
Role: only category allowed to change now

DATA E = cumulative categories
Role: what should already be present
```

## Strict Prompt Rules

Include explicit constraints:

- You are NOT creating a new makeup look.
- IMAGE C is the exact target.
- Apply ONLY the current category.
- Preserve identity from IMAGE A.
- Preserve completed makeup from IMAGE B.
- Do not change unrelated categories.
- Do not add future categories.
- Do not change hair, face shape, skin tone, lighting style, or unrelated appearance.
- Move closer to IMAGE C in the current category only.
- Do not place arrows/text/guidelines in the Result image.

## Model

Configurable:

`TUTORIAL_V2_RESULT_MODEL`

Requested initial value: `gemini-3.6-flash`

Verify image capability before use.

Do not couple business logic to the model name.

## Final Step

Do NOT generate the final step.

Final Look asset reference must equal the canonical premium final preview.

## Testing

- prompt role tests
- category-lock tests
- final-step reuse tests
- storage/idempotency tests
- corrupted response handling
- retry handling

## Device QA

Inspect at least:

- Foundation result
- Blush result
- eye result
- lip result
- penultimate result
- canonical final transition

## Stop

Return report and STOP.

---

# V2-7 — Hybrid Generation Orchestrator + One-Step Prefetch

## Objective

Implement the hybrid generation strategy.

## Required Flow

```text
Create/load session
↓
Plan complete
↓
Show text/tutorial shell
↓
Generate current step assets
↓
Display current step
↓
Prefetch next step only
↓
Persist/cache
↓
Repeat
```

## Rules

- Do not generate all step images immediately.
- Default prefetch depth = 1.
- Avoid duplicate generation requests.
- Use persisted statuses.
- Revisiting a completed step uses cache.
- Exiting and reopening resumes.
- Network failure must not corrupt the plan.
- A failed next-step prefetch must not break the current ready step.
- Final step requires no generation.

## Concurrency

Prevent simultaneous duplicate requests for the same `(session, step, assetType)`.

Use repository/service architecture consistent with current app.

## Testing

- one-step prefetch
- no duplicate generation
- resume after restart
- failed prefetch
- cached revisit
- final-step no-op generation

## Stop

Return report and STOP.

---

# V2-8 — Tutorial UI + Guidelines/Result Slider

## Objective

Implement the user-facing V2 tutorial screen.

## Required Layout

```text
STEP N OF TOTAL

[ GUIDELINES ] ← draggable slider → [ RESULT ]

CATEGORY

Apply:
...

Where:
...

Direction:
...

Technique:
...

Tip:
...

← Previous Step                 Next Step →
```

## Rules

- Guidelines side uses current step guideline asset.
- Result side uses current cumulative result.
- Text comes only from persisted Step Spec.
- Slider divider/handle is comparison UI, not tutorial guidance.
- Total steps comes from persisted canonical plan.
- Previous/Next navigation handles loading gracefully.
- Cached steps appear immediately.
- Current step may show separate loading states for guideline and result.

## Accessibility

Preserve semantic labels.
Avoid text that requires interpreting only color.
Respect image aspect/crop behavior.

## No V1 Geometry Port

Do not copy the V1 normalized-coordinate geometry/painter system into V2 unless this phase explicitly proves it is needed.

The V2 guideline is an AI-generated instructional visual, not a Flutter geometry reconstruction.

## Testing

Widget tests for:

- dynamic total count
- partial readiness
- errors
- retry
- previous/next
- final step
- Kit product display
- standard recommendation display

## Stop

Return report and STOP.

---

# V2-9 — My Makeup Kit Tutorial Integration

## Objective

Integrate V2 entry and data flow with My Makeup Kit without changing core Kit behavior.

## Required Rules

- Tutorial uses the existing persisted Kit recommendation.
- Only owned validated selected products may appear.
- Product snapshots are persisted with the tutorial.
- Missing Kit categories may be omitted.
- Do not invent replacement products.
- Do not rerun Kit selection separately inside tutorial logic.
- Do not modify My Makeup Kit domain rules just to satisfy V2.

## Entry Point

Add the V2 tutorial entry from the appropriate Kit result screen using the current app architecture.

Avoid changes to Kit behavior outside the new entry point.

## Tests

- cross-account safety
- unowned product rejection
- incomplete kit
- product snapshot persistence
- tutorial entry routing
- historical Kit changes do not mutate old tutorial step snapshots

## Stop

Return report and STOP.

---

# V2-10 — Standard Preview / History Integration

## Objective

Integrate V2 with the standard generated makeup preview and supported History/Saved Look entry paths.

## Requirements

Entry must carry or resolve server-side:

- analysis
- selected style
- recommendation
- canonical final preview
- ownership

Do not let client-provided image URLs define ownership.

History reopening should:

- reuse valid V2 session
- reject incompatible old session
- create a new V2 session only through supported flow when necessary

Do not regenerate every visit.

## Tests

- new result entry
- history entry
- ownership
- stale V2 session
- missing required recommendation/final image
- canonical final asset reuse

## Stop

Return report and STOP.

---

# V2-11 — Prompt Hardening + Drift Defense

## Objective

Audit and strengthen planner, guideline, and result prompts using real V2 device outputs.

Do not perform this phase from theory only.

## Required Evidence

Collect representative outputs for:

- Foundation
- Blush
- Contour
- Eyeshadow/Eyeliner
- Lips
- penultimate result

## Audit

For each failure, find the FIRST failure point:

```text
source records
→ step spec
→ guideline prompt
→ guideline output
→ result prompt
→ result output
→ storage
→ UI
```

Do not patch the UI to hide upstream AI intent failures.

## Tune

Strengthen:

- category lock
- identity preservation
- canonical target anchoring
- face-attribute personalization
- prevention of future-category leakage
- prevention of unrelated beautification
- guideline/result consistency

Do not merely add massive prompt text without evidence.

Keep prompt structure testable and modular.

## Stop

Return before/after QA report and STOP.

---

# V2-12 — Performance, Cost, Retry, and Abuse Controls

## Objective

Make V2 production-responsible without degrading correctness.

## Audit

Measure:

- planner latency
- guideline generation latency
- result generation latency
- average calls per completed tutorial
- abandonment cost
- retry frequency
- storage size
- prefetch usefulness

## Controls

Implement/verify:

- authenticated quota operation names
- server-side rate limits
- bounded retries
- idempotency
- one-step prefetch
- cancellation/ignore-late-result behavior where appropriate
- no duplicate asset generation
- private storage lifecycle

Do not reduce image quality or remove canonical anchoring solely to make benchmarks prettier.

## Stop

Return metrics + optimization report and STOP.

---

# V2-13 — Full Regression + Physical Device Acceptance

## Objective

Determine whether V2 is genuinely ready.

## Automated Checks

Run:

```bash
flutter analyze
flutter test
```

Run relevant Deno/Edge Function tests using repository-established commands.

Verify migration status.

Verify no accidental changes to protected systems.

## Device Flows

Test at minimum:

### Standard mode
- Natural
- Soft Glam
- Full Glam

### Kit mode
- complete kit
- incomplete kit

### Representative categories
- Foundation
- Concealer
- Contour/Bronzer
- Blush
- Eyeshadow
- Eyeliner
- Lip

### Lifecycle
- start tutorial
- next/previous
- leave/reopen
- retry failed generation
- cached revisit
- history entry
- final canonical step

## Visual Acceptance

For each tested tutorial:

- instructions match the selected look
- face-based personalization is sensible
- guideline and text agree
- result and text agree
- each step moves toward canonical final
- identity does not visibly drift
- unrelated categories do not change
- no sudden penultimate→final discontinuity
- final step is exactly the canonical premium final preview

## Protected Regression

Confirm:

- Face Analysis
- standard recommendation
- premium preview
- history
- My Makeup Kit
- Kit recommendation
- Kit preview
- auth
- RLS/storage behavior

remain working.

## Deliverable

Create:

`docs/tutorial_v2/V2_FINAL_ACCEPTANCE_REPORT.md`

Classify:

```text
READY
READY WITH KNOWN LIMITATIONS
NOT READY
```

Use evidence.

Do not call it ready merely because tests pass.

## Stop

Return final report and STOP.

---

# V2-14 — Optional Controlled Model Evaluation

## Objective

Only after V2 architecture is correct, determine whether the requested Flash model is sufficient.

Do not run this phase before V2-13 unless explicitly requested.

Compare models/configurations using the SAME:

- selfie
- face analysis
- selected style
- recommendation
- canonical target
- step spec
- prompt
- image size where possible

Judge:

- identity consistency
- guideline usefulness
- category fidelity
- target convergence
- skin-tone stability
- eye fidelity
- lip fidelity
- latency
- cost

Do not choose a more expensive model merely because it produces a prettier standalone image.

The tutorial wins only if it teaches the user to reproduce the selected target more faithfully.

## Stop

Return controlled comparison and STOP.
