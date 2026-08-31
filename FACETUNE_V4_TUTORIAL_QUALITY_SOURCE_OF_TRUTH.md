# FaceTune — V4 TUTORIAL QUALITY & INSTRUCTIONAL UX SOURCE OF TRUTH

**Project Path:** `C:\Users\Kurt\facetune`  
**Project Name:** FaceTune  
**Tagline:** Your AI Makeup Artist  
**Primary Platform:** Android  
**Primary Test Device:** POCO X3 GT  
**Framework:** Flutter  
**Language:** Dart  
**Backend:** Supabase  
**State Management:** Riverpod  
**Architecture:** Clean Architecture + Repository Pattern + Feature-First Structure  
**Active Branch:** `feature/step-by-step-tutorial-v4-ai`  

**Canonical Final Preview Renderer — LOCKED:** `gemini-3.1-flash-image`  
**Tutorial Guideline Renderer — LOCKED:** `gemini-3.1-flash-image`  
**Tutorial Guideline Resolution — LOCKED:** `1K`  
**Manifest Analyzer:** preserve current deployed configuration; do not substitute during this refinement track  
**Recommendation Modes:** `standard` + `my_makeup_kit`  

**Status entering this track:**  
- final makeup preview works on device  
- tutorial session/persistence works  
- dynamic manifest works for the tested Full Glam flow  
- tutorial guideline generation works  
- storage works  
- Flutter tutorial navigation works  
- current work is QUALITY REFINEMENT, not infrastructure recovery  

---

# 0. PURPOSE

This document is the highest authority for the **V4 Tutorial Quality & Instructional UX refinement track**.

It exists because the tutorial is now functional. The milestone is no longer:

> Does tutorial generation work?

The milestone is now:

> **Does FaceTune teach the user how to reconstruct THIS exact final makeup look using clear, reference-grounded instructions, without inventing generic placement or applying makeup inside the tutorial guideline image?**

This track must improve:

1. visual fidelity to the canonical final preview
2. guideline-only compliance
3. dynamic-manifest confidence through multi-style QA
4. guide-to-instruction clarity
5. shade / finish / intensity presentation
6. final-look reference usability
7. global theme consistency
8. visual QA discipline
9. regeneration feedback and controlled quality telemetry

This track does **not** authorize a database redesign, model switch, RLS rewrite, storage redesign, session redesign, manifest redesign, or final-preview rewrite.

---

# 1. AUTHORITY ORDER

Before ANY implementation in this quality track, the coding agent must read, in order:

1. `CODEX_MASTER_GUIDE.md`
2. `FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_SOURCE_OF_TRUTH.md`
3. `FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_PHASE_PROMPTS.md`
4. `FACETUNE_V4_TUTORIAL_QUALITY_SOURCE_OF_TRUTH.md`
5. `FACETUNE_V4_TUTORIAL_QUALITY_PHASE_PROMPTS.md`
6. relevant V4 completion/debug reports
7. actual current source code, migrations, tests, deployed functions, and device evidence relevant to the phase

Authority rule:

- this file governs the new tutorial-quality refinement requirements
- the original V4 Source of Truth continues to govern the underlying V4 architecture
- production/device evidence wins over stale reports
- actual code wins over assumptions about what the code “should” do
- no phase prompt may silently widen its own scope

---

# 2. PROTECTED WORKING BASELINE

The following systems are considered PROTECTED because they are currently working:

```text
SELFIE
↓
FACE ANALYSIS
↓
STYLE
↓
RECOMMENDATION
↓
gemini-3.1-flash-image
↓
CANONICAL FINAL MAKEUP PREVIEW
✅ WORKING

CANONICAL FINAL PREVIEW
↓
TUTORIAL SESSION
↓
DYNAMIC MANIFEST
↓
TUTORIAL STEP GENERATION
↓
gemini-3.1-flash-image @ 1K
↓
PRIVATE STORAGE
↓
FLUTTER TUTORIAL FLOW
✅ WORKING
```

This quality track must not destabilize those systems merely to improve visuals.

---

# 3. HARD LOCKS — DO NOT CHANGE

## 3.1 Model locks

Final preview:

```text
gemini-3.1-flash-image
```

Tutorial guideline renderer:

```text
gemini-3.1-flash-image
```

Tutorial guideline resolution:

```text
1K
```

Do NOT:

- switch the final preview away from `gemini-3.1-flash-image`
- add any silent final-preview model fallback
- silently substitute another image model
- switch tutorial generation to another model
- change tutorial resolution to 0.5K, 2K, or 4K
- create per-category model substitutions
- let Flutter choose the model or resolution

## 3.2 Infrastructure locks

Do NOT change in this refinement track unless a later explicit user-approved phase says otherwise:

- database schema
- existing V4 tables
- RLS policies
- storage bucket visibility
- storage ownership model
- tutorial-session architecture
- canonical-source resolution architecture
- dynamic-manifest architecture
- current step persistence architecture
- recommendation ownership rules
- immutable My Makeup Kit snapshots
- authentication/JWT behavior
- existing on-demand generation architecture
- retry architecture
- existing final-preview request behavior
- existing final-preview prompt
- existing final-preview preprocessing
- existing final-preview parser
- existing final-preview storage behavior

If a requested quality feature appears to require one of these protected changes, STOP and report the dependency before changing it.

---

# 4. FOUR QUALITY PILLARS

Every quality decision must support at least one of these pillars.

## PILLAR 1 — VISUAL FIDELITY

The guideline must reconstruct the exact visible makeup change in the canonical final preview.

The model must not answer:

> What is a sensible makeup tutorial for this category?

It must answer:

> **What visibly changed between THIS original selfie and THIS exact canonical final preview for THIS category only?**

## PILLAR 2 — GUIDELINE-ONLY COMPLIANCE

The tutorial output must be:

```text
ORIGINAL SELFIE
+
INSTRUCTIONAL GUIDELINES ONLY
```

Not:

```text
ORIGINAL SELFIE
+
PARTIAL MAKEUP
+
GUIDELINES
```

## PILLAR 3 — DYNAMIC MANIFEST VALIDATION

The supported vocabulary is controlled, but inclusion must remain visually derived.

```text
ORIGINAL SELFIE
+
CANONICAL FINAL PREVIEW
↓
PRESENT / ABSENT / UNCERTAIN
↓
INCLUDE ONLY VALID RELEVANT STEPS
```

## PILLAR 4 — INSTRUCTIONAL UX

The guideline image shows **WHERE**.

Flutter text explains **HOW**.

Recommendation / kit snapshot data explains **WHAT TO USE**.

The canonical final preview shows **WHAT TO ACHIEVE**.

---

# 5. CENTRAL ACCEPTANCE RULES

A tutorial guideline is **not successful merely because it is cosmetically sensible, attractive, or plausible**.

It is successful only when it is specifically grounded in the visible difference between:

- Image A = the user's original selfie
- Image B = the exact canonical final preview

A tutorial guideline must preserve the original selfie and add instructional guidance only.

Any unintended:

- makeup application
- beautification
- skin smoothing
- face reshaping
- eye reshaping
- nose reshaping
- lip reshaping
- hair alteration
- background alteration
- lighting reinterpretation
- unrelated category leakage

is a quality failure unless the only visible difference is the instructional overlay.

The number of tutorial steps must emerge from visual evidence. The supported vocabulary may be fixed; inclusion must remain dynamic.

---

# 6. INPUT AUTHORITY FOR QUALITY REFINEMENT

For visual placement:

1. Canonical Final Preview — highest visual target authority
2. Original Selfie — highest identity/rendering-base authority
3. Current Tutorial Category — scope limiter
4. Validated Look Plan / immutable product snapshot — supporting semantic/product authority
5. Recommendation — supporting context only
6. Face analysis — supporting context only
7. Selected style — supporting context only

If the selected style says “Full Glam” but the final preview contains a short subtle eyeliner wing, the tutorial must teach the short subtle wing.

Generic makeup conventions never override the final preview.

---

# 7. VISUAL FIDELITY CONTRACT BY CATEGORY

## 7.1 Foundation

Ask:

- what visible coverage changed?
- which regions need evenness?
- what areas remain natural?
- what blend direction is supported by the visible result?
- is a full-face boundary actually justified?

Do not automatically outline the whole face merely because foundation is commonly applied broadly.

Acceptance question:

> Does this guide correspond to the coverage visible in THIS final preview?

## 7.2 Concealer

Ask:

- is under-eye brightening visible?
- is center-face brightening visible?
- are spot areas visibly corrected?
- what boundaries and blend directions are actually supported?

Do not automatically draw generic under-eye triangles or center-face marks unless the comparison supports them.

## 7.3 Contour / Bronzer

Ask:

- where is visible sculpting or warmth added?
- cheekbone?
- temple?
- jaw?
- nose only if visibly present?
- how far does each area extend?
- what direction should it blend?

Do not draw the standard “3-shape contour map” unless the preview actually supports it.

## 7.4 Blush

Ask:

- exact cheek height
- inward extent
- outward extent
- strongest concentration
- blend direction
- visible intensity

Acceptance question:

> Does the placement match THIS preview's exact cheek position?

## 7.5 Highlighter

Ask:

- which highlight zones visibly changed?
- how narrow/broad are they?
- how intense are they?
- are classic highlight zones actually visible?

Do not mark every conventional highlight zone automatically.

## 7.6 Eyebrows

Ask:

- did brow fullness visibly change?
- start point
- arch emphasis
- tail direction
- stroke direction
- what is truly necessary to reconstruct the preview?

Avoid architectural-looking cross-lines and excessive construction geometry.

## 7.7 Eyeshadow

Ask:

- lid coverage
- crease boundary
- outer-corner / outer-V extent
- inner-corner treatment
- blend direction
- intensity
- bilateral consistency

Acceptance question:

> Does the shape match THIS preview's lid, crease, and outer corner?

Hard rule:

```text
NO EYESHADOW PIGMENT
NO EYELID DARKENING
NO SHIMMER
NO TINTED CREASE
```

## 7.8 Eyeliner

Ask:

- lash-line start
- lash-line thickness
- outer-corner transition
- wing angle
- wing length
- curvature
- endpoint

Acceptance question:

> Does the guideline reproduce THIS exact wing direction, length, curvature, and approximate thickness as closely as the model permits?

Do not generate a generic wing.

Hard rule:

```text
NO BLACK EYELINER PIGMENT
ONLY THE INSTRUCTIONAL PATH
```

## 7.9 Lips

Ask:

- natural border versus target border
- Cupid's bow
- corner extension
- lower-lip contour
- visible overline, if any
- shape and fullness

Acceptance question:

> Does the guide correspond to THIS final preview's exact lip shape?

Hard rule:

```text
NO LIPSTICK
NO GLOSS
NO LIP TINT
ONLY GUIDELINES
```

---

# 8. GUIDELINE-ONLY NEGATIVE CONTRACT

Every tutorial prompt must include an explicit negative contract equivalent to:

> DO NOT APPLY THE MAKEUP.  
> DO NOT reproduce the finished makeup.  
> DO NOT tint, darken, brighten, smooth, beautify, reshape, recolor, retouch, or cosmetically modify Image A.  
> Preserve Image A as closely as possible.  
> Add only the minimum instructional guide elements necessary for the CURRENT CATEGORY.  
> Ignore all other categories.  
> Do not creatively reinterpret the target.

Category-specific negative instructions must also be included.

This negative contract is not optional.

---

# 9. MINIMUM USEFUL GEOMETRY RULE

The tutorial must use the **minimum number of guide elements necessary** to teach the placement.

Prefer:

```text
3 useful guide elements
```

over:

```text
14 decorative guide elements
```

The prompt must reject unnecessary visual complexity.

A guide element must have a teaching purpose.

If an arrow cannot be connected to a real direction the user should follow, do not draw it.

If a line cannot be connected to a meaningful boundary or path, do not draw it.

---

# 10. STANDARD GUIDE LANGUAGE

The tutorial uses a small, consistent visual vocabulary.

| Guide | Meaning |
|---|---|
| `●` | Start / anchor point |
| solid line | placement / target boundary / path |
| dashed line | soft blend / fade zone |
| `→` | apply / blend / extend in this direction |

The exact use is category-aware.

Do not create twenty unrelated guide symbols.

Do not ask Gemini to render long instructional text inside the image.

---

# 11. GUIDE KEY + INSTRUCTION LINKING

Every tutorial step must contain a compact guide key rendered by Flutter.

Example:

```text
GUIDE KEY

● Start
━ Placement
- - Blend Zone
→ Direction
```

Every text instruction must reference a visible guide type through a symbol or a clearly matching guide label.

Prohibited:

```text
Blend upward.
```

Preferred:

```text
Follow the upward arrows → and blend toward the temple.
```

The image and instruction must behave as one teaching system.

---

# 12. NUMBERED INSTRUCTIONS

Complex categories should use numbered instructional sequencing.

Example:

```text
HOW TO APPLY

① Start ●
Begin at the outer half of the lash line.

② Follow the path ━
Trace the visible lash-line guideline.

③ Extend →
Follow the arrow toward the wing endpoint.
```

Initial rule:

- Flutter owns the numbers and text
- Gemini does not need to render readable `① ② ③` inside the image
- do not add V3-style geometry mapping merely to place numbers
- do not add normalized face geometry JSON
- do not add CustomPainter face landmark geometry

If the current architecture cannot place location-specific numbered overlays safely without resurrecting geometry mapping, keep numbering in the instruction list and connect it through guide symbols.

Do not invent a new geometry subsystem for decorative numbering.

---

# 13. SIMPLE TEXT INSTRUCTIONS

Every included tutorial step should expose approximately 2–4 concise instructions.

Requirements:

- short
- action-oriented
- category-specific
- tied to visible guide symbols
- grounded in the canonical preview
- not a cosmetology textbook
- no commercial brand invention
- no generic filler

The guideline shows **where**.

The instruction explains **how**.

---

# 14. “YOUR GOAL” MICRO-DESCRIPTION

Each step may show one short goal sentence.

Example:

```text
YOUR GOAL

Lifted rose blush concentrated toward the outer cheek.
```

or:

```text
YOUR GOAL

A thin lash line with a short, slightly upward wing.
```

The goal must be grounded in the canonical final preview.

Do not generate a generic style description merely from the style name.

---

# 15. SHADE / FINISH / INTENSITY

## 15.1 Standard Mode

Authority:

```text
validated brand-neutral recommendation
```

May display:

- shade family
- color name
- HEX
- finish
- intensity
- technique

Must not invent commercial brands/products.

Example:

```text
SHADE
Warm Rose
#B65A68

FINISH
Soft Satin

INTENSITY
Medium
```

## 15.2 My Makeup Kit Mode

Authority:

```text
immutable validated selected-product snapshot
```

May display:

- user-supplied product name
- user-supplied brand if present
- exact shade
- HEX
- finish
- other category-appropriate snapshot metadata

Do not query mutable current kit inventory as historical authority when a snapshot exists.

Do not invent missing product details.

## 15.3 Intensity vocabulary

Initial controlled display vocabulary:

```text
Soft
Medium
Bold
```

If the current validated data uses different established terminology, map carefully and do not silently falsify source data.

---

# 16. GLOBAL THEME REQUIREMENT

The tutorial must NOT force dark mode.

The tutorial must follow the application's global appearance.

```text
App = Light
→ Tutorial = Light

App = Dark
→ Tutorial = Dark

App = System
→ Tutorial follows the existing system/global app theme behavior
```

Use the existing:

- ThemeData
- ColorScheme
- typography
- spacing/design tokens
- surface colors
- button styles
- accessibility conventions

Do not create a separate tutorial-only theme engine.

Do not hardcode black backgrounds, white text, or dark cards merely because the first tutorial implementation used them.

---

# 17. TUTORIAL SCREEN TARGET

Target information hierarchy:

```text
STEP X OF N

CATEGORY

[ GUIDELINE IMAGE ]

● Start   ━ Placement
- - Blend Zone   → Direction

What do these guides mean?

HOW TO APPLY

① Start ●
...

② Blend →
...

③ Stay inside ━
...

YOUR GOAL
...

SHADE
...

FINISH
...

INTENSITY
...

[ Show / Hide Guidelines ]

[ Back ]                  [ Next ]

Draw this step again

YOUR FINAL LOOK

[ CANONICAL FINAL PREVIEW ]
```

The exact visual styling must use the existing FaceTune design system.

Do not treat this ASCII layout as pixel-perfect UI specification.

---

# 18. GUIDE VISIBILITY

Provide a user-visible way to compare:

```text
Guideline image
↔
original base / unobstructed reference where current assets allow
```

Preferred user action:

```text
Show Guidelines
Hide Guidelines
```

Do not trigger another Gemini generation to hide/show a guide.

If the current generated file is a flattened image and there is no separate overlay layer, inspect the current architecture before implementation.

Do not fake a hide/show toggle that cannot actually remove the guide.

If true guide toggling requires a new geometry/overlay architecture, STOP and report rather than resurrecting V3.

---

# 19. GUIDELINE OPACITY

Opacity control is a later quality enhancement only if the current rendering architecture genuinely supports an overlay layer.

Do not claim opacity control is possible on a flattened AI image if it is not.

If implementation would require a new geometry-rendering system, STOP.

No V3-style overlay pipeline may be introduced by stealth.

---

# 20. CATEGORY-AWARE ZOOM

Use Flutter image presentation/cropping/zooming of existing generated assets where practical.

Preferred emphasis:

```text
Foundation       → full face
Concealer        → mid/upper face as appropriate
Contour/Bronzer  → full/mid face
Blush            → cheeks / mid-face
Highlighter      → relevant feature area
Eyebrows         → upper face
Eyeshadow        → eye region
Eyeliner         → eye region
Lips             → lower face / lips
```

Do not generate another paid image merely to achieve zoom.

Do not crop so aggressively that the user loses context needed to apply makeup symmetrically.

---

# 21. FINAL LOOK REFERENCE

Every tutorial step must provide easy access to the canonical final preview.

The user must always be able to answer:

> What am I trying to reproduce?

The tutorial guide explains the route.

The final preview shows the destination.

Do not generate a new “final” image for the tutorial.

Reuse the existing canonical final preview.

---

# 22. DYNAMIC MANIFEST MULTI-STYLE QA

A single Full Glam example with 9/9 steps does not prove a manifest defect.

Full Glam may legitimately contain all nine supported categories.

The manifest must be tested against varied looks, including at minimum where available:

- Full Glam
- Soft Glam
- Natural
- at least one look where one or more categories are subtle or visually absent

Illustrative QA expectations only:

```text
Full Glam  → may contain many/all supported categories
Soft Glam  → may contain a reduced subset
Natural    → may contain a smaller subset
```

These are NOT hardcoded counts.

Never implement:

```text
Natural → 4 steps
```

or:

```text
Supported categories = 9
→ Always create 9 steps
```

Actual rule:

```text
Original Selfie
+
Canonical Final Preview
↓
Visual Comparison
↓
PRESENT
ABSENT
UNCERTAIN
↓
Include / Exclude according to existing manifest contract
```

---

# 23. MANIFEST CONFIDENCE

Continue supporting:

```text
present
absent
uncertain
```

Do not silently convert:

```text
uncertain
→ present
```

Do not use style name alone to resolve uncertainty.

Recommendation/look-plan data may support genuine ambiguity only according to the existing manifest contract.

Do not redesign manifest persistence during this track.

---

# 24. REPRESENTATIVE QA CATEGORIES FIRST

Prompt precision must be tuned first on:

1. Blush
2. Eyeshadow
3. Eyeliner
4. Lips

Why:

- Blush stresses facial placement + blend direction
- Eyeshadow stresses zones + multiple boundaries + no-pigment compliance
- Eyeliner stresses fine geometric fidelity
- Lips stresses border/anchor/shape fidelity

Do NOT regenerate all nine categories repeatedly while tuning the first prompt revision.

Once the representative four meet the approved quality gate, propagate the prompt principles to:

- Foundation
- Concealer
- Contour/Bronzer
- Highlighter
- Eyebrows

---

# 25. VISUAL QA SCORECARD

Every evaluated guideline should be assessed with:

```text
PASS
ACCEPTABLE
FAIL
```

Quality dimensions:

| Dimension | Requirement |
|---|---|
| Final-preview fidelity | guide corresponds to actual final result |
| Category isolation | only current category is analyzed |
| Guideline-only compliance | no actual makeup pigment is added |
| Identity preservation | original face remains recognizable and materially unchanged |
| Placement accuracy | position matches the canonical preview |
| Direction accuracy | arrows match actual application/blend direction |
| Shape fidelity | boundary/path resembles final preview |
| Simplicity | minimum useful guide geometry |
| Instruction agreement | text clearly refers to visible guide symbols |
| Shade accuracy | matches validated recommendation or snapshot |
| Finish accuracy | matches authoritative structured data |
| Intensity accuracy | reflects intended visible strength |
| Bilateral consistency | paired features are coherent unless real asymmetry exists |
| Readability | understandable on POCO X3 GT |
| Final-look usability | final target is easy to reference |

Do not fabricate automated percentages for inherently visual judgments.

Human visual QA is valid and required.

---

# 26. BILATERAL CONSISTENCY

For paired features:

- eyes
- eyebrows
- cheeks

the generated guide should be coherent on both sides unless the canonical final preview genuinely contains asymmetric makeup.

Do not “correct” natural facial asymmetry by forcing mathematically identical geometry.

The target is faithful instruction, not synthetic symmetry.

---

# 27. REGENERATION FEEDBACK

When a user intentionally regenerates a tutorial step, a later phase may offer concise reasons such as:

- Placement looks wrong
- Guide is unclear
- Face changed
- Too many guidelines
- Try another version

Requirements:

- do not log private image bytes
- do not log signed URLs
- do not log full prompts containing private data
- do not auto-regenerate merely because feedback is selected
- explicit user action remains required
- preserve bounded cost controls

Regeneration feedback is product telemetry, not permission for endless paid attempts.

---

# 28. PROMPT VERSIONING

Every material tutorial prompt change must increment or otherwise update the established prompt version.

Do not edit production prompt behavior without version evidence.

Record:

- old prompt version
- new prompt version
- categories changed
- reason
- observed failure addressed
- QA evidence after change

Do not optimize prompts from imagination.

Optimize from observed device/benchmark failures.

---

# 29. PROMPT ARCHITECTURE

Do not build one giant unmaintainable prompt string.

Use composable prompt sections equivalent to:

```text
A. image role contract
B. canonical-preview authority
C. category isolation
D. exact visual-difference questions
E. minimum useful guide language
F. guideline-only negative contract
G. category-specific constraints
H. output constraints
```

The prompt must state that generic makeup knowledge is subordinate to the actual final preview.

---

# 30. PRODUCT / INSTRUCTION AUTHORITY

Visual placement comes from:

```text
canonical final preview
```

Standard Mode product/shade metadata comes from:

```text
validated brand-neutral recommendation
```

My Makeup Kit product identity comes from:

```text
immutable validated owned-product snapshot
```

Instruction text must never invent:

- commercial product
- product ID
- user ownership
- missing kit item
- shade
- HEX
- finish

If authoritative metadata is missing, omit the field or show a truthful unavailable state according to current UI conventions.

---

# 31. NO DATABASE CHANGE FOR INSTRUCTIONAL UX

This refinement track does not authorize a new persistence model for guide instructions.

Before adding structured guide metadata:

1. inspect existing step/domain payloads
2. inspect existing recommendation/snapshot data
3. use typed application contracts where current architecture permits
4. do not add database columns merely for convenience
5. do not add migrations without explicit approval

If persistence is truly required and no safe existing channel exists:

STOP.

Report the exact minimal schema requirement before changing the database.

---

# 32. SECURITY & PRIVACY

All existing security requirements remain.

Do not:

- expose Gemini keys
- expose Supabase service-role keys
- log JWTs
- make private buckets public
- disable RLS
- weaken ownership validation
- log image/base64 data
- log signed URLs
- log full private prompts
- allow client-selected arbitrary model IDs
- allow client-selected arbitrary resolution
- let the client decide manifest categories
- let Gemini prove ownership

This quality track must not weaken security for convenience.

---

# 33. COST CONTROL

Keep existing on-demand behavior.

Do not:

- regenerate every category for every prompt tweak
- generate all categories before the user opens them
- automatically regenerate visually “imperfect” images
- add unlimited QA loops
- add model fallbacks
- change 1K for cost experiments during this track

Representative prompt QA starts with:

```text
Blush
Eyeshadow
Eyeliner
Lips
```

Only expand after the representative gate passes.

---

# 34. GLOBAL THEME QA

Test tutorial appearance under:

```text
Light
Dark
System
```

Verify:

- background
- cards/surfaces
- text
- divider
- progress
- buttons
- guide key
- product metadata
- final-look section
- error/loading states

The tutorial must use the same global theme behavior as the rest of FaceTune.

No forced dark tutorial.

---

# 35. ACCESSIBILITY

Instructional UX must be:

- readable on POCO X3 GT
- usable with larger text scales where practical
- not dependent on color alone to communicate guide meaning
- sufficiently contrast-safe under Light and Dark themes
- semantically labeled
- localization-ready
- scroll-safe
- not clipped by small screens

The symbols + text labels intentionally reduce color-only dependence.

---

# 36. QUALITY TRACK PHASES

## V4-QA-0 — Baseline Freeze & Evidence Capture

Freeze working infrastructure and document the existing visual baseline.

No product changes.

## V4-QA-1 — Instruction & Guide Contract

Create typed guide/instruction contracts using existing architecture.

No database migration.

No prompt behavior change yet.

## V4-QA-2 — Representative Prompt Precision

Tune only:

- Blush
- Eyeshadow
- Eyeliner
- Lips

Focus:

- final-preview fidelity
- guideline-only compliance
- minimum useful geometry

## V4-QA-3 — Remaining Category Prompt Precision

Propagate approved principles to:

- Foundation
- Concealer
- Contour/Bronzer
- Highlighter
- Eyebrows

## V4-QA-4 — Flutter Instructional UX & Global Theme

Implement:

- Guide Key
- numbered instructions
- simple how-to text
- Light/Dark/System inheritance
- goal/shade/finish/intensity presentation shell

Do not force dark mode.

## V4-QA-5 — Product / Final-Look / Viewing Experience

Implement and validate:

- Standard Mode product metadata
- My Makeup Kit snapshot metadata
- final-look reference
- category-aware zoom where safe
- show/hide guide only if the existing rendering architecture genuinely supports it

No fake toggles.

## V4-QA-6 — Dynamic Manifest Multi-Style QA

Validate Full Glam, Soft Glam, Natural, subtle/absent categories, uncertain behavior, and both recommendation modes.

No hardcoded style counts.

## V4-QA-7 — Visual QA Scorecard & Regeneration Feedback

Establish controlled PASS / ACCEPTABLE / FAIL process.

Add regeneration reasons if safe and within existing architecture.

No private-image telemetry.

## V4-QA-8 — End-to-End Quality Baseline Lock

Prove:

- Standard Mode
- My Makeup Kit
- incomplete kit
- multiple styles
- dynamic manifest
- guideline quality
- instructional UX
- global theme behavior
- final-look reference
- reopen/reuse
- no preview regression
- no infrastructure regression

Then explicitly lock the quality baseline.

---

# 37. GLOBAL ACCEPTANCE CRITERIA

This refinement track is complete only when:

## Models / infrastructure

- final preview remains `gemini-3.1-flash-image`
- tutorial remains `gemini-3.1-flash-image`
- tutorial remains 1K
- no silent model fallback
- database architecture remains intact
- RLS remains intact
- storage remains private
- tutorial session architecture remains intact
- dynamic manifest architecture remains intact
- Flutter tutorial flow remains working

## Visual fidelity

- representative categories pass canonical-preview fidelity QA
- remaining categories inherit the same prompt discipline
- no category is accepted merely because it is “cosmetically sensible”
- generic makeup placement is subordinate to the final preview

## Guideline-only

- no intended makeup pigment in tutorial guideline images
- no beautification
- no face redesign
- no unrelated category leakage
- minimum useful guide complexity

## Instructional UX

- compact guide key
- instructions reference visible guide symbols
- approximately 2–4 concise steps per category
- shade shown where authoritative data exists
- finish shown where authoritative data exists
- intensity shown where authoritative data exists
- final-look reference accessible
- theme follows global Light/Dark/System
- readable on POCO X3 GT

## Dynamic manifest

- Full Glam tested
- Soft Glam tested where available
- Natural tested where available
- absent-category omission demonstrated
- uncertain behavior demonstrated
- no fixed-nine fallback
- no hardcoded style counts

## Product authority

- Standard remains brand-neutral
- My Makeup Kit shows only immutable validated owned-product snapshot data
- no invented product/shade/ownership

## QA

- PASS / ACCEPTABLE / FAIL scorecard used
- observed failures documented
- material prompt changes versioned
- no fabricated visual percentages
- end-to-end device evidence exists

---

# 38. FINAL ENGINEERING PRINCIPLE

The final preview already defines the destination.

The tutorial must not redesign the destination.

The tutorial must explain how to get there.

The system should behave conceptually as:

```text
CANONICAL FINAL PREVIEW
↓
defines WHAT THE RESULT MUST LOOK LIKE

ORIGINAL SELFIE
+
CURRENT CATEGORY
↓
defines THE STARTING POINT AND SCOPE

GEMINI GUIDELINE
↓
shows WHERE

FLUTTER GUIDE KEY + INSTRUCTIONS
↓
explains HOW

RECOMMENDATION / KIT SNAPSHOT
↓
explains WHAT TO USE

FINAL LOOK REFERENCE
↓
reminds the user WHAT TO ACHIEVE
```

The core rule remains:

> **A good tutorial is not a plausible makeup tutorial. It is a faithful reconstruction guide for THIS exact canonical final preview.**
