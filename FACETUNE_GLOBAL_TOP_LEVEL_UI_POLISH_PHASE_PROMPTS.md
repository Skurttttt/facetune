# FaceTune — GLOBAL TOP-LEVEL UI POLISH PHASE PROMPTS

**Project Root:** `C:\Users\Kurt\facetune`  
**Target UI Polish Branch:** `feature/global-ui-polish-v1` — existence/base MUST be proven in POLISH-P0; never create/switch/reset automatically without explicit user instruction.  
**Primary Device:** POCO X3 GT  
**Framework:** Flutter / Dart  
**Backend:** Supabase — PROTECTED  
**State Management:** Riverpod  
**Architecture:** Clean Architecture + Repository Pattern + Feature-First Structure  

**Source of Truth:** `FACETUNE_GLOBAL_TOP_LEVEL_UI_POLISH_SOURCE_OF_TRUTH.md`  
**This Phase File:** `FACETUNE_GLOBAL_TOP_LEVEL_UI_POLISH_PHASE_PROMPTS.md`  

**Final Preview Model — HARD LOCK:** `gemini-3.1-flash-image`  
**Tutorial Guideline Model — HARD LOCK:** `gemini-3.1-flash-image`  
**Tutorial Resolution — HARD LOCK:** `1K`  
**Tutorial Prompt — HARD LOCK:** `tutorial_guideline_v4_7`  
**Manifest Prompt — HARD LOCK:** `tutorial_manifest_v4_1`  

**Accepted Scan UI:** PROTECTED  
**Accepted Tutorial UI:** PROTECTED  
**Accepted History UI:** PROTECTED except explicit narrow corrections  
**Global Bottom Navigation Design:** PROTECTED  
**Design Direction:** Luminous Beauty Intelligence  

---

# HOW TO USE THIS FILE

1. Keep this file beside `FACETUNE_GLOBAL_TOP_LEVEL_UI_POLISH_SOURCE_OF_TRUTH.md`.
2. Use OpenAI Codex or Claude Code Pro.
3. Run exactly ONE phase at a time.
4. Paste only the active phase.
5. Review the completion report before the next phase.
6. Never auto-continue.
7. Never treat screenshots alone as behavioral proof.
8. Never treat tests alone as visual proof.
9. Never change backend/domain/security for UI convenience.
10. Never change Gemini/model/prompt behavior for this track.
11. Never merge Standard and My Kit business authorities for presentation reuse.
12. If a UI request requires protected architecture changes, STOP and report.
13. Do not commit/push/merge/rebase unless explicitly instructed.

---

# MANDATORY READ ORDER FOR EVERY PHASE

Read completely, in order, when present:

```text
1. CODEX_MASTER_GUIDE.md
2. FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_SOURCE_OF_TRUTH.md
3. FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_PHASE_PROMPTS.md
4. FACETUNE_V4_TUTORIAL_QUALITY_SOURCE_OF_TRUTH.md
5. FACETUNE_V4_TUTORIAL_QUALITY_PHASE_PROMPTS.md
6. FACETUNE_UI_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md
7. FACETUNE_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md
8. FACETUNE_TUTORIAL_UI_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md
9. FACETUNE_TUTORIAL_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md
10. FACETUNE_HISTORY_UI_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md
11. FACETUNE_HISTORY_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md
12. FACETUNE_GLOBAL_TOP_LEVEL_UI_POLISH_SOURCE_OF_TRUTH.md
13. FACETUNE_GLOBAL_TOP_LEVEL_UI_POLISH_PHASE_PROMPTS.md
14. accepted Scan/Tutorial/History completion reports
15. actual current source/tests/theme/routing relevant to THIS phase
16. current Git diff
```

If an authority file is missing, do not invent it.

Inspect actual source and report ambiguity.

---

# MANDATORY SYSTEM ROLE FOR EVERY PHASE

Act simultaneously as relevant:

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
- Senior Riverpod Engineer
- Senior Mobile Application Engineer
- Senior Mobile Application Developer
- Senior Design Systems Engineer
- Senior Design Systems Developer
- Senior Flutter UI Engineer
- Senior Mobile UI Engineer
- Senior Component Library Engineer
- Senior Responsive Layout Engineer
- Senior State Restoration Engineer
- Senior Interaction Engineer
- Senior Mobile Product Designer
- Senior UI Designer
- Senior UX Designer
- Senior UI/UX Designer
- Senior Information Architecture Designer
- Senior Beauty-App Product Designer
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

AI/backend roles protect accepted behavior. They do not redesign it.

Inspect first.
Challenge stale assumptions.
Prefer the smallest safe presentation-layer change.

---

# GLOBAL GIT SAFETY

Before every phase:

```powershell
git branch --show-current
git log -1 --oneline
git status --short
git diff --stat
git diff --name-only
git diff
```

Do NOT:

- reset
- reset --hard
- clean
- stash
- discard valid work
- restore unrelated files
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

Preserve exactly:

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

- Gemini
- AI prompts
- AI retries/fallbacks
- AI call counts
- Final Preview
- Tutorial generation
- Dynamic Manifest
- face analysis
- recommendation generation
- My Kit authority
- DB schema
- migrations
- RLS
- private storage
- Edge Functions
- auth
- bottom-navigation destinations
- accepted Scan UI
- accepted Tutorial UI

Expected:

```text
EXTRA AI CALLS = 0
SUPABASE DIFF = NONE
NEW DEPENDENCIES = NONE
```

---

# GLOBAL STANDARD / MY KIT AUTHORITY LOCK

```text
STANDARD BUSINESS AUTHORITY       SEPARATE
MY MAKEUP KIT BUSINESS AUTHORITY  SEPARATE
STANDARD → MY KIT FALLBACK        NEVER
MY KIT → STANDARD FALLBACK        NEVER
CONTROLLERS                       NOT MERGED
REPOSITORIES                      NOT MERGED FOR UI CONVENIENCE
```

Shared presentation formatting is allowed.
Shared business authority is not.

---

# GLOBAL UI LOCK

Use accepted:

```text
Luminous Beauty Intelligence
ColorScheme
typography tokens
spacing tokens
radius tokens
icon family
surface system
Light / Dark / System
accessibility
```

Avoid:

```text
magic per-screen padding
manual status-bar compensation
raw screen-coordinate positioning
new typography sizes
new colors
new icon package
emoji
gradient redesign
glow
glassmorphism
arbitrary spacers
unrelated component rewrites
```

---

# GLOBAL VALIDATION

After each implementation phase, run as applicable:

```powershell
dart format <changed Dart files>
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/development.json
git diff -- supabase/
git status --short
git diff --stat
git diff --name-only
```

If the physical POCO X3 GT is unavailable:

```text
REAL DEVICE:
PENDING USER VERIFICATION
```

Do not fabricate visual success.

---

# GLOBAL COMPLETION REPORT

Every phase must end with:

```text
PHASE:
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
AUTHORIZED SCOPE:
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

EXTRA AI CALLS:
0 / FAIL

DATABASE CHANGES:
NONE

RLS CHANGES:
NONE

STORAGE CHANGES:
NONE

EDGE FUNCTION CHANGES:
NONE

AUTH CHANGES:
NONE

STANDARD AUTHORITY:
PRESERVED / FAIL

MY KIT AUTHORITY:
PRESERVED / FAIL

BOTTOM NAV DESTINATIONS:
UNCHANGED / FAIL

----------------------------------
UI / UX
----------------------------------
SCREENS / COMPONENTS CHANGED:
SHARED COMPONENTS CREATED / MODIFIED:
DESIGN TOKENS CHANGED:
NONE / exact authorized change
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
VALIDATION
----------------------------------
DART FORMAT:
FLUTTER ANALYZE:
TARGETED TESTS:
FULL FLUTTER TEST:
ANDROID DEBUG BUILD:
BACKEND DIFF:
NONE / exact issue
REAL DEVICE:
PASS / FAIL / PENDING USER

----------------------------------
KNOWN LIMITATIONS
----------------------------------

----------------------------------
PRE-EXISTING ISSUES
----------------------------------

----------------------------------
ASSUMPTIONS NOT PROVEN
----------------------------------

----------------------------------
MANUAL ACTION REQUIRED
----------------------------------

----------------------------------
NEXT
----------------------------------
NEXT RECOMMENDED PHASE:
Do not implement automatically.

STOP CONFIRMATION:
No later phase implemented.
No valid working-tree work discarded.
No Gemini model changed.
No AI prompt changed.
No Supabase schema/RLS/storage/Edge Function changed.
No Standard/My Kit business authority merged.
No bottom-navigation destination changed.
No commit/push/merge/rebase performed.

STOP.
```

---

# POLISH-P0 — ACCEPTED BASELINE + ROOT-CAUSE AUDIT

Implement only POLISH-P0.

Then STOP.

## Objective

Prove the exact current accepted baseline and map the narrow implementation surfaces for all three edits.

This phase is primarily READ-ONLY.

## Before coding

Run the global Git safety commands.

Audit:

```text
CURRENT BRANCH / HEAD
CURRENT TOP-LEVEL APP SHELL
GLOBAL BOTTOM NAV IMPLEMENTATION
HOME PAGE
HOME RECENT LOOK CARDS
SAVED PAGE HEADER
HISTORY PAGE HEADER
HISTORY SORT STATE
HISTORY EFFECTIVE ORDER
HISTORY DATE GROUPING
HISTORY BOTTOM CLEARANCE
PROFILE PAGE HEADER
PROFILE SETTINGS ACTION LAYOUT
SAFEAREA OWNERSHIP
GLOBAL HORIZONTAL GUTTER
GLOBAL SPACING TOKENS
GLOBAL TYPOGRAPHY TOKENS
STANDARD HISTORY/HOME METADATA SOURCE
MY KIT HISTORY/HOME METADATA SOURCE
DATE/TIME FORMATTER
CURRENT TEST COVERAGE
```

Root-cause audit the black/empty strip across:

```text
Home
Saved
History
Profile
```

Inspect:

```text
bottom padding
SafeArea
Spacer/SizedBox
Stack/Positioned
Scaffold.bottomNavigationBar
shared shell
body/nav surface
MediaQuery padding
list padding
```

Determine whether the defect is:

```text
GLOBAL SHELL DEFECT
PAGE-SPECIFIC DEFECT
INTENTIONAL CONTENT CLEARANCE
MIXED
```

## Branch

Prove the safe accepted base after completed Scan/Tutorial/History tracks.

Do NOT create/switch branch automatically.

## Do NOT implement

- Sort removal
- nav-gap fix
- metadata changes
- header changes
- broad refactors

## Validation

```powershell
flutter analyze
git diff -- supabase/
```

No AI generation.

## Mandatory report additions

```text
SAFE ACCEPTED BASE:
TARGET BRANCH STATUS:
BOTTOM NAV IMPLEMENTATION:
BLACK/EMPTY BAND ROOT CAUSE:
AFFECTED TOP-LEVEL PAGES:
SAFEAREA OWNERSHIP:
HISTORY SORT PRESENTATION OWNER:
HISTORY EFFECTIVE ORDER OWNER:
HISTORY STALE SORT RISK:
HOME RECENT LOOK DATA SOURCE:
HOME MY KIT SUPPORT:
SHARED DATE FORMATTER:
SHARED METADATA FORMATTER ALREADY EXISTS:
SAVED HEADER IMPLEMENTATION:
HISTORY HEADER IMPLEMENTATION:
PROFILE HEADER IMPLEMENTATION:
HOME GREETING IMPLEMENTATION:
GLOBAL SPACING TOKENS:
PROTECTED FILES:
```

STOP.

---

# POLISH-P1 — HISTORY SORT REMOVAL + BOTTOM NAV INTEGRATION FIX

Implement only POLISH-P1.

Then STOP.

## Objective

Two narrow corrections:

```text
A. Remove visible History Sort.
B. Remove unintended black/empty band above global bottom navigation.
```

Nothing else.

## History Sort

Remove visible:

```text
Sort
sort icon
sort bottom-sheet trigger
```

Do not add replacement.

Preserve:

```text
Search
Type
Status
date grouping
unified feed
shared card
overflow
chevron
```

Effective visible order must be:

```text
Newest first
```

If prior presentation state can leave `Oldest` / `A-Z` active after the control disappears, normalize the presentation state to `Newest first` using the smallest UI/presentation-state change.

Do NOT modify backend ordering contracts.

## Bottom nav gap

Fix the proven POLISH-P0 root cause.

Expected final composition:

```text
page content
intentional normal clearance
bottom nav
```

No unexplained black/empty band.

Preserve enough clearance for final content.

Do NOT redesign global bottom nav.

## Global pages

If POLISH-P0 proves the root cause is shared shell, fix it once in the shared shell and validate:

```text
Home
Saved
History
Profile
```

If page-specific, touch only proven affected pages.

## Tests

Prove:

```text
Sort text absent
Sort trigger absent
History newest-first deterministic
date grouping unchanged
filters unchanged
shared cards unchanged
last item clears nav
no oversized bottom spacer
nav tabs/order/destinations unchanged
0 AI calls
```

## POCO QA

Verify all four tabs for black/empty band.

STOP.

---

# POLISH-P2 — HOME RECENT LOOKS METADATA PARITY

Implement only POLISH-P2.

Then STOP.

## Objective

Make Home Recent Looks use the same user-facing metadata vocabulary as History without changing the Home feed definition.

## Standard target

```text
Everyday
Recommendation
Plan ready
Sep 4 · 10:03 PM
```

## My Kit target when authoritative Home data already includes My Kit

```text
Old Money
My Makeup Kit
1 owned product
Sep 5 · 2:41 PM
```

## Shared presentation

Prefer one presentation-safe formatter/model if architecture supports it:

```text
LookMetadataPresentation
title
modeLabel
secondaryMetadata
formattedDateTime
```

Home and History may render different physical card layouts.

Do NOT force History card widget into Home.

Do NOT merge business controllers/repositories.

Do NOT widen Home datasource.

## Home card proportion

Give metadata enough vertical room.

Allowed:

```text
adjust image-to-footer proportion
adjust metadata region height
use existing spacing tokens
```

Forbidden:

```text
shrink global fonts
truncate normal labels
hide Plan ready
hide date/time
redesign image loading
redesign Home hero
```

## Preserve

```text
View all
card tap
Recent Looks source
image source
Start Scan
Home hero
Home control button
```

## Tests

Standard metadata parity.

My Kit parity only if current Home data supports My Kit.

Correct singular/plural.

Same date formatter as History.

Card tap unchanged.

No new fetch.

No extra signed-URL call from metadata.

0 AI calls.

STOP.

---

# POLISH-P3 — GLOBAL TOP-LEVEL HEADER SYSTEM

Implement only POLISH-P3.

Then STOP.

## Objective

Create/reuse canonical top-level header rhythm for:

```text
Saved
History
Profile
Home
```

## Standard component

Prefer:

```text
TopLevelPageHeader
title
optional subtitle
optional trailing action
```

for:

```text
Saved
History
Profile
```

Do not force a new abstraction if an accepted shared component already exists.

## Home companion

Prefer:

```text
HomeGreetingHeader
greeting
supporting text
trailing control
```

Home shares SafeArea/top inset/gutter/spacing family with standard headers, but keeps dashboard greeting hierarchy.

## Spacing

Use existing global tokens.

Conceptual target only:

```text
SafeArea
top breathing room
title row
small title/subtitle gap
subtitle
section gap
first major content
```

Do not hardcode screenshot-specific values.

## Saved

Improve only:

```text
top inset
title/subtitle rhythm
subtitle → first section gap
```

Saved cards/grid are frozen.

## History

Improve only:

```text
top inset
title/subtitle rhythm
subtitle → Search gap
```

History filters/cards are frozen.

## Profile

Place Settings action in title row using shared layout.

Preserve callback/route.

Profile card/library are frozen.

## Home

Use same top inset/gutter.

Preserve:

```text
Welcome back, <display name>
What beauty mood are you in?
trailing control
```

Home hero is frozen.

## Typography

Do NOT reduce page-title size unless source inspection proves current global typography token itself is inconsistent with accepted design authority.

Spacing is the target.

## Tests

```text
SafeArea ownership
no duplicate top inset
Saved header
History header
Profile settings alignment
Home greeting alignment
long display name
2x text
narrow width
Light/Dark/System
0 AI calls
```

STOP.

---

# POLISH-P4 — CROSS-SCREEN RESPONSIVE / ACCESSIBILITY / REGRESSION QA

Implement only POLISH-P4.

Then STOP.

Primarily validation and the smallest proven presentation corrections.

Do not redesign.

## Matrix

Validate:

```text
HOME
- top inset
- greeting/trailing control
- hero unchanged
- Recent Looks metadata
- View all
- bottom nav integration

SAVED
- top inset
- subtitle rhythm
- grid unchanged
- bottom nav integration

HISTORY
- top inset
- Search
- Type
- Status
- Sort absent
- newest first
- date groups
- cards unchanged
- bottom nav integration

PROFILE
- top inset
- Settings aligned
- profile card unchanged
- library unchanged
- bottom nav integration
```

## Devices / modes

```text
POCO X3 GT
narrow Android
short Android
2x text
Light
Dark
System Light
System Dark
keyboard open on History search
```

## Accessibility

Verify:

- semantic titles
- trailing-action semantics
- no clipped labels
- >=44dp effective action targets
- logical focus order
- no color-only meaning
- bottom nav reachable
- final list/grid content fully reachable

## No scope creep

Do NOT change business logic.

STOP.

---

# POLISH-P5 — FINAL PROTECTED-DIFF AUDIT + RELEASE FREEZE

Implement only POLISH-P5.

Then STOP.

This phase is primarily audit/validation.

No redesign except the smallest proven regression fix.

## Protected system audit

Confirm unchanged:

```text
Final Preview model = gemini-3.1-flash-image
Tutorial model = gemini-3.1-flash-image
Tutorial resolution = 1K
Tutorial prompt = tutorial_guideline_v4_7
Manifest prompt = tutorial_manifest_v4_1
Dynamic Manifest
Scan UI
Camera validation
Palette
Result
Tutorial UI
History shared-card behavior
History actions
My Kit snapshot authority
Supabase schema/RLS/storage/Edge Functions
Auth
Bottom-nav destinations
```

## Functional acceptance

```text
History Sort removed
Newest-first effective
Date groups preserved
Bottom-nav black/empty band absent
Final content clearance correct

Home metadata parity
Home navigation unchanged
No new Home datasource

Saved header rhythm
History header rhythm
Profile header rhythm/settings alignment
Home greeting top inset
```

## Required validation

```powershell
dart format <changed Dart files>
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/development.json
git diff -- supabase/
git status --short
git diff --stat
git diff --name-only
```

## Final POCO X3 GT acceptance

1. Open Home.
2. Confirm breathing room below status bar.
3. Confirm Recent Looks metadata parity.
4. Confirm hero unchanged.
5. Confirm no black/empty band above nav.
6. Open Saved.
7. Confirm header rhythm.
8. Confirm grid unchanged.
9. Confirm no black/empty band.
10. Open History.
11. Confirm header rhythm.
12. Confirm Sort absent.
13. Confirm newest-first grouping.
14. Confirm Type/Status/Search unchanged.
15. Confirm cards/overflow/chevron unchanged.
16. Scroll to final item.
17. Confirm final item fully clears nav without oversized spacer.
18. Open Profile.
19. Confirm header breathing room.
20. Confirm Settings aligns with title row.
21. Confirm profile content unchanged.
22. Confirm no black/empty band.
23. Test large text.
24. Test Light/Dark/System.

## Final status

```text
GLOBAL TOP-LEVEL UI POLISH TRACK:
ACCEPTED / PARTIAL / REJECTED

PROTECTED BASELINE:
PASS / FAIL

REAL DEVICE:
PASS / FAIL / PENDING USER

DEFERRED ITEMS:
exact list
```

STOP.

No next phase.
No opportunistic cleanup.
No commit/push/merge/rebase unless separately instructed.
