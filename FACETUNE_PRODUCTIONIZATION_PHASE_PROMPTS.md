# FaceTune — PRODUCTION UI / UX PHASE PROMPTS

**Project root:** `C:\Users\Kurt\facetune`  
**Target UI branch:** `feature/ui-productionization-v1` — branch existence/base MUST be proven in UI-P0 before use  
**Primary device:** POCO X3 GT  
**Framework:** Flutter / Dart  
**Backend:** Supabase — PROTECTED / NO CHANGES AUTHORIZED IN THIS TRACK  
**State management:** Riverpod  
**Architecture:** Clean Architecture + Repository Pattern + Feature-First Structure  
**Source of Truth:** `FACETUNE_UI_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md`  
**This phase file:** `FACETUNE_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md`  

**Final Preview Model — HARD LOCK:** `gemini-3.1-flash-image`  
**Tutorial Guideline Model — HARD LOCK:** `gemini-3.1-flash-image`  
**Tutorial Resolution — HARD LOCK:** `1K`  
**Tutorial Prompt — HARD LOCK:** `tutorial_guideline_v4_7`  
**Manifest Prompt — HARD LOCK:** `tutorial_manifest_v4_1`  
**Accepted V4 Functional Baseline:** PROTECTED  

---

# HOW TO USE THIS FILE

1. Keep this file beside `FACETUNE_UI_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md`.
2. Use either OpenAI Codex or Claude Code Pro with Opus 5.
3. Run **exactly ONE UI phase at a time**.
4. Paste only the prompt for the phase currently being implemented.
5. Read and review the completion report before the next phase.
6. Never auto-continue.
7. Never treat a screenshot alone as proof that behavior remains correct.
8. Never treat automated tests alone as proof of visual polish.
9. Never change the database as a UI convenience.
10. Never change Gemini/model/prompt behavior to make UI easier to build.
11. Never refactor domain/repository/state architecture merely for visual cleanliness.
12. If a requested UI change requires a protected subsystem change, STOP and report first.
13. Production/device evidence wins over stale assumptions.
14. Completion reports are evidence, not authority.
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
6. FACETUNE_UI_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md
7. FACETUNE_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md
8. relevant accepted V4 / UI completion reports
9. actual source code, tests, dependencies, configuration and device evidence relevant to THIS phase
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
- Senior Accessibility Engineer
- Senior Inclusive Design Engineer
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
- Senior My Makeup Kit Engineer
- Senior Code Reviewer

AI/backend roles are included to protect the accepted system, not to redesign it.

Do not behave as a code generator blindly following assumptions.

Inspect first.

Challenge stale documentation.

Prefer the smallest production-safe presentation-layer change.

Preserve working application behavior.

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
- Gemini model names
- Gemini prompts
- Gemini request/response behavior
- AI retries/fallbacks
- AI resolution
- AI call counts
- final-preview generation
- tutorial generation
- manifest logic
- category inclusion
- Makeup Breakdown category authority
- My Makeup Kit ownership/business rules
- database schema
- migrations
- Edge Functions
- RLS
- storage policies
- authentication logic
- repository contracts
- domain entities/rules
- use cases
- persistence contracts
- Riverpod business architecture

Expected backend diff for every UI phase:

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

# GLOBAL UI DESIGN DIRECTION

Use:

## LUMINOUS BEAUTY INTELLIGENCE

FaceTune should feel:

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

- generic AI SaaS aesthetics
- neon
- excessive purple gradients
- excessive glassmorphism
- random glowing borders
- decorative blobs
- emoji icons
- excessive pill shapes
- card nesting
- inconsistent typography
- arbitrary shadows
- screen-specific styling systems

Use the existing brand/theme as evidence and evolve it systematically rather than replacing it from imagination.

---

# GLOBAL RULES BEFORE CODING

For every phase:

```powershell
git branch --show-current
git log -1 --oneline
git status --short
git diff
```

Then inspect:

- current screen implementation
- current theme/design tokens
- current shared components
- current Material 3 usage
- existing UI-specific dependencies
- relevant tests
- responsive/layout behavior
- existing loading/error/empty states
- exact protected logic adjacent to the UI

Identify:

- minimum files to change
- reusable code
- UI-only state if needed
- forbidden adjacent code

Do not edit until the implementation boundary is understood.

---

# GLOBAL RULES DURING IMPLEMENTATION

- preserve Clean Architecture
- preserve Repository Pattern
- preserve feature-first structure
- preserve Riverpod business state
- keep business logic out of widgets
- reuse design tokens/components
- avoid magic UI values
- avoid duplicate component systems
- keep visual state local when genuinely presentation-only
- use ThemeData / ColorScheme
- preserve Light / Dark / System
- preserve semantics/accessibility
- preserve current navigation behavior
- preserve existing data authority
- do not add new dependencies without explicit justification
- do not refactor unrelated files
- do not auto-start another phase

---

# GLOBAL VALIDATION

After each implementation phase, run as applicable:

```powershell
dart format .
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/development.json
```

When a physical device is required and available, use the project's established run command and capture real-device evidence.

If device is unavailable:

```text
REAL DEVICE STATUS:
PENDING DEVICE VERIFICATION
```

Do not fabricate visual success.

Also verify:

```powershell
git diff -- supabase/
```

Expected:

```text
NO BACKEND CHANGES
```

---

# GLOBAL COMPLETION REPORT

Every phase must end with a report using this structure:

```text
PHASE COMPLETED:

AGENT:

BRANCH VERIFIED:

HEAD BEFORE:

HEAD AFTER:

WORKING TREE BEFORE:

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


----------------------------------
UI
----------------------------------

SCREENS / COMPONENTS CHANGED:

DESIGN TOKENS CHANGED:

SHARED COMPONENTS CREATED / MODIFIED:

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
REGRESSION
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

BEFORE / AFTER:
PASS / NOT TOUCHED / FAIL

DYNAMIC MANIFEST:
PASS / NOT TOUCHED / FAIL

MAKEUP BREAKDOWN:
PASS / NOT TOUCHED / FAIL

TUTORIAL:
PASS / NOT TOUCHED / FAIL

HISTORY / REOPEN:
PASS / NOT TOUCHED / FAIL


----------------------------------
VALIDATION
----------------------------------

DART FORMAT:

FLUTTER ANALYZE:

FLUTTER TEST:

ANDROID DEBUG BUILD:

BACKEND DIFF:
NONE / exact unexpected diff

REAL DEVICE:
PASS / FAIL / UNAVAILABLE


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
```

A vague report is not acceptable.

---

# UI-P0 — ACCEPTED BASELINE FREEZE & UI INVENTORY

Read all mandatory authority files completely before making changes.

Implement only:

## UI-P0 — ACCEPTED BASELINE FREEZE & UI INVENTORY

Then STOP.

## Active roles

Especially apply:

- Principal Software Architect
- Principal Flutter Architect
- Senior Frontend Engineer
- Senior Flutter Engineer
- Senior Design Systems Engineer
- Senior Mobile UI/UX Designer
- Senior Regression Engineer
- Senior Code Reviewer

## Objective

Prove the exact accepted FaceTune baseline and map the current UI architecture before any visual redesign begins.

This phase is primarily READ-ONLY.

## Before coding

Run:

```powershell
git branch --show-current
git log -1 --oneline
git status --short
git diff
```

Inspect:

- current branch ancestry
- accepted V4 work presence
- `pubspec.yaml`
- app entry/theme setup
- routing/navigation
- all major screen files
- shared widgets
- design tokens/themes
- current typography
- buttons/inputs/cards
- image containers
- loading/error/empty states
- current Light/Dark/System behavior
- current accessibility patterns
- current responsive layout strategy
- hardcoded colors/font sizes/radii/spacing
- duplicated UI patterns
- UI test coverage

Create a screen inventory covering at minimum:

```text
ENTRY / AUTH
HOME / START
SELFIE / VALIDATION
ANALYSIS / LOADING
STYLE SELECTION
FINAL PREVIEW
BEFORE / AFTER
MAKEUP BREAKDOWN
HISTORY / SAVED LOOKS
MY MAKEUP KIT
TUTORIAL
SETTINGS / APPEARANCE where present
```

## Implement

Create only a privacy-safe UI baseline/audit report containing:

- exact current Git state
- exact current theme architecture
- screen inventory
- shared component inventory
- repeated local styles
- key production-readiness gaps
- responsive risks
- accessibility risks
- loading/error/empty-state inconsistencies
- exact files likely to be touched in UI-P1 through UI-P7
- protected files/functions not to touch

Use:

```text
PASS
ACCEPTABLE
FAIL
NOT TESTED
```

for visual baseline findings.

## Do NOT implement

- broad UI redesign
- new design system
- theme replacement
- screen rewrites
- backend change
- database change
- AI change
- navigation behavior change

## Validation

At minimum:

```powershell
flutter analyze
git diff -- supabase/
```

Run Flutter tests if baseline runtime safety should be confirmed.

Do not generate paid AI content solely for this audit.

## Done when

- current UI system is mapped from actual code
- screen inventory is complete enough for phased redesign
- existing reusable components are identified
- protected baseline is proven
- UI-P1 boundary is explicit
- no product behavior changed

## Completion report additions

```text
UI BASELINE REPORT:
SCREEN INVENTORY:
CURRENT THEME ARCHITECTURE:
CURRENT TYPOGRAPHY:
CURRENT SHARED COMPONENTS:
HARDCODED STYLE FINDINGS:
RESPONSIVE FINDINGS:
ACCESSIBILITY FINDINGS:
GLOBAL STATE FINDINGS:
PROTECTED UI-ADJACENT FILES:
UI-P1 RECOMMENDED FILE BOUNDARY:
```

Then STOP.

---

# UI-P1 — PRODUCTION DESIGN SYSTEM FOUNDATION

Read all mandatory authority files completely before making changes.

Implement only:

## UI-P1 — PRODUCTION DESIGN SYSTEM FOUNDATION

Then STOP.

## Entry gate

UI-P0 must have produced a real code-based UI inventory.

Do not start from imaginary design-system structure.

## Active roles

Especially apply:

- Principal Flutter Architect
- Senior Frontend Engineer
- Senior Flutter Engineer
- Senior Design Systems Engineer
- Senior Component Library Engineer
- Senior UI Designer
- Senior Visual Designer
- Senior Accessibility Engineer
- Senior Regression Engineer

## Objective

Create or consolidate the smallest production-ready FaceTune design-system foundation without redesigning all feature screens yet.

Design direction:

## LUMINOUS BEAUTY INTELLIGENCE

## Before coding

Inspect:

- current ThemeData
- ColorScheme
- TextTheme
- extensions/tokens
- shared widgets
- Material 3 usage
- existing icon family
- current button/input/card implementations
- duplicated magic values

Determine what already exists and can be retained.

## Implement

Create/consolidate reusable presentation foundations for:

- color tokens
- semantic surface roles
- typography hierarchy
- spacing scale
- radius scale
- elevation/border hierarchy
- motion durations/curves where current architecture supports them
- icon policy
- button variants
- input styling
- card/surface primitives
- image container primitive if justified
- divider/section treatment

Requirements:

- Light/Dark/System compatible
- no screen-specific hardcoded design language
- no emoji iconography
- no business logic in components
- no new state authority
- no unnecessary package

## Do NOT implement

- broad screen redesign
- auth-flow rewrite
- navigation rewrite
- results rewrite
- tutorial redesign
- database/backend changes
- AI changes

## Tests

At minimum test where practical:

- Light theme token resolution
- Dark theme token resolution
- System theme compatibility through existing global behavior
- button states
- input states
- large text resilience of shared primitives
- no overflow in representative shared components

## Device QA

On POCO X3 GT where available, verify shared primitives are readable and coherent.

Do not claim the whole app is visually complete yet.

## Done when

- a single reusable production design foundation exists
- current brand identity is preserved/evolved rather than arbitrarily replaced
- shared primitives are testable
- no product behavior changed
- UI-P2 can consume the system

## Completion report additions

```text
DESIGN DIRECTION:
COLOR SYSTEM:
TYPOGRAPHY SYSTEM:
SPACING SYSTEM:
RADIUS SYSTEM:
SURFACE / ELEVATION SYSTEM:
ICON SYSTEM:
BUTTON SYSTEM:
INPUT SYSTEM:
SHARED COMPONENTS:
LIGHT:
DARK:
SYSTEM:
```

Then STOP.

---

# UI-P2 — APP SHELL, NAVIGATION & GLOBAL STATES

Read all mandatory authority files completely before making changes.

Implement only:

## UI-P2 — APP SHELL, NAVIGATION & GLOBAL STATES

Then STOP.

## Entry gate

UI-P1 design-system foundation accepted.

## Active roles

Especially apply:

- Senior Frontend Engineer
- Senior Flutter Engineer
- Senior Mobile UI Engineer
- Senior Interaction Engineer
- Senior Responsive Layout Engineer
- Senior Accessibility Engineer
- Senior QA Engineer

## Objective

Apply the production design system to the reusable app shell and application-wide presentation states without changing navigation/domain behavior.

## Audit first

Inspect:

- current route shell
- app bars
- bottom navigation/tabs if present
- dialogs
- bottom sheets
- loading widgets
- empty states
- error states
- success feedback
- image placeholders
- common page padding/safe-area behavior

## Implement

Polish only presentation of:

- app bars
- navigation chrome
- selected/unselected navigation states
- common page scaffolds/surfaces
- common dialogs
- common sheets
- loading components
- skeletons only where truthful
- empty-state component
- error-state component
- success feedback component
- common image loading/error containers

Do not change route destinations or guards.

## Loading rules

No fake progress percentages.

No repeated network/provider action due to animation/rebuild.

## Error rules

Do not expose internal exceptions/secrets.

Preserve semantic error meaning.

## Tests

- Light/Dark/System shell
- navigation presentation does not alter destinations
- loading state does not trigger duplicate actions
- empty/error states render without overflow
- large text
- narrow width

## Done when

- application-wide chrome/state presentation is coherent
- feature screens can reuse the shared shell/states
- navigation behavior remains unchanged

## Completion report additions

```text
APP SHELL:
APP BAR:
NAVIGATION PRESENTATION:
DIALOGS:
BOTTOM SHEETS:
LOADING STATES:
EMPTY STATES:
ERROR STATES:
SUCCESS STATES:
COMMON IMAGE STATES:
ROUTING BEHAVIOR CHANGED: NO
```

Then STOP.

---

# UI-P3 — ENTRY & CREATION FLOW POLISH

Read all mandatory authority files completely before making changes.

Implement only:

## UI-P3 — ENTRY & CREATION FLOW POLISH

Then STOP.

## Entry gate

UI-P2 accepted.

## Active roles

Especially apply:

- Senior Frontend Developer
- Senior Flutter Developer
- Senior Mobile Product Designer
- Senior UX Designer
- Senior Interaction Engineer
- Senior Accessibility Engineer
- Senior Regression Engineer

## Objective

Make the first-use and makeup-creation journey feel like one polished consumer beauty experience while preserving all existing logic.

## Screens in scope

Only existing screens in this flow, such as:

- onboarding if present
- login
- registration
- recovery presentation if present
- home/start
- selfie capture/import
- selfie validation state
- analysis/loading
- style selection

Do not invent missing product features.

## Hard logic locks

Do NOT modify:

- auth provider/session logic
- selfie validation rules
- image-processing rules
- face analysis
- Gemini calls
- style data/selection logic
- recommendation generation
- navigation destination behavior

## Implement

Improve:

- visual hierarchy
- typography
- screen gutters
- CTA consistency
- form presentation
- validation-message presentation
- loading hierarchy
- image preview presentation
- style card presentation
- selected state clarity
- transitions where justified
- accessibility
- responsive layout

## Analysis/loading rule

Do not invent analysis steps or percentages not backed by actual state.

## Tests

At minimum:

- login/register actions still invoke existing logic
- validation errors preserved
- selfie controls unchanged behavior
- style selection identity/value unchanged
- large text
- narrow width
- Light/Dark/System

## Device QA

Run the flow on POCO X3 GT when available:

```text
ENTRY
→ SELFIE
→ ANALYSIS
→ STYLE
```

Confirm no behavioral regression.

## Done when

- creation flow has one coherent visual language
- business behavior is unchanged
- no backend/AI change exists

## Completion report additions

```text
ENTRY UI:
AUTH UI:
HOME / START:
SELFIE UI:
VALIDATION UI:
ANALYSIS / LOADING UI:
STYLE SELECTION UI:
AUTH LOGIC PRESERVED:
SELFIE LOGIC PRESERVED:
STYLE LOGIC PRESERVED:
```

Then STOP.

---

# UI-P4 — RESULTS, HISTORY & MY MAKEUP KIT POLISH

Read all mandatory authority files completely before making changes.

Implement only:

## UI-P4 — RESULTS, HISTORY & MY MAKEUP KIT POLISH

Then STOP.

## Entry gate

UI-P3 accepted.

## Active roles

Especially apply:

- Senior Frontend Engineer
- Senior Flutter Engineer
- Senior Mobile UI/UX Designer
- Senior Image Presentation Engineer
- Senior My Makeup Kit Engineer
- Senior Accessibility Engineer
- Senior Regression Engineer

## Objective

Make generated results and saved content feel like the emotional payoff of FaceTune while preserving exact data/category/product authority.

## Screens/components in scope

- Final Preview result page
- Before / After presentation
- Makeup Breakdown presentation
- History / saved looks
- My Makeup Kit presentation
- related loading/empty/error states

## Hard locks

Do NOT modify:

- final-preview generation
- manifest timing/logic
- category filtering
- category ordering
- category grouping
- recommendation data
- Standard metadata authority
- My Kit immutable snapshot authority
- save/history persistence
- private image storage

## Required Makeup Breakdown invariant

Presentation must still represent the exact accepted categories:

```text
BREAKDOWN CATEGORY IDS
=
TUTORIAL CATEGORY IDS
```

Do not accidentally turn inner items such as Lipstick + Lip Gloss into separate canonical categories.

## Implement

Improve:

- final preview hero treatment
- Before / After controls/presentation using current behavior
- image loading/error states
- Makeup Breakdown hierarchy
- category headers
- inner recommendation/product detail readability
- History grid/list/card presentation
- empty history state
- My Kit category/product card hierarchy
- empty kit state
- mismatch/error presentation
- responsive behavior
- accessibility

## Image rule

Do not crop or mask faces in a way that hides the final makeup result.

## Tests

- category identity/order preserved
- multiple inner items remain within one canonical category
- Standard metadata unchanged
- My Kit snapshot data unchanged
- History opens same saved look
- loading/error/empty states
- Light/Dark/System
- large text/narrow width

## Device QA

Verify on POCO X3 GT:

```text
FINAL PREVIEW
BEFORE / AFTER
MAKEUP BREAKDOWN
HISTORY
MY MAKEUP KIT
```

## Done when

- results feel production-ready
- saved content is coherent
- data authority is untouched

## Completion report additions

```text
FINAL PREVIEW UI:
BEFORE / AFTER UI:
MAKEUP BREAKDOWN UI:
CATEGORY AUTHORITY PRESERVED:
HISTORY UI:
MY MAKEUP KIT UI:
IMMUTABLE SNAPSHOT AUTHORITY PRESERVED:
IMAGE PRESENTATION:
```

Then STOP.

---

# UI-P5 — TUTORIAL PRESENTATION POLISH

Read all mandatory authority files completely before making changes.

Implement only:

## UI-P5 — TUTORIAL PRESENTATION POLISH

Then STOP.

## Entry gate

UI-P4 accepted.

## Active roles

Especially apply:

- Senior Flutter UI Engineer
- Senior Frontend Developer
- Senior Instructional UX Designer
- Senior Mobile Product Designer
- Senior Accessibility Engineer
- Senior Visual QA Engineer
- Senior V4 Tutorial Systems Reviewer

## Objective

Polish the Flutter presentation of the accepted V4 tutorial without changing any tutorial AI, manifest, category, persistence, or recommendation behavior.

## Hard freeze

Do NOT modify:

```text
tutorial_guideline_v4_7
tutorial_manifest_v4_1
gemini-3.1-flash-image
1K
```

Do NOT modify:

- guideline generation
- category inclusion
- manifest
- step planner
- recommendation authority
- product snapshot authority
- redraw business logic
- tutorial persistence
- image-generation calls

## UI areas in scope

- STEP X OF N hierarchy
- category title
- guideline image container
- Guide Key
- HOW TO APPLY
- numbered instruction presentation
- YOUR GOAL
- shade/HEX/finish/intensity presentation
- product details
- Final Look reference
- Back / Next presentation
- redraw confirmation presentation
- image-viewer entry affordance

## Design target

Current content must feel intentionally instructional, not like stacked debug cards.

Prefer:

- clear hierarchy
- restrained grouping
- compact guide semantics
- readable numbered instructions
- strong association between guide image and HOW TO APPLY
- metadata that is easy to scan
- clear Final Look destination

Avoid:

- card soup
- excessive borders
- giant metadata blocks
- decorative geometry unrelated to teaching
- new AI text/numbers inside images

## Important historical lock

Do NOT restore the rejected Gemini on-image annotation experiment.

Flutter continues to own instructional text and numbering.

## Tests

- instruction order unchanged
- Guide Key semantics unchanged
- product/shade metadata unchanged
- Final Look uses same canonical preview
- no extra generation
- Light/Dark/System
- narrow width
- large text
- viewer still opens
- redraw still requires existing explicit confirmation behavior

## Device QA

On POCO X3 GT verify representative steps, preferably including:

- one complexion category
- Blush or Highlighter
- one eye category
- Lips

This phase reviews UI, not prompt quality.

## Done when

- tutorial looks production-ready
- tutorial remains behaviorally identical
- all AI/manifest locks remain unchanged

## Completion report additions

```text
TUTORIAL HIERARCHY:
GUIDELINE IMAGE PRESENTATION:
GUIDE KEY PRESENTATION:
HOW TO APPLY PRESENTATION:
METADATA PRESENTATION:
FINAL LOOK PRESENTATION:
NAVIGATION PRESENTATION:
REDRAW PRESENTATION:
AI / MANIFEST CHANGES: NONE
```

Then STOP.

---

# UI-P6 — FULL-APP RESPONSIVE, ACCESSIBILITY & THEME QA

Read all mandatory authority files completely before making changes.

Implement only:

## UI-P6 — FULL-APP RESPONSIVE, ACCESSIBILITY & THEME QA

Then STOP.

## Entry gate

UI-P1 through UI-P5 accepted or accepted with explicit visual limitations.

## Active roles

Especially apply:

- Senior Responsive Layout Engineer
- Senior Accessibility Engineer
- Senior Inclusive Design Engineer
- Senior Flutter Engineer
- Senior Visual QA Engineer
- Senior Regression Engineer
- Senior Performance Engineer

## Objective

Prove the productionized UI behaves coherently across theme, screen width, text scale, scrolling, and accessibility constraints.

This phase is QA-first.

Only remediate defects proven by the matrix.

Do not opportunistically redesign screens.

## Required matrix

At minimum validate:

```text
LIGHT
DARK
SYSTEM
```

and representative layout conditions:

```text
NARROW WIDTH ~320 logical px where feasible
POCO X3 GT
LARGER TEXT SCALE
DEFAULT TEXT SCALE
```

## Screens

Cover at minimum:

- auth/entry
- home/start
- selfie
- analysis/loading
- style selection
- final preview
- Makeup Breakdown
- History
- My Makeup Kit
- tutorial

## Accessibility checks

- semantic labels
- button touch targets
- text contrast
- non-color-only states
- large-text clipping
- scroll safety
- image semantics where useful
- focus/keyboard behavior where applicable

## Responsive checks

- horizontal overflow
- clipped actions
- fixed-height text clipping
- image aspect ratios
- nested scrolling conflicts
- keyboard obstruction
- safe area

## Theme checks

- background
- surfaces
- cards
- text
- dividers
- buttons
- inputs
- dialogs/sheets
- image containers
- loading/error/empty
- tutorial metadata

## Performance observation

Watch for obvious issues introduced by polish:

- janky animations
- expensive blur/shadow
- repeated image loads
- excessive rebuilds

Do not rewrite performance architecture without evidence.

## Tests

Add/update focused widget/golden-like tests only where the project already supports them safely.

Do not introduce a new screenshot-test framework merely for this phase unless explicitly approved.

## Done when

- no known blocking overflow
- themes coherent
- larger text usable
- POCO X3 GT readable
- accessibility defects are remediated or explicitly documented
- no behavior regression found

## Completion report additions

```text
LIGHT THEME:
DARK THEME:
SYSTEM THEME:
NARROW WIDTH:
POCO X3 GT:
DEFAULT TEXT:
LARGE TEXT:
OVERFLOW:
ACCESSIBILITY:
PERFORMANCE OBSERVATIONS:
DEFECTS REMEDIATED:
DEFERRED LIMITATIONS:
```

Then STOP.

---

# UI-P7 — PRODUCTION UI BASELINE LOCK

Read all mandatory authority files completely before making changes.

Implement only:

## UI-P7 — PRODUCTION UI BASELINE LOCK

Then STOP.

## Entry gate

UI-P6 completed with device evidence where available.

## Active roles

Apply the full review team, especially:

- Principal Software Architect
- Principal Flutter Architect
- Senior Frontend Engineer
- Senior Design Systems Engineer
- Senior Mobile Product Designer
- Senior Accessibility Engineer
- Senior Visual QA Engineer
- Senior Regression Engineer
- Senior End-to-End Test Engineer
- Senior Release Engineer
- Senior Code Reviewer

## Objective

Prove the UI productionization track works end-to-end and formally lock the accepted production UI baseline.

No new feature development.

Only minimal remediation of a proven release-blocking UI defect is allowed.

## Required end-to-end journeys

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
Recommendation
↓
Final Preview
↓
Makeup Breakdown
↓
Tutorial
↓
History / Reopen
```

### My Makeup Kit

```text
Auth
↓
My Makeup Kit
↓
Selfie
↓
Analysis
↓
Style
↓
Owned-product recommendation
↓
Final Preview
↓
Makeup Breakdown
↓
Tutorial
↓
History / Reopen
```

## Required UI evidence

Validate:

- coherent design language
- shared component reuse
- entry/auth UI
- creation flow
- results
- Before / After
- Makeup Breakdown
- History
- My Makeup Kit
- tutorial
- loading states
- empty states
- error states
- Light
- Dark
- System
- POCO X3 GT
- narrow layout
- larger text
- image usability
- navigation clarity

## Protected regression checks

Explicitly verify no regression in:

- auth logic
- selfie logic
- analysis
- style
- recommendation
- final preview
- dynamic manifest
- Breakdown ↔ Tutorial consistency
- My Kit authority
- History/reopen
- private storage
- RLS
- AI models/prompts

## Validation

Run:

```powershell
dart format .
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/development.json
```

When device available:

```powershell
flutter run --dart-define-from-file=config/development.json
```

Use actual project-established commands if they differ.

## Quality decision

Final decision must be exactly one of:

```text
UI BASELINE ACCEPTED
UI BASELINE ACCEPTED WITH RESTRICTIONS
UI BASELINE REJECTED
```

Do not declare acceptance merely because tests are green.

Human real-device visual evidence is required for a full acceptance decision.

## Completion report additions

```text
DESIGN SYSTEM:
APP SHELL:
ENTRY / AUTH:
CREATION FLOW:
RESULTS:
BEFORE / AFTER:
MAKEUP BREAKDOWN:
HISTORY:
MY MAKEUP KIT:
TUTORIAL:
LOADING / EMPTY / ERROR:
LIGHT:
DARK:
SYSTEM:
NARROW WIDTH:
LARGE TEXT:
POCO X3 GT:
ACCESSIBILITY:
PERFORMANCE:
PROTECTED V4 REGRESSION:
BACKEND DIFF:
AI LOCKS:
QUALITY DECISION:
UI BASELINE ACCEPTED / UI BASELINE ACCEPTED WITH RESTRICTIONS / UI BASELINE REJECTED
```

## Done when

- the full app UI is demonstrably coherent
- protected behavior remains intact
- no unauthorized backend/domain/AI change exists
- device evidence exists or explicit restriction is recorded
- quality decision is documented

Then STOP.

Do not automatically begin another product-development track.
