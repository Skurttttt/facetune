# FaceTune — STEP-BY-STEP TUTORIAL V4 AI SOURCE OF TRUTH

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
**V4 Branch:** `feature/step-by-step-tutorial-v4-ai`  
**V4 Base Branch:** `main`  
**Verified Base Commit At V4 Branch Creation:** `eb6c5e379fb9e71233f893a3edf42a9db88959ed`  
**Canonical Final Preview:** the final makeup image successfully generated, shown to the user, and persisted by FaceTune — the highest visual authority for tutorial reconstruction. It is defined by its **role**, not by the model that rendered it.  
**Canonical Preview Renderer (current):** `gemini-3.1-flash-image`  
**Tutorial Guideline Model:** `gemini-3.1-flash-image`  
**Initial Tutorial Guideline Resolution:** `1K` for every AI-generated tutorial step  
**Recommendation Modes:** `standard` + `my_makeup_kit`  
**Tutorial Manifest Strategy:** Fixed supported vocabulary + deterministic order + dynamic visual inclusion  
**My Makeup Kit Rule:** AI may select only server-validated products actually owned by the authenticated user  

---

# 0. PURPOSE

This document is the highest V4 authority for the FaceTune **Step-by-Step Tutorial V4 AI** feature and its required alignment with **My Makeup Kit**.

V4 does **not** rebuild the entire FaceTune application from login onward.

The V4 branch was intentionally created from `main`. Existing working application features on `main` must be inspected and preserved. V4 exists to add a new tutorial architecture and to make the two recommendation modes compatible with that tutorial architecture from the beginning.

FaceTune must support two recommendation sources:

```text
STANDARD MODE
Face attributes
+
Selected style
        ↓
Brand-neutral AI makeup recommendation
```

and:

```text
MY MAKEUP KIT MODE
Face attributes
+
Selected style
+
Products actually owned by the user
        ↓
Owned-products-only AI makeup recommendation
```

Both modes eventually produce a **validated look plan** and a **canonical final preview**, currently rendered by `gemini-3.1-flash-image`. The renderer may change; the canonical preview's authority does not.

The V4 tutorial must answer one user question:

> **How do I recreate THIS exact makeup look shown in my final FaceTune preview?**

The word **THIS** refers to the user's specific canonical final makeup preview.

The tutorial must therefore be reference-grounded, comparison-based, and specific to the actual final preview.

It must never generate a generic tutorial merely from face shape, eye shape, selected style, product inventory, or common makeup rules.

For My Makeup Kit mode, the tutorial must additionally answer:

> **Which exact product from my saved kit should I use for this step?**

Visual placement comes from the canonical final preview.

Product identity comes from the validated look plan / immutable owned-product snapshot.

These authorities must never be confused.

---

# 1. DOCUMENT AUTHORITY

Before ANY V4 implementation, the coding agent must read these files in this exact order:

1. `CODEX_MASTER_GUIDE.md`
2. `FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_SOURCE_OF_TRUTH.md`
3. `FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_PHASE_PROMPTS.md`
4. the latest completion report for the current V4 phase, when one exists
5. the actual source code, migrations, tests, and deployed evidence relevant to the phase

Authority order:

1. **This V4 Source of Truth** governs the V4 tutorial feature.
2. `CODEX_MASTER_GUIDE.md` governs the rest of FaceTune.
3. The current V4 phase prompt authorizes only that phase.
4. Completion reports are evidence, not truth.
5. Actual code, migrations, logs, tests, and device behavior must be inspected rather than assumed.

If an older V2 or V3 tutorial document conflicts with this document, V4 wins for V4.

Do not silently resurrect V3 requirements.

---

# 2. SYSTEM ROLE

The coding agent must act as a production engineering team composed of:

- Principal Software Engineer
- Principal Software Architect
- Senior Flutter Engineer
- Senior Dart Engineer
- Senior Mobile Application Engineer
- Senior Supabase Engineer
- Senior PostgreSQL Engineer
- Senior Row Level Security Engineer
- Senior TypeScript / Deno Engineer
- Senior API Integration Engineer
- Senior Google Gemini AI Engineer
- Senior Multimodal AI Engineer
- Senior Image Generation Engineer
- Senior AI Systems Engineer
- Senior Prompt Engineer
- Senior Application Security Engineer
- Senior Privacy Engineer
- Senior Reliability Engineer
- Senior Async / Concurrency Engineer
- Senior Performance Engineer
- Senior AI Cost Optimization Engineer
- Senior QA Engineer
- Senior Regression Engineer
- Senior Integration Test Engineer
- Senior Production Debugging Engineer
- Senior Release Engineer
- Senior Code Reviewer
- Senior Mobile UI/UX Engineer

These rules apply equally to:

- OpenAI Codex
- Claude Code Pro using Opus 5

The coding agent must critically inspect the codebase. It must not claim a phase is complete because code was merely written or because a report says so.

---

# 3. ENGINEERING PRIORITIES

Every V4 decision must prioritize:

1. correctness
2. reference fidelity to the canonical final preview
3. preservation of existing working FaceTune behavior
4. security
5. privacy
6. maintainability
7. reliability
8. testability
9. AI cost control
10. performance
11. user experience
12. visual polish

Do not trade correctness for a shorter implementation unless the tradeoff is explicitly approved.

Do not perform a broad rewrite when a smaller integration is sufficient.

---

# 4. GIT BASELINE AND BRANCH SAFETY

V4 was created directly from `main`.

Verified at branch creation:

```text
git merge-base feature/step-by-step-tutorial-v4-ai main
eb6c5e379fb9e71233f893a3edf42a9db88959ed

git rev-parse main
eb6c5e379fb9e71233f893a3edf42a9db88959ed
```

Conceptually:

```text
                 main
                  |
          -----------------
          |               |
          V3              V4
   Hybrid Geometry   AI Guidelines
```

V4 is NOT:

```text
main
 ↓
V3
 ↓
V4
```

## Git restrictions

Do not automatically:

- merge `feature/step-by-step-tutorial-v3`
- cherry-pick V3 tutorial commits
- merge V4 into `main`
- push to `main`
- force push
- rebase
- reset Git history
- delete branches
- apply/drop unrelated stashes
- overwrite unrelated files

Do not run destructive commands such as:

```text
git reset --hard
git clean -fd
git checkout -- .
git restore .
git push --force
git push --force-with-lease
```

unless the user explicitly authorizes the exact operation.

Do not commit or push automatically unless the user explicitly requests it.

---

# 5. V4 ARCHITECTURE NAME

Use the following name:

## Canonical-Preview-Grounded AI Tutorial Rendering

Acceptable short name:

## Reference-Grounded AI Tutorial Rendering

Do not describe V4 as a geometry-rendering architecture.

Do not describe V4 as a generic AI makeup tutorial generator.

---

# 6. CANONICAL V4 FLOW

```text
                           USER SELFIE
                                ↓
                         FACE ANALYSIS
                                +
                         SELECTED STYLE
                                │
                 ┌──────────────┴──────────────┐
                 │                             │
                 ▼                             ▼
          STANDARD MODE                 MY MAKEUP KIT MODE
                 │                             │
      brand-neutral AI plan       owned-products-only AI plan
                 │                             │
                 │                   server validates product IDs
                 │                             │
                 └──────────────┬──────────────┘
                                ▼
                       VALIDATED LOOK PLAN
                                │
                                ▼
               CANONICAL PREVIEW RENDERER
                                │
                                ▼
                    CANONICAL FINAL PREVIEW
                                │
                 ┌──────────────┴──────────────┐
                 ▼                             ▼
           ORIGINAL SELFIE               FINAL PREVIEW
                 │                             │
                 └──────────────┬──────────────┘
                                ▼
                    VISUAL MANIFEST ANALYSIS
                                │
                      supported categories only
                                │
                                ▼
                     DYNAMIC RELEVANT STEPS
                                │
                   deterministic logical order
                                │
                                ▼
                    CURRENT TUTORIAL CATEGORY
                                +
                SUPPORTING VALIDATED LOOK CONTEXT
                                ↓
                    SECURE SUPABASE BACKEND
                                ↓
                    gemini-3.1-flash-image
                                ↓
                    1K GUIDELINE-ONLY IMAGE
                                ↓
                     PRIVATE SUPABASE STORAGE
                                ↓
                        TYPED FLUTTER FLOW
                                │
                 ┌──────────────┴──────────────┐
                 ▼                             ▼
           VISUAL GUIDELINE              PRODUCT DETAILS
          from final preview       from recommendation or kit snapshot
```

The tutorial path after the canonical final preview is shared by both recommendation modes.

Do not create separate tutorial engines for Standard Mode and My Makeup Kit Mode.

The only mode-specific behavior in tutorial presentation is the source of product information and the additional ownership constraints of My Makeup Kit.

---

# 7. CORE PRODUCT RULE

The tutorial must never decide what the makeup should look like.

The final preview already made that decision.

The tutorial's only visual responsibility is:

> **Explain how to reproduce the corresponding makeup feature visible in the canonical final preview.**

This is visual reverse engineering.

The recommendation source mode controls how the upstream look plan was created, but it does not control visual placement inside the tutorial.

For Standard Mode:

- product/shade guidance comes from the validated brand-neutral recommendation

For My Makeup Kit Mode:

- product/shade guidance comes from the immutable validated owned-product snapshot for that look

For both modes:

- placement, direction, coverage, shape, and visible intensity come from the canonical final preview
- the original selfie remains the rendering base
- the tutorial must not invent generic placement
- the tutorial must not apply actual makeup pigment

## 7.1 Recommendation source modes

Use a strongly typed source mode concept such as:

```text
standard
my_makeup_kit
```

Do not infer the mode from nullable fields.

Do not use a loose boolean such as `useKit`.

## 7.2 Standard Mode contract

Standard Mode uses:

```text
face analysis
+
selected style
        ↓
validated brand-neutral recommendation
```

Standard Mode must remain brand-neutral.

It may recommend:

- colors
- HEX values
- finish
- placement concepts
- intensity
- technique
- reasoning

It must not invent or recommend specific commercial product identities.

## 7.3 My Makeup Kit Mode contract

My Makeup Kit exists to answer:

> **What makeup look can I create with the products I already have?**

The user may save multiple products in each supported inventory category.

Supported product inventory categories initially include:

```text
Foundation
Concealer
Blush
Highlighter
Eyeshadow
Lipstick
Lip Gloss
Contour / Bronzer
Eyebrow
Eyeliner
```

A saved kit product may contain category-appropriate data such as:

```text
product name — optional, user supplied
color / shade name
HEX color
finish
foundation depth
foundation undertone
```

Do not require irrelevant fields for every category.

An incomplete kit is valid.

Example:

```text
Foundation      ✓
Concealer       ✗
Contour         ✗
Blush           ✓
Highlighter     ✗
Eyebrow         ✓
Eyeshadow       ✗
Eyeliner        ✓
Lipstick        ✓
Lip Gloss       ✗
```

The system must still be able to create the best possible look from the available owned products.

The AI must never fill a missing category with an imaginary product.

## 7.4 My Makeup Kit ownership rule

When My Makeup Kit mode is selected:

1. The server loads the authenticated user's eligible kit products.
2. The AI may choose only from those supplied product IDs.
3. The AI returns selected product IDs and category-appropriate usage guidance.
4. The server validates every selected product ID.
5. The server validates that every selected product:
   - exists
   - belongs to the authenticated user
   - is active/eligible under current product rules
   - belongs to the expected category
6. Any unknown, foreign, deleted, mismatched, or invented product ID is rejected.
7. The server creates a validated look plan only after ownership/category validation succeeds.

Gemini is not an authority on ownership.

## 7.5 User-supplied commercial names

Standard Mode remains brand-neutral.

My Makeup Kit Mode may display a product or brand name that the user actually entered for an owned product.

That is not a brand recommendation.

The AI must never invent:

- brand
- product name
- shade
- product ID
- product ownership

## 7.6 Immutable product snapshot

When a My Makeup Kit look becomes valid for final preview generation, preserve an immutable snapshot of the exact selected product data used for that look.

The historical look/tutorial must not change if the user later:

- edits the kit product
- renames it
- changes its shade metadata
- changes its finish
- deletes it from active inventory

Conceptually preserve only required snapshot fields:

```text
source_product_id
category
product_name
color_name / shade
hex
finish
foundation_depth
foundation_undertone
captured_at
```

Use current schema conventions and avoid duplicating data unnecessarily.

The snapshot must belong to the look, not to the user's mutable inventory state.

## 7.7 Validated look plan

Both recommendation modes must converge into one validated look plan contract before final preview generation.

Conceptually:

```text
ValidatedLookPlan
- source_mode
- analysis reference
- selected style
- category selections
- color / finish / technique data
- standard recommendation reference OR kit product snapshot reference
- prompt/model/version metadata as appropriate
```

Do not let tutorial code rebuild the upstream recommendation.

The tutorial consumes the already-validated result.

---

# 8. INPUT AUTHORITY ORDER

There are two different authority systems and they must not be mixed.

## 8.1 Visual tutorial authority

If information conflicts about visual placement, the tutorial must use:

1. **Canonical Final Preview**
   - highest authority for visible makeup placement
   - highest authority for visible direction
   - highest authority for visible shape
   - highest authority for visible coverage
   - highest authority for visible intensity/style

2. **Original Selfie**
   - highest authority for identity
   - facial appearance
   - pose
   - expression
   - hairstyle
   - rendering base

3. **Current Tutorial Category**
   - strictly limits which makeup feature may be analyzed and visualized

4. **Validated Look Plan / Product Snapshot**
   - supporting semantic and product context
   - may corroborate what product/category was intended
   - must not override visible placement in the final preview

5. **Persisted Makeup Recommendation**
   - supporting semantic context
   - must not override the final preview

6. **Face Analysis**
   - supporting facial context
   - may explain why a placement is useful
   - must not redesign the tutorial

7. **Selected Makeup Look**
   - supporting context only
   - must not override what is actually visible

## 8.2 Product identity authority

For Standard Mode:

```text
validated brand-neutral recommendation
```

is the product/shade guidance authority.

For My Makeup Kit Mode:

```text
server-validated immutable selected-product snapshot
```

is the product identity authority.

The final preview does not prove product ownership.

Gemini output does not prove product ownership.

## 8.3 Conflict examples

Prohibited:

```text
Final preview:
short subtle eyeliner wing

Selected style:
Party

Generic rule:
Party should have a long dramatic wing

Tutorial:
long dramatic wing
```

Correct:

```text
Final preview:
short subtle eyeliner wing

Tutorial:
short subtle eyeliner guideline matching the preview
```

My Makeup Kit prohibited:

```text
Owned kit:
no highlighter

AI:
returns invented highlighter ID

System:
accepts it
```

Correct:

```text
Server:
rejects unknown/unowned product selection
```

My Makeup Kit preview mismatch prohibited:

```text
Validated kit look plan:
no eyeliner selected

Canonical preview:
clearly contains added eyeliner
```

This must be treated as an upstream consistency failure, not as permission for the tutorial to invent an eyeliner product.

---

# 9. TWO MANDATORY IMAGE REFERENCES

Every AI tutorial rendering request must be grounded in two mandatory image references:

## Image A — ORIGINAL SELFIE

Purpose:

- rendering base
- identity reference
- natural face reference
- source geometry visible to the model

## Image B — CANONICAL FINAL PREVIEW

Purpose:

- authoritative makeup target
- before/after comparison target
- source of visible placement and shape

The server must clearly identify both roles in the prompt.

The client must not be allowed to arbitrarily substitute another user's images or unverified paths.

---

# 10. MODEL CONTRACTS

## 10.1 Final Makeup Preview

Keep the working final preview system. The canonical authority is the persisted
preview artifact, not the model that produced it. The current renderer is:

```text
gemini-3.1-flash-image
```

V4 does not replace the final makeup preview system.

Do not downgrade the final preview model as part of V4.

Do not modify final preview behavior unless a minimal integration change is strictly required.

---

## 10.2 Tutorial Guideline Rendering

Locked initial V4 model:

```text
gemini-3.1-flash-image
```

Locked initial output resolution:

```text
1K
```

Every AI-generated tutorial guideline step uses `1K` during the initial V4 quality baseline.

Do not mix 0.5K and 1K during initial implementation.

Do not use 2K or 4K without evidence and explicit approval.

Do not silently substitute another Gemini model.

Before the first production integration, verify that the configured model ID is currently available through the intended Gemini API. If the exact required model is unavailable or its API contract has materially changed, STOP and report the issue. Do not silently change architecture.

---

# 11. CENTRALIZED AI CONFIGURATION

The tutorial model and resolution must be configured server-side in one maintainable location.

Conceptual configuration:

```text
TUTORIAL_GUIDELINE_MODEL = gemini-3.1-flash-image
TUTORIAL_GUIDELINE_RESOLUTION = 1K
TUTORIAL_PROMPT_VERSION = tutorial_guideline_v4_1
```

Do not:

- hardcode the resolution independently in each category
- let Flutter select arbitrary Gemini model IDs
- let Flutter control prompt versions
- let the client request arbitrary output resolutions

A later cost-optimization phase may test 0.5K, but only after the 1K quality baseline is locked and the user explicitly approves the change.

---

# 11A. DYNAMIC MANIFEST AI CONFIGURATION

The visual manifest analyzer is a separate server-side AI responsibility from guideline image rendering.

It must use a Gemini multimodal model that:

- can compare the original selfie and canonical final preview
- can return structured output appropriate for strict server validation
- is verified as currently supported at implementation time

Prefer reusing the approved structured-output Gemini model already present in FaceTune if it satisfies the requirement.

Do not hardcode a guessed model ID in Flutter.

Centralize:

```text
TUTORIAL_MANIFEST_MODEL
TUTORIAL_MANIFEST_PROMPT_VERSION
TUTORIAL_MANIFEST_SCHEMA_VERSION
```

Do not let the client select these values.

The manifest analyzer must never render tutorial images.

The Flash Image renderer must never become the authority for category inclusion.

---

# 11B. CANONICAL PREVIEW CONSISTENCY FOR MY MAKEUP KIT

When the source mode is `my_makeup_kit`, the final preview is allowed to visualize only the makeup plan produced from server-validated selected owned products.

The final preview prompt/input must not add unsupported makeup categories merely because they suit the selected style.

If a downstream visual comparison strongly indicates that the canonical preview contains a makeup category that was not present in the validated My Makeup Kit look plan:

- do not invent a missing product
- do not silently switch to Standard Mode
- do not build a misleading tutorial step
- flag the inconsistency for controlled recovery/regeneration
- preserve sanitized diagnostics

This consistency rule protects the user promise:

> **This look can be recreated with products you actually own.**

---

# 12. IMPORTANT MODEL LIMITATION

V4 must acknowledge that generative image editing is probabilistic.

Strict prompt engineering can improve fidelity but cannot guarantee mathematically exact placement.

Therefore V4 acceptance criteria are based on **visual fidelity to the final preview**, not exact geometry such as:

```text
wing_angle = 8.000°
```

The product requirement is:

> The generated guideline must be visually faithful enough that a user following it would reproduce the intended placement and direction visible in the final preview.

Do not claim pixel-perfect or mathematically exact guideline placement unless a deterministic system is actually used.

---

# 13. NO V3 GEOMETRY PIPELINE

V4 must NOT add or depend on:

- AI geometry mapper
- normalized geometry JSON
- face landmark JSON
- CustomPainter makeup geometry
- deterministic tutorial polygons
- MediaPipe
- OpenCV
- TensorFlow Lite
- real-time AR
- landmark tracking
- cumulative intermediate makeup images

Do not port V3 geometry code into V4 merely because it already exists elsewhere.

V4 may use normal Flutter drawing for ordinary UI chrome, progress indicators, borders, icons, or non-face tutorial UI. The prohibition applies to V3-style face guideline geometry rendering.

---

# 14. GUIDELINE-ONLY OUTPUT CONTRACT

The tutorial AI must generate **guidelines only**.

It must NOT apply the actual makeup.

It must NOT generate a progressive makeover.

It must NOT create a new finished beauty image for each step.

The allowed visual language includes:

- thin guide lines
- dashed target boundaries
- anchor points
- start/end markers
- arrows
- direction indicators
- zone outlines
- crease boundaries
- lip border traces
- cheekbone path guides
- jawline path guides
- temple path guides

The tutorial image must avoid visual elements that look like finished pigment.

Do not apply:

- black eyeliner fill
- colored eyeshadow
- pink blush pigment
- brown contour pigment
- concealer/foundation paint
- shimmer highlighter
- lipstick fill
- brow color fill

The guideline exists to show **where and how**, not to re-render the final makeup.

---

# 15. NO GENERATED TEXT INSIDE THE IMAGE — INITIAL V4 BASELINE

For the initial V4 quality baseline:

- do not require Gemini to render category names inside the image
- do not require long instructional text inside the generated image
- do not require numbered labels inside the generated image

Flutter owns:

- category title
- step number
- progress
- buttons
- help text
- loading/error states

The generated image should focus on visual guidance.

This reduces text-rendering errors and keeps the AI task constrained.

---

# 16. CATEGORY-SCOPED ANALYSIS

Every Gemini tutorial request must analyze only ONE makeup category.

Example:

```text
CURRENT CATEGORY = EYELINER

Compare:
Image A = original selfie
Image B = canonical final preview

Analyze:
EYELINER ONLY

Ignore:
Foundation
Concealer
Contour
Blush
Highlighter
Eyebrows
Eyeshadow
Lips

Output:
Image A with eyeliner guideline only
```

Do not ask one generation to render all tutorial steps at once for the initial V4 architecture.

Do not generate a single multi-panel tutorial atlas in the initial V4 implementation.

The initial V4 quality strategy is one focused 1K image per generated tutorial category.

---

# 17. SUPPORTED INITIAL V4 CATEGORIES

The supported **tutorial category vocabulary** is controlled and initially contains:

1. Foundation
2. Concealer
3. Contour / Bronzer
4. Blush
5. Highlighter
6. Eyebrows
7. Eyeshadow
8. Eyeliner
9. Lips

This is the set of categories the tutorial system understands.

The architecture must not assume that all nine categories appear in every tutorial.

The architecture must not assume that nine is forever fixed.

The vocabulary must be maintainable and extensible through controlled application changes.

Gemini must not invent tutorial categories such as:

- `Cheek Sculpting Enhancement`
- `Eye Definition`
- `Radiance Layer`

## Product-to-tutorial category mapping

My Makeup Kit inventory categories may map into the tutorial vocabulary.

Examples:

```text
Lipstick      ┐
              ├──> Lips
Lip Gloss     ┘

Contour       ┐
              ├──> Contour / Bronzer
Bronzer       ┘

Eyebrow product ──> Eyebrows
```

A tutorial step may therefore display one or more validated product snapshot items when multiple owned products were intentionally used for the same tutorial category, for example Lipstick + Lip Gloss in the `Lips` step.

The mapping must be server-owned and tested.

Do not let Gemini invent category mappings.

The final makeup preview itself is reused as the final destination view and does not require another Gemini tutorial generation.

---

# 18. CATEGORY VISUAL INTENT

## Foundation

Show:

- coverage perimeter
- central-to-outer blending direction if appropriate
- areas to include/avoid where visible from the final result

Do not apply foundation pigment.

## Concealer

Show:

- under-eye placement boundaries
- targeted center-face or spot placement where applicable
- blend direction

Do not render concealer paint.

## Contour / Bronzer

Show:

- cheekbone path
- temple path
- jawline path
- nose path only if the final preview visibly indicates it
- blending direction arrows

Do not render brown contour.

## Blush

Show:

- placement boundary
- height on the cheek
- inward/outward extent
- blending direction

Do not render pink/rose pigment.

## Highlighter

Show:

- highlight traces or boundaries
- cheekbone/top-of-feature placement
- only areas visible in the final target

Do not render shimmer.

## Eyebrows

Show:

- start point
- arch point
- tail direction
- optional sparse directional stroke guides

Do not fill brows with pigment.

## Eyeshadow

Show:

- lid zone boundary
- crease boundary
- outer corner / outer-V boundary when visible
- inner corner placement where visible
- blend direction

Do not apply eyeshadow color.

## Eyeliner

Show:

- start point
- path along lash line
- outer-corner transition
- wing direction
- wing endpoint
- approximate curvature/length matching the final preview

Do not apply black eyeliner.

## Lips

Show:

- natural lip border reference
- target border/overline guide when visible
- Cupid's bow emphasis
- corner extension where visible
- lower-lip boundary guidance

Do not fill the lips with lipstick.

---

# 19. PROMPT ENGINEERING PRINCIPLE

The prompt must explicitly state:

> The canonical final makeup preview is the authoritative visual target. Do not invent or substitute generic makeup placement. Derive the current category's instructional guideline from the visible difference between the original selfie and the final preview.

It must also state:

> Render the guideline on the original selfie. Preserve the user's identity, pose, expression, hairstyle, facial structure, lighting, and background as closely as the model permits. Do not reproduce the finished makeup.

It must also state:

> Analyze only the requested category. Ignore other makeup categories. Do not beautify, exaggerate, redesign, or creatively reinterpret the target.

Category-specific constraints must be isolated and versioned.

Do not build one enormous unmaintainable prompt string inside an Edge Function handler.

---

# 20. SERVER-AUTHORITATIVE INPUT RESOLUTION

Flutter must not send arbitrary trusted data such as:

- `user_id` to authorize ownership
- original image path as authority
- canonical preview path as authority
- arbitrary signed URLs
- model ID
- prompt version
- resolution
- arbitrary product IDs as trusted ownership
- another user's analysis ID
- another user's kit ID
- another user's product snapshot ID

Preferred conceptual tutorial-step request:

```json
{
  "tutorialSessionId": "<uuid>",
  "category": "eyeliner"
}
```

or, when the session has not yet been created:

```json
{
  "canonicalPreviewId": "<uuid>"
}
```

The server must derive authenticated user identity from the valid session/JWT.

The server must load and validate the owned:

- canonical generated image record
- associated analysis
- original image reference
- source mode
- validated look plan
- recommendation where applicable
- selected style
- tutorial session
- persisted dynamic manifest
- current step

When `source_mode = my_makeup_kit`, the server must also resolve:

- immutable look product snapshot
- snapshot items mapped to the current tutorial category
- source product ownership history/reference where retained
- validated product/category mapping

Do not trust client-provided ownership.

Do not allow Flutter to substitute arbitrary product metadata into the tutorial.

Product text displayed by Flutter must come from server-validated data.

---

# 21. SECURE GEMINI ARCHITECTURE

All Gemini operations remain server-side.

## 21.1 Dual-mode recommendation path

```text
Flutter
  ↓
Authenticated Supabase Backend
  ↓
source_mode
  ├── standard
  │      ↓
  │   brand-neutral recommendation
  │
  └── my_makeup_kit
         ↓
      server loads owned products
         ↓
      Gemini selects only supplied IDs
         ↓
      server validates ownership/category
         ↓
      immutable product snapshot
  ↓
VALIDATED LOOK PLAN
  ↓
gemini-3.1-flash-image
  ↓
CANONICAL FINAL PREVIEW
```

## 21.2 Dynamic manifest path

```text
Owned Original Selfie
+
Owned Canonical Final Preview
  ↓
Authenticated Supabase Backend
  ↓
Server-configured Gemini multimodal structured-output analysis
  ↓
Server validates supported category vocabulary
  ↓
DYNAMIC MANIFEST
  ↓
Deterministic logical ordering
```

## 21.3 Guideline path

```text
Flutter
  ↓
Riverpod Controller / Notifier
  ↓
Use Case
  ↓
Repository
  ↓
Remote Data Source
  ↓
Authenticated Supabase Edge Function
  ↓
Server ownership validation
  ↓
Accepted manifest / included category validation
  ↓
Private Image A + Image B retrieval
  ↓
Resolve source-mode product context
  ↓
Gemini 3.1 Flash Image
  ↓
Output validation
  ↓
Private Supabase Storage
  ↓
Database persistence
  ↓
Typed response
  ↓
Flutter
```

Never call Gemini directly from Flutter.

Never expose `GEMINI_API_KEY` in:

- Dart code
- Flutter assets
- Android resources
- client configuration
- logs
- error messages

Do not disable authentication/JWT verification to make development easier.

The server remains authoritative for:

- source mode
- product ownership
- product/category mapping
- immutable snapshot selection
- canonical preview ownership
- dynamic manifest acceptance
- supported tutorial categories
- tutorial step order
- model IDs
- prompt versions
- resolution
- persistence and idempotency

---

# 22. DATABASE / PERSISTENCE DESIGN

Inspect the existing schema before creating anything.

Do not duplicate tables that already serve the same purpose.

The names below are conceptual. Reuse or extend existing valid entities when possible.

## 22.1 My Makeup Kit inventory

If the current V4/main codebase does not already provide an equivalent, My Makeup Kit requires secure user-owned product persistence.

Conceptual entity:

### `makeup_kit_products`

Minimum concerns:

```text
id
user_id
category
product_name nullable
color_name / shade nullable
hex nullable
finish nullable
foundation_depth nullable
foundation_undertone nullable
is_active
created_at
updated_at
```

Use category-specific validation.

Do not force foundation-only fields onto unrelated categories.

A user may have multiple products per category.

An incomplete kit is valid.

## 22.2 Validated look plan / selected-product snapshot

The application must preserve the exact My Makeup Kit selection used to create a canonical preview.

Prefer a normalized immutable snapshot design such as:

### `look_product_snapshots`

```text
id
user_id
analysis_id
canonical_preview_id or look-plan linkage when available
source_mode
created_at
```

### `look_product_snapshot_items`

```text
id
snapshot_id
source_product_id
tutorial_category
inventory_category
product_name nullable
color_name / shade nullable
hex nullable
finish nullable
foundation_depth nullable
foundation_undertone nullable
position/order if needed
created_at
```

Exact names may differ after inspecting current schema.

Snapshot data must remain stable even if mutable kit inventory later changes.

Do not use the mutable current kit as the historical tutorial authority.

## 22.3 Tutorial manifest persistence

The dynamic tutorial manifest is part of the canonical tutorial session state.

Conceptually track on `tutorial_sessions` or a normalized equivalent:

```text
source_mode
manifest_status
manifest_model
manifest_prompt_version
manifest_analysis_version
manifest_created_at
```

Only included categories should become tutorial steps.

If the architecture needs explicit manifest items before step creation, use a normalized structure rather than unvalidated arbitrary JSON.

Manifest items conceptually require:

```text
tutorial_session_id
category
position
presence_status
visual_confidence / evidence score when supported
product_snapshot_item linkage when My Makeup Kit mode requires it
```

Persist only fields that have a concrete product/engineering purpose.

## 22.4 Tutorial sessions

V4 conceptually needs:

### `tutorial_sessions`

Suggested concerns:

```text
id
user_id
analysis_id
recommendation_id nullable when architecture justifies
canonical_preview_id
source_mode
look_plan_id / product_snapshot_id when applicable
status
manifest_status
manifest_model
manifest_prompt_version
tutorial_prompt_version
tutorial_model
tutorial_resolution
created_at
updated_at
completed_at
```

## 22.5 Tutorial steps

### `tutorial_steps`

Suggested concerns:

```text
id
tutorial_session_id
user_id
category
position
status
guideline_storage_path
model_name
output_resolution
prompt_version
generation_attempt
created_at
updated_at
```

For My Makeup Kit, the step must be able to resolve the exact immutable product snapshot item(s) used for that category.

Use a join structure when multiple products can belong to one tutorial step. Do not encode multiple product IDs in an unchecked comma-separated string.

Optional sanitized technical metadata when justified:

```text
latency_ms
request_correlation_id
failure_code
```

Do not store:

- API keys
- JWTs
- full signed URLs
- raw base64 images
- unrestricted raw Gemini responses
- private prompts containing unnecessary user data
- invented product records produced only because Gemini mentioned them

Prefer enums/check constraints where maintainable.

Use foreign keys and indexes where justified.

Use unique constraints to prevent duplicate category generation when appropriate.

---

# 23. ROW LEVEL SECURITY

All tutorial records, kit inventory, look snapshots, and derived facial images are private user data.

RLS must ensure:

- a user can only read/write their own My Makeup Kit products
- a user cannot attach another user's kit product to a look
- a user cannot read another user's product snapshot
- a user cannot alter another user's snapshot
- immutable look snapshots cannot be silently rewritten through normal inventory edits
- a user can only read their own tutorial sessions
- a user can only read their own tutorial manifest/items
- a user can only read their own tutorial steps
- a user cannot attach another user's canonical preview
- a user cannot attach another user's analysis/recommendation
- a user cannot read another user's guideline image
- a user cannot update/delete another user's tutorial

Never solve access problems by disabling RLS.

Server-side authorization must still validate ownership even when RLS exists.

The backend must validate every My Makeup Kit product ID selected by AI against the authenticated user.

Defense in depth is required.

---

# 24. STORAGE DESIGN

Tutorial guideline images must be private.

Suggested conceptual path:

```text
users/{userId}/tutorials/{tutorialSessionId}/steps/{position}_{category}.png
```

Do not use public buckets for private facial images.

Do not overwrite:

- original selfie
- canonical final preview

Guideline images are derivative private facial images and must receive the same privacy treatment.

Use stable storage references in the database.

Use signed URLs only when needed for presentation and do not persist long-lived signed URLs as application authority.

---

# 25. TUTORIAL SESSION LIFECYCLE

Conceptual session states:

```text
notStarted
creatingSession
analyzingManifest
manifestReady
manifestFailed
ready
generatingStep
stepReady
stepFailed
completed
```

Step states:

```text
pending
generating
ready
failed
```

Manifest states should be explicit and must not be hidden inside ambiguous booleans.

Do not model the complete tutorial lifecycle using ambiguous booleans.

Existing successfully generated steps must be reusable.

An accepted manifest must be reusable for the same canonical preview.

Reopening a tutorial must not:

- re-run accepted manifest analysis
- regenerate already-ready steps

When the canonical final preview changes through regeneration/variation, the old accepted manifest is no longer automatically authoritative for the new visual target.

A new or versioned manifest must be created for the new canonical preview.

---

# 26. DYNAMIC STEP MANIFEST

The supported category vocabulary is fixed and application-controlled.

The **inclusion of categories in a specific tutorial is dynamic**.

The **order among included categories is deterministic and application-controlled**.

The **guideline placement/content is dynamic and canonical-preview-grounded**.

This distinction is permanent:

| Concern | V4 Rule |
|---|---|
| Supported category vocabulary | Controlled/fixed initial set |
| Category inclusion for a specific look | Dynamic from visual comparison |
| Category order | Deterministic logical order |
| Guideline placement | Dynamic from original + final preview |
| Guideline direction/shape/extent | Dynamic from original + final preview |
| Product identity in My Makeup Kit | Immutable validated owned-product snapshot |

## 26.1 Deterministic logical order

The initial logical order is:

```text
Foundation
Concealer
Contour / Bronzer
Blush
Highlighter
Eyebrows
Eyeshadow
Eyeliner
Lips
```

Gemini does not choose the order.

If Contour and Highlighter are absent, the remaining included steps stay in relative order:

```text
Foundation
Concealer
Blush
Eyebrows
Eyeshadow
Eyeliner
Lips
```

## 26.2 Manifest must visually inspect the canonical final preview

Before tutorial steps are created, the system must compare:

```text
Image A = original selfie
Image B = canonical final preview
```

and determine which supported makeup categories are **visibly part of this particular final look**.

The system must answer, only for the controlled vocabulary:

```text
Foundation?       present / absent / uncertain
Concealer?        present / absent / uncertain
Contour/Bronzer?  present / absent / uncertain
Blush?            present / absent / uncertain
Highlighter?      present / absent / uncertain
Eyebrows?         present / absent / uncertain
Eyeshadow?        present / absent / uncertain
Eyeliner?         present / absent / uncertain
Lips?             present / absent / uncertain
```

Do not create nine steps merely because nine categories are supported.

Do not include a category merely because:

- it is common in makeup
- the selected style usually uses it
- a face-shape rule recommends it
- the recommendation schema has a field for it
- My Makeup Kit contains a product in that category

## 26.3 Manifest analyzer

Use a server-side, prompt-versioned Gemini multimodal analysis operation capable of structured output.

Prefer reusing the current approved Gemini multimodal structured-output model already used by FaceTune when technically appropriate.

If a separate model is required:

- verify the current production model ID during implementation
- configure it server-side
- do not hardcode an unverified model ID in Flutter
- do not use free-form client prompts
- return only supported categories
- validate the structured response server-side

The manifest analyzer is not the same responsibility as `gemini-3.1-flash-image` guideline rendering.

The manifest analyzer decides **which supported categories are visibly present**.

Flash Image renders the **guideline for one already-approved category**.

## 26.4 Manifest authority

The canonical final preview is the highest authority for category presence.

The original selfie is required to distinguish natural facial color/structure from makeup added in the final preview.

Persisted recommendation, selected style, face analysis, and product selections may support ambiguous interpretation but may not force inclusion of a category that is not visually grounded in the final preview.

If visual comparison is unavailable, do not create a manifest that claims to reproduce the final preview.

Fail safely.

## 26.5 Uncertain category rule

If the analyzer cannot confidently establish a category from the visual comparison:

- do not invent a generic tutorial step
- use validated supporting look-plan context only to resolve genuine ambiguity
- persist/return an explicit unresolved/uncertain state where the implementation requires it
- do not silently treat `uncertain` as `present`

The implementation may define evidence thresholds only after controlled QA.

Do not hardcode arbitrary confidence thresholds without evidence.

## 26.6 Standard Mode inclusion

For Standard Mode:

```text
visual presence in canonical preview
        ↓
included tutorial category
```

The recommendation may corroborate what was intended, but it cannot force a category that the final preview does not visibly support.

## 26.7 My Makeup Kit inclusion

For My Makeup Kit Mode, inclusion requires both:

1. the category is visually grounded in the canonical final preview
2. the category maps to validated selected owned-product snapshot item(s)

Conceptually:

```text
VISIBLE IN FINAL PREVIEW
        ∩
VALIDATED OWNED PRODUCT SELECTION
        ↓
MY MAKEUP KIT TUTORIAL STEP
```

If the product was selected but the feature is not visually present:

- do not create a visual tutorial step merely because the product exists
- report/track the discrepancy where appropriate

If the final preview visibly contains a makeup category that has no corresponding validated owned-product selection:

- treat this as `kit_preview_mismatch` or equivalent
- do not invent a product
- do not create a misleading My Makeup Kit tutorial step
- the inconsistent preview must not be treated as a valid canonical My Makeup Kit result until the product/preview inconsistency is resolved

## 26.8 Manifest persistence

Once a manifest is accepted for a canonical preview, persist it.

Reopening the same tutorial for the same canonical preview must reuse the accepted manifest.

Do not re-run paid/AI manifest analysis on:

- widget rebuild
- route rebuild
- app resume
- simple reopen

A newly regenerated canonical preview is a new visual target and therefore requires a new or versioned manifest.

## 26.9 Examples

Natural look may result in:

```text
Foundation
Concealer
Blush
Eyebrows
Lips
```

Full Glam may result in:

```text
Foundation
Concealer
Contour / Bronzer
Blush
Highlighter
Eyebrows
Eyeshadow
Eyeliner
Lips
```

Clean Girl may result in:

```text
Foundation
Concealer
Blush
Highlighter
Eyebrows
Lips
```

These are examples only.

Do not hardcode style-to-step templates.

---

# 27. ON-DEMAND GENERATION AND COST CONTROL

Initial V4 must NOT automatically generate every tutorial image merely because a final preview exists.

Preferred behavior:

1. User opens Step-by-Step Tutorial.
2. Server creates/reuses a tutorial session.
3. If no accepted manifest exists for this canonical preview, run the dynamic visual manifest analysis once.
4. Persist/reuse the accepted manifest.
5. Create/resolve only manifest-included tutorial steps.
6. Generate the current step if not already ready.
7. Optionally prefetch at most the next included step when justified.
8. Persist the generated result.
9. Reuse it on revisit.

Do not generate nine images for users who never open the tutorial.

Do not re-run manifest analysis on:

- widget rebuild
- route rebuild
- app resume
- reopening the same tutorial with an accepted manifest

Do not regenerate guideline images on:

- widget rebuild
- route rebuild
- app resume
- reopening an already-ready step
- repeated button taps

Use separate idempotency/concurrency protection for:

- manifest analysis
- tutorial-session creation
- step-record creation
- Flash guideline generation

A duplicate client event must not create duplicate paid AI work.

Track technical usage separately for manifest analysis and guideline generation so future cost optimization can be measured rather than guessed.

---

# 28. RETRY POLICY

Retries cost money and can create duplicate results.

Automatic retry must be bounded.

Allowed automatic retry:

- at most one retry
- only for clearly transient technical failure
- only when no usable image result was persisted

Do not automatically retry because:

- the model's visual style is not preferred
- the guideline looks aesthetically imperfect
- a user navigated away
- the client timed out but the server generation may still be completing

Use server-side idempotency/status checks before retrying.

Explicit user-triggered regeneration is a separate action and should be deliberate.

---

# 29. OUTPUT VALIDATION

Before persisting a Gemini tutorial image, validate at minimum:

- response contains an image
- supported image MIME/type
- image is decodable
- image dimensions are reasonable for requested 1K output
- file size is within safe limits
- result is not empty
- category/session ownership still valid
- storage write succeeds before marking step ready

Do not claim automated code can perfectly validate visual makeup correctness unless such validation is actually implemented.

Visual guideline correctness is evaluated in the V4 QA phases.

---

# 30. FLUTTER RESPONSIBILITIES

Flutter owns:

- recommendation mode selection UI when this belongs to the existing product flow
- My Makeup Kit inventory presentation / editing UI through proper use cases
- tutorial navigation
- dynamic `Step X of N`
- category title
- product detail presentation
- product shade/color/finish presentation
- progress
- loading states
- retry UI
- image display
- accessibility
- localization-ready text
- back/forward navigation
- final canonical preview display
- explicit regenerate action when approved
- responsive layout

For Standard Mode, Flutter may show validated recommendation metadata.

For My Makeup Kit Mode, Flutter must show the exact immutable selected-product snapshot data for that tutorial step.

Flutter must not fetch product names from mutable current kit inventory as historical authority when a snapshot exists.

Flutter does NOT own:

- Gemini API key
- Gemini model selection
- manifest prompt authority
- manifest category decisions
- product ownership validation
- final-preview ownership validation
- tutorial prompt authority
- tutorial image generation
- arbitrary storage path authority
- guideline geometry rendering

The generated guideline image must not be the source of product text.

Product metadata is structured application data rendered by Flutter.

---

# 31. TUTORIAL UI PRINCIPLE

Each tutorial screen should primarily show:

```text
STEP X OF N
CATEGORY

[GUIDELINE IMAGE ON ORIGINAL SELFIE]

PRODUCT / SHADE DETAILS WHEN APPLICABLE

Short instruction / technique / tip

Previous      Next
```

The guideline image must be visually dominant.

For Standard Mode:

- product area may show brand-neutral color/shade/finish guidance derived from validated recommendation data

For My Makeup Kit Mode:

- product area must show the exact validated snapshot product(s) selected for that look
- examples include user-entered product name, shade, HEX, finish, foundation depth/undertone where relevant
- do not invent missing product information
- do not silently substitute a different current-kit product

Example:

```text
STEP 3 — BLUSH

Product:
Maybelline Example Blush

Shade:
Rose

Color:
#D98983

Finish:
Satin

[ORIGINAL SELFIE + BLUSH ZONE + BLEND ARROWS]
```

The product text is Flutter UI.

It must not be baked into the Gemini guideline image.

Do not clutter the experience with excessive prose.

The final tutorial destination reuses the canonical final preview without another tutorial AI generation.

## No cumulative intermediate makeup images

Initial V4 does not create progressive AI makeup results such as:

```text
Step 1 generated makeup
↓
Step 2 adds more makeup
↓
Step 3 adds more makeup
```

Each guideline step starts from the same original selfie and canonical final preview references.

This applies to both Standard Mode and My Makeup Kit Mode.

Cumulative generated makeup images are a separate future product decision and must not be smuggled into V4 implementation.

---

# 32. ERROR HANDLING

Handle intentionally:

- unauthenticated request
- expired session
- canonical preview not found
- canonical preview not owned by user
- original selfie not found
- analysis/recommendation missing
- invalid recommendation source mode
- My Makeup Kit product not found
- My Makeup Kit product not owned by user
- My Makeup Kit product category mismatch
- invented/unknown AI-selected product ID
- empty but valid kit state
- invalid kit product metadata
- immutable product snapshot missing
- kit look plan missing
- `kit_preview_mismatch`
- manifest analysis failure
- manifest malformed structured output
- unsupported category returned by manifest analyzer
- manifest uncertain/unresolved category
- no relevant tutorial categories detected
- private storage failure
- Gemini timeout
- Gemini refusal
- empty Gemini image result
- unsupported image response
- rate limit
- transient Gemini upstream failure
- duplicate manifest analysis request
- duplicate guideline generation request
- user navigation during generation
- failed persistence
- signed URL failure
- network loss

User-facing errors must be understandable and sanitized.

An incomplete My Makeup Kit is not inherently an error.

Do not expose:

- raw provider errors
- stack traces
- SQL details
- secrets
- private URLs
- JWTs
- request bodies containing image data
- another user's product metadata.

---

# 33. PROMPT VERSIONING

All AI prompts that materially affect V4 behavior must be versioned.

## Dynamic manifest

Conceptual versions:

```text
tutorial_manifest_v4_1
tutorial_manifest_schema_v4_1
```

Persist:

- manifest model
- manifest prompt version
- manifest schema version

Do not bury manifest prompt text in Flutter or random backend handlers.

## Tutorial guideline rendering

Initial common version:

```text
tutorial_guideline_v4_1
```

Category prompt modules may use:

```text
tutorial_guideline_v4_1_foundation
tutorial_guideline_v4_1_concealer
tutorial_guideline_v4_1_contour
tutorial_guideline_v4_1_blush
tutorial_guideline_v4_1_highlighter
tutorial_guideline_v4_1_eyebrows
tutorial_guideline_v4_1_eyeshadow
tutorial_guideline_v4_1_eyeliner
tutorial_guideline_v4_1_lips
```

## Recommendation / My Makeup Kit selection

If V4 materially changes or introduces the My Makeup Kit selection prompt, version that prompt separately from:

- Standard Mode recommendation prompt
- manifest prompt
- guideline prompt
- Pro-preview prompt

Do not use one giant prompt version for unrelated AI responsibilities.

Do not bury prompt text inside Flutter widgets.

Do not scatter prompt fragments randomly through backend handlers.

---

# 34. VISUAL FIDELITY ACCEPTANCE

V4 is successful only when the guideline is faithful to the canonical preview.

Evaluate:

- correct facial region
- correct relative position
- correct directional intent
- correct approximate extent/coverage
- correct shape class
- correct start/end relationship where applicable
- no obvious exaggeration
- no generic substitution
- no unrelated makeup feature inserted
- no actual makeup pigment rendered
- identity remains recognizably the original user
- no meaningful facial-structure redesign

Examples:

## Eyeliner

Must preserve:

- lash-line region
- relative start point
- wing direction
- approximate wing length
- approximate endpoint
- general curvature

It does not need to prove a mathematically exact degree.

## Blush

Must preserve:

- cheek height
- inward/outward position
- relative area
- blend direction

## Contour

Must preserve:

- cheekbone relationship
- temple/jaw/nose usage only when applicable
- general path and blend direction

---

# 35. VISUAL QA BENCHMARK

Before V4 is considered production-ready, build a controlled benchmark using diverse approved test images.

Target guideline categories must include at least:

- eyeliner
- eyeshadow
- eyebrows
- contour
- blush
- lips
- foundation
- concealer
- highlighter

Include variation across:

- face shapes
- eye shapes
- skin tones
- accepted lighting
- subtle vs stronger final looks
- Standard Mode
- My Makeup Kit Mode
- complete kits
- incomplete kits
- multiple products in the same kit category
- looks in which some supported tutorial categories are visually absent

Evaluate guideline results for:

1. original identity preservation
2. guideline-only compliance
3. target category isolation
4. final-preview fidelity
5. readability on POCO X3 GT
6. first-generation success
7. retry rate
8. latency
9. duplicate-call behavior
10. storage/reopen behavior
11. correct product details for My Makeup Kit
12. no invented My Makeup Kit product

Evaluate dynamic manifest results for:

1. supported vocabulary only
2. correct visual inclusion
3. correct visual exclusion
4. deterministic ordering
5. no style-template substitution
6. no generic face-shape inclusion
7. stable persistence/reopen
8. correct behavior on uncertain categories
9. Standard Mode correctness
10. My Makeup Kit intersection with validated product snapshot
11. detection of `kit_preview_mismatch`

Do not approve V4 solely from a few attractive examples.

Do not fabricate benchmark percentages.

---

# 36. 1K QUALITY BASELINE FIRST

V4 initially uses:

```text
ALL GENERATED TUTORIAL STEPS → 1K
```

Reason:

- remove output resolution as a confounding variable during quality validation
- establish one stable reference baseline
- simplify debugging
- evaluate model/prompt behavior before cost optimization

Only after V4 quality is locked may a future experiment compare:

```text
0.5K vs 1K
```

If 0.5K is tested later:

- do it in a separate approved optimization phase
- measure guideline readability and fidelity
- do not silently change production defaults
- keep an easy global 1K override

---

# 37. SECURITY AND PRIVACY

FaceTune processes facial images and must treat them as sensitive application data.

Requirements:

- private storage
- RLS
- authenticated Edge Functions
- server-side ownership checks
- minimal retention of derived metadata
- no image binary logging
- no signed URL logging
- no prompt logging that exposes private image data
- no Gemini API key exposure
- no user-to-user data leakage
- safe deletion behavior
- sanitized errors
- request bounds
- rate limiting
- abuse controls

Never trust the client as the authority for user ownership.

---

# 38. PERFORMANCE

Requirements:

- no duplicate Gemini requests
- reuse persisted steps
- avoid unnecessary image downloads
- use appropriately sized images in UI
- avoid decoding full-size images repeatedly in lists
- use Riverpod state intentionally
- avoid rebuild-triggered AI calls
- cancel/ignore stale client state safely without assuming server work was canceled
- prefetch at most one next step initially unless measurements justify otherwise
- keep scrolling/navigation smooth

Do not prematurely add a complicated caching framework.

---

# 39. OOP / CLEAN ARCHITECTURE RULES

Preserve the existing project's modular architecture.

Permanent rules:

- no God classes
- no God widgets
- no God repositories
- no business logic inside UI
- no Supabase calls from widgets
- no Gemini calls from widgets
- one primary responsibility per class/module
- use `data/domain/presentation` where business logic exists
- use interfaces/contracts where they improve testability
- prefer immutable domain models
- avoid passing raw `Map<String, dynamic>` through presentation
- centralize error translation
- keep server AI responsibilities separated from Flutter presentation
- do not create meaningless abstractions merely to imitate Clean Architecture

Conceptual feature structure:

```text
lib/features/tutorial/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
└── presentation/
    ├── controllers/
    ├── pages/
    └── widgets/
```

Use the existing project structure if it already provides a valid equivalent.

---

# 40. TESTING STRATEGY

Automated tests should use mocks/fakes for Gemini where practical.

Do not make every unit test call live Gemini.

Test at minimum:

## Core tutorial

- domain validation
- session creation
- dynamic step ordering
- manifest persistence
- idempotency
- repository behavior
- error mapping
- RLS policies where possible
- storage ownership
- retry rules
- state transitions
- UI states
- navigation
- reopening existing tutorial steps

## Dynamic manifest

- all nine supported vocabulary values accepted
- unsupported/invented category rejected
- visually absent category excluded
- visually present category included
- deterministic order after filtering
- uncertain category not silently included
- no generic style template
- same canonical preview reuses manifest
- regenerated canonical preview requires new/versioned manifest

## My Makeup Kit

- multiple products per category
- incomplete kit accepted
- empty kit handled intentionally
- AI-selected owned product accepted
- AI-selected foreign product rejected
- AI-invented product ID rejected
- category mismatch rejected
- exact selected product snapshot created
- snapshot remains unchanged after inventory edit/delete
- My Makeup Kit step resolves correct snapshot product
- visual category with no validated product produces mismatch
- selected product whose category is not visually present does not force a tutorial step
- Standard Mode remains brand-neutral
- user-entered My Makeup Kit product name may be displayed without being treated as AI brand recommendation

Live Gemini testing belongs in controlled integration/QA phases.

---

# 41. LOGGING

Allowed sanitized telemetry may include:

- tutorial session ID
- source mode
- manifest version
- manifest prompt version
- manifest model ID
- manifest included category count
- step category
- tutorial prompt version
- tutorial model ID
- output resolution
- status
- latency
- sanitized failure category
- generation attempt count
- sanitized mismatch code such as `kit_preview_mismatch`

Do not log:

- API keys
- service credentials
- JWTs
- full prompts containing private data
- original image bytes
- final preview bytes
- guideline image bytes
- signed URLs
- base64 image data
- user-entered product names unless specifically required by a privacy-reviewed logging design
- full kit contents
- product snapshot contents

Telemetry should measure system behavior, not become a shadow copy of private user data.

---

# 42. AI COST CONTROL

Do not hardcode Philippine peso estimates into application logic because provider pricing and FX rates can change.

Track technical usage instead.

## Manifest analysis

Track:

- manifest model
- manifest prompt version
- number of manifest analysis attempts
- accepted/reused manifest status
- latency
- sanitized failure category

Do not re-run an accepted manifest for the same canonical preview without a deliberate invalidation reason.

## Guideline generation

Track:

- tutorial model
- 1K resolution
- number of generation attempts
- number of completed steps
- regeneration count
- latency
- sanitized failure category

## My Makeup Kit recommendation

Where usage tracking exists, distinguish:

- Standard Mode recommendation operation
- My Makeup Kit recommendation operation

Do not log full private kit contents merely for cost measurement.

Cost optimization must never silently downgrade visual quality or weaken product-ownership validation.

The initial V4 guideline strategy is quality-first at 1K.

---

# 43. NO AUTOMATIC MODEL FALLBACK

Do not silently fall back from:

```text
gemini-3.1-flash-image
```

to another image model.

A silent model fallback can change:

- behavior
- quality
- cost
- prompt compatibility
- visual consistency

If the configured model is unavailable:

1. fail safely
2. return a sanitized user-facing error
3. log a sanitized provider/model availability code
4. report the issue
5. wait for explicit approval before substituting another model

---

# 44. NO SILENT PROMPT OR MANIFEST FALLBACK

Do not silently use:

- generic beauty instructions
- face-shape templates
- style-to-step templates
- fixed nine-step inclusion
- hardcoded generic guideline coordinates
- old V3 geometry
- a generic "best makeup for you" prompt
- mutable current-kit inventory as historical snapshot authority
- invented substitute My Makeup Kit products

If canonical final preview comparison is unavailable, the tutorial cannot claim to reproduce the final look.

If manifest analysis fails, do not silently create all nine steps.

If My Makeup Kit product validation fails, do not silently switch to Standard Mode.

Fail safely instead.

---

# 45. EXISTING FEATURE PRESERVATION

V4 must preserve working:

- authentication
- profile/session behavior
- selfie capture/upload
- face analysis
- style selection
- Standard Mode recommendation
- final Pro preview
- before/after result
- saved looks
- history
- private storage
- RLS
- existing app navigation

My Makeup Kit must be developed/aligned as part of V4 rather than left as a later tutorial retrofit.

If a valid My Makeup Kit implementation already exists in the repository or an existing feature branch:

- inspect it before duplicating concepts
- reuse compatible domain/schema/UI ideas where safe
- do not merge/cherry-pick automatically
- do not switch branches destructively
- preserve V4's `main` ancestry unless explicitly instructed otherwise

If My Makeup Kit is not present on the V4 branch, implement the minimum complete production feature required by the approved V4 phases.

Do not rewrite unrelated working systems merely to accommodate V4.

Add the smallest clean integration point necessary.

---

# 46. REMOTE DEPLOYMENT RULE

Do not deploy unrelated dirty work.

Before any remote migration or Edge Function deployment:

- inspect Git status
- inspect the exact files being deployed
- confirm they belong to the current phase
- verify the correct Supabase project/environment is linked
- avoid CLI upgrades during controlled work unless required and approved

Remote deployment must not be used as a substitute for understanding local changes.

---

# 47. DEFINITION OF DONE FOR EVERY V4 PHASE

A V4 phase is complete only when:

- only the authorized phase scope was implemented
- existing functionality remains working
- architecture remains modular
- relevant files are formatted
- static analysis is checked
- relevant tests are run
- errors introduced by the phase are fixed
- no secret is exposed
- no unrelated code is rewritten
- no next phase is started
- completion evidence is reported

Compilation alone is not enough.

A report claiming completion is not enough.

---

# 48. REQUIRED VALIDATION COMMANDS

Use the existing project commands and environment conventions.

When appropriate:

```powershell
flutter pub get
dart format .
flutter analyze
flutter test
```

For Android build validation, prefer the project's existing development configuration:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

For physical device validation when available:

```powershell
flutter run --dart-define-from-file=config/development.json
```

Do not hide or suppress genuine errors merely to make validation appear green.

---

# 49. PHASE EXECUTION RULE

Every V4 phase must follow:

```text
READ AUTHORITATIVE FILES
        ↓
INSPECT ACTUAL CODE / STATE
        ↓
STATE OBJECTIVE
        ↓
IDENTIFY MINIMUM FILES
        ↓
IMPLEMENT CURRENT PHASE ONLY
        ↓
TEST / VALIDATE
        ↓
REPORT EVIDENCE
        ↓
STOP
```

Never auto-start the next phase.

---

# 50. V4 DEVELOPMENT PHASES

V4 and My Makeup Kit are developed as one aligned system so the tutorial never requires a later architectural retrofit.

## V4-0 — Baseline Audit & Dual-Mode Integration Map

Read-only architecture audit.

Goal:

- prove V4 branch baseline
- locate existing Standard Mode flow
- inspect My Makeup Kit implementation if present
- if `feature/my-makeup-kit` exists, inspect it read-only without merge/cherry-pick
- locate final preview, analysis, recommendation, storage, auth, result flows
- identify schema/UI/domain gaps
- identify smallest aligned integration seam

No feature code.

---

## V4-1 — Dual-Mode Domain & Contracts

Create typed shared contracts for:

- `RecommendationSourceMode`
- Standard Mode
- My Makeup Kit Mode
- kit product categories
- kit product entity
- validated look plan
- immutable selected-product snapshot
- tutorial category
- dynamic manifest
- tutorial session/step contracts
- source-mode-aware repository/use case contracts
- central AI configuration contracts

No database or live AI yet.

---

## V4-2 — My Makeup Kit Persistence, Snapshot Persistence, Tutorial Persistence & RLS

Implement migration-backed persistence for:

- My Makeup Kit products
- immutable look product snapshots
- snapshot items
- source mode / validated look linkage
- tutorial sessions
- dynamic manifest state/items
- tutorial steps
- foreign keys/indexes
- RLS
- private storage strategy

No live Gemini generation.

---

## V4-3 — My Makeup Kit Inventory Application Flow

Implement:

- add product
- edit product
- delete/deactivate product
- multiple products per category
- incomplete kit
- category-aware fields
- repository/use cases
- Riverpod/controller integration
- My Makeup Kit inventory UI
- ownership-safe backend/data access

No recommendation selection AI yet.

---

## V4-4 — Dual-Mode Recommendation & Server Product Validation

Implement:

Standard Mode:
- preserve existing brand-neutral recommendation behavior

My Makeup Kit Mode:
- send only eligible owned products to AI
- AI selects only provided product IDs
- server validates ownership/category
- reject invented/foreign IDs
- build validated look plan
- create immutable product snapshot
- support incomplete kits
- never silently fall back to Standard Mode

---

## V4-5 — Canonical Pro Preview Integration & Kit Consistency Guard

Implement/validate:

- both modes feed the same canonical preview renderer (currently `gemini-3.1-flash-image`)
- final preview remains canonical visual target
- source mode and look-plan lineage persist
- My Makeup Kit preview uses validated selected products only
- detect/handle obvious product/preview inconsistency where technically feasible
- no tutorial generation yet

---

## V4-6 — Dynamic Visual Manifest Analyzer

Implement:

```text
Original Selfie
+
Canonical Final Preview
        ↓
Visual comparison
        ↓
Supported categories present?
        ↓
Persist dynamic manifest
```

Rules:

- fixed vocabulary
- deterministic order
- dynamic inclusion
- structured server-validated output
- no generic style/face-shape step templates
- Standard and My Makeup Kit mode rules
- My Makeup Kit requires validated product intersection
- detect `kit_preview_mismatch`

No guideline image generation yet.

---

## V4-7 — Tutorial Repository, Session Lifecycle & Idempotency

Implement:

- create/reuse tutorial session
- reuse accepted manifest
- create only included steps
- dynamic `N`
- deterministic order
- source-mode linkage
- immutable product snapshot linkage
- duplicate prevention
- typed errors

No Flash guideline generation yet.

---

## V4-8 — Canonical Source Resolution

Implement server-authoritative resolution of:

- auth
- original selfie
- canonical final preview
- source mode
- validated look plan
- recommendation
- My Makeup Kit snapshot when applicable
- dynamic manifest
- current category
- exact product snapshot item(s) for current step

No Flash generation yet.

---

## V4-9 — Gemini Flash Guideline Renderer Foundation

Integrate:

```text
gemini-3.1-flash-image
1K
```

Implement:

- server-side call
- centralized config
- two-image contract
- guideline-only rules
- one pilot category
- output validation
- private storage
- bounded retries
- prompt versioning

---

## V4-10 — Category-Specific Guideline Rendering & Product Presentation Contracts

Implement all supported tutorial categories.

Every category remains:

```text
1K
guideline-only
canonical-preview-grounded
```

Add structured product presentation mapping:

- Standard Mode → validated brand-neutral recommendation metadata
- My Makeup Kit → exact immutable selected-product snapshot item(s)

No product text inside generated images.

---

## V4-11 — Orchestration, On-Demand Generation & Cost Controls

Implement:

- current-step generation
- optional one-step prefetch
- no generate-all
- persisted reuse
- duplicate protection
- bounded retry
- explicit regeneration
- source-mode-aware state
- sanitized telemetry

---

## V4-12 — Flutter Tutorial UI & Dual-Mode Product Experience

Implement:

- tutorial entry
- dynamic `Step X of N`
- guideline image
- product details
- My Makeup Kit exact product/shade/HEX/finish
- Standard Mode brand-neutral metadata
- previous/next
- loading/error/retry
- final canonical preview
- accessibility/responsive UI

No cumulative intermediate makeup images.

---

## V4-13 — Reopen, Persistence, History & Snapshot Stability

Implement:

- reopen without regeneration
- manifest reuse
- ready-step reuse
- snapshot-stable product display after kit edit/delete
- saved/history linkage
- cleanup/deletion behavior

---

## V4-14 — Reliability, Security & Abuse Hardening

Audit:

- auth/RLS
- product ownership
- invented product IDs
- cross-user kit access
- immutable snapshot rules
- manifest abuse
- duplicate calls
- rate limits
- prompt injection
- storage privacy
- logs
- source-mode tampering
- silent fallbacks

---

## V4-15 — Visual Manifest QA, Guideline QA & Prompt Optimization

Benchmark:

- manifest inclusion/exclusion accuracy
- Standard Mode
- My Makeup Kit Mode
- incomplete kits
- kit/preview mismatches
- final-preview fidelity
- guideline-only compliance
- identity preservation
- category isolation
- product correctness
- latency/retry
- POCO X3 GT readability

Production remains 1K.

---

## V4-16 — End-to-End Device QA & Quality Baseline Lock

Validate both real journeys:

```text
STANDARD MODE
Selfie
↓
Analysis
↓
Style
↓
Brand-neutral recommendation
↓
Pro final preview
↓
Dynamic manifest
↓
Flash 1K guideline tutorial
```

and:

```text
MY MAKEUP KIT MODE
Save owned products
↓
Selfie
↓
Analysis
↓
Style
↓
Owned-products-only recommendation
↓
Server product validation
↓
Immutable product snapshot
↓
Pro final preview
↓
Dynamic manifest
↓
Flash 1K guideline tutorial
↓
Exact owned product shown per applicable step
```

Primary device:

```text
POCO X3 GT
```

V4 is not complete until both intended mode flows work end-to-end and the quality baseline is explicitly locked.

---

# 51. V4 GLOBAL ACCEPTANCE CRITERIA

V4 may be considered feature-complete only when all of the following are true:

## Architecture

- V4 remains cleanly isolated from V3 geometry architecture.
- Existing FaceTune final preview remains working.
- Standard Mode and My Makeup Kit Mode converge into one validated look-plan architecture.
- The tutorial engine is shared by both modes.
- No separate duplicate tutorial engine exists for My Makeup Kit.

## Canonical visual authority

- Tutorial input always includes the owned original selfie and owned canonical final preview.
- Final preview is treated as visual authority.
- Flash Image does not invent generic makeup placement.
- Tutorial output is guideline-only.
- No actual tutorial-step makeup pigment is rendered as intended output.
- No cumulative intermediate generated makeup images are part of initial V4.

## Dynamic manifest

- supported category vocabulary is controlled
- category order is deterministic
- category inclusion is dynamic
- manifest visually compares original selfie vs canonical final preview
- absent categories are not automatically turned into steps
- unsupported categories are rejected
- generic style/face-shape templates do not create steps
- uncertain categories do not silently become present
- accepted manifest is persisted/reused
- regenerated canonical preview receives new/versioned manifest

## My Makeup Kit

- user can save multiple products per category
- incomplete kit is valid
- AI cannot invent missing products
- server validates every AI-selected product ID
- cross-user product selection is impossible through normal/attacker paths
- product category mismatch is rejected
- exact selected products are snapshotted immutably for the look
- later kit edits/deletes do not change historical tutorial product details
- Standard Mode stays brand-neutral
- user-entered product names may be shown in My Makeup Kit mode
- My Makeup Kit tutorial steps display exact validated snapshot product(s)
- visually absent categories do not appear solely because the kit contains a product
- visually present category with no validated selected owned product is treated as a mismatch, not silently invented

## AI / cost / security

- Every initial generated tutorial step is 1K.
- Model/resolution/prompt version are centralized server-side.
- Gemini is called only through secure backend operations.
- Tutorial, kit, snapshot, and manifest records are private.
- RLS and server ownership checks prevent cross-user access.
- Existing ready steps reopen without new Gemini calls.
- Existing accepted manifest reopens without unnecessary AI analysis.
- Duplicate client events do not cause duplicate paid generations.
- Automatic retries are bounded.
- User-visible failures have recovery paths.
- No silent model, mode, prompt, product, or manifest fallback exists.

## Quality

- Manifest behavior passes controlled QA.
- Prompt/category behavior passes controlled visual QA.
- Both recommendation modes pass integration testing.
- POCO X3 GT real-device flow works.
- `flutter analyze` and relevant tests pass for V4 changes.
- No unrelated functionality regresses.
- No V4 phase is marked complete solely from code review without appropriate runtime evidence.

---

# 52. FINAL ENGINEERING PRINCIPLE

V4 is intentionally simpler than V3, but simpler must not mean careless.

The architecture removes the geometry-mapping and CustomPainter face-guideline pipeline because the product requirement is better expressed as reference-grounded visual instruction.

My Makeup Kit is not a later tutorial add-on.

It is an upstream recommendation mode designed into the same V4 contracts, persistence, canonical preview lineage, dynamic manifest, security model, and tutorial UI from the beginning.

The non-negotiable visual rule remains:

> **The final Pro preview defines the visual target. The original selfie defines the base. Gemini 3.1 Flash Image explains the route using guidelines only.**

The non-negotiable My Makeup Kit rule is:

> **The AI may use only products the authenticated user actually owns and the server validates. The exact selected products are snapshotted for the look and shown by Flutter; Gemini never invents product ownership.**

The non-negotiable manifest rule is:

> **The category vocabulary is controlled, the logical order is deterministic, but category inclusion is derived from visual comparison of the original selfie and canonical final preview.**

Build V4 so another senior engineering team can maintain, test, audit, and change it without reverse-engineering hidden assumptions.

---

