# FACETUNE_TUTORIAL_FIDELITY_AND_GUIDELINES_SOURCE_OF_TRUTH.md

## Purpose
Authoritative source of truth for repairing two confirmed Step-by-Step Tutorial defects:
1. Personalized placement guidelines do not appear.
2. Cumulative tutorial images drift away from the selected canonical final look.

The feature is fixed only when:
**Visible personalized guidelines + stable identity + cumulative makeup + progressive convergence + final-look fidelity.**

## Core Product Contract
The tutorial must reconstruct the selected final makeup result, not reinvent the style from text.

```text
ORIGINAL SELFIE
+ SELECTED CANONICAL FINAL PREVIEW
+ FACE ATTRIBUTES
+ SELECTED LOOK
+ ACTUAL RECOMMENDATION / KIT SNAPSHOT
        ↓
PERSONALIZED TUTORIAL PLAN
        ↓
STEP 1 → STEP 2 → ... → FINAL
        ↓
FINAL TUTORIAL APPEARANCE ≈ CANONICAL FINAL PREVIEW
```

## Confirmed Root Causes
### Missing guidelines
Production planning uses legacy tutorial instructions but does not populate `PersonalizedTutorialStepSpec` / placement metadata. No approved production normalized geometry exists. The renderer receives no primitives to paint.

### Makeup drift
Intermediate images recursively edit the previous generated result. The canonical final preview is not supplied as a target reference, so errors accumulate and the model gradually invents its own interpretation.

### Selected style bug
The tutorial backend must use the real persisted `makeup_style` field rather than the incorrect `style_code` lookup.

### Stale sessions
Old/inconsistent sessions may contain missing specs, empty placement metadata, obsolete plan versions, wrong `total_steps`, or other incompatible state.

## Strict Scope
This is Step-by-Step Tutorial-only work.

Preferred writable scope:
```text
lib/features/step_by_step_tutorial/**
supabase/functions/<tutorial-related-functions>/**
tutorial-only migrations/tests/docs
```

Other FaceTune systems may be read for contracts but not modified without explicit approval:
- standard Face Analysis
- standard Makeup Recommendation
- existing Gemini Pro final preview
- My Makeup Kit core recommendation/preview
- auth
- unrelated Saved Looks / History
- unrelated shared components, navigation, RLS, tables

If an unrelated change appears required: STOP, report exact file/system, reason, smallest safe change, impact, and wait for approval.

## Target Architecture
```text
IMAGE A — ORIGINAL SELFIE
Role: permanent identity reference

IMAGE B — PREVIOUS RESULT
Role: current cumulative makeup state
(Step 1 uses original as starting state)

IMAGE C — CANONICAL FINAL PREVIEW
Role: exact target makeup appearance

PERSONALIZED TUTORIAL STEP SPEC
Role: add only current category

        ↓
TUTORIAL IMAGE MODEL
        ↓
CURRENT CUMULATIVE RESULT
```

The final tutorial step must reuse the canonical premium final preview.

## Tutorial-Only Gemini Geometry & Placement Planning
Preferred safe architecture: add a tutorial-only server-side Gemini planning operation. Do not modify standard `analyze-face` unless explicitly approved.

Gemini may do the visual/makeup reasoning:
- inspect actual selfie
- identify relevant normalized regions
- decide placement
- zones
- paths
- arrows
- direction
- intensity
- technique
- confidence

FaceTune still owns:
- strict schema
- validation
- persistence
- rendering
- security
- retry/error handling
- step order
- cost controls

Prefer ONE planning call per newly created tutorial, then persist/reuse the complete plan.

## Geometry Contract
Use normalized 0.0–1.0 coordinates, never device pixels.

Schema must support primitives such as:
```text
zone: ellipse | polygon | soft_band | region
path: normalized ordered points
arrow: normalized from/to points
confidence: 0.0–1.0
```

Do not fabricate coordinates when Gemini output is absent/invalid.

## Production Personalized Pipeline
Required:
```text
recommendation
+ face attributes
+ selected style
+ Gemini tutorial placement plan
        ↓
PersonalizedTutorialInput
        ↓
PersonalizedTutorialMetadataPipeline
        ↓
PersonalizedTutorialStepSpec
        ↓
placement metadata
        ↓
persist
        ↓
render
```

New compatible sessions must not persist null personalized specs/placement metadata.

## Guideline Requirements
Guidelines are instructions, not decoration.

Foundation:
- broad coverage zones
- multiple blend arrows
- no central strip

Concealer:
- targeted under-eye / relevant central areas
- no random circles

Contour/Bronzer:
- cheekbone/temple/jaw bands and direction

Blush:
- personalized cheek zones and blend direction

Highlighter:
- targeted highlight zones

Eyeshadow:
- lid/crease/outer/inner zones when needed

Eyeliner:
- eye-relative path and wing direction

Brows:
- fill/shape direction

Lips:
- lip-relative coverage/definition

## Validation & Confidence
Validate:
- coordinates within 0.0–1.0
- plausible sizes
- correct left/right relations
- eye guides near eyes
- cheek guides near cheeks
- lip guides near lips
- no unrelated crossing arrows
- category/primitive compatibility

Confidence:
```text
HIGH → precise overlays
MEDIUM → broader/simpler overlays
LOW → no false precision; written or safe broad guidance only
```

## Canonical Final Target Rule
Every intermediate generation must receive the canonical final preview as a distinct target reference.

Image roles:
```text
A = original identity
B = previous cumulative result
C = canonical final target
```

## Target-Convergence Rule
Each step must add only the current category and match that category to the canonical target.

Do not recreate the entire style at each step.
Do not globally reinterpret the face.

Example:
```text
Current step: Blush
Match the target blush placement, color family, finish, intensity,
shape and blending visible in IMAGE C.
Preserve all other completed categories.
```

## Production Gemini Prompt — Source of Truth
Use a versioned backend prompt generated from structured step data:

```text
You are generating ONE cumulative image in a personalized step-by-step makeup tutorial.

You are NOT creating a new makeup look.
You are reconstructing the already-selected CANONICAL FINAL MAKEUP TARGET one category at a time.

IMAGE A — ORIGINAL SELFIE
Permanent identity reference.

IMAGE B — PREVIOUS TUTORIAL RESULT
Current cumulative makeup state when provided.

IMAGE C — CANONICAL FINAL MAKEUP TARGET
Exact selected makeup target.
Use it for makeup appearance only.

Selected style:
{{selected_style}}

Relevant face attributes:
{{face_attributes}}

Step:
{{step_number}}

Category:
{{category}}

Product:
{{product_name_or_category}}

Color:
{{color_name}}

HEX:
{{color_hex}}

Finish:
{{finish}}

Intensity:
{{intensity}}

Placement:
{{placement_description}}

Direction:
{{direction}}

Technique:
{{technique}}

CURRENT STEP — STRICT
Apply ONLY the current makeup category.
Match IMAGE C for this category:
- placement
- color family
- saturation
- intensity
- finish
- shape
- blending
- edge softness

Do not globally reinterpret the style.

CUMULATIVE PRESERVATION — STRICT
Preserve all correctly completed makeup from IMAGE B.
Do not remove, restyle, or intensify unrelated categories.

IDENTITY — STRICT
Remain the same person as IMAGE A.
Do not change face shape, proportions, skin tone, ethnicity, eyes,
nose, lips, hair, expression, pose, crop, camera angle, or background.
No unrelated beautification.

TARGET CONVERGENCE
The current result must become visibly closer to IMAGE C in the current category only.

CLEAN RESULT
Do not draw arrows, guide lines, dots, labels, diagrams, zones, or text.
FaceTune renders guides separately.

OUTPUT
Return ONE clean cumulative Result image:
previous completed makeup + current target-matched category.
```

Omit unavailable optional values cleanly. Never fabricate.

## Style Field
Verify schema and fix production use of the real `makeup_style` field. Do not preserve the typo by creating duplicate fields.

## Stale Session Rules
Treat sessions as stale/incompatible when appropriate:
- missing personalized spec
- empty placement metadata
- missing geometry plan
- unsupported plan/prompt version
- missing canonical target
- inconsistent `total_steps`
- invalid/duplicate/non-contiguous step ordering

Do not invent missing geometry. Regenerate a clean personalized plan through the supported recovery flow.

## total_steps
Require:
```text
session.total_steps == canonical persisted tutorial step count
```

No `STEP 10 OF 1` style inconsistencies.

## Model Decision
Do NOT upgrade to Pro before fixing architecture.

Keep tutorial model/resolution server-configurable.

First fix:
1. production personalized planning
2. tutorial-only geometry planning
3. guidelines
4. style lookup
5. stale sessions
6. canonical target reference
7. convergence prompt

Then retest Flash.

Only after corrected Flash testing compare:
- KEEP FLASH
- KEEP FLASH + HIGHER RESOLUTION
- HYBRID FLASH + PRO
- UPGRADE ALL TUTORIAL RESULTS TO PRO

## Security
Gemini key stays server-side:
```text
Flutter → authenticated Supabase Edge Function → Gemini
```

Validate ownership of selfie, previous result, canonical target and tutorial session.

## Persistence
Persist enough to make reopen deterministic:
- plan version
- prompt version
- geometry plan
- personalized specs
- placement metadata
- canonical target reference
- result paths
- model/resolution
- selected style
- product snapshot
- confidence

Do not re-plan on every reopen.

## Success Criteria
Complete only when:
1. guidelines appear and are meaningful;
2. geometry is real, normalized and validated;
3. production planning populates personalized specs;
4. selected style reaches Gemini;
5. canonical final target is supplied to intermediate generations;
6. each step adds only its category;
7. prior makeup is preserved;
8. identity is stable;
9. penultimate step is visually close to canonical final;
10. final step reuses canonical preview;
11. stale sessions are handled;
12. `total_steps` is correct;
13. protected FaceTune systems are unchanged;
14. Flash is evaluated after architecture repair;
15. Pro is evaluated only if controlled testing still justifies it.
