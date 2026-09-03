# FaceTune — PRODUCTION UI / UX SOURCE OF TRUTH

**Project Path:** `C:\Users\Kurt\facetune`  
**Project Name:** FaceTune  
**Tagline:** Your AI Makeup Artist  
**Primary Platform:** Android  
**Primary Test Device:** POCO X3 GT  
**Framework:** Flutter  
**Language:** Dart  
**Backend:** Supabase  
**AI Provider:** Google Gemini API  
**State Management:** Riverpod  
**Architecture:** Clean Architecture + Repository Pattern + Feature-First Structure  
**Accepted V4 Tutorial Branch:** `feature/step-by-step-tutorial-v4-ai`  
**UI Productionization Branch (target):** `feature/ui-productionization-v1`  
**UI Productionization Base:** MUST be proven from the accepted working V4 baseline in UI-P0; never assume `main` already contains every accepted V4 change  
**Accepted V4 Tutorial Quality Baseline:** ACCEPTED after real-device post-deploy smoke verification  
**Canonical Final Preview Renderer — HARD LOCK:** `gemini-3.1-flash-image`  
**Tutorial Guideline Renderer — HARD LOCK:** `gemini-3.1-flash-image`  
**Tutorial Guideline Resolution — HARD LOCK:** `1K`  
**Tutorial Prompt — HARD LOCK:** `tutorial_guideline_v4_7`  
**Manifest Prompt — HARD LOCK:** `tutorial_manifest_v4_1`  
**Recommendation Modes:** `standard` + `my_makeup_kit`  
**UI Track Scope:** presentation-layer productionization only  
**UI Design Direction:** Luminous Beauty Intelligence  
**Release Goal For This Track:** a coherent, premium, responsive, accessible, production-ready FaceTune interface that preserves the accepted functional baseline exactly  

---

# 0. PURPOSE

This document is the highest authority for the FaceTune **Production UI / UX Track**.

FaceTune already has a working accepted functional baseline.

This track does **not** rebuild the AI system, tutorial system, recommendation system, backend, authentication logic, storage model, persistence model, or application domain architecture.

This track exists to answer one product question:

> **How do we make the already-working FaceTune application look and feel like a polished, premium, trustworthy consumer beauty product without changing how the system works?**

The central principle is:

> **CHANGE THE PRESENTATION, NOT THE SYSTEM.**

The UI track may improve:

```text
VISUAL HIERARCHY
TYPOGRAPHY
SPACING
SURFACES
CARDS
BUTTONS
INPUTS
NAVIGATION PRESENTATION
LOADING STATES
EMPTY STATES
ERROR STATES
SUCCESS STATES
PROGRESS STATES
IMAGE PRESENTATION
RESPONSIVE LAYOUT
ACCESSIBILITY
MOTION / TRANSITIONS
LIGHT / DARK / SYSTEM CONSISTENCY
ICON CONSISTENCY
SCREEN-TO-SCREEN COHERENCE
```

The UI track must preserve:

```text
AUTHENTICATION BEHAVIOR
SELFIE FLOW
FACE ANALYSIS
STYLE SELECTION LOGIC
RECOMMENDATION LOGIC
FINAL PREVIEW GENERATION
BEFORE / AFTER LOGIC
DYNAMIC MANIFEST
MAKEUP BREAKDOWN AUTHORITY
STEP-BY-STEP TUTORIAL AUTHORITY
MY MAKEUP KIT BUSINESS RULES
HISTORY / REOPEN / REUSE
RIVERPOD BUSINESS STATE
SUPABASE ARCHITECTURE
DATABASE SCHEMA
RLS
PRIVATE STORAGE
AI MODELS
AI PROMPTS
AI CALL COUNTS
```

A visually attractive implementation that changes working behavior is a failure.

---

# 1. DOCUMENT AUTHORITY

Before ANY UI implementation, the coding agent must read these files completely, in this order when they exist:

1. `CODEX_MASTER_GUIDE.md`
2. `FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_SOURCE_OF_TRUTH.md`
3. `FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_PHASE_PROMPTS.md`
4. `FACETUNE_V4_TUTORIAL_QUALITY_SOURCE_OF_TRUTH.md`
5. `FACETUNE_V4_TUTORIAL_QUALITY_PHASE_PROMPTS.md`
6. `FACETUNE_UI_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md`
7. `FACETUNE_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md`
8. relevant accepted V4 / UI completion reports
9. actual current source code, tests, configuration, migrations, deployed functions, and device evidence relevant to the current phase

Authority order:

1. **This UI Source of Truth** governs the Production UI / UX Track.
2. The accepted V4 Source of Truth and V4 Quality Source of Truth continue to govern the protected AI/tutorial architecture.
3. `CODEX_MASTER_GUIDE.md` governs general FaceTune engineering outside narrower source-of-truth documents.
4. The active UI phase prompt authorizes only that phase.
5. Completion reports are evidence, not truth.
6. Actual current code beats assumptions about what the code should contain.
7. Real-device behavior beats stale screenshots or stale reports.
8. A phase may never silently widen its own scope.
9. A UI convenience never authorizes backend/domain/security changes.

If an older UI idea conflicts with this document, this document wins for this track.

---

# 2. SYSTEM ROLE

The coding agent must behave as a disciplined production UI engineering team.

Apply the roles relevant to each phase, including:

## Architecture / Engineering Leadership

- Principal Software Engineer
- Principal Software Architect
- Principal Mobile Architect
- Principal Flutter Architect
- Senior Code Reviewer
- Senior Release Engineer

## Frontend / Flutter Engineering

- Senior Frontend Engineer
- Senior Frontend Developer
- Senior Flutter Engineer
- Senior Flutter Developer
- Senior Dart Engineer
- Senior Dart Developer
- Senior Mobile Application Engineer
- Senior Mobile Application Developer
- Senior Riverpod Engineer
- Senior Flutter Performance Engineer

## UI Engineering / Design Systems

- Senior Design Systems Engineer
- Senior Design Systems Developer
- Senior Flutter UI Engineer
- Senior Mobile UI Engineer
- Senior Component Library Engineer
- Senior Responsive Layout Engineer
- Senior Motion / Interaction Engineer
- Senior Visual QA Engineer

## Product / Design

- Senior Mobile Product Designer
- Senior UI Designer
- Senior UX Designer
- Senior UI/UX Designer
- Senior Interaction Designer
- Senior Visual Designer
- Senior Beauty-App Product Designer
- Senior Information Architecture Designer

## Accessibility / Localization Readiness

- Senior Accessibility Engineer
- Senior Inclusive Design Engineer
- Senior Semantic UI Engineer
- Senior Localization-Readiness Engineer

## Protection / Regression

- Senior Application Security Engineer
- Senior Privacy Engineer
- Senior Supabase Engineer
- Senior Backend Engineer
- Senior QA Engineer
- Senior Regression Engineer
- Senior Integration Test Engineer
- Senior End-to-End Test Engineer
- Senior Production Debugging Engineer
- Senior Reliability Engineer
- Senior Performance Engineer

## Protected AI Awareness

- Senior Gemini AI Engineer
- Senior AI Systems Engineer
- Senior My Makeup Kit Engineer

The AI-related roles are present to **protect existing behavior**, not to redesign AI during UI work.

The coding agent must not behave as a code generator that blindly follows the prompt.

It must:

- inspect first
- challenge stale assumptions
- reuse existing working code
- identify the smallest safe presentation-layer surface
- avoid broad rewrites
- preserve current behavior
- stop when a requested visual change requires a protected cross-layer change

---

# 3. ENGINEERING PRIORITIES

Every UI decision must prioritize:

1. correctness
2. preservation of working behavior
3. visual consistency
4. usability
5. accessibility
6. responsive behavior
7. maintainability
8. performance
9. testability
10. security
11. privacy
12. production polish

Visual polish never outranks correctness.

A beautiful broken screen is a failed screen.

---

# 4. ACCEPTED V4 BASELINE — PROTECTED

The accepted V4 baseline is a dependency, not a redesign target.

Known-good systems include:

```text
AUTH
↓
SELFIE
↓
FACE ANALYSIS
↓
STYLE
↓
RECOMMENDATION
↓
CANONICAL FINAL PREVIEW
↓
DYNAMIC MANIFEST
↓
MAKEUP BREAKDOWN
+
STEP-BY-STEP TUTORIAL
↓
SAVE / HISTORY / REOPEN
```

Both recommendation modes remain supported:

```text
STANDARD
MY MAKEUP KIT
```

The UI may change how these systems are presented.

The UI may NOT change how they decide, generate, validate, persist, authorize, or secure data.

---

# 5. HARD AI LOCKS

Every UI phase must verify these remain unchanged:

```text
FINAL PREVIEW MODEL
= gemini-3.1-flash-image

TUTORIAL GUIDELINE MODEL
= gemini-3.1-flash-image

TUTORIAL RESOLUTION
= 1K

TUTORIAL PROMPT
= tutorial_guideline_v4_7

MANIFEST PROMPT
= tutorial_manifest_v4_1
```

UI work must NOT modify:

- Gemini model names
- Gemini configuration
- Gemini request payloads
- Gemini response parsing
- final-preview prompts
- tutorial prompts
- manifest prompts
- recommendation prompts
- AI retry behavior
- AI fallback behavior
- AI call counts
- AI output resolution
- image-generation parameters
- model-lock logic

Any unauthorized AI diff during this track is a HARD FAILURE.

---

# 6. FINAL PREVIEW PIPELINE — PROTECTED

Do NOT modify:

- `generate-makeup-preview`
- `generate-kit-makeup-preview`
- final-preview model resolution
- canonical-preview authority
- final-preview generation orchestration
- final-preview persistence
- final-preview storage behavior
- final-preview request structure
- final-preview preprocessing
- final-preview parser

Allowed:

- redesign image container
- improve aspect-ratio handling
- improve placeholder/loading/error presentation
- improve Before / After presentation
- improve surrounding copy/hierarchy
- improve accessibility labels

The UI may change how the preview is **shown**.

It may not change how the preview is **produced**.

---

# 7. TUTORIAL SYSTEM — PROTECTED

Do NOT modify:

- tutorial AI generation
- tutorial prompt `tutorial_guideline_v4_7`
- tutorial model
- tutorial 1K resolution
- guideline-only contract
- manifest prompt `tutorial_manifest_v4_1`
- manifest analyzer behavior
- dynamic category inclusion
- category vocabulary
- category order
- tutorial persistence
- redraw business logic
- tutorial retry/attempt limits already present
- canonical final-look reference authority

Allowed UI work:

- visual hierarchy
- typography
- spacing
- card presentation
- Guide Key presentation
- HOW TO APPLY presentation
- product/shade metadata presentation
- Final Look section presentation
- progress presentation
- navigation presentation
- viewer entry affordance
- loading/error states
- responsive behavior
- accessibility

No AI prompt change is authorized to make a tutorial card easier to design.

---

# 8. MAKEUP BREAKDOWN — PROTECTED DATA AUTHORITY

Do NOT modify:

- accepted manifest authority
- canonical category identity
- canonical category order
- grouping logic
- recommendation mapping
- Standard metadata authority
- My Makeup Kit immutable product authority

Required invariant remains:

```text
ONE MANIFEST CATEGORY
=
ONE MAKEUP BREAKDOWN CATEGORY
=
ONE STEP-BY-STEP CATEGORY
```

The UI may redesign the presentation of categories and inner items.

It may not change which categories appear.

---

# 9. MY MAKEUP KIT — PROTECTED BUSINESS RULES

Do NOT modify:

- owned-product validation
- product ownership authority
- immutable product snapshots
- mismatch behavior
- product substitution rules
- recommendation logic
- historical product authority

UI may improve:

- product card hierarchy
- category grouping presentation
- empty states
- mismatch/error presentation
- product image containers
- typography
- spacing
- accessibility

Business rules remain unchanged.

---

# 10. BACKEND / DATABASE — HARD FREEZE

This is a UI-only track.

Do NOT modify:

- Supabase Edge Functions
- database schema
- migrations
- tables
- columns
- indexes
- triggers
- database functions
- RPCs
- RLS policies
- storage policies
- auth server behavior
- server-side ownership rules

Expected for every UI phase:

```text
DATABASE MIGRATIONS: NONE
RLS CHANGES: NONE
STORAGE POLICY CHANGES: NONE
EDGE FUNCTION CHANGES: NONE
```

If a UI request appears to require backend persistence or schema work:

```text
STOP
↓
REPORT EXACT DEPENDENCY
↓
DO NOT IMPLEMENT IT
```

---

# 11. AUTHENTICATION — PRESENTATION ONLY

Authentication screens may be visually redesigned.

Do NOT modify:

- login logic
- registration logic
- auth provider
- session behavior
- token behavior
- recovery logic
- logout logic
- auth guards
- user identity authority

Allowed:

- layout
- typography
- input styling
- password affordances already supported
- validation-message presentation
- loading state
- error state
- spacing
- responsive design
- accessibility

---

# 12. RIVERPOD / STATE MANAGEMENT — PROTECTED

Do NOT:

- replace Riverpod
- redesign provider architecture
- move business logic into widgets
- create parallel sources of truth
- refactor providers merely for aesthetic cleanliness

Allowed local presentation state includes only genuinely visual concerns such as:

- selected tab
- expanded/collapsed section
- carousel/page position
- temporary sheet/dialog state
- local animation state
- local focus state

Domain authority stays where it currently belongs.

---

# 13. DOMAIN / REPOSITORIES / USE CASES — PROTECTED

UI phases must not change:

- repository contracts
- repository implementations
- domain entities
- domain rules
- use cases
- persistence contracts
- recommendation logic

If compilation proves a presentation adapter is missing and a cross-layer adjustment appears necessary:

STOP and report first.

Do not implement the cross-layer change automatically.

---

# 14. SECURITY / PRIVACY — HARD LOCK

Do NOT:

- weaken RLS
- make private storage public
- expose signed URLs unnecessarily
- expose Gemini keys
- expose service-role keys
- log JWTs
- log private image bytes
- log base64 images
- log private prompts
- move ownership checks client-side
- bypass authentication for visual convenience

UI productionization must preserve security exactly.

---

# 15. UI DESIGN DIRECTION — LUMINOUS BEAUTY INTELLIGENCE

FaceTune should feel:

- elegant
- premium
- calm
- modern
- intelligent
- editorial
- beauty-focused
- trustworthy
- refined
- consumer-ready

The visual experience should resemble a high-quality beauty product, not a generic AI dashboard.

Avoid:

- cheap AI gradients
- excessive neon
- excessive purple
- excessive glassmorphism
- random glowing borders
- decorative blobs without purpose
- childish visual language
- excessive rounded rectangles
- card-inside-card-inside-card layouts
- arbitrary gradients
- random icon styles
- inconsistent typography
- excessive shadows
- fake luxury gold everywhere
- screen-specific design languages

The UI should communicate confidence through restraint.

---

# 16. DESIGN SYSTEM PRINCIPLE

Production UI must be system-driven.

Avoid scattered magic values.

Create or consolidate reusable global tokens/components for:

- colors
- typography
- spacing
- radius
- elevation
- borders
- motion
- iconography
- buttons
- inputs
- cards
- app bars
- dialogs
- sheets
- loading states
- empty states
- error states
- success states
- image containers
- dividers
- chips where truly needed

Individual screens must consume the same system rather than inventing local styles.

---

# 17. COLOR SYSTEM

The coding agent must first inspect the existing FaceTune theme and branding.

Do not blindly replace functioning brand colors.

Target characteristics:

- soft beauty-oriented neutrals
- restrained warm/cosmetic accents
- high text readability
- sufficient contrast
- subtle surface separation
- no color-only semantic communication
- coherent Light and Dark counterparts

Color must come from ThemeData / ColorScheme / design tokens.

Do not scatter literal hex values across widgets unless a narrowly scoped asset color truly requires it.

---

# 18. TYPOGRAPHY SYSTEM

Create a deliberate hierarchy for at minimum:

- display / hero
- screen title
- section title
- card title
- body
- secondary body
- label
- metadata
- caption
- button text

Rules:

- prioritize readability over decorative fonts
- avoid too many font weights
- avoid tiny metadata
- support larger text scales
- avoid manually setting font sizes on every screen when theme styles suffice
- use one coherent family strategy unless actual brand requirements prove otherwise

Beauty-app polish comes from hierarchy, not from using five fashionable fonts.

---

# 19. SPACING SYSTEM

Use a small reusable spacing scale.

Avoid arbitrary values such as:

```text
13
17
21
29
```

scattered through unrelated widgets merely because they looked acceptable during one screenshot.

Spacing should support:

- dense metadata
- normal cards
- screen gutters
- section separation
- large hero spacing

Consistency is more important than a mathematically perfect scale.

---

# 20. RADIUS / SHAPE SYSTEM

Use controlled radius tokens.

Avoid every element being a pill.

Differentiate:

- buttons
- cards
- chips
- image containers
- dialogs/sheets
- input fields

Do not use extreme rounding as a substitute for visual design.

---

# 21. ELEVATION / SURFACE SYSTEM

Prefer subtle hierarchy using:

- surface tone
- borders
- spacing
- typography
- restrained shadow

Avoid heavy floating cards everywhere.

Light and Dark must both remain readable.

---

# 22. ICON POLICY

FaceTune must use a coherent professional vector icon system.

Do NOT use emojis as UI icons.

Prohibited:

- emoji navigation
- emoji buttons
- emoji state indicators
- emoji loading indicators
- decorative Unicode symbols pretending to be production icons

Prefer one icon family already compatible with the project, such as Material Symbols, unless the current app has another established professional family.

Do not mix icon families arbitrarily.

---

# 23. BUTTON SYSTEM

Create/reuse clear variants such as:

- primary
- secondary
- tertiary/text
- destructive where genuinely required
- icon button

States must cover:

- enabled
- pressed
- disabled
- loading
- focus/semantic behavior where applicable

A button must not visually imply availability when the existing domain state says the action is unavailable.

UI styling cannot bypass domain guards.

---

# 24. INPUT SYSTEM

Inputs should share:

- consistent labels
- consistent helper/error presentation
- consistent padding
- consistent focus states
- semantic labels
- keyboard-safe layouts
- password visibility controls only where existing functionality supports them

Do not rewrite validation logic during visual polish.

---

# 25. IMAGE PRESENTATION

FaceTune is image-centric.

Production UI must handle:

- original selfie
- final preview
- tutorial guideline images
- history thumbnails
- My Kit product images where present

Every image surface must have truthful:

- loading state
- failure state
- aspect-ratio behavior
- clipping behavior
- accessibility semantics where practical

Do not crop face images aggressively merely for visual style.

Do not create fake image placeholders that look like actual generated results.

---

# 26. LOADING EXPERIENCE

Loading states must communicate actual state without inventing fake progress.

Allowed:

- spinner/progress indicator
- skeletons for deterministic content structures
- concise explanatory copy
- staged presentation only when actual state is available

Forbidden:

- fake percentages
- fake AI stages not represented by system state
- animation that triggers repeated provider/API work
- loading screens that restart requests on rebuild

---

# 27. EMPTY STATES

Create deliberate empty states for screens such as:

- History
- My Makeup Kit
- results/list surfaces where no data legitimately exists

An empty state should contain:

- clear explanation
- one useful next action when available
- no invented data

Avoid giant illustrations unless they genuinely improve the experience.

---

# 28. ERROR STATES

Errors must be:

- readable
- actionable where the existing system supports an action
- honest
- visually integrated

Do not expose raw stack traces, server secrets, signed URLs, or internal exception dumps.

UI may improve error copy/presentation only when semantic meaning is preserved.

Do not change error classification/business behavior.

---

# 29. SUCCESS STATES

Success should be clear but restrained.

Do not require full-screen celebrations for routine actions.

Use production feedback appropriate to importance:

- snackbar
- inline confirmation
- state transition
- success panel

Do not add success state that fires before the underlying action actually succeeds.

---

# 30. GLOBAL THEME

FaceTune must support:

```text
LIGHT
DARK
SYSTEM
```

The UI track must preserve global theme authority.

Do not create screen-specific theme engines.

Test at minimum:

- background
- app bar
- surfaces
- cards
- text
- inputs
- buttons
- dividers
- image containers
- loading/error/empty states
- tutorial UI
- history
- My Kit

Dark mode must not be a simple color inversion.

---

# 31. RESPONSIVE LAYOUT

Primary device:

```text
POCO X3 GT
```

But implementation must not hardcode only for that width.

Test representative widths including:

- narrow Android phone around 320 logical px where feasible
- primary POCO-size layout
- wider phone layouts

Rules:

- no horizontal overflow
- no clipped buttons
- no text hidden behind fixed heights
- avoid rigid pixel widths where responsive constraints are appropriate
- use scroll where content legitimately grows
- preserve safe areas
- keyboard-safe forms

---

# 32. ACCESSIBILITY

Every major UI phase must consider:

- larger text scale
- semantic labels
- touch target size
- contrast
- icon + text where meaning would otherwise be ambiguous
- non-color-only state communication
- screen reader semantics where practical
- scroll safety
- reduced reliance on tiny metadata

A polished UI that becomes unusable at larger text scale is not production-ready.

---

# 33. MOTION / ANIMATION

Motion should communicate hierarchy/state, not decorate every transition.

Allowed when justified:

- subtle page transitions
- expansion/collapse
- image crossfade
- loading animation
- button state transitions

Rules:

- no infinite expensive decorative animation
- no animation that triggers provider/network work
- respect platform conventions
- keep durations consistent through motion tokens where practical
- avoid motion that interferes with before/after visual comparison

---

# 34. NAVIGATION PRESENTATION

UI work may improve:

- app bars
- bottom navigation appearance
- tab appearance
- back affordances
- route transition presentation
- screen titles

Do NOT rewrite routing behavior unless the current phase explicitly proves a presentation defect cannot be solved otherwise.

Route destinations and auth guards remain protected.

---

# 35. SCREEN GROUPS

For this track, screens are grouped conceptually as:

## Group A — Entry

- splash / launch presentation if present
- onboarding if present
- login
- registration
- recovery UI if present

## Group B — Creation

- home/start
- selfie capture/import
- validation states
- analysis/loading
- style selection
- recommendation transition

## Group C — Results

- final preview
- before/after
- Makeup Breakdown
- save/share presentation where already supported

## Group D — Library / Kit

- History
- saved looks
- My Makeup Kit
- product presentation
- empty/error states

## Group E — Tutorial

- tutorial overview if present
- step screen
- Guide Key
- HOW TO APPLY
- metadata
- Final Look reference
- redraw confirmation
- image viewer entry

## Group F — Settings / Supporting UI

- appearance settings if present
- account/supporting settings already implemented
- generic app dialogs/sheets

Do not invent new product features just to fill empty visual areas.

---

# 36. COMPONENT REUSE RULE

Before creating a new component:

1. inspect existing shared components
2. inspect current design tokens
3. inspect Material 3 capabilities already used
4. determine whether extending an existing component is safer

Do not build duplicate button/card/input systems in separate feature folders.

Shared components should remain presentation-focused.

Do not move domain logic into the design system.

---

# 37. CLEAN ARCHITECTURE RULE FOR UI

Widgets should render state and send user intent through existing controllers/use cases.

Widgets should not contain:

- AI orchestration
- database queries
- ownership checks
- recommendation logic
- manifest logic
- persistence rules

Keep business logic out of widgets.

---

# 38. PERFORMANCE

UI polish must not create regressions through:

- unnecessary rebuilds
- large unbounded images
- excessive blur/shadow effects
- expensive nested scrolling
- uncontrolled animation controllers
- redundant providers
- repeated network/image fetches on rebuild

Audit:

- const opportunities where useful
- image sizing/caching behavior using existing architecture
- rebuild scope
- list virtualization where large collections exist

Do not perform speculative micro-optimization unrelated to an observed issue.

---

# 39. NO NEW DEPENDENCY BY DEFAULT

Do not install a UI package simply because it is convenient.

Before adding a dependency:

- inspect whether Flutter/Material already supports the requirement
- inspect whether the project already has an equivalent dependency
- evaluate maintenance/security/size impact
- justify why custom/simple native implementation is insufficient

Any added dependency must be listed explicitly in the phase completion report.

---

# 40. GIT SAFETY

Before every phase run:

```powershell
git branch --show-current
git log -1 --oneline
git status --short
git diff
```

Never:

- reset
- clean
- restore unrelated work
- stash automatically
- rebase automatically
- merge automatically
- commit automatically
- push automatically

unless explicitly requested by the user.

Preserve accepted V4 work.

---

# 41. UI BASELINE CAPTURE

Before broad visual changes, capture the current UI baseline.

At minimum identify:

- screen inventory
- existing theme files
- typography strategy
- shared components
- repeated hardcoded styles
- loading/error/empty patterns
- navigation shell
- image containers
- major accessibility issues
- visual inconsistencies
- screens with overflow risk

Use screenshots/device evidence where available.

Do not claim visual defects that were not observed.

---

# 42. VISUAL QA SCALE

Use:

```text
PASS
ACCEPTABLE
FAIL
NOT TESTED
```

Evaluate at minimum:

- hierarchy
- consistency
- typography
- spacing
- visual balance
- theme correctness
- responsive behavior
- accessibility/readability
- loading/error/empty clarity
- image usability
- navigation clarity

Do not fabricate scores or percentages.

Human visual review is required for polish.

---

# 43. DEVICE QA

Primary device:

```text
POCO X3 GT
```

Device evidence is required for phases that materially change user-facing screens.

If device is unavailable:

- do not fabricate pass
- mark `PENDING DEVICE VERIFICATION`
- provide exact manual test steps

Automated widget tests do not prove visual polish.

---

# 44. REGRESSION CONTRACT

Every phase must prove protected behavior remains unchanged.

At minimum verify relevant paths for:

- auth
- selfie
- analysis
- style
- Standard recommendation
- My Makeup Kit
- final preview
- before/after
- dynamic manifest
- Makeup Breakdown
- tutorial
- History/reopen

Also assert no unintended changes to:

```text
FINAL PREVIEW MODEL
TUTORIAL MODEL
TUTORIAL RESOLUTION
TUTORIAL PROMPT
MANIFEST PROMPT
DATABASE
RLS
STORAGE
EDGE FUNCTIONS
```

---

# 45. UI PHASE BOUNDARY RULE

Every phase must have one clearly bounded visual objective.

Do not combine:

```text
DESIGN SYSTEM
+
EVERY SCREEN REDESIGN
+
TUTORIAL REDESIGN
+
NAVIGATION REWRITE
```

into one giant implementation.

One phase at a time.

---

# 46. PRODUCTION UI PHASES

The UI track contains exactly these controlled phases:

## UI-P0 — ACCEPTED BASELINE FREEZE & UI INVENTORY

Read-only/near-read-only audit.

Prove current Git state, accepted V4 presence, screen inventory, design-system state, shared-component state, theme state, responsive risks, and exact UI implementation boundaries.

No broad visual implementation.

## UI-P1 — PRODUCTION DESIGN SYSTEM FOUNDATION

Create/consolidate global UI tokens and reusable primitives.

Focus:

- colors
- typography
- spacing
- radius
- elevation
- motion
- icon policy
- base buttons/inputs/cards/surfaces
- global theme consistency

Do not redesign all feature screens yet.

## UI-P2 — APP SHELL, NAVIGATION & GLOBAL STATES

Polish the app shell and reusable application-wide presentation:

- app bars
- navigation presentation
- global dialogs/sheets
- loading primitives
- error states
- empty states
- success feedback
- common image containers

No domain/routing behavior rewrite.

## UI-P3 — ENTRY & CREATION FLOW POLISH

Polish:

- entry/auth screens
- home/start
- selfie flow presentation
- validation presentation
- analysis/loading
- style selection

Preserve logic completely.

## UI-P4 — RESULTS, HISTORY & MY MAKEUP KIT POLISH

Polish:

- Final Preview
- Before / After
- Makeup Breakdown
- History/saved looks
- My Makeup Kit
- related loading/empty/error states

Preserve all data authority and grouping logic.

## UI-P5 — TUTORIAL PRESENTATION POLISH

Polish only Flutter presentation of the accepted V4 tutorial:

- hierarchy
- Guide Key
- HOW TO APPLY
- product/shade metadata
- Final Look reference
- progress/navigation presentation
- redraw confirmation presentation
- image viewer entry

AI/tutorial/manifest behavior remains frozen.

## UI-P6 — FULL-APP RESPONSIVE, ACCESSIBILITY & THEME QA

Cross-screen remediation limited to defects proven by:

- Light
- Dark
- System
- narrow widths
- larger text
- POCO X3 GT
- accessibility review
- overflow review

No speculative redesign.

## UI-P7 — PRODUCTION UI BASELINE LOCK

Final UI-only end-to-end verification.

No new design features unless minimal remediation of a proven release-blocking UI defect is necessary.

Final decision must be one of:

```text
UI BASELINE ACCEPTED
UI BASELINE ACCEPTED WITH RESTRICTIONS
UI BASELINE REJECTED
```

Then STOP.

---

# 47. GLOBAL COMPLETION CRITERIA

The UI track is complete only when:

- FaceTune has one coherent visual language
- shared design tokens/components are used consistently
- major screens no longer invent arbitrary local styling
- Light/Dark/System behave coherently
- POCO X3 GT passes visual QA
- narrow layout passes
- larger text is usable
- loading/error/empty states are production-ready
- images are presented safely
- navigation presentation is coherent
- tutorial presentation is polished without changing V4 behavior
- Makeup Breakdown data authority is unchanged
- My Makeup Kit authority is unchanged
- all accepted V4 AI locks remain unchanged
- no database/RLS/storage/backend change was required
- regressions are not observed

---

# 48. FINAL ENGINEERING PRINCIPLE

The accepted FaceTune system already knows **what to do**.

This track changes **how it looks and feels while doing it**.

Conceptually:

```text
ACCEPTED WORKING SYSTEM
↓
PRODUCTION DESIGN SYSTEM
↓
CONSISTENT UI COMPONENTS
↓
POLISHED SCREEN FLOWS
↓
RESPONSIVE + ACCESSIBLE QA
↓
PRODUCTION UI BASELINE LOCK
```

Not:

```text
UI POLISH
↓
REWRITE WORKING BACKEND / AI / DOMAIN
```

The final principle is:

> **Make FaceTune visually production-ready while keeping the accepted system boringly stable.**
