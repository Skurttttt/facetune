# FaceTune — My Makeup Kit Implementation Roadmap

**File:** `FACETUNE_MY_MAKEUP_KIT_ROADMAP.md`  
**Feature specification:** `FACETUNE_MY_MAKEUP_KIT_GUIDE.md`  
**Parent system guide:** `CODEX_MASTER_GUIDE.md`  
**Protected baseline:** `main` at Phase 22  
**Development branch:** `feature/my-makeup-kit`  
**Intended agents:** OpenAI Codex and Claude Code Pro

## How to use

Each phase below is a complete copy/paste prompt. Every phase includes the mandatory Git safety header once. The phase body does not repeat the guide-reading instruction.

Execute one MK phase at a time. Review and checkpoint successful work before proceeding. Do not merge into `main` until My Makeup Kit is complete and regression-tested.

## Phase summary

| Phase | Name |
|---|---|
| MK-1 | Baseline & Architecture Contract |
| MK-2 | Supabase Schema & RLS |
| MK-3 | Domain, Repository & State Foundation |
| MK-4 | Kit Overview & Category UX |
| MK-5 | Add Product & Visual Color Picker |
| MK-6 | Edit, Delete & Inventory Management |
| MK-7 | Mode Selection Integration |
| MK-8 | Kit-Aware AI Recommendation Backend |
| MK-9 | Owned-Product Validation & Incomplete Kits |
| MK-10 | Kit-Based AI Preview Integration |
| MK-11 | Results, Saved Looks & History Compatibility |
| MK-12 | Loading, Errors, Offline, Security & Performance |
| MK-13 | End-to-End QA & Regression |
| MK-14 | Final UI/UX Polish & Feature Completion |

> Current project checkpoint: MK-1 through MK-3 have already been completed on `feature/my-makeup-kit`. Continue with MK-4 after confirming the repository state.

---

# MK-1 — Baseline & Architecture Contract

```text
GIT SAFETY CHECK — MANDATORY

Before modifying any file:

1. Run:
   git status
   git branch --show-current

2. Confirm the active branch is exactly:
   feature/my-makeup-kit

3. If the active branch is NOT feature/my-makeup-kit:
   STOP immediately and report the active branch.
   Do not modify any files.

PROTECTED BASELINE

The main branch is the protected Phase 22 baseline.

Do NOT:

- develop on main
- commit My Makeup Kit changes to main
- merge into main
- force-push
- reset or rewrite main
- delete branches
- discard existing work without my explicit approval

SOURCE OF TRUTH

Before implementation, read completely:

1. CODEX_MASTER_GUIDE.md
2. FACETUNE_MY_MAKEUP_KIT_GUIDE.md
3. The requested MK phase in FACETUNE_MY_MAKEUP_KIT_ROADMAP.md

Inspect the CURRENT repository before implementation.
Do not assume previous work exists unless it is actually present.

The existing Makeup Recommendation flow is FROZEN.
My Makeup Kit must remain additive and isolated.

Implement ONLY the requested MK phase.

Run all validation required by that phase.

Do not hide or suppress genuine errors.
Do not fabricate successful tests, builds, migrations, deployments, or device results.

Provide the required completion report.

Then STOP.

Do not implement the next MK phase until explicitly instructed.

PHASE TO IMPLEMENT

MK-1 — Baseline & Architecture Contract

OBJECTIVE
Establish the isolated technical boundary for My Makeup Kit.

AUDIT
Inspect feature structure, auth/session, analysis, style selection, standard recommendation, preview, Saved Looks, History, routing, Supabase migrations/RLS, Edge Functions, Riverpod patterns, error handling, and tests.

IMPLEMENT
Create only minimum feature scaffolding and typed contracts for product category, category-specific finish, foundation depth, foundation undertone, and normalized HEX color. Identify the smallest safe downstream convergence point with existing preview/results.

DO NOT
Create DB schema, CRUD UI, Gemini kit logic, kit preview, or refactor the frozen standard recommendation system.

TESTS
Cover categories, finishes, invalid combinations, HEX normalization/validation, depth, and undertone.

REQUIRED VALIDATION
- dart format .
- flutter analyze
- relevant flutter test
- configured flutter build apk --debug if materially appropriate

COMPLETION REPORT
PHASE COMPLETED:
EXISTING MAKEUP RECOMMENDATION MODIFIED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
ARCHITECTURE DECISIONS:
TESTS / VALIDATION:
REGRESSION CHECK:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE: MK-2 — Supabase Schema & RLS

Then STOP.
```

---

# MK-2 — Supabase Schema & RLS

```text
GIT SAFETY CHECK — MANDATORY

Before modifying any file:

1. Run:
   git status
   git branch --show-current

2. Confirm the active branch is exactly:
   feature/my-makeup-kit

3. If the active branch is NOT feature/my-makeup-kit:
   STOP immediately and report the active branch.
   Do not modify any files.

PROTECTED BASELINE

The main branch is the protected Phase 22 baseline.

Do NOT:

- develop on main
- commit My Makeup Kit changes to main
- merge into main
- force-push
- reset or rewrite main
- delete branches
- discard existing work without my explicit approval

SOURCE OF TRUTH

Before implementation, read completely:

1. CODEX_MASTER_GUIDE.md
2. FACETUNE_MY_MAKEUP_KIT_GUIDE.md
3. The requested MK phase in FACETUNE_MY_MAKEUP_KIT_ROADMAP.md

Inspect the CURRENT repository before implementation.
Do not assume previous work exists unless it is actually present.

The existing Makeup Recommendation flow is FROZEN.
My Makeup Kit must remain additive and isolated.

Implement ONLY the requested MK phase.

Run all validation required by that phase.

Do not hide or suppress genuine errors.
Do not fabricate successful tests, builds, migrations, deployments, or device results.

Provide the required completion report.

Then STOP.

Do not implement the next MK phase until explicitly instructed.

PHASE TO IMPLEMENT

MK-2 — Supabase Schema & RLS

OBJECTIVE
Create secure persistent storage for each authenticated user's private makeup inventory.

IMPLEMENT
Follow current migration conventions. Create a scalable `makeup_kit_products`-style schema supporting product ID, owner ID, category, optional product name, normalized HEX, optional shade label, finish, foundation depth/undertone where applicable, and timestamps.

Add appropriate PK/FK/indexes/constraints without destructive changes.

RLS
Users may SELECT/INSERT/UPDATE/DELETE only their own products. Prevent user-ID spoofing. Do not weaken existing policies.

VERIFY
Where supported, test cross-user access denial and valid own-product CRUD. Do not claim remote migration success unless actually applied.

COMPLETION REPORT
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DATABASE CHANGES:
RLS POLICIES:
INDEXES / CONSTRAINTS:
MIGRATION APPLIED:
SECURITY TESTS:
MANUAL ACTION REQUIRED:
EXISTING DATA IMPACT:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE: MK-3 — Domain, Repository & State Foundation

Then STOP.
```

---

# MK-3 — Domain, Repository & State Foundation

```text
GIT SAFETY CHECK — MANDATORY

Before modifying any file:

1. Run:
   git status
   git branch --show-current

2. Confirm the active branch is exactly:
   feature/my-makeup-kit

3. If the active branch is NOT feature/my-makeup-kit:
   STOP immediately and report the active branch.
   Do not modify any files.

PROTECTED BASELINE

The main branch is the protected Phase 22 baseline.

Do NOT:

- develop on main
- commit My Makeup Kit changes to main
- merge into main
- force-push
- reset or rewrite main
- delete branches
- discard existing work without my explicit approval

SOURCE OF TRUTH

Before implementation, read completely:

1. CODEX_MASTER_GUIDE.md
2. FACETUNE_MY_MAKEUP_KIT_GUIDE.md
3. The requested MK phase in FACETUNE_MY_MAKEUP_KIT_ROADMAP.md

Inspect the CURRENT repository before implementation.
Do not assume previous work exists unless it is actually present.

The existing Makeup Recommendation flow is FROZEN.
My Makeup Kit must remain additive and isolated.

Implement ONLY the requested MK phase.

Run all validation required by that phase.

Do not hide or suppress genuine errors.
Do not fabricate successful tests, builds, migrations, deployments, or device results.

Provide the required completion report.

Then STOP.

Do not implement the next MK phase until explicitly instructed.

PHASE TO IMPLEMENT

MK-3 — Domain, Repository & State Foundation

OBJECTIVE
Build the typed Flutter data/domain/state foundation.

IMPLEMENT
Following existing conventions, add the appropriate domain entity, DTO/model, mapper, repository interface/implementation, data source if appropriate, CRUD use cases where used, Riverpod providers, and controller/notifier state.

Support load all, category filtering, create, update, and delete.

VALIDATION
Validate category, finish/category compatibility, normalized HEX, category-specific fields, and foundation depth/undertone. Convert backend errors into safe app failures.

Do not implement the full UI or Gemini kit recommendation.

TESTS / VALIDATION
- mapping/repository/controller/validation/failure tests
- dart format .
- flutter analyze
- relevant flutter test
- configured Android debug build if appropriate

COMPLETION REPORT
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DOMAIN MODELS:
REPOSITORY:
RIVERPOD / STATE:
VALIDATION:
TESTS / VALIDATION:
REGRESSION CHECK:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE: MK-4 — Kit Overview & Category UX

Then STOP.
```

---

# MK-4 — Kit Overview & Category UX

```text
GIT SAFETY CHECK — MANDATORY

Before modifying any file:

1. Run:
   git status
   git branch --show-current

2. Confirm the active branch is exactly:
   feature/my-makeup-kit

3. If the active branch is NOT feature/my-makeup-kit:
   STOP immediately and report the active branch.
   Do not modify any files.

PROTECTED BASELINE

The main branch is the protected Phase 22 baseline.

Do NOT:

- develop on main
- commit My Makeup Kit changes to main
- merge into main
- force-push
- reset or rewrite main
- delete branches
- discard existing work without my explicit approval

SOURCE OF TRUTH

Before implementation, read completely:

1. CODEX_MASTER_GUIDE.md
2. FACETUNE_MY_MAKEUP_KIT_GUIDE.md
3. The requested MK phase in FACETUNE_MY_MAKEUP_KIT_ROADMAP.md

Inspect the CURRENT repository before implementation.
Do not assume previous work exists unless it is actually present.

The existing Makeup Recommendation flow is FROZEN.
My Makeup Kit must remain additive and isolated.

Implement ONLY the requested MK phase.

Run all validation required by that phase.

Do not hide or suppress genuine errors.
Do not fabricate successful tests, builds, migrations, deployments, or device results.

Provide the required completion report.

Then STOP.

Do not implement the next MK phase until explicitly instructed.

PHASE TO IMPLEMENT

MK-4 — Kit Overview & Category UX

OBJECTIVE
Create the premium My Makeup Kit inventory browsing experience.

NAVIGATION
Add an appropriate entry point within the existing Home/Profile/navigation hierarchy without changing the standard recommendation flow.

IMPLEMENT
- My Makeup Kit overview screen
- supported category presentation
- product counts where useful
- product cards/list items
- color swatches
- finish labels
- multiple products per category
- empty kit/category states
- loading/skeleton state
- error/retry state
- Add Product CTA

VISUAL REQUIREMENTS
Match FaceTune: premium beauty, modern/minimal, soft feminine, Material 3, existing typography/spacing/radii, accessible contrast, responsive Android layout.

Do not implement recommendation mode or Gemini logic yet.

TESTS
Cover loading, empty, populated, and error states where practical.

REQUIRED VALIDATION
- dart format .
- flutter analyze
- relevant flutter test
- configured Android debug build

COMPLETION REPORT
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
SCREENS / COMPONENTS:
NAVIGATION:
STATE INTEGRATION:
TESTS / VALIDATION:
ANDROID BUILD:
REGRESSION CHECK:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE: MK-5 — Add Product & Visual Color Picker

Then STOP.
```

---

# MK-5 — Add Product & Visual Color Picker

```text
GIT SAFETY CHECK — MANDATORY

Before modifying any file:

1. Run:
   git status
   git branch --show-current

2. Confirm the active branch is exactly:
   feature/my-makeup-kit

3. If the active branch is NOT feature/my-makeup-kit:
   STOP immediately and report the active branch.
   Do not modify any files.

PROTECTED BASELINE

The main branch is the protected Phase 22 baseline.

Do NOT:

- develop on main
- commit My Makeup Kit changes to main
- merge into main
- force-push
- reset or rewrite main
- delete branches
- discard existing work without my explicit approval

SOURCE OF TRUTH

Before implementation, read completely:

1. CODEX_MASTER_GUIDE.md
2. FACETUNE_MY_MAKEUP_KIT_GUIDE.md
3. The requested MK phase in FACETUNE_MY_MAKEUP_KIT_ROADMAP.md

Inspect the CURRENT repository before implementation.
Do not assume previous work exists unless it is actually present.

The existing Makeup Recommendation flow is FROZEN.
My Makeup Kit must remain additive and isolated.

Implement ONLY the requested MK phase.

Run all validation required by that phase.

Do not hide or suppress genuine errors.
Do not fabricate successful tests, builds, migrations, deployments, or device results.

Provide the required completion report.

Then STOP.

Do not implement the next MK phase until explicitly instructed.

PHASE TO IMPLEMENT

MK-5 — Add Product & Visual Color Picker

OBJECTIVE
Allow users to register makeup products they actually own.

FLOW
My Makeup Kit → Add Product → Category → category-specific form → Shade/Color → Finish → relevant attributes → Validate → Save → updated kit.

COLOR UX
Use a user-friendly visual color picker:
- curated category-appropriate beauty shades where useful
- selected-color preview
- custom visual color picker for precise adjustment
- normalized HEX stored internally
- optional advanced/reference HEX display/input if appropriate
- invalid HEX cannot be saved

Users must not need to understand HEX. Do not implement camera-based physical shade detection.

CATEGORY FORM
Use category-specific finishes from the Guide.
Foundation additionally supports Fair/Light/Medium/Tan/Deep depth and Cool/Neutral/Warm undertone.
Do not show irrelevant fields. Product name is optional; brand is not required.

SAVE
Implement validation, loading, duplicate-submit protection, success feedback, recovery, and preservation of entered values after recoverable failure.

TESTS
Include Foundation, Lipstick, Eyeshadow, Blush, Eyeliner, invalid finish/category combinations, and invalid colors.

REQUIRED VALIDATION
- dart format .
- flutter analyze
- relevant flutter test
- configured Android debug build
- manual add-product smoke test if device/backend available

COMPLETION REPORT
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
COLOR PICKER:
CURATED SHADE UX:
CATEGORY-SPECIFIC FORMS:
VALIDATION:
DATABASE OPERATIONS:
TESTS / VALIDATION:
ANDROID BUILD:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE: MK-6 — Edit, Delete & Inventory Management

Then STOP.
```

---

# MK-6 — Edit, Delete & Inventory Management

```text
GIT SAFETY CHECK — MANDATORY

Before modifying any file:

1. Run:
   git status
   git branch --show-current

2. Confirm the active branch is exactly:
   feature/my-makeup-kit

3. If the active branch is NOT feature/my-makeup-kit:
   STOP immediately and report the active branch.
   Do not modify any files.

PROTECTED BASELINE

The main branch is the protected Phase 22 baseline.

Do NOT:

- develop on main
- commit My Makeup Kit changes to main
- merge into main
- force-push
- reset or rewrite main
- delete branches
- discard existing work without my explicit approval

SOURCE OF TRUTH

Before implementation, read completely:

1. CODEX_MASTER_GUIDE.md
2. FACETUNE_MY_MAKEUP_KIT_GUIDE.md
3. The requested MK phase in FACETUNE_MY_MAKEUP_KIT_ROADMAP.md

Inspect the CURRENT repository before implementation.
Do not assume previous work exists unless it is actually present.

The existing Makeup Recommendation flow is FROZEN.
My Makeup Kit must remain additive and isolated.

Implement ONLY the requested MK phase.

Run all validation required by that phase.

Do not hide or suppress genuine errors.
Do not fabricate successful tests, builds, migrations, deployments, or device results.

Provide the required completion report.

Then STOP.

Do not implement the next MK phase until explicitly instructed.

PHASE TO IMPLEMENT

MK-6 — Edit, Delete & Inventory Management

OBJECTIVE
Let users maintain their real makeup collection over time.

IMPLEMENT
Support product details, editing name/color/finish/category-specific metadata, deletion with confirmation, correct state refresh, and safe mutation failure recovery.

If category changes are supported, clear/revalidate incompatible stale fields. Foundation-only metadata must not survive hidden after changing to an unrelated category.

Maintain ownership/RLS.

TESTS / VALIDATION
Cover CRUD and category-change validation.
- dart format .
- flutter analyze
- relevant flutter test
- configured Android build
- RLS regression where practical

COMPLETION REPORT
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
CRUD STATUS:
CATEGORY CHANGE BEHAVIOR:
VALIDATION:
RLS / OWNERSHIP:
TESTS / VALIDATION:
ANDROID BUILD:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE: MK-7 — Mode Selection Integration

Then STOP.
```

---

# MK-7 — Mode Selection Integration

```text
GIT SAFETY CHECK — MANDATORY

Before modifying any file:

1. Run:
   git status
   git branch --show-current

2. Confirm the active branch is exactly:
   feature/my-makeup-kit

3. If the active branch is NOT feature/my-makeup-kit:
   STOP immediately and report the active branch.
   Do not modify any files.

PROTECTED BASELINE

The main branch is the protected Phase 22 baseline.

Do NOT:

- develop on main
- commit My Makeup Kit changes to main
- merge into main
- force-push
- reset or rewrite main
- delete branches
- discard existing work without my explicit approval

SOURCE OF TRUTH

Before implementation, read completely:

1. CODEX_MASTER_GUIDE.md
2. FACETUNE_MY_MAKEUP_KIT_GUIDE.md
3. The requested MK phase in FACETUNE_MY_MAKEUP_KIT_ROADMAP.md

Inspect the CURRENT repository before implementation.
Do not assume previous work exists unless it is actually present.

The existing Makeup Recommendation flow is FROZEN.
My Makeup Kit must remain additive and isolated.

Implement ONLY the requested MK phase.

Run all validation required by that phase.

Do not hide or suppress genuine errors.
Do not fabricate successful tests, builds, migrations, deployments, or device results.

Provide the required completion report.

Then STOP.

Do not implement the next MK phase until explicitly instructed.

PHASE TO IMPLEMENT

MK-7 — Mode Selection Integration

OBJECTIVE
Allow explicit selection between Makeup Recommendation and My Makeup Kit without changing standard behavior.

UX
Add a clear mutually exclusive selector at the safest point in the current scan/style journey. Prefer explicit cards if clearer than a literal switch.

STANDARD MODE
Must enter the exact existing path. Do not modify its prompt, endpoint, model, repository behavior, response schema, or preview behavior.

MY MAKEUP KIT
- verify at least one valid product
- intentional empty-kit UX
- Add Product path
- allow return to standard mode
- preserve scan/style state where safe

Represent mode type-safely.

MANDATORY REGRESSION
Prove standard Makeup Recommendation still behaves as before.

REQUIRED VALIDATION
- dart format .
- flutter analyze
- relevant flutter test
- configured Android build
- standard-mode regression
- manual smoke test where available

COMPLETION REPORT
PHASE COMPLETED:
MODE SELECTOR:
STANDARD MODE MODIFIED:
MY MAKEUP KIT ENTRY:
EMPTY KIT UX:
FILES CREATED:
FILES MODIFIED:
TESTS / VALIDATION:
ORIGINAL MAKEUP RECOMMENDATION REGRESSION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE: MK-8 — Kit-Aware AI Recommendation Backend

Then STOP.
```

---

# MK-8 — Kit-Aware AI Recommendation Backend

```text
GIT SAFETY CHECK — MANDATORY

Before modifying any file:

1. Run:
   git status
   git branch --show-current

2. Confirm the active branch is exactly:
   feature/my-makeup-kit

3. If the active branch is NOT feature/my-makeup-kit:
   STOP immediately and report the active branch.
   Do not modify any files.

PROTECTED BASELINE

The main branch is the protected Phase 22 baseline.

Do NOT:

- develop on main
- commit My Makeup Kit changes to main
- merge into main
- force-push
- reset or rewrite main
- delete branches
- discard existing work without my explicit approval

SOURCE OF TRUTH

Before implementation, read completely:

1. CODEX_MASTER_GUIDE.md
2. FACETUNE_MY_MAKEUP_KIT_GUIDE.md
3. The requested MK phase in FACETUNE_MY_MAKEUP_KIT_ROADMAP.md

Inspect the CURRENT repository before implementation.
Do not assume previous work exists unless it is actually present.

The existing Makeup Recommendation flow is FROZEN.
My Makeup Kit must remain additive and isolated.

Implement ONLY the requested MK phase.

Run all validation required by that phase.

Do not hide or suppress genuine errors.
Do not fabricate successful tests, builds, migrations, deployments, or device results.

Provide the required completion report.

Then STOP.

Do not implement the next MK phase until explicitly instructed.

PHASE TO IMPLEMENT

MK-8 — Kit-Aware AI Recommendation Backend

OBJECTIVE
Create an isolated secure AI pipeline that selects the best look only from products the authenticated user owns.

ARCHITECTURE
Prefer a dedicated operation such as `generate-kit-makeup-recommendation`. Do not alter the standard recommendation operation.

SERVER FLOW
authenticate → validate analysis ownership/style → load authenticated user's kit → structured Gemini request → structured result → server validate every selected product → persist validated kit recommendation → safe response.

AI INPUT/OUTPUT
Use relevant face attributes, style, product IDs/categories/colors/finishes/foundation metadata. Require strict structured output referencing real supplied product IDs.

ANTI-HALLUCINATION
Validate ID, ownership, category, stored color, and finish. Reject/repair safely. Never persist/display invented ownership.

SECURITY
Authenticated Edge Function, server-side ownership checks, server-only Gemini key, safe logs/errors.

PROMPT VERSIONING
Create a separate versioned My Makeup Kit prompt. Never mutate the standard recommendation prompt.

ERRORS
Handle empty kit, stale analysis, invalid style, timeout, 429/5xx, malformed JSON, fabricated ID, unsupported category, quota failure, expired session, and product deletion during request.

TESTS
Mock AI responses, including hallucinated/malicious IDs. Do not use paid Gemini calls for ordinary automated tests.

DEPLOYMENT
Do not claim deployment unless actually performed; otherwise report exact manual action.

COMPLETION REPORT
PHASE COMPLETED:
NEW EDGE FUNCTION / OPERATION:
STANDARD RECOMMENDATION ENDPOINT MODIFIED:
PROMPT VERSION:
STRUCTURED OUTPUT:
OWNED-PRODUCT VALIDATION:
DATABASE CHANGES:
FILES CREATED:
FILES MODIFIED:
TESTS / VALIDATION:
DEPLOYMENT STATUS:
MANUAL ACTION REQUIRED:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE: MK-9 — Owned-Product Validation & Incomplete Kits

Then STOP.
```

---

# MK-9 — Owned-Product Validation & Incomplete Kits

```text
GIT SAFETY CHECK — MANDATORY

Before modifying any file:

1. Run:
   git status
   git branch --show-current

2. Confirm the active branch is exactly:
   feature/my-makeup-kit

3. If the active branch is NOT feature/my-makeup-kit:
   STOP immediately and report the active branch.
   Do not modify any files.

PROTECTED BASELINE

The main branch is the protected Phase 22 baseline.

Do NOT:

- develop on main
- commit My Makeup Kit changes to main
- merge into main
- force-push
- reset or rewrite main
- delete branches
- discard existing work without my explicit approval

SOURCE OF TRUTH

Before implementation, read completely:

1. CODEX_MASTER_GUIDE.md
2. FACETUNE_MY_MAKEUP_KIT_GUIDE.md
3. The requested MK phase in FACETUNE_MY_MAKEUP_KIT_ROADMAP.md

Inspect the CURRENT repository before implementation.
Do not assume previous work exists unless it is actually present.

The existing Makeup Recommendation flow is FROZEN.
My Makeup Kit must remain additive and isolated.

Implement ONLY the requested MK phase.

Run all validation required by that phase.

Do not hide or suppress genuine errors.
Do not fabricate successful tests, builds, migrations, deployments, or device results.

Provide the required completion report.

Then STOP.

Do not implement the next MK phase until explicitly instructed.

PHASE TO IMPLEMENT

MK-9 — Owned-Product Validation & Incomplete Kits

OBJECTIVE
Make kit recommendations truthful and useful even with incomplete collections.

CORE RULE
Incomplete kits are valid. Never invent missing products.

IMPLEMENT
Handle no foundation/concealer/blush/highlighter, missing eye/lip products, one-category kits, and arbitrary partial combinations.

Distinguish selected owned products, unavailable categories, and categories not required for the look.

Do not block merely because the kit is incomplete.
Do not silently fall back to standard mode.
Do not introduce non-owned products.

CONCURRENCY
Handle products edited/deleted between recommendation creation and later use.

TEST MATRIX
Empty kit, one product, multiple products in one category, partial kits, reasonably complete kit, deleted product, fabricated AI selection, malformed AI response. Run standard-mode regression too.

COMPLETION REPORT
PHASE COMPLETED:
INCOMPLETE KIT BEHAVIOR:
ANTI-HALLUCINATION:
CONCURRENT PRODUCT CHANGE:
FILES CREATED:
FILES MODIFIED:
TEST MATRIX:
STANDARD MODE REGRESSION:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE: MK-10 — Kit-Based AI Preview Integration

Then STOP.
```

---

# MK-10 — Kit-Based AI Preview Integration

```text
GIT SAFETY CHECK — MANDATORY

Before modifying any file:

1. Run:
   git status
   git branch --show-current

2. Confirm the active branch is exactly:
   feature/my-makeup-kit

3. If the active branch is NOT feature/my-makeup-kit:
   STOP immediately and report the active branch.
   Do not modify any files.

PROTECTED BASELINE

The main branch is the protected Phase 22 baseline.

Do NOT:

- develop on main
- commit My Makeup Kit changes to main
- merge into main
- force-push
- reset or rewrite main
- delete branches
- discard existing work without my explicit approval

SOURCE OF TRUTH

Before implementation, read completely:

1. CODEX_MASTER_GUIDE.md
2. FACETUNE_MY_MAKEUP_KIT_GUIDE.md
3. The requested MK phase in FACETUNE_MY_MAKEUP_KIT_ROADMAP.md

Inspect the CURRENT repository before implementation.
Do not assume previous work exists unless it is actually present.

The existing Makeup Recommendation flow is FROZEN.
My Makeup Kit must remain additive and isolated.

Implement ONLY the requested MK phase.

Run all validation required by that phase.

Do not hide or suppress genuine errors.
Do not fabricate successful tests, builds, migrations, deployments, or device results.

Provide the required completion report.

Then STOP.

Do not implement the next MK phase until explicitly instructed.

PHASE TO IMPLEMENT

MK-10 — Kit-Based AI Preview Integration

OBJECTIVE
Generate a visual preview from a validated kit recommendation without changing standard preview behavior.

AUDIT FIRST
Inspect the working preview pipeline and use the smallest backward-compatible integration point. Avoid broad refactoring.

KIT PREVIEW
Feed a normalized validated kit plan into preview generation. Respect actual owned-product colors, visually relevant finishes, placement/intensity, identity-preservation rules, and original-selfie integrity.

Do not substitute unrelated shades and present them as registered products.

PERSISTENCE
Distinguish kit vs standard preview records where needed, preserve history, never overwrite original selfie.

RESILIENCE
Reuse proven timeout, duplicate-request, retry, cancellation, timing, and storage protections. Handle stale/deleted products.

MANDATORY REGRESSION
Run standard Makeup Recommendation → Preview.

REQUIRED VALIDATION
- Edge Function tests if changed
- dart format .
- flutter analyze
- relevant flutter test
- configured Android debug build
- real generation only if deployment/device/API actually available

COMPLETION REPORT
PHASE COMPLETED:
KIT PREVIEW ARCHITECTURE:
STANDARD PREVIEW MODIFIED:
IDENTITY PROTECTION:
COLOR / FINISH HANDLING:
DATABASE / STORAGE CHANGES:
FILES CREATED:
FILES MODIFIED:
TESTS / VALIDATION:
REAL DEVICE / API TEST:
STANDARD PREVIEW REGRESSION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE: MK-11 — Results, Saved Looks & History Compatibility

Then STOP.
```

---

# MK-11 — Results, Saved Looks & History Compatibility

```text
GIT SAFETY CHECK — MANDATORY

Before modifying any file:

1. Run:
   git status
   git branch --show-current

2. Confirm the active branch is exactly:
   feature/my-makeup-kit

3. If the active branch is NOT feature/my-makeup-kit:
   STOP immediately and report the active branch.
   Do not modify any files.

PROTECTED BASELINE

The main branch is the protected Phase 22 baseline.

Do NOT:

- develop on main
- commit My Makeup Kit changes to main
- merge into main
- force-push
- reset or rewrite main
- delete branches
- discard existing work without my explicit approval

SOURCE OF TRUTH

Before implementation, read completely:

1. CODEX_MASTER_GUIDE.md
2. FACETUNE_MY_MAKEUP_KIT_GUIDE.md
3. The requested MK phase in FACETUNE_MY_MAKEUP_KIT_ROADMAP.md

Inspect the CURRENT repository before implementation.
Do not assume previous work exists unless it is actually present.

The existing Makeup Recommendation flow is FROZEN.
My Makeup Kit must remain additive and isolated.

Implement ONLY the requested MK phase.

Run all validation required by that phase.

Do not hide or suppress genuine errors.
Do not fabricate successful tests, builds, migrations, deployments, or device results.

Provide the required completion report.

Then STOP.

Do not implement the next MK phase until explicitly instructed.

PHASE TO IMPLEMENT

MK-11 — Results, Saved Looks & History Compatibility

OBJECTIVE
Make kit looks first-class FaceTune results while preserving standard-result compatibility.

RESULTS
Clearly identify kit-based results and show owned-product category, optional name, swatch/color, finish, and relevant foundation metadata. Never imply ownership of unregistered products.

SAVED LOOKS / HISTORY
Support save/reopen. Use a safe snapshot/reference strategy so old results remain understandable after products are edited/deleted.

Preserve existing standard records/navigation.

CLEANUP
Follow existing linked-record/storage cleanup conventions and avoid orphaned data.

TEST
Save/reopen kit look; edit/delete product after saving; reopen historical kit result; existing standard saved look/history.

COMPLETION REPORT
PHASE COMPLETED:
RESULTS UI:
SAVED LOOKS:
HISTORY:
SNAPSHOT / REFERENCE STRATEGY:
DATABASE CHANGES:
FILES CREATED:
FILES MODIFIED:
TESTS / VALIDATION:
BACKWARD COMPATIBILITY:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE: MK-12 — Loading, Errors, Offline, Security & Performance

Then STOP.
```

---

# MK-12 — Loading, Errors, Offline, Security & Performance

```text
GIT SAFETY CHECK — MANDATORY

Before modifying any file:

1. Run:
   git status
   git branch --show-current

2. Confirm the active branch is exactly:
   feature/my-makeup-kit

3. If the active branch is NOT feature/my-makeup-kit:
   STOP immediately and report the active branch.
   Do not modify any files.

PROTECTED BASELINE

The main branch is the protected Phase 22 baseline.

Do NOT:

- develop on main
- commit My Makeup Kit changes to main
- merge into main
- force-push
- reset or rewrite main
- delete branches
- discard existing work without my explicit approval

SOURCE OF TRUTH

Before implementation, read completely:

1. CODEX_MASTER_GUIDE.md
2. FACETUNE_MY_MAKEUP_KIT_GUIDE.md
3. The requested MK phase in FACETUNE_MY_MAKEUP_KIT_ROADMAP.md

Inspect the CURRENT repository before implementation.
Do not assume previous work exists unless it is actually present.

The existing Makeup Recommendation flow is FROZEN.
My Makeup Kit must remain additive and isolated.

Implement ONLY the requested MK phase.

Run all validation required by that phase.

Do not hide or suppress genuine errors.
Do not fabricate successful tests, builds, migrations, deployments, or device results.

Provide the required completion report.

Then STOP.

Do not implement the next MK phase until explicitly instructed.

PHASE TO IMPLEMENT

MK-12 — Loading, Errors, Offline, Security & Performance

OBJECTIVE
Harden the complete feature for real-world use.

AUDIT
Loading/skeletons/empty states, offline/retry/timeouts, session expiry, stale async completion, duplicate submissions, mutation races, Supabase failures, malformed data, Gemini failures/output, hallucinated references, quotas, preview/storage failures, cancellation, and cross-account leakage.

SECURITY
Verify RLS isolation, no user-ID spoofing, no cross-account visibility, Edge Function auth, server ownership validation, no client Gemini secrets, safe logging, and logout state clearing.

PERFORMANCE
Audit duplicate loads, unnecessary DB/AI calls, Riverpod rebuilds, large inventory rendering, color picker rendering, caching/invalidation. Optimize only measured or obvious issues.

REQUIRED VALIDATION
- security tests
- repository/controller tests
- backend tests
- dart format .
- flutter analyze
- flutter test
- configured Android debug build

COMPLETION REPORT
PHASE COMPLETED:
RECOVERY AUDIT:
OFFLINE BEHAVIOR:
SECURITY AUDIT:
RLS:
CROSS-ACCOUNT TEST:
AI FAILURE HANDLING:
PERFORMANCE CHANGES:
FILES CREATED:
FILES MODIFIED:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE: MK-13 — End-to-End QA & Regression

Then STOP.
```

---

# MK-13 — End-to-End QA & Regression

```text
GIT SAFETY CHECK — MANDATORY

Before modifying any file:

1. Run:
   git status
   git branch --show-current

2. Confirm the active branch is exactly:
   feature/my-makeup-kit

3. If the active branch is NOT feature/my-makeup-kit:
   STOP immediately and report the active branch.
   Do not modify any files.

PROTECTED BASELINE

The main branch is the protected Phase 22 baseline.

Do NOT:

- develop on main
- commit My Makeup Kit changes to main
- merge into main
- force-push
- reset or rewrite main
- delete branches
- discard existing work without my explicit approval

SOURCE OF TRUTH

Before implementation, read completely:

1. CODEX_MASTER_GUIDE.md
2. FACETUNE_MY_MAKEUP_KIT_GUIDE.md
3. The requested MK phase in FACETUNE_MY_MAKEUP_KIT_ROADMAP.md

Inspect the CURRENT repository before implementation.
Do not assume previous work exists unless it is actually present.

The existing Makeup Recommendation flow is FROZEN.
My Makeup Kit must remain additive and isolated.

Implement ONLY the requested MK phase.

Run all validation required by that phase.

Do not hide or suppress genuine errors.
Do not fabricate successful tests, builds, migrations, deployments, or device results.

Provide the required completion report.

Then STOP.

Do not implement the next MK phase until explicitly instructed.

PHASE TO IMPLEMENT

MK-13 — End-to-End QA & Regression

OBJECTIVE
Validate My Makeup Kit end-to-end and prove the original recommendation experience remains intact.

KIT E2E
Sign in → My Makeup Kit → add Foundation/multiple Lipsticks/Blush/Eyeshadow → edit/delete → Scan → Analysis → Style → My Makeup Kit → Kit Recommendation → validate owned products → Preview → Save → History → Reopen.

ADDITIONAL
Test empty/incomplete/one-product/larger kits, invalid data, offline, timeout, malformed Gemini output, fabricated ID, session expiry, account switching, background/resume, back/cancel, and product changes during flow.

MANDATORY ORIGINAL REGRESSION
Selfie → Face Analysis → Style → Makeup Recommendation → AI Preview → Results → Save → History.

DEVICE
Prioritize configured Android device/target when available. Never fabricate device/live API testing.

REQUIRED VALIDATION
- dart format .
- flutter analyze
- complete relevant flutter test
- configured Android debug build
- backend tests
- deployment/version verification where applicable
- manual device checklist where available

COMPLETION REPORT
PHASE COMPLETED:
MY MAKEUP KIT E2E:
ORIGINAL MAKEUP RECOMMENDATION E2E:
EMPTY KIT:
INCOMPLETE KIT:
MULTI-PRODUCT KIT:
CROSS-ACCOUNT:
AI ANTI-HALLUCINATION:
PREVIEW:
SAVED LOOKS:
HISTORY:
FLUTTER ANALYZE:
FLUTTER TEST:
ANDROID BUILD:
BACKEND TESTS:
DEVICE TEST:
BLOCKERS:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE: MK-14 — Final UI/UX Polish & Feature Completion

Then STOP.
```

---

# MK-14 — Final UI/UX Polish & Feature Completion

```text
GIT SAFETY CHECK — MANDATORY

Before modifying any file:

1. Run:
   git status
   git branch --show-current

2. Confirm the active branch is exactly:
   feature/my-makeup-kit

3. If the active branch is NOT feature/my-makeup-kit:
   STOP immediately and report the active branch.
   Do not modify any files.

PROTECTED BASELINE

The main branch is the protected Phase 22 baseline.

Do NOT:

- develop on main
- commit My Makeup Kit changes to main
- merge into main
- force-push
- reset or rewrite main
- delete branches
- discard existing work without my explicit approval

SOURCE OF TRUTH

Before implementation, read completely:

1. CODEX_MASTER_GUIDE.md
2. FACETUNE_MY_MAKEUP_KIT_GUIDE.md
3. The requested MK phase in FACETUNE_MY_MAKEUP_KIT_ROADMAP.md

Inspect the CURRENT repository before implementation.
Do not assume previous work exists unless it is actually present.

The existing Makeup Recommendation flow is FROZEN.
My Makeup Kit must remain additive and isolated.

Implement ONLY the requested MK phase.

Run all validation required by that phase.

Do not hide or suppress genuine errors.
Do not fabricate successful tests, builds, migrations, deployments, or device results.

Provide the required completion report.

Then STOP.

Do not implement the next MK phase until explicitly instructed.

PHASE TO IMPLEMENT

MK-14 — Final UI/UX Polish & Feature Completion

OBJECTIVE
Finish My Makeup Kit as a coherent, premium, documented FaceTune feature.

VISUAL AUDIT
Review feature entry, kit overview/categories, product cards/swatches, Add Product, category forms, visual color picker, finishes, foundation attributes, edit/delete, mode selector, empty/incomplete states, recommendation, preview/results, and loading/error/recovery states.

UX AUDIT
Users should not need HEX knowledge; forms expose only relevant fields; optional/destructive actions are clear; empty/incomplete kits have paths; mode selection is understandable; standard mode remains easy; no developer placeholders remain.

DOCUMENTATION
Update architecture, schema/RLS, AI contract, prompt version, deployment requirements, known limitations, maintenance, and regression protection.

FINAL DEFINITION OF DONE
Private inventory, multi-product categories, visual colors, finishes, foundation metadata, CRUD, incomplete kits, explicit mode, owned-product-only AI, anti-hallucination, kit preview, Saved/History, security/RLS, and validation all work while original Makeup Recommendation remains unchanged.

REQUIRED VALIDATION
- dart format .
- flutter analyze
- complete relevant flutter test
- configured Android debug build
- relevant Edge Function/backend tests
- final manual checklist where available

COMPLETION REPORT
FEATURE COMPLETED: My Makeup Kit
PHASE COMPLETED:
FEATURE STATUS:
DATABASE / RLS:
PRODUCT CRUD:
COLOR PICKER:
CATEGORY / FINISH VALIDATION:
MODE SELECTOR:
KIT AI RECOMMENDATION:
ANTI-HALLUCINATION:
KIT PREVIEW:
SAVED LOOKS / HISTORY:
SECURITY:
PERFORMANCE:
ORIGINAL MAKEUP RECOMMENDATION REGRESSION:
FLUTTER ANALYZE:
FLUTTER TEST:
ANDROID BUILD:
EDGE FUNCTION TESTS:
MANUAL ACTION REQUIRED:
KNOWN LIMITATIONS:
DOCUMENTATION UPDATED:
NEXT RECOMMENDED ACTION:
Return to broader FaceTune feature expansion or resume the original roadmap only when explicitly instructed.

Then STOP.
```

---
