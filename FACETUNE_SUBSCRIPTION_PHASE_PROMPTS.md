# FaceTune - SUBSCRIPTION V1 PHASE PROMPTS

**Project Path:** `C:\Users\Kurt\facetune`  
**Project Name:** FaceTune  
**Tagline:** Your AI Makeup Artist  
**Primary Platform:** Android  
**Primary Test Device:** POCO X3 GT  
**Framework:** Flutter  
**Language:** Dart  
**Backend:** Supabase  
**State Management:** Riverpod  
**Architecture:** Clean Architecture + Repository Pattern + Feature-First Structure  
**AI Provider:** Google Gemini API, server-side only  
**Subscription Business Authority:** `FACETUNE_SUBSCRIPTION_SOURCE_OF_TRUTH.md`  
**Shared Subscription/Admin Contract:** `FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md`  
**Web Admin Authority:** `FACETUNE_WEB_ADMIN_SOURCE_OF_TRUTH.md`  
**This Phase File:** `FACETUNE_SUBSCRIPTION_PHASE_PROMPTS.md`  
**Shared Contract Version:** `subscription_admin_contract_v1`  
**Primary User-Facing Billable Unit:** AI Look  
**V1 Public Plans:** Free, Plus, Pro, Salon Pro  
**V1 Internal Research Entitlement:** Salon Pilot  

---

# 0. PURPOSE

This file contains the only authorized implementation phases for **FaceTune Subscription V1**.

It exists to translate the approved Subscription Source of Truth into controlled implementation work without allowing a coding agent to reinterpret business rules, rewrite protected FaceTune AI behavior, invent store behavior, or continue automatically through later phases.

This file governs implementation of:

- subscription domain architecture
- plan identifiers and typed contracts
- subscription persistence
- entitlements
- AI Look usage accounting
- reserve / commit / release semantics
- allowance enforcement
- Final Makeup Preview subscription gating
- Flutter subscription state
- remaining-AI-Look UX
- subscription/paywall presentation
- Google Play Billing integration
- server-side purchase verification
- subscription lifecycle reconciliation
- renewal / cancellation / expiration behavior
- restore purchases
- Free entitlement compatibility
- Salon Pilot backend compatibility
- sanitized telemetry and cost measurement
- security hardening
- concurrency and idempotency
- real-device and sandbox validation

This file does **not** implement the FaceTune Web Admin.

Web Admin implementation belongs only to:

```text
FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md
```

This file must not redefine pricing, allowances, AI Look meaning, plan behavior, or admin semantics that already belong to higher authorities.

---

# 1. HOW TO USE THIS FILE

1. Keep this file in the FaceTune project root beside the three subscription/admin authority files.
2. Use OpenAI Codex or Claude Code Pro only with the explicitly selected phase prompt.
3. Run **exactly one SUB-* phase at a time**.
4. Paste only the current phase prompt into the coding agent.
5. Never ask the coding agent to implement the entire file in one run.
6. Never ask the coding agent to continue automatically.
7. Review the completion report and actual diff before starting the next phase.
8. Test each phase before approving the next phase.
9. After SUB-15, perform the final Subscription acceptance review before beginning `FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md`.
10. A completion report is evidence, not proof. Code, migrations, tests, deployed state, provider responses, and real-device behavior win when they disagree with stale reports.

Execution pattern:

```text
READ AUTHORITIES
        ↓
RUN ONE SUB-* PHASE
        ↓
VALIDATE
        ↓
REVIEW DIFF + EVIDENCE
        ↓
PASS / FIX
        ↓
STOP
        ↓
ONLY THEN START NEXT PHASE
```

Forbidden execution pattern:

```text
"Implement subscriptions"
        ↓
Agent edits every layer at once
        ↓
Database + billing + AI + UI change together
        ↓
Nobody knows which assumption broke production
```

---

# 2. MANDATORY AUTHORITY ORDER FOR EVERY PHASE

Before making any change, the coding agent must read the relevant authorities in this order:

```text
1. CODEX_MASTER_GUIDE.md
2. Current approved FaceTune / V4 authority file(s) relevant to the touched behavior
3. FACETUNE_SUBSCRIPTION_SOURCE_OF_TRUTH.md
4. FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md
5. FACETUNE_WEB_ADMIN_SOURCE_OF_TRUTH.md only when cross-system compatibility is relevant
6. FACETUNE_SUBSCRIPTION_PHASE_PROMPTS.md
7. Latest completion report(s) for prior completed Subscription phases, when available
8. Actual source code, migrations, policies, Edge Functions, tests, configuration,
   deployed Supabase state, provider/store state, and real-device evidence relevant to the phase
```

Authority rules:

1. Existing protected FaceTune V4 / AI authorities remain highest authority for protected AI behavior, Final Preview generation, Tutorial behavior, My Makeup Kit behavior, model configuration, prompt configuration, retry behavior, and AI lifecycle.
2. `FACETUNE_SUBSCRIPTION_SOURCE_OF_TRUTH.md` is highest authority for subscription business rules, plans, pricing, allowances, AI Look semantics, lifecycle meaning, and user-facing subscription meaning.
3. `FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md` is highest authority for shared identifiers, statuses, fields, idempotency semantics, adjustment semantics, and subscription/admin compatibility.
4. `FACETUNE_WEB_ADMIN_SOURCE_OF_TRUTH.md` governs later Admin behavior only. It does not authorize building Web Admin during Subscription phases.
5. This file authorizes implementation scope one phase at a time.
6. A phase prompt may narrow scope but may not override a Source of Truth.
7. Completion reports are evidence, not authority.
8. Real code, migrations, tests, provider responses, and production/device behavior must be inspected rather than guessed.

If an authority conflict cannot be safely reconciled:

> **STOP. Report the exact conflict. Do not invent a silent compromise.**

---

# 3. MANDATORY SYSTEM ROLE FOR EVERY SUBSCRIPTION PHASE

Act simultaneously as a production engineering team composed of:

- Principal Software Engineer
- Principal Software Architect
- Principal Backend Engineer
- Senior Full-Stack Engineer
- Senior Flutter Engineer
- Senior Flutter Developer
- Senior Dart Engineer
- Senior Mobile Application Engineer
- Senior Riverpod / Product State Engineer
- Senior Backend Engineer
- Senior Backend Developer
- Senior Supabase Engineer
- Senior PostgreSQL Engineer
- Senior Database Migration Engineer
- Senior Row Level Security Engineer
- Senior TypeScript / Deno Engineer
- Senior API Integration Engineer
- Senior Subscription Systems Architect
- Senior Subscription Systems Engineer
- Senior Entitlements Engineer
- Senior Billing Integration Engineer
- Senior Google Play Billing Engineer
- Senior App Store / In-App Purchase Compatibility Engineer for future-safe contracts only
- Senior Domain Modeling Engineer
- Senior Distributed Systems Engineer
- Senior Transaction Engineer
- Senior Idempotency Engineer
- Senior Async / Concurrency Engineer
- Senior Authentication Engineer
- Senior Authorization Engineer
- Senior Application Security Engineer
- Senior Privacy Engineer
- Senior Reliability Engineer
- Senior Observability Engineer
- Senior Performance Engineer
- Senior AI Systems Integration Engineer
- Senior AI Cost Optimization / FinOps Engineer
- Senior QA Engineer
- Senior Regression Engineer
- Senior Integration Test Engineer
- Senior Security Test Engineer
- Senior Production Debugging Engineer
- Senior Release Engineer
- Senior Code Reviewer
- Senior Mobile UI/UX Engineer when UI is in scope
- Senior Accessibility Engineer when UI is in scope

Do not behave as a blind code generator.

You must:

- inspect first
- prove current behavior from actual code
- challenge stale documentation
- distinguish business rules from implementation assumptions
- distinguish provider facts from remembered provider behavior
- reuse valid current architecture
- prefer the smallest production-safe change
- preserve valid uncommitted work
- preserve protected V4 behavior
- test the exact layer changed
- stop when the current phase is complete

---

# 4. GLOBAL ENGINEERING PRIORITIES

Every Subscription phase must prioritize:

1. correctness
2. entitlement integrity
3. prevention of duplicate or incorrect AI Look consumption
4. preservation of existing working FaceTune behavior
5. server authority
6. billing verification integrity
7. security
8. privacy
9. idempotency
10. concurrency safety
11. auditability
12. reliability
13. maintainability
14. testability
15. AI cost control
16. performance
17. user clarity
18. visual polish

Do not trade entitlement correctness for implementation speed.

Do not move authoritative business logic into Flutter for convenience.

Do not rewrite a working feature when a smaller integration seam is sufficient.

---

# 5. GLOBAL GIT SAFETY

Before every phase:

```powershell
git branch --show-current
git status
```

Also inspect, when relevant:

```powershell
git log -n 10 --oneline
git diff
git diff --staged
```

Do not assume a branch name or HEAD from an old report.

Do not automatically create or switch branches.

If the current phase or latest user instruction explicitly requires a branch and the current branch differs:

> **STOP and report the mismatch. Do not switch automatically.**

Never automatically run:

```text
git reset --hard
git clean -fd
git restore .
git checkout -- .
git stash
git stash pop
git stash drop
git merge
git rebase
git cherry-pick
git push
git push --force
git push --force-with-lease
```

Do not:

- delete branches
- rewrite history
- discard unrelated uncommitted work
- overwrite unrelated files
- commit unless explicitly instructed
- push unless explicitly instructed

A dirty working tree is not permission to clean it.

If valid user work exists, preserve it.

---

# 6. GLOBAL ARCHITECTURE RULES

Preserve the established project architecture:

```text
Flutter
Clean Architecture
Repository Pattern
Feature-First Structure
Riverpod
Supabase
Server-authoritative privileged operations
```

Permanent rules:

- no business logic inside widgets
- no subscription authority inside presentation widgets
- no direct privileged entitlement mutation from Flutter widgets
- no God classes
- no God widgets
- no God repositories
- no raw `Map<String, dynamic>` flowing through presentation when typed models are practical
- no duplicate entitlement calculators in multiple layers
- no scattered pricing or allowance constants throughout Flutter
- no client-side premium truth such as an authoritative `bool isPremium`
- no arbitrary plan strings when controlled typed plan identifiers exist
- no duplicate backend concepts merely because conceptual Source-of-Truth names differ from current schema names
- inspect existing schema before adding tables
- inspect existing domain before adding models
- inspect existing data sources before adding parallel data sources
- prefer immutable domain models where practical
- keep error translation centralized
- keep provider-specific details behind appropriate abstractions
- do not introduce abstraction layers with no concrete testability or maintainability benefit

---

# 7. PROTECTED FACETUNE / V4 BOUNDARIES

Subscription wraps the existing Final Makeup Preview lifecycle. It does not redesign the AI product.

The current protected architecture includes, subject to the latest actual repository authority:

- canonical Final Makeup Preview as the highest final-look artifact
- server-side Gemini only
- current Final Preview renderer configuration
- current Final Preview prompt and request contract
- current Final Preview persistence
- current Standard Mode behavior
- current My Makeup Kit ownership validation
- immutable selected-product snapshots
- current Tutorial manifest architecture
- current Tutorial guideline rendering architecture
- current Tutorial prompt/version rules
- current retry rules
- current History
- current Saved Looks
- current result/reopen behavior
- accepted loading UX
- accepted navigation behavior

The expected Subscription integration is conceptually:

```text
USER REQUESTS NEW FINAL MAKEUP PREVIEW
        ↓
AUTHENTICATE
        ↓
RESOLVE ENTITLEMENT
        ↓
CHECK AVAILABLE AI LOOK CAPACITY
        ↓
RESERVE ONE AI LOOK
        ↓
EXISTING FINAL PREVIEW GENERATION
        ↓
EXISTING VALIDATION / PERSISTENCE
        ↓
USABLE PERSISTED CANONICAL FINAL PREVIEW EXISTS?
        ├── YES → COMMIT EXACTLY ONE AI LOOK
        └── NO  → RELEASE RESERVATION WHEN FAILURE IS AUTHORITATIVELY KNOWN
```

Subscription phases must not:

- switch Gemini models
- downgrade models for Free users
- change Final Preview prompts to reduce cost
- create a second Final Preview pipeline
- change Tutorial billing into a second user-facing AI Look
- alter Tutorial model or resolution
- alter manifest inclusion behavior
- alter My Makeup Kit ownership authority
- restore old V3 geometry logic
- introduce MediaPipe/OpenCV/TFLite
- add client-side AI calls
- move expensive AI lifecycle work into widget `build()`
- introduce subjective automatic retries

If the current repository has a later approved V4 model/prompt version than an older document, preserve the actual approved current configuration.

Do not silently revert to stale AI configuration.

---

# 8. SUBSCRIPTION V1 HARD LOCKS

Approved plan semantics:

```text
FREE
Price: PHP 0
Allowance: 1 AI Look one-time
Reset: never
Rollover: none
```

```text
PLUS
Price baseline: PHP 399/month
Allowance: 3 AI Looks per verified billing period
Rollover: none
```

```text
PRO
Price baseline: PHP 899/month
Allowance: 8 AI Looks per verified billing period
Rollover: none
```

```text
SALON PRO
Price baseline: PHP 2,999/month
Allowance: 35 AI Looks per verified billing period
Account concept: 1 Makeup Artist Account
Rollover: none
No client-session quota
```

```text
SALON PILOT
Price: Complimentary / admin granted
Initial allowance: 30 AI Looks
Allowance: admin-adjustable
Publicly purchasable: no
Auto-renew: no
Automatic reset: no
Expiration: admin controlled
```

Canonical internal plan codes:

```text
free
plus
pro
salon_pro
salon_pilot
```

Do not invent alternate codes unless an explicitly approved contract revision authorizes them.

---

# 9. UNIVERSAL AI LOOK CONTRACT

Hard-lock:

> **1 AI Look = 1 successfully generated and persisted Final Makeup Preview that is usable by the user.**

One AI Look is not:

- one tap
- one HTTP request
- one Gemini request
- one Gemini token charge
- one selfie
- one face analysis
- one recommendation
- one manifest
- one Tutorial open
- one Tutorial guideline generation
- one Saved Looks open
- one History open
- one reopened existing Final Preview

A genuinely new successfully persisted Final Makeup Preview consumes one AI Look even when created from:

- the same selfie
- the same style
- a different style
- a different intensity
- Standard Mode
- My Makeup Kit
- a deliberate new variation/regeneration that produces and persists a new usable canonical Final Preview under current product rules

---

# 10. TUTORIAL BILLING HARD LOCK

Tutorial is optional and included with the AI Look.

```text
Successful Final Preview
        ↓
1 AI Look committed
        ↓
Tutorial may be opened
        ↓
0 additional user-facing AI Looks
```

Reopening Tutorial:

```text
0 additional AI Looks
```

Reopening an existing Final Preview:

```text
0 additional AI Looks
```

Tutorial provider/AI cost may still be tracked internally as technical cost.

Do not change Tutorial generation lifecycle merely to simplify subscription accounting.

---

# 11. USAGE TRANSACTION CONTRACT

Canonical states:

```text
reserved
committed
released
```

Canonical lifecycle:

```text
CHECK ENTITLEMENT
        ↓
CHECK AVAILABLE CAPACITY
        ↓
RESERVE
        ↓
GENERATE
        ↓
PERSIST
        ↓
COMMIT
```

Failure lifecycle:

```text
RESERVE
        ↓
GENERATION OR PERSISTENCE DOES NOT PRODUCE A USABLE PERSISTED FINAL PREVIEW
        ↓
RELEASE
```

Hard rule:

> **No usable persisted Final Makeup Preview = no committed AI Look consumption.**

Important timeout rule:

A client timeout, app close, lost connection, navigation away, or stale Flutter state does not automatically prove server work failed.

The server must first determine whether:

- work is still active
- a usable preview was persisted
- the operation committed
- the operation failed and can safely release

Do not release merely because Flutter stopped waiting.

---

# 12. REMAINING CAPACITY CONTRACT

The authoritative remaining capacity is server-derived.

Conceptually:

```text
effective_allowance
-
committed_usage
-
active_reserved_usage
=
available_capacity
```

Active reservations count against currently available capacity so two concurrent requests cannot oversubscribe the last AI Look.

The implementation must never permit negative remaining capacity.

Flutter may display a server-provided result but must not become authoritative by locally decrementing a counter.

---

# 13. IDEMPOTENCY HARD LOCK

Every expensive or entitlement-mutating operation that can be retried or duplicated must be idempotent.

Especially protect:

- AI Look reservation
- AI Look commit
- AI Look release
- Final Preview operation association
- purchase verification
- entitlement activation/update
- provider lifecycle reconciliation
- restore purchase reconciliation
- renewal processing
- refund/revocation processing

Use a unique operation identifier/idempotency key or equivalent proven mechanism.

Example:

```text
operation_id = ABC

Request #1 reserves ABC
Request #2 repeats ABC

Correct:
one logical reservation
one eventual commit OR release

Forbidden:
two reservations
two commits
two deductions
```

UI button disabling is useful UX but is not sufficient idempotency protection.

---

# 14. CONCURRENCY HARD LOCK

The system must safely handle:

- two simultaneous Final Preview requests
- duplicate taps
- multiple devices
- client network retry
- client timeout while server work continues
- provider callback/event duplication
- renewal while a generation is reserved
- expiration transition while a generation is reserved
- restore while entitlement already exists
- multiple provider reconciliation attempts

Critical invariant:

```text
User has 1 available AI Look
Two valid new-preview requests arrive concurrently

Allowed:
1 reservation succeeds
1 request is rejected / blocked

Forbidden:
2 reservations commit
remaining = -1
```

Atomic/transaction-safe server behavior is required where shared mutable state is involved.

---

# 15. GLOBAL SECURITY HARD LOCKS

Never:

- disable RLS
- bypass JWT verification
- trust client-provided user identity for ownership
- trust client-provided plan code as purchase proof
- trust client-provided remaining allowance
- let Flutter grant premium
- let Flutter mutate authoritative usage
- expose Supabase service-role credentials in Flutter
- expose Supabase service-role credentials in browser code
- expose Google/provider private credentials in Flutter
- log provider tokens unnecessarily
- log JWTs
- log signed private image URLs
- log image bytes/base64
- log private Gemini prompts containing unnecessary personal data
- hardcode Salon Pilot to a special email address
- grant Salon Pilot using a local debug flag in production
- make Salon Pilot unlimited

RLS is required but is not the only authorization layer.

Server-side authorization and business validation remain required.

---

# 16. GLOBAL PROVIDER / STORE RULE

Provider behavior changes over time.

For phases involving Google Play Billing, purchase verification, lifecycle, renewal, cancellation, grace periods, refund/revocation, or restore:

- verify current **official** Google Play / Android documentation at implementation time
- verify the current package/library/API compatibility with the actual repository
- verify the current Google Play Console product configuration used by the project
- verify current subscription lifecycle semantics before coding them
- prefer official provider documentation over old blogs/tutorials
- if current official behavior cannot be verified, STOP and report
- do not silently rely on remembered API versions

Do not let a stale 2024 tutorial become the payment architecture of a 2026 app. Humanity has suffered enough from copy-pasted billing code.

---

# 17. GLOBAL PRICING CONFIGURATION RULE

The approved V1 business baseline is:

```text
Plus      PHP 399/month
Pro       PHP 899/month
Salon Pro PHP 2,999/month
```

The runtime purchase UI must respect verified provider/store product configuration and localized provider price presentation where appropriate.

Do not scatter literal pricing throughout Flutter.

Do not treat a hardcoded UI price as proof of what the user purchased.

The backend must map verified provider product identity to stable internal plan codes.

The PHP 45 effective AI Look cost is a planning/research assumption, not a runtime entitlement constant.

---

# 18. GLOBAL VALIDATION RULES

Run validation appropriate to the changed layer.

For Flutter/Dart changes, when appropriate:

```powershell
flutter pub get
dart format .
flutter analyze
flutter test
```

For Android build validation when justified:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

For profile-mode physical-device validation when performance-sensitive behavior is in scope:

```powershell
flutter run --profile --dart-define-from-file=config/development.json
```

For backend changes:

- validate TypeScript/Deno according to existing project commands
- run relevant backend/unit/integration tests
- validate migration syntax and ordering
- validate RLS behavior
- validate authorization and error behavior
- verify the correct Supabase environment before any deployment

For provider/store changes:

- use sandbox/internal-test mechanisms appropriate to current Google Play tooling
- do not perform production purchase testing accidentally
- document manual Google Play Console actions exactly

Do not suppress genuine errors just to produce a green report.

Do not claim tests ran when they did not.

---

# 19. REMOTE DEPLOYMENT RULE

A phase prompt does not automatically authorize production deployment.

Before any remote migration, Edge Function deployment, or billing/provider configuration change:

- inspect Git status
- identify the exact files/configuration being deployed
- prove they belong to the current phase
- verify the linked Supabase project/environment
- verify sandbox vs production provider environment
- verify secrets are server-side
- verify RLS remains enabled
- avoid unrelated CLI/toolchain upgrades

If the phase requires deployment for validation but explicit authorization is absent:

- prepare the change
- validate locally where possible
- list the exact manual/remote action required
- STOP

Do not deploy unrelated dirty work.

---

# 20. STANDARD SUBSCRIPTION PHASE COMPLETION REPORT

Every SUB-* phase must end with this report structure.

Do not omit fields merely because nothing changed. Use `None` where appropriate.

```text
PHASE COMPLETED:

BRANCH VERIFIED:

WORKING TREE PRESERVED:

AUTHORITY FILES READ:

OBJECTIVE ACHIEVED:

FILES CREATED:

FILES MODIFIED:

FILES DELETED:
None / exact files with justification

DEPENDENCIES ADDED / REMOVED:

DATABASE / MIGRATION CHANGES:

RLS CHANGES:

EDGE FUNCTION / BACKEND CHANGES:

FLUTTER CHANGES:

SUBSCRIPTION DOMAIN CHANGES:

PLAN / PRODUCT CONFIG CHANGES:

ENTITLEMENT CHANGES:

USAGE LEDGER CHANGES:

AI LOOK ACCOUNTING CHANGES:

FINAL PREVIEW INTEGRATION CHANGES:

GOOGLE PLAY / PROVIDER CHANGES:

PURCHASE VERIFICATION CHANGES:

LIFECYCLE / RESTORE CHANGES:

SALON PILOT COMPATIBILITY CHANGES:

TELEMETRY / COST MEASUREMENT CHANGES:

PROTECTED AI / V4 REGRESSION CHECK:

SECURITY CHECK:

IDEMPOTENCY CHECK:

CONCURRENCY CHECK:

PRIVACY CHECK:

TESTS / VALIDATION:

REAL DEVICE / LIVE BACKEND / STORE SANDBOX EVIDENCE:

KNOWN LIMITATIONS:

ASSUMPTIONS NOT PROVEN:

MANUAL ACTION REQUIRED:
None / exact action

NEXT RECOMMENDED PHASE:

STOP CONFIRMATION:
No later Subscription phase was implemented.
```

A vague completion report is not acceptable.

---

# 21. PHASE EXECUTION TEMPLATE

Every phase must follow this sequence:

```text
READ AUTHORITIES
        ↓
VERIFY BRANCH + GIT STATUS
        ↓
PRESERVE VALID WORKING TREE
        ↓
INSPECT ACTUAL IMPLEMENTATION
        ↓
STATE CURRENT PHASE OBJECTIVE
        ↓
IDENTIFY MINIMUM FILES
        ↓
IDENTIFY EXPLICITLY FORBIDDEN CHANGES
        ↓
IMPLEMENT CURRENT PHASE ONLY
        ↓
FORMAT / ANALYZE / TEST
        ↓
PROVE SECURITY + REGRESSION BEHAVIOR
        ↓
REPORT EXACT EVIDENCE
        ↓
STOP
```

Do not automatically begin the next phase.

---

# SUB-0 - BASELINE ARCHITECTURE & SUBSCRIPTION INTEGRATION AUDIT

Read all mandatory authority files completely before making any changes.

Implement only **SUB-0 - BASELINE ARCHITECTURE & SUBSCRIPTION INTEGRATION AUDIT**.

This phase is **READ-ONLY** except for an explicitly requested audit/completion-report file.

## Active roles

Especially apply:

- Principal Software Architect
- Principal Backend Engineer
- Senior Flutter Engineer
- Senior Riverpod Engineer
- Senior Supabase Engineer
- Senior PostgreSQL / RLS Engineer
- Senior TypeScript / Deno Engineer
- Senior Subscription Systems Architect
- Senior Google Play Billing Engineer
- Senior Security Engineer
- Senior Integration Test Engineer
- Senior Code Reviewer

## Objective

Establish the exact current technical baseline before any subscription implementation is created.

Produce a concrete integration map based on real code and deployed evidence rather than assumptions.

## Before coding

Verify and record:

```powershell
git branch --show-current
git status
```

Inspect at minimum:

- project root structure
- `CODEX_MASTER_GUIDE.md`
- current protected FaceTune/V4 authority files
- `pubspec.yaml`
- Flutter feature/module structure
- Riverpod providers/controllers/notifiers relevant to Profile, Final Preview, Result, History, Saved Looks, and auth
- current auth/session implementation
- current Final Makeup Preview request path
- exact Edge Function(s) used by Final Preview
- exact server-side model configuration actually used today
- exact canonical Final Preview persistence path
- current generated-image/result tables
- current recommendation/analysis lineage
- current My Makeup Kit lineage and immutable snapshots
- current Tutorial/manifest architecture only enough to prove non-billable integration boundaries
- current Supabase migrations
- current RLS policies
- current storage policies
- existing subscription, entitlement, usage, purchase, receipt, billing, or product tables if any
- existing provider/billing abstractions if any
- Android package/application ID
- existing Google Play Billing dependencies if any
- existing build configuration
- current tests
- current environment/config files without exposing secrets
- currently deployed Supabase function names and schema where evidence is available

## Required audit output

Document:

1. current subscription/billing implementation status
2. exact Final Preview call path from Flutter to persisted canonical preview
3. exact safe integration seam for `reserve -> existing generation -> persist -> commit/release`
4. exact current database concepts that can be reused
5. schema gaps
6. RLS gaps
7. domain-model gaps
8. Flutter-state gaps
9. provider/billing gaps
10. tests that already exist and can be reused
11. protected files/modules that later phases should avoid modifying
12. likely minimum files for SUB-1
13. assumptions requiring runtime/provider proof

## Non-negotiable rules

- inspect, do not guess
- do not trust stale completion reports over current code
- preserve current branch and working tree
- do not switch branches
- do not clean/stash/reset user work
- do not modify production logic

## Do NOT implement

- domain models
- migrations
- RLS changes
- Edge Functions
- usage ledger
- entitlement engine
- Flutter subscription UI
- paywall
- Google Play Billing
- provider verification
- store configuration
- Final Preview changes
- telemetry changes
- Web Admin

## Validation

At minimum record:

```powershell
git branch --show-current
git status
flutter analyze
```

If baseline tests can be run without changing project state, run the relevant established suite and record results.

Do not fix unrelated pre-existing warnings/errors during the audit unless the user explicitly authorizes it.

## Done when

- the real subscription baseline is proven
- the exact Final Preview integration seam is proven
- existing reusable schema/domain code is identified
- no subscription feature code was added
- SUB-1 has a concrete minimum boundary

## Completion report

Use the **STANDARD SUBSCRIPTION PHASE COMPLETION REPORT**.

Then STOP.

Do not implement SUB-1 unless explicitly instructed.

---

# SUB-1 - SUBSCRIPTION DOMAIN MODELS & TYPED CONTRACTS

Read all mandatory authorities and the SUB-0 audit before making changes.

Implement only **SUB-1 - SUBSCRIPTION DOMAIN MODELS & TYPED CONTRACTS**.

## Active roles

Especially apply:

- Principal Software Architect
- Senior Domain Modeling Engineer
- Senior Flutter/Dart Engineer
- Senior Subscription Systems Engineer
- Senior Entitlements Engineer
- Senior QA Engineer
- Senior Code Reviewer

## Objective

Create the minimum strongly typed domain contracts required for Subscription V1 without implementing persistence, provider billing, Final Preview enforcement, or UI.

## Before coding

- verify branch and working tree
- read SUB-0 integration map
- inspect existing domain conventions
- reuse existing value-object/enums/result patterns where valid
- inspect whether any subscription/billing concepts already exist
- identify the smallest set of types needed by later phases

## Implement

Create typed domain representation for concepts equivalent to:

```text
SubscriptionPlanCode
BillingProvider
EntitlementStatus
PurchaseLifecycleStatus when a separate provider state is justified
UsageType
UsageStatus
ResetPolicy
SubscriptionPlanDefinition / ProductDefinition
SubscriptionEntitlement
SubscriptionPeriod
SubscriptionAllowance
SubscriptionUsageSummary
AI Look operation identity
Subscription access decision / generation authorization result
```

Canonical plan codes:

```text
free
plus
pro
salon_pro
salon_pilot
```

Canonical usage state:

```text
reserved
committed
released
```

Canonical entitlement concepts must support:

```text
active
grace_period
expired
suspended
revoked
```

Use `pending` only if actual architecture/provider lifecycle needs it and the Shared Contract permits it.

Represent distinctly:

- recurring billing period (`period_start`, `period_end` semantics)
- admin-granted temporary entitlement (`starts_at`, `expires_at` semantics)
- base/effective allowance where Salon Pilot adjustments later apply
- committed/reserved/remaining usage
- public vs non-public plan classification

## Non-negotiable rules

- use Shared Contract identifiers exactly
- do not invent alternate plan/status strings
- do not infer plan from price
- do not model source using ambiguous booleans when an enum/value object is appropriate
- do not hardcode provider purchase truth into Flutter domain constructors
- prefer immutable models
- keep domain provider-agnostic where practical

## Do NOT implement

- migrations
- tables
- RLS
- live repositories/data sources
- Google Play SDK
- purchase verification
- Final Preview changes
- subscription UI
- paywall
- Web Admin

## Tests / validation

Test at minimum:

- all canonical plan codes parse/serialize correctly
- unsupported plan code rejected intentionally
- entitlement statuses are controlled
- usage statuses are controlled
- Free reset semantics representable
- recurring billing period semantics representable
- Salon Pilot admin-grant/expiration semantics representable
- 3/8/35 allowance configuration is representable without scattering constants in presentation
- remaining usage cannot be represented as a silently negative user-facing value
- domain equality/serialization follows project conventions

Run:

```powershell
dart format .
flutter analyze
flutter test
```

## Done when

- later persistence/backend layers can depend on stable typed contracts
- no subscription business rule is duplicated in widgets
- no persistence/provider integration exists yet

## Completion report

Use the standard report.

Then STOP.

Do not implement SUB-2 unless explicitly instructed.

---

# SUB-2 - SUBSCRIPTION PERSISTENCE, DATABASE & RLS FOUNDATION

Read all mandatory authorities and prior completion reports.

Implement only **SUB-2 - SUBSCRIPTION PERSISTENCE, DATABASE & RLS FOUNDATION**.

## Active roles

Especially apply:

- Principal Backend Engineer
- Senior Supabase Engineer
- Senior PostgreSQL Engineer
- Senior Database Migration Engineer
- Senior RLS Engineer
- Senior Security Engineer
- Senior Privacy Engineer
- Senior Subscription Systems Engineer
- Senior Code Reviewer

## Objective

Create the minimum secure, migration-backed persistence required for Subscription V1.

## Before coding

- verify branch and working tree
- inspect every existing relevant migration/table/index/enum/RLS policy
- inspect auth user linkage conventions
- inspect generated-image/canonical-preview identifiers
- inspect any existing product/subscription/usage tables
- reuse or extend valid existing entities where possible
- do not duplicate concepts merely because the Source of Truth uses conceptual names

## Implement

Implement persistence equivalent to the required concepts, using exact project conventions after inspection.

Conceptual entities may include:

### `subscription_products`

Concerns:

```text
plan_code
display_name
publicly_purchasable
billing_provider compatibility metadata when appropriate
provider_product_id where appropriate
billing_interval
base AI Look allowance
active
created_at
updated_at
```

### `user_entitlements`

Concerns:

```text
id
user_id
plan_code
status
origin / billing_provider
provider_product_id nullable
provider subscription/transaction reference where safe and justified
period_start nullable
period_end nullable
starts_at
expires_at nullable
auto_renew where meaningful
base/effective allowance or normalized linkage according to final design
version / concurrency field when justified
created_at
updated_at
```

### `usage_ledger`

Concerns:

```text
id
user_id
entitlement_id
usage_type
operation_id
canonical_preview_id nullable until commit
status
period_start / period_end or period identity when required
reserved_at
committed_at
released_at
sanitized failure code nullable
created_at
updated_at
```

Additional provider-event or purchase-verification persistence may be deferred to SUB-10 unless a minimal table is structurally required now.

## Required database qualities

- foreign keys
- appropriate indexes
- controlled/check-constrained values where maintainable
- uniqueness/idempotency constraints
- no duplicate committed operation for the same logical `operation_id`
- no user-editable remaining-balance column used as truth when it can be derived safely
- compatibility with Free one-time entitlement
- compatibility with recurring Plus/Pro/Salon Pro periods
- compatibility with Salon Pilot admin-granted total allowance
- historical usage preservation

## RLS requirements

Normal users must not be able to:

- grant/change own paid entitlement
- grant own Salon Pilot
- edit authoritative plan/status/provider state
- insert fake committed usage
- edit/delete committed ledger history
- read another user's entitlement
- read another user's usage
- attach another user's canonical preview to their usage operation

Users may read their own sanitized subscription/usage state only according to the approved architecture.

Privileged server operations remain required.

Never disable RLS.

## Do NOT implement

- Google Play Billing
- provider purchase verification
- Final Preview gating
- paywall UI
- subscription page
- Web Admin
- manual admin grant UI
- broad auth refactor
- AI changes

## Tests / validation

Test at minimum:

- migration applies cleanly in approved local/test environment
- canonical plan/status constraints
- valid own-user read where intended
- cross-user entitlement denial
- cross-user usage denial
- normal user entitlement mutation denial
- normal user fake ledger insert/update denial
- duplicate operation uniqueness/idempotency constraint
- canonical preview ownership/link constraints where implemented
- Free semantics persistable
- Salon Pilot semantics persistable
- recurring period semantics persistable

Validate exact migration files and RLS policies.

Do not deploy remotely without explicit authorization.

## Done when

- secure persistence exists for later entitlement/usage engines
- RLS protects subscription data
- no generation or billing integration exists yet

## Completion report

Use the standard report.

Then STOP.

Do not implement SUB-3 unless explicitly instructed.

---

# SUB-3 - SERVER ENTITLEMENT RESOLUTION & ALLOWANCE ENGINE

Read all mandatory authorities and prior phase reports.

Implement only **SUB-3 - SERVER ENTITLEMENT RESOLUTION & ALLOWANCE ENGINE**.

## Active roles

Especially apply:

- Principal Backend Engineer
- Senior Subscription Systems Engineer
- Senior Entitlements Engineer
- Senior Supabase/PostgreSQL Engineer
- Senior Domain Modeling Engineer
- Senior Reliability Engineer
- Senior QA Engineer
- Senior Code Reviewer

## Objective

Implement the server-authoritative entitlement resolver and allowance calculator that can answer whether the authenticated user may begin a new Final Makeup Preview operation.

## Before coding

- verify branch/working tree
- inspect SUB-2 schema actually implemented
- inspect auth/session server conventions
- inspect existing backend service/use-case organization
- identify the smallest server-owned API/service boundary
- prove how current time is handled server-side

## Implement

The server must be able to resolve, for the authenticated user:

```text
current effective plan
entitlement status
billing/admin origin
period start/end when recurring
starts_at/expires_at when admin-granted
base allowance
effective allowance
committed usage
active reserved usage
available capacity
reset date OR expiration date
whether generation is currently authorized
sanitized denial reason
```

Canonical capacity rule:

```text
effective_allowance - committed - active_reserved = available_capacity
```

Generation authorization must account for:

- active entitlement
- provider-verified grace entitlement only where the Subscription SOT/provider rules allow it
- expired
- suspended
- revoked
- no entitlement / Free fallback semantics as designed
- zero available capacity
- future start date
- expired Salon Pilot

## Non-negotiable rules

- derive authenticated user server-side
- do not trust Flutter plan/status/remaining
- do not use device clock as billing-period authority
- do not delete historical usage to simulate reset
- do not implement provider verification yet beyond existing proven state
- do not create a second source of truth for remaining balance

## Do NOT implement

- reservation mutation
- commit/release
- Final Preview integration
- Google Play purchase
- paywall
- Web Admin

## Tests / validation

Test at minimum:

- Free unused -> 1 available
- Free used -> 0 available and no reset
- Plus 0/3 -> 3 available
- Plus 2 committed, 0 reserved -> 1 available
- Plus 2 committed, 1 reserved -> 0 available
- Pro allowance = 8
- Salon Pro allowance = 35
- Salon Pilot base 30
- Salon Pilot adjustment-capable effective allowance representation from persisted state when present
- expired blocks
- suspended blocks
- revoked blocks
- provider-entitled grace state behavior only if currently implemented/verified
- no negative available capacity
- cross-user query blocked

## Done when

- one server-owned resolver can answer generation eligibility and authoritative allowance
- Flutter has no authority over the calculation
- no usage mutation exists yet

## Completion report

Use the standard report.

Then STOP.

Do not implement SUB-4 unless explicitly instructed.

---

# SUB-4 - AI LOOK RESERVATION / COMMIT / RELEASE ENGINE

Read all mandatory authorities and prior completion reports.

Implement only **SUB-4 - AI LOOK RESERVATION / COMMIT / RELEASE ENGINE**.

## Active roles

Especially apply:

- Principal Backend Engineer
- Senior Distributed Systems Engineer
- Senior Transaction Engineer
- Senior Idempotency Engineer
- Senior Async / Concurrency Engineer
- Senior PostgreSQL Engineer
- Senior Supabase Engineer
- Senior Reliability Engineer
- Senior Security Engineer
- Senior Integration Test Engineer

## Objective

Implement the atomic server-side usage engine for one AI Look operation.

Equivalent operations:

```text
reserve AI Look
commit AI Look
release AI Look
```

Exact function/service names must follow existing project conventions.

## Before coding

- verify branch/working tree
- inspect SUB-3 entitlement resolver
- inspect ledger schema/constraints
- inspect transaction/RPC patterns already used in the repository
- inspect whether Postgres functions/RPC or Edge Function transactions are the safest established mechanism
- prove how duplicate calls are currently handled elsewhere

## Implement

### Reserve

Must:

- authenticate user
- resolve current entitlement
- resolve available capacity atomically
- create/reuse one logical reservation by `operation_id`
- reject oversubscription
- link reservation to correct entitlement/period
- return typed/sanitized result

### Commit

Must:

- locate the logical reserved operation
- verify ownership
- verify the usable canonical Final Preview belongs to the operation/user
- transition to committed exactly once
- associate stable canonical-preview lineage
- tolerate duplicate commit request idempotently

### Release

Must:

- locate the logical reservation
- verify ownership/server authority
- release only when the operation is authoritatively failed/cancelled under approved rules
- tolerate duplicate release request idempotently
- never release a committed operation

## Critical invariants

```text
reserved -> committed
```

or:

```text
reserved -> released
```

Never:

```text
committed -> released
```

through ordinary technical-failure handling.

Never create two committed usage entries for one logical operation.

## Concurrency test

With exactly one available AI Look:

```text
Request A reserve
Request B reserve concurrently
```

Expected:

```text
one succeeds
one receives quota/unavailable result
```

Not:

```text
both succeed
```

## Stale reservation strategy

Implement or define a safe reconciliation mechanism consistent with the Subscription SOT.

Do not use a naive client timer to release reservations.

A timeout must not release work that may still be generating server-side.

## Do NOT implement

- Final Preview wiring
- Google Play Billing
- subscription UI
- Web Admin
- new AI calls

## Tests / validation

Test at minimum:

- reserve success
- reserve exhausted
- duplicate reserve same operation ID
- concurrent reserve with one remaining
- commit success
- duplicate commit
- release success
- duplicate release
- release after commit rejected/no-op according to contract
- commit after release rejected according to contract
- cross-user operation access rejected
- expired/suspended/revoked entitlement cannot reserve
- ledger history remains immutable
- no negative capacity

## Done when

- the usage engine is atomic, idempotent, and concurrency-safe
- it is still not wired into Final Preview

## Completion report

Use the standard report.

Then STOP.

Do not implement SUB-5 unless explicitly instructed.

---

# SUB-5 - FINAL MAKEUP PREVIEW ENTITLEMENT INTEGRATION

Read all mandatory authorities and prior completion reports.

Implement only **SUB-5 - FINAL MAKEUP PREVIEW ENTITLEMENT INTEGRATION**.

## Active roles

Especially apply:

- Principal Software Architect
- Principal Backend Engineer
- Senior Subscription Systems Engineer
- Senior Gemini AI Systems Integration Engineer
- Senior Supabase / TypeScript-Deno Engineer
- Senior Reliability Engineer
- Senior Idempotency / Concurrency Engineer
- Senior My Makeup Kit Integration Engineer when applicable
- Senior Integration Test Engineer
- Senior Code Reviewer

## Objective

Wrap the existing Final Makeup Preview generation lifecycle with the approved AI Look entitlement transaction without changing the visual/AI behavior.

## Before coding

- verify branch/working tree
- inspect the exact current Final Preview request handler
- prove model/prompt/configuration currently used
- prove Standard and My Makeup Kit pathways
- prove current persistence success boundary
- prove current retry/idempotency behavior
- inspect whether existing `operation_id`/request correlation can be reused
- identify the smallest integration seam

## Implement

Conceptually:

```text
Authenticated user requests NEW Final Makeup Preview
        ↓
Resolve entitlement
        ↓
Reserve one AI Look
        ↓
Call EXISTING Final Preview generation flow
        ↓
Validate existing response under existing rules
        ↓
Persist canonical Final Preview using EXISTING persistence authority
        ↓
Only after usable persisted result exists
        ↓
Commit reserved AI Look exactly once
```

Failure:

```text
Reserved
        ↓
No usable persisted canonical Final Preview
        ↓
Authoritative failure confirmed
        ↓
Release
```

Client timeout/navigation:

```text
DO NOT blindly release
```

Reconcile from server operation state.

## Hard locks

Do not modify:

- Final Preview model
- model fallback rules
- prompt
- prompt version
- image resolution/quality settings
- current recommendation behavior
- Standard Mode brand-neutral authority
- My Makeup Kit server-owned product authority
- immutable product snapshot semantics
- manifest analyzer
- Tutorial rendering
- Tutorial billing rule
- accepted retry behavior

Do not add a cheaper AI path for Free/Plus users.

Do not call Gemini from Flutter.

## Do NOT implement

- subscription/paywall UI
- Google Play Billing
- provider verification
- Web Admin

## Tests / validation

Use mocks/fakes for Gemini where practical.

Test at minimum:

- successful Standard Final Preview -> exactly one commit
- successful My Makeup Kit Final Preview -> exactly one commit
- generation failure -> release
- persistence failure with no usable result -> release
- duplicate client request does not double-generate/double-charge where current idempotency architecture supports this
- duplicate commit callback -> one commit
- client timeout + server success -> committed and result remains reopenable
- client timeout + confirmed server failure -> release
- zero remaining -> generation never reaches expensive AI call
- suspended/expired/revoked -> generation never reaches expensive AI call
- reopening existing Final Preview -> zero new reservation
- Tutorial open/reopen -> zero new user-facing AI Look
- current model unchanged
- current prompt unchanged
- Standard/My Kit regressions pass

## Done when

- every new usable persisted Final Preview consumes exactly one AI Look
- technical failure without usable persisted result consumes zero
- protected AI architecture remains unchanged

## Completion report

Use the standard report.

Then STOP.

Do not implement SUB-6 unless explicitly instructed.

---

# SUB-6 - FLUTTER SUBSCRIPTION STATE & REPOSITORY INTEGRATION

Read all mandatory authorities and prior phase reports.

Implement only **SUB-6 - FLUTTER SUBSCRIPTION STATE & REPOSITORY INTEGRATION**.

## Active roles

Especially apply:

- Senior Flutter Engineer
- Senior Dart Engineer
- Senior Riverpod Engineer
- Senior Mobile Application Engineer
- Senior Domain Modeling Engineer
- Senior Subscription Systems Engineer
- Senior Async / Concurrency Engineer
- Senior QA Engineer

## Objective

Expose authoritative server subscription/entitlement state to Flutter through the established architecture without giving Flutter business authority.

## Before coding

- verify branch/working tree
- inspect existing auth/user repositories
- inspect existing Profile state
- inspect current Riverpod patterns
- inspect error/result abstractions
- inspect app lifecycle/session refresh behavior
- identify the minimum reusable architecture

## Implement

Use project conventions equivalent to:

```text
Remote Data Source
        ↓
Repository implementation
        ↓
Domain Repository contract
        ↓
Use Case(s)
        ↓
Riverpod Controller / Notifier
        ↓
Presentation
```

Flutter must be able to consume a typed authoritative summary such as:

```text
plan code / display name
entitlement status
billing/admin source
limit/effective allowance
committed usage
reserved usage when product UX needs it
remaining/available capacity
period end / reset date
expiration date
renewal state where safely available
```

## State requirements

Explicit states should distinguish at least:

- initial/loading
- ready
- refreshing
- unauthenticated/session failure
- recoverable network failure
- entitlement unavailable/inconsistent

Do not use ambiguous booleans as the entire state model.

## Async rules

- widget rebuild must not create duplicate backend calls unnecessarily
- paid AI generation must never originate from `build()`
- subscription refresh should follow deliberate lifecycle events
- stale responses must not overwrite newer state
- logout/session change must clear user-specific subscription state safely

## Non-negotiable rules

- server remains authoritative
- Flutter may not locally grant premium
- Flutter may not locally decrement authoritative balance as the only source of truth
- Flutter may optimistically disable UX only if eventual server refresh remains authoritative

## Do NOT implement

- full subscription/paywall UI
- Google Play purchases
- provider verification
- Web Admin
- redesign of existing Profile

## Tests / validation

Test at minimum:

- Free summary mapping
- Plus mapping
- Pro mapping
- Salon Pro mapping
- Salon Pilot mapping
- loading/success/error
- session logout
- stale async response handling
- authoritative remaining displayed from server model
- no AI calls introduced by subscription state rebuilds

Run:

```powershell
dart format .
flutter analyze
flutter test
```

## Done when

- Flutter has a typed, testable subscription state path
- no presentation layer owns entitlement truth

## Completion report

Use the standard report.

Then STOP.

Do not implement SUB-7 unless explicitly instructed.

---

# SUB-7 - REMAINING AI LOOKS UX & GENERATION GUARD PRESENTATION

Read all authorities and prior reports.

Implement only **SUB-7 - REMAINING AI LOOKS UX & GENERATION GUARD PRESENTATION**.

## Active roles

Especially apply:

- Senior Flutter Engineer
- Senior Riverpod Engineer
- Senior Mobile UI/UX Engineer
- Senior Accessibility Engineer
- Senior Subscription Product Engineer
- Senior QA Engineer

## Objective

Make remaining AI Look allowance understandable at the decision points where it matters, without redesigning unrelated screens or turning the entire application into a quota dashboard.

## Before coding

- verify branch/working tree
- inspect accepted current Profile UI
- inspect current Final Preview CTA screen
- inspect current success/error flow
- inspect existing design system/components
- inspect server subscription state added in SUB-6
- preserve accepted Luminous Beauty Intelligence design language

## Implement

At minimum, where current UX structure supports it:

### Profile / Subscription summary

Examples:

```text
FaceTune Plus
2 of 3 AI Looks remaining
Resets Oct 7
```

```text
Salon Pilot
Research Access
19 of 30 AI Looks remaining
Expires Nov 7
```

### Before Generate Makeup Preview

Small, non-blocking context:

```text
2 AI Looks remaining this month
```

### One remaining

```text
1 AI Look remaining
```

### After successful committed Final Preview

Subtle feedback may show:

```text
AI Look created · 1 remaining
```

Only after authoritative state confirms success.

### Zero paid monthly

```text
You've used all your AI Looks.
Your allowance resets on <verified date>.
```

### Free exhausted

```text
0 of 1 complimentary AI Look remaining.
Upgrade to create more AI Looks.
```

### Salon Pilot exhausted

```text
Salon Pilot allowance used
0 of <effective allowance> AI Looks remaining
```

Do not show a consumer store purchase prompt as though Salon Pilot were a public store product.

## Non-negotiable rules

- display backend-authoritative values
- do not compute billing dates from phone clock
- do not display internal reservation/operation IDs to normal users
- do not block reopening History/Saved/Preview/Tutorial after entitlement exhaustion
- do not change existing Final Preview AI lifecycle

## Do NOT implement

- plan purchase cards
- Google Play Billing
- provider verification
- Web Admin
- major navigation redesign
- unrelated Profile redesign

## Tests / validation

Test at minimum:

- Free unused/exhausted
- Plus normal/low/zero
- Pro normal/low/zero
- Salon Pro normal/low/zero
- Salon Pilot active/expired/zero
- reset vs expiration wording
- loading/error state does not show invented quota
- existing History/Saved/reopen flows unaffected
- POCO X3 GT layout sanity when device testing is available

## Done when

- users can understand remaining allowance at appropriate moments
- quota UI is informative, not authoritative
- unrelated accepted UI remains stable

## Completion report

Use the standard report.

Then STOP.

Do not implement SUB-8 unless explicitly instructed.

---

# SUB-8 - SUBSCRIPTION / PAYWALL UI

Read all authorities and prior reports.

Implement only **SUB-8 - SUBSCRIPTION / PAYWALL UI**.

## Active roles

Especially apply:

- Senior Flutter Engineer
- Senior Mobile UI/UX Engineer
- Senior Accessibility Engineer
- Senior Subscription Product Engineer
- Senior Riverpod Engineer
- Senior QA / Regression Engineer

## Objective

Create the production-ready subscription selection/paywall presentation for public plans without implementing Google Play purchase mechanics yet.

## Before coding

- verify branch/working tree
- inspect existing FaceTune premium design tokens/components
- inspect Profile/navigation entry point
- inspect SUB-6 subscription state
- inspect current pricing/product configuration representation
- inspect current app typography, icon family, spacing, CTA patterns

## Public plans displayed

```text
Free
Plus
Pro
Salon Pro
```

Salon Pilot must not appear as a purchasable public card.

## Approved V1 baseline content

```text
Free
PHP 0
1 one-time AI Look
```

```text
Plus
PHP 399/month baseline
3 AI Looks per billing period
```

```text
Pro
PHP 899/month baseline
8 AI Looks per billing period
```

```text
Salon Pro
PHP 2,999/month baseline
35 AI Looks per billing period
1 Makeup Artist Account
```

The later live purchase price display must use provider-localized product information where required. Do not architect the UI so literal PHP strings are the only possible price source.

## UI requirements

- polished FaceTune visual language
- restrained premium beauty aesthetic
- no emoji icons
- use the existing vector icon family
- clear current-plan state
- clear allowance comparison
- clear CTA state
- clear restore-purchase entry point placeholder/action shell if architecture needs it for SUB-11
- loading/error states
- accessibility labels
- no deceptive urgency
- no invented annual savings
- no fake discount

## Non-goals

Do not add:

- annual plan
- free trial unless separately approved
- add-on packs
- lifetime
- unlimited AI
- multi-seat Salon
- promo codes
- affiliate/referral
- external Stripe checkout

## Do NOT implement

- actual Google Play purchase request
- server purchase verification
- Web Admin
- store lifecycle
- AI changes

## Tests / validation

Test at minimum:

- current plan state
- Free exhausted -> paywall entry
- Plus/Pro/Salon Pro cards
- Salon Pilot not publicly purchasable
- loading provider-price placeholder compatible with next phase
- error state
- accessibility semantics
- no overflow on POCO X3 GT dimensions

Run Flutter validation.

## Done when

- public subscription/paywall UI exists
- it is not yet authorized to grant entitlement
- no fake premium state is created

## Completion report

Use the standard report.

Then STOP.

Do not implement SUB-9 unless explicitly instructed.

---

# SUB-9 - GOOGLE PLAY BILLING CLIENT INTEGRATION

Read all authorities and prior reports.

Implement only **SUB-9 - GOOGLE PLAY BILLING CLIENT INTEGRATION**.

## Active roles

Especially apply:

- Senior Google Play Billing Engineer
- Senior Billing Integration Engineer
- Senior Flutter Engineer
- Senior Android Engineer
- Senior Security Engineer
- Senior Subscription Systems Engineer
- Senior QA / Integration Test Engineer

## Objective

Integrate the Android client with the current supported Google Play subscription purchase mechanism while preserving backend authority.

## Mandatory current-provider verification before coding

Before editing billing code:

1. inspect current `pubspec.yaml` and Android configuration
2. inspect whether a billing package already exists
3. verify current official Google Play Billing requirements
4. verify the current compatible Flutter integration/package/API version
5. verify the app package ID
6. verify configured subscription product IDs in the approved environment
7. verify current Google Play test/internal-track requirements
8. record the official source/version/date used for provider-dependent decisions

If official current documentation cannot be accessed:

> **STOP and report. Do not implement billing from memory.**

## Implement

Client responsibilities may include, according to verified current provider APIs:

- query public subscription products
- expose localized store product metadata to UI
- initiate purchase flow
- receive purchase updates
- handle pending/cancel/error outcomes
- send provider purchase evidence/token/reference to FaceTune backend for verification
- trigger entitlement refresh after server verification
- support lifecycle-safe listener setup/teardown

Conceptual flow:

```text
Flutter
        ↓
Google Play Billing
        ↓
Provider purchase result / token
        ↓
FaceTune backend verification request
```

## Hard lock

Forbidden:

```dart
if (purchaseSucceeded) {
  isPremium = true;
}
```

Flutter purchase success is not entitlement authority.

Flutter must not map an unverified arbitrary client plan directly to premium access.

## Pending purchase

Pending must not be treated as active entitlement until current verified provider/server rules permit it.

## Non-negotiable rules

- no service account/provider private key in Flutter
- no purchase-token logging
- no hardcoded server bypass
- no test entitlement grant hidden in release build
- no Salon Pilot through Google Play
- use provider localized price metadata for live purchase UI where appropriate

## Do NOT implement

- server-side verification logic beyond required request contract stub/adapter
- lifecycle reconciliation
- Web Admin
- AI changes

## Tests / validation

Use mocks/fakes for client billing where practical.

Test at minimum:

- product query success
- product query failure
- unavailable product
- purchase initiation
- pending result
- user cancellation
- provider error
- purchase update listener duplication protection
- purchase evidence forwarded server-side
- client does not grant entitlement itself
- Salon Pilot cannot be purchased

Document manual Google Play Console setup required.

## Done when

- Flutter can interact with Google Play safely
- entitlement still depends on server verification

## Completion report

Use the standard report.

Then STOP.

Do not implement SUB-10 unless explicitly instructed.

---

# SUB-10 - SERVER-SIDE GOOGLE PLAY PURCHASE VERIFICATION & ENTITLEMENT ACTIVATION

Read all authorities and prior reports.

Implement only **SUB-10 - SERVER-SIDE GOOGLE PLAY PURCHASE VERIFICATION & ENTITLEMENT ACTIVATION**.

## Active roles

Especially apply:

- Principal Backend Engineer
- Senior Google Play Billing Engineer
- Senior Payments Integration Engineer
- Senior Subscription Systems Engineer
- Senior Supabase / TypeScript-Deno Engineer
- Senior Authentication / Authorization Engineer
- Senior Security Engineer
- Senior Idempotency Engineer
- Senior Integration Test Engineer

## Objective

Verify public Android subscription purchases server-side using current official Google provider mechanisms and activate/update FaceTune entitlement only from verified provider evidence.

## Mandatory provider verification

Before coding:

- verify current official server-side Google Play subscription verification API/mechanism
- verify authentication requirements
- verify current response/state semantics
- verify acknowledgement requirements and which side owns them in the chosen architecture
- verify product/base-plan/offer identifiers used by the actual project
- verify provider event/reconciliation approach needed by current APIs
- record the official provider documentation used

If current provider behavior cannot be verified:

> **STOP.**

## Implement

Conceptually:

```text
Authenticated FaceTune user
        ↓
Purchase evidence from Android client
        ↓
Protected FaceTune server / Edge Function
        ↓
Official Google Play verification
        ↓
Validate package/product/subscription state
        ↓
Map verified provider product → canonical internal plan
        ↓
Idempotently create/update entitlement
        ↓
Return sanitized authoritative subscription state
```

## Validate at minimum

- authenticated user context
- expected application/package
- expected provider product/base plan according to current API
- legitimate subscription state
- provider purchase/transaction identity
- replay/duplicate behavior
- mapping to `plus`, `pro`, or `salon_pro`
- no client-selected Salon Pilot

## Security rules

- provider credentials server-side only
- do not expose raw provider responses unnecessarily
- do not log full purchase token
- do not trust client price
- do not trust client plan code
- do not fabricate Google Play state for admin-granted access

## Idempotency

The same purchase evidence verified multiple times must not create duplicate entitlements or duplicate periods.

## Do NOT implement

- full renewal/cancellation/grace/refund lifecycle beyond minimum current-verification state necessary for activation
- Web Admin
- annual/add-on plans
- AI changes

## Tests / validation

Use provider fakes/mocks plus sandbox/integration validation where appropriate.

Test at minimum:

- valid Plus purchase
- valid Pro purchase
- valid Salon Pro purchase
- unknown product rejected
- wrong package rejected
- fabricated token rejected
- expired/ineligible provider state rejected
- duplicate verification idempotent
- replay behavior safe
- client plan mismatch ignored in favor of provider mapping
- unauthorized request rejected
- provider failure returns sanitized error

## Done when

- verified store evidence can create/update authoritative entitlement
- Flutter cannot self-grant premium

## Completion report

Use the standard report.

Then STOP.

Do not implement SUB-11 unless explicitly instructed.

---

# SUB-11 - SUBSCRIPTION LIFECYCLE, RENEWAL, CANCELLATION, EXPIRATION & RESTORE

Read all authorities and prior reports.

Implement only **SUB-11 - SUBSCRIPTION LIFECYCLE, RENEWAL, CANCELLATION, EXPIRATION & RESTORE**.

## Active roles

Especially apply:

- Senior Google Play Billing Engineer
- Senior Subscription Lifecycle Engineer
- Senior Backend Engineer
- Senior Distributed Systems Engineer
- Senior Idempotency Engineer
- Senior Supabase/PostgreSQL Engineer
- Senior Reliability Engineer
- Senior Security Engineer
- Senior Integration Test Engineer

## Objective

Implement provider-backed subscription lifecycle reconciliation so FaceTune entitlement follows verified provider state instead of stale client assumptions.

## Mandatory current-provider verification

Verify current official Google Play behavior for:

- renewal
- cancellation
- expiration
- grace period / account hold or equivalent current states
- refund/revocation
- restoration/reconciliation
- server notifications/events when applicable
- product/base-plan changes
- acknowledgement requirements where applicable

Do not rely on old event names or obsolete API versions.

## Core business rules

### Cancellation

```text
cancelled auto-renew
!=
immediately expired entitlement
```

If verified provider state grants access through `period_end`, FaceTune keeps entitlement through that verified period.

### Renewal

A verified new billing period receives the plan's configured allowance:

```text
Plus      3
Pro       8
Salon Pro 35
```

Prior period usage remains historical.

No rollover.

Do not delete old ledger rows to reset usage.

### Expiration

Blocks new paid Final Preview generation.

Does not delete:

- History
- Saved Looks
- existing Final Previews
- existing Tutorials

### Restore/reconciliation

Must:

- query/reconcile legitimate provider purchases through the approved current mechanism
- rebuild/repair entitlement from verified provider evidence
- remain idempotent
- avoid fabricating provider state

### Refund/revocation

Process according to current verified provider semantics and Subscription SOT.

## Implement

- lifecycle mapping from verified provider state to canonical entitlement state
- period transitions
- no-rollover behavior
- reconciliation path
- restore purchase path
- event deduplication/idempotency
- safe state transition persistence
- authoritative Flutter refresh after lifecycle changes

## Do NOT implement

- Web Admin
- manual paid-plan override UI
- Apple IAP unless explicitly approved for current phase
- annual/add-on plans
- AI changes

## Tests / validation

Test at minimum:

- active renewing
- active but cancelled until period end
- renewal creates new period capacity
- prior usage retained
- no rollover
- expiration blocks new generation
- existing content remains available
- grace state follows verified provider entitlement semantics
- revoked/refunded state
- duplicate provider event idempotent
- restore valid purchase
- restore duplicate idempotent
- restore no purchase
- provider unavailable
- period transition with active reservation handled according to approved reconciliation rules

## Done when

- public subscription lifecycle follows verified provider truth
- no client clock/client boolean controls entitlement

## Completion report

Use the standard report.

Then STOP.

Do not implement SUB-12 unless explicitly instructed.

---

# SUB-12 - FREE & SALON PILOT BACKEND COMPATIBILITY

Read all authorities and prior reports.

Implement only **SUB-12 - FREE & SALON PILOT BACKEND COMPATIBILITY**.

## Active roles

Especially apply:

- Senior Subscription Systems Engineer
- Senior Entitlements Engineer
- Senior Supabase/PostgreSQL Engineer
- Senior Backend Engineer
- Senior Security Engineer
- Senior Shared-Contract Engineer
- Senior QA / Integration Test Engineer

## Objective

Finalize backend compatibility for non-store entitlement types so Free and Salon Pilot use the same safe subscription/usage engine without pretending to be store purchases.

## Free contract

```text
plan_code = free
billing_provider/origin = none equivalent
allowance = 1 one-time AI Look
reset = never
rollover = not applicable
```

The user must not receive a new complimentary AI Look every month merely because a date changed.

## Salon Pilot contract

```text
plan_code = salon_pilot
billing provider/origin = admin_granted
publicly purchasable = false
starting allowance = 30
admin-adjustable = true
auto-renew = false
automatic reset = none
expiration = required/admin-controlled
```

This phase must support later Web Admin operations through the Shared Contract, but it does not build the Web Admin.

## Implement

- Free entitlement initialization/resolution according to current account architecture
- one-time Free allowance persistence that survives month changes/reinstalls according to account identity
- Salon Pilot entitlement representation
- base/effective allowance semantics compatible with later audited adjustments
- expiration semantics
- generation blocking when expired/suspended/revoked
- shared response compatibility with `subscription_admin_contract_v1`

If a minimal server-only test/admin fixture is necessary for automated tests, it must not become a production hidden admin bypass.

## Hard locks

- no hardcoded special pilot email
- no client-side pilot flag
- no public purchase product for Salon Pilot
- no unlimited pilot
- no automatic monthly pilot reset
- no 3-previews-per-client logic
- no client-session billing

## Do NOT implement

- Admin Dashboard
- Admin user search
- Admin grant buttons
- Admin +5/+10 UI
- Admin suspend/revoke UI
- Web Admin frontend

Those belong to `FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md`.

## Tests / validation

Test at minimum:

- new Free user gets one entitlement according to approved account lifecycle
- Free first committed look -> zero remaining
- month change does not reset Free
- reinstall/login does not recreate Free allowance incorrectly
- Salon Pilot 30 starting allowance representable
- Salon Pilot 18 committed -> 12 remaining before adjustment
- effective allowance supports future +10 adjustment -> 22 remaining in the conceptual example
- expired Salon Pilot blocks new generation
- Salon Pilot is not returned as publicly purchasable
- public plan purchase verification cannot create `salon_pilot`
- normal user cannot self-grant pilot

## Done when

- Free and Salon Pilot are first-class non-store entitlement types
- later Web Admin can operate Salon Pilot through the Shared Contract without database hacks

## Completion report

Use the standard report.

Then STOP.

Do not implement SUB-13 unless explicitly instructed.

---

# SUB-13 - SUBSCRIPTION TELEMETRY, COST MEASUREMENT & OPERATIONAL SAFETY

Read all authorities and prior reports.

Implement only **SUB-13 - SUBSCRIPTION TELEMETRY, COST MEASUREMENT & OPERATIONAL SAFETY**.

## Active roles

Especially apply:

- Senior Observability Engineer
- Senior AI Cost Optimization / FinOps Engineer
- Senior Subscription Systems Engineer
- Senior Privacy Engineer
- Senior Backend Engineer
- Senior Reliability Engineer
- Senior Data/Analytics Engineer
- Senior QA Engineer

## Objective

Add privacy-safe technical measurement required to understand subscription behavior and validate the Salon Pilot cost hypothesis without turning telemetry into a second database of private user data.

## Business research objective

The current planning assumption is:

```text
PHP 45 effective cost per successfully delivered AI Look
```

This is not runtime billing truth.

Salon Pilot should help calculate:

```text
total billable AI/API cost
/
successfully delivered AI Looks
=
effective cost per delivered AI Look
```

## Implement / expose sanitized technical measurements where current architecture supports them

Examples:

- plan code
- billing provider/origin
- entitlement state transitions
- usage operation count
- reserved count
- committed count
- released count
- sanitized failure category
- operation latency
- Final Preview successful-delivery count
- provider verification success/failure category
- restore/reconciliation count
- Tutorial technical operations separately where existing analytics can safely provide them
- model/prompt/version metadata only where already safe/approved and useful for cost attribution
- provider usage units/cost inputs only through a separately maintainable cost model where technically feasible

## Privacy rules

Do not log:

- image bytes
- base64 images
- signed URLs
- JWTs
- service-role credentials
- full provider purchase tokens
- raw provider responses containing sensitive purchase data
- private Gemini prompts
- raw My Makeup Kit contents
- user-entered product names merely for cost measurement

Telemetry measures system behavior, not user makeup content.

## Cost-model rule

Do not hardcode:

```text
PHP 45
```

into entitlement logic.

Do not hardcode mutable provider prices/FX throughout code.

A separately maintained/reporting-time cost model may be used when justified.

## Do NOT implement

- new Gemini calls
- model downgrade
- prompt downgrade
- Web Admin analytics dashboard unless separately authorized later
- broad product analytics platform migration

## Tests / validation

Test at minimum:

- committed/released events distinguishable
- duplicate operation does not double-count logical usage
- failure telemetry sanitized
- secrets absent from logs
- image/signed URL data absent from logs
- provider tokens redacted/omitted
- telemetry failure does not corrupt entitlement transaction

## Done when

- Subscription can be measured safely
- Salon Pilot can later support real effective-cost analysis
- no runtime pricing decision depends directly on the PHP 45 assumption

## Completion report

Use the standard report.

Then STOP.

Do not implement SUB-14 unless explicitly instructed.

---

# SUB-14 - FULL SECURITY, REGRESSION & EDGE-CASE HARDENING

Read all authorities and prior reports.

Implement only **SUB-14 - FULL SECURITY, REGRESSION & EDGE-CASE HARDENING**.

## Active roles

Especially apply:

- Principal Software Engineer
- Senior Application Security Engineer
- Senior RLS Engineer
- Senior Idempotency / Concurrency Engineer
- Senior Subscription Systems Engineer
- Senior Google Play Billing Engineer
- Senior Reliability Engineer
- Senior QA Engineer
- Senior Regression Engineer
- Senior Integration Test Engineer
- Senior Production Debugging Engineer
- Senior Code Reviewer

## Objective

Prove Subscription V1 is resilient across entitlement, billing, AI Look accounting, security, provider, async, and protected FaceTune regression cases.

This phase is primarily hardening/testing. Do not use it as permission for a broad refactor.

## Required automated/controlled scenarios

### Free

- initial one-time allowance
- first success commits one
- exhausted remains exhausted
- no monthly reset
- reinstall/login does not improperly recreate allowance

### Plus

- 3/3
- 2/3
- 1/3
- 0/3
- new verified period resets to 3 with old usage preserved

### Pro

- 8/8
- exhaustion
- new period

### Salon Pro

- 35/35
- high-volume sequential generation
- exhaustion
- new period

### Salon Pilot

- 30 initial
- no automatic reset
- expiration
- future allowance adjustment compatibility
- non-public purchase behavior

### AI Look accounting

- success commits once
- generation failure releases
- persistence failure releases when no usable result exists
- duplicate operation does not double-charge
- duplicate commit does not double-charge
- duplicate release safe
- reopen existing preview consumes zero
- Tutorial open/reopen consumes zero
- History open consumes zero
- Saved Looks open consumes zero

### Concurrency

- one remaining + two simultaneous requests
- multiple devices
- network retry
- duplicate operation ID
- client timeout while server succeeds
- client timeout while server fails
- renewal during reservation
- expiration boundary during reservation
- stale reservation recovery

### Provider

- valid purchase
- invalid token/evidence
- wrong product
- duplicate verification
- cancellation with valid remaining paid period
- renewal
- expiration
- grace state according to verified current rules
- refund/revocation
- restore
- duplicate lifecycle event

### Security

- user cannot grant own entitlement
- user cannot grant Salon Pilot
- user cannot edit own usage ledger
- user cannot read another user's entitlement
- user cannot read another user's usage
- cross-user preview association rejected
- RLS remains enabled
- JWT bypass absent
- service-role key absent from Flutter/browser
- provider secrets absent from client

### Protected FaceTune regression

- Standard Mode still works
- My Makeup Kit still works
- Final Preview renderer/model unchanged
- Final Preview prompt unchanged unless an earlier explicitly authorized phase proved a required non-visual integration change
- Tutorial still opens
- Tutorial does not consume another AI Look
- History works
- Saved Looks works
- existing Final Preview reopens
- no Gemini call moved into Flutter
- no build-triggered paid AI work
- accepted navigation/loading behavior remains stable

### Flutter/UI

- subscription state loading
- offline/error
- current plan
- remaining allowance
- low allowance
- zero allowance
- reset date
- expiration date
- public paywall
- Salon Pilot non-public state

## Static/security review

Inspect for:

- hardcoded `isPremium`
- hardcoded plan/allowance duplication
- hidden test bypasses
- hardcoded pilot emails
- direct privileged Supabase writes from client
- logs containing secrets/tokens
- stale provider assumptions
- duplicated billing listeners
- race-prone decrement logic

## Fix policy

Fix only defects proven by this hardening scope.

Do not redesign unrelated UI or AI behavior.

## Done when

- critical edge cases have explicit automated or controlled evidence
- no known high-severity subscription integrity defect remains
- protected FaceTune regressions are green or explicitly documented as pre-existing/unrelated

## Completion report

Use the standard report.

Then STOP.

Do not implement SUB-15 unless explicitly instructed.

---

# SUB-15 - REAL DEVICE, GOOGLE PLAY SANDBOX & PRODUCTION-READINESS QA

Read all authorities and every prior Subscription completion report.

Implement only **SUB-15 - REAL DEVICE, GOOGLE PLAY SANDBOX & PRODUCTION-READINESS QA**.

This is the final Subscription V1 acceptance phase.

## Active roles

Especially apply:

- Principal Software Engineer
- Senior Release Engineer
- Senior Google Play Billing Engineer
- Senior Subscription Systems Engineer
- Senior Mobile QA Engineer
- Senior Integration Test Engineer
- Senior Security Test Engineer
- Senior Production Debugging Engineer
- Senior Performance Engineer
- Senior Code Reviewer

## Objective

Validate the complete Subscription V1 journey using real-device, live approved backend, and Google Play test/sandbox evidence where available and authorized.

Do not begin Web Admin implementation in this phase.

## Before validation

- verify branch/working tree
- inspect all prior completion reports
- inspect current diff
- confirm no unreviewed unrelated changes are mixed in
- verify Supabase environment
- verify Google Play testing environment/internal track
- verify test products/base plans
- verify provider documentation still matches implemented behavior
- verify no production secret is bundled in client

## Primary device

```text
POCO X3 GT
```

Use profile/release-like execution for performance-sensitive UI when debug overhead would distort results.

## Required end-to-end journeys

### A. Free

```text
Create/sign into eligible Free account
        ↓
1 AI Look available
        ↓
Generate successful Final Preview
        ↓
0 remaining
        ↓
Reopen Final Preview = allowed
Tutorial = allowed / 0 extra AI Looks
History = allowed
Saved Looks = allowed
New Final Preview = blocked/paywall
```

### B. Plus sandbox purchase

```text
Purchase Plus through approved Google Play test flow
        ↓
Client receives provider evidence
        ↓
Server verifies
        ↓
Plus entitlement active
        ↓
3 AI Looks available for verified period
        ↓
Generate one
        ↓
2 remaining
```

### C. Pro sandbox purchase

```text
Verified Pro purchase
        ↓
8 AI Looks available
```

Generate at least enough controlled test operations to prove accounting behavior without wasting unnecessary provider cost.

### D. Salon Pro sandbox purchase

```text
Verified Salon Pro purchase
        ↓
35 AI Looks available
```

Do not exhaust 35 live AI calls merely to prove an integer if automated tests already prove quota arithmetic. Use controlled evidence and avoid pointless cost.

### E. Failure handling

Prove at least with controlled test/fake plus live-safe evidence where possible:

```text
technical failure before usable persisted Final Preview
        ↓
reservation released
        ↓
no user-facing AI Look consumed
```

### F. Duplicate / retry

Prove duplicate logical request does not double-charge.

### G. Cancellation / expiration

Using provider sandbox mechanisms where possible:

- cancelled but still-valid period remains entitled until verified end
- expired blocks new Final Preview
- existing History/Saved/Preview/Tutorial remain accessible

### H. Restore

- valid purchase restore/reconciliation
- duplicate restore safe

### I. Salon Pilot compatibility

Without building Web Admin, prove backend/test fixture behavior necessary for later Admin:

```text
salon_pilot
30 initial allowance
non-public
no automatic reset
expiration supported
```

Do not ship a hidden production grant bypass merely to test this.

## Performance / UX checks

On POCO X3 GT:

- subscription/paywall opens smoothly
- no repeated provider query loops
- no duplicate purchase listener side effects
- Final Preview loading remains accepted
- quota state updates after successful committed generation
- no layout overflow
- Profile remains smooth
- Saved/History performance remains accepted

## Security release checks

Verify:

- no service-role key in APK/client config
- no provider private credential in APK
- no Gemini key in Flutter
- RLS enabled
- protected server functions require auth as designed
- normal user cannot mutate entitlement/ledger
- logs are sanitized
- test-only bypasses are removed/disabled from production paths

## Final acceptance report

In addition to the standard completion report, include:

```text
SUBSCRIPTION V1 FINAL STATUS:
PASS / FAIL / CONDITIONAL

FREE JOURNEY:

PLUS JOURNEY:

PRO JOURNEY:

SALON PRO JOURNEY:

SALON PILOT BACKEND COMPATIBILITY:

GOOGLE PLAY SANDBOX EVIDENCE:

AI LOOK ACCOUNTING EVIDENCE:

FAILURE / RELEASE EVIDENCE:

DUPLICATE / IDEMPOTENCY EVIDENCE:

LIFECYCLE / RESTORE EVIDENCE:

PROTECTED V4 REGRESSION EVIDENCE:

REAL DEVICE EVIDENCE:

SECURITY EVIDENCE:

OUTSTANDING BLOCKERS:

PRODUCTION MANUAL ACTIONS:

READY TO BEGIN FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md:
YES / NO
```

## Done when

- Subscription V1 is demonstrably stable enough for the approved next step
- outstanding manual/provider actions are explicit
- no Web Admin code was started

## Completion report

Use the standard report plus the final acceptance addendum.

Then STOP.

Do not begin `FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md` automatically.

---

# 22. SUBSCRIPTION PHASE COMPLETION FLOW

The required execution sequence is:

```text
SUB-0  Audit
  ↓
Review / PASS
  ↓
SUB-1  Domain Contracts
  ↓
Review / PASS
  ↓
SUB-2  Database + RLS
  ↓
Review / PASS
  ↓
SUB-3  Entitlement Resolver
  ↓
Review / PASS
  ↓
SUB-4  Reserve / Commit / Release
  ↓
Review / PASS
  ↓
SUB-5  Final Preview Integration
  ↓
Review / PASS
  ↓
SUB-6  Flutter Subscription State
  ↓
Review / PASS
  ↓
SUB-7  Remaining AI Looks UX
  ↓
Review / PASS
  ↓
SUB-8  Subscription / Paywall UI
  ↓
Review / PASS
  ↓
SUB-9  Google Play Client Billing
  ↓
Review / PASS
  ↓
SUB-10 Server Purchase Verification
  ↓
Review / PASS
  ↓
SUB-11 Lifecycle / Restore
  ↓
Review / PASS
  ↓
SUB-12 Free + Salon Pilot Compatibility
  ↓
Review / PASS
  ↓
SUB-13 Telemetry / Cost Measurement
  ↓
Review / PASS
  ↓
SUB-14 Security + Regression Hardening
  ↓
Review / PASS
  ↓
SUB-15 Real Device / Sandbox / Production Readiness
  ↓
FINAL SUBSCRIPTION PASS
  ↓
ONLY THEN
FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md
```

Testing occurs after every phase, not only at the end.

---

# 23. OUT OF SCOPE FOR THIS PHASE FILE

Do not implement through this file unless a future approved authority explicitly changes scope:

- Web Admin UI
- Admin Dashboard
- Admin Users page
- Admin Audit page
- Admin entitlement-management screens
- annual subscriptions
- AI Look add-on packs
- multiple Salon Pro seats
- salon employee accounts
- salon branches
- salon CRM
- per-client subscription accounting
- client-session billing
- three-previews-per-client logic
- family plans
- referral system
- affiliate system
- promo codes
- gift subscriptions
- lifetime plans
- unlimited AI
- dynamic usage billing
- enterprise billing
- external Stripe checkout for in-app digital functionality
- wallet/coin economy
- rollover
- model downgrade by plan
- ad-supported quota replenishment

Do not pre-build these "for flexibility."

Unused abstraction is not architecture. It is future confusion with a constructor.

---

# 24. FINAL NON-NEGOTIABLE CHECKLIST

Before claiming Subscription V1 complete, prove all of the following:

```text
[ ] Free = 1 one-time AI Look
[ ] Plus = 3 AI Looks / verified billing period
[ ] Pro = 8 AI Looks / verified billing period
[ ] Salon Pro = 35 AI Looks / verified billing period
[ ] Salon Pilot = 30 initial, admin-adjustable later, no auto-reset
[ ] No rollover
[ ] 1 AI Look = 1 usable persisted Final Makeup Preview
[ ] Tutorial consumes 0 additional user-facing AI Looks
[ ] Reopening existing Preview consumes 0
[ ] History/Saved reopen consumes 0
[ ] Technical failure without usable persisted preview consumes 0
[ ] Reserve / Commit / Release is server-authoritative
[ ] Duplicate operation cannot double-charge
[ ] Concurrent last-look requests cannot oversubscribe
[ ] Flutter cannot self-grant premium
[ ] Google Play purchase is verified server-side
[ ] Client plan/price is not purchase authority
[ ] Cancellation != immediate expiration when verified paid period remains
[ ] Renewal creates new period allowance without deleting old history
[ ] Restore is idempotent
[ ] Expiration blocks new generation but preserves historical content
[ ] RLS remains enabled
[ ] Normal user cannot edit entitlement/ledger
[ ] Service-role key is not in Flutter/browser
[ ] Gemini key is not in Flutter
[ ] Final Preview model/prompt architecture is preserved
[ ] Standard Mode is preserved
[ ] My Makeup Kit is preserved
[ ] Tutorial architecture is preserved
[ ] No build-triggered paid AI work
[ ] PHP 45 cost assumption is not runtime entitlement logic
[ ] Salon Pilot is not a public store product
[ ] No hidden production admin bypass
[ ] SUB-15 final acceptance completed
[ ] No Web Admin implementation started automatically
```

---

# 25. FINAL STOP RULE

The coding agent must never interpret completion of a phase as authorization to begin another phase.

At the end of every phase:

```text
REPORT
↓
STOP
```

At the end of SUB-15:

```text
FINAL SUBSCRIPTION REPORT
↓
STOP
↓
WAIT FOR EXPLICIT USER AUTHORIZATION
```

Only after the user accepts Subscription V1 should implementation proceed to:

```text
FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md
```

