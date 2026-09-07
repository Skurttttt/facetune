# FaceTune - WEB ADMIN PHASE PROMPTS

**Project root:** `C:\Users\Kurt\facetune`  
**Project:** FaceTune  
**Tagline:** Your AI Makeup Artist  
**Primary product platform:** Android / Flutter  
**Backend:** Supabase  
**Admin surface:** Private web-based administration portal  
**Subscription authority:** `FACETUNE_SUBSCRIPTION_SOURCE_OF_TRUTH.md`  
**Shared contract authority:** `FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md`  
**Web Admin authority:** `FACETUNE_WEB_ADMIN_SOURCE_OF_TRUTH.md`  
**This phase file:** `FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md`  
**Shared contract version:** `subscription_admin_contract_v1`  
**Primary execution rule:** exactly ONE Web Admin phase at a time  
**Automatic continuation:** PROHIBITED  

---

# 0. PURPOSE

This document contains the only authorized implementation phases for FaceTune Web Admin V1.

It exists to translate the approved Web Admin Source of Truth and Subscription/Admin Shared Contract into controlled, reviewable, production-safe implementation work.

This file does NOT redefine:

- subscription pricing
- subscription plan allowances
- what consumes an AI Look
- entitlement lifecycle semantics
- usage ledger semantics
- Google Play purchase truth
- Final Makeup Preview behavior
- Gemini model configuration
- Gemini prompts
- Tutorial behavior
- My Makeup Kit ownership logic

Those rules are owned by their higher-authority documents.

The Web Admin must operate the existing Subscription system.

The Web Admin must not reinvent it.

Conceptually:

```text
FACETUNE_SUBSCRIPTION_SOURCE_OF_TRUTH.md
                    ↓
FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md
                    ↓
FACETUNE_WEB_ADMIN_SOURCE_OF_TRUTH.md
                    ↓
FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md
                    ↓
ONE AUTHORIZED IMPLEMENTATION PHASE
```

---

# 1. HOW TO USE THIS FILE

1. Keep this file in the FaceTune project root beside all current authority files.
2. Use either OpenAI Codex or Claude Code Pro according to the user's current workflow.
3. Execute exactly ONE Web Admin phase at a time.
4. Paste only the prompt for the phase currently being implemented.
5. Review the completion report before starting the next phase.
6. Never tell the coding agent to continue automatically.
7. Never allow the coding agent to interpret a successful test as authorization for the next phase.
8. Never assume a prior phase is correct merely because its completion report says `complete`.
9. Actual code, migrations, browser behavior, backend behavior, logs, tests, and production/staging evidence win over stale documentation.
10. Do not merge, push, reset, stash, rebase, or clean working state automatically.
11. If a phase discovers a conflict with a higher authority, STOP and report the conflict.
12. If the actual Subscription implementation differs from the expected shared contract, STOP and report before inventing compatibility logic.
13. If the Web Admin framework does not yet exist, inspect first before selecting a framework or creating a new app.
14. If an existing valid admin/web project exists, prefer extending it over creating a competing second admin application.
15. Every phase ends with a completion report and STOP.

---

# 2. AUTHORITY ORDER

Before ANY Web Admin implementation phase, read the following in order:

```text
1. CODEX_MASTER_GUIDE.md

2. Existing protected FaceTune / V4 authorities
   relevant to the current integration

3. FACETUNE_SUBSCRIPTION_SOURCE_OF_TRUTH.md

4. FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md

5. FACETUNE_WEB_ADMIN_SOURCE_OF_TRUTH.md

6. FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md

7. Relevant completed Subscription phase reports

8. Relevant prior Web Admin phase reports

9. Actual source code, schema, migrations, RLS,
   Edge Functions / server APIs, configuration,
   tests, deployed state, and browser evidence
```

Authority rule:

```text
Source of Truth
defines WHAT is true.

Shared Contract
defines WHAT both systems must agree on.

Web Admin Source of Truth
defines WHAT admins may do.

Phase Prompt
defines WHAT may be implemented now.
```

A phase prompt cannot override a Source of Truth.

Completion reports are evidence, not authority.

If this file conflicts with `FACETUNE_WEB_ADMIN_SOURCE_OF_TRUTH.md`, the Web Admin Source of Truth wins.

If Web Admin behavior conflicts with `FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md`, the Shared Contract wins for common contract semantics.

If Subscription business behavior conflicts with this file, `FACETUNE_SUBSCRIPTION_SOURCE_OF_TRUTH.md` wins.

---

# 3. MANDATORY SYSTEM ROLE FOR EVERY PHASE

Act simultaneously as a production engineering team composed of:

- Principal Software Engineer
- Principal Software Architect
- Senior Full-Stack Engineer
- Senior Frontend Engineer
- Senior Backend Engineer
- Senior Backend Developer
- Senior Web Application Engineer
- Senior TypeScript Engineer
- Senior Supabase Engineer
- Senior PostgreSQL Engineer
- Senior Row Level Security Engineer
- Senior API Integration Engineer
- Senior Authentication Engineer
- Senior Authorization / RBAC Engineer
- Senior Application Security Engineer
- Senior Privacy Engineer
- Senior Domain Modeling Engineer
- Senior Subscription Systems Engineer
- Senior Billing Systems Engineer
- Senior Transaction Engineer
- Senior Async / Concurrency Engineer
- Senior Idempotency Engineer
- Senior Reliability Engineer
- Senior Performance Engineer
- Senior Admin UX Engineer
- Senior Accessibility Engineer
- Senior QA Engineer
- Senior Regression Engineer
- Senior Integration Test Engineer
- Senior Production Debugging Engineer
- Senior Release Engineer
- Senior Code Reviewer

These roles apply equally whether the coding agent is:

- OpenAI Codex
- Claude Code Pro
- another explicitly approved coding agent

Do not behave as a UI generator that blindly creates pages from assumptions.

Inspect first.

Challenge stale documentation.

Prefer the smallest production-safe change.

Preserve working application behavior.

Do not invent architecture before inspecting the repository.

---

# 4. ENGINEERING PRIORITIES

Every Web Admin decision must prioritize:

1. security
2. correctness
3. authorization
4. auditability
5. data integrity
6. privacy
7. reliability
8. maintainability
9. testability
10. concurrency safety
11. performance
12. accessibility
13. usability
14. visual polish

Do not trade authorization integrity for convenience.

Do not trade auditability for fewer database writes.

Do not trade privacy for a more informative dashboard.

Do not trade existing Subscription correctness for faster Admin implementation.

Do not perform a broad rewrite when a smaller integration is sufficient.

---

# 5. GLOBAL PRE-IMPLEMENTATION RULES

Before coding in EVERY phase:

```powershell
git branch --show-current
git status
```

Then inspect, when relevant:

- current branch
- current HEAD
- current working-tree changes
- untracked files
- valid uncommitted Subscription work
- repository structure
- existing web/admin application structure
- `pubspec.yaml`
- `package.json`
- lockfiles
- TypeScript configuration
- web framework configuration
- Supabase client configuration
- Supabase Auth integration
- admin-role storage
- server-side authorization implementation
- subscription product records
- entitlement persistence
- usage ledger
- allowance adjustments
- audit logs
- Edge Functions
- server APIs
- PostgreSQL functions / RPCs
- RLS policies
- environment files and conventions
- deployment configuration
- test configuration
- lint / format / build commands
- relevant completion reports

Do not assume:

- React
- Next.js
- Vite
- Flutter Web
- Supabase service role usage pattern
- admin table names
- entitlement table names
- existing RBAC implementation
- deployment provider
- hosting provider
- routing framework

Prove these from the repository.

---

# 6. GIT SAFETY

Never automatically run:

```text
git reset --hard
git clean -fd
git clean -fdx
git restore .
git checkout -- .
git stash
git stash push
git stash pop
git merge
git rebase
git cherry-pick
git push
git push --force
git push --force-with-lease
```

Never automatically:

- switch branches
- delete branches
- delete tags
- overwrite unrelated files
- discard user changes
- rewrite history
- create a "clean state" by destroying valid work
- commit
- push
- merge to `main`

unless the user explicitly authorizes the exact operation.

A dirty working tree is not permission to clean it.

If valid uncommitted Subscription or UI work exists:

> preserve it.

If the current branch differs from the expected branch:

> STOP and report the actual branch.

Do not silently switch.

---

# 7. WORKING TREE PRESERVATION

Before modifying a file:

1. inspect whether it is already modified
2. determine whether those modifications belong to prior valid work
3. preserve valid changes
4. apply the smallest compatible diff

Do not rewrite entire files merely because localized edits are harder.

Do not reformat unrelated files.

Do not normalize unrelated line endings.

Do not reorder unrelated imports across the project.

Do not touch accepted FaceTune consumer UI unless the current Web Admin phase explicitly requires a narrow integration point.

---

# 8. SUBSCRIPTION SYSTEM PROTECTION

The Web Admin must consume the completed Subscription system.

It must not redefine:

- `free`
- `plus`
- `pro`
- `salon_pro`
- `salon_pilot`
- AI Look definition
- plan allowance values
- entitlement statuses
- billing provider codes
- usage statuses
- reset policy
- rollover policy
- purchase verification logic
- entitlement resolution logic
- reserve / commit / release semantics
- remaining balance formula
- cancellation semantics
- expiration semantics
- provider truth
- Google Play transaction truth

The Web Admin is an operational layer.

It is not the economic authority.

---

# 9. SUBSCRIPTION V1 HARD LOCKS

Current approved business baseline:

```text
FREE
₱0
1 one-time AI Look
No monthly reset

PLUS
₱399/month
3 AI Looks per billing period
No rollover

PRO
₱899/month
8 AI Looks per billing period
No rollover

SALON PRO
₱2,999/month
35 AI Looks per billing period
1 Makeup Artist Account
No rollover

SALON PILOT
Complimentary
30 initial AI Looks
Admin-adjustable
Temporary
Non-public
Non-renewing
Expiration required
```

The Web Admin must not scatter these values independently if the Subscription backend already provides authoritative configuration.

The Web Admin must not change Google Play product pricing.

The Web Admin must not fabricate store purchase records.

---

# 10. AI LOOK HARD LOCK

Universal rule:

```text
1 AI Look
=
1 successfully generated
AND persisted
Final Makeup Preview
```

Not:

```text
button tap
purchase
selfie
recommendation
Gemini request
manifest analysis
tutorial generation
history reopen
saved-look reopen
share
```

The Web Admin may display AI Look consumption.

It may not reinterpret it.

---

# 11. USAGE LEDGER HARD LOCK

Canonical usage statuses:

```text
reserved
committed
released
```

Meaning:

```text
reserved
=
capacity temporarily held

committed
=
successful persisted Final Makeup Preview
and final AI Look consumption

released
=
reservation ended without consumption
```

The Admin UI must not invent:

```text
spent
used_up
failed_charge
pending_charge
done
```

as alternate persisted states.

Display labels may be human-readable, but backend semantics must remain canonical.

---

# 12. PROTECTED V4 / AI BOUNDARIES

Web Admin must not modify:

- canonical Final Makeup Preview authority
- `gemini-3.1-flash-image`
- Final Preview model configuration
- Final Preview prompt
- Final Preview request architecture
- Final Preview persistence architecture
- current accepted retry behavior
- current Manifest model
- Manifest prompt
- Manifest schema
- Manifest lifecycle
- Tutorial guideline model
- Tutorial prompt
- Tutorial resolution
- Tutorial generation behavior
- Tutorial on-demand behavior
- Tutorial reuse behavior
- Standard Mode recommendation behavior
- My Makeup Kit recommendation behavior
- My Makeup Kit ownership validation
- immutable product snapshots
- canonical-preview-grounded tutorial authority

Web Admin V1 must not trigger:

```text
Generate Preview
Regenerate Preview
Run Manifest
Generate Tutorial
Regenerate Tutorial
Run Gemini
```

unless a future authority explicitly approves a diagnostic feature.

---

# 13. ADMIN SECURITY HARD LOCKS

The following are permanently prohibited:

```text
service_role key in browser
service_role key in Flutter
service_role key in public web config

hardcoded admin email
hardcoded admin password
hardcoded admin user ID

frontend-only admin authorization
localStorage as authorization authority
route visibility as authorization authority
email domain as authorization authority

RLS disabled for Admin convenience
JWT verification bypass
anonymous privileged mutation
direct arbitrary DB mutation from browser
direct arbitrary SQL console
arbitrary JSON row editor
```

The frontend may express intent.

The server decides whether the action is authorized and valid.

---

# 14. ADMIN APPLICATION BOUNDARY

Required conceptual architecture:

```text
ADMIN USER
    ↓
WEB ADMIN FRONTEND
    ↓
AUTHENTICATED SESSION
    ↓
PROTECTED SERVER / EDGE FUNCTION
    ↓
SERVER-SIDE ADMIN AUTHORIZATION
    ↓
DOMAIN VALIDATION
    ↓
SUBSCRIPTION / ENTITLEMENT SERVICE
    ↓
POSTGRES / SUPABASE
```

Forbidden:

```text
ADMIN BROWSER
    ↓
PRIVILEGED DATABASE MUTATION
```

The Admin frontend is not trusted merely because it is private.

---

# 15. SHARED CONTRACT COMPATIBILITY

Both systems must conform to:

```text
subscription_admin_contract_v1
```

If Web Admin expects a field that the Subscription backend does not expose:

```text
STOP
REPORT THE CONTRACT GAP
DO NOT INVENT A CLIENT-SIDE SUBSTITUTE
```

Example:

```text
Web Admin expects:
effective_allowance

Backend exposes only:
base_allowance
```

Do not silently derive a new business rule unless the Shared Contract explicitly defines that derivation and server data is sufficient.

Prefer a server-owned contract response.

---

# 16. CANONICAL PLAN CODES

Use only:

```text
free
plus
pro
salon_pro
salon_pilot
```

Do not add aliases such as:

```text
premium
professional
salon
research
pilot
salon_test
```

without an approved contract revision.

---

# 17. CANONICAL BILLING PROVIDERS

Use the Shared Contract values.

Conceptually:

```text
none
google_play
apple_app_store
admin_granted
```

Do not infer provider from plan code.

Salon Pilot:

```text
billing_provider = admin_granted
```

It is not a fake store subscription.

---

# 18. CANONICAL ENTITLEMENT STATES

Use the Shared Contract values.

Expected V1 vocabulary:

```text
active
grace_period
expired
suspended
revoked
```

Use `pending` only if the actual approved Subscription implementation requires it.

Do not flatten everything into:

```text
active / inactive
```

Cancellation is not necessarily immediate expiration.

---

# 19. ADMIN V1 SCOPE

Web Admin V1 includes:

```text
Dashboard
Users
Entitlements
Usage
Audit

Admin authentication
Admin authorization

Salon Pilot grant
Salon Pilot allowance adjustment
Salon Pilot expiration extension

Entitlement suspension
Entitlement reactivation
Entitlement revocation

Read-only commercial-plan visibility

Salon Pilot research metrics
```

---

# 20. EXPLICIT WEB ADMIN V1 NON-GOALS

Do NOT implement:

- Salon CRM
- end-client profiles
- appointment booking
- branch management
- salon employee management
- multiple salon seats
- payroll
- accounting
- invoicing
- marketing CMS
- affiliate system
- referral system
- promo-code manager
- annual subscription manager
- add-on AI Look packs
- family plans
- lifetime plans
- unlimited AI
- enterprise billing
- Stripe checkout
- dynamic usage billing
- SQL console
- database browser
- arbitrary table editor
- RLS editor
- API key manager
- My Makeup Kit editor
- Gemini prompt editor
- Gemini model selector
- Final Preview generator
- Tutorial generator
- image inspection console
- arbitrary signed URL viewer
- mass revoke-all action
- mass suspend-all action
- mass Salon Pilot grant

unless the user explicitly creates a new approved scope.

---

# 21. PRIVACY HARD LOCK

Subscription administration must not expose unnecessary:

- original selfies
- Final Makeup Preview image binaries
- tutorial image binaries
- signed image URLs
- raw prompts
- Gemini request bodies
- Gemini responses
- full My Makeup Kit contents
- private image metadata
- JWTs
- provider secrets
- purchase tokens beyond what is operationally necessary
- service credentials

Admin does not need facial imagery to answer:

```text
How many AI Looks remain?
```

Minimize data.

---

# 22. LOGGING HARD LOCK

Allowed sanitized telemetry may include:

```text
admin_user_id
target_user_id
entitlement_id
plan_code
billing_provider
admin_action
usage_status
operation_id
request_correlation_id
latency_ms
sanitized_failure_code
timestamp
```

Do not log:

```text
API keys
JWTs
service role key
signed URLs
image bytes
base64 images
raw Gemini responses
full private prompts
full My Makeup Kit contents
provider secrets
raw purchase tokens unless an approved secure diagnostic need exists
```

Audit logs are not permission to store private application content.

---

# 23. IDEMPOTENCY HARD LOCK

Privileged mutations must be duplicate-safe where duplicate execution could cause harm.

Examples:

```text
grant_entitlement
adjust_allowance
extend_expiration
suspend_entitlement
reactivate_entitlement
revoke_entitlement
```

If:

```text
Admin double-clicks +10
```

result must be:

```text
+10 exactly once
```

not:

```text
+20
```

UI button disabling is helpful.

Server-side idempotency is mandatory.

---

# 24. CONCURRENCY HARD LOCK

The system must safely handle:

```text
Admin A changes allowance
Admin B changes allowance

Admin changes allowance
while user reserves AI Look

Admin suspends entitlement
while AI Look is reserved

Admin revokes entitlement
while user has active session

Browser retries a mutation
after server succeeded

Network timeout
while server mutation completed
```

Use transaction-safe logic where required.

Do not calculate authoritative mutation results only in the browser.

---

# 25. STALE-WRITE PROTECTION

Where concurrent admin changes are possible, use an approved optimistic-concurrency or version/precondition mechanism when appropriate.

Example:

```text
Admin A reads allowance = 30

Admin B changes allowance = 40

Admin A submits change based on stale 30
```

The system should not silently overwrite newer state.

Prefer:

```text
STALE_ENTITLEMENT_VERSION
```

or equivalent approved conflict result.

---

# 26. ADMIN ACTION AUDITABILITY

Every privileged mutation must record enough information to reconstruct:

```text
who
did what
to whom
when
why
what changed
which request
```

Conceptual audit event:

```text
id
admin_user_id
action
target_user_id
target_entitlement_id
before_state
after_state
reason
request_correlation_id
created_at
```

Audit data must be immutable through ordinary Admin UI.

No:

```text
Edit Audit
Delete Audit
Rewrite History
```

---

# 27. SAFE ALLOWANCE ADJUSTMENT

Salon Pilot allowance adjustments must be additive/audited where compatible with the Subscription implementation.

Concept:

```text
Initial grant:       30
Admin adjustment:   +10
Effective allowance: 40
Committed usage:     18
Reserved usage:       0
Remaining:            22
```

Do not rewrite 18 committed usages to create more capacity.

Do not reduce effective allowance below committed usage.

Where active reservations count against available capacity, safe reduction must also honor reservation semantics defined by the Subscription system.

---

# 28. REMAINING BALANCE AUTHORITY

The authoritative remaining balance comes from the backend.

Web Admin displays it.

Web Admin does not invent it.

Conceptually:

```text
effective_allowance
-
committed
-
active_reserved
=
available_capacity
```

Use the actual approved Subscription calculation.

Do not duplicate the formula across random frontend components.

---

# 29. WEB ADMIN UI PRINCIPLES

The Admin portal is:

- private
- desktop-first
- professional
- dense but readable
- predictable
- restrained
- keyboard-friendly
- accessible
- status-oriented
- operational

Prefer:

- clear hierarchy
- tables
- filters
- pagination
- status badges with text
- concise mutation forms
- explicit confirmation for destructive actions

Avoid:

- consumer beauty-app animations
- decorative blobs
- oversized hero sections
- excessive gradients
- gratuitous glassmorphism
- fake analytics charts
- dashboard decoration that hides operational information

---

# 30. STANDARD COMPLETION REPORT

Every Web Admin phase must end with:

```text
PHASE COMPLETED:

BRANCH VERIFIED:

WORKING TREE PRESERVED:

OBJECTIVE ACHIEVED:

FILES CREATED:

FILES MODIFIED:

FILES DELETED:
None / exact list with justification

DEPENDENCIES ADDED / REMOVED:

WEB APP / FRONTEND CHANGES:

DATABASE / MIGRATION CHANGES:

RLS CHANGES:

EDGE FUNCTION / SERVER API CHANGES:

ADMIN AUTHENTICATION CHANGES:

ADMIN AUTHORIZATION CHANGES:

SHARED CONTRACT CHANGES:
None / exact authorized compatibility change

USER MANAGEMENT CHANGES:

ENTITLEMENT CHANGES:

SALON PILOT CHANGES:

ALLOWANCE ADJUSTMENT CHANGES:

USAGE LEDGER CHANGES:

AUDIT LOG CHANGES:

SUBSCRIPTION ENGINE CHANGES:
None / exact minimal integration change and justification

FINAL PREVIEW / AI CHANGES:
Must normally be None

PRIVACY CHECK:

SECURITY CHECK:

SERVICE-ROLE EXPOSURE CHECK:

IDEMPOTENCY CHECK:

CONCURRENCY CHECK:

ACCESSIBILITY CHECK:

TESTS / VALIDATION:

REAL BACKEND / BROWSER EVIDENCE:

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

# 31. VALIDATION RULES FOR EVERY PHASE

Run the validation appropriate to every changed layer.

At minimum:

```text
git branch --show-current
git status
```

If a JavaScript/TypeScript web project exists, use the project's actual commands for:

```text
format
lint
typecheck
test
build
```

Do not invent commands when the repository already defines them.

If Flutter files are modified:

```powershell
dart format .
flutter analyze
flutter test
```

If Supabase migrations/RLS/functions are changed:

- validate migration syntax
- validate affected policies
- validate function/type checks
- validate authorization behavior
- run available local/integration tests

Do not hide genuine errors merely to produce green output.

Do not change unrelated lint configuration merely to silence failures.

Separate:

```text
pre-existing failures
```

from:

```text
failures introduced by this phase
```

Fix failures introduced by the phase.

Report pre-existing failures accurately.

---

# 32. PHASE EXECUTION RULE

Every Web Admin phase follows:

```text
READ AUTHORITIES
        ↓
VERIFY GIT / WORKING TREE
        ↓
INSPECT ACTUAL IMPLEMENTATION
        ↓
STATE CURRENT-PHASE OBJECTIVE
        ↓
IDENTIFY MINIMUM FILES
        ↓
IDENTIFY PROHIBITED CHANGES
        ↓
IMPLEMENT CURRENT PHASE ONLY
        ↓
FORMAT
        ↓
STATIC ANALYSIS / TYPECHECK
        ↓
TEST
        ↓
BUILD WHEN JUSTIFIED
        ↓
REPORT
        ↓
STOP
```

Never continue automatically.

---

# WA-0 - WEB ADMIN BASELINE & SUBSCRIPTION INTEGRATION AUDIT

Read all mandatory authority files completely before making changes.

Implement only:

## `WA-0 - WEB ADMIN BASELINE & SUBSCRIPTION INTEGRATION AUDIT`

This phase is READ-ONLY except for an explicitly requested audit/completion document.

## Active roles

Especially apply:

- Principal Software Architect
- Principal Software Engineer
- Senior Full-Stack Engineer
- Senior Backend Engineer
- Senior Supabase Engineer
- Senior PostgreSQL / RLS Engineer
- Senior Subscription Systems Engineer
- Senior Application Security Engineer
- Senior Code Reviewer

## Objective

Establish the exact technical baseline of FaceTune after Subscription implementation and before Web Admin feature development.

Prove what exists.

Do not design from assumptions.

## Before coding

Run:

```powershell
git branch --show-current
git status
```

Inspect:

- actual current branch
- working tree
- Subscription completion status
- current Subscription domain contracts
- subscription products
- user entitlements
- usage ledger
- usage adjustments if present
- audit log if present
- provider/lifecycle implementation
- admin-role implementation if present
- Supabase Auth
- RLS
- Edge Functions / server APIs
- database functions / RPCs
- project root
- existing web/admin directories
- package files
- frontend framework if any
- build/deployment configuration
- test suites
- environment conventions
- service-role usage locations
- current shared-contract version implementation

## Produce

A concrete integration audit that identifies:

1. actual Subscription implementation map
2. actual entitlement data source
3. actual usage-ledger data source
4. actual remaining-balance source
5. actual admin-role capability
6. actual available server authorization mechanism
7. existing Web Admin framework status
8. existing frontend stack if any
9. existing backend/admin endpoints if any
10. RLS implications for Admin
11. service-role usage and security boundary
12. missing schema/contracts needed by WA-1+
13. likely minimum files/modules for WA-1
14. assumptions requiring runtime proof
15. any mismatch between Shared Contract and actual Subscription implementation

## Non-negotiable rules

- read-only
- no new packages
- no migration
- no admin role creation
- no web framework creation
- no entitlement mutation
- no Subscription rewrite
- no AI changes
- no deployment
- preserve current working tree

## Do NOT implement

- Admin UI
- Admin login
- Admin APIs
- Salon Pilot grant
- allowance adjustments
- audit UI
- migrations
- RLS changes
- Google Play changes
- Gemini changes

## Validation

At minimum:

```powershell
git branch --show-current
git status
```

Run existing baseline typecheck/analyze/test commands only when justified and safe.

## Done when

- actual Subscription architecture is mapped
- actual Admin capability is mapped
- actual web frontend state is proven
- shared-contract gaps are documented
- security boundary is understood
- smallest WA-1 scope is identified
- no product feature code was added

## Completion report

Use the STANDARD COMPLETION REPORT.

Then STOP.

Do not implement WA-1 unless explicitly instructed.

---

# WA-1 - ADMIN DOMAIN & SHARED CONTRACT ALIGNMENT

Read all mandatory authority files completely before making changes.

Implement only:

## `WA-1 - ADMIN DOMAIN & SHARED CONTRACT ALIGNMENT`

## Active roles

Especially apply:

- Principal Software Architect
- Senior Domain Modeling Engineer
- Senior Backend Engineer
- Senior Frontend Engineer
- Senior TypeScript Engineer
- Senior Subscription Systems Engineer
- Senior QA Engineer
- Senior Code Reviewer

## Objective

Create the minimum strongly typed Web Admin domain/contracts required to consume `subscription_admin_contract_v1` without duplicating or redefining Subscription rules.

## Before coding

- read WA-0 audit
- inspect actual Subscription domain/contracts
- inspect actual web project if present
- identify where shared DTOs/types belong
- reuse server types/contracts where safe
- do not create a second incompatible vocabulary

## Implement

Typed concepts or actual-project equivalents for:

```text
AdminRole
AdminAction
SubscriptionPlanCode
BillingProvider
EntitlementStatus
UsageType
UsageStatus
ResetPolicy

AdminUserSummary
AdminUserDetail

AdminEntitlementView
AdminUsageRecord
AdminUsageSummary

AllowanceAdjustment
AllowanceAdjustmentPreview

AuditEvent
AuditEventSource

AdminMutationResult
AdminPagination
AdminFilter / Query contracts

Shared sanitized error codes
```

If an existing generated/shared API schema already provides these, reuse it.

Do not create duplicate enum definitions merely to make the Admin project self-contained.

## Non-negotiable rules

- plan codes match Shared Contract
- entitlement statuses match Shared Contract
- usage statuses match Shared Contract
- provider codes match Shared Contract
- no raw maps through presentation where typed contracts are practical
- no business pricing ownership moved into Admin
- no client-side entitlement authority
- no AI changes

## Do NOT implement

- database migrations unless WA-0 proves a tiny contract-supporting migration is strictly required and explicitly authorized by this phase
- Admin authentication
- Admin UI pages
- Salon Pilot grant
- entitlement mutations
- usage mutations
- audit mutations
- AI operations

If a required schema gap exists that exceeds this phase, STOP and report.

## Tests

Test at minimum:

- canonical plan-code parsing
- entitlement-state parsing
- billing-provider parsing
- usage-state parsing
- unknown enum rejection/failure mapping
- immutable/admin-read-model mapping
- consistent remaining-balance field semantics
- mutation-result decoding
- error-code mapping

## Done when

- Admin and Subscription speak the same shared contract
- no alternate vocabulary was introduced
- later phases can depend on typed contracts
- no privileged behavior exists yet

## Completion report

Use STANDARD COMPLETION REPORT.

Then STOP.

Do not implement WA-2 unless explicitly instructed.

---

# WA-2 - ADMIN IDENTITY, AUTHENTICATION & AUTHORIZATION FOUNDATION

Read all mandatory authority files completely before making changes.

Implement only:

## `WA-2 - ADMIN IDENTITY, AUTHENTICATION & AUTHORIZATION FOUNDATION`

## Active roles

Especially apply:

- Senior Authentication Engineer
- Senior Authorization / RBAC Engineer
- Senior Application Security Engineer
- Senior Supabase Engineer
- Senior Backend Engineer
- Senior Web Application Engineer
- Senior Privacy Engineer
- Senior QA Engineer

## Objective

Create the secure admin identity boundary so only server-verified administrators can access privileged Admin operations.

## Before coding

Inspect:

- existing Supabase Auth
- current user/session model
- current role/profile tables
- JWT claims if used
- server authorization helpers
- Edge Function auth patterns
- RLS
- current admin bootstrap/provisioning process if any

Do not invent a new auth system if the existing one is sufficient.

## Implement

At minimum:

- authenticated Admin session support
- server-side admin-role verification
- protected server helper/middleware for Admin authorization
- protected frontend-route foundation
- unauthorized state
- revoked/expired session behavior
- logout behavior
- typed authorization failures
- minimum admin-role persistence if genuinely missing and within approved architecture

## Hard locks

Forbidden:

```text
email == hardcoded admin email
localStorage.isAdmin
frontend boolean authority
hidden URL as security
service_role in browser
JWT bypass
RLS disabled
```

A normal authenticated FaceTune user must remain a normal user.

## Admin provisioning

Use a controlled server-side mechanism.

If bootstrap requires a manual database/admin operation, document the exact action.

Do not quietly hardcode a production admin identity.

## Tests

At minimum:

- valid admin accepted
- normal user rejected
- unauthenticated rejected
- forged frontend role rejected
- expired session rejected
- revoked admin rejected where supported
- protected API rejects normal user
- protected route does not expose privileged data before auth decision
- browser bundle contains no service-role secret

## Done when

- Admin identity is server-authoritative
- privileged server entry points can verify admin status
- normal users cannot cross the boundary
- no Admin business mutation exists yet

## Completion report

Use STANDARD COMPLETION REPORT.

Then STOP.

Do not implement WA-3 unless explicitly instructed.

---

# WA-3 - PROTECTED ADMIN SHELL & NAVIGATION

Read all mandatory authority files completely before making changes.

Implement only:

## `WA-3 - PROTECTED ADMIN SHELL & NAVIGATION`

## Active roles

Especially apply:

- Senior Frontend Engineer
- Senior Web Application Engineer
- Senior Admin UX Engineer
- Senior Accessibility Engineer
- Senior Authentication Engineer
- Senior QA Engineer

## Objective

Build the private authenticated Admin application shell without implementing business mutations.

## Implement

- protected Admin layout
- authorization loading state
- unauthorized state
- session-expired state
- logout
- desktop-first responsive shell
- navigation items:
  - Dashboard
  - Users
  - Entitlements
  - Usage
  - Audit
- accessible keyboard/focus behavior
- stable layout
- route protection
- page placeholders only where later phases own the data feature

## UI principles

Use:

- restrained internal-tool styling
- dense but readable spacing
- semantic headings
- predictable navigation
- clear active route
- accessible labels
- desktop-first behavior

Avoid:

- beauty-consumer animations
- unnecessary gradients
- floating blobs
- giant hero cards
- fake stats
- emoji icons when the app design uses vector icons

## Do NOT implement

- dashboard data
- user search
- entitlement read
- Salon Pilot grant
- allowance adjustment
- suspend/revoke
- audit data
- AI generation

## Tests

- admin can access shell
- normal user cannot
- refresh preserves authorized route appropriately
- logout removes access
- expired session returns to secure state
- navigation works
- keyboard navigation works
- no privileged data fetched before admin authorization

## Done when

- secure Admin shell exists
- navigation is stable
- later feature pages have safe route destinations
- no business mutation exists

## Completion report

Use STANDARD COMPLETION REPORT.

Then STOP.

Do not implement WA-4 unless explicitly instructed.

---

# WA-4 - READ-ONLY ADMIN DASHBOARD

Read all mandatory authority files completely before making changes.

Implement only:

## `WA-4 - READ-ONLY ADMIN DASHBOARD`

## Active roles

Especially apply:

- Senior Backend Engineer
- Senior PostgreSQL Engineer
- Senior Supabase Engineer
- Senior Frontend Engineer
- Senior Performance Engineer
- Senior Admin UX Engineer
- Senior QA Engineer

## Objective

Create a read-only operational dashboard using authoritative backend aggregation.

## Candidate metrics

Only implement metrics actually supported by the approved schema.

Examples:

```text
Total Users

Active Plus
Active Pro
Active Salon Pro
Active Salon Pilot

Committed AI Looks Today
Committed AI Looks This Billing/Calendar Month

Reserved AI Look Operations
Released AI Look Operations

Expiring Salon Pilot Entitlements
```

Do not invent data.

## Backend requirements

- aggregate server-side
- authorize admin server-side
- return sanitized totals
- avoid downloading full tables to compute counts
- paginate/detail elsewhere
- use indexes where needed and justified

## Frontend requirements

- clear summary hierarchy
- loading
- success
- empty / unavailable
- error
- refresh if justified
- no fake percentages
- no fake trend graphs unless real historical data exists

## Do NOT implement

- mutations
- user search
- entitlement modification
- AI calls
- private image access

## Tests

- admin dashboard data correct for fixtures
- normal user denied
- empty system handled
- query errors handled
- dashboard does not expose private content
- large-data path uses aggregation rather than giant client payload

## Done when

- dashboard is useful and read-only
- metrics are authoritative
- no browser-side full-dataset aggregation exists

## Completion report

Use STANDARD COMPLETION REPORT.

Then STOP.

Do not implement WA-5 unless explicitly instructed.

---

# WA-5 - USERS SEARCH, PAGINATION & USER DETAIL

Read all mandatory authority files completely before making changes.

Implement only:

## `WA-5 - USERS SEARCH, PAGINATION & USER DETAIL`

## Active roles

Especially apply:

- Senior Backend Engineer
- Senior Supabase Engineer
- Senior Frontend Engineer
- Senior Privacy Engineer
- Senior Performance Engineer
- Senior Admin UX Engineer
- Senior QA Engineer

## Objective

Allow authorized admins to find FaceTune accounts and inspect subscription-relevant user detail without exposing unnecessary private FaceTune data.

## Implement

User search by:

```text
email
user_id
```

Use controlled partial email search only if the approved security/privacy design supports it.

Implement:

- server-side search
- pagination
- stable page size
- safe sorting
- sanitized user summary
- user detail route/page

User list may display:

```text
Email
User ID where appropriate
Current Plan
Entitlement Status
AI Looks Remaining
Renewal / Expiration
Account Status if supported
```

User detail may display:

```text
User ID
Email
Account Created
Current Plan
Entitlement Status
Billing Provider
AI Look Limit
Committed Usage
Reserved Usage
Remaining Usage
Period Start
Period End
Expiration
Auto-Renew where applicable
```

## Privacy hard lock

Do not expose:

- selfies
- Final Preview image
- Tutorial images
- signed URLs
- raw prompts
- Gemini payloads
- full My Makeup Kit inventory

## Tests

- exact email search
- user ID search
- no-result state
- pagination
- unauthorized request
- user detail not found
- sanitized output
- no private facial data returned
- large dataset does not load fully into browser

## Done when

- admins can locate users safely
- user detail shows subscription-relevant state
- privacy boundary is preserved

## Completion report

Use STANDARD COMPLETION REPORT.

Then STOP.

Do not implement WA-6 unless explicitly instructed.

---

# WA-6 - READ-ONLY ENTITLEMENTS & USAGE

Read all mandatory authority files completely before making changes.

Implement only:

## `WA-6 - READ-ONLY ENTITLEMENTS & USAGE`

## Active roles

Especially apply:

- Senior Subscription Systems Engineer
- Senior Backend Engineer
- Senior PostgreSQL Engineer
- Senior Frontend Engineer
- Senior Privacy Engineer
- Senior QA Engineer

## Objective

Expose authoritative entitlement and usage-ledger state to authorized admins without mutation.

## Entitlements view

Support filtering where justified by:

```text
plan
status
provider
expiration
user
```

Display:

```text
Plan
Status
Provider
Effective Allowance
Committed
Reserved
Remaining
Period
Expiration
Auto Renew
Created
Updated
```

## Usage view

Use canonical states:

```text
reserved
committed
released
```

Display sanitized fields such as:

```text
operation_id
user reference
entitlement_id
usage_type
status
created_at
committed_at
released_at
sanitized failure code
request correlation ID
```

Do not expose image content.

## Tests

- entitlement filter
- pagination
- usage filter
- canonical status mapping
- released failures distinguishable from committed success
- unauthorized access denied
- private payloads absent

## Done when

- admins can inspect entitlement and usage truth
- no mutation exists
- canonical shared vocabulary is preserved

## Completion report

Use STANDARD COMPLETION REPORT.

Then STOP.

Do not implement WA-7 unless explicitly instructed.

---

# WA-7 - SALON PILOT GRANT WORKFLOW

Read all mandatory authority files completely before making changes.

Implement only:

## `WA-7 - SALON PILOT GRANT WORKFLOW`

## Active roles

Especially apply:

- Senior Backend Engineer
- Senior Subscription Systems Engineer
- Senior Authorization Engineer
- Senior Transaction / Idempotency Engineer
- Senior Supabase Engineer
- Senior Admin UX Engineer
- Senior QA Engineer

## Objective

Implement the first production privileged Web Admin mutation: granting a temporary Salon Pilot entitlement.

## Required flow

```text
Search User
    ↓
Open User
    ↓
Grant Salon Pilot
    ↓
Default Initial AI Looks = 30
    ↓
Set Expiration
    ↓
Enter Required Reason
    ↓
Preview
    ↓
Confirm
    ↓
Server Authorization
    ↓
Server Validation
    ↓
Transactional Grant
    ↓
Audit Event
    ↓
Return Authoritative New State
```

## Salon Pilot hard locks

```text
plan_code = salon_pilot
billing_provider = admin_granted
publicly_purchasable = false
auto_renew = false
default_initial_ai_look_allowance = 30
expiration required = true
```

Use actual Subscription persistence semantics.

Do not fabricate a Google Play purchase.

## Idempotency

Duplicate grant submission must not create multiple equivalent active Pilot entitlements or duplicate grants.

Use a mutation idempotency key / operation identifier according to existing server conventions.

## Audit

Record:

- admin
- target user
- action
- entitlement
- before
- after
- reason
- request correlation
- timestamp

## Do NOT implement

- allowance adjustment
- suspension
- revocation
- commercial plan override
- AI generation

## Tests

- valid grant
- non-admin denied
- user not found
- missing expiration rejected
- missing reason rejected
- duplicate submission idempotent
- conflicting active entitlement handled according to Subscription rules
- audit exactly once
- returned remaining balance authoritative

## Done when

- Salon Pilot can be securely granted
- app-facing entitlement state reflects the grant
- operation is idempotent and audited

## Completion report

Use STANDARD COMPLETION REPORT.

Then STOP.

Do not implement WA-8 unless explicitly instructed.

---

# WA-8 - SALON PILOT ALLOWANCE ADJUSTMENTS

Read all mandatory authority files completely before making changes.

Implement only:

## `WA-8 - SALON PILOT ALLOWANCE ADJUSTMENTS`

## Active roles

Especially apply:

- Senior Subscription Systems Engineer
- Senior Backend Engineer
- Senior Transaction Engineer
- Senior Concurrency / Idempotency Engineer
- Senior PostgreSQL Engineer
- Senior Admin UX Engineer
- Senior QA Engineer

## Objective

Allow authorized admins to adjust Salon Pilot allowance without rewriting historical usage.

## Implement

Quick actions where appropriate:

```text
+5
+10
Custom
```

Support safe reduction only if approved by current SOT and Shared Contract.

Every adjustment requires:

```text
target entitlement
adjustment amount
required reason
admin identity
idempotency key
expected/current version where appropriate
timestamp
```

## Required preview

Before confirmation:

```text
Current Effective Allowance: 30
Adjustment:                 +10
New Effective Allowance:     40
Committed:                   18
Reserved:                     0
New Remaining:               22
```

Preview is informational.

Server performs final calculation and validation.

## Hard locks

Never:

- edit committed usage
- delete committed usage
- rewrite usage history
- set remaining directly
- calculate final authority only in browser
- reduce below committed usage
- ignore reservations if Subscription rules count them against available capacity

## Tests

- +5
- +10
- custom positive
- valid reduction
- reduction below committed rejected
- stale version rejected where supported
- duplicate submission applies once
- concurrent adjustments are safe
- adjustment creates audit event
- historical usage unchanged
- returned effective/remaining authoritative

## Done when

- allowance can be changed safely
- history remains immutable
- duplicate/concurrent mutation does not corrupt allowance

## Completion report

Use STANDARD COMPLETION REPORT.

Then STOP.

Do not implement WA-9 unless explicitly instructed.

---

# WA-9 - EXPIRATION, SUSPEND, REACTIVATE & REVOKE

Read all mandatory authority files completely before making changes.

Implement only:

## `WA-9 - EXPIRATION, SUSPEND, REACTIVATE & REVOKE`

## Active roles

Especially apply:

- Senior Subscription Systems Engineer
- Senior Backend Engineer
- Senior Authorization Engineer
- Senior Reliability Engineer
- Senior Transaction Engineer
- Senior Admin UX Engineer
- Senior QA Engineer

## Objective

Implement deliberate, auditable entitlement lifecycle controls allowed by the Web Admin SOT.

## Implement

### Extend expiration

Require:

- current expiration
- proposed expiration
- reason
- confirmation
- server validation
- audit

### Suspend

```text
active
↓
suspended
```

Effect:

- block new premium AI generation
- preserve account
- preserve History
- preserve Saved Looks
- preserve existing Final Previews
- preserve existing Tutorials

### Reactivate

```text
suspended
↓
active
```

Only if underlying entitlement remains valid.

Do not reactivate an expired or invalid provider-backed entitlement by ignoring Subscription rules.

### Revoke

```text
active / suspended
↓
revoked
```

Require stronger confirmation and reason.

## Provider boundary

Do not overwrite verified Google Play truth.

Administrative state must coexist with provider lifecycle according to Subscription authority.

## Tests

- extend valid expiration
- invalid date rejected
- suspend active
- generation blocked after suspend
- existing historical content still readable
- reactivate valid suspended
- invalid reactivation rejected
- revoke
- revoked generation blocked
- duplicate actions idempotent
- audit exactly once
- unauthorized denied

## Done when

- lifecycle controls are secure and auditable
- no historical user content is deleted
- Subscription semantics remain authoritative

## Completion report

Use STANDARD COMPLETION REPORT.

Then STOP.

Do not implement WA-10 unless explicitly instructed.

---

# WA-10 - AUDIT LOG & ENTITLEMENT HISTORY

Read all mandatory authority files completely before making changes.

Implement only:

## `WA-10 - AUDIT LOG & ENTITLEMENT HISTORY`

## Active roles

Especially apply:

- Senior Backend Engineer
- Senior PostgreSQL Engineer
- Senior Audit / Security Engineer
- Senior Frontend Engineer
- Senior Privacy Engineer
- Senior QA Engineer

## Objective

Provide authorized, immutable operational visibility into Admin mutations and entitlement lifecycle.

## Implement

Audit list/detail with pagination and filters such as:

```text
admin
action
target user
date
target entitlement
```

Display sanitized audit details:

```text
admin
action
target
reason
before state
after state
timestamp
request correlation ID
event source
```

Entitlement history should show meaningful timeline events:

```text
Salon Pilot granted
Allowance adjusted
Expiration extended
Suspended
Reactivated
Revoked
Provider-driven state change when applicable
```

## Hard locks

Normal Admin UI must not expose:

```text
Edit Audit
Delete Audit
Rewrite Audit
```

Do not show secrets inside before/after snapshots.

Store or present only privacy-reviewed state.

## Tests

- audit pagination
- filters
- correct lifecycle ordering
- mutation appears once
- duplicate request does not create duplicate audit
- unauthorized access denied
- immutable UI
- no sensitive payload leakage

## Done when

- Admin actions are traceable
- history is readable
- audit remains immutable through ordinary Admin UI

## Completion report

Use STANDARD COMPLETION REPORT.

Then STOP.

Do not implement WA-11 unless explicitly instructed.

---

# WA-11 - CONCURRENCY, IDEMPOTENCY & STALE-WRITE HARDENING

Read all mandatory authority files completely before making changes.

Implement only:

## `WA-11 - CONCURRENCY, IDEMPOTENCY & STALE-WRITE HARDENING`

## Active roles

Especially apply:

- Senior Concurrency Engineer
- Senior Idempotency Engineer
- Senior Transaction Engineer
- Senior PostgreSQL Engineer
- Senior Reliability Engineer
- Senior Subscription Systems Engineer
- Senior Integration Test Engineer

## Objective

Prove privileged Admin mutations remain correct under duplicate requests, concurrent operators, network retries, and simultaneous FaceTune usage.

## Test / harden scenarios

### Duplicate allowance action

```text
Admin double-clicks +10
```

Expected:

```text
+10 once
```

### Two admins

```text
Admin A: +10
Admin B: +5
```

No lost update.

### Stale write

```text
Admin A loaded allowance 30
Admin B changes allowance to 40
Admin A submits stale mutation
```

Detect/prevent silent overwrite where architecture supports version checks.

### User generating during adjustment

```text
User reserves AI Look
while
Admin changes allowance
```

Remaining capacity must remain valid.

### Suspend during generation

Define behavior according to actual Subscription transaction semantics.

Do not invent cancellation of already-running server work unless the Subscription system supports it.

### Network timeout

Server succeeds, client retries.

Mutation must remain idempotent.

### Revoke duplicate

Must not duplicate destructive side effects or audit events.

## Implement

Only the minimum backend/frontend hardening proven necessary by tests.

Do not redesign the whole Subscription ledger.

## Tests

Automated concurrency/integration tests where practical.

Document what was proven with database-level atomicity versus what requires live/manual validation.

## Done when

- duplicate admin operations do not double-apply
- concurrent edits do not corrupt state
- stale writes are handled deliberately
- usage/allowance cannot become negative due to races
- audit remains accurate

## Completion report

Use STANDARD COMPLETION REPORT.

Then STOP.

Do not implement WA-12 unless explicitly instructed.

---

# WA-12 - SECURITY, PRIVACY & ABUSE HARDENING

Read all mandatory authority files completely before making changes.

Implement only:

## `WA-12 - SECURITY, PRIVACY & ABUSE HARDENING`

## Active roles

Especially apply:

- Senior Application Security Engineer
- Senior Authorization Engineer
- Senior Privacy Engineer
- Senior Supabase / RLS Engineer
- Senior Web Security Engineer
- Senior Reliability Engineer
- Senior QA Engineer

## Objective

Perform a dedicated security and privacy pass on the Web Admin system.

## Validate

### Authentication / authorization

- unauthenticated denied
- normal user denied
- forged browser role denied
- stale/expired admin session denied
- revoked admin denied
- hidden route not considered security
- direct API invocation still requires authorization

### RLS / backend

- RLS remains enabled
- cross-user unauthorized mutations impossible
- Admin privileged path is explicit
- client cannot self-grant role
- user cannot edit entitlement
- user cannot edit usage ledger
- user cannot edit audit log

### Secrets

Search built frontend/server boundaries for accidental:

```text
service role key
provider secrets
JWT
raw purchase token
signed URL
Gemini key
```

### Web security

Where applicable to the chosen framework:

- XSS-safe rendering
- CSRF protections if cookie/session architecture requires them
- clickjacking protection
- secure headers
- Content Security Policy where justified
- secure cookie/session settings where relevant
- safe redirect handling
- input/schema validation

Do not add cargo-cult middleware unrelated to the actual architecture.

### Abuse

Protect:

- user search
- entitlement mutation
- allowance adjustment
- repeated lifecycle mutations
- audit queries/export where applicable

Use reasonable rate limiting / request bounds compatible with actual infrastructure.

## Privacy

Verify Admin endpoints do not expose:

- selfies
- Final Preview images
- Tutorial images
- full My Makeup Kit
- private prompts
- Gemini payloads
- signed URLs

unless an explicitly approved feature requires them, which V1 does not.

## Tests

Include negative/security tests.

Document limitations.

## Done when

- normal user cannot cross Admin boundary
- secrets are not exposed
- RLS remains intact
- privacy boundary is enforced
- privileged mutations require authenticated authorized server path

## Completion report

Use STANDARD COMPLETION REPORT.

Then STOP.

Do not implement WA-13 unless explicitly instructed.

---

# WA-13 - SALON PILOT RESEARCH DASHBOARD & OPERATIONAL METRICS

Read all mandatory authority files completely before making changes.

Implement only:

## `WA-13 - SALON PILOT RESEARCH DASHBOARD & OPERATIONAL METRICS`

## Active roles

Especially apply:

- Senior Product Analytics Engineer
- Senior Subscription Systems Engineer
- Senior Backend Engineer
- Senior AI Cost Optimization Engineer
- Senior Privacy Engineer
- Senior Admin UX Engineer
- Senior QA Engineer

## Objective

Provide research-safe Salon Pilot operational metrics to support real cost and usage validation without turning Admin into a private-data analytics warehouse.

## Per-entitlement metrics

Where supported:

```text
Initial Allowance
Admin Adjustments
Effective Allowance
Committed
Reserved
Remaining
Expiration

Successful Final Previews
Released / Failed AI Look Operations
```

## Aggregate Salon Pilot metrics

Where actual technical telemetry supports them:

```text
Pilot users
Active pilot entitlements
Successful delivered AI Looks
Released failed operations
Tutorial generations / technical operations
AI/API billable usage
Average effective cost per successfully delivered AI Look
```

## Cost rule

The current planning assumption:

```text
₱45 per successfully delivered AI Look
```

must not be treated as a hardcoded production fact.

Where actual cost data exists, compute:

```text
total billable AI/API cost
/
successfully delivered AI Looks
=
effective cost per AI Look
```

If actual provider cost data is not available in the system, do not fabricate it.

Show `Not available` or omit the metric.

## Privacy

Do not aggregate/report:

- private image content
- product names
- raw prompts
- raw Gemini payloads
- identifying participant details beyond operational need

## Tests

- per-pilot allowance metrics
- committed/released counts
- empty pilot data
- cost metric absent when unsupported
- no hardcoded ₱45 runtime dependency
- authorization required
- aggregate queries performant

## Done when

- Salon Pilot research can measure usage safely
- cost assumption can be validated with real data when available
- no private-data overcollection exists

## Completion report

Use STANDARD COMPLETION REPORT.

Then STOP.

Do not implement WA-14 unless explicitly instructed.

---

# WA-14 - END-TO-END SUBSCRIPTION / WEB ADMIN INTEGRATION & REGRESSION

Read all mandatory authority files completely before making changes.

Implement only:

## `WA-14 - END-TO-END SUBSCRIPTION / WEB ADMIN INTEGRATION & REGRESSION`

## Active roles

Especially apply:

- Senior Integration Test Engineer
- Senior Subscription Systems Engineer
- Senior Backend Engineer
- Senior Frontend Engineer
- Senior Reliability Engineer
- Senior QA / Regression Engineer
- Senior Production Debugging Engineer

## Objective

Validate the completed Web Admin system against the completed Subscription system without adding new product scope.

## Required journey

### Account -> Salon Pilot

```text
FaceTune account exists
    ↓
Admin finds user
    ↓
Admin grants Salon Pilot
    ↓
30 AI Looks available
    ↓
FaceTune app refreshes entitlement
    ↓
Salon Pilot visible
```

### Generate one

```text
30 remaining
    ↓
Final Preview succeeds
    ↓
usage committed
    ↓
29 remaining
```

Admin must also show:

```text
Committed = 1
Remaining = 29
```

### Adjust

```text
Admin +10
    ↓
Effective allowance = 40
Committed = 1
Remaining = 39
```

FaceTune user must receive the same authoritative remaining count.

### Suspend

```text
Admin suspends
    ↓
new Final Preview blocked
```

Existing:

```text
History
Saved Looks
Final Preview reopen
Tutorial reopen
```

remain available subject to normal data rules.

### Reactivate

```text
Admin reactivates valid entitlement
    ↓
new generation allowed
```

### Revoke

```text
Admin revokes
    ↓
new generation blocked
```

Existing historical content remains.

## Also regress

- Free
- Plus
- Pro
- Salon Pro
- store-backed entitlements
- cancellation state
- grace period where implemented
- expiration
- usage reserve/commit/release
- duplicate operation protection
- existing app UI
- Saved Looks
- History
- Tutorial
- My Makeup Kit
- canonical Final Preview

## Do NOT

- add new Admin features
- redesign consumer UI
- alter AI behavior
- change pricing

Fix only defects proven by integration testing and within existing authority.

## Done when

- Subscription and Admin agree on authoritative state
- Salon Pilot workflow is end-to-end functional
- commercial plans remain intact
- no protected FaceTune regression exists

## Completion report

Use STANDARD COMPLETION REPORT.

Then STOP.

Do not implement WA-15 unless explicitly instructed.

---

# WA-15 - REAL BROWSER / LIVE BACKEND / PRODUCTION READINESS QA

Read all mandatory authority files completely before making changes.

Implement only:

## `WA-15 - REAL BROWSER / LIVE BACKEND / PRODUCTION READINESS QA`

## Active roles

Especially apply:

- Senior Release Engineer
- Senior Production Debugging Engineer
- Senior Application Security Engineer
- Senior QA Engineer
- Senior Integration Test Engineer
- Senior Performance Engineer
- Senior Accessibility Engineer
- Senior Code Reviewer

## Objective

Perform final Web Admin acceptance testing on the intended real browser and controlled live/staging backend environment.

This phase is primarily validation and targeted defect correction.

Do not add new product scope.

## Validate authentication

```text
Admin login
Protected route
Refresh
Session expiration
Logout
Normal user denial
Revoked admin denial
```

## Validate navigation

```text
Dashboard
Users
Entitlements
Usage
Audit
```

## Validate Users

```text
Search by email
Search by user ID
Pagination
Open user
No-result
```

## Validate Salon Pilot

```text
Grant
30 AI Looks

FaceTune generates one
29 remaining

Admin +10
39 remaining

Extend expiration

Suspend
generation blocked

Reactivate
generation allowed

Revoke
generation blocked
```

## Validate audit

Every privileged mutation:

- appears exactly once
- shows correct admin
- shows correct target
- has reason
- has timestamp
- has before/after state where appropriate

## Validate security

- no service-role key in browser bundle
- no privileged endpoint works for normal user
- RLS intact
- no private image data in normal Admin responses
- no raw SQL errors
- no JWT leakage
- no signed URL leakage
- no provider-secret leakage

## Validate performance

- user list paginated
- entitlement list paginated
- usage list paginated
- audit list paginated
- dashboard aggregation responsive
- no giant browser payloads
- no unnecessary polling
- no obvious duplicate requests

## Validate accessibility

- keyboard navigation
- focus visibility
- form labels
- table semantics where practical
- readable contrast
- destructive actions clearly labeled
- confirmation dialogs usable without pointer-only interaction

## Validate deployment

- correct environment
- correct Supabase project
- secure env vars
- production build succeeds
- no secrets bundled client-side
- exact manual deployment steps documented if deployment is not authorized

## Final acceptance report

Report:

```text
WEB ADMIN V1 ACCEPTANCE:

AUTHENTICATION:
PASS / FAIL

AUTHORIZATION:
PASS / FAIL

DASHBOARD:
PASS / FAIL

USERS:
PASS / FAIL

ENTITLEMENTS:
PASS / FAIL

USAGE:
PASS / FAIL

SALON PILOT GRANT:
PASS / FAIL

ALLOWANCE ADJUSTMENTS:
PASS / FAIL

LIFECYCLE CONTROLS:
PASS / FAIL

AUDIT:
PASS / FAIL

IDEMPOTENCY:
PASS / FAIL

CONCURRENCY:
PASS / FAIL

PRIVACY:
PASS / FAIL

RLS:
PASS / FAIL

SECRET EXPOSURE:
PASS / FAIL

PERFORMANCE:
PASS / FAIL

ACCESSIBILITY:
PASS / FAIL

SUBSCRIPTION REGRESSION:
PASS / FAIL

FACE TUNE AI / V4 REGRESSION:
PASS / FAIL

MANUAL ACTIONS REQUIRED:

KNOWN LIMITATIONS:

PRODUCTION READINESS:
PASS / CONDITIONAL PASS / FAIL
```

Then use the STANDARD COMPLETION REPORT.

Then STOP.

No later phase exists in this V1 file.

---

# 33. CROSS-PHASE TEST MATRIX

The following behaviors must be covered across the relevant phases.

## Authorization

```text
Unauthenticated admin route
Normal FaceTune user
Valid admin
Expired admin session
Revoked admin
Forged frontend role
Direct API attempt without Admin role
```

## Users

```text
Email search
User ID search
No result
Pagination
Large dataset
Sanitized detail
```

## Entitlement states

```text
active
grace_period
expired
suspended
revoked
```

## Plans

```text
free
plus
pro
salon_pro
salon_pilot
```

## Salon Pilot

```text
Initial grant = 30
+5
+10
custom
safe reduction
invalid reduction
expiration extension
suspend
reactivate
revoke
```

## Usage

```text
reserved
committed
released
duplicate operation
concurrent operation
historical immutability
```

## Audit

```text
grant
adjust
extend
suspend
reactivate
revoke
duplicate request
source/admin attribution
```

## Privacy

```text
No selfie
No Final Preview bytes
No Tutorial bytes
No signed URLs
No raw prompts
No full kit data
```

## Secrets

```text
No service role in browser
No Gemini key
No JWT log
No provider secret
```

---

# 34. REQUIRED SALON PILOT ACCEPTANCE SCENARIO

Before Web Admin V1 is accepted, prove this scenario:

```text
1. Create/use a normal FaceTune account.

2. Account begins with its valid existing entitlement state.

3. Admin searches the exact account.

4. Admin grants:
   salon_pilot

5. Initial allowance:
   30 AI Looks

6. Expiration:
   explicit future timestamp/date

7. FaceTune refreshes entitlement.

8. FaceTune displays:
   Salon Pilot
   30 AI Looks remaining

9. User successfully generates one Final Makeup Preview.

10. Subscription system commits exactly one AI Look.

11. FaceTune displays:
    29 remaining

12. Web Admin displays:
    Effective allowance = 30
    Committed = 1
    Remaining = 29

13. Admin adds:
    +10

14. Effective allowance becomes:
    40

15. Committed remains:
    1

16. Remaining becomes:
    39

17. Historical usage record remains unchanged.

18. Admin suspends entitlement.

19. New Final Preview generation is blocked.

20. Existing History remains available.

21. Existing Saved Looks remain available.

22. Existing Final Preview remains reopenable.

23. Existing Tutorial remains reopenable.

24. Admin reactivates valid entitlement.

25. New Final Preview generation is allowed.

26. Admin revokes entitlement.

27. New Final Preview generation is blocked.

28. Every privileged Admin mutation appears exactly once in Audit.
```

No phase may claim complete Web Admin integration without this scenario or an explicitly documented environmental blocker.

---

# 35. COMMERCIAL PLAN READ-ONLY ACCEPTANCE

Web Admin must be able to inspect without rewriting provider truth:

## Plus

```text
Plan: Plus
Billing Provider: Google Play when Android store-backed
Limit: 3
Used
Reserved
Remaining
Period
Renewal / cancellation state
```

## Pro

```text
Plan: Pro
Limit: 8
```

## Salon Pro

```text
Plan: Salon Pro
Limit: 35
```

Admin must not create fake provider receipts or subscriptions.

---

# 36. CANCELLATION VISIBILITY

Where Subscription lifecycle supports cancellation:

```text
Active + auto-renewing
```

must be distinguishable from:

```text
Active but cancelled
Valid until period_end
```

and from:

```text
Expired
```

Do not collapse them into a single vague "Inactive" status.

---

# 37. GRACE PERIOD VISIBILITY

If the completed Subscription system supports verified provider grace periods:

Admin should display the canonical entitlement state.

Do not invent grace behavior in Web Admin.

Do not manually force `active` when Subscription says `grace_period`.

---

# 38. PROVIDER-DRIVEN REFUND / REVOCATION

Provider events and Admin actions must be distinguishable.

Do not label a provider-driven revocation as:

```text
Admin revoked
```

unless an admin actually performed the action.

Audit/event source must preserve truthful origin.

---

# 39. NO DIRECT USAGE REWRITING

The Web Admin must not include controls for:

```text
Edit committed usage
Delete usage
Set usage = 0
Set remaining = 50
```

Allowance changes happen through approved allowance-adjustment mechanisms.

If a future correction workflow is needed, it requires a separate approved authority.

---

# 40. NO DIRECT DATABASE EDITOR

The Web Admin must not become a generic Supabase replacement.

Never create:

```text
Edit arbitrary row
Run SQL
Update JSON
Delete table
Disable RLS
Change policy
Manage secrets
```

Domain-specific Admin actions only.

---

# 41. ADMIN CONFIRMATION SEVERITY

Read-only action:

```text
No confirmation
```

Moderate mutation:

```text
Preview
Reason
Confirm
```

High-risk mutation:

```text
Explicit description of effect
Required reason
Explicit confirmation
```

Examples of high-risk:

```text
Suspend
Revoke
Safe allowance reduction
```

Do not make `Revoke` a one-click icon with no context.

---

# 42. MUTATION UI STATE

While a mutation is pending:

- disable/restrict duplicate submission
- show clear progress
- prevent accidental repeated confirmation
- retain form state when failure is recoverable
- reconcile from server after success

But UI prevention is not sufficient.

Server-side idempotency remains mandatory.

---

# 43. EMPTY / ERROR STATES

Every data page must intentionally handle:

```text
loading
empty
success
error
refreshing
unauthorized
session expired
```

Examples:

```text
No users matched your search.
No active Salon Pilot entitlement.
No usage records for this period.
No audit events matched the filters.
```

Do not leave permanent spinners.

---

# 44. PAGINATION RULE

For potentially large datasets:

- server-side pagination
- bounded page size
- stable ordering
- safe filters
- no fetching all users into browser memory
- no client-only sort over unbounded data

Apply to:

```text
Users
Entitlements
Usage
Audit
```

---

# 45. FILTER RULE

Only implement filters supported by indexed/queryable fields and real operational needs.

Useful examples:

```text
Users:
email
user ID
plan
status

Entitlements:
plan
status
provider
expiration

Usage:
date
status
plan
user

Audit:
date
admin
action
target user
```

Avoid arbitrary filtering that requires downloading the world.

---

# 46. ACCESSIBILITY BASELINE

At minimum:

- semantic buttons
- labels
- keyboard reachability
- visible focus
- logical tab order
- sufficient contrast
- destructive actions labeled in text
- status meaning not color-only
- forms associated with validation messages
- dialogs focus-managed where framework supports it
- tables readable with assistive technology where practical

---

# 47. PERFORMANCE BASELINE

Requirements:

- server-side aggregation for dashboard
- server-side filtering
- pagination
- avoid repeated identical queries
- avoid unnecessary polling
- avoid giant client payloads
- avoid expensive list re-renders
- no image-heavy admin views
- no AI calls
- cache only when correctness remains clear
- prefer simple measured optimizations

Do not add a complicated caching framework because one table exists.

---

# 48. DEFINITION OF DONE FOR EVERY WEB ADMIN PHASE

A phase is complete only when:

- only current authorized phase scope was implemented
- actual branch was verified
- working tree was preserved
- higher authorities were followed
- shared contract remains compatible
- Subscription behavior remains correct
- security boundary remains intact
- RLS remains intact
- no client secret is exposed
- relevant code is formatted
- relevant lint/typecheck/analyze passes or failures are documented
- relevant tests run
- errors introduced by the phase are fixed
- no unrelated code was rewritten
- no later phase was implemented
- completion evidence is reported

Compilation alone is not enough.

A page rendering is not enough.

A completion report claiming success is not enough.

---

# 49. WEB ADMIN V1 COMPLETION FLOW

Execute:

```text
WA-0
AUDIT
↓
REPORT
↓
STOP

User reviews

WA-1
CONTRACTS
↓
TEST
↓
REPORT
↓
STOP

User reviews

WA-2
AUTH
↓
TEST
↓
REPORT
↓
STOP

...

WA-15
FINAL QA
↓
REPORT
↓
STOP
```

Never:

```text
"Implement Web Admin."
↓
Build everything
↓
hope
```

---

# 50. FINAL WEB ADMIN V1 SCOPE CHECK

When WA-15 is complete, the resulting system should provide:

```text
PRIVATE ADMIN AUTHENTICATION

SERVER-VERIFIED ADMIN AUTHORIZATION

DASHBOARD

USER SEARCH

USER DETAIL

ENTITLEMENT READ

USAGE READ

SALON PILOT GRANT

SALON PILOT ALLOWANCE ADJUSTMENT

SALON PILOT EXPIRATION EXTENSION

SUSPEND

REACTIVATE

REVOKE

AUDIT LOG

ENTITLEMENT HISTORY

SALON PILOT RESEARCH METRICS

IDEMPOTENT PRIVILEGED MUTATIONS

CONCURRENCY SAFETY

STALE-WRITE PROTECTION

RLS PRESERVATION

PRIVACY PROTECTION

PRODUCTION-READINESS QA
```

It should NOT provide any out-of-scope system listed in this file.

---

# 51. FINAL STOP RULE

After completing ANY individual WA phase:

```text
REPORT
↓
STOP
```

Do not:

- begin the next WA phase
- create speculative placeholders for later phases
- "prepare" unrelated later-phase files
- add future features while already editing
- merge
- push
- deploy
- clean the working tree

unless explicitly instructed.

For WA-15:

```text
FINAL REPORT
↓
STOP
```

The coding agent must not invent a WA-16.

