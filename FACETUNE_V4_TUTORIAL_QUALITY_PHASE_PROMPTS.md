# FaceTune — V4 TUTORIAL QUALITY & INSTRUCTIONAL UX PHASE PROMPTS

**Project root:** `C:\Users\Kurt\facetune`  
**Required branch:** `feature/step-by-step-tutorial-v4-ai`  
**Primary device:** POCO X3 GT  

**Final Preview Model — LOCKED:** `gemini-3.1-flash-image`  
**Tutorial Guideline Model — LOCKED:** `gemini-3.1-flash-image`  
**Tutorial Resolution — LOCKED:** `1K`  
**Database / RLS / Storage / Session Architecture / Dynamic Manifest Architecture:** PROTECTED  

---

# HOW TO USE THIS FILE

1. Keep this file beside the V4 Source of Truth files.
2. Use either OpenAI Codex or Claude Code Pro with Opus 5.
3. Run exactly ONE phase at a time.
4. Paste only the prompt for the phase currently being executed.
5. Read and review the completion report before the next phase.
6. Never auto-continue.
7. Never treat a visual-quality claim as proven without real evidence.
8. Never change the model as a “quality fix.”
9. Never change the database as a “UI convenience.”
10. If a phase requires a protected subsystem change, STOP and report first.

---

# MANDATORY READ ORDER FOR EVERY PHASE

Read completely, in order:

```text
1. CODEX_MASTER_GUIDE.md
2. FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_SOURCE_OF_TRUTH.md
3. FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_PHASE_PROMPTS.md
4. FACETUNE_V4_TUTORIAL_QUALITY_SOURCE_OF_TRUTH.md
5. FACETUNE_V4_TUTORIAL_QUALITY_PHASE_PROMPTS.md
6. relevant V4 completion/debug report(s)
7. actual source code / deployed functions / tests relevant to this phase
8. device evidence relevant to this phase
```

Production/device evidence wins over stale assumptions.

---

# MANDATORY SYSTEM ROLE FOR EVERY PHASE

Act simultaneously as:

- Principal Software Engineer
- Principal Software Architect
- Senior Flutter Engineer
- Senior Dart Engineer
- Senior Riverpod Engineer
- Senior Supabase Engineer
- Senior TypeScript / Deno Engineer
- Senior Gemini AI Engineer
- Senior Multimodal Image Engineer
- Senior Prompt Engineer
- Senior AI Systems Engineer
- Senior Mobile UI/UX Engineer
- Senior Accessibility Engineer
- Senior Reliability Engineer
- Senior Privacy Engineer
- Senior Security Engineer
- Senior Regression Engineer
- Senior Integration Test Engineer
- Senior Visual QA Engineer
- Senior Product Quality Engineer
- Senior AI Cost Optimization Engineer
- Senior My Makeup Kit Engineer
- Senior Code Reviewer

Do not behave as a code generator blindly following the prompt.

Inspect first.

Challenge stale assumptions.

Prefer the smallest production-safe change.

---

# GLOBAL HARD LOCKS

Every phase must preserve:

```text
FINAL PREVIEW
→ gemini-3.1-flash-image

TUTORIAL GUIDELINES
→ gemini-3.1-flash-image
→ 1K
```

Do NOT:

- use any other final-preview image model
- add any silent final-preview model fallback
- switch tutorial model
- switch final-preview model
- change tutorial resolution
- change final-preview prompt
- change final-preview request behavior
- change final-preview preprocessing
- change final-preview parser
- redesign database schema
- disable or weaken RLS
- make storage public
- redesign tutorial-session persistence
- redesign dynamic-manifest persistence
- add V3 geometry mapping
- add MediaPipe/OpenCV/TFLite
- add normalized face geometry JSON
- add CustomPainter face guideline geometry
- create cumulative tutorial makeup images
- create fixed nine-step fallback
- create style-to-step hardcoding
- automatically regenerate until a visual result “looks good”
- commit/push/merge/rebase unless explicitly instructed

---

# GLOBAL QUALITY RULE

A tutorial guideline is NOT accepted merely because it looks like a good makeup tutorial.

It must answer:

```text
What EXACTLY changed between
THIS original selfie
and
THIS exact canonical final preview
for
THIS category only?
```

Then it must show only the minimum useful instructional guides needed to reproduce that visible change.

---

# GLOBAL COMPLETION REPORT

Every phase must end with:

```text
PHASE COMPLETED:

BRANCH VERIFIED:

WORKING TREE BEFORE:

OBJECTIVE ACHIEVED:

PROTECTED BASELINE STATUS:
Final Preview:
Tutorial Session:
Dynamic Manifest:
Storage:
Flutter Tutorial Flow:

FINAL PREVIEW MODEL:
gemini-3.1-flash-image

TUTORIAL MODEL:
gemini-3.1-flash-image

TUTORIAL RESOLUTION:
1K

MODEL CHANGES:
NONE

DATABASE CHANGES:
NONE / STOPPED BEFORE CHANGE

RLS CHANGES:
NONE

STORAGE CHANGES:
NONE

SESSION ARCHITECTURE CHANGES:
NONE

DYNAMIC MANIFEST ARCHITECTURE CHANGES:
NONE

FILES CREATED:

FILES MODIFIED:

FILES DELETED:

DEPENDENCIES ADDED / REMOVED:

PROMPT VERSION BEFORE:

PROMPT VERSION AFTER:

EDGE FUNCTIONS DEPLOYED:
None / exact list

FLUTTER CHANGES:

STANDARD MODE CHANGES:

MY MAKEUP KIT CHANGES:

GLOBAL THEME CHANGES:

VISUAL QA EVIDENCE:

SECURITY CHECK:

COST / DUPLICATE-CALL CHECK:

DART FORMAT:

FLUTTER ANALYZE:

FLUTTER TEST:

ANDROID BUILD:

REAL DEVICE STATUS:

KNOWN LIMITATIONS:

ASSUMPTIONS NOT PROVEN:

MANUAL ACTION REQUIRED:

NEXT RECOMMENDED PHASE:

STOP CONFIRMATION:
No later phase was implemented automatically.
```

A vague report is not acceptable.

---

# V4-QA-0 — BASELINE FREEZE & EVIDENCE CAPTURE

Read all mandatory authority files completely before making changes.

Implement only:

**V4-QA-0 — BASELINE FREEZE & EVIDENCE CAPTURE**

Then STOP.

## Objective

Freeze the known-good V4 system before quality work begins.

This phase is primarily read-only.

Prove the current working state and document the exact visual-quality problems that later phases are authorized to address.

## Before coding

- verify branch
- run `git status`
- inspect current prompt implementation
- inspect current category-specific prompt fragments
- inspect current tutorial Flutter UI
- inspect current theme handling
- inspect current recommendation/product presentation
- inspect current dynamic-manifest behavior
- inspect current tutorial step domain/data contracts
- inspect current regenerate flow
- record current deployed function versions where available
- confirm real device evidence showing final preview + tutorial steps working

## Implement

Create only a privacy-safe quality baseline report containing:

- protected working flow map
- current prompt version(s)
- current guide visual vocabulary
- current UI information hierarchy
- current theme behavior
- current shade/finish/intensity behavior
- current final-look presentation
- current regenerate behavior
- current dynamic-manifest evidence
- representative screenshot observations
- exact smallest code surfaces later phases should modify

Classify current visual findings using:

```text
PASS
ACCEPTABLE
FAIL
NOT TESTED
```

At minimum assess:

- Blush
- Eyeshadow
- Eyeliner
- Lips

and note observations for:

- Foundation
- Concealer
- Contour/Bronzer
- Highlighter
- Eyebrows

## Non-negotiable rules

- no prompt change
- no code change except explicitly requested baseline report
- no deployment
- no model change
- no database change
- no UI redesign
- no theme change
- no regeneration loop
- do not infer dynamic-manifest quality from Full Glam alone

## Do NOT implement

- Guide Key
- new instructions
- prompt optimization
- shade/finish/intensity changes
- theme fixes
- new dynamic-manifest rules
- new feedback UI

## Validation

Run at minimum:

```powershell
git branch --show-current
git status
flutter analyze
```

Do not run paid generations solely for this audit unless explicit device evidence is required and approved.

## Done when

- current system is mapped from real code
- current prompt versions are known
- representative visual issues are documented
- protected files/functions are identified
- V4-QA-1 implementation boundary is explicit
- no production behavior changed

## Completion report additions

```text
BASELINE REPORT:
CURRENT TUTORIAL PROMPT VERSION:
CURRENT GUIDE TYPES:
CURRENT THEME BEHAVIOR:
CURRENT PRODUCT METADATA BEHAVIOR:
REPRESENTATIVE CATEGORY FINDINGS:
DYNAMIC MANIFEST EVIDENCE:
PROTECTED FILES / FUNCTIONS:
```

Then STOP.

---

# V4-QA-1 — INSTRUCTION & GUIDE CONTRACT

Read all mandatory authority files completely before making changes.

Implement only:

**V4-QA-1 — INSTRUCTION & GUIDE CONTRACT**

Then STOP.

## Objective

Create typed, maintainable contracts for guide semantics and instructional presentation without changing the database or generated guideline prompt behavior yet.

The system must have a shared controlled vocabulary for:

```text
● Start / Anchor
solid line = Placement / Boundary / Path
dashed line = Blend / Fade Zone
→ Direction
```

and a typed instructional structure for:

- short goal
- 2–4 numbered instruction items
- guide symbol/type reference
- shade
- HEX
- finish
- intensity
- product presentation source

## Before coding

Inspect:

- existing tutorial domain models
- existing recommendation metadata
- existing immutable kit snapshot metadata
- existing step presentation model
- current repository/use-case contracts
- current UI mapping
- whether any existing typed instruction structure can be reused

## Implement

Create the minimum clean contracts necessary, conceptually equivalent to:

```text
TutorialGuideType
- start_anchor
- placement_boundary
- blend_zone
- direction

TutorialInstructionItem
- sequence
- guide_type
- short_title
- instruction

TutorialInstructionPresentation
- goal
- items
- shade
- hex
- finish
- intensity
- product presentation source
```

Use project naming conventions rather than blindly copying these names.

Requirements:

- immutable where practical
- no raw unvalidated maps in presentation
- Standard Mode remains brand-neutral
- My Makeup Kit product identity comes only from immutable validated snapshot
- missing optional metadata is representable truthfully
- no invented product/shade/finish/intensity

## Critical numbering rule

Do NOT create a new geometry system merely to place `① ② ③` on the face.

Initial numbering belongs to the Flutter instruction list.

Guide symbols connect instructions to the visual image.

If exact spatial numbered overlays require coordinate metadata or face geometry:

STOP and report.

Do not add it in this phase.

## Non-negotiable rules

- no DB migration
- no RLS change
- no storage change
- no Gemini prompt change
- no model change
- no dynamic-manifest change
- no generated text in guideline images
- no V3 geometry

## Tests

Test at minimum:

- controlled guide vocabulary
- invalid guide type rejected
- instruction ordering
- 2–4 instruction representability
- optional shade
- optional HEX
- optional finish
- optional intensity
- Standard brand-neutral product presentation
- My Kit snapshot presentation
- missing metadata does not cause invention

Run:

```powershell
dart format .
flutter analyze
flutter test
```

## Done when

- typed instructional contracts exist
- contracts do not require DB changes
- both modes are representable
- guide vocabulary is controlled
- no production AI behavior changed

Then STOP.

---

# V4-QA-2 — REPRESENTATIVE PROMPT PRECISION PILOT

Read all mandatory authority files completely before making changes.

Implement only:

**V4-QA-2 — REPRESENTATIVE PROMPT PRECISION PILOT**

Then STOP.

## Objective

Improve prompt discipline for ONLY:

```text
Blush
Eyeshadow
Eyeliner
Lips
```

These four categories are the representative quality gate.

Do NOT modify the remaining five category prompt behaviors in this phase.

## Protected baseline

Must remain:

```text
Final Preview
→ gemini-3.1-flash-image

Tutorial
→ gemini-3.1-flash-image
→ 1K
```

## Prompt requirement

Every representative category must explicitly enforce:

```text
IMAGE A = ORIGINAL SELFIE
IMAGE B = CANONICAL FINAL PREVIEW

Compare A versus B.

Analyze CURRENT CATEGORY ONLY.

Determine what visibly changed in THIS category.

Use the final preview as visual authority.

Do not substitute generic makeup placement.

Render the minimum useful instructional guides on Image A.

DO NOT APPLY MAKEUP.
DO NOT beautify.
DO NOT recolor the face.
DO NOT change other categories.
```

## Blush-specific analysis

Ask explicitly:

- exact cheek height
- inward extent
- outward extent
- strongest concentration
- blend direction
- visible intensity

Reject generic “apple of cheeks” logic unless visually supported.

## Eyeshadow-specific analysis

Ask explicitly:

- lid zone
- crease
- outer corner / outer-V
- inner corner if visible
- blend direction
- bilateral relationship

Hard negative rules:

```text
NO EYESHADOW PIGMENT
NO EYELID DARKENING
NO CREASE TINT
NO SHIMMER
```

## Eyeliner-specific analysis

Ask explicitly:

- lash-line start
- thickness
- curvature
- outer transition
- wing angle
- wing length
- endpoint

Hard rule:

```text
DO NOT APPLY BLACK EYELINER.
DRAW ONLY THE INSTRUCTIONAL PATH / GUIDE.
```

## Lips-specific analysis

Ask explicitly:

- natural border
- target border
- Cupid's bow
- corners
- lower lip
- overline only if visible

Hard rule:

```text
NO LIPSTICK
NO GLOSS
NO LIP TINT
```

## Minimum useful geometry

Prompt must prefer:

```text
few meaningful guide elements
```

over:

```text
dense decorative geometry
```

## Before coding

- inspect current shared prompt builder
- inspect category prompt fragments
- identify one maintainable place for shared negative contract
- identify category-specific fragment boundaries
- record current prompt version

## Implement

- refactor only as needed for maintainable prompt composition
- add shared canonical-preview fidelity contract
- add shared guideline-only negative contract
- update four representative category fragments
- version prompt change
- add tests proving required prompt clauses are present
- preserve all non-representative categories untouched

## Do NOT implement

- UI changes
- new instruction cards
- theme changes
- dynamic-manifest changes
- remaining five category prompt changes
- model/resolution changes
- DB/storage/RLS changes

## QA protocol

Do not regenerate all nine categories.

Evaluate the representative four only.

Use:

```text
PASS
ACCEPTABLE
FAIL
```

Dimensions:

- final-preview fidelity
- category isolation
- guideline-only compliance
- identity preservation
- placement accuracy
- direction accuracy
- shape fidelity
- simplicity
- bilateral consistency
- POCO X3 GT readability

If device is unavailable, do not fabricate visual success.

## Deployment rule

Deploy only the exact tutorial function(s) required for prompt changes.

Do not deploy final-preview functions.

Audit deployment bundle before deployment.

## Done when

- representative prompt contract is versioned
- no model/resolution change occurred
- four categories have real QA evidence when device available
- no other category was silently modified
- no infrastructure change occurred

## Completion report additions

```text
REPRESENTATIVE CATEGORIES:
PROMPT VERSION BEFORE:
PROMPT VERSION AFTER:
BLUSH QA:
EYESHADOW QA:
EYELINER QA:
LIPS QA:
GUIDELINE-ONLY FAILURES:
IDENTITY DRIFT:
GENERIC-PLACEMENT OBSERVATIONS:
MINIMUM-GEOMETRY OBSERVATIONS:
```

Then STOP.

---

# V4-QA-3 — REMAINING CATEGORY PROMPT PRECISION

Read all mandatory authority files completely before making changes.

Implement only:

**V4-QA-3 — REMAINING CATEGORY PROMPT PRECISION**

Then STOP.

## Entry gate

Do not start this phase unless V4-QA-2 produced:

```text
PASS
or
PASS WITH EXPLICITLY ACCEPTED MINOR LIMITATIONS
```

for the representative prompt principles.

## Objective

Propagate the approved prompt discipline to:

```text
Foundation
Concealer
Contour / Bronzer
Highlighter
Eyebrows
```

## Foundation rules

- infer actual visible coverage
- do not automatically outline the whole face
- use minimum useful coverage/blend guides
- no foundation pigment

## Concealer rules

- only show areas visibly changed
- no automatic generic triangles
- no concealer pigment

## Contour/Bronzer rules

- cheekbone/temple/jaw/nose only when visually supported
- no generic contour map
- no brown pigment

## Highlighter rules

- only visible highlight zones
- no automatic classic highlight map
- no shimmer pigment

## Eyebrow rules

- start/arch/tail/stroke direction only as needed
- reduce excessive construction lines
- no brow fill

## Implement

- reuse V4-QA-2 shared prompt contracts
- add category-specific visual-difference questions
- add category-specific negative clauses
- maintain minimum useful geometry
- version prompt change if material
- update tests

## Do NOT implement

- UI changes
- manifest changes
- theme changes
- model changes
- resolution changes
- DB/RLS/storage changes

## QA

Evaluate each category with:

```text
PASS
ACCEPTABLE
FAIL
```

Do not approve a category merely because the image looks professional.

Ask:

> Would following this guide move the user toward reproducing THIS exact final preview?

## Done when

- all nine category prompt fragments follow the same quality architecture
- no category uses generic placement as primary authority
- guideline-only negative contract applies to every category
- no preview regression

Then STOP.

---

# V4-QA-4 — FLUTTER INSTRUCTIONAL UX & GLOBAL THEME

Read all mandatory authority files completely before making changes.

Implement only:

**V4-QA-4 — FLUTTER INSTRUCTIONAL UX & GLOBAL THEME**

Then STOP.

## Objective

Turn the working tutorial from a collection of guideline images into a clear teaching experience.

Implement:

- compact Guide Key
- numbered HOW TO APPLY instructions
- guide-symbol references
- YOUR GOAL
- SHADE
- HEX when available
- FINISH when available
- INTENSITY when available
- Light/Dark/System inheritance
- responsive layout
- accessibility-safe presentation

## Critical Guide Key

Render with Flutter:

```text
● Start
━ Placement
- - Blend Zone
→ Direction
```

Exact wording may follow design-system conventions.

## Instruction rule

Every instruction must reference a visible guide symbol or matching guide label.

Bad:

```text
Blend upward.
```

Good:

```text
Follow the upward arrows → and blend toward the temple.
```

## Numbering rule

Flutter owns instruction numbering.

Example:

```text
① Start ●
...

② Blend →
...

③ Stay inside ━
...
```

Do not add coordinate geometry merely to position numbers on the face.

## Theme rule

The tutorial must inherit the application's global appearance.

Test:

```text
Light
Dark
System
```

Do not force dark mode.

Use existing:

- ThemeData
- ColorScheme
- design tokens
- typography
- buttons
- spacing
- surfaces

Do not create tutorial-only theme state.

## Data authority

Standard Mode:

- brand-neutral recommendation metadata

My Makeup Kit:

- immutable validated product snapshot

Do not invent missing fields.

## Database rule

NO migration.

If the implementation requires persistence not supported by current architecture:

STOP.

Do not invent a schema change.

## Do NOT implement

- prompt changes
- model changes
- manifest changes
- storage changes
- session changes
- V3 geometry
- opacity control requiring flattened-image decomposition

## Tests

At minimum:

- Guide Key rendering
- instruction ordering
- symbol references
- missing optional metadata
- Standard Mode brand neutrality
- My Kit exact snapshot display
- Light theme
- Dark theme
- System theme
- large text / overflow
- POCO X3 GT layout when available

Run:

```powershell
dart format .
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/development.json
```

## Done when

- user can understand what every guide symbol means
- instructions are visibly tied to guide semantics
- no forced dark mode remains
- both recommendation modes display truthful metadata
- no infrastructure change occurred

## Completion report additions

```text
GUIDE KEY:
INSTRUCTION UI:
LIGHT THEME:
DARK THEME:
SYSTEM THEME:
SHADE DISPLAY:
FINISH DISPLAY:
INTENSITY DISPLAY:
ACCESSIBILITY:
```

Then STOP.

---

# V4-QA-5 — PRODUCT, FINAL-LOOK & VIEWING EXPERIENCE

Read all mandatory authority files completely before making changes.

Implement only:

**V4-QA-5 — PRODUCT, FINAL-LOOK & VIEWING EXPERIENCE**

Then STOP.

## Objective

Improve tutorial usability without changing AI generation or infrastructure.

Implement/validate:

- Standard Mode recommendation card
- My Makeup Kit exact owned-product card
- canonical final-look reference on every step
- category-aware zoom/crop where safe
- guide show/hide only if the existing rendering architecture truthfully supports it

## Standard Mode card

May show only validated brand-neutral metadata:

```text
SHADE
Warm Rose

HEX
#B65A68

FINISH
Soft Satin

INTENSITY
Medium
```

No commercial brand recommendations.

## My Makeup Kit card

Show exact immutable snapshot data only.

Do not fetch mutable current kit as historical authority.

Do not invent missing product metadata.

## Final-look reference

Every step must provide clear access to:

```text
YOUR FINAL LOOK
[ canonical final preview ]
```

Do not generate a second final image.

## Category-aware zoom

Use Flutter presentation of existing images.

Do not create extra AI generations.

Do not remove needed facial context.

## Show / Hide Guidelines gate

Before implementing, prove whether guideline rendering is a separate overlay or a flattened AI image.

If flattened:

```text
TRUE HIDE/SHOW MAY NOT BE POSSIBLE
```

Do not fake it.

Do not add a V3 geometry system.

If true hide/show cannot be implemented safely:

report it as deferred.

## Opacity

Same rule.

Do not claim an opacity slider can separate a flattened AI image.

No geometry redesign.

## Do NOT implement

- AI prompt changes
- model changes
- database migrations
- manifest changes
- storage changes

## Tests

- Standard product card
- My Kit product card
- final-look reference
- zoom behavior
- orientation/layout
- no extra paid generation
- no mutable-kit historical drift
- show/hide truthfulness

## Done when

- user can see what to use
- user can see final target
- zoom improves small-feature usability without new generation
- no fake overlay controls exist

Then STOP.

---

# V4-QA-6 — DYNAMIC MANIFEST MULTI-STYLE VALIDATION

Read all mandatory authority files completely before making changes.

Implement only:

**V4-QA-6 — DYNAMIC MANIFEST MULTI-STYLE VALIDATION**

Then STOP.

## Objective

Prove that dynamic inclusion is genuinely visual rather than style-template-driven or fixed-nine behavior.

This phase is QA-first.

## Required test looks

Where available in the app:

```text
Full Glam
Soft Glam
Natural
```

plus at least one case containing a visibly absent/subtle supported category.

Do not invent styles that are not actually available.

## Core rule

Never hardcode:

```text
Full Glam → 9
Soft Glam → 6
Natural → 4
```

Counts are evidence outcomes, not implementation rules.

## Test matrix

For each tested canonical preview, capture:

- manifest category
- present / absent / uncertain
- included / excluded
- short visual rationale
- whether recommendation context was consulted
- whether inclusion matched visible evidence
- final deterministic order

Test both:

- Standard Mode
- My Makeup Kit Mode where practical

For My Kit additionally verify:

```text
visual presence
∩
validated selected product mapping
```

and mismatch handling.

## Non-negotiable rules

- no manifest schema redesign
- no DB change
- no fixed-nine fallback
- no style-to-step template
- no model substitution
- no arbitrary uncertain→present conversion

## Prompt changes

Only change manifest prompt if a repeated, evidenced classification failure is proven.

Any material prompt change must be versioned.

Do not optimize from one ambiguous sample.

## QA outcome

Report:

```text
PASS
PASS WITH RESTRICTIONS
FAIL
```

Do not fabricate accuracy percentages unless the benchmark sample and counting method are explicitly documented.

## Done when

- Full Glam evidence exists
- lighter-look evidence exists
- absent category omission is proven at least once
- uncertain behavior is observed/tested
- no fixed-nine behavior is found
- both mode rules remain intact

## Completion report additions

```text
LOOKS TESTED:
MANIFEST SAMPLE COUNT:
FULL GLAM FINDINGS:
SOFT GLAM FINDINGS:
NATURAL FINDINGS:
ABSENT CATEGORY PROOF:
UNCERTAIN CATEGORY PROOF:
MY KIT INTERSECTION FINDINGS:
MISMATCH FINDINGS:
MANIFEST PROMPT CHANGE:
RECOMMENDATION:
```

Then STOP.

---

# V4-QA-7 — VISUAL QA SCORECARD & REGENERATION FEEDBACK

Read all mandatory authority files completely before making changes.

Implement only:

**V4-QA-7 — VISUAL QA SCORECARD & REGENERATION FEEDBACK**

Then STOP.

## Objective

Establish a repeatable quality process and add safe regeneration feedback without introducing private-image telemetry or automatic regeneration.

## Scorecard

Use:

```text
PASS
ACCEPTABLE
FAIL
```

Dimensions:

- Final-preview fidelity
- Category isolation
- Guideline-only compliance
- Identity preservation
- Placement accuracy
- Direction accuracy
- Shape fidelity
- Simplicity
- Instruction ↔ Guide agreement
- Shade accuracy
- Finish accuracy
- Intensity accuracy
- Bilateral consistency
- Readability
- Final-look usability

## Human QA rule

Do not pretend these visual dimensions are perfectly automatable.

Human visual review is required.

Automated tests may verify contracts, presence, types, prompt clauses, and UI behavior.

## Regeneration feedback

When the user explicitly chooses:

```text
Draw this step again
```

optionally offer:

- Placement looks wrong
- Guide is unclear
- Face changed
- Too many guidelines
- Try another version

Requirements:

- selecting a reason must not automatically fire generation until the user confirms according to the current UX
- no private image content logged
- no signed URLs logged
- no full prompt logging
- preserve quota/idempotency
- preserve explicit regeneration semantics
- feedback does not alter model/resolution

## Database gate

Inspect whether existing telemetry/state can support the feedback safely.

If persistence requires a schema migration:

STOP.

Do not create it without explicit approval.

A non-persisted local/UI-only feedback flow is acceptable only if it still has real user value and does not pretend to create analytics.

## Do NOT implement

- automatic retries for visual quality
- unbounded regeneration
- hidden background regeneration
- model fallback
- 0.5K testing
- DB migration without approval

## Done when

- QA scorecard is documented and usable
- regeneration feedback is safely implemented or explicitly deferred with evidence
- no cost-abuse path added

Then STOP.

---

# V4-QA-8 — END-TO-END QUALITY BASELINE LOCK

Read all mandatory authority files completely before making changes.

Implement only:

**V4-QA-8 — END-TO-END QUALITY BASELINE LOCK**

Then STOP.

## Objective

Prove the refined tutorial quality system works end-to-end and lock the accepted baseline.

New feature development is forbidden except minimal remediation of defects proven in this phase.

## Required journeys

### Standard Mode

```text
Auth
↓
Selfie
↓
Analysis
↓
Style
↓
Brand-neutral recommendation
↓
gemini-3.1-flash-image final preview
↓
Dynamic manifest
↓
gemini-3.1-flash-image @ 1K tutorial
↓
Guide Key
↓
HOW TO APPLY
↓
Shade / Finish / Intensity
↓
Final-look reference
↓
Reopen / reuse
```

### My Makeup Kit

```text
Owned products
↓
Selfie
↓
Analysis
↓
Style
↓
Owned-products-only recommendation
↓
Server validation
↓
Immutable snapshot
↓
gemini-3.1-flash-image final preview
↓
Dynamic manifest
↓
gemini-3.1-flash-image @ 1K tutorial
↓
Exact owned product details
↓
Guide Key + Instructions
↓
Final-look reference
↓
Reopen / reuse
```

## Required quality evidence

At minimum validate:

- representative four categories
- remaining five categories
- Full Glam
- a lighter style
- absent category omission
- guideline-only compliance
- identity preservation
- instruction agreement
- Standard product authority
- My Kit snapshot authority
- Light theme
- Dark theme
- System theme
- POCO X3 GT readability
- reopen without unnecessary regeneration
- final preview unchanged

## Regression guard

Explicitly verify no regression in:

- authentication
- selfie flow
- face analysis
- recommendation
- final preview quality
- before/after
- save/history
- tutorial persistence
- dynamic manifest
- private storage
- RLS
- navigation

## Hard locks

Final preview remains:

```text
gemini-3.1-flash-image
```

Tutorial remains:

```text
gemini-3.1-flash-image
1K
```

## Validation

Run:

```powershell
dart format .
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/development.json
flutter run --dart-define-from-file=config/development.json
```

when device is available.

## Quality decision

Final recommendation must be exactly one of:

```text
BASELINE ACCEPTED
BASELINE ACCEPTED WITH RESTRICTIONS
BASELINE REJECTED
```

Explain evidence.

Do not declare acceptance merely because tests are green.

## Completion report additions

```text
STANDARD MODE E2E:
MY MAKEUP KIT E2E:
INCOMPLETE KIT:
FULL GLAM:
LIGHTER STYLE:
ABSENT CATEGORY OMISSION:
REPRESENTATIVE CATEGORY QA:
REMAINING CATEGORY QA:
GUIDELINE-ONLY:
IDENTITY PRESERVATION:
INSTRUCTION AGREEMENT:
STANDARD PRODUCT AUTHORITY:
MY KIT PRODUCT AUTHORITY:
LIGHT THEME:
DARK THEME:
SYSTEM THEME:
POCO X3 GT:
REOPEN / REUSE:
FINAL PREVIEW REGRESSION:
PAID-CALL DUPLICATION:
QUALITY DECISION:
BASELINE ACCEPTED / BASELINE ACCEPTED WITH RESTRICTIONS / BASELINE REJECTED
```

Then STOP.

Do not start a cost-optimization or 0.5K phase automatically.
