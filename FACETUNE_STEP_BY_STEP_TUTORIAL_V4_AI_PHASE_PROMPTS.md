# FaceTune — STEP-BY-STEP TUTORIAL V4 AI PHASE PROMPTS

**Project root:** `C:\Users\Kurt\facetune`  
**V4 branch:** `feature/step-by-step-tutorial-v4-ai`  
**Master guide:** `CODEX_MASTER_GUIDE.md`  
**V4 Source of Truth:** `FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_SOURCE_OF_TRUTH.md`  
**This phase file:** `FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_PHASE_PROMPTS.md`  
**Primary device:** POCO X3 GT  
**Tutorial model:** `gemini-3.1-flash-image`  
**Initial tutorial output resolution:** `1K` for ALL generated tutorial steps  
**Recommendation modes:** `standard` + `my_makeup_kit`  
**Manifest strategy:** controlled vocabulary + deterministic order + dynamic visual inclusion  

---

# HOW TO USE THIS FILE

1. Keep this file in the FaceTune project root beside the V4 Source of Truth.
2. Use either Codex or Claude Code Pro with Opus 5.
3. Run exactly ONE V4 phase at a time.
4. Paste only the prompt for the phase currently being implemented.
5. Review the completion report and evidence before starting the next phase.
6. Never tell the coding agent to continue automatically.
7. Never assume a previous phase is correct merely because its report says `complete`.
8. If production/device evidence contradicts a report, production/device evidence wins.
9. Do not merge V3 into V4.
10. Do not merge/push to `main` automatically.

Every phase below requires the coding agent to read, in order:

```text
1. CODEX_MASTER_GUIDE.md
2. FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_SOURCE_OF_TRUTH.md
3. FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_PHASE_PROMPTS.md
4. relevant prior V4 completion report(s)
5. actual source code / migrations / tests relevant to the phase
```

---

# MANDATORY SYSTEM ROLE FOR EVERY PHASE

Act simultaneously as:

- Principal Software Engineer
- Principal Software Architect
- Senior Flutter Engineer
- Senior Dart Engineer
- Senior Mobile Engineer
- Senior Supabase Engineer
- Senior PostgreSQL / RLS Engineer
- Senior TypeScript / Deno Engineer
- Senior Gemini AI Engineer
- Senior Multimodal Image Engineer
- Senior Prompt Engineer
- Senior AI Systems Engineer
- Senior Application Security Engineer
- Senior Privacy Engineer
- Senior Reliability Engineer
- Senior Async / Concurrency Engineer
- Senior Performance Engineer
- Senior AI Cost Optimization Engineer
- Senior QA / Regression Engineer
- Senior Integration Test Engineer
- Senior Production Debugging Engineer
- Senior Release Engineer
- Senior Code Reviewer
- Senior Domain Modeling Engineer
- Senior Product State Engineer
- Senior Makeup-Tutorial Systems Designer
- Senior My Makeup Kit / Inventory Systems Engineer

Do not behave as a code generator that blindly follows assumptions.

Inspect first.

Challenge stale documentation.

Prefer the smallest production-safe change.

Preserve working application behavior.

---

# GLOBAL RULES FOR EVERY PHASE

Before coding:

- verify the current Git branch
- run `git status`
- inspect current implementation
- inspect `pubspec.yaml` when Flutter dependencies may matter
- inspect relevant Supabase migrations/functions when backend changes may matter
- identify reusable existing code
- identify the minimum files that need modification
- identify what the phase explicitly forbids
- do not modify unrelated modules

During implementation:

- preserve Clean Architecture / Repository Pattern / feature-first organization
- preserve modular OOP
- keep business logic out of widgets
- keep Gemini calls out of Flutter
- keep secrets server-side
- do not disable RLS
- do not bypass JWT verification
- do not add MediaPipe/OpenCV/TFLite
- do not add V3 geometry mapping
- do not add CustomPainter face-guideline geometry
- do not silently switch Gemini models
- do not silently change tutorial resolution from 1K
- do not create generic makeup tutorial rules
- do not let face shape override the canonical final preview
- do not create fixed nine-step inclusion
- keep supported tutorial category vocabulary controlled
- derive category inclusion from visual comparison of original selfie vs canonical final preview
- keep category order deterministic after dynamic filtering
- do not let Gemini invent tutorial category names
- support both `standard` and `my_makeup_kit` through shared contracts
- in My Makeup Kit mode, validate every AI-selected product ID server-side for ownership and category
- incomplete My Makeup Kit inventory is valid
- never invent missing My Makeup Kit products
- never silently fall back from My Makeup Kit mode to Standard Mode
- preserve immutable product snapshots for historical looks/tutorials
- do not add cumulative intermediate AI makeup images
- do not automatically start later phases
- do not commit, push, merge, rebase, or force-push unless explicitly instructed

After implementation:

- format changed code
- run static analysis
- run relevant tests
- run Android build validation when justified
- validate backend code/migrations where applicable
- fix errors introduced by this phase
- distinguish proven facts from assumptions
- report manual actions exactly
- STOP

---

# STANDARD V4 COMPLETION REPORT

Every phase must end with:

```text
PHASE COMPLETED:

BRANCH VERIFIED:

OBJECTIVE ACHIEVED:

FILES CREATED:

FILES MODIFIED:

FILES DELETED:
None / list exact files and justification

DEPENDENCIES ADDED / REMOVED:

DATABASE / RLS CHANGES:

STORAGE CHANGES:

EDGE FUNCTION / AI CHANGES:

RECOMMENDATION SOURCE MODE CHANGES:

MY MAKEUP KIT CHANGES:

DYNAMIC MANIFEST CHANGES:

GEMINI MODEL USED:
None / exact model

OUTPUT RESOLUTION:
None / exact resolution

PROMPT VERSION:
None / exact version

SECURITY CHECK:

TESTS / VALIDATION:

REAL DEVICE / LIVE BACKEND EVIDENCE:

KNOWN LIMITATIONS:

ASSUMPTIONS NOT PROVEN:

MANUAL ACTION REQUIRED:
None / exact action

NEXT RECOMMENDED PHASE:

STOP CONFIRMATION:
No later phase was implemented.
```

A vague completion report is not acceptable.

---

# V4-0 — BASELINE AUDIT & DUAL-MODE INTEGRATION MAP

Read all mandatory authority files completely before making changes.

Implement only **V4-0 — BASELINE AUDIT & DUAL-MODE INTEGRATION MAP**.

Do not redo completed V4 phases unless the smallest safe adjustment is required to implement this phase.

## Active roles

Especially apply:

- Principal Software Architect
- Senior Flutter/Dart Engineer
- Senior Supabase Engineer
- Senior Gemini AI Engineer
- Senior My Makeup Kit / Inventory Systems Engineer
- Senior Security Engineer
- Senior Integration Test Engineer
- Senior Code Reviewer

## Objective

Establish the exact technical baseline of `feature/step-by-step-tutorial-v4-ai` before any V4, My Makeup Kit alignment, dynamic-manifest, or tutorial-generation code is created. This phase is intentionally inspection-first and read-only except for an explicitly requested audit report.

## Before coding

- verify current branch and working-tree state
- prove V4 ancestry relative to `main`
- inspect `pubspec.yaml`, `lib/`, routing, Riverpod, configuration, tests
- inspect relevant Supabase migrations, RLS, storage policies, Edge Functions
- locate the existing Standard Mode face-analysis → style → recommendation → Pro-preview flow
- locate canonical `gemini-3-pro-image` preview persistence and original-selfie lineage
- inspect whether My Makeup Kit already exists on the V4/main-based branch
- if `feature/my-makeup-kit` exists locally, inspect it READ-ONLY with `git show`, `git log`, or `git diff`; do not switch, merge, cherry-pick, or rebase

Do not code from assumptions when the repository, migrations, deployed state, or tests can prove the answer.

## Implement

- produce a concrete Standard Mode integration map
- produce a concrete My Makeup Kit status/integration map
- identify reusable existing kit/product domain, persistence, UI, repositories, and tests
- identify schema gaps for kit products, immutable look-product snapshots, dynamic manifests, tutorial sessions, and steps
- identify RLS/storage/security gaps
- identify any V3 tutorial/geometry code accidentally present
- identify exact likely files/modules later phases should extend
- document assumptions requiring runtime proof

## Non-negotiable rules

- no write should occur except an explicitly requested audit document
- current production/device evidence wins over stale completion reports
- read-only inspection of another branch is not permission to merge it
- preserve V4's clean `main` ancestry

## Do NOT implement

- feature code
- migrations
- new Edge Functions
- Gemini calls
- My Makeup Kit CRUD
- dynamic manifest analyzer
- tutorial UI
- V3 merge
- broad refactor

## Tests / validation

Test at minimum:

- `git status` recorded
- `git branch --show-current` proves correct branch
- baseline `flutter analyze` result recorded
- real source files are cited in the audit rather than guessed

Run the appropriate validation for every changed layer.

At minimum:

- `git status`
- `git branch --show-current`
- `flutter analyze`

If Flutter dependencies changed, run `flutter pub get`.

When Android compilation should be verified, run:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

If a physical Android device is required by this phase and is available, use the project's established run command.

Fix errors introduced by this phase.

Do not hide or suppress genuine errors merely to make validation appear green.

## Done when

- Standard Mode is mapped from real code
- canonical preview and original-selfie lineage are understood
- actual My Makeup Kit implementation status is proven
- schema/storage/RLS gaps are documented
- smallest V4-1 implementation boundary is identified
- no product feature code was added


## Completion report

Use the **STANDARD V4 COMPLETION REPORT**.

Then STOP.

Do not implement V4-1 unless explicitly instructed.

---

# V4-1 — DUAL-MODE DOMAIN & CONTRACTS

Read all mandatory authority files completely before making changes.

Implement only **V4-1 — DUAL-MODE DOMAIN & CONTRACTS**.

Do not redo completed V4 phases unless the smallest safe adjustment is required to implement this phase.

## Active roles

Especially apply:

- Principal Software Architect
- Senior Domain Modeling Engineer
- Senior Flutter/Dart Engineer
- Senior My Makeup Kit / Inventory Systems Engineer
- Senior QA Engineer
- Senior Code Reviewer

## Objective

Create strongly typed shared contracts so Standard Mode and My Makeup Kit Mode converge into one validated look-plan and one tutorial architecture, including dynamic visual-manifest concepts.

## Before coding

- read V4-0 integration map
- inspect existing recommendation/domain entities
- reuse valid My Makeup Kit concepts discovered in V4-0
- identify the minimum new types necessary

Do not code from assumptions when the repository, migrations, deployed state, or tests can prove the answer.

## Implement

- `RecommendationSourceMode` equivalent with `standard` and `my_makeup_kit`
- controlled My Makeup Kit inventory category representation
- `MakeupKitProduct` contract with category-specific optional metadata
- shared validated look-plan contract
- immutable selected-product snapshot contracts
- `TutorialCategory` controlled vocabulary
- server-owned product-category → tutorial-category mapping contract
- `TutorialManifest` and manifest-item contracts that can represent present/absent/uncertain
- deterministic category ordering independent from dynamic inclusion
- `TutorialSession`, `TutorialStep`, statuses, failures, resolution
- repository/use-case contracts for inventory, look plan, manifest, session, and step
- central manifest/tutorial AI configuration contracts where architecturally justified

## Non-negotiable rules

- do not infer source mode from nullable fields
- do not use a vague `useKit` boolean as the domain model
- all nine categories are supported but not all are mandatory
- category inclusion must be independent from category order
- Gemini cannot invent new category names
- My Makeup Kit product identity is separate from visual placement authority
- models should be immutable where practical
- avoid raw maps in presentation contracts

## Do NOT implement

- Supabase migrations/RLS
- live data sources
- live Gemini
- prompt templates
- My Makeup Kit UI
- tutorial UI
- V3 geometry
- CustomPainter face overlays

## Tests / validation

Test at minimum:

- source-mode behavior
- controlled tutorial category vocabulary
- deterministic ordering after filtering
- inventory-category → tutorial-category mappings
- multiple product items mapping to one tutorial category
- incomplete kit representable without error
- unsupported category rejected
- central tutorial resolution default is 1K

Run the appropriate validation for every changed layer.

At minimum:

- `dart format .`
- `flutter analyze`
- `flutter test`

If Flutter dependencies changed, run `flutter pub get`.

When Android compilation should be verified, run:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

If a physical Android device is required by this phase and is available, use the project's established run command.

Fix errors introduced by this phase.

Do not hide or suppress genuine errors merely to make validation appear green.

## Done when

- both source modes have clean typed representation
- validated look plan is the shared convergence point
- immutable kit product snapshots are first-class domain data
- dynamic inclusion is separated from deterministic order
- later persistence/AI/UI phases can depend on stable contracts


## Completion report

Use the **STANDARD V4 COMPLETION REPORT**.

Then STOP.

Do not implement V4-2 unless explicitly instructed.

---

# V4-2 — MY MAKEUP KIT, SNAPSHOT, MANIFEST & TUTORIAL PERSISTENCE / RLS

Read all mandatory authority files completely before making changes.

Implement only **V4-2 — MY MAKEUP KIT, SNAPSHOT, MANIFEST & TUTORIAL PERSISTENCE / RLS**.

Do not redo completed V4 phases unless the smallest safe adjustment is required to implement this phase.

## Active roles

Especially apply:

- Senior Supabase Engineer
- Senior PostgreSQL Engineer
- Senior RLS Engineer
- Senior Security Engineer
- Senior Privacy Engineer
- Senior Flutter Data Engineer
- Senior Code Reviewer

## Objective

Create the minimum secure migration-backed persistence required for My Makeup Kit, immutable selected-product snapshots, source-mode lineage, dynamic manifest state, tutorial sessions, and guideline steps.

## Before coding

- inspect all existing relevant tables/migrations/enums/FKs/indexes/RLS/storage
- reuse or extend valid existing My Makeup Kit persistence
- do not duplicate concepts merely because the Source of Truth uses conceptual names
- prove how analyses, recommendations, generated images, ownership, and storage currently work

Do not code from assumptions when the repository, migrations, deployed state, or tests can prove the answer.

## Implement

- user-owned My Makeup Kit product persistence with multiple products per category
- category-aware optional fields such as product name, shade/color, HEX, finish, foundation depth/undertone
- valid incomplete-kit persistence
- immutable look-product snapshot and normalized snapshot-item persistence
- source-mode / look-plan lineage
- tutorial-session persistence with canonical-preview and manifest metadata
- normalized dynamic-manifest persistence or equivalent validated structure
- tutorial-step persistence only for included categories
- step-to-one-or-more snapshot-item linkage where required
- appropriate foreign keys, indexes, checks, uniqueness/idempotency constraints
- RLS and ownership-safe policies
- private guideline storage path convention

## Non-negotiable rules

- all kit/snapshot/manifest/tutorial records are private user data
- user A cannot attach/read user B kit/snapshot/tutorial data
- mutable kit edits cannot rewrite immutable historical snapshots
- original selfie and canonical preview are never overwritten
- RLS is never disabled for convenience
- server validation remains required even with RLS

## Do NOT implement

- live Gemini
- AI product selection
- visual manifest analysis
- tutorial generation
- full My Makeup Kit UI
- public storage
- V3 geometry
- destructive remote deployment without explicit authorization

## Tests / validation

Test at minimum:

- own-user RLS allow
- cross-user kit denial
- cross-user snapshot denial
- cross-user tutorial denial
- multiple products same category
- incomplete kit persistence
- snapshot stability semantics
- manifest category constraints
- duplicate session/step constraints

Run the appropriate validation for every changed layer.

At minimum:

- `dart format .`
- `flutter analyze`
- `flutter test`

If Flutter dependencies changed, run `flutter pub get`.

When Android compilation should be verified, run:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

If a physical Android device is required by this phase and is available, use the project's established run command.

Fix errors introduced by this phase.

Do not hide or suppress genuine errors merely to make validation appear green.

## Done when

- schema supports both source modes
- mutable inventory and immutable historical snapshot are separate
- dynamic manifest and included-step persistence are possible
- RLS protects every new user-owned entity
- no Gemini generation exists


## Completion report

Use the **STANDARD V4 COMPLETION REPORT**.

Then STOP.

Do not implement V4-3 unless explicitly instructed.

---

# V4-3 — MY MAKEUP KIT INVENTORY APPLICATION FLOW

Read all mandatory authority files completely before making changes.

Implement only **V4-3 — MY MAKEUP KIT INVENTORY APPLICATION FLOW**.

Do not redo completed V4 phases unless the smallest safe adjustment is required to implement this phase.

## Active roles

Especially apply:

- Senior Flutter Engineer
- Senior Dart Engineer
- Senior My Makeup Kit / Inventory Systems Engineer
- Senior Supabase Engineer
- Senior Riverpod Engineer
- Senior Mobile UI/UX Engineer
- Senior QA Engineer

## Objective

Implement My Makeup Kit as a real production inventory feature on V4 so later AI recommendation and tutorial phases do not require a retrofit.

## Before coding

- reuse V4-1 domain and V4-2 persistence
- inspect existing FaceTune design system/navigation
- inspect any reusable My Makeup Kit work discovered in V4-0
- preserve Standard Mode

Do not code from assumptions when the repository, migrations, deployed state, or tests can prove the answer.

## Implement

- repository/data-source implementation for owned products
- add product
- edit product
- delete/deactivate product consistent with historical snapshot rules
- list/group/filter by category
- multiple products per category
- empty and incomplete kits
- category-aware validation for product name optional, shade/color, HEX, finish, foundation depth/undertone
- Riverpod/controller explicit states
- polished My Makeup Kit inventory UI using existing design system
- auth/session-safe data access

## Non-negotiable rules

- inventory UI is not the tutorial engine
- user may save real product/brand names they own
- user-entered names must not become Standard Mode brand recommendations
- do not invent missing metadata
- business logic stays outside widgets

## Do NOT implement

- AI recommendation/product selection
- Pro-preview changes
- visual manifest
- Flash guideline generation
- tutorial UI
- cumulative intermediate images

## Tests / validation

Test at minimum:

- add first product
- multiple products same category
- incomplete kit
- empty kit
- edit product
- delete/deactivate product
- category-specific fields
- invalid metadata
- cross-user access denial
- session expiration

Run the appropriate validation for every changed layer.

At minimum:

- `dart format .`
- `flutter analyze`
- `flutter test`

If Flutter dependencies changed, run `flutter pub get`.

When Android compilation should be verified, run:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

If a physical Android device is required by this phase and is available, use the project's established run command.

Fix errors introduced by this phase.

Do not hide or suppress genuine errors merely to make validation appear green.

## Done when

- user can safely maintain real owned products
- multiple products per category work
- incomplete kit is valid
- data persists securely
- existing Standard Mode still works


## Completion report

Use the **STANDARD V4 COMPLETION REPORT**.

Then STOP.

Do not implement V4-4 unless explicitly instructed.

---

# V4-4 — DUAL-MODE RECOMMENDATION & SERVER PRODUCT VALIDATION

Read all mandatory authority files completely before making changes.

Implement only **V4-4 — DUAL-MODE RECOMMENDATION & SERVER PRODUCT VALIDATION**.

Do not redo completed V4 phases unless the smallest safe adjustment is required to implement this phase.

## Active roles

Especially apply:

- Senior Gemini AI Engineer
- Senior Prompt Engineer
- Senior Supabase Backend Engineer
- Senior TypeScript/Deno Engineer
- Senior My Makeup Kit / Inventory Systems Engineer
- Senior Security Engineer
- Senior QA Engineer

## Objective

Implement two first-class recommendation modes that converge into a validated look plan. Standard Mode remains brand-neutral. My Makeup Kit Mode may select only products actually owned by the authenticated user.

## Before coding

- inspect existing Standard Mode recommendation implementation
- preserve valid Standard Mode schema/prompt behavior
- inspect V4-3 inventory and V4-1 contracts
- verify current structured-output Gemini model used for recommendation

Do not code from assumptions when the repository, migrations, deployed state, or tests can prove the answer.

## Implement

- preserve/minimally adapt Standard Mode face analysis + selected style → validated brand-neutral recommendation
- add My Makeup Kit Mode using face analysis + selected style + server-resolved eligible owned products
- send only eligible owned product IDs/metadata to Gemini
- require AI to reference only supplied product IDs
- server-validate selected IDs for existence, ownership, active/eligible state, and category
- reject unknown, foreign, deleted, or wrong-category IDs
- support incomplete kits without inventing categories
- produce one shared validated look-plan contract
- create immutable selected-product snapshot after My Makeup Kit validation succeeds
- persist source mode and model/prompt/schema versions
- bounded retry/error handling

## Non-negotiable rules

- Gemini never proves ownership
- My Makeup Kit never invents missing products
- no silent fallback from My Makeup Kit to Standard Mode
- Standard Mode remains brand-neutral
- user-entered kit product names may be preserved/displayed
- ownership validation is server-side

## Do NOT implement

- Pro-preview changes beyond minimum contract
- visual manifest
- Flash guideline generation
- tutorial UI
- shopping recommendations
- brand recommendations in Standard Mode

## Tests / validation

Test at minimum:

- Standard Mode success
- Standard Mode brand-neutral output
- complete kit
- incomplete kit
- multiple candidate products same category
- valid selected IDs
- invented ID rejected
- foreign ID rejected
- wrong-category ID rejected
- immutable snapshot created
- malformed AI output
- auth failure

Run the appropriate validation for every changed layer.

At minimum:

- `dart format .`
- `flutter analyze`
- `flutter test`

If Flutter dependencies changed, run `flutter pub get`.

When Android compilation should be verified, run:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

If a physical Android device is required by this phase and is available, use the project's established run command.

Fix errors introduced by this phase.

Do not hide or suppress genuine errors merely to make validation appear green.

## Done when

- both modes produce validated look plans
- My Makeup Kit cannot escape server-owned product universe
- snapshot contains only validated selected products
- Standard Mode behavior remains working


## Completion report

Use the **STANDARD V4 COMPLETION REPORT**.

Then STOP.

Do not implement V4-5 unless explicitly instructed.

---

# V4-5 — CANONICAL PRO PREVIEW INTEGRATION & KIT CONSISTENCY GUARD

Read all mandatory authority files completely before making changes.

Implement only **V4-5 — CANONICAL PRO PREVIEW INTEGRATION & KIT CONSISTENCY GUARD**.

Do not redo completed V4 phases unless the smallest safe adjustment is required to implement this phase.

## Active roles

Especially apply:

- Senior Gemini Image Engineer
- Senior Supabase Backend Engineer
- Senior Prompt Engineer
- Senior Security Engineer
- Senior Reliability Engineer
- Senior Integration Test Engineer

## Objective

Ensure both recommendation modes feed the existing canonical final-preview architecture through one canonical lineage, with My Makeup Kit constrained to the validated owned-product look plan.

## Before coding

- inspect current Pro-preview generation and persistence
- prove analysis/recommendation/model/prompt/generated-image lineage
- do not replace working Pro behavior without reason

Do not code from assumptions when the repository, migrations, deployed state, or tests can prove the answer.

## Implement

- feed Standard Mode validated look plan into existing Pro flow
- feed My Makeup Kit validated look plan + immutable selected-product snapshot into Pro flow
- prevent My Makeup Kit prompt/input from intentionally adding categories absent from selected-product plan
- persist source mode and look-plan/snapshot lineage with canonical preview
- preserve original selfie as identity reference
- preserve regenerate/variation lineage
- create a controlled mismatch status/failure path for later detected kit-preview inconsistency

## Non-negotiable rules

- the canonical final preview is a role, not a model; the current renderer is `gemini-3.1-flash-image`
- canonical preview is visual tutorial authority regardless of mode
- My Makeup Kit preview must be recreatable from owned selected products
- do not add an unowned category because style usually uses it
- never overwrite original selfie
- do not downgrade Pro model

## Do NOT implement

- visual manifest analyzer
- Flash guideline generation
- tutorial UI
- cumulative tutorial images
- silent regeneration loops

## Tests / validation

Test at minimum:

- Standard Mode canonical preview
- My Makeup Kit canonical preview
- source-mode lineage
- snapshot lineage
- regenerated preview lineage
- missing snapshot rejected in My Makeup Kit mode
- existing result/before-after regression

Run the appropriate validation for every changed layer.

At minimum:

- `dart format .`
- `flutter analyze`
- `flutter test`

If Flutter dependencies changed, run `flutter pub get`.

When Android compilation should be verified, run:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

If a physical Android device is required by this phase and is available, use the project's established run command.

Fix errors introduced by this phase.

Do not hide or suppress genuine errors merely to make validation appear green.

## Done when

- both modes produce canonical previews through one coherent architecture
- My Makeup Kit preview is tied to validated owned-product selection
- tutorial can later resolve exact source mode/plan/snapshot from canonical preview
- existing result flow remains working


## Completion report

Use the **STANDARD V4 COMPLETION REPORT**.

Then STOP.

Do not implement V4-6 unless explicitly instructed.

---

# V4-6 — DYNAMIC VISUAL MANIFEST ANALYZER

Read all mandatory authority files completely before making changes.

Implement only **V4-6 — DYNAMIC VISUAL MANIFEST ANALYZER**.

Do not redo completed V4 phases unless the smallest safe adjustment is required to implement this phase.

## Active roles

Especially apply:

- Senior Gemini AI Engineer
- Senior Multimodal AI Engineer
- Senior Prompt Engineer
- Senior TypeScript/Deno Engineer
- Senior Domain Modeling Engineer
- Senior Reliability Engineer
- Senior QA Engineer

## Objective

Implement the comparison-based manifest system: visually inspect the original selfie and canonical final preview, determine which supported makeup categories are actually present, and persist only relevant steps in deterministic logical order.

## Before coding

- verify a current approved Gemini multimodal model capable of strict structured output
- prefer reuse of FaceTune's approved structured-output model when appropriate
- inspect canonical-preview lineage and manifest contracts
- define versioned supported-category schema

Do not code from assumptions when the repository, migrations, deployed state, or tests can prove the answer.

## Implement

- separate server-side manifest-analysis operation
- Image A = owned original selfie
- Image B = owned canonical final preview
- compare BEFORE vs FINAL
- classify only supported categories as present/absent/uncertain or justified equivalent
- validate structured output server-side
- reject invented/unsupported categories
- derive inclusion from visual evidence, not style or face-shape templates
- apply deterministic order after filtering
- Standard Mode: include visually grounded categories
- My Makeup Kit Mode: include intersection of visually grounded categories and validated selected-product snapshot mappings
- detect visible My Makeup Kit category with no validated selected product as `kit_preview_mismatch` or equivalent
- do not let kit product force a step when visual evidence is absent
- persist model/prompt/schema version and accepted manifest
- reuse accepted manifest for the same canonical preview

## Non-negotiable rules

- supported vocabulary is controlled; inclusion is dynamic; order is deterministic
- do not create nine steps by default
- do not use face-shape or style-to-step templates
- uncertain is not silently present
- recommendation/look plan is supporting context only for genuine ambiguity
- visual comparison unavailable → fail safely
- regenerated canonical preview requires new/versioned manifest

## Do NOT implement

- Flash guideline rendering
- tutorial UI
- V3 geometry
- CustomPainter guideline mapping
- arbitrary hardcoded confidence thresholds without evidence

## Tests / validation

Test at minimum:

- all categories present
- subset present
- Highlighter absent → excluded
- unsupported category output rejected
- uncertain not silently included
- deterministic order
- manifest reused
- new preview gets new manifest
- Standard Mode
- My Makeup Kit incomplete kit
- visible category without selected product → mismatch
- selected product but visually absent → no forced step

Run the appropriate validation for every changed layer.

At minimum:

- `dart format .`
- `flutter analyze`
- `flutter test`

If Flutter dependencies changed, run `flutter pub get`.

When Android compilation should be verified, run:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

If a physical Android device is required by this phase and is available, use the project's established run command.

Fix errors introduced by this phase.

Do not hide or suppress genuine errors merely to make validation appear green.

## Done when

- Original + Final visual comparison literally determines tutorial inclusion
- only relevant supported categories become steps
- order stays deterministic
- My Makeup Kit constraints align with manifest inclusion
- manifest is persisted/reusable


## Completion report additions

```text
MANIFEST MODEL:
MANIFEST PROMPT VERSION:
MANIFEST SCHEMA VERSION:
DYNAMIC INCLUSION STATUS:
DETERMINISTIC ORDER STATUS:
MY MAKEUP KIT INTERSECTION STATUS:
KIT PREVIEW MISMATCH STATUS:
MANIFEST REUSE STATUS:
```

## Completion report

Use the **STANDARD V4 COMPLETION REPORT**.

Then STOP.

Do not implement V4-7 unless explicitly instructed.

---

# V4-7 — TUTORIAL REPOSITORY, SESSION LIFECYCLE & IDEMPOTENCY

Read all mandatory authority files completely before making changes.

Implement only **V4-7 — TUTORIAL REPOSITORY, SESSION LIFECYCLE & IDEMPOTENCY**.

Do not redo completed V4 phases unless the smallest safe adjustment is required to implement this phase.

## Active roles

Especially apply:

- Senior Flutter/Dart Engineer
- Senior Supabase Engineer
- Senior Async/Concurrency Engineer
- Senior Reliability Engineer
- Senior Product State Engineer
- Senior QA Engineer

## Objective

Create/reuse tutorial sessions from accepted dynamic manifests and create only included tutorial steps while preserving source mode and immutable product context.

## Before coding

- reuse V4-1 domain, V4-2 persistence, V4-6 accepted manifest
- inspect existing generated-image/reopen patterns

Do not code from assumptions when the repository, migrations, deployed state, or tests can prove the answer.

## Implement

- create/reuse tutorial session for same canonical preview + manifest version
- load accepted manifest
- create/resolve step records only for included categories
- assign deterministic positions after filtering
- make `Step X of N` depend on actual included count
- link session to source mode and validated look plan
- link My Makeup Kit steps to exact immutable snapshot item(s)
- reuse existing ready steps
- prevent duplicate sessions/category records
- request correlation/idempotency
- typed errors and safe state transitions

## Non-negotiable rules

- widget rebuild never creates paid work
- reopen does not re-run accepted manifest
- reopen later must reuse ready guideline steps
- source mode cannot change inside an existing canonical tutorial session
- client cancellation does not prove server cancellation

## Do NOT implement

- Flash guideline generation
- category prompts
- full tutorial UI
- prefetch
- V3 geometry

## Tests / validation

Test at minimum:

- subset manifest creates subset steps
- dynamic step count
- deterministic positions
- session reuse
- duplicate concurrent create
- ready-step reuse
- My Makeup Kit snapshot linkage
- Standard Mode no kit snapshot
- cross-user denial

Run the appropriate validation for every changed layer.

At minimum:

- `dart format .`
- `flutter analyze`
- `flutter test`

If Flutter dependencies changed, run `flutter pub get`.

When Android compilation should be verified, run:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

If a physical Android device is required by this phase and is available, use the project's established run command.

Fix errors introduced by this phase.

Do not hide or suppress genuine errors merely to make validation appear green.

## Done when

- session lifecycle is proven without Flash Image
- only manifest-approved categories exist as steps
- source-mode/product linkage is stable
- duplicate creation is prevented


## Completion report

Use the **STANDARD V4 COMPLETION REPORT**.

Then STOP.

Do not implement V4-8 unless explicitly instructed.

---

# V4-8 — CANONICAL SOURCE RESOLUTION

Read all mandatory authority files completely before making changes.

Implement only **V4-8 — CANONICAL SOURCE RESOLUTION**.

Do not redo completed V4 phases unless the smallest safe adjustment is required to implement this phase.

## Active roles

Especially apply:

- Senior Supabase Backend Engineer
- Senior TypeScript/Deno Engineer
- Senior Security Engineer
- Senior API Integration Engineer
- Senior Privacy Engineer
- Senior Integration Test Engineer

## Objective

Create the secure server-authoritative resolver that supplies each future guideline request with the exact two images, approved category, source mode, and validated product context.

## Before coding

- inspect V4-7 session/step persistence
- inspect private storage conventions
- inspect existing signed-source retrieval

Do not code from assumptions when the repository, migrations, deployed state, or tests can prove the answer.

## Implement

- derive authenticated user from JWT/session
- resolve owned tutorial session and accepted manifest
- verify requested category is included
- resolve Image A = owned original selfie
- resolve Image B = owned canonical final preview
- resolve source mode and validated look plan
- resolve recommendation/face analysis/style as supporting context
- My Makeup Kit: resolve exact immutable snapshot item(s) mapped to current category
- Standard Mode: resolve brand-neutral recommendation metadata
- reject arbitrary client model/resolution/prompt/image/product authority
- return typed internal generation context

## Non-negotiable rules

- Image A and Image B are mandatory
- final preview is visual placement authority
- product context does not override placement
- My Makeup Kit product metadata comes from immutable snapshot
- mutable current kit is not historical authority
- no JWT bypass or long-lived signed URL persistence
- sanitize logs

## Do NOT implement

- Gemini guideline generation
- manifest redesign beyond bug fix
- tutorial UI
- prefetch
- V3 geometry

## Tests / validation

Test at minimum:

- valid Standard Mode
- valid My Makeup Kit
- missing original
- missing final preview
- foreign preview
- foreign snapshot
- category not in manifest
- invalid source mode
- expired auth
- sanitized errors

Run the appropriate validation for every changed layer.

At minimum:

- `dart format .`
- `flutter analyze`
- `flutter test`

If Flutter dependencies changed, run `flutter pub get`.

When Android compilation should be verified, run:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

If a physical Android device is required by this phase and is available, use the project's established run command.

Fix errors introduced by this phase.

Do not hide or suppress genuine errors merely to make validation appear green.

## Done when

- backend constructs exact two-image + category + product context without trusting client
- both modes use one secure resolution path


## Completion report

Use the **STANDARD V4 COMPLETION REPORT**.

Then STOP.

Do not implement V4-9 unless explicitly instructed.

---

# V4-9 — GEMINI 3.1 FLASH GUIDELINE RENDERER FOUNDATION

Read all mandatory authority files completely before making changes.

Implement only **V4-9 — GEMINI 3.1 FLASH GUIDELINE RENDERER FOUNDATION**.

Do not redo completed V4 phases unless the smallest safe adjustment is required to implement this phase.

## Active roles

Especially apply:

- Senior Gemini AI Engineer
- Senior Multimodal Image Engineer
- Senior Prompt Engineer
- Senior TypeScript/Deno Engineer
- Senior Security Engineer
- Senior Reliability Engineer
- Senior AI Cost Optimization Engineer
- Senior QA Engineer

## Objective

Integrate `gemini-3.1-flash-image` at 1K with one controlled pilot category, using original selfie as rendering base and canonical final preview as authoritative target.

## Before coding

- verify exact current model availability and API contract
- verify image+text inputs and 1K output
- STOP if exact required model cannot be used; do not silently substitute
- reuse V4-8 resolved context

Do not code from assumptions when the repository, migrations, deployed state, or tests can prove the answer.

## Implement

- centralized tutorial model config
- centralized 1K resolution
- prompt versioning
- common Image A/Image B roles
- one pilot category such as Blush
- secure Gemini request
- bounded timeout
- at most one technical retry when no usable result exists
- output image extraction/validation
- private storage write
- step metadata/status persistence
- duplicate-call protection

## Non-negotiable rules

- Image B is authoritative for placement
- Image A is rendering base
- analyze one requested included category only
- no generic placement
- no actual makeup pigment
- guidelines/arrows/boundaries only
- preserve identity/pose/expression/hairstyle/background
- no unrelated categories
- no product text baked into image
- all initial outputs 1K

## Do NOT implement

- all categories
- 0.5K
- tutorial UI
- AI visual reviewer
- cumulative makeup images
- V3 geometry

## Tests / validation

Test at minimum:

- pilot Standard Mode generation
- pilot My Makeup Kit generation
- guideline-only output
- no product text in image
- private storage
- metadata persistence
- duplicate request reuse/coalescing
- bounded technical retry

Run the appropriate validation for every changed layer.

At minimum:

- `dart format .`
- `flutter analyze`
- `flutter test`

If Flutter dependencies changed, run `flutter pub get`.

When Android compilation should be verified, run:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

If a physical Android device is required by this phase and is available, use the project's established run command.

Fix errors introduced by this phase.

Do not hide or suppress genuine errors merely to make validation appear green.

## Done when

- one pilot category generates a real/controlled 1K guideline securely
- both modes share the renderer
- product context does not replace visual authority


## Completion report

Use the **STANDARD V4 COMPLETION REPORT**.

Then STOP.

Do not implement V4-10 unless explicitly instructed.

---

# V4-10 — CATEGORY-SPECIFIC GUIDELINES & PRODUCT PRESENTATION CONTRACTS

Read all mandatory authority files completely before making changes.

Implement only **V4-10 — CATEGORY-SPECIFIC GUIDELINES & PRODUCT PRESENTATION CONTRACTS**.

Do not redo completed V4 phases unless the smallest safe adjustment is required to implement this phase.

## Active roles

Especially apply:

- Senior Gemini AI Engineer
- Senior Prompt Engineer
- Senior Makeup-Tutorial Systems Designer
- Senior Multimodal Image Engineer
- Senior My Makeup Kit / Inventory Systems Engineer
- Senior QA Engineer
- Senior Regression Engineer

## Objective

Implement strict category-scoped prompt modules for every supported included tutorial category and structured product-detail contracts for Standard Mode and My Makeup Kit Mode.

## Before coding

- reuse common V4-9 prompt builder
- reuse V4-6 manifest; excluded categories must never generate
- inspect recommendation/snapshot mappings per category

Do not code from assumptions when the repository, migrations, deployed state, or tests can prove the answer.

## Implement

- Foundation: coverage perimeter/blend/avoid boundaries; no pigment
- Concealer: target boundaries/blend arrows; no pigment
- Contour/Bronzer: cheek/temple/jaw/nose only if visible; no brown shading
- Blush: boundary/height/extent/blend; no pigment
- Highlighter: visible trace/boundary; no shimmer
- Eyebrows: start/arch/tail/direction; no fill
- Eyeshadow: lid/crease/outer-V/inner-corner/blend; no color
- Eyeliner: start/lash path/transition/wing direction/endpoint/length/curvature; no black fill
- Lips: natural/target border/Cupid's bow/corners/lower boundary; no lipstick fill
- central category prompt builder and versioning
- Standard Mode brand-neutral product/colour presentation adapter
- My Makeup Kit exact immutable snapshot presentation adapter
- multiple snapshot items per step where mapped, e.g. Lipstick + Lip Gloss → Lips

## Non-negotiable rules

- canonical preview wins over generic convention
- face analysis/style only support interpretation
- excluded manifest categories are rejected
- Flutter renders product text/metadata; Gemini image does not
- My Makeup Kit exact product data comes from immutable snapshot
- do not invent missing fields
- 1K remains locked

## Do NOT implement

- full tutorial UI
- 0.5K
- generate-all
- AI visual QA model
- V3 geometry
- cumulative makeup results

## Tests / validation

Test at minimum:

- each category prompt mapping
- authority rules present
- guideline-only rules present
- unsupported category rejected
- excluded category rejected
- 1K locked
- Standard Mode remains brand-neutral
- My Makeup Kit details match snapshot
- Lips supports lipstick and/or gloss

Run the appropriate validation for every changed layer.

At minimum:

- `dart format .`
- `flutter analyze`
- `flutter test`

If Flutter dependencies changed, run `flutter pub get`.

When Android compilation should be verified, run:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

If a physical Android device is required by this phase and is available, use the project's established run command.

Fix errors introduced by this phase.

Do not hide or suppress genuine errors merely to make validation appear green.

## Done when

- every supported included category can generate through one backend
- product presentation contract is correct for both modes
- generated images remain guideline-only and text-light


## Completion report additions

```text
CATEGORY:
PROMPT VERSION:
LIVE TESTED:
GUIDELINE-ONLY PASS:
FINAL-PREVIEW FIDELITY NOTES:
STANDARD PRODUCT CONTRACT:
MY KIT PRODUCT CONTRACT:
KNOWN RISK:
```

## Completion report

Use the **STANDARD V4 COMPLETION REPORT**.

Then STOP.

Do not implement V4-11 unless explicitly instructed.

---

# V4-11 — ORCHESTRATION, ON-DEMAND GENERATION & COST CONTROLS

Read all mandatory authority files completely before making changes.

Implement only **V4-11 — ORCHESTRATION, ON-DEMAND GENERATION & COST CONTROLS**.

Do not redo completed V4 phases unless the smallest safe adjustment is required to implement this phase.

## Active roles

Especially apply:

- Senior Async/Concurrency Engineer
- Senior Reliability Engineer
- Senior AI Cost Optimization Engineer
- Senior Flutter/Riverpod Engineer
- Senior Supabase Engineer
- Senior QA Engineer

## Objective

Ensure manifest analysis and Flash guideline generation occur only when needed, are reused, and cannot multiply through incidental Flutter lifecycle events.

## Before coding

- inspect current state/request lifecycle
- reuse manifest/session/step idempotency contracts

Do not code from assumptions when the repository, migrations, deployed state, or tests can prove the answer.

## Implement

- generate current included step only when needed
- reuse ready guideline step
- optionally prefetch at most one next included step
- never generate all steps on tutorial open
- never re-run accepted manifest for same canonical preview
- deduplicate/coalesce in-flight requests
- bounded technical retry
- explicit user regeneration contract
- stale-client handling
- source-mode-aware state
- sanitized usage telemetry

## Non-negotiable rules

- no generation from widget build/provider recomputation/app resume/duplicate taps
- no ready-step regeneration on navigation
- no manifest regeneration on reopen
- client cannot request arbitrary model/resolution/prompt/category outside accepted manifest
- one action must not accidentally create multiple billable calls

## Do NOT implement

- visual UI polish
- 0.5K
- generate-all
- V3 geometry

## Tests / validation

Test at minimum:

- rapid double tap
- route rebuild
- background/foreground
- back then reopen
- concurrent same category
- manifest reuse
- failure then bounded retry
- ready step reopen
- Standard Mode
- My Makeup Kit

Run the appropriate validation for every changed layer.

At minimum:

- `dart format .`
- `flutter analyze`
- `flutter test`

If Flutter dependencies changed, run `flutter pub get`.

When Android compilation should be verified, run:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

If a physical Android device is required by this phase and is available, use the project's established run command.

Fix errors introduced by this phase.

Do not hide or suppress genuine errors merely to make validation appear green.

## Done when

- cost follows intentional use
- manifest and guideline calls are independently idempotent
- prefetch depth <= 1
- ready results reopen without new paid calls


## Completion report

Use the **STANDARD V4 COMPLETION REPORT**.

Then STOP.

Do not implement V4-12 unless explicitly instructed.

---

# V4-12 — FLUTTER TUTORIAL UI & DUAL-MODE PRODUCT EXPERIENCE

Read all mandatory authority files completely before making changes.

Implement only **V4-12 — FLUTTER TUTORIAL UI & DUAL-MODE PRODUCT EXPERIENCE**.

Do not redo completed V4 phases unless the smallest safe adjustment is required to implement this phase.

## Active roles

Especially apply:

- Senior Flutter Engineer
- Senior Riverpod Engineer
- Senior Mobile UI/UX Engineer
- Senior Accessibility Engineer
- Senior My Makeup Kit / Inventory Systems Engineer
- Senior QA Engineer

## Objective

Integrate the real variable-length V4 tutorial into the result flow and show exact My Makeup Kit product snapshots without changing the guideline-image contract.

## Before coding

- inspect existing result/before-after navigation
- reuse FaceTune design tokens/components
- reuse V4-10 product presentation contracts

Do not code from assumptions when the repository, migrations, deployed state, or tests can prove the answer.

## Implement

- smallest appropriate tutorial entry from canonical result
- dynamic `Step X of N` using manifest-approved steps
- category title and 1K guideline image
- Standard Mode brand-neutral recommendation metadata
- My Makeup Kit exact immutable product details: user-entered name, shade, HEX, finish, depth/undertone where relevant
- one or more products per tutorial step where mapped
- short structured instruction/technique/tip
- previous/next/progress
- loading/generating/retry/image-error states
- safe back navigation and completion
- reuse canonical final preview at end
- accessibility/localization-ready labels

## Non-negotiable rules

- product text is Flutter UI, never Gemini image text
- UI never calls Gemini directly
- generation never begins inside `build()`
- revisit ready step without regeneration
- excluded categories are not shown
- do not invent product fields
- do not use mutable kit as historical authority when snapshot exists
- no cumulative intermediate makeup images

## Do NOT implement

- V3 CustomPainter face geometry
- extra AI-generated makeup
- 0.5K
- progressive cumulative makeup images
- broad app redesign

## Tests / validation

Test at minimum:

- 5-step tutorial
- 9-step tutorial
- dynamic step count
- Standard product card
- My Kit exact product card
- multiple lip products
- loading/retry
- next/previous
- ready-step reopen
- final preview reuse

Run the appropriate validation for every changed layer.

At minimum:

- `dart format .`
- `flutter analyze`
- `flutter test`

If Flutter dependencies changed, run `flutter pub get`.

When Android compilation should be verified, run:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

If a physical Android device is required by this phase and is available, use the project's established run command.

Fix errors introduced by this phase.

Do not hide or suppress genuine errors merely to make validation appear green.

## Done when

- variable-length tutorial works
- both modes share same visual tutorial UX
- My Makeup Kit displays exact selected product snapshot
- UI causes no duplicate AI calls


## Completion report

Use the **STANDARD V4 COMPLETION REPORT**.

Then STOP.

Do not implement V4-13 unless explicitly instructed.

---

# V4-13 — REOPEN, HISTORY, DELETION & SNAPSHOT STABILITY

Read all mandatory authority files completely before making changes.

Implement only **V4-13 — REOPEN, HISTORY, DELETION & SNAPSHOT STABILITY**.

Do not redo completed V4 phases unless the smallest safe adjustment is required to implement this phase.

## Active roles

Especially apply:

- Senior Flutter Engineer
- Senior Supabase Engineer
- Senior Product State Engineer
- Senior Regression Engineer
- Senior Privacy Engineer
- Senior My Makeup Kit / Inventory Systems Engineer

## Objective

Make dual-mode tutorials durable across app sessions and prove historical My Makeup Kit tutorials retain the exact product snapshot used when the look was created.

## Before coding

- inspect saved-look/history/deletion model
- inspect snapshot/tutorial foreign-key relationships

Do not code from assumptions when the repository, migrations, deployed state, or tests can prove the answer.

## Implement

- reopen tutorial from associated canonical result
- reload accepted manifest and ready guideline images
- resume sensible step where UX supports it
- preserve completed state
- connect to saved/history through clean references
- define cleanup/deletion relationship
- prove old tutorial product details stay stable after mutable kit edit
- prove product deletion/deactivation does not rewrite historical snapshot
- handle missing derived assets safely

## Non-negotiable rules

- reopen must not rerun manifest
- reopen must not regenerate ready steps
- historical product authority is immutable snapshot
- deletion follows deliberate privacy/retention rules
- avoid orphaned private facial assets

## Do NOT implement

- new generic history system
- broad saved-look rewrite
- generate-all
- 0.5K
- V3 geometry

## Tests / validation

Test at minimum:

- reopen after navigation
- reopen after relaunch where feasible
- ready step reused
- manifest reused
- product renamed after look
- product deleted/deactivated after look
- missing guideline asset
- deleted canonical preview
- cross-user denial

Run the appropriate validation for every changed layer.

At minimum:

- `dart format .`
- `flutter analyze`
- `flutter test`

If Flutter dependencies changed, run `flutter pub get`.

When Android compilation should be verified, run:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

If a physical Android device is required by this phase and is available, use the project's established run command.

Fix errors introduced by this phase.

Do not hide or suppress genuine errors merely to make validation appear green.

## Done when

- tutorials are durable/reusable
- historical My Makeup Kit product details are stable
- deletion behavior is explicit
- no accidental regeneration


## Completion report

Use the **STANDARD V4 COMPLETION REPORT**.

Then STOP.

Do not implement V4-14 unless explicitly instructed.

---

# V4-14 — RELIABILITY, SECURITY & ABUSE HARDENING

Read all mandatory authority files completely before making changes.

Implement only **V4-14 — RELIABILITY, SECURITY & ABUSE HARDENING**.

Do not redo completed V4 phases unless the smallest safe adjustment is required to implement this phase.

## Active roles

Especially apply:

- Senior Application Security Engineer
- Senior RLS Engineer
- Senior Supabase Engineer
- Senior Reliability Engineer
- Senior Privacy Engineer
- Senior AI Abuse Prevention Engineer
- Senior My Makeup Kit / Inventory Systems Engineer
- Senior Code Reviewer

## Objective

Audit the complete dual-mode V4 system for auth, product ownership, RLS, privacy, manifest abuse, prompt injection, duplicate-cost attacks, and silent fallbacks.

## Before coding

- inspect every V4 endpoint/table/storage policy/client request
- identify attacker-controlled IDs/strings
- inspect logs/telemetry

Do not code from assumptions when the repository, migrations, deployed state, or tests can prove the answer.

## Implement

- audit JWT/auth
- cross-user preview/tutorial access
- kit/snapshot ownership
- AI-selected product ID validation
- source-mode tampering
- manifest/category tampering
- model/resolution/prompt manipulation
- duplicate manifest/guideline requests
- retry/regeneration spam
- prompt injection from product metadata/client input
- request bounds/rate limits
- signed URL/image/base64/private logging
- partial writes/stale state
- model/no-fallback behavior
- fix proven high-risk issues

## Non-negotiable rules

- never disable RLS
- never make private buckets public
- never bypass JWT
- never weaken ownership
- never silently switch modes
- never silently substitute Gemini model
- never silently create fixed nine-step manifest
- never accept invented product IDs

## Do NOT implement

- broad unrelated security rewrite
- 0.5K
- V3 merge
- new product features

## Tests / validation

Test at minimum:

- cross-user kit attack
- cross-user snapshot attack
- cross-user tutorial attack
- fake product ID
- wrong-category product ID
- source-mode tampering
- manifest injection
- duplicate requests
- rate-limit path
- expired JWT
- private log review

Run the appropriate validation for every changed layer.

At minimum:

- `dart format .`
- `flutter analyze`
- `flutter test`

If Flutter dependencies changed, run `flutter pub get`.

When Android compilation should be verified, run:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

If a physical Android device is required by this phase and is available, use the project's established run command.

Fix errors introduced by this phase.

Do not hide or suppress genuine errors merely to make validation appear green.

## Done when

- no obvious high-risk ownership/privacy/cost-abuse issue remains
- server remains authority for ownership/manifest inclusion
- silent fallback paths are absent


## Completion report additions

```text
SECURITY FINDINGS:
SEVERITY:
FIX STATUS:
EVIDENCE:
REMAINING EXTERNAL CONFIGURATION:
```

## Completion report

Use the **STANDARD V4 COMPLETION REPORT**.

Then STOP.

Do not implement V4-15 unless explicitly instructed.

---

# V4-15 — VISUAL MANIFEST QA, GUIDELINE QA & PROMPT OPTIMIZATION

Read all mandatory authority files completely before making changes.

Implement only **V4-15 — VISUAL MANIFEST QA, GUIDELINE QA & PROMPT OPTIMIZATION**.

Do not redo completed V4 phases unless the smallest safe adjustment is required to implement this phase.

## Active roles

Especially apply:

- Senior Gemini AI Engineer
- Senior Prompt Engineer
- Senior Multimodal QA Engineer
- Senior Regression Engineer
- Senior Product Quality Engineer
- Senior AI Cost Optimization Engineer
- Senior My Makeup Kit / Inventory Systems Engineer

## Objective

Measure whether the dynamic manifest and 1K Flash guidelines are reliable enough for both Standard Mode and My Makeup Kit Mode. This phase is evidence-driven.

## Before coding

- prepare privacy-safe approved benchmark
- include both modes
- include complete/incomplete kits
- include subtle/strong looks and absent categories

Do not code from assumptions when the repository, migrations, deployed state, or tests can prove the answer.

## Implement

- benchmark manifest inclusion/exclusion across supported categories
- benchmark deterministic ordering
- benchmark uncertain behavior
- benchmark `kit_preview_mismatch` detection
- benchmark guideline final-preview fidelity/category isolation/no-pigment/identity preservation
- benchmark My Makeup Kit product correctness
- record first-pass success/retry/latency/duplicate-call evidence
- test POCO X3 GT readability when available
- optimize prompts only from observed failures
- version every material prompt change

## Non-negotiable rules

- no generic placement to improve scores
- no hardcoded geometry
- no style-to-step templates
- no silent model switch
- production stays 1K
- no endless regenerate-until-good
- no fabricated percentages

## Do NOT implement

- new features
- production 0.5K switch
- V3 CustomPainter
- unbounded QA regeneration

## Tests / validation

Test at minimum:

- manifest present/absent measured evidence
- eyeliner
- eyeshadow
- eyebrows
- contour
- lips
- blush
- foundation
- concealer
- highlighter
- Standard Mode
- My Kit complete
- My Kit incomplete
- visible category without selected product
- snapshot product display correctness

Run the appropriate validation for every changed layer.

At minimum:

- `dart format .`
- `flutter analyze`
- `flutter test`

If Flutter dependencies changed, run `flutter pub get`.

When Android compilation should be verified, run:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

If a physical Android device is required by this phase and is available, use the project's established run command.

Fix errors introduced by this phase.

Do not hide or suppress genuine errors merely to make validation appear green.

## Done when

- manifest/guideline quality has measured evidence
- prompt changes are versioned
- PASS / PASS WITH RESTRICTIONS / FAIL recommendation produced
- production remains 1K


## Completion report additions

```text
BENCHMARK SAMPLE SIZE:
STANDARD MODE SAMPLES:
MY MAKEUP KIT SAMPLES:
MANIFEST INCLUSION FINDINGS:
MANIFEST EXCLUSION FINDINGS:
KIT PREVIEW MISMATCH FINDINGS:
FIRST-PASS GUIDELINE SUCCESS RATE:
GUIDELINE-ONLY FAILURE RATE:
IDENTITY-DRIFT OBSERVATIONS:
FINAL-PREVIEW FIDELITY OBSERVATIONS:
PROMPT VERSIONS TESTED:
RECOMMENDATION:
PASS / PASS WITH RESTRICTIONS / FAIL
```

## Completion report

Use the **STANDARD V4 COMPLETION REPORT**.

Then STOP.

Do not implement V4-16 unless explicitly instructed.

---

# V4-16 — END-TO-END DEVICE QA & QUALITY BASELINE LOCK

Read all mandatory authority files completely before making changes.

Implement only **V4-16 — END-TO-END DEVICE QA & QUALITY BASELINE LOCK**.

Do not redo completed V4 phases unless the smallest safe adjustment is required to implement this phase.

## Active roles

Especially apply:

- Senior Integration Test Engineer
- Senior Mobile QA Engineer
- Senior Production Debugging Engineer
- Senior Release Engineer
- Senior Security Engineer
- Senior Code Reviewer
- Senior My Makeup Kit / Inventory Systems Engineer

## Objective

Prove the complete V4 system works with both recommendation modes, real backend/private storage, dynamic manifest analysis, and real 1K Flash guideline generation. New feature development is forbidden except minimal remediation of proven V4-16 defects.

## Before coding

- confirm V4-15 recommendation permits baseline consideration
- verify current branch/status
- verify correct Supabase environment
- verify device availability

Do not code from assumptions when the repository, migrations, deployed state, or tests can prove the answer.

## Implement

- validate Standard Mode: auth → selfie → analysis → style → brand-neutral recommendation → Pro preview → dynamic manifest → 1K tutorial → reopen
- validate My Makeup Kit: save owned products → selfie → analysis → style → owned-products-only recommendation → server validation → immutable snapshot → Pro preview → dynamic manifest → 1K tutorial → exact snapshot product per relevant step → reopen
- validate incomplete-kit journey
- validate dynamic step count/order and absent-category omission
- validate canonical final preview reuse at tutorial end
- validate accepted manifest and ready-step reuse without duplicate paid calls
- validate auth/RLS/private storage
- validate history/reopen/snapshot stability
- validate regression of auth/preview/before-after/save/history/navigation
- validate no V3 code introduced

## Non-negotiable rules

- do not merge to `main`
- do not push automatically
- do not start 0.5K optimization
- do not declare ready without evidence
- do not hide blockers

## Do NOT implement

- new unrelated features
- silent quality downgrade
- automatic merge/push
- V3 geometry

## Tests / validation

Test at minimum:

- Standard Mode E2E
- My Makeup Kit E2E
- incomplete kit E2E
- dynamic subset manifest
- reopen no-regeneration
- snapshot stability
- slow network
- failure/retry
- back navigation
- cross-user protection
- POCO X3 GT readability

Run the appropriate validation for every changed layer.

At minimum:

- `dart format .`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug --dart-define-from-file=config/development.json`
- `flutter run --dart-define-from-file=config/development.json` when physical device is available

If Flutter dependencies changed, run `flutter pub get`.

When Android compilation should be verified, run:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

If a physical Android device is required by this phase and is available, use the project's established run command.

Fix errors introduced by this phase.

Do not hide or suppress genuine errors merely to make validation appear green.

## Done when

- both source modes work end-to-end
- dynamic manifest follows Source of Truth
- My Makeup Kit uses only validated owned products
- tutorial shows exact immutable product data
- guidelines remain 1K and canonical-preview-grounded
- no high-severity blocker remains
- duplicate protections are proven
- quality baseline explicitly LOCKED or NOT LOCKED


## Completion report additions

```text
STANDARD MODE END-TO-END:
MY MAKEUP KIT END-TO-END:
INCOMPLETE KIT STATUS:
DYNAMIC MANIFEST STATUS:
REAL DEVICE STATUS:
LIVE GEMINI MANIFEST STATUS:
LIVE GEMINI GUIDELINE STATUS:
PRODUCT OWNERSHIP STATUS:
SNAPSHOT STABILITY STATUS:
DUPLICATE-CALL STATUS:
RLS / STORAGE STATUS:
VISUAL QUALITY STATUS:
REGRESSION STATUS:
HIGH-SEVERITY BLOCKERS:
QUALITY BASELINE:
LOCKED / NOT LOCKED
```

## Completion report

Use the **STANDARD V4 COMPLETION REPORT**.

Then STOP.

Do not implement V4-17 unless explicitly instructed.

---


# FINAL EXECUTION RULE

For Codex and Claude Code Pro using Opus 5:

```text
ONE PHASE
↓
READ CODEX MASTER GUIDE
↓
READ V4 SOURCE OF TRUTH
↓
READ CURRENT V4 PHASE PROMPT
↓
INSPECT ACTUAL CODE / STATE
↓
IMPLEMENT ONLY AUTHORIZED SCOPE
↓
TEST
↓
REPORT EVIDENCE
↓
STOP
```

Never:

```text
ONE PHASE
↓
IMPLEMENT
↓
ASSUME SUCCESS
↓
AUTO-CONTINUE
```

The permanent V4 product flow is:

```text
STANDARD MODE
or
MY MAKEUP KIT MODE
        ↓
VALIDATED LOOK PLAN
        ↓
GEMINI 3 PRO CANONICAL FINAL PREVIEW
        ↓
ORIGINAL + FINAL VISUAL COMPARISON
        ↓
DYNAMIC RELEVANT STEP MANIFEST
        ↓
GEMINI 3.1 FLASH IMAGE 1K
        ↓
GUIDELINES ONLY
```

For My Makeup Kit:

```text
AI SELECTS ONLY PROVIDED PRODUCT IDS
        ↓
SERVER OWNERSHIP + CATEGORY VALIDATION
        ↓
IMMUTABLE LOOK PRODUCT SNAPSHOT
```

No invented products.

No fixed nine-step inclusion.

No cumulative intermediate AI makeup images.

My Makeup Kit and the dynamic visual manifest are part of V4 from the beginning. They are not later tutorial retrofits.

