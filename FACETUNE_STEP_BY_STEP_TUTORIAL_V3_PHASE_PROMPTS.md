# FaceTune Step-by-Step Tutorial V3 — Claude Code Opus 5 Phase Prompts

**Source of truth:** `FACETUNE_STEP_BY_STEP_TUTORIAL_V3_SOURCE_OF_TRUTH.md`  
**Required branch:** `feature/step-by-step-tutorial-v3`

# Global Role and Rules

You are Claude Code using Opus 5.

Act as:
- Principal Software Engineer
- Principal Mobile Architect
- Senior Flutter Architect
- Senior Dart Engineer
- Senior Clean Architecture Engineer
- Senior Supabase/Postgres Engineer
- Senior Supabase Edge Function Engineer
- Senior AI Integration Engineer
- Senior Gemini / Multimodal Engineer
- Senior Structured Output / Schema Engineer
- Senior Geometry / Rendering Engineer
- Senior Backend Security Engineer
- QA/Test Architect
- Senior Visual QA Engineer
- Git Safety Engineer
- Mobile Performance Engineer
- Technical Product Engineer

V3's central rule:

> No intermediate makeup appearance generation. Every non-final tutorial step displays the ORIGINAL SELFIE unchanged with a personalized deterministic Flutter guideline overlay whose geometry is derived from the persisted Step Spec and the user's actual face.

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
- all current files/reports relevant to the phase

Global prohibitions:
- no development on `main`
- no modification of V1/V2 branches
- no reset/force push/branch deletion
- no unrelated cleanup
- no Gemini secret exposure
- no `service_role` use from client/test harness
- no RLS disabling
- no public-storage workaround
- no original-selfie overwrite
- no cumulative makeup-result generation
- no previous-guideline → next-guideline dependency
- no AI-generated replacement guideline selfie
- no universal static placement coordinates
- no AI-controlled overlay styling
- no automatic next phase

Use `npx -y supabase ...`.

Every phase completion report must include:
1. Files changed
2. Architecture decisions
3. Tests and results
4. Risks/limitations
5. Security impact
6. Acceptance status
7. STOP

Open release blocker to preserve in all relevant reports:

> The previously exposed legacy Supabase `service_role` credential remains an OPEN HIGH-PRIORITY SECURITY ITEM until migrated/revoked. Do not use or expose it. Production/release is blocked until remediation is complete.

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

# V3-0.5 — Remote Migration / Function Recovery

## Goal
Recover exact local source for already-applied/deployed tutorial artifacts before any new V3 remote write.

## Rules
- recover historical applied migration source exactly
- recover deployed function source where missing
- verify hashes where possible
- preserve live quota-operation superset
- do not apply unapplied historical WIP migrations
- no destructive repair
- no remote mutation unless explicitly authorized

## Deliverable
Create/update:

`docs/tutorial_v3/V3-0.5_REMOTE_RECOVERY_REPORT.md`

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
- guideline/geometry status
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
- original selfie is authoritative base for every non-final step
- Step Spec drives both Flutter instructional text and geometry intent
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
Read V3-0 and V3-0.5 reports.

## Prefer
- `tutorial_v3_sessions`
- `tutorial_v3_steps`

Do not invent additional tables unless current repository conventions justify them.

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
- current guideline/geometry status/reference fields if already established
- retry/error metadata

## Security
- RLS enabled
- authenticated owner scope
- safe foreign keys
- server-side ownership validation
- no edit of historical applied migrations
- storage/history cleanup compatibility

## Critical
Current schema may still contain image-guideline fields from the earlier architecture. Do not prematurely rewrite them here unless this phase explicitly authorizes migration evolution.

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
- update step guideline/geometry state
- reject incompatible plan versions
- resume/reopen
- reuse ready compatible step visualization data
- retry failed mapping/generation state

States may include:
`planning`, `plan_ready`, `mapping`, `ready`, `failed`, `incompatible`.

If older code still uses `generating`, preserve backward compatibility until an explicitly authorized migration refactor.

## Critical
Do not port V2 cumulative-result state machinery.

## Tests
DTO/codec, stale version, ownership, reload, idempotency, compatible ready reuse, failed state.

## STOP

---

# V3-4 — Personalized Master Tutorial Planner

## Goal
Generate ONE complete dynamic tutorial plan before any guideline geometry is mapped.

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
- Step Spec must contain enough spatial specificity for deterministic geometry mapping

## Model
Server-configurable:

`TUTORIAL_V3_PLANNER_MODEL`

Current approved default:

`gemini-3.6-flash`

## Validation
Strict schema + semantic validation + bounded retry.

## Tests
Prompt/parser/malformed-response/dynamic-plan/Kit-ownership tests.

## STOP

---

# V3-5 — Historical Guideline Model Capability Gate / Decision Record

## Status
COMPLETED HISTORICAL PHASE.

Do not rerun automatically.

## Historical finding
`gemini-3.6-flash` in the current integration is suitable for image-in → text/JSON structured output, not the required image-output guideline workflow.

The image-output model spike used `gemini-3.1-flash-image`.

Subsequent behavioral gates rejected AI-generated replacement guideline selfies:

### V3-6A.1
Two-image renderer:

```text
Original Selfie + Canonical Final + Step Spec → generated guideline image
```

Rejected because finished makeup/style from the canonical target leaked into non-current categories.

### V3-6A.2
Single-image renderer:

```text
Original Selfie + Step Spec → generated guideline image
```

Rejected because region-fill annotation altered source facial surfaces, especially Foundation skin tone and Lip Color surface.

## Permanent conclusion
Do not continue generative-image prompt tuning for tutorial guideline selfies without explicit architectural approval.

The current architecture uses structured geometry + Flutter rendering.

## Evidence
Read:
- `docs/tutorial_v3/V3-5_GUIDELINE_MODEL_GATE.md`
- `docs/tutorial_v3/V3-6A_GUIDELINE_BEHAVIOR_SMOKE_GATE.md`
- `docs/tutorial_v3/V3-6A.1_LIVE_SMOKE_PROBE_REPORT.md`
- `docs/tutorial_v3/V3-6A.2_SINGLE_IMAGE_RENDERER_GATE.md`

## STOP

---

# V3-6R — Personalized Deterministic Geometry Renderer Gate

## Goal
Prove that FaceTune can produce personalized, dynamic, safe guideline visuals without generating a replacement selfie.

## Architecture under test

```text
ORIGINAL SELFIE
+ PERSISTED CURRENT STEP SPEC
+ SCOPED RELEVANT FACE ATTRIBUTES
        ↓
TUTORIAL_V3_GEOMETRY_MODEL
        ↓
STRICT NORMALIZED GEOMETRY JSON
        ↓
VALIDATION
        ↓
FLUTTER CUSTOMPAINTER
        ↓
ORIGINAL JPG + TRANSPARENT GUIDELINE OVERLAY
```

## Model
Server-side:

`TUTORIAL_V3_GEOMETRY_MODEL = gemini-3.6-flash`

Do not use `gemini-3.1-flash-image` for tutorial guideline rendering.

Do not modify the premium preview model.

## AI responsibility
Gemini receives:
- original selfie
- persisted current Step Spec
- minimum sufficient scoped face attributes

Gemini returns strict JSON only.

Gemini does NOT return:
- image bytes
- SVG
- HTML
- Flutter code
- text labels
- colors
- opacity
- fonts
- gradients
- animation
- arbitrary style

## Coordinate system

```text
x ∈ [0,1]
y ∈ [0,1]
origin = top-left
coordinateSpace = normalized_original_image
```

## Required primitive families
Use a strict sealed/discriminated schema for:
- region
- ellipse
- polyline
- arrow
- marker

## Semantic roles
Examples:
- coverage_zone
- placement_zone
- application_path
- blend_direction
- boundary
- exclusion
- focus_marker

AI may not invent arbitrary roles.

## Validation
Reject:
- unsupported schema version
- category mismatch
- unknown primitive
- unknown role
- NaN/infinity
- out-of-range coordinates
- malformed regions/polylines
- invalid radii
- zero-length arrows
- excessive primitive/point counts
- category-incompatible primitives
- unexpected text/style/code fields

Do not silently clamp invalid geometry.

## Flutter renderer
Prefer deterministic native Flutter `CustomPainter`.

Concept:

```text
Stack
├── Image(originalSelfie)
└── CustomPaint(validatedGeometry)
```

Flutter owns all visual style.

## Transform correctness
Implement/test original-image normalized coordinates → displayed image rect under actual BoxFit/alignment behavior.

Use proven image-fit math such as `applyBoxFit` / `Alignment.inscribe` or equivalent.

Inspect real EXIF/orientation/mirroring behavior before applying transforms.

## Full category gate
Test ALL canonical categories using actual project codes:
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

Do not permanently rename category codes.

## Personalization differential
Prove the system is not static.

At minimum test representative categories such as Blush, Eyeliner, and Lip Color with two genuinely different valid Step Specs requiring different placements.

Geometry must differ because Step Specs differ, not because of random offsets.

## Original integrity
Hash the original portrait before and after.

The hash must be identical.

The renderer must never write to the original source path.

## Temporary probe
Use an isolated temporary Edge Function such as:

`map-tutorial-v3-guideline-geometry-probe`

Do not use `service_role`.
Do not mutate shared secrets.
Do not use broad deploy or `--prune`.
Keep JWT verification ON.
Use safe ephemeral probe authentication without fragile global string substitution.

## No database work
No migrations, SQL, RLS changes, or production persistence in V3-6R.

## Evidence
Save local, gitignored evidence under:

`build/tutorial_v3_geometry_gate/`

Include:
- original image
- validated geometry JSON
- actual Flutter-rendered overlay previews
- prompts/metadata
- contact sheet if useful

## PASS criteria
All must hold:
1. original selfie byte-identical
2. strict normalized geometry returned
3. invalid geometry rejected
4. Flutter deterministic rendering works
5. all canonical categories representable
6. geometry reasonably matches Step Spec
7. personalization differential proves non-static behavior
8. no AI replacement selfie exists
9. no AI typography/style control exists
10. BoxFit/coordinate transform correct

## FAIL criteria
Fail if geometry repeatedly maps to wrong facial regions, complex categories cannot be represented, Step Spec is ignored, coordinates drift materially, static presets are effectively used, or invalid output cannot be safely rejected.

## Deliverable
Create:

`docs/tutorial_v3/V3-6R_DETERMINISTIC_GEOMETRY_RENDERER_GATE.md`

Classify:
- PASS
- FAIL
- BLOCKED BY INFRASTRUCTURE

If PASS:

`READY FOR EXPLICIT V3-6B GEOMETRY PIPELINE AUTHORIZATION`

If not:

`BLOCKED — DO NOT START V3-6B`

## STOP

---

# V3-6B — Production Personalized Geometry Pipeline

## Precondition
V3-6R has an evidence-backed PASS.

## Goal
Implement the secure production pipeline that maps one persisted non-final Step Spec to validated normalized geometry for deterministic Flutter rendering.

## Client request
Client sends identifiers only, such as:
- session ID
- step index / step ID

Do not trust client-supplied:
- Step Spec JSON
- analysis ID without ownership resolution
- storage paths
- face attributes
- category
- selected look
- arbitrary prompt text

## Server resolves
- authenticated user
- V3 session
- current V3 step
- analysis
- original selfie
- persisted Step Spec
- scoped relevant face attributes
- recommendation / Kit recommendation context as needed for integrity validation
- source mode
- plan/geometry versions

The canonical final preview is NOT an input to the geometry mapper.

## Kit security
For Kit sessions, re-read and validate authoritative ownership/product snapshot context server-side where required.

Never rely solely on optional client/domain-owned product ID sets.

## Geometry mapper
Use server-side:

`TUTORIAL_V3_GEOMETRY_MODEL`

Build prompt/context server-side from authoritative persisted records.

The mapper is not a second planner.

## Geometry persistence
Design the smallest V3-specific persistence evolution necessary after inspecting current schema.

Persist:
- geometry schema/version
- validated geometry payload or safe reference
- mapping status
- attempt/error metadata

Do not silently repurpose old image-path fields if that creates ambiguous semantics.

Do not edit historical applied migrations.
Use a new migration if schema evolution is required.

## State lifecycle
Conceptually:

```text
pending/failed
→ atomic claim
→ mapping
→ Gemini structured output
→ strict validation
→ persist validated geometry
→ ready
```

Idempotency:
- ready compatible geometry is reused
- duplicate concurrent mapping prevented
- bounded retries only
- stale/incompatible geometry version is explicit

## Security
- authenticated Edge Function
- client sends identifiers only
- server ownership validation
- Gemini key server-side
- no public storage workaround
- no `service_role` use from client
- no arbitrary client prompt

## Tests
Must cover:
- ownership
- session/step context mismatch
- source-mode mismatch
- Kit ownership/snapshot integrity
- exact Step Spec authority
- prompt contract
- structured response parsing
- invalid coordinate rejection
- unknown primitive/role rejection
- category mismatch
- complexity limits
- idempotency
- duplicate claims
- retry/failure
- compatible ready reuse
- stale geometry version
- no canonical preview sent to mapper
- no AI image output path

## Deliverable
Create:

`docs/tutorial_v3/V3-6B_PRODUCTION_GEOMETRY_PIPELINE_REPORT.md`

## Do Not
No Flutter tutorial screen in this phase.
No prefetch implementation.
No V3-7/V3-8.
No premium preview changes.

## STOP

---

# V3-7 — Hybrid Geometry Mapping + Prefetch

## Goal
Make guideline geometry responsive without mapping the whole tutorial upfront.

## Flow

```text
create/load session
↓
generate/load persisted plan
↓
show text/tutorial shell
↓
load/map current geometry
↓
render original selfie + overlay
↓
prefetch NEXT geometry only
↓
cache validated geometry
```

## Rules
- default prefetch depth = 1
- no duplicate concurrent mapping
- every geometry request starts from original selfie + persisted Step Spec
- previous geometry never becomes AI input
- revisiting uses compatible cached geometry
- failed prefetch does not break current step
- final step has no geometry-mapping call
- no generated guideline JPG cache

## Tests
Current+1, duplicate prevention, resume, failed prefetch, cached revisit, version invalidation, final-step no-op.

## STOP

---

# V3-8 — Tutorial UI

## Goal
Build the real V3 tutorial screen using the original selfie plus deterministic overlay geometry.

## Required layout

```text
STEP N OF TOTAL
CATEGORY

[ Stack
  ├── ORIGINAL SELFIE
  └── PERSONALIZED GUIDELINE CustomPaint
]

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
- canonical preview exact and unmodified
- dynamic total count
- loading/error/retry states for geometry
- cached geometry appears immediately
- final screen reuses premium canonical preview
- overlay style controlled centrally by Flutter
- original selfie is never modified/overwritten

## Geometry transform
Use the tested image-space transform from V3-6R/6B.

Overlay must remain aligned across:
- screen sizes
- portrait aspect ratios
- expected BoxFit/alignment behavior

## Target crop
MVP uses full canonical final preview.
Do not use AI-generated target crops.

## Tests
Dynamic steps, loading/error/retry, target reference, geometry alignment, final screen, Previous/Next, Kit/standard text, accessibility where relevant.

## STOP

---

# V3-9 — My Makeup Kit Integration

## Goal
Connect V3 geometry tutorial flow to existing My Makeup Kit safely.

## Rules
- use persisted Kit recommendation
- owned selected products only
- server validates authoritative ownership where necessary
- persist/reuse product snapshots
- incomplete kit valid
- omit unavailable categories where appropriate
- no independent product selection
- no core Kit rewrite
- geometry mapper never invents products/shades

## Tests
Unowned rejection, incomplete Kit, cross-account safety, snapshots, routing, historical product changes, geometry only for valid persisted steps.

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
- reuse compatible ready geometry
- reject incompatible old sessions/geometry versions
- create new V3 session only through supported flow
- no remapping every visit when compatible geometry is ready

## Tests
Standard entry, history entry, ownership, missing recommendation/final preview, geometry cache reuse, incompatible-version behavior.

## STOP

---

# V3-11 — Geometry + Visual Hardening

## Goal
Improve actual guideline usefulness from real rendered outputs, not theory.

## Device samples
Test all canonical categories:
- Foundation
- Concealer
- Blush
- Highlighter
- Eyeshadow
- Lip Color
- Lip Gloss
- Contour/Bronzer
- Eyebrow
- Eyeliner

## Find first failure point

```text
source records
→ Step Spec
→ geometry prompt
→ structured model output
→ validator
→ persisted geometry
→ image-space transform
→ CustomPainter
→ UI
```

## Fix only evidenced problems
- wrong placement
- wrong direction
- malformed region
- coordinate drift
- BoxFit misalignment
- overly cosmetic-looking Flutter styling
- selected-look disconnect in Step Spec
- weak face personalization
- unrelated primitives
- excessive/unclear geometry

Do not change the Step Spec merely to agree with wrong geometry.

Do not hide wrong geometry with cosmetic-looking decoration.

Do not return to AI-generated replacement images.

## Deliverable
Before/after QA report.

## STOP

---

# V3-12 — Category-Specific Target Reference (Optional)

## Goal
Evaluate whether focused target references improve learning.

Examples:
- blush → cheek-focused canonical view
- eyeshadow → eye-focused canonical view
- lips → lip-focused canonical view

## Rules
- derive from actual canonical final preview
- no AI redraw/recreation
- target crop is UI/reference only
- do not feed target crop to geometry mapper
- keep full preview if reliable non-generative cropping is unavailable

Retain only if stable and more useful.

## STOP

---

# V3-13 — Performance + Cost Controls

## Goal
Make V3 production-responsible without hurting correctness.

Measure:
- planner latency
- geometry-mapper latency
- geometry payload bytes
- primitives/points per step
- calls/tutorial
- abandonment cost
- retries
- cache hit rate
- prefetch usefulness
- Flutter overlay render cost

Verify:
- authenticated quota
- rate limiting
- bounded retry
- idempotency
- duplicate prevention
- current+1 prefetch
- geometry version compatibility
- history-deletion lifecycle

Expect geometry mapping to be materially cheaper/lighter than image generation, but measure rather than assume.

Do not sacrifice geometry correctness just to improve benchmarks.

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
- Blush
- Highlighter
- Eyeshadow
- Lip Color
- Lip Gloss
- Contour/Bronzer
- Eyebrow
- Eyeliner

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
- leave original selfie visually unchanged underneath
- teach current category only
- match persisted Step Spec
- make sense for face attributes
- make sense for selected look through planner-authored Step Spec
- clearly connect to canonical target in UI
- use understandable zones/arrows/paths
- require no AI typography
- exhibit no coordinate drift/clipping
- remain aligned across supported device layouts

## Personalization acceptance
Prove with evidence:
- same selected look + different relevant face attributes can produce legitimately different Step Specs/geometry
- same user + different selected look can produce legitimately different Step Specs/geometry

No fake/random offset personalization.

## Protected regression
Verify:
- Face Analysis
- standard recommendation
- premium preview
- history
- My Makeup Kit
- Kit recommendation/preview
- auth
- RLS/private storage

## Security acceptance
Production/release cannot be READY while the exposed legacy `service_role` remediation remains open.

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

# V3-15 — Optional Controlled Geometry-Model Comparison

## Goal
Only after V3 works, compare structured-output-capable models/configurations for geometry mapping.

Use the SAME:
- original selfie
- persisted Step Spec
- scoped face attributes
- geometry schema
- validation rules
- Flutter renderer

Judge:
- Step Spec alignment
- facial-region localization
- valid-JSON rate
- validation-pass rate
- personalization fidelity
- geometry stability
- latency
- cost

Do not compare models by prettier rendered screenshots when the underlying Step Spec/geometry is worse.

Do not use image-generation models merely because they can make attractive composites.

The best geometry model is the one that maps the authoritative Step Spec most faithfully and reliably.

## STOP
