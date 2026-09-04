# FaceTune — TUTORIAL UI / UX PRODUCTIONIZATION PHASE PROMPTS

**Project root:** `C:\Users\Kurt\facetune`  
**Required active branch:** `feature/live-scan-educational-palette` — MUST be verified; do not create/switch automatically  
**Primary device:** POCO X3 GT  
**Framework:** Flutter / Dart  
**Backend:** Supabase — PROTECTED / NO CHANGES AUTHORIZED IN THIS TRACK  
**State management:** Riverpod  
**Architecture:** Clean Architecture + Repository Pattern + Feature-First Structure  
**Source of Truth:** `FACETUNE_TUTORIAL_UI_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md`  
**This phase file:** `FACETUNE_TUTORIAL_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md`  
**Final Preview Model — HARD LOCK:** `gemini-3.1-flash-image`  
**Tutorial Guideline Model — HARD LOCK:** `gemini-3.1-flash-image`  
**Tutorial Resolution — HARD LOCK:** `1K`  
**Tutorial Prompt — HARD LOCK:** `tutorial_guideline_v4_7`  
**Manifest Prompt — HARD LOCK:** `tutorial_manifest_v4_1`  
**Accepted V4 Functional Baseline:** PROTECTED  
**Recommendation Modes:** `standard` + `my_makeup_kit`  
**Design Direction:** Luminous Beauty Intelligence

---

# HOW TO USE THIS FILE

1. Keep this file beside `FACETUNE_TUTORIAL_UI_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md`.
2. Use OpenAI Codex / GPT-5.6 Sol High or Claude Code Pro.
3. Run **exactly ONE phase at a time**.
4. Paste only the prompt for the active phase.
5. Review the completion report before proceeding.
6. Never auto-continue.
7. Never treat a screenshot alone as proof of behavior.
8. Never treat automated tests alone as proof of premium visual quality.
9. Never change Gemini/model/prompt behavior to make UI easier.
10. Never change database/RLS/storage as a UI convenience.
11. Never merge Standard and My Kit business authority for DRY.
12. Never add Standard fallback into My Kit.
13. Never refactor domain/repository/state architecture merely for visual cleanliness.
14. If a requested UI change requires a protected cross-layer change: **STOP AND REPORT**.
15. Do not commit/push/merge/rebase unless explicitly instructed.

---

# MANDATORY READ ORDER FOR EVERY PHASE

Read completely, in order:

```text
1. CODEX_MASTER_GUIDE.md
2. FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_SOURCE_OF_TRUTH.md
3. FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_PHASE_PROMPTS.md
4. FACETUNE_V4_TUTORIAL_QUALITY_SOURCE_OF_TRUTH.md
5. FACETUNE_V4_TUTORIAL_QUALITY_PHASE_PROMPTS.md
6. current canonical FaceTune UI Productionization Source of Truth
7. current canonical FaceTune UI Productionization Phase Prompts
8. FACETUNE_LIVE_SCAN_EDUCATIONAL_PALETTE_SOURCE_OF_TRUTH.md if present
9. FACETUNE_LIVE_SCAN_EDUCATIONAL_PALETTE_PHASE_PROMPTS.md if present
10. FACETUNE_TUTORIAL_UI_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md
11. FACETUNE_TUTORIAL_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md
12. relevant accepted V4 / UI / LSEP / tutorial completion reports
13. actual current source, tests, dependencies, configuration, deployed evidence,
    and real-device evidence relevant to THIS phase
```

If an authority file is missing, do not invent its content.

Inspect actual source.

---

# MANDATORY SYSTEM ROLE FOR EVERY PHASE

Act simultaneously as the roles relevant to the phase, including:

- Principal Software Engineer
- Principal Software Architect
- Principal Mobile Architect
- Principal Flutter Architect
- Senior Frontend Engineer
- Senior Frontend Developer
- Senior Flutter Engineer
- Senior Flutter Developer
- Senior Dart Engineer
- Senior Dart Developer
- Senior Mobile Application Engineer
- Senior Mobile Application Developer
- Senior Riverpod Engineer
- Senior Tutorial UI Engineer
- Senior Design Systems Engineer
- Senior Design Systems Developer
- Senior Flutter UI Engineer
- Senior Mobile UI Engineer
- Senior Component Library Engineer
- Senior Responsive Layout Engineer
- Senior Interaction Engineer
- Senior Motion Engineer
- Senior Mobile Product Designer
- Senior UI Designer
- Senior UX Designer
- Senior UI/UX Designer
- Senior Visual Designer
- Senior Beauty-App Product Designer
- Senior Information Architecture Designer
- Senior Instructional UX Designer
- Senior Accessibility Engineer
- Senior Inclusive Design Engineer
- Senior Semantic UI Engineer
- Senior Localization-Readiness Engineer
- Senior Performance Engineer
- Senior Reliability Engineer
- Senior Application Security Engineer
- Senior Privacy Engineer
- Senior Supabase Engineer
- Senior Backend Engineer
- Senior QA Engineer
- Senior Regression Engineer
- Senior Integration Test Engineer
- Senior End-to-End Test Engineer
- Senior Visual QA Engineer
- Senior Production Debugging Engineer
- Senior Release Engineer
- Senior Gemini AI Engineer
- Senior AI Systems Engineer
- Senior Tutorial AI Engineer
- Senior Dynamic Manifest Engineer
- Senior My Makeup Kit Engineer
- Senior Recommendation Authority Engineer
- Senior Code Reviewer

AI/backend roles exist to protect the accepted system, not redesign it.

Inspect first.

Challenge stale documentation.

Prefer the smallest production-safe presentation-layer change.

Preserve working application behavior.

---

# GLOBAL GIT SAFETY

Before any implementation phase:

```powershell
git branch --show-current
git log -1 --oneline
git status --short
git diff --stat
git diff --name-only
```

Required branch:

```text
feature/live-scan-educational-palette
```

If branch differs:

```text
STOP
DO NOT SWITCH AUTOMATICALLY
DO NOT IMPLEMENT
```

Do NOT:

- reset
- reset --hard
- clean
- stash
- restore unrelated files
- discard valid work
- checkout unrelated files
- rebase
- merge
- cherry-pick
- commit
- push

If working-tree ownership is unclear:

```text
STOP
REPORT
```

---

# GLOBAL HARD LOCKS

Every phase must preserve:

```text
FINAL PREVIEW MODEL
= gemini-3.1-flash-image

TUTORIAL MODEL
= gemini-3.1-flash-image

TUTORIAL RESOLUTION
= 1K

TUTORIAL PROMPT
= tutorial_guideline_v4_7

MANIFEST PROMPT
= tutorial_manifest_v4_1
```

Do NOT modify:

- Gemini configuration
- model names
- model environment configuration
- prompts
- prompt versions
- request/response behavior
- AI retries/fallbacks
- image resolution
- AI call counts
- final-preview generation
- tutorial generation
- manifest logic/reuse
- category inclusion/order
- Makeup Breakdown authority
- My Makeup Kit owned-product authority
- immutable snapshot authority
- database
- migrations
- Edge Functions
- RLS
- storage
- authentication
- repository contracts
- domain entities/rules
- use cases
- persistence contracts
- Riverpod business architecture

Expected protected backend diff:

```text
NONE
```

If any protected change appears necessary:

```text
STOP
REPORT
DO NOT IMPLEMENT
```

---

# GLOBAL TUTORIAL HARD LOCKS

Preserve:

```text
V4 IMAGE CONTRACT
V4 CATEGORY ISOLATION
GUIDELINE-ONLY OUTPUT
NO MAKEUP PIGMENT
NO CHAINED STEP IMAGES
CANONICAL FINAL PREVIEW REUSE
DYNAMIC MANIFEST AUTHORITY
RUNTIME CATEGORY COUNT
RUNTIME CATEGORY ORDER
REDRAW CONFIRMATION
REDRAW COST BEHAVIOR
REDRAW RETRY RULES
FULLSCREEN VIEWER CAPABILITY
HISTORY / REOPEN AUTHORITY
```

Guide semantics remain:

```text
● Start
━ Placement
- - Blend Zone
→ Direction
```

Do not hardcode `Lips` as the last step.

Do not hardcode a fixed number of steps.

---

# GLOBAL MODE-AUTHORITY LOCK

Core rule:

```text
ONE TUTORIAL EXPERIENCE
+
TWO DATA AUTHORITIES
```

Standard and My Makeup Kit may share presentation.

They may NOT merge business authority.

Standard:

```text
brand-neutral recommendation authority
```

My Makeup Kit:

```text
validated immutable owned-product snapshot authority
```

Never:

```text
STANDARD FALLBACK INTO MY KIT
MY KIT PRODUCT SUBSTITUTION
CURRENT-KIT REPLACEMENT OF HISTORICAL SNAPSHOT
BUSINESS CONTROLLER MERGE
```

---

# GLOBAL AI LIFECYCLE LOCK

No paid/network AI work from `build()`.

Rebuilds from theme, snackbar, MediaQuery, orientation, text scale, semantics, scroll, or footer changes must trigger:

```text
0 EXTRA GEMINI CALLS
0 EXTRA MANIFEST CALLS
0 EXTRA PREVIEW CALLS
0 EXTRA TUTORIAL CALLS
0 EXTRA REDRAW CALLS
```

Preserve existing controlled lifecycle/state orchestration.

---

# GLOBAL UI DESIGN DIRECTION

Use **LUMINOUS BEAUTY INTELLIGENCE**.

FaceTune tutorial should feel:

- elegant
- premium
- calm
- modern
- intelligent
- beauty-focused
- editorial
- trustworthy
- restrained
- consumer-ready

Avoid:

- generic AI SaaS visuals
- neon
- excessive purple gradients
- glassmorphism
- glowing borders
- decorative blobs
- emoji icons
- excessive pills
- card nesting
- database-form UI
- arbitrary shadows
- tutorial-specific styling systems

Reuse existing global FaceTune tokens/components.

---

# GLOBAL RULES DURING IMPLEMENTATION

- preserve Clean Architecture
- preserve Repository Pattern
- preserve feature-first structure
- preserve Riverpod business state
- keep business logic out of widgets
- reuse global tokens/components
- avoid magic UI values
- avoid duplicate component systems
- keep visual state local only when truly presentation-only
- use ThemeData / ColorScheme
- preserve Light / Dark / System
- preserve semantics/accessibility
- preserve navigation behavior
- preserve data authority
- do not add dependencies without explicit justification
- do not refactor unrelated code
- do not auto-start another phase

---

# GLOBAL VALIDATION

After each implementation phase, run as applicable:

```powershell
dart format .
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/development.json
git diff -- supabase/
```

Expected:

```text
NO BACKEND CHANGES
```

If device is unavailable:

```text
REAL DEVICE STATUS:
PENDING USER / DEVICE VERIFICATION
```

Never fabricate visual success.

---

# GLOBAL COMPLETION REPORT

Every phase must end with this structure:

```text
PHASE COMPLETED:

AGENT:

BRANCH VERIFIED:

HEAD BEFORE:

HEAD AFTER:

WORKING TREE BEFORE:

WORKING TREE AFTER:

OBJECTIVE ACHIEVED:
YES / PARTIAL / NO

----------------------------------
SCOPE
----------------------------------

AUTHORIZED UI SCOPE:

UNAUTHORIZED SCOPE TOUCHED:
NONE / exact issue

----------------------------------
PROTECTED BASELINE
----------------------------------

FINAL PREVIEW MODEL:
gemini-3.1-flash-image

TUTORIAL MODEL:
gemini-3.1-flash-image

TUTORIAL RESOLUTION:
1K

TUTORIAL PROMPT:
tutorial_guideline_v4_7

MANIFEST PROMPT:
tutorial_manifest_v4_1

AI CHANGES:
NONE

DATABASE CHANGES:
NONE

RLS CHANGES:
NONE

STORAGE CHANGES:
NONE

EDGE FUNCTION CHANGES:
NONE

AUTH LOGIC CHANGES:
NONE

DOMAIN / REPOSITORY CHANGES:
NONE

RIVERPOD BUSINESS-STATE CHANGES:
NONE

MY KIT AUTHORITY CHANGES:
NONE

----------------------------------
UI
----------------------------------

SCREENS / COMPONENTS CHANGED:

DESIGN TOKENS CHANGED:

SHARED COMPONENTS CREATED / MODIFIED:

STANDARD UI STATUS:

MY KIT UI STATUS:

STANDARD / MY KIT VISUAL PARITY:

LIGHT THEME:

DARK THEME:

SYSTEM THEME:

RESPONSIVE STATUS:

ACCESSIBILITY STATUS:

VISUAL QA:

----------------------------------
FILES
----------------------------------

FILES CREATED:

FILES MODIFIED:

FILES DELETED:

DEPENDENCIES ADDED / REMOVED:

----------------------------------
TUTORIAL REGRESSION
----------------------------------

GUIDE IMAGE:
PASS / NOT TOUCHED / FAIL

GUIDE KEY:
PASS / NOT TOUCHED / FAIL

REDRAW:
PASS / NOT TOUCHED / FAIL

HOW TO APPLY:
PASS / NOT TOUCHED / FAIL

RECOMMENDATION SECTION:
PASS / NOT TOUCHED / FAIL

FINAL LOOK:
PASS / NOT TOUCHED / FAIL

FULLSCREEN VIEWER:
PASS / NOT TOUCHED / FAIL

DYNAMIC MANIFEST:
PASS / NOT TOUCHED / FAIL

CATEGORY ORDER:
PASS / NOT TOUCHED / FAIL

HISTORY / REOPEN:
PASS / NOT TOUCHED / FAIL

----------------------------------
APP REGRESSION
----------------------------------

AUTH:
PASS / NOT TOUCHED / FAIL

SELFIE FLOW:
PASS / NOT TOUCHED / FAIL

FACE ANALYSIS:
PASS / NOT TOUCHED / FAIL

STYLE:
PASS / NOT TOUCHED / FAIL

STANDARD RECOMMENDATION:
PASS / NOT TOUCHED / FAIL

MY MAKEUP KIT:
PASS / NOT TOUCHED / FAIL

FINAL PREVIEW:
PASS / NOT TOUCHED / FAIL

MAKEUP BREAKDOWN:
PASS / NOT TOUCHED / FAIL

----------------------------------
VALIDATION
----------------------------------

DART FORMAT:

FLUTTER ANALYZE:

TARGETED TESTS:

FULL FLUTTER TEST:

ANDROID DEBUG BUILD:

BACKEND DIFF:
NONE / exact unexpected diff

EXTRA AI CALLS:
0 / exact issue

REAL DEVICE:
PASS / FAIL / PENDING USER

----------------------------------
KNOWN LIMITATIONS
----------------------------------

----------------------------------
ASSUMPTIONS NOT PROVEN
----------------------------------

----------------------------------
MANUAL ACTION REQUIRED
----------------------------------

NONE / exact action

----------------------------------
NEXT
----------------------------------

NEXT RECOMMENDED PHASE:

STOP CONFIRMATION:
No later phase was implemented automatically.
No model changed.
No prompt changed.
No backend/DB/RLS/storage changed.
No Standard/My Kit authority merged.
No commit/push/merge/rebase performed.
```

A vague report is not acceptable.

---

# TUT-UI-0 — BASELINE AUDIT + PROTECTED SURFACE MAP

Read all mandatory authority files completely.

Implement only:

## TUT-UI-0 — BASELINE AUDIT + PROTECTED SURFACE MAP

Then STOP.

## Active roles

Especially apply:

- Principal Software Architect
- Principal Flutter Architect
- Senior Frontend Engineer
- Senior Flutter Engineer
- Senior Tutorial UI Engineer
- Senior Design Systems Engineer
- Senior UX Designer
- Senior My Makeup Kit Engineer
- Senior Dynamic Manifest Engineer
- Senior Regression Engineer
- Senior Code Reviewer

## Objective

Prove the exact current Standard and My Makeup Kit tutorial implementations before presentation unification begins.

This phase is primarily READ-ONLY.

## Before coding

Run:

```powershell
git branch --show-current
git log -1 --oneline
git status --short
git diff --stat
git diff --name-only
```

Inspect:

- Standard tutorial page(s)
- My Makeup Kit tutorial page(s)
- regular tutorial step UI
- final runtime tutorial step UI
- header/progress
- guide image widget
- Tap to enlarge
- fullscreen viewer
- Guide Key / What the guides mean
- redraw action/confirmation
- How to Apply
- Your Goal
- Suggested Shades
- My Kit product section
- Hex presentation
- Where to Apply / Technique duplication
- Final Look presentation
- final-step giant Final Look special case
- Back / Next / Finish navigation
- scrolling
- SafeArea/footer behavior
- controllers/providers
- manifest/category source
- Standard recommendation authority
- My Kit immutable snapshot authority
- tests
- global UI tokens/components

## Mandatory proof

Report exact source paths and ownership for:

```text
TUTORIAL SHELL
PROGRESS HEADER
GUIDE HERO
GUIDE KEY
REDRAW
HOW TO APPLY
GOAL
STANDARD RECOMMENDATION SECTION
MY KIT RECOMMENDATION SECTION
FINAL LOOK
FULLSCREEN VIEWER
FOOTER / NAVIGATION
FINAL-STEP SPECIAL CASE
```

Also prove the hard locks from current source/configuration.

## Audit Standard / My Kit parity

For each surface classify:

```text
IDENTICAL
VISUALLY DIFFERENT
DATA-AUTHORITY DIFFERENT AS EXPECTED
UNKNOWN
```

## Do NOT implement

- UI redesign
- new shared shell
- new footer
- prompt/model changes
- domain/My Kit business changes
- backend changes

## Validation

At minimum:

```powershell
flutter analyze
flutter test
git diff -- supabase/
```

Do not generate paid AI solely for audit.

## Done when

A privacy-safe baseline report proves:

- exact Git state
- tutorial architecture
- Standard/My Kit differences
- protected files/surfaces
- minimum files likely for later phases
- no backend/model/prompt changes

Return Global Completion Report.

STOP.

---

# TUT-UI-1 — SHARED TUTORIAL SHELL + PERSISTENT FOOTER

Read all mandatory authorities and accepted TUT-UI-0 report.

Implement only:

## TUT-UI-1 — SHARED TUTORIAL SHELL + PERSISTENT FOOTER

Then STOP.

## Active roles

Especially apply:

- Principal Flutter Architect
- Senior Frontend Engineer
- Senior Flutter Engineer
- Senior Component Library Engineer
- Senior Responsive Layout Engineer
- Senior UX Designer
- Senior Accessibility Engineer
- Senior My Makeup Kit Engineer
- Senior Regression Engineer

## Objective

Create one consistent presentation shell for:

```text
STANDARD REGULAR STEP
STANDARD FINAL STEP
MY KIT REGULAR STEP
MY KIT FINAL STEP
```

without merging business authority.

## Required target

```text
X

Step X of N            progress
<Category>

SCROLLABLE CONTENT
...

FIXED SAFE-AREA FOOTER
[ Back ]                [ Next ]
```

Final runtime category:

```text
[ Back ]              [ Finish ]
```

## Hard requirements

- content remains scrollable
- footer persistent
- footer outside scroll content
- no footer overlay
- SafeArea required
- top X remains Exit Tutorial
- bottom Back remains Previous Tutorial Category
- step count from runtime accepted data
- final step from runtime last category
- no hardcoded Lips special case
- no fixed step count
- Finish uses existing completion behavior
- no AI calls from footer/render changes

## Shared presentation rule

Shared shell is authorized.

Do NOT merge:

- Standard controller
- My Kit controller
- repositories
- domain entities
- data authority
- immutable snapshot

Thin presentation adapters allowed.

## Content freeze for this phase

Do NOT redesign yet:

- Guide Key
- How to Apply
- Suggested Shades
- Final Look
- redraw placement

Only place current content inside shared shell.

## Footer hierarchy

Use global FaceTune buttons.

Regular:

```text
Back = secondary
Next = primary
```

Final:

```text
Back = secondary
Finish = primary
```

Do not invent new button styles.

## Required tests

Prove:

- Standard regular/footer
- Standard final/footer
- My Kit regular/footer
- My Kit final/footer
- callbacks unchanged
- runtime N count
- runtime final-step detection
- scroll independent from footer
- footer visible
- no footer overlap
- no extra AI calls
- no business-authority merge

## Validation

Run global validation.

## Real device

POCO X3 GT:

- regular step
- final step
- Standard
- My Kit where available
- scroll to bottom
- last content fully visible above footer
- footer always visible

If unavailable: PENDING USER.

Return Global Completion Report.

STOP.

---

# TUT-UI-2 — GUIDE HERO + COMPACT GUIDE KEY + REDRAW PLACEMENT

Read all authorities and accepted TUT-UI-0 / TUT-UI-1 reports.

Implement only:

## TUT-UI-2 — GUIDE HERO + COMPACT GUIDE KEY + REDRAW PLACEMENT

Then STOP.

## Active roles

Especially apply:

- Senior Flutter UI Engineer
- Senior Tutorial UI Engineer
- Senior Design Systems Engineer
- Senior Interaction Designer
- Senior Accessibility Engineer
- Senior Gemini AI Engineer for protection only
- Senior Regression Engineer

## Objective

Improve the top tutorial content without changing generated imagery or redraw behavior.

## Guide Hero

Preserve:

- same generated guideline image
- same source/crop
- same resolution
- same fullscreen viewer
- same Tap to enlarge capability

Make guide remain visual hero.

Tap-to-enlarge may become visually quieter using global utility styling.

## Guide Key

Replace large `What the guides mean` card with compact:

```text
Guide key
<relevant accepted symbols only>
```

Accepted meanings remain:

```text
● Start
━ Placement
- - Blend Zone
→ Direction
```

No semantic changes.

## Redraw

Move `Draw this step again` near guide area.

Preferred label:

```text
Redraw guide
```

Use global refresh/redraw vector icon.

Do NOT change:

- confirmation
- call count
- paid behavior
- reason handling
- retries
- prompt/model
- generation inputs
- persistence

## Layout order

```text
GUIDE IMAGE
Tap to enlarge

Guide key

Redraw guide

How to apply...
```

## Standard / My Kit

Exact same visual presentation.

## Required tests

- correct Guide Key symbols
- enlarge still works
- fullscreen viewer unchanged
- redraw calls existing callback
- redraw not triggered by rebuild
- Standard/My Kit parity
- no extra AI calls

## Validation

Run global validation.

## Real device

POCO X3 GT:

- inspect at least two categories with different symbols
- hero prominence
- Guide Key compactness
- redraw discoverability
- redraw confirmation unchanged
- do not perform unnecessary paid redraw solely for visual QA

Return Global Completion Report.

STOP.

---

# TUT-UI-3 — HOW TO APPLY EDITORIAL RAIL + YOUR GOAL CALLOUT

Read all authorities and accepted prior reports.

Implement only:

## TUT-UI-3 — HOW TO APPLY EDITORIAL RAIL + YOUR GOAL CALLOUT

Then STOP.

## Active roles

Especially apply:

- Senior Frontend Engineer
- Senior Flutter Engineer
- Senior Instructional UX Designer
- Senior Information Architecture Designer
- Senior Design Systems Engineer
- Senior Accessibility Engineer
- Senior Tutorial AI Engineer for copy protection only
- Senior Regression Engineer

## Objective

Replace generic giant How-to card with premium editorial instructional rail while preserving authoritative text exactly.

## Target

```text
How to apply

01   <existing title>          <relevant guide symbol>
     <existing authoritative body>

     │

02   <existing title>          <relevant guide symbol>
     <existing authoritative body>

     │

03   <existing title>          <relevant guide symbol>
     <existing authoritative body>


YOUR GOAL
│ <existing authoritative goal text>
```

## Hard copy rule

Flutter must NOT:

- summarize
- paraphrase
- rewrite
- shorten
- invent
- truncate

authoritative tutorial text.

If source copy is too long:

```text
REPORT COPY-DENSITY ISSUE
DO NOT MODIFY PROMPT
```

## Presentation rules

- no giant outer How-to card if safe under global UI
- numbered step anchors
- strong step title
- supporting body typography
- editorial connecting rail if appropriate
- guide symbols only where mapping is truthful
- global typography/spacing
- Your Goal as restrained editorial callout
- no gradient/glow/sparkle card

## Standard / My Kit

Identical How-to presentation.

## Required tests

- all steps present
- original text preserved
- order preserved
- goal preserved
- large text wraps
- no overflow
- Standard/My Kit parity
- no AI/prompt changes

## Validation

Run global validation.

## Real device

POCO X3 GT:

- inspect Eyeshadow-like category
- inspect Lips-like category
- verify scanability/body readability
- goal visible but not dominant
- footer remains visible

Return Global Completion Report.

STOP.

---

# TUT-UI-4 — BEAUTY RECOMMENDATION SECTION + STANDARD / MY KIT PARITY

Read all authorities and accepted prior reports.

Implement only:

## TUT-UI-4 — BEAUTY RECOMMENDATION SECTION + STANDARD / MY KIT PARITY

Then STOP.

## Active roles

Especially apply:

- Principal Software Architect
- Senior Frontend Engineer
- Senior Flutter Engineer
- Senior Beauty-App Product Designer
- Senior Design Systems Engineer
- Senior My Makeup Kit Engineer
- Senior Recommendation Authority Engineer
- Senior Accessibility Engineer
- Senior Regression Engineer

## Objective

Replace database-form tutorial recommendation presentation with one beauty-oriented shared presentation component while preserving separate data authority.

## Standard target

```text
Suggested shades

●  Bronzed Rose Quartz
   Shimmer · Medium

●  Soft Champagne
   Satin · Soft
```

## My Kit target

```text
From your makeup kit

●  <authoritative owned product>
   <finish> · <intensity>
```

Brand may be shown only if authoritative snapshot contains it.

## Shared component

Visual structure identical.

Thin adapters may provide:

```text
sectionLabel
displayName
swatch
finish
intensity
optional authoritative brand
```

Shared presentation must not own business logic.

## Remove from primary tutorial recommendation UI

```text
Hex
Where to apply
Technique
```

Hard rules:

- Hex preserved internally
- Placement preserved internally
- Technique preserved internally
- downstream consumers untouched
- Makeup Breakdown untouched
- My Kit snapshot untouched

## No fallback

If My Kit lacks authoritative data:

```text
DO NOT DISPLAY STANDARD SUBSTITUTE
DO NOT SILENTLY FILL
```

Use existing truthful behavior or STOP if safe presentation cannot be proven.

## No database-form layout

Do not render primary rows like:

```text
Shade:
Hex:
Finish:
Intensity:
```

Use beauty-oriented hierarchy.

## Swatches

- useful but not enormous
- not sole source of color meaning
- accessible text name required
- global border treatment
- no new color system

## Required tests

Standard:

- section label
- shade names
- swatches
- finish
- intensity
- Hex absent
- Where to apply absent
- Technique absent

My Kit:

- section label
- immutable owned product data
- same visual component
- no Standard fallback
- no substitution
- Hex absent from primary UI
- no duplicate placement/technique

Cross-mode:

- visual parity
- separate data authority
- zero repository merge
- zero extra AI calls

## Validation

Run global validation.

## Real device

POCO X3 GT:

- Standard multi-shade category
- My Kit category with owned product
- compare hierarchy
- verify same structure
- verify truthful data differences only

Return Global Completion Report.

STOP.

---

# TUT-UI-5 — COMPACT FINAL LOOK + FINAL-STEP UNIFICATION

Read all authorities and accepted prior reports.

Implement only:

## TUT-UI-5 — COMPACT FINAL LOOK + FINAL-STEP UNIFICATION

Then STOP.

## Active roles

Especially apply:

- Principal Flutter Architect
- Senior Flutter Engineer
- Senior Component Library Engineer
- Senior Mobile UX Designer
- Senior My Makeup Kit Engineer
- Senior V4 Tutorial Engineer for protection only
- Senior Regression Engineer

## Objective

Use one compact canonical Final Look component on every step and remove special giant Final Look block from final runtime category.

## Target component

```text
┌──────────────────────────────────┐
│ [thumbnail]  Your final look  ↗  │
│              View your target    │
└──────────────────────────────────┘
```

## Authority

Image must reuse existing canonical Final Preview.

No new generation.

No per-step Final Look generation.

No alternate image source.

## Interaction

Tap opens existing canonical fullscreen Final Look viewer.

Do not invent another viewer.

## Final runtime category

Use same shell as regular category.

Only footer action changes:

```text
Next
→
Finish
```

Remove giant inline final-look special case.

Do not hardcode Lips.

## Finish

Preserve accepted completion/Result behavior.

Do NOT:

- regenerate Final Preview
- regenerate manifest
- create new completion screen
- change save/history/reopen

## Standard / My Kit

Same compact component and viewer behavior.

Do not mix Standard preview into My Kit.

## Required tests

- compact Final Look on regular step
- compact Final Look on final runtime step
- giant final inline image absent
- tap opens existing viewer
- same canonical preview identity reused
- Finish unchanged
- runtime final-step detection
- Standard/My Kit parity
- zero AI calls from viewer

## Validation

Run global validation.

## Real device

POCO X3 GT:

- Standard regular/final
- My Kit regular/final where available
- tap Final Look
- fullscreen viewer
- close viewer
- Finish behavior

Return Global Completion Report.

STOP.

---

# TUT-UI-6 — RESPONSIVE + ACCESSIBILITY + GLOBAL THEME POLISH

Read all authorities and accepted prior reports.

Implement only:

## TUT-UI-6 — RESPONSIVE + ACCESSIBILITY + GLOBAL THEME POLISH

Then STOP.

## Active roles

Especially apply:

- Senior Responsive Layout Engineer
- Senior Accessibility Engineer
- Senior Inclusive Design Engineer
- Senior Localization-Readiness Engineer
- Senior Flutter UI Engineer
- Senior Design Systems Engineer
- Senior Visual QA Engineer
- Senior Performance Engineer
- Senior Regression Engineer

## Objective

Polish the unified tutorial across screen sizes, text scales, themes, and accessibility without changing architecture/business behavior.

## Required viewport coverage

- POCO X3 GT
- narrow Android
- 320 logical width where supported
- short viewport
- normal text
- 2x text
- Light
- Dark
- System Light
- System Dark

## Required stress cases

- long category name
- long instruction title/body
- multiple recommendation rows
- long owned-product name
- final runtime category
- Standard
- My Kit

## Footer

Verify:

- persistent
- SafeArea
- no overlay
- full content scrolls above footer
- labels not incorrectly truncated
- adequate touch targets

## Accessibility

Verify:

- X semantics
- Back/Next/Finish semantics
- enlarge semantics
- redraw semantics
- Guide Key reading order
- instruction reading order
- swatch + text semantics
- Final Look semantics
- viewer Close semantics
- no color-only meaning
- reduced motion where supported

## Performance

Prove theme/text/scroll changes cause:

```text
0 AI CALLS
0 MANIFEST CALLS
0 TUTORIAL CALLS
0 REDRAW CALLS
0 PREVIEW CALLS
```

## Do NOT implement

- redesign
- copy changes
- prompt/model changes
- backend changes
- business-authority changes

## Validation

Run global validation.

## Real device

POCO X3 GT full tutorial run:

```text
FIRST RUNTIME STEP
MIDDLE STEP
FINAL RUNTIME STEP
STANDARD
MY KIT where available
```

Verify all major components and Finish behavior.

Return Global Completion Report.

STOP.

---

# TUT-UI-7 — FINAL PROTECTED-DIFF AUDIT + RELEASE ACCEPTANCE

Read all authorities and all accepted TUT-UI reports.

Implement only:

## TUT-UI-7 — FINAL PROTECTED-DIFF AUDIT + RELEASE ACCEPTANCE

Then STOP.

This phase is primarily READ-ONLY.

## Active roles

Especially apply:

- Principal Software Architect
- Principal Flutter Architect
- Senior Release Engineer
- Senior Regression Engineer
- Senior Application Security Engineer
- Senior Privacy Engineer
- Senior Gemini AI Engineer
- Senior Dynamic Manifest Engineer
- Senior My Makeup Kit Engineer
- Senior Visual QA Engineer
- Senior Code Reviewer

## Objective

Prove tutorial UI productionization achieved target UX without changing protected V4 behavior or mode authority.

## Git audit

Run:

```powershell
git branch --show-current
git log -1 --oneline
git status --short
git diff --stat
git diff --name-only
git diff -- supabase/
```

Inspect all tutorial-track diffs.

## Protected baseline proof

Confirm:

```text
FINAL PREVIEW MODEL
gemini-3.1-flash-image

TUTORIAL MODEL
gemini-3.1-flash-image

TUTORIAL RESOLUTION
1K

TUTORIAL PROMPT
tutorial_guideline_v4_7

MANIFEST PROMPT
tutorial_manifest_v4_1

MODEL CHANGES
NONE

PROMPT CHANGES
NONE

EDGE FUNCTION CHANGES
NONE

DB CHANGES
NONE

RLS CHANGES
NONE

STORAGE CHANGES
NONE
```

## Mode-authority proof

Confirm:

```text
STANDARD AUTHORITY
PRESERVED

MY KIT OWNED-PRODUCT AUTHORITY
PRESERVED

MY KIT IMMUTABLE SNAPSHOT
PRESERVED

STANDARD FALLBACK INTO MY KIT
NONE

MY KIT SUBSTITUTION
NONE

BUSINESS CONTROLLERS MERGED
NO
```

## Tutorial architecture acceptance

Confirm:

```text
ONE SHARED PRESENTATION SHELL
PASS

REGULAR / FINAL STEP CONSISTENCY
PASS

PERSISTENT FOOTER
PASS

GUIDE HERO
PASS

COMPACT GUIDE KEY
PASS

REDRAW NEAR GUIDE
PASS

HOW-TO EDITORIAL RAIL
PASS

YOUR GOAL CALLOUT
PASS

STANDARD BEAUTY SHADE SECTION
PASS

MY KIT OWNED-PRODUCT SECTION
PASS

HEX PRIMARY UI
ABSENT

DUPLICATE WHERE TO APPLY / TECHNIQUE
ABSENT FROM TUTORIAL RECOMMENDATION SECTION

COMPACT FINAL LOOK
PASS

GIANT FINAL LOOK FINAL-STEP SPECIAL CASE
ABSENT

FULLSCREEN VIEWER
PASS
```

## Automated validation

Run:

```powershell
dart format .
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/development.json
```

## Real-device final acceptance

Do not fabricate.

POCO X3 GT must verify Standard:

- first step
- middle step
- final runtime step
- Back
- Next
- Finish
- X exit semantics
- enlarge
- redraw placement
- Guide Key
- How to Apply
- Goal
- Suggested shades
- compact Final Look
- fullscreen Final Look

My Makeup Kit where runtime data is available:

- same visual shell
- same navigation
- same guide treatment
- same instruction treatment
- same Final Look component
- truthful owned-product section
- no Standard substitution

Themes/accessibility:

- Dark
- Light where practical
- System
- large text
- no footer overlay
- no clipped content

If device evidence incomplete:

```text
RELEASE STATUS:
PENDING DEVICE ACCEPTANCE
```

Do not declare PASS.

## Final report

Return Global Completion Report plus:

```text
TUTORIAL UI TRACK FINAL STATUS:
ACCEPTED / NOT ACCEPTED / PENDING DEVICE

PROTECTED V4 BASELINE:
PRESERVED / FAIL

STANDARD / MY KIT VISUAL PARITY:
PASS / FAIL / PARTIAL

STANDARD / MY KIT DATA AUTHORITY:
SEPARATE / FAIL

EXTRA AI CALLS:
0 / FAIL

RELEASE BLOCKERS:
NONE / exact blockers

NEXT ACTION:
Do not implement automatically.
```

STOP.
