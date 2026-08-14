# FACETUNE_PERSONALIZED_MAKEUP_OVERLAY_ROADMAP.md

## Purpose

Focused repair/enhancement roadmap for turning generic Step-by-Step Tutorial overlays into personalized face-aware makeup instructions.

Use with:
1. `CODEX_MASTER_GUIDE.md`
2. `FACETUNE_STEP_BY_STEP_TUTORIAL_GUIDE.md`
3. `FACETUNE_STEP_BY_STEP_TUTORIAL_ROADMAP.md`
4. `FACETUNE_PERSONALIZED_MAKEUP_OVERLAY_GUIDE.md`
5. the requested MO phase

## Mandatory Rules

```text
PHASE EXECUTION AUTHORIZATION

When the user pastes/selects/provides/references a complete MO phase, that is explicit authorization to execute it.

Do NOT ask for another confirmation.

Execute ONLY that MO phase.
Do NOT continue automatically.
After completion report, STOP.

GIT SAFETY

Run:
git status
git branch --show-current

Active branch must be:
feature/step-by-step-tutorial

If not, STOP.

main is protected.

STRICT SCOPE

Writable by default:
lib/features/step_by_step_tutorial/**
supabase/functions/<tutorial-related-functions>/**
tutorial-specific migrations/tests/docs

Other FaceTune code is read-only unless explicit approval is granted.

If an unrelated change appears necessary:
STOP and report exact file + reason + smallest proposed change + impact.

NO OPPORTUNISTIC REFACTORING.

MODEL RULE

Tutorial image model and resolution must remain configurable server-side and decoupled from business logic/UI.

SOURCE OF TRUTH

Read all required guide/roadmap files and inspect current repository before implementation.

Do not fabricate tests/builds/migrations/deployments/device/Gemini results.
```

# MO-1 — Overlay Accuracy Audit & Scope Lock

```text
Execute MO-1 — Overlay Accuracy Audit & Scope Lock.

Audit current tutorial-only overlay pipeline:
- planner
- placement metadata
- overlay renderer
- viewer/comparison
- repository/state
- tutorial prompt builder
- tutorial tests

Identify:
- where coordinates come from;
- whether coordinates are fixed;
- whether face attributes affect placement;
- whether style affects placement;
- whether recommendation color/finish/intensity affect placement;
- whether text/overlay/Gemini share one source.

Document current generic behavior and define minimal tutorial-only architecture for:
- PersonalizedTutorialInput
- PersonalizedTutorialStepSpec
- geometry abstraction
- placement rules
- confidence-aware overlay

Do not implement full redesign yet.
Do not modify unrelated FaceTune code.

Report:
PHASE COMPLETED
CURRENT BRANCH
ROOT CAUSE
CURRENT DATA FLOW
MISSING PERSONALIZATION
PROPOSED ARCHITECTURE
FILES MODIFIED
UNRELATED FILES MODIFIED
VALIDATION
NEXT PHASE: MO-2

Then STOP.
```

# MO-2 — Personalized Tutorial Input & Step Specification

```text
Execute MO-2 — Personalized Tutorial Input & Step Specification.

Create/evolve tutorial-only typed models for:
- PersonalizedTutorialInput
- PersonalizedTutorialStepSpec
- placement region/side
- direction
- intensity
- technique
- style/face adjustment
- overlay type/color
- geometry/placement confidence

Represent:
face shape, skin tone, undertone, eye shape, lip shape, hair color, eye color, selected style, recommendation data, and kit snapshot.

Separate WHAT / WHERE / HOW.

No UI pixels in domain models.
No unrelated code changes.

Add tests for validation and optional values.

Report and STOP.
```

# MO-3 — Tutorial Face Geometry Abstraction

```text
Execute MO-3 — Tutorial Face Geometry Abstraction.

Create tutorial-only normalized geometry for:
eyes, brows, nose, lips, forehead, cheeks, jaw, chin, face boundary.

Use 0.0–1.0 normalized coordinates.

Create an abstraction such as:
TutorialFaceGeometryProvider

Use existing FaceTune data first.
Do NOT add MediaPipe/OpenCV/TFLite/new face stack without approval.

Include geometry confidence.
Do not pretend semantic attributes are exact landmarks.

Test bounds, left/right, size independence, confidence.

Report and STOP.
```

# MO-4 — Face-Attribute & Style Placement Rules

```text
Execute MO-4 — Face-Attribute & Style Placement Rules.

Implement tutorial-only deterministic placement rules for:
Foundation
Concealer
Contour/Bronzer
Blush
Highlighter
Eyeshadow
Eyeliner
Brows
Lipstick/Lip Gloss

Rules must combine:
face attributes + selected style + actual recommendation/product.

Examples:
round vs oval blush differs where appropriate;
hooded vs almond eye guidance differs;
Korean vs Full Glam differs where appropriate.

Kit mode uses owned-product snapshot only.

Output structured metadata, not widgets.

Add personalization tests.

Report and STOP.
```

# MO-5 — Recommendation-to-Placement Metadata Pipeline

```text
Execute MO-5 — Recommendation-to-Placement Metadata Pipeline.

Build canonical tutorial pipeline:

PersonalizedTutorialInput
→ PersonalizedTutorialStepSpec
→ written instruction
→ overlay metadata
→ Gemini prompt input

For each step capture:
category, product snapshot, color, finish, placement, side, direction, intensity, technique, tip, face/style adjustment, geometry anchors, confidence.

Text, overlay, and Gemini must all consume the same spec.

Remove/deprecate duplicate independent tutorial-only interpretation.

Do not modify standard recommendation generation.

Add consistency tests.

Report and STOP.
```

# MO-6 — Personalized Category-Specific Overlay Renderer

```text
Execute MO-6 — Personalized Category-Specific Overlay Renderer.

Render from PersonalizedTutorialStepSpec + normalized geometry.

Foundation:
broad coverage + outward arrows.

Concealer:
targeted under-eye/nose/forehead/chin when instructed.

Contour:
soft bands.

Blush:
personalized cheek zones + direction.

Highlighter:
small highlight regions.

Eyeshadow:
lid/crease/outer/inner zones.

Eyeliner:
eye-relative path.

Brows:
directional fill.

Lips:
lip-relative coverage.

Use actual recommendation HEX where appropriate.
No hardcoded screen pixels.
Step 1 Placement uses original selfie.
Step N Placement uses Step N-1 Result.
Result remains clean.

Add renderer tests.

Report and STOP.
```

# MO-7 — Overlay Accuracy Validation & Confidence Fallback

```text
Execute MO-7 — Overlay Accuracy Validation & Confidence Fallback.

Validate:
normalized bounds
side correctness
category-region compatibility
cheek/eye/lip proximity
arrow plausibility
overlay size
bilateral consistency

Confidence:
HIGH → precise
MEDIUM → broader safe region
LOW → no misleading precise line; written instruction prioritized

Never draw random default coordinates.

Add malformed/low-confidence tests.

Report and STOP.
```

# MO-8 — Gemini Personalized Step Prompt Upgrade

```text
Execute MO-8 — Gemini Personalized Step Prompt Upgrade.

Modify only tutorial image-generation prompt pipeline.

Do not modify Gemini 3 Pro final preview.

Keep tutorial model/resolution configurable server-side.
Current defaults may remain:
gemini-3.1-flash-image
512px

Build versioned prompt from PersonalizedTutorialStepSpec.

Include:
style
relevant face attributes
category
actual product/color/HEX/finish
placement
direction
intensity
technique
face/style adjustment
cumulative rule

Where supported:
original selfie = identity reference
previous Result = cumulative makeup reference

Require same person and previous makeup preservation.
Apply only current step.
Forbid arrows/lines/dots/text/diagrams in Result.

Do not invent kit products.

Use the full Gemini prompt template from FACETUNE_PERSONALIZED_MAKEUP_OVERLAY_GUIDE.md.

Add prompt-builder tests.

Report:
prompt version
model config
identity strategy
cumulative strategy
deployment required
exact npx -y supabase commands if required

Then STOP.
```

# MO-9 — Personalized Tutorial Persistence & Snapshot Compatibility

```text
Execute MO-9 — Personalized Tutorial Persistence & Snapshot Compatibility.

Persist tutorial-owned personalized metadata:
placement
direction
intensity
technique
face/style adjustment
overlay metadata
confidence
product snapshot
prompt version
result image

Reopening must reuse saved personalized plan.
Do not re-decide placement every open.
Preserve My Makeup Kit snapshot semantics.

Use additive tutorial-only migration if required.
Do not modify unrelated tables.

Report exact npx -y supabase db push if needed.

Test reopen consistency.

Report and STOP.
```

# MO-10 — Personalized Overlay QA, Regression & Completion

```text
Execute MO-10 — Personalized Overlay QA, Regression & Completion.

Verify:
1. same style + different face shapes produces relevant differences;
2. same user + different styles produces relevant differences;
3. eye-shape guidance differs where appropriate;
4. kit mode uses owned snapshot only;
5. Foundation is broad/meaningful, not central rectangle;
6. Concealer is targeted, not generic circles;
7. Blush is face-relative;
8. Contour is face-shape-aware;
9. eye overlays are eye-relative;
10. lip overlays are lip-relative;
11. low confidence avoids false precision;
12. Gemini Result preserves identity + previous makeup;
13. Gemini Result contains no tutorial lines/text;
14. Placement↔Result slider still works;
15. standard Recommendation, Gemini 3 Pro preview, My Makeup Kit, Saved/History remain unaffected.

Run:
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
repository-established Android debug build

Real-device test only if available.

Final report:
FEATURE
CURRENT BRANCH
PERSONALIZATION STATUS
CATEGORY STATUSES
CONFIDENCE FALLBACK
GEMINI PROMPT STATUS
IDENTITY
CUMULATIVE MAKEUP
KIT MODE
PERSISTENCE
FILES CREATED/MODIFIED
UNRELATED FILES MODIFIED
ANALYZE/TEST/BUILD/DEVICE
REGRESSION
KNOWN LIMITATIONS
READY FOR RETEST: YES/NO

Then STOP.
```

## Phase Sequence

```text
MO-1  Overlay Accuracy Audit & Scope Lock
MO-2  Personalized Tutorial Input & Step Specification
MO-3  Tutorial Face Geometry Abstraction
MO-4  Face-Attribute & Style Placement Rules
MO-5  Recommendation-to-Placement Metadata Pipeline
MO-6  Personalized Category-Specific Overlay Renderer
MO-7  Overlay Accuracy Validation & Confidence Fallback
MO-8  Gemini Personalized Step Prompt Upgrade
MO-9  Personalized Tutorial Persistence & Snapshot Compatibility
MO-10 Personalized Overlay QA, Regression & Completion
```
