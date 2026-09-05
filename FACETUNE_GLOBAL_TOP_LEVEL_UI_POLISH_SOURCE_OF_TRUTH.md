# FaceTune — GLOBAL TOP-LEVEL UI POLISH SOURCE OF TRUTH

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

**Target UI Polish Branch:** `feature/global-ui-polish-v1` — branch existence/base MUST be proven in POLISH-P0 before use; never create/switch/reset automatically without explicit user instruction.  
**UI Polish Base:** MUST be proven from the current accepted working FaceTune baseline after the completed Scan UI, Tutorial UI, and History UI tracks. Never assume `main` contains every accepted change.  

**Accepted Scan UI Baseline:** PROTECTED  
**Accepted Tutorial UI Baseline:** PROTECTED  
**Accepted History UI Baseline:** PROTECTED except the explicitly authorized narrow corrections in this document  
**Accepted Global Bottom Navigation Design:** PROTECTED  
**Accepted V4 Tutorial Quality Baseline:** PROTECTED  

**Canonical Final Preview Renderer — HARD LOCK:** `gemini-3.1-flash-image`  
**Tutorial Guideline Renderer — HARD LOCK:** `gemini-3.1-flash-image`  
**Tutorial Guideline Resolution — HARD LOCK:** `1K`  
**Tutorial Prompt — HARD LOCK:** `tutorial_guideline_v4_7`  
**Manifest Prompt — HARD LOCK:** `tutorial_manifest_v4_1`  

**Recommendation Modes:** `standard` + `my_makeup_kit`  
**UI Track Scope:** presentation-layer polish and shared presentation formatting only  
**UI Design Direction:** Luminous Beauty Intelligence  
**Release Goal:** a coherent, premium, responsive, accessible top-level FaceTune shell with consistent page-header rhythm, consistent Home/History look metadata vocabulary, a cleaner History control surface, and visually integrated bottom navigation without changing accepted system behavior.

---

# 0. PURPOSE

This document is the highest authority for the FaceTune **Global Top-Level UI Polish Track**.

FaceTune already has accepted working Scan, Tutorial, History, Result, recommendation, and My Makeup Kit behavior.

This track is intentionally narrow.

It exists to implement exactly three product edits:

```text
EDIT 1
HISTORY CLEANUP
- remove visible Sort
- force effective default order to Newest first
- preserve date grouping
- fix the unintended black / empty band above bottom navigation
- preserve enough final-item clearance

EDIT 2
HOME RECENT LOOKS METADATA PARITY
- use the same presentation vocabulary as History
- title
- mode
- secondary metadata
- date/time
- shared presentation formatter / presentation model where safe
- preserve separate Standard and My Makeup Kit authorities

EDIT 3
GLOBAL TOP-LEVEL HEADER SPACING
- consistent SafeArea strategy
- consistent top inset
- consistent horizontal gutter
- consistent title/subtitle rhythm
- consistent header-to-content spacing
- Saved
- History
- Profile
- Home companion greeting header
- trailing action alignment
```

The central principle is:

> **POLISH THE TOP-LEVEL EXPERIENCE WITHOUT REOPENING THE SYSTEM.**

A visually attractive implementation that changes AI behavior, data authority, History card semantics, navigation behavior, storage security, tutorial architecture, or recommendation authority is a failure.

---

# 1. DOCUMENT AUTHORITY

Before ANY implementation, read completely in this order when present:

1. `CODEX_MASTER_GUIDE.md`
2. `FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_SOURCE_OF_TRUTH.md`
3. `FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_PHASE_PROMPTS.md`
4. `FACETUNE_V4_TUTORIAL_QUALITY_SOURCE_OF_TRUTH.md`
5. `FACETUNE_V4_TUTORIAL_QUALITY_PHASE_PROMPTS.md`
6. `FACETUNE_UI_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md`
7. `FACETUNE_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md`
8. `FACETUNE_TUTORIAL_UI_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md`
9. `FACETUNE_TUTORIAL_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md`
10. `FACETUNE_HISTORY_UI_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md`
11. `FACETUNE_HISTORY_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md`
12. `FACETUNE_GLOBAL_TOP_LEVEL_UI_POLISH_SOURCE_OF_TRUTH.md`
13. `FACETUNE_GLOBAL_TOP_LEVEL_UI_POLISH_PHASE_PROMPTS.md`
14. accepted completion reports for Scan UI, Tutorial UI, History UI
15. actual current source, tests, theme, routing, shell, and device evidence relevant to the active phase
16. current Git diff

Authority rules:

1. This document governs this narrow polish track.
2. Accepted V4/tutorial authorities govern protected AI/tutorial architecture.
3. Accepted global UI authorities govern the visual system.
4. Accepted History authorities govern History business behavior.
5. `CODEX_MASTER_GUIDE.md` governs general engineering outside narrower authorities.
6. The active phase prompt authorizes only that phase.
7. Completion reports are evidence, not truth.
8. Actual current code beats assumptions.
9. Real-device behavior beats stale screenshots.
10. A phase may never widen its scope silently.
11. UI convenience never authorizes backend/domain/security changes.

If an older UI idea conflicts with this document, this document wins for this track.

---

# 2. SYSTEM ROLE

The coding agent must behave as a disciplined production UI engineering team.

## Architecture / Leadership

- Principal Software Engineer
- Principal Software Architect
- Principal Mobile Architect
- Principal Flutter Architect
- Senior Code Reviewer
- Senior Release Engineer

## Frontend / Flutter

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
- Senior State Restoration Engineer

## UI / Design Systems

- Senior Design Systems Engineer
- Senior Design Systems Developer
- Senior Flutter UI Engineer
- Senior Mobile UI Engineer
- Senior Component Library Engineer
- Senior Responsive Layout Engineer
- Senior Interaction Engineer
- Senior Visual QA Engineer

## Product / UX

- Senior Mobile Product Designer
- Senior UI Designer
- Senior UX Designer
- Senior UI/UX Designer
- Senior Interaction Designer
- Senior Information Architecture Designer
- Senior Beauty-App Product Designer

## Accessibility / Localization

- Senior Accessibility Engineer
- Senior Inclusive Design Engineer
- Senior Semantic UI Engineer
- Senior Localization-Readiness Engineer

## Protection / Regression

- Senior QA Engineer
- Senior Regression Engineer
- Senior Integration Test Engineer
- Senior End-to-End Test Engineer
- Senior Production Debugging Engineer
- Senior Reliability Engineer
- Senior Performance Engineer
- Senior Application Security Engineer
- Senior Privacy Engineer
- Senior Supabase Engineer
- Senior Backend Engineer

## Protected AI / Domain Awareness

- Senior Gemini AI Engineer
- Senior AI Systems Engineer
- Senior My Makeup Kit Engineer

AI/backend/domain roles exist to **protect accepted behavior**, not redesign it.

The agent must:

- inspect first
- challenge stale assumptions
- preserve valid working-tree work
- reuse accepted global components/tokens
- identify the smallest presentation-layer surface
- avoid broad rewrites
- stop if a requested visual change requires protected architecture changes

---

# 3. ABSOLUTE AI / V4 HARD LOCKS

Every phase must preserve exactly:

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

Do NOT modify:

- Gemini model names
- Gemini model configuration
- Gemini prompts
- AI request/response contracts
- AI retries
- AI fallbacks
- AI resolution
- AI call counts
- Final Preview generation
- Tutorial generation
- Dynamic Manifest
- category inclusion/order
- face analysis
- recommendation generation
- Makeup Breakdown authority
- My Makeup Kit recommendation authority

Expected AI diff:

```text
NONE
```

Top-level UI interactions added in this track must create:

```text
EXTRA GEMINI CALLS = 0
```

---

# 4. BACKEND / SECURITY HARD LOCK

Do NOT modify:

- Supabase database schema
- migrations
- RLS
- storage policies
- private bucket behavior
- signed-URL security
- Edge Functions
- auth
- JWT handling
- secrets
- persistence contracts
- repository contracts merely for UI convenience

Expected:

```text
git diff -- supabase/
= NONE
```

If a requested polish requires a protected backend/domain change:

```text
STOP
REPORT
DO NOT IMPLEMENT
```

---

# 5. ACCEPTED FEATURE BASELINES — FREEZE

Do NOT redesign or alter accepted behavior for:

```text
NEW SCAN
LIVE CAMERA
LOCAL LIGHTING / SHARPNESS / STEADINESS
MANUAL SHUTTER
FACE ANALYSIS
STYLE SELECTION
PERSONALIZED PALETTE
FINAL PREVIEW
RESULT
BEFORE / AFTER
MAKEUP BREAKDOWN
TUTORIAL UI
TUTORIAL GENERATION
DYNAMIC MANIFEST
MY MAKEUP KIT ACQUISITION
MY MAKEUP KIT RECOMMENDATION
HISTORY UNIFIED FEED
HISTORY SEARCH
HISTORY TYPE FILTER
HISTORY STATUS FILTER
HISTORY SHARED CARD
HISTORY OVERFLOW ACTIONS
HISTORY DATE GROUPING
HISTORY REOPEN
HISTORY FAVORITE
HISTORY DELETE
PROFILE BUSINESS LOGIC
SAVED LOOKS BUSINESS LOGIC
GLOBAL BOTTOM NAV DESTINATIONS
```

This track changes presentation only where explicitly authorized below.

---

# 6. EDIT 1 — HISTORY REMOVE SORT

The visible History Sort action is no longer part of the desired UX.

Remove from the visible History UI:

```text
Sort
sort icon
sort bottom-sheet affordance
```

Do NOT replace it with another permanent control.

The History control hierarchy remains:

```text
Search
Type
Status
Date grouping
```

---

# 7. HISTORY EFFECTIVE ORDER — NEWEST FIRST

After removing the visible Sort affordance, the user must not be trapped in a stale previously-selected order.

Effective History order must be:

```text
Newest first
```

Rules:

- inspect the current presentation-state implementation first
- if Sort state persists in local/session UI state, normalize the effective visible ordering to Newest first when this new UI is active
- do not rewrite backend ordering contracts
- do not modify database fields
- do not delete domain sort enums merely for cleanliness
- do not widen scope into repository redesign

---

# 8. HISTORY DATE GROUPING — FREEZE

Preserve accepted chronological grouping:

```text
Today
Yesterday
This week
Earlier
```

Do not redesign group labels, timezone architecture, or stored timestamps.

---

# 9. HISTORY CONTROL SURFACE — FREEZE

Preserve:

```text
Search your history

TYPE
All
My Makeup Kit
Recommendations

STATUS
All
Completed
Favorites
```

No broader filter redesign in this track.

---

# 10. BOTTOM NAVIGATION BLACK / EMPTY BAND DEFECT

The unintended black or visually empty strip above the four global bottom-navigation destinations must be removed.

Affected top-level pages must be audited:

```text
Home
Saved
History
Profile
```

Target:

```text
LAST VISIBLE PAGE CONTENT
↓
normal intentional content clearance
↓
GLOBAL BOTTOM NAVIGATION
```

Forbidden result:

```text
LAST CONTENT
↓
large unexplained black / empty band
↓
GLOBAL BOTTOM NAVIGATION
```

---

# 11. BOTTOM NAV GAP — ROOT CAUSE FIRST

Before editing, inspect:

```text
list/view bottom padding
manual Spacer / SizedBox
duplicate SafeArea
Scaffold body padding
bottomNavigationBar integration
Stack / Positioned
nested shell layout
body background vs nav surface
MediaQuery viewPadding
navigation-bar reserved height
scroll-view content padding
shared app-shell constraints
```

Do not assume the cause from screenshots. Fix the actual layout source.

---

# 12. BOTTOM NAV DESIGN — HARD FREEZE

Do NOT redesign:

- tab order
- icons
- labels
- selected state
- selected color
- destinations
- router architecture
- interaction behavior

This track fixes **integration/gap**, not nav design.

---

# 13. FINAL CONTENT CLEARANCE

Removing the black/empty band must NOT cause the last item to be hidden behind the bottom navigation.

Required:

- last scrollable item can become fully visible above bottom nav
- normal intentional bottom clearance remains
- no oversized fake spacer
- no double SafeArea
- no content overlay
- no arbitrary giant `SizedBox`

---

# 14. EDIT 2 — HOME RECENT LOOKS METADATA PARITY

Home `Recent looks` must use the same user-facing metadata vocabulary as History.

The physical card layout may differ:

```text
HOME
= compact portrait/grid card

HISTORY
= horizontal list card
```

The information hierarchy must match.

---

# 15. STANDARD RECENT LOOK METADATA

Target Standard presentation:

```text
Everyday
Recommendation
Plan ready
Sep 4 · 10:03 PM
```

Hierarchy:

```text
TITLE
strongest

MODE
Recommendation
quieter accent metadata

SECONDARY
Plan ready
secondary metadata

DATE / TIME
same formatter/treatment as History
```

---

# 16. MY MAKEUP KIT RECENT LOOK METADATA

When the current authoritative Home Recent Looks data includes a My Makeup Kit record, target:

```text
Old Money
My Makeup Kit
1 owned product
Sep 5 · 2:41 PM
```

Pluralization:

```text
1 owned product
2 owned products
```

Hard rule:

- do not widen the Home datasource solely to make My Kit appear
- do not add new queries
- do not merge repositories
- if current Home Recent Looks is Standard-only, preserve that data scope and report My Kit display as not exercised on Home

---

# 17. SHARED LOOK METADATA PRESENTATION

Prefer one shared presentation-safe formatter/model when current architecture supports it.

Conceptually:

```text
LookMetadataPresentation
├── title
├── modeLabel
├── secondaryMetadata
└── formattedDateTime
```

Then:

```text
HOME RECENT LOOK CARD
→ compact vertical renderer

HISTORY CARD
→ horizontal renderer
```

Hard locks:

```text
STANDARD BUSINESS AUTHORITY
SEPARATE

MY MAKEUP KIT BUSINESS AUTHORITY
SEPARATE

BUSINESS CONTROLLERS
NOT MERGED

REPOSITORIES
NOT MERGED FOR UI CONVENIENCE
```

---

# 18. HOME RECENT LOOK CARD PROPORTION

The compact Home card must give the new metadata enough room.

Allowed:

- adjust image-to-metadata vertical proportion
- increase metadata region height responsively
- use existing spacing tokens
- preserve card width/grid behavior
- preserve image crop/radius
- preserve card tap/navigation

Forbidden shortcuts:

```text
shrink global fonts
truncate "Recommendation" at normal supported width
hide "Plan ready"
hide date/time
compress metadata into unreadable spacing
change image-loading architecture
redesign Home hero
```

---

# 19. HOME RECENT LOOKS BEHAVIOR — FREEZE

Do NOT change:

- Recent Looks data source
- `View all` navigation
- card tap destination
- history/reopen semantics
- image source/signing
- favorite/delete semantics
- Home hero
- Start Scan
- Home controls

---

# 20. EDIT 3 — GLOBAL TOP-LEVEL HEADER SYSTEM

Create or reuse a shared header system that standardizes:

```text
SafeArea strategy
top breathing room
horizontal gutter
title row
title/subtitle gap
header-to-first-content gap
trailing action alignment
responsive behavior
large-text behavior
```

---

# 21. STANDARD TOP-LEVEL PAGE HEADER

Applies to:

```text
Saved
History
Profile
```

Conceptual component:

```text
TopLevelPageHeader
├── title
├── optional subtitle
└── optional trailing action
```

Use existing FaceTune spacing tokens where equivalent. Do not hardcode screenshot-specific values.

---

# 22. SAVED LOOKS HEADER

Target:

```text
Saved Looks
Your personal makeup library, ready when you are.

Makeup Recommendations
```

Improve only:

- top breathing room
- title/subtitle spacing
- subtitle-to-first-section spacing

Saved cards/grid are frozen.

---

# 23. HISTORY HEADER

Target:

```text
History
Revisit every step of your FaceTune journey.

[ Search your history ]
```

Improve only:

- top breathing room
- title/subtitle rhythm
- subtitle-to-search spacing

History filters/cards/date groups are frozen except Sort removal.

---

# 24. PROFILE HEADER

Target:

```text
Profile                              [Settings]

[ profile card ]
```

Requirements:

- settings action belongs to the title row
- align via shared layout, not raw screen coordinates
- no magic `Positioned` offsets
- preserve current settings callback/route
- preserve profile-card business behavior

---

# 25. HOME GREETING HEADER

Home uses a companion pattern:

```text
HomeGreetingHeader
├── greeting
├── supporting text
└── trailing control
```

Current content remains:

```text
Welcome back, <display name>
What beauty mood are you in?
```

Home must share with standard headers:

```text
SafeArea strategy
global top inset
horizontal page gutter
vertical spacing family
trailing-action alignment principles
responsive behavior
accessibility behavior
```

---

# 26. HEADER TYPOGRAPHY — FREEZE FIRST

The current large title size is acceptable.

Do NOT reduce title typography merely because the header is close to the status bar.

Fix spacing first.

---

# 27. GLOBAL UI DESIGN DIRECTION

Use **LUMINOUS BEAUTY INTELLIGENCE**.

Preserve:

- global `ColorScheme`
- global typography
- spacing tokens
- radius tokens
- icon family
- surfaces
- borders
- Light theme
- Dark theme
- System theme
- accessibility behavior

Avoid:

- generic AI SaaS design
- neon
- excessive gradients
- glassmorphism
- glow
- emoji icons
- arbitrary shadows
- pill overload
- screen-specific design systems
- manual status-bar compensation
- magic page-specific padding
- raw screen-coordinate positioning

---

# 28. SAFE AREA RULE

SafeArea must be handled intentionally and only where needed.

Do not:

- apply duplicate top SafeAreas
- manually add status-bar height plus SafeArea
- duplicate bottom SafeArea around an already-safe global nav shell
- use raw `MediaQuery.padding.top` as magic compensation if the shared shell already owns it

Audit ownership first.

---

# 29. RESPONSIVE / ACCESSIBILITY

Verify:

```text
POCO X3 GT
narrow Android
short Android
large text / 2x text where practical
keyboard open on History search
Light
Dark
System
```

Requirements:

- titles remain readable
- trailing actions do not collide
- Home greeting handles longer display names safely
- Recent Looks metadata remains readable
- no bottom-nav overlap
- no top clipping
- no raw overflow
- touch targets remain >=44dp effective where applicable

---

# 30. NO NEW DEPENDENCIES

```text
NEW DEPENDENCIES = NONE
```

If a new package appears necessary:

```text
STOP
REPORT
DO NOT ADD
```

---

# 31. PERFORMANCE RULES

Do NOT add:

- new network calls
- new history fetches
- new signed-URL calls
- AI calls
- expensive work in `build()`
- duplicate metadata computation with side effects
- repeated provider refreshes from harmless rebuilds

Shared presentation formatting must be deterministic and cheap.

---

# 32. TESTING PRINCIPLE

At minimum prove:

```text
History Sort absent
History effective order Newest first
History date grouping preserved
History filters preserved
History shared cards preserved
bottom-nav gap absent
last-item clearance valid
Home metadata parity
Standard metadata authority
My Kit metadata authority where available
Home card navigation unchanged
Saved header
History header
Profile header/settings alignment
Home greeting header
Light/Dark/System
large text
0 new AI calls
0 Supabase diff
```

---

# 33. FORBIDDEN SHORTCUTS

Do NOT:

- redesign History cards
- redesign Saved grid
- redesign Profile card
- redesign Home hero
- redesign bottom nav
- merge Standard/My Kit controllers
- merge repositories
- widen Home feed data scope
- change image-loading architecture
- add new caching
- modify Tutorial
- modify Scan
- modify Result
- modify Palette
- modify My Kit business logic
- modify DB/RLS/storage/Edge Functions
- modify Gemini
- add unrelated cleanup/refactors

---

# 34. DEFINITION OF DONE

This track is accepted only when:

```text
HISTORY VISIBLE SORT                REMOVED
HISTORY EFFECTIVE ORDER             NEWEST FIRST
HISTORY DATE GROUPING               PRESERVED
HISTORY SEARCH                      PRESERVED
HISTORY TYPE FILTER                 PRESERVED
HISTORY STATUS FILTER               PRESERVED
HISTORY SHARED CARD                 PRESERVED
HISTORY OVERFLOW/CHEVRON            PRESERVED

BOTTOM NAV BLACK/EMPTY BAND         ABSENT
LAST ITEM CLEARANCE                 PASS
BOTTOM NAV DESIGN                   UNCHANGED

HOME RECENT LOOK TITLE              PARITY
HOME MODE LABEL                     PARITY
HOME SECONDARY METADATA             PARITY
HOME DATE/TIME                      PARITY
HOME CARD NAVIGATION                UNCHANGED
STANDARD AUTHORITY                  PRESERVED
MY KIT AUTHORITY                    PRESERVED
CONTROLLERS                         NOT MERGED

SAVED HEADER RHYTHM                 PASS
HISTORY HEADER RHYTHM               PASS
PROFILE HEADER RHYTHM               PASS
PROFILE SETTINGS ALIGNMENT          PASS
HOME GREETING TOP INSET             PASS
GLOBAL HORIZONTAL GUTTER            CONSISTENT
SAFEAREA OWNERSHIP                  CLEAN

LIGHT / DARK / SYSTEM               PASS
LARGE TEXT                          PASS
POCO X3 GT                          PASS

FINAL PREVIEW MODEL                 gemini-3.1-flash-image
TUTORIAL MODEL                      gemini-3.1-flash-image
TUTORIAL RESOLUTION                 1K
TUTORIAL PROMPT                     tutorial_guideline_v4_7
MANIFEST PROMPT                     tutorial_manifest_v4_1

EXTRA AI CALLS                      0
SUPABASE DIFF                       NONE
NEW DEPENDENCIES                    NONE
FULL FLUTTER TEST                   PASS
ANDROID DEBUG BUILD                 PASS
```

---

# 35. RELEASE PHILOSOPHY

The user should experience:

```text
ONE FACETUNE SHELL
ONE HEADER RHYTHM
ONE METADATA VOCABULARY
ONE CLEAN BOTTOM NAV INTEGRATION
```

The user should not see evidence that Home, Saved, History, and Profile were polished in different weeks by different pieces of code.
