# FaceTune — HISTORY UI / UX PRODUCTIONIZATION PHASE PROMPTS

**Project Root:** `C:\Users\Kurt\facetune`  
**Target History UI Branch:** `feature/history-ui-productionization-v1` — branch existence/base MUST be proven in HIST-UI-0 before use.  
**Primary Device:** POCO X3 GT  
**Framework:** Flutter / Dart  
**Backend:** Supabase — PROTECTED  
**State Management:** Riverpod  
**Architecture:** Clean Architecture + Repository Pattern + Feature-First Structure  

**Source of Truth:** `FACETUNE_HISTORY_UI_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md`  
**This Phase File:** `FACETUNE_HISTORY_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md`  

**Final Preview Model — HARD LOCK:** `gemini-3.1-flash-image`  
**Tutorial Guideline Model — HARD LOCK:** `gemini-3.1-flash-image`  
**Tutorial Resolution — HARD LOCK:** `1K`  
**Tutorial Prompt — HARD LOCK:** `tutorial_guideline_v4_7`  
**Manifest Prompt — HARD LOCK:** `tutorial_manifest_v4_1`  

**History Principle:** ONE HISTORY EXPERIENCE + MULTIPLE TRUTHFUL DATA AUTHORITIES  
**Accepted Scan UI:** PROTECTED  
**Accepted Tutorial UI:** PROTECTED  
**Accepted V4 Functional Baseline:** PROTECTED  

---

# HOW TO USE THIS FILE

1. Keep this file beside the History Source of Truth.
2. Use OpenAI Codex or Claude Code Pro.
3. Run exactly ONE History phase at a time.
4. Paste only the active phase prompt.
5. Review completion report before proceeding.
6. Never auto-continue.
7. Never treat screenshots alone as behavioral proof.
8. Never treat tests alone as visual proof.
9. Never change database/security as UI convenience.
10. Never change Gemini/model/prompt behavior for History UI.
11. Never merge Standard and My Kit business authorities for component reuse.
12. If a requested enhancement requires protected architecture changes, STOP and report.
13. Production/device evidence beats stale assumptions.
14. Completion reports are evidence, not authority.
15. Do not commit/push/merge/rebase unless explicitly authorized.

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
12. relevant accepted completion reports
13. actual current source/tests/config relevant to THIS phase
14. current Git diff
```

If an authority file is missing, do not invent it. Inspect actual source and report ambiguity.

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
- Senior Flutter UI Engineer
- Senior Mobile UI Engineer
- Senior Component Library Engineer
- Senior Responsive Layout Engineer
- Senior List Rendering / Virtualization Engineer
- Senior State Restoration Engineer
- Senior Image Loading / Caching Engineer
- Senior Mobile Performance Engineer
- Senior Interaction Engineer
- Senior Mobile Product Designer
- Senior UI Designer
- Senior UX Designer
- Senior UI/UX Designer
- Senior Information Architecture Designer
- Senior Search / Filter UX Designer
- Senior Beauty-App Product Designer
- Senior Accessibility Engineer
- Senior Inclusive Design Engineer
- Senior Localization-Readiness Engineer
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
- Senior Reliability Engineer
- Senior Release Engineer
- Senior Gemini AI Engineer
- Senior AI Systems Engineer
- Senior My Makeup Kit Engineer
- Senior Code Reviewer

AI/backend roles protect the baseline. They do not redesign it.

Inspect first. Challenge stale assumptions. Prefer the smallest safe change.

---

# GLOBAL GIT SAFETY FOR EVERY PHASE

Run first:

```powershell
git branch --show-current
git log -1 --oneline
git status --short
git diff --stat
git diff --name-only
git diff
```

Do NOT reset, clean, stash, discard valid work, restore unrelated files, rebase, merge, cherry-pick, commit, or push.

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

Do NOT modify Gemini models/config, prompts, AI retries/fallbacks, AI resolution, AI call counts, Final Preview, tutorial generation, Dynamic Manifest, recommendation generation, face analysis, My Kit immutable snapshot, Standard/My Kit authority separation, DB schema, migrations, RLS, private storage, Edge Functions, auth, JWT, or bottom nav architecture.

Expected:

```text
AI CHANGES = NONE
SUPABASE DIFF = NONE
AI CALLS FROM HISTORY UI = 0
```

---

# GLOBAL HISTORY AUTHORITY LOCK

Visual shell may be shared.

Business authority may not.

```text
STANDARD DATA AUTHORITY       SEPARATE
MY KIT DATA AUTHORITY         SEPARATE
STANDARD → MY KIT FALLBACK    NEVER
MY KIT → STANDARD FALLBACK    NEVER
BUSINESS CONTROLLER MERGE     FORBIDDEN
```

---

# GLOBAL SIGNED-URL / PRIVACY LOCK

Do NOT make private storage public, log signed URLs/image data, casually extend signed URL lifetime, persist sensitive URLs outside policy, bypass RLS, or weaken privacy for caching.

---

# GLOBAL VALIDATION

After implementation phases run as applicable:

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

If POCO X3 GT unavailable:

```text
REAL DEVICE STATUS:
PENDING USER VERIFICATION
```

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
AI CALLS FROM HISTORY:
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
DOMAIN / REPOSITORY CONTRACT CHANGES:
NONE / exact authorized finding
STANDARD AUTHORITY:
PRESERVED / FAIL
MY KIT AUTHORITY:
PRESERVED / FAIL

----------------------------------
UI / UX
----------------------------------
SCREENS / COMPONENTS CHANGED:
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
No Standard/My Kit authority merged.
No bottom-navigation architecture changed.
No commit/push/merge/rebase performed.

STOP.
```

---

# HIST-UI-0 — BASELINE, AUTHORITY & DATA-LOADING AUDIT

Implement only HIST-UI-0, then STOP.

## Objective

Prove the exact current History architecture before redesign. Primarily READ-ONLY.

## Audit

Map:

```text
CURRENT HISTORY PAGE
CURRENT HISTORY ROUTE
STANDARD HISTORY SOURCE
MY KIT HISTORY SOURCE
CURRENT MERGE/SECTION LOGIC
CURRENT SEARCH LOGIC
CURRENT STATUS FILTER LOGIC
CURRENT FAVORITE LOGIC
CURRENT DELETE LOGIC
CURRENT CARD COMPONENTS
CURRENT THUMBNAIL COMPONENTS
CURRENT SIGNED-URL FLOW
CURRENT IMAGE CACHE BEHAVIOR
CURRENT LOADING STATES
CURRENT ERROR STATES
CURRENT EMPTY STATES
CURRENT REOPEN/NAVIGATION
CURRENT BOTTOM NAV
CURRENT SCROLL STATE
CURRENT FILTER STATE
CURRENT PAGINATION SUPPORT
CURRENT PULL-TO-REFRESH SUPPORT
```

Prove whether createdAt, lastViewedAt, title/style, favorite, Completed, pagination, signed URL reuse, image cache, and route restoration actually exist.

Prove current branch/HEAD and safe base for `feature/history-ui-productionization-v1`.

Do NOT create/switch branch automatically.

## Do NOT implement

No feed redesign, filters, cards, skeletons, pagination, cache package, backend, or model changes.

## Validation

```powershell
flutter analyze
git diff -- supabase/
```

No paid AI calls.

## Report additions

```text
STANDARD HISTORY SOURCE:
MY KIT HISTORY SOURCE:
CURRENT HISTORY RECORD IDENTITY:
CURRENT CREATED-AT AUTHORITY:
CURRENT LAST-VIEWED AUTHORITY:
CURRENT FAVORITE AUTHORITY:
CURRENT COMPLETED AUTHORITY:
CURRENT SEARCH SCOPE:
CURRENT PAGINATION SUPPORT:
CURRENT SIGNED-URL STRATEGY:
CURRENT IMAGE CACHE STRATEGY:
CURRENT SCROLL RESTORATION:
CURRENT FILTER STATE LIFETIME:
SAFE BRANCH BASE:
PROTECTED FILES / FUNCTIONS:
```

STOP.

---

# HIST-UI-1 — UNIFIED FEED + SHARED MODE ADAPTERS

Implement only HIST-UI-1, then STOP.

## Objective

Replace permanent My Makeup Kit and Recommendations sections with one shared History feed.

## Requirements

- one scrollable feed
- mixed Standard/My Kit under All
- preserve record type and stable ID
- preserve existing reopen callback
- no cross-mode fallback
- no AI calls
- no repository merge

Presentation may use a UI-only view model containing authoritative existing fields only.

## Date grouping

Default Newest:

```text
Today
Yesterday
This week
Earlier
```

## Do NOT implement yet

Final filters, sort sheet, overflow redesign, skeleton overhaul, pagination/cache behavior.

## Tests

Standard-only, My Kit-only, mixed feed, deterministic tie handling, grouping, metadata isolation, correct card route, 0 AI calls.

STOP.

---

# HIST-UI-2 — FILTER HIERARCHY + SEARCH + SORT

Implement only HIST-UI-2, then STOP.

## Target

```text
[ Search your history ]

TYPE
[ All ] [ My Makeup Kit ] [ Recommendations ]

STATUS
[ All ] [ Completed ] [ Favorites ]      Sort
```

## Rules

Type filters use authoritative type.

Status meanings remain current accepted meanings.

Prove combined filters.

Sort bottom sheet uses only supported options:

```text
Newest first
Oldest first
Style A-Z
Recently viewed
```

Recently viewed is forbidden if no authoritative field exists.

Chronological sorts use date groups.

Style A-Z suppresses chronological headings.

Search placeholder:

```text
Search your history
```

Preserve actual search scope. No AI search or DB FTS.

Changing one control must not unnecessarily reset others.

## Tests

Type, status, intersections, search+filters, newest, oldest, A-Z if supported, unsupported Recently viewed absent, no duplicates, 0 AI calls.

STOP.

---

# HIST-UI-3 — SHARED HISTORY CARD + SAFE ACTIONS

Implement only HIST-UI-3, then STOP.

## Objective

One premium shared card shell for Standard and My Kit.

```text
[ thumbnail ]  STYLE / TITLE               ⋮
               MODE
               SECONDARY METADATA
               DATE / TIME
                                               >
```

Shared card geometry, thumbnail, typography, chevron, overflow, touch behavior.

## Standard

```text
EVERYDAY
Recommendation
Plan ready
Sep 5 · 2:41 PM
```

## My Kit

```text
OLD MONEY
My Makeup Kit
1 owned product
Sep 5 · 2:41 PM
```

Move Delete to overflow:

```text
View
Favorite / Remove favorite
Delete
```

Preserve existing callbacks/confirmations.

Correct singular/plural grammar.

Reduce status badge prominence.

Do not delete underlying metadata.

## Tests

Both modes, equal structure, metadata, grammar, overflow View, favorite, delete confirmation, navigation, semantics, 0 AI calls.

STOP.

---

# HIST-UI-4 — SKELETONS + THUMBNAIL LOADING EXPERIENCE

Implement only HIST-UI-4, then STOP.

## Objective

Replace spinner-heavy/layout-shifting load states with stable skeleton-first UX.

## Initial load

Approximately 4-5 card-shaped skeletons matching real geometry.

No per-card spinner farm.

## Data-first behavior

Once metadata arrives, show real text and keep skeleton only in thumbnail area.

## Image success

Subtle crossfade.

## Image failure

Stable fallback. Card remains usable where record is valid.

## Lifecycle hard lock

No signed-URL generation/fetch initiated from repeated `build()`.

Do not change signing contracts.

## Tests

Initial skeleton, metadata-before-image, success, failure, crossfade, rebuild no duplicate signing/fetch, filter change no stale thumbnail mixing, 0 AI calls.

POCO real-loading QA required.

STOP.

---

# HIST-UI-5 — SESSION STATE + SCROLL RESTORATION + REFRESH

Implement only HIST-UI-5, then STOP.

## Objective

Preserve History context when opening an item and returning.

Where safe, preserve:

- Type
- Status
- Sort
- Search query
- Scroll position

Do not persist to Supabase/settings unless already accepted.

## Pull-to-refresh

Use global refresh if repository supports reload.

No AI calls, no duplicates, keep feed stable on failure.

## Tests

Back restoration, filter/sort/query preservation, refresh success/failure, no duplicate fetch loop, 0 AI calls.

STOP.

---

# HIST-UI-6 — PAGINATION / CACHE OPTIMIZATION GATE

Implement only HIST-UI-6, then STOP.

This phase has a mandatory architecture gate.

## Pagination

If current contracts ALREADY support paging:

- wire existing page contract
- reasonable first batch, typically 10-20 according to current contract
- near-end loading
- 2-3 bottom skeletons
- append without replacing visible data
- deduplicate by authoritative ID
- block concurrent duplicate page loads
- end-of-list handling
- inline retry on next-page error

If paging requires schema/RPC/migration/repository-contract rewrite/Edge Function/RLS:

```text
DO NOT IMPLEMENT
MARK DEFERRED
REPORT
```

## Cache

If existing stack safely supports cache reuse, use it.

If improvement requires new package, persistent signed URLs, public bucket, or security change:

```text
DO NOT IMPLEMENT
MARK DEFERRED
```

## Tests

No duplicate next-page request, no N+1 introduced, no AI calls, no signing in build, no list replacement, no image cross-contamination, expired URL keeps accepted recovery behavior.

STOP.

---

# HIST-UI-7 — EMPTY / ERROR / RESPONSIVE / ACCESSIBILITY POLISH

Implement only HIST-UI-7, then STOP.

## Empty states

```text
No history yet
Looks you create will appear here.
```

```text
No My Makeup Kit history yet
Looks created with products from your kit will appear here.
```

```text
No favorites yet
Favorite a look to keep it easy to find.
```

```text
No matches found
Try another search or clear your filters.
```

## Error states

Initial error with valid Retry.
Pagination error inline, preserving loaded content.
Image error uses stable thumbnail fallback.

## Responsive QA

POCO X3 GT, narrow Android, short Android, 2x text, keyboard open, long titles/filter labels.

## Accessibility

Search semantics, selected filters, sort, cards, overflow, destructive delete, favorites, touch targets, skeleton semantics, focus order.

## Theme

Light, Dark, System Light, System Dark.

STOP.

---

# HIST-UI-8 — FINAL PROTECTED-DIFF AUDIT + RELEASE ACCEPTANCE

Implement only HIST-UI-8, then STOP.

Primarily audit/validation. No redesign except smallest proven History regression fix.

## Functional matrix

Verify both Standard and My Kit:

```text
History open
Initial loading
Mixed All feed
Type filter
Status filter
Search
Sort
Date grouping
Card open
Favorite
Delete
Back restoration
Image loading
Image failure
Refresh
Pagination if implemented
Empty states
Error states
Bottom navigation
```

## Zero-AI proof

History interactions produce 0 Gemini calls.

## Protected baseline audit

Confirm unchanged:

- Final Preview `gemini-3.1-flash-image`
- Tutorial `gemini-3.1-flash-image`
- `1K`
- `tutorial_guideline_v4_7`
- `tutorial_manifest_v4_1`
- Dynamic Manifest
- recommendation contracts
- My Kit snapshot authority
- Scan UI
- camera validation
- Tutorial UI
- Result
- Supabase schema/RLS/storage/Edge Functions
- auth
- bottom navigation

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

## POCO X3 GT acceptance

1. Open History.
2. Observe initial skeleton.
3. Confirm no spinner in every card.
4. Confirm mixed feed.
5. Confirm date grouping.
6. Filter My Makeup Kit.
7. Filter Recommendations.
8. Combine Favorites.
9. Search.
10. Sort newest.
11. Sort oldest.
12. Style A-Z if supported.
13. Confirm unsupported Recently viewed absent.
14. Open overflow.
15. Confirm View.
16. Confirm Favorite/Remove favorite.
17. Confirm Delete is not permanently exposed.
18. Cancel delete.
19. Open item.
20. Back.
21. Confirm state/scroll restored.
22. Observe thumbnail reuse/loading.
23. Pull-to-refresh if implemented.
24. Scroll to pagination boundary if implemented.
25. Confirm bottom skeleton pagination.
26. Test large text.
27. Test Light/Dark/System.
28. Confirm bottom nav unchanged.

## Final release status

```text
HISTORY UI TRACK:
ACCEPTED / PARTIAL / REJECTED

DEFERRED NON-UI ITEMS:
exact list

PROTECTED BASELINE:
PASS / FAIL

REAL DEVICE:
PASS / FAIL / PENDING USER
```

STOP.

No next track.
No auto-cleanup.
No opportunistic refactor.
