# FaceTune Step-by-Step Tutorial V3 — Claude Code Opus 5 Phase Prompts

**Source of truth:** `FACETUNE_STEP_BY_STEP_TUTORIAL_V3_SOURCE_OF_TRUTH.md`  
**Required branch:** `feature/step-by-step-tutorial-v3`

# Global Role and Rules

You are Claude Code using Opus 5.

Act as:
- Principal Software Engineer
- Senior Flutter Architect
- Senior Dart Engineer
- Senior Supabase/Postgres Engineer
- Senior AI Integration Engineer
- Multimodal Prompt Engineer
- Security Engineer
- QA/Test Architect
- Git Safety Engineer
- Mobile Performance Engineer
- Technical Product Engineer

V3's central rule:

> No intermediate makeup appearance generation. Every non-final tutorial step is a personalized guideline image generated independently from the ORIGINAL SELFIE.

Before every phase:

```bash
git status
git branch --show-current
```

Expected:

`feature/step-by-step-tutorial-v3`

If not exact, STOP.

Read:
- `FACETUNE_STEP_BY_STEP_TUTORIAL_V3_SOURCE_OF_TRUTH.md`
- `CODEX_MASTER_GUIDE.md`
- all current files relevant to the phase

Global prohibitions:
- no development on `main`
- no modification of V1/V2 branches
- no reset/force push/branch deletion
- no unrelated cleanup
- no Gemini secret exposure
- no RLS disabling
- no public-storage workaround
- no original-selfie overwrite
- no cumulative makeup-result generation
- no previous-guideline → next-guideline dependency
- no generic universal placement
- no automatic next phase

Use `npx -y supabase ...`.

Every phase completion report must include:
1. Files changed
2. Architecture decisions
3. Tests and results
4. Risks/limitations
5. Acceptance status
6. STOP

---

# V3-0 — Clean Baseline + Remote Audit

## Goal
Prove V3 starts from the clean `main` baseline and document current remote constraints.

## Do
1. Verify branch/status.
2. Confirm V3 base vs `main`.
3. Confirm no V2 WIP is present locally.
4. Run `flutter analyze` and `flutter test`.
5. Run:
   - `npx -y supabase migration list --linked`
   - `npx -y supabase functions list`
6. Identify V1/V2 tutorial migrations/tables/functions still present remotely.
7. Verify the real persisted selected-style field.
8. Verify standard and Kit recommendation relationships.
9. Verify canonical premium preview persistence/storage.
10. Verify original-selfie storage/ownership.
11. Verify history deletion behavior for analysis-owned storage.

## Deliverable
Create:

`docs/tutorial_v3/V3-0_BASELINE_AUDIT.md`

## Do Not
No feature code, migrations, deployment, UI, or remote writes.

## STOP

---

# V3-1 — Domain Contracts + Step Spec

## Goal
Define the complete V3 tutorial domain before database or AI work.

## Implement
Strong types for:
- V3 session
- V3 plan
- V3 Step Spec
- tutorial category
- source mode
- guideline status
- product snapshot
- target-reference mode
- plan version

## Step Spec must represent
- step index
- category
- selected style
- product/shade if relevant
- coverage/intensity
- where
- direction
- technique
- amount/tool if useful
- tip/avoid
- scoped face attributes
- face rationale
- target rationale
- target cues
- guideline visual intent
- final-step flag

## Enforce
- dynamic count
- final look last
- no intermediate Result entity/state
- original selfie is base for every non-final step
- Step Spec drives both Flutter text and guideline image intent
- no independent per-step instruction invention

## Tests
Dynamic plans, ordering, duplicates, Kit constraints, face-attribute scoping, final canonical reuse, no result-state semantics.

## No DB, Gemini, or UI.

## STOP

---

# V3-2 — V3 Persistence + RLS

## Goal
Create isolated V3 persistence without reusing V1/V2 schema accidentally.

## Precondition
Read V3-0 audit.

## Prefer
- `tutorial_v3_sessions`
- `tutorial_v3_steps`
- `tutorial_v3_assets`

unless current repository conventions justify a safer equivalent.

## Persist
Session:
- owner
- analysis
- standard/Kit recommendation
- source mode
- selected look
- canonical preview
- total steps
- plan version
- status

Step:
- index
- category
- validated Step Spec
- product snapshot
- guideline status/reference
- retry/error metadata

## Security
- RLS enabled
- authenticated owner scope
- safe foreign keys
- server-side ownership validation
- no edit of historical applied migrations
- storage/history cleanup compatibility

## Tests
Migration/security/repository-contract tests.

## STOP

---

# V3-3 — Repository + Session Lifecycle

## Goal
Implement Clean Architecture persistence/session behavior.

## Implement
- create/load session
- load plan/steps
- persist plan
- update guideline state
- persist guideline asset
- reject incompatible plan versions
- resume/reopen
- reuse ready guideline
- retry failed guideline

States may include:
`planning`, `plan_ready`, `generating`, `ready`, `failed`, `incompatible`.

## Critical
Do not port V2 cumulative-result state machinery.

## Tests
DTO/codec, stale version, ownership, reload, idempotency, ready-asset reuse, failed state.

## STOP

---

# V3-4 — Personalized Master Tutorial Planner

## Goal
Generate ONE complete dynamic tutorial plan before any guideline image is generated.

## Server-verified inputs
- authenticated user
- analysis
- relevant face attributes
- persisted selected style
- standard OR Kit recommendation
- owned validated Kit products when applicable
- canonical final preview

## Prompt intent
> Decompose the already-selected canonical final makeup look into the exact dynamic makeup-application instructions this specific user should follow.

## Output per step
- category
- product/shade if applicable
- coverage/intensity
- where
- direction
- technique
- amount/tool if useful
- personalized tip
- avoid
- scoped face attributes
- face rationale
- target rationale
- target cues
- guideline visual intent
- final-step flag

## Rules
- no fixed count
- no generic filler
- no independent product selection
- Kit only uses owned validated products
- selected look mandatory
- final look last
- no makeup-result-generation instructions

## Model
Planner model must be server-configurable.
If `gemini-3.6-flash` is used for structured planning, verify it against the current integration before hardcoding.

## Validation
Strict schema + semantic validation + bounded retry.

## Tests
Prompt/parser/malformed-response/dynamic-plan/Kit-ownership tests.

## STOP

---

# V3-5 — Guideline Image Model Capability Gate

## Goal
Verify the user's requested guideline model can actually output images before implementation.

Requested model:

`gemini-3.6-flash`

Required capability:

```text
source image(s) IN
+ structured instruction IN
→ image bytes OUT
```

## Verify
1. endpoint/API version
2. request format
3. image input support
4. multiple input/reference image support if needed
5. image-output support
6. response shape
7. inline image/MIME behavior
8. image edit/annotation capability

Do not confuse:
`image IN → text/JSON OUT`
with:
`image IN → image OUT`.

## Deliverable
Create:

`docs/tutorial_v3/V3-5_GUIDELINE_MODEL_GATE.md`

Classify:

`SUPPORTED`

or

`NOT SUPPORTED`

If not supported, STOP and report exact incompatibility.

**Do not silently substitute another model.**

No feature implementation in this phase.

## STOP

---

# V3-6 — Personalized Guideline Image Pipeline

## Precondition
V3-5 has an explicitly approved image-output-capable model.

## Goal
Generate one personalized guideline image from the original selfie for a persisted Step Spec.

## Inputs
```text
IMAGE A = original selfie
Role: exact visual base / identity

IMAGE B = canonical final preview
Role: exact unmodified destination reference

DATA C = persisted current V3 Step Spec
Role: authoritative instruction

DATA D = scoped relevant face attributes
Role: personalization
```

## Strict prompt
> Preserve the source selfie and identity. Do not apply makeup. Do not retouch or beautify. Do not intentionally alter facial features or lighting. Add only the visual instructional zones, arrows, paths, bands, or markers required by the persisted Step Spec for the CURRENT category.

> The canonical final preview is reference only. Use it to understand the intended category placement/style. Do not copy the finished makeup onto the selfie.

> Visualize the Step Spec. Do not invent a new instruction.

## Allowed
- translucent zones
- arrows
- paths
- soft bands
- minimal markers

## Forbidden
- finished makeup appearance
- unrelated-category guidance
- AI typography required for correctness
- new makeup look
- previous guideline as input
- beautification

## Edge Function
Use V3-specific slug such as:
`generate-tutorial-v3-guideline`

## Configuration
Server-side:
`TUTORIAL_V3_GUIDELINE_MODEL`

## Security
Client sends identifiers only.
Server resolves and validates session, step, analysis, recommendation, canonical preview, and storage ownership.

## Storage
Analysis-owned private V3 path.
Never overwrite selfie or canonical preview.

## Idempotency
Atomic claim/equivalent, ready reuse, bounded retry.

## Tests
Prompt contract, current-category lock, no-makeup rule, response parsing, corrupt image, ownership, path safety, idempotency.

## STOP

---

# V3-7 — Hybrid Generation + Prefetch

## Goal
Make guideline generation responsive without generating the whole tutorial upfront.

## Flow
```text
create/load session
↓
generate/load plan
↓
show text shell
↓
generate current guideline
↓
display
↓
prefetch next guideline only
↓
cache
```

## Rules
- default prefetch depth = 1
- no duplicate concurrent request
- every guideline begins from original selfie
- revisiting uses cache
- failed prefetch does not break current step
- final step has no guideline-generation call

## Tests
Current+1, duplicate prevention, resume, failed prefetch, cached revisit, final-step no-op.

## STOP

---

# V3-8 — Tutorial UI

## Goal
Build the real V3 tutorial screen.

## Required layout
```text
STEP N OF TOTAL
CATEGORY

[ LARGE PERSONALIZED GUIDELINE IMAGE ]

TARGET LOOK
[ exact canonical final preview thumbnail / expandable reference ]

APPLY
...

WHERE
...

DIRECTION
...

TECHNIQUE
...

WHY THIS PLACEMENT
...

TIP
...

← Previous                         Next →
```

## Rules
- no Guidelines ↔ Result slider
- no intermediate makeup-result UI
- all text from persisted Step Spec
- canonical preview is exact and unmodified
- dynamic total count
- loading/error/retry states
- cached guidelines appear immediately
- final screen reuses premium canonical preview

## Target crop
MVP uses full canonical final preview.
Do not use AI-generated target crops.

## Tests
Dynamic steps, loading/error/retry, target reference, final screen, Previous/Next, Kit/standard text.

## STOP

---

# V3-9 — My Makeup Kit Integration

## Goal
Connect V3 to existing My Makeup Kit safely.

## Rules
- use persisted Kit recommendation
- owned selected products only
- server validates product IDs
- persist product snapshots
- incomplete kit valid
- omit unavailable categories where appropriate
- no independent product selection
- no core Kit rewrite

## Tests
Unowned rejection, incomplete Kit, cross-account safety, snapshots, routing, historical product changes.

## STOP

---

# V3-10 — Standard Preview + History Integration

## Goal
Allow V3 to start/reopen from standard preview and supported history paths.

## Resolve server-side
- analysis
- selected style
- recommendation
- canonical final preview
- ownership

Do not trust arbitrary client URLs/paths.

## Reopen
- reuse valid V3 session
- reject incompatible old sessions
- create new V3 session only through supported flow
- no regeneration every visit

## Tests
Standard entry, history entry, ownership, missing recommendation/final preview, cache reuse.

## STOP

---

# V3-11 — Visual Prompt Hardening

## Goal
Improve actual guideline quality from real outputs, not theory.

## Device samples
- Foundation
- Concealer
- Contour/Bronzer
- Blush
- Eyeshadow
- Eyeliner
- Lip Color

## Find first failure point
```text
source records
→ Step Spec
→ prompt
→ model output
→ storage
→ UI
```

## Fix only evidenced problems
- finished makeup appears
- face altered
- wrong placement
- unrelated arrows
- selected-look disconnect
- target disconnect
- weak face personalization
- AI text appears
- unclear zones/arrows

Do not change the Step Spec to agree with a wrong image.
Do not hide AI failures with fake Flutter decoration.

## Deliverable
Before/after QA report.

## STOP

---

# V3-12 — Category-Specific Target Reference (Optional)

## Goal
Evaluate whether focused target references improve learning.

Examples:
- blush → cheek-focused canonical view
- eyes → eye-focused canonical view
- lips → lip-focused canonical view

## Rules
- derive from actual canonical final preview
- no AI redraw/recreation
- no major geometry subsystem merely for thumbnails
- keep full preview if reliable cropping is unavailable

Retain only if stable and more useful.

## STOP

---

# V3-13 — Performance + Cost Controls

## Goal
Make V3 production-responsible without hurting correctness.

Measure:
- planner latency
- guideline latency
- calls/tutorial
- abandonment cost
- retries
- storage
- prefetch usefulness

Verify:
- authenticated quota
- rate limiting
- bounded retry
- idempotency
- duplicate prevention
- current+1 prefetch
- storage lifecycle
- history-deletion limits

Do not sacrifice guideline correctness just to improve benchmarks.

## STOP

---

# V3-14 — Full Regression + Device Acceptance

## Goal
Decide whether V3 is genuinely ready.

## Automated
Run:
```bash
flutter analyze
flutter test
```

Run relevant Edge/Deno tests.
Verify migrations/deployments.

## Device scenarios
Standard:
- Natural
- Soft Glam
- Full Glam

Kit:
- complete Kit
- incomplete Kit

Categories:
- Foundation
- Concealer
- Contour/Bronzer
- Blush
- Eyeshadow
- Eyeliner
- Lip Color

Lifecycle:
- start
- previous/next
- leave/reopen
- retry
- cached revisit
- history
- final canonical screen

## Visual acceptance
Every tested guideline must:
- preserve recognizable identity
- add no finished makeup appearance
- teach current category only
- match Step Spec
- make sense for face attributes
- make sense for selected look
- clearly connect to canonical target
- use understandable zones/arrows
- require no AI typography

## Protected regression
Verify:
- Face Analysis
- standard recommendation
- premium preview
- history
- My Makeup Kit
- Kit recommendation/preview
- auth
- RLS/storage

## Deliverable
Create:
`docs/tutorial_v3/V3_FINAL_ACCEPTANCE_REPORT.md`

Classify:
- READY
- READY WITH KNOWN LIMITATIONS
- NOT READY

Use evidence, not merely green tests.

## STOP

---

# V3-15 — Optional Controlled Model Comparison

## Goal
Only after V3 works, compare image-capable models/configurations.

Use the SAME:
- original selfie
- analysis
- selected look
- recommendation
- canonical target
- Step Spec
- prompt
- image size where possible

Judge:
- identity preservation
- no-makeup compliance
- placement usefulness
- category lock
- target alignment
- personalization
- latency
- cost

Do not choose a model merely because its image looks prettier.

The best model is the one that teaches the selected final look most faithfully.

## STOP
