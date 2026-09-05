# FaceTune — HISTORY UI / UX PRODUCTIONIZATION SOURCE OF TRUTH

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

**History UI Branch (target):** `feature/history-ui-productionization-v1`  
**History UI Base:** MUST be proven from the current accepted working FaceTune baseline in HIST-UI-0; never assume `main` contains every accepted Scan, Tutorial, or UI change.  
**History UI Track Scope:** History presentation, presentation-state, loading UX, filtering/sorting presentation, responsive/accessibility productionization, and only those data-loading optimizations already supported by accepted repository/domain contracts.  

**Canonical Final Preview Renderer — HARD LOCK:** `gemini-3.1-flash-image`  
**Tutorial Guideline Renderer — HARD LOCK:** `gemini-3.1-flash-image`  
**Tutorial Guideline Resolution — HARD LOCK:** `1K`  
**Tutorial Prompt — HARD LOCK:** `tutorial_guideline_v4_7`  
**Manifest Prompt — HARD LOCK:** `tutorial_manifest_v4_1`  

**Recommendation Modes:** `standard` + `my_makeup_kit`  
**History Design Direction:** Luminous Beauty Intelligence  
**History Product Principle:** ONE HISTORY EXPERIENCE + MULTIPLE TRUTHFUL DATA AUTHORITIES  
**Release Goal:** A fast, coherent, premium, searchable, filterable, responsive, accessible History experience with uniform cards, predictable navigation, excellent loading states, and zero regressions to the accepted FaceTune AI/business/security baseline.

---

# 0. PURPOSE

This document is the highest authority for the FaceTune **History UI / UX Productionization Track**.

The current History screen is functional, but visually heavy because it combines search, status chips, separate mode sections, different card structures, per-image loading behavior, exposed delete icons, and inconsistent metadata density.

This track converts History into a single production-ready chronological experience without merging or weakening the authorities beneath it.

The central principles are:

> **CHANGE THE HISTORY PRESENTATION, NOT THE FACETUNE SYSTEM.**

> **ONE HISTORY EXPERIENCE, MULTIPLE TRUTHFUL DATA AUTHORITIES.**

The History UI may improve:

```text
HISTORY INFORMATION ARCHITECTURE
UNIFIED FEED PRESENTATION
TYPE FILTERING
STATUS FILTERING
SORT PRESENTATION
DATE GROUPING
SEARCH PRESENTATION
CARD UNIFORMITY
THUMBNAIL PRESENTATION
SKELETON LOADING
IMAGE LOADING
EMPTY STATES
ERROR STATES
PULL-TO-REFRESH PRESENTATION
SCROLL POSITION PRESERVATION
FILTER STATE PRESERVATION
RESPONSIVE LAYOUT
ACCESSIBILITY
LIGHT / DARK / SYSTEM CONSISTENCY
PERCEIVED PERFORMANCE
LIST RENDERING EFFICIENCY
```

The History track must preserve:

```text
AUTHENTICATION
SELFIE FLOW
FACE ANALYSIS
STYLE SELECTION
STANDARD RECOMMENDATION AUTHORITY
MY MAKEUP KIT AUTHORITY
FINAL PREVIEW GENERATION
CANONICAL FINAL PREVIEW
DYNAMIC MANIFEST
MAKEUP BREAKDOWN
STEP-BY-STEP TUTORIAL
HISTORY RECORD AUTHORITY
FAVORITE BUSINESS RULES
DELETE BUSINESS RULES
HISTORY REOPEN BEHAVIOR
SIGNED-URL SECURITY
PRIVATE STORAGE
SUPABASE DATABASE SCHEMA
RLS
EDGE FUNCTIONS
AI MODELS
AI PROMPTS
AI RETRIES / FALLBACKS
AI CALL COUNTS
```

A beautiful History redesign that changes data authority, security, persistence, AI behavior, or reopen semantics is a failure.

---

# 1. DOCUMENT AUTHORITY

Before ANY History UI implementation, read completely in this order when present:

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
12. relevant accepted completion reports
13. actual current History source
14. actual Standard history source/controller/repository path
15. actual My Makeup Kit history source/controller/repository path
16. current favorites behavior
17. current delete behavior
18. current signed-URL/image-loading implementation
19. current search/filter behavior
20. current bottom navigation
21. current global theme/design tokens/components
22. relevant tests
23. current Git diff
24. real-device evidence

Authority order:

1. This History UI Source of Truth governs this track.
2. V4/tutorial authorities continue to govern protected AI/tutorial behavior.
3. The accepted global UI Source of Truth governs the visual system.
4. `CODEX_MASTER_GUIDE.md` governs general engineering outside narrower documents.
5. The active History phase prompt authorizes only that phase.
6. Completion reports are evidence, not truth.
7. Actual current code beats assumptions.
8. Real-device behavior beats stale screenshots.
9. A phase may never silently widen scope.
10. UI convenience never authorizes database/security/domain changes.

---

# 2. SYSTEM ROLE

The coding agent must behave as a disciplined production engineering team.

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
- Senior List Rendering / Virtualization Engineer
- Senior State Restoration Engineer

## UI Engineering / Design Systems

- Senior Design Systems Engineer
- Senior Design Systems Developer
- Senior Flutter UI Engineer
- Senior Mobile UI Engineer
- Senior Component Library Engineer
- Senior Responsive Layout Engineer
- Senior Interaction Engineer
- Senior Motion Engineer
- Senior Visual QA Engineer

## Product / UX

- Senior Mobile Product Designer
- Senior UI Designer
- Senior UX Designer
- Senior UI/UX Designer
- Senior Interaction Designer
- Senior Visual Designer
- Senior Information Architecture Designer
- Senior Search / Filter UX Designer
- Senior Beauty-App Product Designer

## Loading / Performance / Reliability

- Senior Mobile Performance Engineer
- Senior Image Loading / Caching Engineer
- Senior Reliability Engineer
- Senior Production Debugging Engineer

## Accessibility / Localization

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

## Protected AI Awareness

- Senior Gemini AI Engineer
- Senior AI Systems Engineer
- Senior My Makeup Kit Engineer

AI/backend roles exist to protect accepted behavior, not redesign it during History UI work.

The agent must inspect first, challenge stale assumptions, reuse working code, preserve truthful mode authority, avoid broad rewrites, and STOP when a desired History enhancement requires a protected subsystem change.

---

# 3. ACCEPTED BASELINE FREEZE

The following accepted areas are outside this track:

```text
NEW SCAN
LIVE CAMERA
LOCAL LIGHTING / SHARPNESS / STEADINESS
MANUAL SHUTTER
FACE ANALYSIS
STYLE SELECTION
PERSONALIZED PALETTE
RESULT
BEFORE / AFTER
MAKEUP BREAKDOWN
TUTORIAL UI
TUTORIAL GENERATION
MY MAKEUP KIT ACQUISITION
MY MAKEUP KIT RECOMMENDATION AUTHORITY
PROFILE
GLOBAL BOTTOM NAVIGATION
```

History may navigate into accepted reopen/result flows, but it may not redesign those destinations.

---

# 4. ABSOLUTE AI / V4 HARD LOCKS

Every History phase must preserve:

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

Do NOT modify Gemini model names/config, prompts, retries/fallbacks, AI resolution, AI call counts, final-preview generation, tutorial generation, manifest generation/category order, recommendation generation, or face analysis.

History must generate:

```text
AI CALLS ON OPEN = 0
AI CALLS ON SEARCH = 0
AI CALLS ON FILTER = 0
AI CALLS ON SORT = 0
AI CALLS ON SCROLL = 0
AI CALLS ON PULL-TO-REFRESH = 0
AI CALLS ON FAVORITE = 0
AI CALLS ON DELETE = 0
```

Reopening existing History content must preserve current accepted reuse behavior. History is retrieval, not regeneration.

---

# 5. BACKEND / DATABASE / SECURITY HARD LOCKS

Do NOT change:

- Supabase schema
- migrations
- RLS
- storage policies
- bucket privacy
- auth
- JWT handling
- Edge Functions
- AI secrets
- repository/domain contracts merely for visual convenience
- persistence semantics
- immutable My Kit snapshots

Expected `supabase/` diff:

```text
NONE
```

If a desired feature requires a protected backend/domain change:

```text
STOP
REPORT
DO NOT IMPLEMENT
```

---

# 6. SIGNED URL / IMAGE SECURITY HARD LOCK

History thumbnails may use existing private-storage signed URLs only through the accepted current mechanism.

Do NOT:

- make private buckets public
- extend URL lifetime casually
- log signed URLs
- persist sensitive signed URLs beyond existing policy
- log image bytes/base64
- bypass RLS
- add public mirrors
- change signing authority for perceived performance

Caching must remain compatible with signed-URL expiry/security.

---

# 7. CORE HISTORY PRODUCT MODEL

History becomes one unified feed rather than permanently separated mode sections.

Canonical user-facing type vocabulary:

```text
ALL
MY MAKEUP KIT
RECOMMENDATIONS
```

Underlying domain enum/model names remain unchanged.

---

# 8. ONE FEED, TWO DATA AUTHORITIES

```text
STANDARD HISTORY
→ current Standard history/recommendation authority

MY MAKEUP KIT HISTORY
→ current validated My Kit history / immutable snapshot authority
```

Shared UI is encouraged.

Merged business authority is forbidden.

```text
STANDARD FALLBACK INTO MY KIT
NEVER

MY KIT FALLBACK INTO STANDARD
NEVER

OWNED-PRODUCT SNAPSHOT SUBSTITUTION
NEVER

HISTORY CARD VISUAL PARITY
REQUIRED

BUSINESS CONTROLLER MERGE
FORBIDDEN
```

---

# 9. TARGET HISTORY INFORMATION ARCHITECTURE

```text
History
Revisit every look you've created.

[ Search your history........................ ]

TYPE
[ All ] [ My Makeup Kit ] [ Recommendations ]

STATUS
[ All ] [ Completed ] [ Favorites ]       Sort

Today
[ uniform history card ]
[ uniform history card ]

Yesterday
[ uniform history card ]

This week
[ uniform history card ]

Earlier
[ uniform history card ]
```

Use global FaceTune typography, spacing, surfaces, radii, icons, and theme tokens.

---

# 10. PRIMARY TYPE FILTER

Primary filter:

```text
All
My Makeup Kit
Recommendations
```

Rules:

- `All` default unless accepted state restoration proves another default.
- filter by authoritative record type only.
- no AI calls.
- do not infer mode from rendered text or images.
- switching type should not unnecessarily reset status/sort/search.
- primary type filter has stronger visual hierarchy than status filter.

---

# 11. SECONDARY STATUS FILTER

Secondary filter:

```text
All
Completed
Favorites
```

Rules:

- reuse accepted definitions.
- never redefine `Completed`.
- never invent favorite persistence.
- visually quieter than Type.
- intersections must work predictably.

Example:

```text
My Makeup Kit + Favorites
= favorite My Makeup Kit history only
```

---

# 12. SORT

Use one compact global Sort affordance and a global bottom sheet.

Possible options:

```text
Newest first
Oldest first
Style A-Z
Recently viewed
```

Hard rules:

- `Newest first` default.
- `Oldest first` only if authoritative creation time exists.
- `Style A-Z` only if authoritative title/style exists.
- `Recently viewed` ONLY if authoritative last-viewed data already exists.
- omit unsupported options.
- no DB field may be added for this UI track.
- never fake persistent Recently Viewed using session order.

---

# 13. DATE GROUPING

For chronological sorts:

```text
Today
Yesterday
This week
Earlier
```

Use existing date/time utilities where available.

Do not redesign timezone architecture or mutate stored timestamps.

For `Style A-Z`, suppress misleading date group headings and use a flat alphabetical feed or already-supported alphabetical grouping.

---

# 14. SEARCH

Placeholder:

```text
Search your history
```

Preserve current authoritative search scope.

Allowed only when already present in authoritative loaded data:

- style/title
- mode/type
- product/shade name where authorized
- existing searchable metadata

Do NOT add AI semantic search, Gemini search, new server endpoint, DB FTS migration, or unsupported beauty-trait claims.

---

# 15. SHARED HISTORY CARD

Standard and My Kit must use one shared visual card shell:

```text
[ THUMBNAIL ]  TITLE / STYLE              ⋮
               MODE LABEL
               SECONDARY METADATA
               DATE / TIME
                                              >
```

Shared:

- thumbnail ratio/radius
- card radius/padding
- typography hierarchy
- chevron
- overflow
- loading placeholder
- interaction surface
- accessibility semantics

Mode-specific metadata remains truthful.

---

# 16. STANDARD CARD CONTENT

Example:

```text
EVERYDAY
Recommendation
Plan ready
Sep 5 · 2:41 PM
```

Rules:

- preserve Standard authority.
- `Plan ready` is quiet metadata, not a dominant pill.
- no My Kit product count.
- no fake owned-product metadata.

---

# 17. MY MAKEUP KIT CARD CONTENT

Example:

```text
OLD MONEY
My Makeup Kit
1 owned product
Sep 5 · 2:41 PM
```

Rules:

- use actual My Kit authority.
- grammar must be correct:
  - `1 owned product`
  - `2 owned products`
- variation metadata may remain only if it aids retrieval.
- no Standard status substitution.

---

# 18. DELETE ACTION

Delete must leave the primary card surface.

Preferred overflow:

```text
View
Favorite / Remove favorite
Delete
```

Preserve existing delete callback, confirmation, persistence, and post-delete behavior.

Do not add swipe-to-delete without explicit authorization.

---

# 19. FAVORITE INDICATOR

A quiet global heart indicator is allowed.

Rules:

- no giant favorite badge
- no emoji
- no new favorite persistence
- reuse existing favorite action/authority
- card indicator informational only

---

# 20. INITIAL LOADING UX

Initial History load:

```text
4-5 CARD-SHAPED SKELETONS
MATCH REAL CARD GEOMETRY
STABLE LAYOUT
```

Do not show independent spinners in every card.

Do not use neon shimmer or dramatic AI-style loading.

---

# 21. DATA LOADED, IMAGE STILL LOADING

Once metadata arrives:

```text
REAL CARD TEXT
+
THUMBNAIL PLACEHOLDER
```

When image succeeds:

```text
placeholder
→ subtle crossfade
→ thumbnail
```

When image fails:

- stable fallback
- card stays usable if record remains valid
- no full-card error spinner

---

# 22. THUMBNAIL RULES

Thumbnails require:

- consistent aspect ratio
- consistent crop policy
- consistent radius
- fixed layout footprint
- loading fallback
- error fallback
- stable identity

Do not let intrinsic image dimensions resize cards.

Avoid per-image CircularProgressIndicator unless current global image primitive makes it unavoidable.

---

# 23. IMAGE CACHE / RETURN PERFORMANCE

Returning to History should reuse already-available images where current architecture safely permits.

First inspect current image cache/package/signed-URL strategy.

Prefer accepted caching.

Do not add packages or weaken privacy merely for cache behavior.

If stronger caching requires infrastructure/security changes:

```text
STOP
REPORT
DEFER
```

---

# 24. PAGINATION / INCREMENTAL LOADING

Target UX if current repository already supports paging:

```text
INITIAL PAGE
→ reasonable first batch, commonly 10-20 under current contract

NEAR END
→ fetch next page
→ 2-3 bottom skeleton rows
→ append without replacing visible content
```

If paging requires repository contract rewrite, DB/RPC/schema/migration/Edge Function/RLS change:

```text
DO NOT IMPLEMENT
MARK DEFERRED
REPORT
```

No full-screen spinner after content is visible.

---

# 25. PULL TO REFRESH

Allowed if current data layer supports reload.

Rules:

- subtle global refresh behavior
- no giant Refresh CTA
- no AI calls
- no duplicate records
- keep visible feed during failure where practical
- no backend schema changes

---

# 26. FILTER / SORT STATE PRESERVATION

During active session, preserve where current architecture safely supports:

- Type
- Status
- Sort
- Search query
- Scroll position

Opening an item and returning should not reset the History experience unnecessarily.

Do not persist these to Supabase/settings unless already accepted app behavior.

---

# 27. SCROLL POSITION

History → item → Back should return to the same logical scroll position where safe.

Prefer local/PageStorage/navigation state rather than new global persistence.

---

# 28. EMPTY STATES

Required contextual states:

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

Use global tone/style.

No emoji or decorative AI art.

---

# 29. ERROR STATES

Initial load error:
- clear message
- valid retry where supported

Pagination error:
- keep loaded content
- inline retry at bottom

Image error:
- stable thumbnail fallback

No destructive state reset.

---

# 30. CARD TAP / REOPEN

Card tap/chevron must preserve current reopen behavior.

Do not regenerate content, create a new history item, change history identifiers, or cross-convert Standard/My Kit.

History is retrieval, not regeneration.

---

# 31. GLOBAL BOTTOM NAVIGATION HARD FREEZE

Do NOT change:

- tabs
- order
- icons
- labels
- destinations
- selected-state behavior
- navigation architecture

No History-specific nav variant.

---

# 32. GLOBAL UI DESIGN DIRECTION

Use **LUMINOUS BEAUTY INTELLIGENCE**.

History should feel elegant, premium, calm, editorial, modern, beauty-focused, trustworthy, fast, coherent, and restrained.

Avoid generic AI SaaS styling, neon, glowing borders, excessive gradients, glassmorphism, decorative blobs, emoji, pill overload, card nesting, arbitrary shadows, History-only typography, or over-badging.

Use accepted global typography, ColorScheme, spacing, radii, surfaces, borders, icons, buttons, sheets, menus, Light/Dark/System.

---

# 33. PERFORMANCE PRINCIPLES

Required:

- lazy list rendering
- stable card geometry
- no expensive work in `build()`
- no AI work in `build()`
- no URL signing in rebuild loops
- no duplicate load calls from harmless rebuilds
- no N+1 behavior introduced by presentation
- deterministic item keys
- avoid nested unbounded scrollables

Expensive async work must have a lifecycle owner outside repeated widget build.

---

# 34. LOADING CONCURRENCY SAFETY

If image/signed-URL state is asynchronous:

- stale completions must not overwrite newer state
- disposed widgets must not update invalid state
- rebuild must not re-trigger signing/fetch
- item identity must be stable
- filter/sort changes must not mix stale result sets

---

# 35. RESPONSIVE RULES

Support:

- POCO X3 GT
- narrower Android
- short Android
- large text
- keyboard open
- system insets

Do not truncate important titles unnecessarily.

Do not let bottom nav overlay content.

---

# 36. ACCESSIBILITY

Required:

- semantic search label
- semantic filter selected state
- sort semantics
- card title/mode readable
- overflow semantics
- destructive delete announced clearly
- favorite state announced
- >=44dp effective touch targets
- no color-only state
- large text support
- logical focus order
- skeletons excluded from misleading accessibility reading where appropriate

---

# 37. LOCALIZATION READINESS

Layouts must handle longer strings for mode labels, filters, counts, dates, and titles.

Do not solve long text by shrinking fonts below global tokens.

---

# 38. TESTING PRINCIPLE

Every History phase must test both Standard and My Makeup Kit and relevant:

- zero AI calls
- correct type mapping
- correct card identity
- correct reopen
- no cross-mode fallback
- filter intersections
- sort semantics
- loading states
- image failure
- empty states
- delete/favorite callback preservation
- large text
- theme safety

---

# 39. FORBIDDEN SHORTCUTS

Do NOT:

- merge Standard/My Kit repositories
- make storage public
- add DB fields for UI sorting
- add Recently viewed without authoritative data
- fake pagination
- filter by parsing rendered text
- use list index as identity
- refetch whole History on every chip tap without need
- trigger URL signing in `build()`
- show spinner farms
- keep delete permanently exposed
- redesign bottom nav
- change AI model/prompt
- modify tutorial/scan/result/recommendation contracts

---

# 40. DEFINITION OF DONE

The track passes only when:

```text
UNIFIED FEED                       PASS
TYPE FILTER                        PASS
STATUS FILTER                      PASS
SUPPORTED SORTS                    PASS
DATE GROUPING                      PASS
SHARED CARD                        PASS
STANDARD AUTHORITY                 PRESERVED
MY KIT AUTHORITY                   PRESERVED
DELETE OUT OF PRIMARY CARD         PASS
FAVORITE PRESENTATION              PASS WHERE SUPPORTED
INITIAL SKELETON                   PASS
THUMBNAIL-ONLY LOADING             PASS
IMAGE CROSSFADE                    PASS
IMAGE ERROR FALLBACK               PASS
PER-CARD SPINNER FARM              ABSENT
SEARCH                             PASS
EMPTY / ERROR STATES               PASS
SESSION FILTER PRESERVATION        PASS
SCROLL RESTORATION                 PASS WHERE SAFE
PULL TO REFRESH                    PASS IF SUPPORTED
PAGINATION                         PASS IF SUPPORTED OR PROPERLY DEFERRED
BOTTOM NAV                         UNCHANGED
AI CALLS                           0
V4 MODELS / PROMPTS                UNCHANGED
SUPABASE SCHEMA / RLS / STORAGE    UNCHANGED
LIGHT / DARK / SYSTEM              PASS
POCO X3 GT                         PASS
ACCESSIBILITY                      PASS
FULL FLUTTER TEST                  PASS
ANDROID DEBUG BUILD                PASS
PROTECTED DIFF                     PASS
```

---

# 41. RELEASE PHILOSOPHY

The user should see:

```text
SEARCH
FILTER
SORT
DATE
LOOK
```

not:

```text
DATABASE TYPE
INTERNAL STATUS
SIGNED URL STATE
MODE-SPECIFIC CARD ARCHITECTURE
DESTRUCTIVE ACTIONS EVERYWHERE
```

The implementation may be sophisticated.

The interface should not advertise that fact.
