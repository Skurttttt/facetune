# FaceTune — TUTORIAL UI / UX PRODUCTIONIZATION SOURCE OF TRUTH

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
**Required Active Branch:** `feature/live-scan-educational-palette` — MUST be verified before implementation; do not create/switch automatically  
**Accepted V4 Tutorial Branch:** `feature/step-by-step-tutorial-v4-ai`  
**Accepted V4 Tutorial Quality Baseline:** ACCEPTED after real-device post-deploy verification  
**Canonical Final Preview Renderer — HARD LOCK:** `gemini-3.1-flash-image`  
**Tutorial Guideline Renderer — HARD LOCK:** `gemini-3.1-flash-image`  
**Tutorial Guideline Resolution — HARD LOCK:** `1K`  
**Tutorial Prompt — HARD LOCK:** `tutorial_guideline_v4_7`  
**Manifest Prompt — HARD LOCK:** `tutorial_manifest_v4_1`  
**Recommendation Modes:** `standard` + `my_makeup_kit`  
**Track Scope:** tutorial presentation architecture and UX productionization only  
**Design Direction:** Luminous Beauty Intelligence  
**Release Goal:** one coherent, premium, responsive, accessible tutorial experience shared visually by Standard and My Makeup Kit while preserving accepted V4 AI, manifest, data-authority, redraw, persistence, security, and cost behavior exactly

---

# 0. PURPOSE

This document is the highest authority for the FaceTune **Tutorial UI / UX Productionization Track**.

FaceTune already has a working accepted V4 tutorial system. This track does **not** rebuild the tutorial engine.

The central rule is:

> **CHANGE THE TUTORIAL PRESENTATION, NOT THE TUTORIAL SYSTEM.**

This track may improve:

```text
TUTORIAL INFORMATION ARCHITECTURE
VISUAL HIERARCHY
TYPOGRAPHY
SPACING
SURFACES
COMPONENT REUSE
PROGRESS PRESENTATION
GUIDE IMAGE PRESENTATION
GUIDE KEY PRESENTATION
REDRAW ACTION PLACEMENT
HOW-TO-APPLY PRESENTATION
YOUR-GOAL PRESENTATION
SUGGESTED-SHADES / MY-KIT PRODUCT PRESENTATION
FINAL-LOOK PRESENTATION
PERSISTENT BOTTOM NAVIGATION
STANDARD / MY-KIT VISUAL PARITY
RESPONSIVE LAYOUT
ACCESSIBILITY
LIGHT / DARK / SYSTEM CONSISTENCY
MOTION / TRANSITIONS
SCROLLING EXPERIENCE
VISUAL QA
```

This track must preserve:

```text
TUTORIAL GENERATION
TUTORIAL IMAGE CONTRACT
TUTORIAL MODEL
TUTORIAL PROMPT
TUTORIAL RESOLUTION
FINAL PREVIEW GENERATION
FINAL PREVIEW MODEL
CANONICAL FINAL PREVIEW AUTHORITY
DYNAMIC MANIFEST
MANIFEST PROMPT
CATEGORY INCLUSION
CATEGORY ORDER
CATEGORY IDENTITIES
MAKEUP BREAKDOWN AUTHORITY
STANDARD RECOMMENDATION AUTHORITY
MY MAKEUP KIT OWNED-PRODUCT AUTHORITY
MY MAKEUP KIT IMMUTABLE SNAPSHOT
REDRAW BUSINESS RULES
REDRAW CONFIRMATION
REDRAW COST / RETRY BEHAVIOR
RIVERPOD BUSINESS STATE
REPOSITORIES
DOMAIN ENTITIES
SUPABASE ARCHITECTURE
DATABASE
RLS
PRIVATE STORAGE
AUTHENTICATION
AI CALL COUNTS
```

A beautiful tutorial UI that changes accepted behavior is a failure.

---

# 1. DOCUMENT AUTHORITY

Before ANY tutorial UI implementation, the coding agent must read these files completely, in this order when they exist:

1. `CODEX_MASTER_GUIDE.md`
2. `FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_SOURCE_OF_TRUTH.md`
3. `FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_PHASE_PROMPTS.md`
4. `FACETUNE_V4_TUTORIAL_QUALITY_SOURCE_OF_TRUTH.md`
5. `FACETUNE_V4_TUTORIAL_QUALITY_PHASE_PROMPTS.md`
6. current canonical FaceTune UI Productionization Source of Truth
7. current canonical FaceTune UI Productionization Phase Prompts
8. `FACETUNE_LIVE_SCAN_EDUCATIONAL_PALETTE_SOURCE_OF_TRUTH.md` if present
9. `FACETUNE_LIVE_SCAN_EDUCATIONAL_PALETTE_PHASE_PROMPTS.md` if present
10. this file
11. `FACETUNE_TUTORIAL_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md`
12. relevant accepted V4 / UI / LSEP completion reports
13. actual current tutorial source, tests, configuration, deployed evidence, and real-device evidence relevant to the active phase

Authority order:

1. This Tutorial UI Source of Truth governs tutorial presentation.
2. Accepted V4 authorities continue to govern tutorial AI/functionality.
3. Global FaceTune UI authority governs design language.
4. `CODEX_MASTER_GUIDE.md` governs general engineering outside narrower authorities.
5. The active phase prompt authorizes only that phase.
6. Completion reports are evidence, not truth.
7. Actual code beats assumptions.
8. Real-device behavior beats stale screenshots.
9. No phase may silently widen scope.
10. UI convenience never authorizes AI, backend, security, or business-rule changes.

---

# 2. SYSTEM ROLE

The coding agent must behave as a disciplined production tutorial engineering team.

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

## Tutorial / UI Engineering

- Senior Tutorial UI Engineer
- Senior Design Systems Engineer
- Senior Design Systems Developer
- Senior Flutter UI Engineer
- Senior Mobile UI Engineer
- Senior Component Library Engineer
- Senior Responsive Layout Engineer
- Senior Motion / Interaction Engineer
- Senior Visual QA Engineer

## Product / UX / Beauty

- Senior Mobile Product Designer
- Senior UI Designer
- Senior UX Designer
- Senior UI/UX Designer
- Senior Interaction Designer
- Senior Visual Designer
- Senior Beauty-App Product Designer
- Senior Information Architecture Designer
- Senior Instructional UX Designer

## Accessibility / Localization

- Senior Accessibility Engineer
- Senior Inclusive Design Engineer
- Senior Semantic UI Engineer
- Senior Localization-Readiness Engineer

## Regression / Protection

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

## Protected AI / Data-Authority Awareness

- Senior Gemini AI Engineer
- Senior AI Systems Engineer
- Senior Tutorial AI Engineer
- Senior Dynamic Manifest Engineer
- Senior My Makeup Kit Engineer
- Senior Recommendation Authority Engineer

AI/backend roles exist to **protect** accepted behavior, not redesign it.

The coding agent must:

- inspect first
- challenge stale assumptions
- verify branch and working tree
- reuse working code
- identify the smallest safe presentation surface
- preserve accepted behavior
- use shared presentation only where safe
- keep visual state local when truly presentation-only
- stop when a requested visual change requires a protected cross-layer change
- never change model/prompt/backend to make UI easier

---

# 3. ABSOLUTE AI / MODEL HARD LOCKS

```text
CANONICAL FINAL PREVIEW MODEL
= gemini-3.1-flash-image

TUTORIAL GUIDELINE MODEL
= gemini-3.1-flash-image

TUTORIAL GUIDELINE RESOLUTION
= 1K

TUTORIAL PROMPT
= tutorial_guideline_v4_7

MANIFEST PROMPT
= tutorial_manifest_v4_1
```

Do NOT modify:

- model names
- model env configuration
- model selection
- fallback chains
- token settings
- retry rules
- prompt text
- prompt versions
- image resolution
- AI request/response schema
- AI lifecycle
- AI call count
- final-preview generation
- tutorial-generation orchestration
- manifest generation or reuse
- persisted outputs

If UI work appears to require any of these:

```text
STOP
REPORT
DO NOT IMPLEMENT
```

---

# 4. V4 TUTORIAL IMAGE CONTRACT — HARD LOCK

Preserve the accepted V4 tutorial image contract exactly.

Do not change:

- original selfie rendering-base authority
- canonical Final Preview reference authority
- category-specific comparison behavior
- guideline-only output requirement
- no makeup pigment requirement
- no chained-step image generation
- identity preservation behavior
- redraw generation behavior

No UI phase may improve image quality by changing the AI system.

---

# 5. GUIDE SYMBOL SEMANTICS — HARD LOCK

Accepted Guide Key meanings:

```text
● Start
━ Placement
- - Blend Zone
→ Direction
```

Only relevant accepted symbols should be displayed for the active category.

Presentation may change. Meaning may not.

---

# 6. DYNAMIC MANIFEST / CATEGORY AUTHORITY — HARD LOCK

Category inclusion/order comes from accepted runtime authority.

The UI must not hardcode:

- fixed step count
- fixed-nine fallback
- category inclusion
- category omission
- category order
- Lips-only final-step hacks

`Step X of N` must use runtime accepted data.

Final step means the current runtime category is the final runtime category, not that `Lips` is always hardcoded as last.

---

# 7. ONE TUTORIAL EXPERIENCE + TWO DATA AUTHORITIES

Core rule:

```text
ONE TUTORIAL EXPERIENCE
+
TWO DATA AUTHORITIES
```

Standard and My Makeup Kit must share the same tutorial presentation architecture.

They must NOT merge business authority.

```text
STANDARD TUTORIAL UI
=
MY MAKEUP KIT TUTORIAL UI

VISUAL STRUCTURE
IDENTICAL

NAVIGATION
IDENTICAL

GUIDE PRESENTATION
IDENTICAL

HOW TO APPLY
IDENTICAL PRESENTATION

FINAL LOOK PRESENTATION
IDENTICAL

RESPONSIVE BEHAVIOR
IDENTICAL

DATA AUTHORITY
SEPARATE
```

---

# 8. STANDARD DATA AUTHORITY

Standard tutorial may display only accepted Standard-mode tutorial and brand-neutral recommendation data.

Allowed recommendation presentation:

```text
shade name
swatch
finish
intensity
```

Standard remains brand-neutral.

Never invent brands.

---

# 9. MY MAKEUP KIT DATA AUTHORITY — ABSOLUTE

Preserve:

- owned-products-only authority
- server validation
- immutable product snapshot
- historical snapshot authority
- no Standard fallback
- no silent substitution
- no current-kit replacement of historical snapshot
- no business-controller merge with Standard

My Kit may display actual product/brand values only when present in authoritative immutable data.

If My Kit data is missing, do not fill it from Standard.

---

# 10. SHARED PRESENTATION COMPONENTS — AUTHORIZED WITH BOUNDARIES

Conceptual target:

```text
TutorialPageShell
├── TutorialProgressHeader
├── TutorialGuideHero
├── TutorialGuideKey
├── TutorialRedrawAction
├── TutorialHowToApply
├── TutorialRecommendationSection
├── TutorialFinalLookCard
└── TutorialBottomNavigation
```

Then:

```text
STANDARD PRESENTATION ADAPTER
→ accepted Standard values

MY KIT PRESENTATION ADAPTER
→ validated immutable owned-product snapshot values
```

Shared widgets may accept presentation-ready values.

Shared widgets must NOT own repositories, business controllers, server validation, data substitution rules, AI calls, or persistence.

Priority:

```text
CORRECTNESS
>
BUSINESS AUTHORITY
>
SECURITY
>
VISUAL PARITY
>
DRY
```

---

# 11. UNIFIED TUTORIAL SHELL

Every runtime tutorial category uses one shell.

Regular step:

```text
X

Step 4 of 5           progress
Eyeshadow

[ GUIDE IMAGE ]

Guide key

Redraw guide

How to apply

Suggested shades
or
From your makeup kit

Your final look

FIXED SAFE-AREA FOOTER
[ Back ]                    [ Next ]
```

Final runtime step:

```text
SAME SHELL

FIXED SAFE-AREA FOOTER
[ Back ]                  [ Finish ]
```

The final step must not become a different page architecture.

---

# 12. SCROLLING + FOOTER RULE

```text
TUTORIAL CONTENT
SCROLLABLE

BOTTOM NAVIGATION
PERSISTENT IN RESERVED LAYOUT SPACE
```

Do NOT make the tutorial non-scrollable.

Do NOT overlay navigation on content.

Do NOT require scrolling merely to find Back / Next / Finish.

SafeArea is required.

---

# 13. EXIT / BACK SEMANTICS

Top `X` means:

```text
EXIT TUTORIAL
```

Bottom `Back` means:

```text
PREVIOUS TUTORIAL CATEGORY
```

Do not mix these meanings.

---

# 14. PROGRESS HEADER

Target:

```text
Step 4 of 5        progress
Eyeshadow
```

Hierarchy:

```text
CATEGORY
PRIMARY

STEP COUNT
METADATA

PROGRESS
SUPPORTING
```

Keep compact.

Do not hardcode counts.

---

# 15. GUIDE IMAGE HERO

The generated guideline image remains the hero.

Preserve:

- accepted image source
- useful image size
- accepted crop behavior
- tap to enlarge
- fullscreen viewer
- category-specific generated guideline

Do not reduce it to a thumbnail.

Do not regenerate it for UI reasons.

---

# 16. TAP TO ENLARGE

Preserve the existing fullscreen capability.

The affordance may become visually quieter using global FaceTune utility styling.

Accessibility must keep the action discoverable.

---

# 17. COMPACT GUIDE KEY

Replace the large `What the guides mean` card with compact inline content:

```text
Guide key
● Start   ━ Placement   - - Blend zone   → Direction
```

Show only relevant symbols.

No semantic changes.

---

# 18. REDRAW ACTION PLACEMENT

Move redraw close to the guide.

Preferred label:

```text
Redraw guide
```

Use global vector refresh/redraw icon.

Preserve:

- explicit user initiation
- confirmation
- paid-generation behavior
- optional local-only reason behavior if present
- reason not persisted/logged/transmitted/prompted
- retries/cost rules
- same category authority
- no redraw from rebuild

This is placement only.

---

# 19. HOW TO APPLY — EDITORIAL STEP RAIL

Target:

```text
How to apply

01   Identify each eye zone       ━
     Existing authoritative instruction...

     │

02   Blend across the transition  - -
     Existing authoritative instruction...

     │

03   Follow the marked direction  →
     Existing authoritative instruction...
```

Rules:

- numbers are visual anchors
- titles remain strong
- body copy becomes supporting
- guide symbol may appear only where mapping is truthful
- use fewer giant surfaces
- preserve text and step order
- do not summarize Gemini text in Flutter

---

# 20. HOW-TO COPY AUTHORITY

Flutter must render accepted tutorial instruction text.

Do NOT:

- rewrite
- paraphrase
- summarize
- shorten locally
- invent
- truncate with ellipsis

If source copy is too long:

```text
STOP
REPORT COPY-DENSITY ISSUE
DO NOT MODIFY PROMPT
```

---

# 21. YOUR GOAL — EDITORIAL CALLOUT

Target:

```text
YOUR GOAL

│ Existing authoritative goal text...
```

Use restrained existing accent treatment.

No gradient, glow, giant card, or decorative AI styling.

---

# 22. STANDARD SUGGESTED SHADES

Target:

```text
Suggested shades

●  Bronzed Rose Quartz
   Shimmer · Medium

●  Soft Champagne
   Satin · Soft
```

Primary display focuses on:

```text
SHADE
SWATCH
FINISH
INTENSITY
```

Hex remains internal, not primary UI.

---

# 23. MY KIT RECOMMENDATION PRESENTATION

Use the same visual component.

Preferred label:

```text
From your makeup kit
```

Target:

```text
From your makeup kit

●  Actual Owned Product Name
   Finish · Intensity
```

Authoritative brand may display if present in immutable snapshot.

No Standard fallback.

---

# 24. HEX PRESENTATION RULE

Hex strings such as `#9E6B55` must not be primary tutorial UI.

Underlying values remain preserved.

No new Color Details feature is required in this track.

---

# 25. REMOVE DUPLICATE WHERE TO APPLY / TECHNIQUE FROM RECOMMENDATION SECTION

Responsibilities:

```text
HOW TO APPLY
→ where
→ movement
→ sequence
→ blending
→ direction

SUGGESTED SHADES / FROM YOUR MAKEUP KIT
→ color/product
→ finish
→ intensity
```

Therefore tutorial recommendation presentation should not repeat:

```text
Where to apply
Technique
```

Underlying placement/technique data remains preserved.

Downstream consumers remain untouched.

---

# 26. FEWER GIANT CARDS

Avoid:

```text
CARD
CARD
CARD
CARD
CARD
```

Preferred rhythm:

```text
GUIDE IMAGE
→ surface

GUIDE KEY
→ compact inline content

REDRAW
→ tertiary action

HOW TO APPLY
→ editorial page content

YOUR GOAL
→ restrained callout

RECOMMENDATION
→ compact beauty surface

FINAL LOOK
→ compact preview surface
```

---

# 27. COMPACT FINAL LOOK

Every step uses one compact reusable component:

```text
┌──────────────────────────────────┐
│ [thumbnail]  Your final look  ↗  │
│              View your target    │
└──────────────────────────────────┘
```

Tap opens existing canonical Final Look viewer.

The image must be the accepted canonical Final Preview.

No per-step generation.

---

# 28. FINAL STEP UNIFICATION

The final runtime step must NOT show a giant second inline Final Look.

Use the same compact component as every step.

Only footer action changes:

```text
Next
→
Finish
```

Finish preserves existing completion / Result behavior.

No new completion screen.

---

# 29. PERSISTENT BOTTOM NAVIGATION

Regular:

```text
[ Back ]                    [ Next ]
```

Final:

```text
[ Back ]                  [ Finish ]
```

Rules:

- persistent
- reserved layout space
- SafeArea
- no overlay
- global button hierarchy
- Back = previous step
- Next = next runtime step
- Finish = existing accepted completion

Do not change navigation business logic.

---

# 30. AI LIFECYCLE — HARD LOCK

No paid AI work from `build()`.

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

# 31. GLOBAL UI DESIGN DIRECTION

Use **LUMINOUS BEAUTY INTELLIGENCE**.

Tutorial should feel:

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
- purple-gradient AI clichés
- excessive glassmorphism
- glowing borders
- decorative blobs
- emoji icons
- excessive pills
- giant card nesting
- database-form UI
- random shadows
- tutorial-only styling systems

---

# 32. GLOBAL UI SYSTEM — HARD LOCK

Use existing FaceTune:

- typography tokens
- spacing tokens
- ColorScheme
- surfaces
- borders
- radii
- icon family
- button hierarchy
- modal conventions
- fullscreen viewer conventions
- Light theme
- Dark theme
- System theme
- accessibility semantics
- reduced-motion behavior where supported

Do not invent a tutorial-only design system.

---

# 33. RESPONSIVE REQUIREMENTS

Must work on:

- POCO X3 GT
- narrow Android
- 320 logical width where current tests support it
- normal text
- 2x text
- long category name
- long instruction title/body
- multiple shade/product rows
- final runtime step
- Standard
- My Kit

No overflow, clipped text, footer overlay, inaccessible final row, or broken viewer.

---

# 34. ACCESSIBILITY REQUIREMENTS

Required:

- top X semantic exit label
- Back / Next / Finish semantics
- enlarge semantics
- guide symbols not color-only
- swatches not sole color communication
- logical heading order
- adequate touch targets
- large text support
- focus order matches visual order
- modal/viewer close semantics
- reduced motion where supported

---

# 35. BACKEND / DB / RLS / STORAGE — ABSOLUTE FREEZE

Expected diff:

```text
supabase/
NO CHANGES
```

Do NOT modify:

- Edge Functions
- database
- migrations
- RLS
- storage policies
- auth
- secrets
- server validation

If required:

```text
STOP
REPORT
DO NOT IMPLEMENT
```

---

# 36. TESTING / QA PRINCIPLE

Every implementation phase must:

- run targeted tests
- run full Flutter tests unless explicitly impossible
- run `flutter analyze`
- build Android debug
- inspect protected diff
- report real-device status honestly

Automated tests do not prove premium visual quality.

Final acceptance requires real-device QA.

---

# 37. PROHIBITED SHORTCUTS

Do NOT:

- hardcode Lips as final
- hardcode fixed step count
- hardcode Standard data into My Kit
- use Standard fallback in My Kit
- replace immutable My Kit snapshot
- rewrite Gemini copy locally
- edit prompt to shorten content
- switch model for quality
- add another AI call for presentation
- regenerate Final Look per step
- move paid work into build()
- overlay footer
- reintroduce giant duplicate Final Look
- expose Hex as primary tutorial metadata
- restore duplicate Where to apply / Technique in recommendation section
- create multiple design systems

---

# 38. STOP CONDITIONS

STOP and report if:

- required authority missing and scope cannot be proven
- branch wrong
- working tree ownership unclear
- model change required
- tutorial prompt change required
- manifest prompt change required
- backend/DB/RLS/storage change required
- My Kit authority would be weakened
- Standard fallback into My Kit would be needed
- router architecture replacement would be needed
- AI call count would change
- redraw business rules would change
- protected file changes unexpectedly

---

# 39. CONTROLLED PHASE PLAN

```text
TUT-UI-0
Baseline audit + protected-surface map

TUT-UI-1
Shared tutorial shell + persistent footer + regular/final unification

TUT-UI-2
Guide hero + compact Guide Key + redraw placement

TUT-UI-3
How-to editorial rail + Your Goal callout

TUT-UI-4
Suggested Shades / My Kit recommendation presentation parity

TUT-UI-5
Compact Final Look + final-step cleanup + canonical viewer reuse

TUT-UI-6
Responsive/accessibility/global-theme polish + real-device parity QA

TUT-UI-7
Final protected-diff audit + release acceptance
```

Run exactly one phase at a time.

Never auto-continue.

---

# 40. FINAL RELEASE DEFINITION

Accept only when:

```text
ONE TUTORIAL SHELL
PASS

REGULAR / FINAL CONSISTENCY
PASS

STANDARD / MY KIT VISUAL PARITY
PASS

DATA AUTHORITY SEPARATION
PASS

PERSISTENT FOOTER
PASS

GUIDE HERO
PASS

COMPACT GUIDE KEY
PASS

REDRAW PLACEMENT
PASS

HOW-TO EDITORIAL RAIL
PASS

YOUR GOAL CALLOUT
PASS

STANDARD BEAUTY SHADE PRESENTATION
PASS

MY KIT OWNED-PRODUCT PRESENTATION
PASS

HEX PRIMARY UI
ABSENT

DUPLICATE WHERE TO APPLY / TECHNIQUE
ABSENT FROM TUTORIAL RECOMMENDATION SECTION

COMPACT FINAL LOOK
PASS

GIANT FINAL LOOK ON FINAL STEP
ABSENT

FULLSCREEN VIEWER
PASS

LIGHT / DARK / SYSTEM
PASS

LARGE TEXT
PASS

NARROW DEVICE
PASS

POCO X3 GT
PASS

EXTRA AI CALLS
0

MODEL CHANGES
NONE

PROMPT CHANGES
NONE

V4
UNCHANGED

BACKEND / DB / RLS / STORAGE
UNCHANGED

MY KIT AUTHORITY
UNCHANGED
```

---

# 41. CHANGE CONTROL

No coding agent may silently rewrite this Source of Truth during implementation.

If code proves this document stale:

```text
STOP
REPORT CONFLICT
REQUEST EXPLICIT AUTHORIZATION
```

---

# 42. FINAL PRINCIPLE

The desired result is:

> **A PREMIUM GUIDED BEAUTY EXPERIENCE WITH LESS VISUAL NOISE, BETTER INFORMATION ARCHITECTURE, STRONGER BEAUTY-EDITORIAL DESIGN, AND ZERO FUNCTIONAL REGRESSION.**

Internally it must remain the same accepted V4 system with the same models, prompts, manifest, business authorities, security, and cost behavior.
