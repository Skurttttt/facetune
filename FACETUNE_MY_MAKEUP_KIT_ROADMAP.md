# FaceTune — My Makeup Kit Implementation Roadmap

**File:** `FACETUNE_MY_MAKEUP_KIT_ROADMAP.md`  
**Feature specification:** `FACETUNE_MY_MAKEUP_KIT_GUIDE.md`  
**Parent system guide:** `CODEX_MASTER_GUIDE.md`  
**Original roadmap:** `FACETUNE_CODEX_PHASES_1_TO_26.md`  
**Intended agents:** OpenAI Codex and Claude Code Pro

---

# EXECUTION RULE

This file contains the **implementation phases and copy/paste prompts** for My Makeup Kit.

For every phase:

1. Read `CODEX_MASTER_GUIDE.md` completely.
2. Read `FACETUNE_MY_MAKEUP_KIT_GUIDE.md` completely.
3. Inspect the current repository and Git state.
4. Implement only the requested phase.
5. Preserve the frozen Makeup Recommendation behavior.
6. Run the required validation.
7. Fix issues introduced by the phase.
8. Give the required completion report.
9. STOP.

Never automatically continue into the next phase.

---

# PHASE SUMMARY

| Phase | Name |
| --- | --- |
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

---

# MK-1 — Baseline & Architecture Contract

```text
Read CODEX_MASTER_GUIDE.md completely first.

Then read FACETUNE_MY_MAKEUP_KIT_GUIDE.md completely.

Inspect the CURRENT repository and Git state before making changes.

Implement ONLY:

MK-1 — Baseline & Architecture Contract

OBJECTIVE

Establish the technical boundary for My Makeup Kit before adding database
tables, CRUD UI, or AI functionality.

The existing Makeup Recommendation flow is FROZEN and is the protected
baseline. My Makeup Kit must remain additive and isolated.

AUDIT

Inspect the current implementation of:

- feature-first folder structure
- authentication/session state
- face analysis
- style selection
- Makeup Recommendation
- recommendation models/contracts
- preview generation
- Saved Looks
- History
- routing/navigation
- Supabase migrations
- RLS conventions
- Edge Function conventions
- Riverpod/controller conventions
- error/recovery abstractions
- tests

Do not assume architecture from documentation if the current repository differs.
The current valid repository is authoritative.

IMPLEMENT

Create only the minimum architecture/scaffolding justified for My Makeup Kit.

Establish typed contracts for:

- makeup product category
- category-specific finish
- foundation depth
- foundation undertone
- normalized HEX color

Define/document the isolated feature boundary.

Conceptually preserve:

Standard Makeup Recommendation
→ existing implementation

My Makeup Kit
→ new isolated implementation

Identify the smallest safe downstream convergence point for preview/results.

Do NOT:

- create the database schema yet
- implement product CRUD
- call Gemini
- implement kit recommendation
- implement kit preview
- rewrite existing recommendation architecture for abstraction purity

TESTS

Add focused unit tests for:

- supported categories
- allowed finishes per category
- invalid category/finish combinations
- HEX validation and normalization
- foundation depth
- foundation undertone

DONE WHEN

- My Makeup Kit has a clear architectural home.
- Core values/contracts are typed.
- Existing Makeup Recommendation behavior is unchanged.
- Integration boundaries are documented.
- No unnecessary functionality was implemented.

REQUIRED VALIDATION

Run:
- dart format .
- flutter analyze
- relevant flutter test tests
- flutter build apk --debug with the project's required development
  configuration if application code changed materially

Do not suppress genuine errors to make validation green.

COMPLETION REPORT

PHASE COMPLETED:
MK-1 — Baseline & Architecture Contract

EXISTING MAKEUP RECOMMENDATION MODIFIED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
ARCHITECTURE DECISIONS:
TESTS / VALIDATION:
REGRESSION CHECK:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
MK-2 — Supabase Schema & RLS

Then STOP.

Do not implement MK-2 until explicitly instructed.
```

---

# MK-2 — Supabase Schema & RLS

```text
Read CODEX_MASTER_GUIDE.md and FACETUNE_MY_MAKEUP_KIT_GUIDE.md completely.

Inspect the current database migrations and repository state.

Implement ONLY:

MK-2 — Supabase Schema & RLS

OBJECTIVE

Create secure persistent storage for each authenticated user's private makeup
inventory.

DESIGN

Follow the project's existing migration, UUID, timestamp, foreign-key, index,
ownership, and RLS conventions.

Create a simple scalable schema for My Makeup Kit.

A likely core table is conceptually:

makeup_kit_products

Support the fields required by FACETUNE_MY_MAKEUP_KIT_GUIDE.md, including:

- product ID
- owner/user ID
- category
- optional product name
- normalized color HEX
- optional color/shade label where justified
- finish
- foundation depth where applicable
- foundation undertone where applicable
- created_at
- updated_at

Use exact column names/types consistent with the existing project.

DATABASE INTEGRITY

Add appropriate:

- primary keys
- foreign keys
- indexes
- category constraints
- finish constraints where practical
- HEX validation where practical
- ownership protection

Avoid overly brittle SQL for category-specific validation if the same rule is
better enforced in typed application/domain validation.

RLS

Authenticated users must only be able to:

- SELECT their own kit products
- INSERT their own kit products
- UPDATE their own kit products
- DELETE their own kit products

Prevent user-ID spoofing.

Do not weaken existing RLS.

Do not alter existing recommendation tables merely to support this feature.

Do not create destructive migrations.

TEST / VERIFY

Where supported, verify:

- user A cannot read user B's kit
- user A cannot update user B's kit
- user A cannot delete user B's kit
- invalid ownership insertion fails
- valid own-product operations succeed

Do not claim remote migration success unless it was actually applied.

REQUIRED VALIDATION

Validate migration syntax and database tests according to project conventions.

If remote deployment is not performed, clearly report the manual command/action
required.

COMPLETION REPORT

PHASE COMPLETED:
MK-2 — Supabase Schema & RLS

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
NEXT RECOMMENDED PHASE:
MK-3 — Domain, Repository & State Foundation

Then STOP.
```

---

# MK-3 — Domain, Repository & State Foundation

```text
Read CODEX_MASTER_GUIDE.md and FACETUNE_MY_MAKEUP_KIT_GUIDE.md completely.

Implement ONLY:

MK-3 — Domain, Repository & State Foundation

OBJECTIVE

Build the typed Flutter data/domain/state foundation for My Makeup Kit.

IMPLEMENT

Following the existing Clean Architecture / feature conventions, implement the
appropriate equivalents of:

- MakeupKitProduct domain entity
- database DTO/model
- mapper
- repository interface
- Supabase repository implementation
- data source if consistent with the current architecture
- CRUD use cases where the project uses use-case classes
- Riverpod providers
- controller/notifier and explicit UI state

Support:

- load all user's products
- load/filter by category
- create product
- update product
- delete product

VALIDATION

Validate:

- category
- finish/category compatibility
- normalized HEX
- category-specific fields
- foundation depth/undertone

Never trust raw database strings blindly.

Map backend exceptions into safe application failures.

Do not expose raw Supabase/PostgREST diagnostics to UI state.

Do not implement the full UI yet.

Do not implement Gemini kit recommendation yet.

TESTS

Add focused tests for:

- model/DTO mapping
- repository operations
- controller state transitions
- validation failures
- backend failure mapping

REQUIRED VALIDATION

Run:
- dart format .
- flutter analyze
- relevant flutter test
- configured debug Android build if appropriate

COMPLETION REPORT

PHASE COMPLETED:
MK-3 — Domain, Repository & State Foundation

FILES CREATED:
FILES MODIFIED:
DOMAIN MODELS:
REPOSITORY:
RIVERPOD / STATE:
VALIDATION:
TESTS / VALIDATION:
REGRESSION CHECK:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
MK-4 — Kit Overview & Category UX

Then STOP.
```

---

# MK-4 — Kit Overview & Category UX

```text
Read CODEX_MASTER_GUIDE.md and FACETUNE_MY_MAKEUP_KIT_GUIDE.md completely.

Implement ONLY:

MK-4 — Kit Overview & Category UX

OBJECTIVE

Create the premium My Makeup Kit inventory browsing experience.

NAVIGATION

Inspect the existing Home/Profile/navigation hierarchy and add an appropriate
entry point without cluttering or changing the standard recommendation flow.

IMPLEMENT

Build:

- My Makeup Kit overview screen
- supported category presentation
- product counts where useful
- product cards/list items
- color swatches
- finish labels
- multiple products per category
- empty kit state
- empty category state
- loading/skeleton state
- error/retry state
- Add Product CTA

VISUAL REQUIREMENTS

Match FaceTune:

- premium beauty
- modern/minimal
- soft feminine
- Material 3
- existing typography
- existing spacing/radii
- accessible contrast
- responsive Android layout

Do not create a visually disconnected mini-app.

Do not implement recommendation mode or Gemini logic yet.

TESTS

Cover key loading, empty, populated, and error states where practical.

REQUIRED VALIDATION

Run:
- dart format .
- flutter analyze
- relevant flutter test
- configured Android debug build

COMPLETION REPORT

PHASE COMPLETED:
MK-4 — Kit Overview & Category UX

FILES CREATED:
FILES MODIFIED:
SCREENS / COMPONENTS:
NAVIGATION:
STATE INTEGRATION:
TESTS / VALIDATION:
ANDROID BUILD:
REGRESSION CHECK:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
MK-5 — Add Product & Visual Color Picker

Then STOP.
```

---

# MK-5 — Add Product & Visual Color Picker

```text
Read CODEX_MASTER_GUIDE.md and FACETUNE_MY_MAKEUP_KIT_GUIDE.md completely.

Implement ONLY:

MK-5 — Add Product & Visual Color Picker

OBJECTIVE

Allow users to register makeup products they actually own.

FLOW

My Makeup Kit
→ Add Product
→ Select Category
→ Category-specific form
→ Select Shade/Color
→ Select Finish
→ Enter relevant additional attributes
→ Validate
→ Save
→ Return to updated kit

COLOR UX

Implement a user-friendly visual color picker.

Requirements:

- visual color/shade selection
- selected-color preview
- normalized HEX persistence
- optional advanced/reference HEX display or entry if appropriate
- invalid HEX cannot be saved
- ordinary users are not required to understand HEX

Do NOT implement camera-based physical shade detection.

CATEGORY-SPECIFIC FORM

The form must adapt to the selected category.

Use the finish catalog from FACETUNE_MY_MAKEUP_KIT_GUIDE.md.

Foundation additionally supports:

- depth: Fair / Light / Medium / Tan / Deep
- undertone: Cool / Neutral / Warm

Do not show irrelevant fields.

Product name is optional.

Brand is not required.

SAVE BEHAVIOR

Implement:

- client/domain validation
- explicit loading
- duplicate-submit protection
- success feedback
- safe error recovery
- preservation of entered values after recoverable failure

TESTS

Test representative categories, especially:

- Foundation
- Lipstick
- Eyeshadow
- Blush
- Eyeliner

Test invalid finish/category combinations and invalid colors.

REQUIRED VALIDATION

Run:
- dart format .
- flutter analyze
- relevant flutter test
- configured Android debug build
- manual add-product smoke test if device/backend is available

COMPLETION REPORT

PHASE COMPLETED:
MK-5 — Add Product & Visual Color Picker

FILES CREATED:
FILES MODIFIED:
COLOR PICKER:
CATEGORY-SPECIFIC FORMS:
VALIDATION:
DATABASE OPERATIONS:
TESTS / VALIDATION:
ANDROID BUILD:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
MK-6 — Edit, Delete & Inventory Management

Then STOP.
```

---

# MK-6 — Edit, Delete & Inventory Management

```text
Read CODEX_MASTER_GUIDE.md and FACETUNE_MY_MAKEUP_KIT_GUIDE.md completely.

Implement ONLY:

MK-6 — Edit, Delete & Inventory Management

OBJECTIVE

Allow users to keep their digital kit synchronized with their real makeup
collection.

IMPLEMENT

Support:

- product details
- edit optional product name
- edit color/shade
- edit finish
- edit category-specific metadata
- delete product
- delete confirmation
- correct state refresh after mutations
- safe mutation failure recovery

If category changes are supported, incompatible old fields must be cleared or
revalidated.

Example:
Foundation depth/undertone must never survive as hidden stale metadata after
changing the product into Lipstick.

Maintain ownership/RLS boundaries.

Do not use optimistic updates unless rollback behavior is safe and consistent
with the existing architecture.

TESTS

Cover complete CRUD and category-change validation.

REQUIRED VALIDATION

Run:
- dart format .
- flutter analyze
- relevant flutter test
- configured Android build
- RLS regression where practical

COMPLETION REPORT

PHASE COMPLETED:
MK-6 — Edit, Delete & Inventory Management

FILES CREATED:
FILES MODIFIED:
CRUD STATUS:
CATEGORY CHANGE BEHAVIOR:
VALIDATION:
RLS / OWNERSHIP:
TESTS / VALIDATION:
ANDROID BUILD:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
MK-7 — Mode Selection Integration

Then STOP.
```

---

# MK-7 — Mode Selection Integration

```text
Read CODEX_MASTER_GUIDE.md and FACETUNE_MY_MAKEUP_KIT_GUIDE.md completely.

Implement ONLY:

MK-7 — Mode Selection Integration

OBJECTIVE

Allow users to explicitly choose:

1. Makeup Recommendation
2. My Makeup Kit

without changing the behavior of Makeup Recommendation.

UX

At the safest appropriate point in the current scan/style journey, add a clear
mutually exclusive mode selector.

Prefer explicit selectable cards or another accessible control if clearer than
a literal switch.

Concept:

HOW WOULD YOU LIKE TO CREATE YOUR LOOK?

[ Makeup Recommendation ]
Let FaceTune choose the ideal makeup for you.

[ My Makeup Kit ]
Create a look using makeup you already own.

CRITICAL STANDARD MODE RULE

Selecting Makeup Recommendation must route into the exact existing working
path.

Do not modify its:

- AI prompt
- endpoint
- model
- repository behavior
- response schema
- preview behavior

MY MAKEUP KIT ENTRY

When My Makeup Kit is selected:

- verify the user has at least one valid kit product
- if empty, show intentional empty-kit UX
- offer Add Product
- allow the user to return to standard Makeup Recommendation
- preserve current scan/style state where safely possible

STATE

Represent recommendation mode explicitly and type-safely.

REGRESSION TEST

Mandatory:
prove the standard Makeup Recommendation route still behaves as before.

REQUIRED VALIDATION

Run:
- dart format .
- flutter analyze
- relevant flutter test
- configured Android build
- standard-mode regression test
- manual smoke test where available

COMPLETION REPORT

PHASE COMPLETED:
MK-7 — Mode Selection Integration

MODE SELECTOR:
STANDARD MODE MODIFIED:
MY MAKEUP KIT ENTRY:
EMPTY KIT UX:
FILES CREATED:
FILES MODIFIED:
TESTS / VALIDATION:
ORIGINAL MAKEUP RECOMMENDATION REGRESSION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
MK-8 — Kit-Aware AI Recommendation Backend

Then STOP.
```

---

# MK-8 — Kit-Aware AI Recommendation Backend

```text
Read CODEX_MASTER_GUIDE.md and FACETUNE_MY_MAKEUP_KIT_GUIDE.md completely.

Implement ONLY:

MK-8 — Kit-Aware AI Recommendation Backend

OBJECTIVE

Create a secure isolated AI pipeline that selects the best makeup look from
products the authenticated user actually owns.

ARCHITECTURE

Prefer a dedicated secure operation such as:

generate-kit-makeup-recommendation

Do NOT alter the behavior of the existing generate-makeup-recommendation
operation.

Conceptual server flow:

authenticate
→ validate analysis ownership
→ validate selected style
→ load authenticated user's kit
→ construct structured Gemini request
→ receive structured result
→ validate every selected product against server-loaded inventory
→ persist validated kit recommendation
→ return safe structured response

AI INPUT

Use relevant:

- face attributes
- selected style
- product IDs
- product categories
- shade/color
- finish
- foundation metadata where applicable

AI OUTPUT

Use a strict structured schema.

Every selected makeup item must reference a real supplied product ID.

The AI must not be treated as authoritative about inventory.

ANTI-HALLUCINATION

After model response:

- parse safely
- validate every product ID
- validate ownership
- validate category
- validate stored color
- validate stored finish
- reject/repair safely when output is fabricated or inconsistent

Never persist or display invented ownership.

SECURITY

- authenticated Edge Function
- server-side ownership validation
- Gemini key server-side only
- no arbitrary client-owned product claims
- safe logs
- safe user-facing failures

PROMPT VERSIONING

Create a separate versioned My Makeup Kit prompt.

Do not mutate the standard recommendation prompt.

ERRORS

Handle:

- empty kit
- invalid/stale analysis
- invalid style
- AI timeout
- 429 / transient 5xx
- malformed JSON
- fabricated product ID
- unsupported category
- quota failure
- expired session
- product deleted during request

TESTS

Use mocked AI responses.

Include malicious/hallucinated product-ID tests.

Do not use real paid Gemini calls for ordinary automated tests.

DEPLOYMENT

Do not claim the Edge Function is deployed unless actually deployed.

If deployment changes live infrastructure and was not explicitly authorized,
report the exact manual deployment command.

REQUIRED VALIDATION

Run all relevant:
- Deno/Edge Function tests
- type/lint checks according to project conventions
- Flutter contract tests if changed
- dart format .
- flutter analyze
- relevant flutter test

COMPLETION REPORT

PHASE COMPLETED:
MK-8 — Kit-Aware AI Recommendation Backend

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
NEXT RECOMMENDED PHASE:
MK-9 — Owned-Product Validation & Incomplete Kits

Then STOP.
```

---

# MK-9 — Owned-Product Validation & Incomplete Kits

```text
Read CODEX_MASTER_GUIDE.md and FACETUNE_MY_MAKEUP_KIT_GUIDE.md completely.

Implement ONLY:

MK-9 — Owned-Product Validation & Incomplete Kits

OBJECTIVE

Make kit recommendations useful and truthful even when the user's makeup
collection is incomplete.

CORE RULE

Incomplete kits are valid.

Never invent missing products.

IMPLEMENT INTENTIONAL BEHAVIOR FOR

- no foundation
- no concealer
- no blush
- no highlighter
- missing eye products
- missing lip products
- one-category kits
- arbitrary partial combinations

The recommendation/result contract should distinguish:

- selected products the user actually owns
- unavailable categories
- categories not required for the chosen look

UX

Explain what can be achieved with the user's available kit.

Do not block users merely because the kit is incomplete.

If the selected style cannot be faithfully achieved, communicate that clearly.

Do not silently fall back to standard Makeup Recommendation.

Do not silently introduce non-owned products.

CONCURRENCY

Handle a product being deleted/edited between recommendation creation and later
use.

Revalidate inventory references where required.

TEST MATRIX

Include:

- empty kit
- one product
- one category with multiple products
- several partial categories
- reasonably complete kit
- product deleted during flow
- fabricated AI selection
- malformed AI response

Also run standard Makeup Recommendation regression tests.

REQUIRED VALIDATION

Run all relevant formatting, analyzer, tests, backend tests, and configured
Android build.

COMPLETION REPORT

PHASE COMPLETED:
MK-9 — Owned-Product Validation & Incomplete Kits

INCOMPLETE KIT BEHAVIOR:
ANTI-HALLUCINATION:
CONCURRENT PRODUCT CHANGE:
FILES CREATED:
FILES MODIFIED:
TEST MATRIX:
STANDARD MODE REGRESSION:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
MK-10 — Kit-Based AI Preview Integration

Then STOP.
```

---

# MK-10 — Kit-Based AI Preview Integration

```text
Read CODEX_MASTER_GUIDE.md and FACETUNE_MY_MAKEUP_KIT_GUIDE.md completely.

Implement ONLY:

MK-10 — Kit-Based AI Preview Integration

OBJECTIVE

Generate a visual makeup preview from a validated My Makeup Kit recommendation
without changing standard preview behavior.

AUDIT FIRST

Inspect the current working preview pipeline.

Identify the smallest backward-compatible integration point.

Do not broadly refactor the standard preview system.

KIT PREVIEW

Feed a normalized validated kit makeup plan into the preview generation path.

The preview instructions must respect:

- actual selected owned-product colors
- finishes where visually applicable
- placement/intensity
- current identity-preservation requirements
- original selfie integrity

Do not allow the model to substitute unrelated shades and then present them as
the user's registered products.

PERSISTENCE

Distinguish kit-based vs standard preview records where needed.

Preserve all historical records.

Never overwrite the original selfie.

RESILIENCE

Reuse proven:

- timeout handling
- duplicate-request protection
- retry policy
- cancellation safety
- timing instrumentation
- storage safety

without regressing the standard preview.

Handle stale/deleted selected products safely.

MANDATORY REGRESSION

Run the existing standard Makeup Recommendation → Preview flow.

REQUIRED VALIDATION

Run:
- Edge Function tests if changed
- dart format .
- flutter analyze
- relevant flutter test
- configured Android debug build
- real generation only when deployment/device/API are actually available

Never fabricate a live generation result.

COMPLETION REPORT

PHASE COMPLETED:
MK-10 — Kit-Based AI Preview Integration

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
NEXT RECOMMENDED PHASE:
MK-11 — Results, Saved Looks & History Compatibility

Then STOP.
```

---

# MK-11 — Results, Saved Looks & History Compatibility

```text
Read CODEX_MASTER_GUIDE.md and FACETUNE_MY_MAKEUP_KIT_GUIDE.md completely.

Implement ONLY:

MK-11 — Results, Saved Looks & History Compatibility

OBJECTIVE

Make My Makeup Kit looks first-class FaceTune results while keeping all existing
standard results backward compatible.

RESULTS

Clearly identify kit-based results as created using My Makeup Kit.

Show selected owned products appropriately:

- category
- custom product name when present
- color swatch
- shade/color
- finish
- relevant foundation metadata

Never imply ownership of an unregistered product.

SAVED LOOKS / HISTORY

Support saving and reopening kit-based looks.

Design persistence so an old result remains understandable if a product is
later edited or deleted.

Use a safe snapshot/reference strategy.

Do not make historical meaning depend entirely on mutable current inventory.

Preserve existing standard records and navigation.

DELETION / CLEANUP

Follow existing linked-record and storage cleanup conventions.

Avoid orphaned data.

TEST

Cover:

- save kit look
- reopen kit look
- edit product after saving
- delete product after saving
- reopen historical kit result
- existing standard saved look
- existing standard history item

REQUIRED VALIDATION

Run all relevant formatting, analyzer, tests, database tests, Android build, and
standard regression checks.

COMPLETION REPORT

PHASE COMPLETED:
MK-11 — Results, Saved Looks & History Compatibility

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
NEXT RECOMMENDED PHASE:
MK-12 — Loading, Errors, Offline, Security & Performance

Then STOP.
```

---

# MK-12 — Loading, Errors, Offline, Security & Performance

```text
Read CODEX_MASTER_GUIDE.md and FACETUNE_MY_MAKEUP_KIT_GUIDE.md completely.

Implement ONLY:

MK-12 — Loading, Errors, Offline, Security & Performance

OBJECTIVE

Harden the complete My Makeup Kit feature for real-world use.

AUDIT EVERY KIT FLOW FOR

- loading
- skeletons
- empty states
- offline behavior
- retries
- timeouts
- session expiry
- stale async completions
- duplicate submissions
- product mutation races
- Supabase failures
- malformed database data
- Gemini failures
- malformed AI output
- AI hallucinated product references
- quota/rate limits
- preview failures
- storage failures
- navigation cancellation
- cross-account state leakage

SECURITY AUDIT

Verify:

- RLS isolation
- no user-ID spoofing
- no cross-account kit visibility
- Edge Function auth
- server-side product ownership validation
- Gemini secrets absent from client
- safe logging
- logout clears user-specific kit workflow state

PERFORMANCE

Audit:

- duplicate kit loads
- unnecessary database calls
- unnecessary AI calls
- Riverpod rebuilds
- large inventory rendering
- color picker rendering
- caching/invalidation

Optimize only measured or obvious inefficiencies.

Do not sacrifice correctness or standard-mode stability for speculative
micro-optimizations.

REQUIRED VALIDATION

Run:
- security tests
- repository/controller tests
- backend tests
- dart format .
- flutter analyze
- flutter test
- configured Android debug build

Document any manual Supabase security checks.

COMPLETION REPORT

PHASE COMPLETED:
MK-12 — Loading, Errors, Offline, Security & Performance

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
NEXT RECOMMENDED PHASE:
MK-13 — End-to-End QA & Regression

Then STOP.
```

---

# MK-13 — End-to-End QA & Regression

```text
Read CODEX_MASTER_GUIDE.md and FACETUNE_MY_MAKEUP_KIT_GUIDE.md completely.

Implement ONLY:

MK-13 — End-to-End QA & Regression

OBJECTIVE

Validate My Makeup Kit end to end and prove that the original FaceTune
recommendation experience remains intact.

MY MAKEUP KIT E2E

Test:

Sign in
→ Open My Makeup Kit
→ Add Foundation
→ Add multiple Lipsticks
→ Add Blush
→ Add Eyeshadow
→ Edit Product
→ Delete Product
→ Start Scan
→ Face Analysis
→ Select Style
→ Select My Makeup Kit
→ Generate Kit Recommendation
→ Validate Owned Products
→ Generate Preview
→ Save Look
→ Open History
→ Reopen Result

ADDITIONAL SCENARIOS

Test:

- empty kit
- incomplete kit
- one-product kit
- larger kit
- invalid product data
- offline transition
- timeout
- malformed Gemini output
- fabricated Gemini product ID
- session expiry
- logout/login as another account
- app background/resume
- back/cancel navigation
- product changed during recommendation flow

MANDATORY ORIGINAL-FLOW REGRESSION

Test:

Selfie
→ Face Analysis
→ Style
→ Makeup Recommendation
→ AI Preview
→ Results
→ Save
→ History

No behavioral change to the protected flow is acceptable without explicit
approval.

DEVICE

Prioritize the project's configured Android target/device when available.

Do not fabricate device or live API testing.

TEST QUALITY

Prefer meaningful unit/widget/integration coverage over brittle tests written
only to increase coverage numbers.

REQUIRED VALIDATION

Run:
- dart format .
- flutter analyze
- complete relevant flutter test
- configured Android debug build
- backend tests
- deployment/version verification where applicable
- manual device checklist when available

COMPLETION REPORT

PHASE COMPLETED:
MK-13 — End-to-End QA & Regression

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
NEXT RECOMMENDED PHASE:
MK-14 — Final UI/UX Polish & Feature Completion

Then STOP.
```

---

# MK-14 — Final UI/UX Polish & Feature Completion

```text
Read CODEX_MASTER_GUIDE.md and FACETUNE_MY_MAKEUP_KIT_GUIDE.md completely.

Implement ONLY:

MK-14 — Final UI/UX Polish & Feature Completion

OBJECTIVE

Finish My Makeup Kit as a coherent, premium, documented FaceTune feature.

VISUAL AUDIT

Review:

- feature entry point
- kit overview
- category navigation
- product cards
- swatches
- Add Product
- category-specific forms
- visual color picker
- finish selectors
- foundation depth/undertone
- edit/delete
- recommendation mode selector
- empty kit
- incomplete kit
- kit recommendation
- kit preview
- kit results
- loading/error/recovery states

Ensure visual consistency with FaceTune.

UX AUDIT

Verify:

- users do not need to understand HEX
- forms expose only relevant fields
- optional fields are clearly optional
- destructive actions are intentional
- empty/incomplete kits have clear paths
- mode selection is easy to understand
- standard Makeup Recommendation remains easy to use
- no placeholder/developer UI remains

DOCUMENTATION

Update appropriate project documentation with:

- My Makeup Kit architecture
- schema/RLS overview
- AI contract
- prompt version
- deployment requirements
- known limitations
- maintenance considerations
- regression protection

Do not rewrite the original Phase 1–26 roadmap unnecessarily.

FINAL DEFINITION OF DONE

My Makeup Kit is complete only if:

- private inventory works
- multiple products/category work
- visual color selection works
- category-specific finishes work
- foundation metadata works
- add/edit/delete work
- incomplete kits work honestly
- kit mode is explicit
- AI selects only owned products
- anti-hallucination validation works
- kit preview works
- saved/history works
- security/RLS work
- original Makeup Recommendation remains unchanged
- required validation passes or blockers are truthfully documented

REQUIRED VALIDATION

Run:
- dart format .
- flutter analyze
- complete relevant flutter test
- configured Android debug build
- relevant Edge Function/backend tests
- final manual checklist where available

COMPLETION REPORT

FEATURE COMPLETED:
My Makeup Kit

PHASE COMPLETED:
MK-14 — Final UI/UX Polish & Feature Completion

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
Return to the broader FaceTune feature-expansion plan or resume the original
roadmap only when explicitly instructed.

Then STOP.

Do not begin another feature automatically.
```

---

# UNIVERSAL COPY/PASTE HANDOFF PROMPT

Use this if switching between Codex and Claude Code Pro during any phase:

```text
Read CODEX_MASTER_GUIDE.md completely first.

Then read FACETUNE_MY_MAKEUP_KIT_GUIDE.md completely.

Then locate and read the requested phase in
FACETUNE_MY_MAKEUP_KIT_ROADMAP.md.

Inspect the CURRENT repository, Git diff, and Git status before making changes.

Continue from the actual current workspace state. Do not assume the previous AI
agent completed work that is not present in the repository.

The existing Makeup Recommendation flow is FROZEN and is the protected baseline.

Implement ONLY:

MK-[NUMBER] — [PHASE NAME]

Follow the exact scope, constraints, validation, and completion criteria in the
roadmap.

Preserve all valid existing functionality, architecture, security controls,
Supabase RLS, Gemini integrations, timeout/retry protections, and existing data.

Do not refactor the existing Makeup Recommendation flow merely to support My
Makeup Kit.

If this phase cannot be implemented without changing the behavior of the frozen
Makeup Recommendation flow, STOP and report the architectural conflict.

Run all required validation.

Fix errors introduced by this phase.

Do not hide or suppress genuine errors just to make validation appear green.

Do not fabricate successful tests, API calls, database migrations, Edge
Function deployments, APK builds, or device results.

Provide the phase's required completion report.

Then STOP.

Do not implement the next phase until explicitly instructed.
```
