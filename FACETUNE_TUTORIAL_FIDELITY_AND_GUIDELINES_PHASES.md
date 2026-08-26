# FACETUNE_TUTORIAL_FIDELITY_AND_GUIDELINES_PHASES.md

## Required References
Before every phase read:
- `CODEX_MASTER_GUIDE.md`
- `FACETUNE_STEP_BY_STEP_TUTORIAL_GUIDE.md`
- `FACETUNE_STEP_BY_STEP_TUTORIAL_ROADMAP.md`
- `FACETUNE_PERSONALIZED_MAKEUP_OVERLAY_GUIDE.md`
- `FACETUNE_PERSONALIZED_MAKEUP_OVERLAY_ROADMAP.md`
- `FACETUNE_TUTORIAL_FIDELITY_AND_GUIDELINES_SOURCE_OF_TRUTH.md`

## Mandatory Claude Code Rules
```text
Providing/referencing a complete TF phase is explicit authorization to execute that phase.
Do NOT ask "should I proceed?"
Execute ONLY that TF phase.
Do NOT automatically continue.
Report, then STOP.

Before changes:
git status
git branch --show-current

Required branch:
feature/step-by-step-tutorial

If not, STOP.

main is protected.

Strict scope:
Step-by-Step Tutorial only.

Read unrelated systems if needed, but do not modify them without approval.

If an unrelated modification is required:
STOP and report exact file, reason, smallest safe change and impact.

No opportunistic refactoring.
Do not fabricate tests, builds, device results, deployments, Gemini results or DB state.
```

# TF-1 — Production Personalized Planning Integration
```text
Execute TF-1.

Confirm the production planner defect first.

Wire production tutorial creation to:
PersonalizedTutorialInput
→ PersonalizedTutorialMetadataPipeline
→ PersonalizedTutorialStepSpec
→ placement metadata.

Do not fabricate geometry if TF-2 is not yet available.
Represent missing geometry as an explicit dependency/blocker.

Preserve dynamic ordering.
Do not modify standard Recommendation or Face Analysis.

Tests:
- production planner invokes personalized pipeline;
- valid geometry input creates spec;
- no fake geometry fallback;
- stale/legacy input remains detectable.

Report:
PHASE COMPLETED: TF-1
CURRENT BRANCH
ROOT CAUSE CONFIRMED
FILES MODIFIED
PIPELINE STATUS
SPEC STATUS
PLACEMENT STATUS
GEOMETRY DEPENDENCY
TESTS
UNRELATED FILES MODIFIED
VALIDATION
BLOCKERS
Then STOP.
```

# TF-2 — Tutorial-Only Gemini Geometry & Placement Planning
```text
Execute TF-2.

Create a tutorial-only server-side Gemini planning operation.
Do NOT modify standard analyze-face.

Use ONE planning call per new tutorial/source selfie.

Inputs:
- original selfie
- existing face attributes
- selected style
- full recommendation
- My Makeup Kit snapshot if applicable
- canonical step categories

Return strict structured JSON for complete tutorial placement plan:
- category
- normalized zones
- normalized paths
- normalized arrows
- placement
- direction
- intensity
- technique
- confidence
- color/finish as relevant

Coordinates must be 0.0–1.0.

FaceTune validates, persists and renders.

Reject malformed/out-of-range/impossible geometry.
Never invent fallback coordinates.

Keep model server-configurable.
Gemini key server-side.

Persist valid plan once and reuse.

Tests:
schema parse
bounds
confidence
category coverage
kit integrity
no product invention
invalid-response rejection.

Report:
PHASE COMPLETED: TF-2
CURRENT BRANCH
FUNCTION
MODEL CONFIG
INPUT CONTRACT
OUTPUT SCHEMA
VALIDATION
PERSISTENCE
AI CALL COUNT
SECURITY
FILES CREATED/MODIFIED
TESTS
DEPLOYMENT REQUIRED
MANUAL COMMANDS
UNRELATED FILES MODIFIED
Then STOP.
```

# TF-3 — Production Personalized Guideline Activation
```text
Execute TF-3.

Map persisted Gemini planning output into:
PersonalizedTutorialStepSpec
→ placement metadata
→ overlay renderer.

Ensure meaningful primitives for:
Foundation
Concealer
Contour/Bronzer
Blush
Highlighter
Eyeshadow
Eyeliner
Brows
Lips.

Step 1 Placement = original selfie + current overlay.
Step N Placement = Step N-1 Result + current overlay.
Result side stays clean.

No fake guides when invalid.
Use confidence fallback.

Tests:
category primitives
overlay layering
normalized scaling
Step 1/Step N sources
confidence behavior
Result has no Flutter overlay.

Report and STOP.
```

# TF-4 — makeup_style + Stale Session Integrity
```text
Execute TF-4.

Inspect actual schema.

Fix production selected-style lookup to use real `makeup_style`.

Ensure style reaches:
- tutorial planning
- persisted personalized spec
- tutorial Gemini prompt

Add stale-session validation:
- missing spec
- empty placement metadata
- missing geometry plan
- unsupported plan/prompt version
- missing canonical target
- invalid step numbering
- inconsistent total_steps

Require:
session.total_steps == canonical persisted step count.

Do not fabricate geometry.
Use existing recovery/regeneration flow for stale sessions.

Tests:
style propagation
stale detection
total_steps mismatch
valid modern-session reuse.

Report and STOP.
```

# TF-5 — Canonical Final Target Integration
```text
Execute TF-5.

Every intermediate tutorial generation must receive:

IMAGE A = original selfie / identity
IMAGE B = previous Result / cumulative state (Step > 1)
IMAGE C = canonical selected final preview / target makeup

Step 1:
original + canonical target.

Step N:
original + previous Result + canonical target.

Final step:
reuse canonical final preview.
Do not regenerate final_look.

Make image roles explicit in prompt/request assembly.
Validate private storage ownership.

Tests:
target resolution
Step 1 inputs
Step N inputs
final_look reuse
unauthorized access rejection.

Report and STOP.
```

# TF-6 — Target-Convergence Prompt Upgrade
```text
Execute TF-6.

Modify only tutorial image-generation prompting.
Do not modify premium final-preview prompt.

Use the full versioned convergence prompt from the Source of Truth.

Prompt must:
- define image A identity;
- image B cumulative state;
- image C canonical target;
- say DO NOT create a new look;
- apply ONLY current category;
- match target placement/color/finish/intensity/shape/blending;
- preserve previous completed categories;
- prevent global style reinterpretation;
- preserve identity;
- forbid guide graphics in Result;
- require progressive convergence.

Ensure real makeup_style is included.
Persist prompt version.

Add prompt-builder tests for Step 1, Step N, complexion, blush, eyes, lips, kit mode and missing optional values.

Report and STOP.
```

# TF-7 — Corrected Flash End-to-End Retest
```text
Execute TF-7.

Do NOT switch to Pro.

Confirm deployed/current tutorial model and resolution.

Use a CLEAN newly planned tutorial, not stale data.

Verify guidelines:
Foundation
Concealer
Contour
Blush
Eyes
Lips

Verify fidelity:
identity
skin tone
complexion
contour/blush
eyes
lips
lighting
prior-step preservation
target similarity

Compare penultimate generated step to canonical final target.
Rate discontinuity: LOW / MEDIUM / HIGH.

Run:
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
repository-standard Android debug build

Device test only if actually available.

Report:
PHASE COMPLETED: TF-7
MODEL
RESOLUTION
GUIDELINES
IDENTITY
CUMULATIVE DRIFT
TARGET FIDELITY
STEP-TO-FINAL DISCONTINUITY
FLASH ACCEPTABLE: YES/NO/UNCERTAIN
ARCHITECTURE BLOCKERS
TESTS/BUILD/DEVICE
Then STOP.
```

# TF-8 — Controlled Flash vs Pro Evaluation
```text
Execute TF-8 only after TF-7 architecture works.

Do not change production defaults first.

Compare Flash vs currently supported/configured Pro image model using identical:
- original selfie
- previous result
- canonical target
- step spec
- prompt version
- category
- style
- resolution where possible

Evaluate:
identity
target fidelity
placement
color
eyes
lips
skin tone
prior-step preservation
drift
latency
operational complexity
qualitative cost impact

Return ONE:
KEEP FLASH
KEEP FLASH + HIGHER RESOLUTION
HYBRID FLASH + PRO
UPGRADE ALL TUTORIAL RESULT GENERATION TO PRO

Do not pick Pro just because it looks prettier.
Choose based on target reconstruction + identity + cumulative stability.

Do not permanently change default during this phase.

Report and STOP.
```

# TF-9 — Final Regression & Completion
```text
Execute TF-9.

Verify:
1. clean planning works;
2. Gemini planning occurs once and is reused;
3. personalized specs persist;
4. visible guidelines appear;
5. guidelines are meaningful;
6. selected style persists;
7. canonical target used in intermediate generation;
8. cumulative steps preserve prior makeup;
9. penultimate-to-final transition is coherent;
10. final step reuses canonical preview;
11. stale sessions handled;
12. total_steps correct;
13. reopen does not re-plan unnecessarily;
14. kit mode works;
15. standard Recommendation unchanged;
16. premium final preview unchanged;
17. auth/security unchanged.

Run format/analyze/test/Android debug build.
Device test only if actually available.

Final report:
REPAIR
CURRENT BRANCH
GEOMETRY PLANNER
PRODUCTION PERSONALIZED PIPELINE
VISIBLE GUIDELINES
STYLE PROPAGATION
STALE SESSION HANDLING
CANONICAL TARGET
CONVERGENCE PROMPT
MODEL/RESOLUTION
FLASH/PRO DECISION
IDENTITY
CUMULATIVE FIDELITY
FINAL-LOOK CONTINUITY
KIT MODE
PERSISTENCE
SECURITY
FILES CREATED/MODIFIED
UNRELATED FILES MODIFIED
ANALYZE/TEST/BUILD/DEVICE
KNOWN LIMITATIONS
READY TO MOVE TO NEXT FEATURES: YES/NO

Then STOP.
```

## Phase Order
```text
TF-1 Production Personalized Planning Integration
TF-2 Tutorial-Only Gemini Geometry & Placement Planning
TF-3 Production Personalized Guideline Activation
TF-4 makeup_style + Stale Session Integrity
TF-5 Canonical Final Target Integration
TF-6 Target-Convergence Prompt Upgrade
TF-7 Corrected Flash End-to-End Retest
TF-8 Controlled Flash vs Pro Evaluation
TF-9 Final Regression & Completion
```
