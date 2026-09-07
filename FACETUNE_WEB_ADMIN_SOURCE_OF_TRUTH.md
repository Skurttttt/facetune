# FaceTune — WEB ADMIN SOURCE OF TRUTH

**Project Path:** `C:\Users\Kurt\facetune`  
**Project Name:** FaceTune  
**Tagline:** Your AI Makeup Artist  
**Admin Surface:** Private Web Admin  
**Consumer Platform:** Flutter mobile application  
**Backend:** Supabase  
**Subscription Authority:** `FACETUNE_SUBSCRIPTION_SOURCE_OF_TRUTH.md`  
**Shared Contract:** `FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md`  
**This Document:** `FACETUNE_WEB_ADMIN_SOURCE_OF_TRUTH.md`  
**Future Phase File:** `FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md`  
**Contract Compatibility Target:** `subscription_admin_contract_v1`  
**Primary Admin Target:** Desktop web browser  
**V1 Primary Purpose:** Secure subscription, entitlement, Salon Pilot, usage, and audit administration  

---

# 0. PURPOSE

This document is the highest authority for the FaceTune **Web Admin** application and the administrative operations it is allowed to perform.

The Web Admin is a private operational control plane. It exists so an authorized FaceTune administrator can safely inspect and administer subscription and entitlement state without editing the database directly and without exposing privileged credentials to the browser.

The Web Admin exists to answer these operational questions:

```text
Which user has which entitlement?
How many AI Looks are available, reserved, committed, and remaining?
Can this user generate a new paid Final Makeup Preview?
Can an administrator grant Salon Pilot?
Can an administrator add or safely reduce Salon Pilot allowance?
Can an administrator extend, suspend, reactivate, or revoke an entitlement?
What administrative action changed this entitlement and why?
What is the current subscription / provider lifecycle state?
```

The Web Admin is NOT another consumer-facing FaceTune application.

It must not become:

- a replacement for the FaceTune mobile app
- a generic database console
- an AI prompt editor
- a Gemini control panel
- a salon CRM
- an image browser for private facial content
- a hidden bypass around subscription rules

The Subscription Source of Truth owns subscription business rules. The Shared Contract owns canonical cross-system identifiers and semantics. This Web Admin Source of Truth owns admin behavior, admin security, admin UI scope, and administrative operations.

---

# 1. DOCUMENT AUTHORITY

Before ANY Web Admin implementation, the coding agent must read these authorities in this order:

```text
1. CODEX_MASTER_GUIDE.md
2. Current protected FaceTune / V4 authority files relevant to the implementation
3. FACETUNE_SUBSCRIPTION_SOURCE_OF_TRUTH.md
4. FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md
5. FACETUNE_WEB_ADMIN_SOURCE_OF_TRUTH.md
6. FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md for the explicitly authorized phase
7. Relevant prior completion report(s), when they exist
8. Actual source code, migrations, policies, Edge Functions, tests, logs, and deployed evidence
```

Authority rules:

1. Existing protected FaceTune architecture remains authoritative for protected AI, tutorial, My Makeup Kit, storage, and user-data behavior.
2. `FACETUNE_SUBSCRIPTION_SOURCE_OF_TRUTH.md` owns subscription business rules, pricing, entitlements, AI Look consumption, lifecycle semantics, and user-facing subscription behavior.
3. `FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md` owns canonical shared identifiers, statuses, fields, action names, error codes, and compatibility semantics.
4. This document owns Web Admin scope, UX, authorization, admin mutations, auditability, and security behavior.
5. The current Web Admin phase prompt authorizes only the current phase.
6. Completion reports are evidence, not authority.
7. Actual code, migrations, tests, and deployed behavior must be inspected rather than guessed.

If this document conflicts with the Subscription Source of Truth on a subscription business rule, the Subscription Source of Truth wins.

If this document conflicts with the Shared Contract on a shared canonical identifier or state meaning, the Shared Contract wins unless an explicitly approved contract revision is performed.

If production/device/backend evidence conflicts with stale documentation, STOP and report the conflict before rewriting valid production behavior.

Do not silently invent a compatibility layer.

---

# 2. MANDATORY SYSTEM ROLE

The coding agent must act as a production engineering team composed of:

- Principal Software Engineer
- Principal Software Architect
- Senior Full-Stack Engineer
- Senior Frontend Engineer
- Senior Backend Engineer
- Senior Backend Developer
- Senior Web Application Engineer
- Senior TypeScript Engineer
- Senior API Integration Engineer
- Senior Supabase Engineer
- Senior PostgreSQL Engineer
- Senior Row Level Security Engineer
- Senior Database Reliability Engineer
- Senior Authentication Engineer
- Senior Authorization Engineer
- Senior Application Security Engineer
- Senior Web Security Engineer
- Senior Privacy Engineer
- Senior Reliability Engineer
- Senior Async / Concurrency Engineer
- Senior Performance Engineer
- Senior Domain Modeling Engineer
- Senior Subscription Systems Engineer
- Senior Entitlement Systems Engineer
- Senior Billing Integration Engineer
- Senior Audit / Compliance Engineer
- Senior QA Engineer
- Senior Regression Engineer
- Senior Integration Test Engineer
- Senior Production Debugging Engineer
- Senior Release Engineer
- Senior Code Reviewer
- Senior Admin UX Engineer
- Senior Accessibility Engineer
- Senior Observability Engineer

When changes touch the existing Flutter application, additionally act as:

- Senior Flutter Engineer
- Senior Dart Engineer
- Senior Riverpod Engineer
- Senior Mobile Integration Engineer

When changes touch existing FaceTune AI generation boundaries, additionally apply the protected requirements from the existing V4 authorities. Do not redesign Gemini behavior under the excuse of adding Admin.

The coding agent must not behave as a blind code generator.

It must:

- inspect first
- challenge stale assumptions
- reuse valid existing architecture
- prefer the smallest production-safe change
- preserve valid working behavior
- prove claims with code/tests/backend evidence
- stop when the authorized phase is complete

---

# 3. ENGINEERING PRIORITIES

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
12. usability
13. accessibility
14. visual polish

Security and authorization always outrank convenience.

Do not trade server authority for a faster implementation.

Do not trade auditability for an editable table.

Do not trade privacy for a more "informative" admin screen.

Do not perform a broad rewrite when a smaller secure integration is sufficient.

---

# 4. WEB ADMIN V1 SCOPE

V1 is intentionally limited to these primary sections:

```text
Dashboard
Users
Entitlements
Usage
Audit
```

V1 must support the minimum complete operational workflows required to administer Subscription V1 and Salon Pilot.

V1 specifically includes:

- admin authentication
- admin authorization
- protected routes
- admin session handling
- dashboard summaries
- user search
- user detail
- entitlement inspection
- grant Salon Pilot
- Salon Pilot initial allowance
- Salon Pilot allowance adjustment
- Salon Pilot expiration extension
- entitlement suspension
- entitlement reactivation
- entitlement revocation
- read-only commercial plan inspection
- usage ledger inspection
- failed/released usage visibility
- entitlement history
- audit log
- idempotent admin mutations
- concurrency-safe admin mutations
- privacy-safe error handling
- pagination/filtering
- integration with the already-implemented subscription backend

---

# 5. EXPLICIT NON-GOALS

V1 does NOT include unless explicitly approved later:

- salon CRM
- client profiles for salon customers
- appointment scheduling
- POS
- invoices
- payroll
- multiple salon branches
- multiple makeup artist seats
- team permissions beyond the minimal admin role
- affiliate management
- referral management
- promo-code management
- annual-plan management UI
- add-on pack purchasing UI
- gift subscriptions
- customer-facing support ticketing
- finance/accounting system
- generic analytics warehouse
- AI prompt editing
- Gemini model editing
- tutorial prompt editing
- Final Preview model editing
- manifest model editing
- AI resolution editing
- AI retry-policy editing
- My Makeup Kit editing
- user selfie browsing
- Final Preview image browsing
- tutorial image browsing
- raw Gemini request/response inspection
- storage browser
- SQL console
- database row editor
- RLS policy editor
- API key manager
- service-role credential manager
- arbitrary Supabase administration
- destructive bulk operations
- "grant all users" actions
- "revoke all users" actions

Do not implement excluded features merely because they would be convenient during development.

---

# 6. APPLICATION BOUNDARY

The Web Admin architecture must follow this conceptual boundary:

```text
AUTHORIZED ADMIN
      ↓
FACETUNE WEB ADMIN
      ↓
AUTHENTICATED ADMIN SESSION
      ↓
PROTECTED SERVER / EDGE FUNCTION / API
      ↓
SERVER-SIDE ADMIN AUTHORIZATION
      ↓
SUBSCRIPTION / ENTITLEMENT SERVICES
      ↓
SUPABASE DATABASE
```

Forbidden architecture:

```text
ADMIN BROWSER
      ↓
SERVICE_ROLE KEY
      ↓
DIRECT PRIVILEGED DATABASE WRITES
```

The browser is never privileged authority.

The browser sends intent.

The server validates and performs privileged mutations.

---

# 7. ADMIN AUTHENTICATION

Admin access requires a real authenticated identity using the approved project authentication infrastructure.

Requirements:

- authenticated admin account
- secure session lifecycle
- server-verifiable identity
- logout support
- expired session handling
- revoked admin handling
- no privileged data before authorization succeeds

Forbidden shortcuts:

- hardcoded admin password
- secret admin URL as the only security boundary
- email-domain trust
- hardcoded admin email in frontend code
- `isAdmin = true` client flag as authority
- browser localStorage role as authority
- query parameter granting admin access
- debug mode granting admin access

---

# 8. ADMIN AUTHORIZATION

V1 may use a minimal role model:

```text
normal_user
admin
```

Exact persistence must be proven from the repository/schema during implementation.

Every privileged server operation must independently verify admin authorization.

UI visibility is not authorization.

Protected routing is not sufficient authorization.

A normal user who manually calls an admin endpoint must be denied.

---

# 9. ADMIN SESSION SECURITY

Requirements:

- authenticated session must be valid before admin data loads
- admin authorization must be revalidated server-side for privileged operations
- logout must clear client-held session state appropriately
- expired session must fail safely
- removed/revoked admin privilege must take effect without requiring a new app build
- stale browser state must not preserve admin authority
- sensitive admin pages must not render privileged data while authorization is unresolved

If the chosen web architecture uses cookies, use secure cookie practices appropriate to that architecture.

If it uses token-based client sessions, follow the existing Supabase/session architecture securely.

Do not invent auth architecture before inspection.

---

# 10. ADMIN ACCOUNT PROVISIONING

Admin privilege must be provisioned through a controlled server-side process.

The exact bootstrap mechanism must be designed after inspecting the current schema and deployment model.

Production Admin must not rely permanently on:

```text
if email == "owner@example.com"
    allow admin
```

Any bootstrap exception must be explicit, temporary, documented, and replaced with the approved persistent authorization model.

---

# 11. DASHBOARD

The Dashboard gives an operational summary, not a decorative business-intelligence showcase.

Recommended V1 cards/metrics:

```text
Total Users
Active Plus
Active Pro
Active Salon Pro
Active Salon Pilot

AI Looks Committed Today
AI Looks Committed This Billing Month
Currently Reserved AI Looks
Released / Failed Usage Operations
```

Optional research-safe Salon Pilot summary:

```text
Salon Pilot Accounts
Effective Pilot Allowance
Committed Pilot AI Looks
Remaining Pilot AI Looks
Released Pilot Operations
```

Do not show misleading "revenue" or "profit" unless the backend has a real, validated financial data source.

---

# 12. DASHBOARD DATA RULES

Dashboard values must come from authoritative server-side aggregation or efficient server queries.

Do not:

- fetch every user into the browser to count users
- fetch the full usage ledger to compute totals client-side
- calculate authoritative subscription state in JavaScript
- infer provider status from stale cached labels

Dashboard summaries must be paginated/aggregated appropriately and must remain privacy-minimal.

---

# 13. USERS PAGE

The Users page supports controlled user lookup.

V1 search keys:

```text
email
user_id
```

A user display name may be used only if it already exists legitimately in the application and is needed operationally.

Do not create new PII fields merely to make the admin table look complete.

---

# 14. USER SEARCH RULES

Requirements:

- exact and/or controlled partial search
- server-side query
- pagination
- bounded result size
- sanitized output
- rate limiting where justified
- no unrestricted export of the entire user base
- no private face data

Search must not become a user enumeration vulnerability for non-admin callers.

---

# 15. USER LIST VIEW

Recommended columns:

```text
Email
User ID (shortened display where useful)
Current Plan
Entitlement Status
AI Looks Remaining
Renewal / Expiration
Account Status
```

Optional metadata:

```text
Account Created
Billing Provider
```

Do not display unnecessary private user information.

---

# 16. USER DETAIL VIEW

The user detail view may show:

```text
User ID
Email
Account Created
Current Plan
Entitlement Status
Billing Provider
AI Look Limit / Effective Allowance
Committed Usage
Reserved Usage
Remaining Usage
Period Start
Period End
Starts At
Expires At
Auto-Renew state when relevant
Created At
Updated At
```

Commercial store subscriptions may additionally show sanitized provider lifecycle information that is appropriate for support/admin use.

---

# 17. USER PRIVACY BOUNDARY

The subscription admin screen must NOT automatically expose:

- selfies
- Final Preview images
- Tutorial images
- signed image URLs
- storage object paths unless strictly necessary and privacy-reviewed
- raw Gemini prompts
- raw Gemini responses
- base64 data
- private My Makeup Kit contents
- full product snapshots
- face-analysis attributes unless explicitly required for a separate approved support workflow

Subscription administration does not require facial-content access.

---

# 18. ENTITLEMENTS PAGE

Admin may inspect entitlements by:

- user
- plan
- status
- billing provider
- expiration
- billing period

Recommended filters:

```text
Plan
Status
Provider
Expiration window
```

Results must be paginated server-side.

---

# 19. CURRENT ENTITLEMENT VIEW

Display shared-contract fields consistently:

```text
Plan
Status
Provider
Base Allowance
Admin Adjustment
Effective Allowance
Committed
Reserved
Remaining
Period Start
Period End
Starts At
Expires At
Auto Renew
Created
Updated
```

Fields that do not apply must be shown intentionally as not applicable rather than fabricated.

---

# 20. GRANT SALON PILOT

Granting Salon Pilot is the primary V1 privileged workflow.

Flow:

```text
Search User
      ↓
Open User
      ↓
Grant Entitlement
      ↓
Select Salon Pilot
      ↓
Initial AI Look Allowance = 30 default
      ↓
Set Expiration
      ↓
Enter Reason
      ↓
Review
      ↓
Confirm
      ↓
Server validates admin + user + entitlement rules
      ↓
Grant
      ↓
Audit event
```

Do not create a separate fake Salon Pilot account when the user already has a normal FaceTune account.

The normal account receives the `salon_pilot` entitlement.

---

# 21. SALON PILOT DEFAULTS

Web Admin must respect Subscription authority:

```text
plan_code: salon_pilot
publicly_purchasable: false
billing_provider: admin_granted
starting_ai_look_allowance: 30
auto_renew: false
expiration_required: true
allowance_admin_editable: true
```

The Web Admin may propose `30` as the default grant.

The grant form must still submit the actual server-validated value.

---

# 22. EDITABLE SALON PILOT ALLOWANCE

Salon Pilot allowance may be adjusted through audited admin operations.

Example:

```text
Original Grant: 30
Admin Adjustment: +10
Effective Allowance: 40
```

Historical committed usage must remain unchanged.

Do not implement allowance editing as direct rewriting of `used` values.

---

# 23. ADD AI LOOKS

Recommended Admin UX:

```text
+5
+10
Custom
```

The exact UI is secondary to the server contract.

Every positive allowance adjustment must include:

```text
idempotency key
admin identity
target entitlement
amount
reason
timestamp
```

The backend performs the authoritative calculation.

---

# 24. REDUCE AI LOOK ALLOWANCE

Admin may reduce Salon Pilot allowance only when the resulting effective allowance remains valid.

Example:

```text
Effective Allowance: 40
Committed: 18
Reserved: 0
```

Reducing to `30` may be valid.

Reducing to `15` must be rejected because committed usage already exceeds the proposed allowance.

If active reservations exist, the final reduction policy must also preserve currently reserved capacity according to the Shared Contract.

Do not create a negative remaining balance silently.

---

# 25. ADJUSTMENT PREVIEW

Before confirming a mutation, show its expected effect.

Example:

```text
Current Effective Allowance: 30
Adjustment: +10
New Effective Allowance: 40
Committed: 18
Reserved: 0
Expected Remaining: 22
```

The browser preview is informational.

The server recomputes and validates before committing.

---

# 26. ADJUSTMENT REASON

Every manual adjustment requires a non-empty reason.

Examples:

```text
Panel testing extension
Research requirement
Technical compensation
Administrative correction
Approved pilot extension
```

Do not allow silent numeric mutations.

---

# 27. EXTEND SALON PILOT EXPIRATION

Admin may extend Salon Pilot expiration.

Example:

```text
Current Expiration: Nov 7, 2026
New Expiration: Dec 7, 2026
Reason: Research extension
```

Requirements:

- validate new date
- enforce entitlement rules
- record before/after state
- audit action
- use idempotency/concurrency safety

---

# 28. SUSPEND ENTITLEMENT

Suspension is temporary administrative blocking.

```text
active
  ↓
suspended
```

Effects:

- new entitled Final Preview generation is blocked
- existing user account remains
- existing History remains
- existing Saved Looks remain
- existing Final Previews remain
- existing Tutorials remain
- historical usage remains

Suspension must not delete user content.

---

# 29. REACTIVATE ENTITLEMENT

A suspended entitlement may be reactivated only when underlying lifecycle rules still allow it.

```text
suspended
  ↓
active
```

Before reactivation, server validates:

- entitlement exists
- not irrevocably revoked
- not invalidly expired unless extension/grant rules permit
- provider state where applicable
- admin authorization

Do not blindly set `status = active` from the browser.

---

# 30. REVOKE ENTITLEMENT

Revocation is a deliberate administrative termination.

```text
active / suspended
      ↓
revoked
```

Requirements:

- explicit confirmation
- reason required
- admin identity recorded
- before/after state recorded
- audit event
- server authorization
- idempotency

Revocation blocks new entitled Final Preview generation according to the Subscription SOT.

It does not automatically delete historical user content.

---

# 31. REVOKE CONFIRMATION UX

Revocation must use a high-friction confirmation appropriate to its risk.

Example:

```text
Revoke Salon Pilot?

This blocks new premium AI generations for this entitlement.
Existing History, Saved Looks, Final Previews, and Tutorials remain subject to normal retention rules.

Reason:
[____________________________]

[Cancel] [Revoke Access]
```

Do not use ambiguous labels such as `Remove` for entitlement revocation.

---

# 32. MANUAL GRANT OF PLUS / PRO

V1 may support manual grants only if explicitly required by the Subscription implementation for QA, support, or controlled promotion.

Any manual commercial-plan grant must use:

```text
billing_provider = admin_granted
```

or another approved explicit provider/source representation.

Never fabricate a Google Play purchase.

Never write a fake purchase token.

Never make an admin grant indistinguishable from provider-verified billing.

---

# 33. SALON PRO ADMINISTRATION

Admin may inspect Salon Pro:

```text
plan
provider
status
billing period
35 AI Look limit
committed
reserved
remaining
renewal state
```

Do not casually edit the recurring allowance of a provider-backed Salon Pro entitlement.

Commercial plan allowance comes from Subscription/product configuration.

Any future paid-plan override mechanism must be separately approved, auditable, and must not rewrite store/provider truth.

---

# 34. USAGE PAGE

The Usage page exposes sanitized entitlement usage records.

Recommended columns:

```text
Timestamp
User
Plan
Usage Type
Operation ID / shortened display
Status
AI Look Impact
Correlation ID / shortened display
```

No image data is required.

---

# 35. USAGE STATUSES

Use only the Shared Contract values:

```text
reserved
committed
released
```

Do not create Web Admin-only synonyms such as:

```text
pending_charge
successful_charge
cancelled_charge
```

unless the Shared Contract is explicitly versioned and changed.

---

# 36. USAGE DETAIL

An individual usage record may expose:

```text
operation_id
request_correlation_id
user_id
entitlement_id
usage_type
status
created_at
committed_at
released_at
sanitized_failure_code
```

Provider/AI technical telemetry may be linked only when privacy-safe and actually required.

Do not show raw private request payloads.

---

# 37. FAILED GENERATION VISIBILITY

Admin must distinguish:

```text
SUCCESSFUL DELIVERED FINAL PREVIEW
→ committed
→ consumes 1 AI Look
```

from:

```text
FAILED / NON-DELIVERED OPERATION
→ released
→ consumes 0 AI Looks
```

This visibility is particularly important during Salon Pilot validation.

---

# 38. AI LOOK COST RESEARCH

Salon Pilot may expose operational research metrics if the underlying data exists.

Examples:

```text
AI Looks Granted
Successful AI Looks
Reserved Operations
Released / Failed Operations
Tutorial Open Count
Estimated AI Spend
Effective Cost / Delivered AI Look
```

Important:

- do not hardcode `₱45` into entitlement logic
- `₱45` is a planning assumption from the Subscription SOT
- cost display must be based on actual tracked cost/usage data if implemented
- provider pricing and FX can change
- cost metrics must not expose private prompts/images

---

# 39. SALON PILOT RESEARCH DASHBOARD

Optional V1/V1.1 research-focused panel:

```text
SALON PILOT

Original Grant: 30
Admin Adjustments: +10
Effective Allowance: 40
Committed: 27
Reserved: 0
Remaining: 13
Released Operations: 3
Expiration: <date>
```

If actual cost telemetry exists:

```text
Estimated API Spend
Effective Cost / Delivered AI Look
```

Do not fabricate metrics from assumptions.

---

# 40. ENTITLEMENT HISTORY

Admin should see meaningful lifecycle events.

Example:

```text
Sep 7
Salon Pilot granted
30 AI Looks

Sep 20
Allowance adjustment +10
Reason: Panel testing extension

Oct 1
Expiration extended

Nov 3
Suspended

Nov 4
Reactivated
```

History must be derived from authoritative events/audit records.

---

# 41. AUDIT LOG

Every privileged admin mutation must create an audit record.

Canonical actions come from the Shared Contract, including:

```text
grant_entitlement
adjust_allowance
extend_expiration
suspend_entitlement
reactivate_entitlement
revoke_entitlement
```

If later actions are added, update the Shared Contract deliberately.

---

# 42. AUDIT RECORD FIELDS

Conceptually:

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

Use privacy-safe snapshots.

Do not dump secrets/provider payloads into audit JSON.

---

# 43. AUDIT IMMUTABILITY

Normal Admin UI must not allow:

```text
Edit Audit Record
Delete Audit Record
Rewrite Action Timestamp
Rewrite Historical Actor
```

Audit records are evidence.

Any future retention/deletion policy for audit data must be explicit and separate from ordinary admin mutations.

---

# 44. ADMIN ACTION CONFIRMATION RULES

Risk-based confirmation:

### Read-only operation

No destructive confirmation.

### Moderate-risk mutation

Examples:

- add allowance
- reduce allowance
- extend expiration

Require:

- preview
- reason where required
- confirmation

### High-risk mutation

Examples:

- suspend
- revoke

Require:

- explicit confirmation
- clear consequence text
- reason

---

# 45. IDEMPOTENCY

Every privileged mutation that can create duplicate side effects must be idempotent.

Example:

```text
Admin double-clicks +10 AI Looks
```

Correct:

```text
+10 once
```

Incorrect:

```text
+20
```

Use server-side idempotency rather than trusting disabled buttons.

Apply idempotency to at minimum:

- grant entitlement
- allowance adjustment
- expiration extension where duplicate effects matter
- suspend
- reactivate
- revoke
- any future provider reconciliation action

---

# 46. CONCURRENCY

The system must handle concurrent state changes safely.

Examples:

```text
Admin A adjusts allowance
Admin B adjusts same entitlement
User simultaneously reserves an AI Look
```

or:

```text
Subscription renewal updates period
while Admin loads stale entitlement page
```

Use transaction-safe, atomic server-side operations where required.

Do not compute authoritative new totals solely in the browser.

---

# 47. OPTIMISTIC CONCURRENCY / STALE WRITES

Where architecturally appropriate, admin mutations should include an expected version / updated_at / state token.

Example:

```text
Admin A loads effective allowance = 30
Admin B changes it to 40
Admin A later submits change based on 30
```

The backend should detect stale state rather than silently overwriting newer data.

Recommended behavior:

```text
STALE_ENTITLEMENT_VERSION
```

Then Admin refreshes authoritative state.

---

# 48. SERVER-OWNED MUTATIONS

Admin Web sends user intent.

Example:

```text
adjust allowance +10
```

The server decides:

- whether admin is authorized
- whether entitlement is valid
- whether adjustment is valid
- current authoritative allowance
- current committed usage
- current reserved usage
- resulting allowance
- resulting remaining value
- audit event

The browser must not write ledger rows directly.

---

# 49. PROTECTED SERVER APIs / EDGE FUNCTIONS

Conceptual operations:

```text
admin-search-users
admin-get-user
admin-list-entitlements
admin-get-entitlement
admin-grant-entitlement
admin-adjust-allowance
admin-extend-expiration
admin-suspend-entitlement
admin-reactivate-entitlement
admin-revoke-entitlement
admin-list-usage
admin-get-usage
admin-list-audit
```

These names are conceptual.

Before implementation, inspect existing server naming conventions and reuse the established architecture.

Do not create one giant `admin-do-everything` endpoint.

Do not create dozens of trivial endpoints if one well-bounded domain operation safely serves multiple views.

Prefer clear domain boundaries.

---

# 50. API VALIDATION

Every admin mutation validates at minimum:

- authenticated caller
- server-authorized admin role
- request schema
- target user exists
- target entitlement exists when required
- current entitlement status
- action is allowed
- allowance/resulting allowance is valid
- dates are valid
- reason is present when required
- idempotency key
- expected concurrency/version state where required

Never trust IDs merely because they came from the Admin UI.

---

# 51. ROW LEVEL SECURITY

Admin functionality must NOT be implemented by disabling RLS.

Requirements:

- normal users cannot mutate premium entitlement
- normal users cannot grant Salon Pilot
- normal users cannot mutate usage ledger
- normal users cannot mutate audit log
- users may read only their own subscription data when allowed by Subscription rules
- privileged admin writes occur through protected server operations
- server authorization remains required even when database policies exist

Defense in depth is mandatory.

---

# 52. SERVICE ROLE PROTECTION

The Supabase `service_role` credential must never be exposed to:

- Flutter
- browser JavaScript
- web assets
- source maps
- public environment variables
- localStorage
- sessionStorage
- logs
- error messages
- client configuration

Privileged credentials remain server-side only.

Do not build Web Admin by embedding the service role key in a frontend `.env` variable that gets bundled anyway.

---

# 53. ERROR CONTRACT

Use stable sanitized error codes from the Shared Contract where applicable.

Examples:

```text
ADMIN_UNAUTHORIZED
USER_NOT_FOUND
ENTITLEMENT_NOT_FOUND
ENTITLEMENT_INACTIVE
ENTITLEMENT_EXPIRED
ENTITLEMENT_SUSPENDED
ENTITLEMENT_REVOKED
AI_LOOK_LIMIT_REACHED
INVALID_ALLOWANCE_ADJUSTMENT
USAGE_ALREADY_COMMITTED
STALE_ENTITLEMENT_VERSION
DUPLICATE_OPERATION
PURCHASE_VERIFICATION_FAILED
```

Browser/admin messages must be actionable but safe.

Never expose:

- raw SQL
- stack traces
- service-role keys
- provider tokens
- JWTs
- raw Gemini responses
- private URLs

---

# 54. WEB ADMIN NAVIGATION

Recommended V1 primary navigation:

```text
Dashboard
Users
Entitlements
Usage
Audit
```

Do not add tabs for excluded systems.

Navigation should be stable and desktop-friendly.

---

# 55. ADMIN UI PRINCIPLES

The Admin UI should be:

- professional
- restrained
- information-dense without being cluttered
- predictable
- accessible
- desktop-first
- consistent

Prefer:

- readable tables
- clear status badges
- useful filters
- sensible spacing
- clear destructive-action hierarchy
- explicit labels

Avoid:

- consumer beauty-app animations
- decorative gradients everywhere
- floating glass shapes
- giant marketing cards
- excessive motion
- hidden controls
- ambiguous icon-only destructive actions

This is an operations tool.

---

# 56. RESPONSIVE DESIGN

Primary target:

```text
Desktop browser
```

Also support reasonable tablet widths.

V1 mobile browser optimization is secondary unless explicitly required.

Do not compromise desktop operational density merely to force every table into a tiny phone layout.

---

# 57. STATUS VISUAL LANGUAGE

Use canonical statuses with visible text:

```text
Active
Grace Period
Expired
Suspended
Revoked
```

Color may reinforce meaning but must never be the only indicator.

Use the Shared Contract values underneath presentation labels.

---

# 58. SEARCH / FILTER UX

Users filters:

```text
Email
User ID
Plan
Status
```

Usage filters:

```text
Date range
Plan
Status
User
Usage Type
```

Audit filters:

```text
Admin
Action
Target User
Date range
```

Filters should be server-backed for large datasets.

---

# 59. PAGINATION

All potentially large lists must use bounded pagination or equivalent scalable retrieval.

Applies to:

- users
- entitlements
- usage ledger
- audit log

Do not load the entire database into browser memory.

---

# 60. SORTING

Useful supported sort fields may include:

```text
created_at
updated_at
expires_at
remaining
plan
```

Only expose sorts the backend can support safely and efficiently.

Do not implement arbitrary client-side sort over an unbounded dataset.

---

# 61. LOADING STATES

Every admin screen must represent explicit states:

```text
loading
empty
success
error
refreshing
```

Mutation state must be distinct from page loading.

Do not blank the entire application for a small row mutation when a scoped state is sufficient.

---

# 62. EMPTY STATES

Examples:

```text
No users matched your search.
```

```text
No active Salon Pilot entitlement.
```

```text
No usage records for this period.
```

```text
No audit events matched these filters.
```

Empty is not an error.

---

# 63. MUTATION LOADING

While a privileged mutation is pending:

- show explicit pending state
- prevent accidental repeated UI submission
- preserve server idempotency anyway

UI locking is convenience.

Server idempotency is protection.

---

# 64. SUCCESS FEEDBACK

Use concise operational confirmation.

Example:

```text
Salon Pilot granted successfully.
30 AI Looks available.
Expires Nov 7, 2026.
```

Allowance example:

```text
Allowance updated.
Effective allowance: 40 AI Looks.
Remaining: 22.
```

Do not claim success before server confirmation.

---

# 65. MUTATION ERROR FEEDBACK

Error messages should explain the valid business reason without exposing internals.

Example:

```text
Allowance could not be reduced.
24 AI Looks have already been committed.
The effective allowance cannot be lower than committed usage.
```

Concurrency example:

```text
This entitlement changed after you opened it.
Refresh and review the latest state before trying again.
```

---

# 66. REMAINING BALANCE AUTHORITY

Hard-lock:

> The Web Admin displays authoritative remaining allowance returned from server-side entitlement + usage state.

Do not make browser-side arithmetic the source of truth.

The UI may preview a mutation, but the backend recomputes and returns the final authoritative values.

---

# 67. PRICING VISIBILITY

Admin may display current plan prices for operational reference.

Store-backed prices must respect controlled store/product configuration.

Web Admin must not arbitrarily overwrite Google Play/App Store pricing unless a future explicitly approved workflow coordinates provider-side product configuration.

---

# 68. SALON PILOT PRICING

Salon Pilot should display:

```text
Complimentary
```

and/or:

```text
Admin Granted
```

Do not present Salon Pilot as a `₱0` public store subscription.

It is a non-public research entitlement.

---

# 69. PRODUCT CONFIGURATION BOUNDARY

V1 product configuration should be read-only or excluded unless Subscription implementation proves an operational need.

Web Admin must not become a general editor for:

- Plus price
- Pro price
- Salon Pro price
- provider SKU
- provider billing period
- store offer configuration

without a separately approved product-management design.

---

# 70. PROTECTED AI BOUNDARIES

Web Admin must not modify:

- Final Preview renderer
- Final Preview model ID
- Gemini model IDs
- recommendation prompts
- Final Preview prompts
- tutorial prompts
- tutorial prompt versions
- tutorial resolution
- manifest model
- manifest prompt version
- retry policy
- My Makeup Kit recommendation logic
- canonical Final Preview authority
- tutorial generation behavior

Admin manages entitlements.

Admin does not redesign the AI system.

---

# 71. NO AI GENERATION FROM ADMIN

V1 Web Admin must not provide:

```text
Generate Final Preview
Regenerate Final Preview
Generate Tutorial
Regenerate Tutorial
Run Gemini
```

unless a later diagnostic feature is explicitly approved.

Subscription administration must not create new paid AI operations accidentally.

---

# 72. PRIVACY

The Admin system must follow data minimization.

Subscription support generally requires:

- user identifier
- entitlement state
- provider state
- usage state
- audit state

It generally does not require private facial images.

Do not expose more user data merely because the caller is an admin.

---

# 73. LOGGING

Allowed sanitized telemetry may include:

```text
admin_user_id
admin_action
entitlement_id
plan_code
status
operation_id
request_correlation_id
latency_ms
sanitized_error_code
```

Do not log:

- JWTs
- API keys
- service-role credentials
- provider purchase tokens unless securely required and redacted
- signed URLs
- image bytes
- raw Gemini payloads
- private prompts
- selfies
- Final Preview bytes
- Tutorial bytes
- full My Makeup Kit contents

Telemetry measures system behavior, not private user content.

---

# 74. RATE LIMITING / ABUSE PROTECTION

Protect high-value admin operations appropriately.

Targets include:

- user search
- entitlement mutations
- repeated allowance changes
- audit queries/exports if later supported
- authentication attempts

Do not rely solely on the fact that "only admins use this." Admin credentials can be compromised too, because computers enjoy consistency.

---

# 75. WEB SECURITY

Implementation must account for applicable web risks based on the actual chosen stack:

- XSS
- CSRF when relevant
- clickjacking
- insecure cookies/session handling
- credential leakage
- insecure CORS
- unsafe redirects
- CSP / secure headers where appropriate
- dependency vulnerabilities

Do not cargo-cult middleware.

Inspect the actual web architecture first and apply controls that match it.

---

# 76. SENSITIVE CONFIRMATION ACTIONS

Require deliberate UX for:

```text
Reduce Allowance
Suspend Entitlement
Revoke Entitlement
```

Do not hide these behind ambiguous overflow-menu icons without labels/confirmation.

---

# 77. NO DANGEROUS BULK ACTIONS IN V1

Do not initially implement:

```text
Revoke All
Suspend All
Grant Salon Pilot To All
Add 100 Looks To Selected 500 Users
```

V1 privileged mutations are one-target-at-a-time unless an explicit batch requirement is later approved.

---

# 78. NO DIRECT DATABASE EDITING

The Web Admin must not expose generic controls such as:

```text
Edit Database Row
Run SQL
Edit Arbitrary JSON
Change RLS
Delete Table
```

Every admin mutation must be a domain-specific operation with validation and audit.

---

# 79. NO HISTORICAL USAGE REWRITING

Admin must not directly alter committed usage counts or delete ledger history to "give credits back."

Use:

```text
allowance adjustment
```

or a separately approved, auditable correction mechanism.

Historical usage remains historical evidence.

---

# 80. HISTORICAL DATA PRESERVATION

Changing entitlement must not delete:

- usage history
- entitlement history
- audit records
- existing Final Previews
- existing Tutorials
- Saved Looks
- History

Existing user-generated content remains subject to normal application retention/deletion rules, not admin entitlement mutation.

---

# 81. CANCELLATION VISIBILITY

For provider-backed subscriptions, distinguish at minimum:

```text
Active and renewing
Active but cancelled / will not renew
Expired
```

Cancellation does not necessarily mean immediate loss of entitlement.

The Subscription Source of Truth owns lifecycle semantics.

---

# 82. GRACE PERIOD VISIBILITY

If verified provider lifecycle supports a grace period, Admin must display it distinctly.

Example:

```text
Status: Grace Period
Entitled: Yes, according to verified subscription lifecycle
```

Do not convert grace period to `active` merely for simpler UI.

---

# 83. REFUND / PROVIDER REVOCATION VISIBILITY

Provider-driven changes must remain distinguishable from admin actions.

The system should be able to answer:

```text
Was this entitlement revoked by admin?
Was it refunded/revoked by provider lifecycle?
Did it naturally expire?
```

Do not falsify audit history.

---

# 84. PROVIDER SOURCE

Clearly display entitlement source where useful:

```text
Google Play
Apple App Store
Admin Granted
None
```

Salon Pilot must be clearly `Admin Granted`.

---

# 85. SALON PILOT CONTROLS

V1 must support:

```text
Grant Salon Pilot
Increase AI Looks
Reduce AI Looks safely
Extend Expiration
Suspend
Reactivate
Revoke
```

These are the primary operational mutations of the initial Web Admin.

---

# 86. SALON PILOT METRICS

Recommended fields:

```text
Original Grant
Admin Adjustments
Effective Allowance
Committed
Reserved
Remaining
Starts At
Expires At
Status
```

Optional research fields only when actual tracked data exists:

```text
Released Operations
Tutorial Open Count
Estimated AI Spend
Effective AI Cost / Delivered Look
```

---

# 87. COMMERCIAL PLAN METRICS

For Plus / Pro / Salon Pro show:

```text
Plan
Billing Provider
Entitlement Status
Billing Period
AI Look Limit
Committed
Reserved
Remaining
Auto-Renew / Renewal State
```

Commercial plans are primarily observed, not manually rewritten.

---

# 88. ADMINISTRATIVE OVERRIDE POLICY

Manual overrides to public paid plans must be exceptional.

If implemented, they require:

- explicit admin authorization
- clear source marking
- reason
- audit trail
- no fake provider transaction
- no mutation of provider receipt/token history

Do not use manual overrides as normal billing infrastructure.

---

# 89. CONTRACT VERSION

Web Admin must declare compatibility with the Shared Contract version.

Initial target:

```text
subscription_admin_contract_v1
```

The exact field/mechanism may be code-level or documentation-level depending on repository architecture.

Do not silently change canonical meanings without versioning the Shared Contract.

---

# 90. COMPATIBILITY FAILURE

If Web Admin expects a field/action/state that the Subscription backend does not support:

```text
STOP
REPORT THE CONTRACT MISMATCH
DO NOT INVENT CLIENT-SIDE FALLBACK SEMANTICS
```

Examples:

- backend does not expose `effective_allowance`
- backend status differs from Shared Contract
- admin action name conflicts with server operation
- remaining balance cannot be derived authoritatively

Do not paper over contract drift.

---

# 91. GIT SAFETY

Before every Web Admin implementation phase:

```powershell
git branch --show-current
git status
```

Do not assume the current branch.

If the current branch differs from the phase's approved branch expectations, STOP and report. Do not auto-switch.

Never automatically:

- `git reset --hard`
- `git clean -fd`
- `git restore .`
- `git checkout -- .`
- stash valid user work
- drop stashes
- switch branches destructively
- merge
- rebase
- cherry-pick unrelated work
- force push
- push to `main`
- delete branches
- overwrite unrelated files

Do not commit or push unless explicitly instructed.

---

# 92. WORKING TREE PRESERVATION

Existing valid uncommitted work must be preserved.

A dirty working tree is not permission to clean it.

The coding agent must:

- inspect changed files
- identify whether they are related
- avoid overwriting them
- report conflicts

Do not reset or stash merely to create a visually clean `git status`.

---

# 93. ARCHITECTURE INSPECTION RULE

Before implementation, inspect:

- repository root
- actual current branch
- current working tree
- whether Web Admin already exists
- current frontend/web framework if any
- package managers
- Supabase auth
- admin-role persistence if any
- subscription schema
- entitlement schema
- usage ledger
- audit schema
- Edge Functions / server APIs
- deployment configuration
- existing tests
- existing CI/build conventions

Do not assume:

- React
- Next.js
- Vite
- Flutter Web
- a second repository
- a monorepo
- a specific hosting provider

The repository decides the integration strategy.

---

# 94. DEPENDENCY POLICY

Do not add dependencies merely because they are popular.

Every new dependency must have:

- concrete requirement
- security review appropriate to risk
- maintenance justification
- no simpler existing equivalent

Prefer existing project conventions.

Do not change package managers unnecessarily.

---

# 95. SECRET MANAGEMENT

Secrets must be:

- server-side
- environment-managed
- never committed
- never bundled into frontend assets
- never printed to logs
- never returned in API responses

This includes:

- Supabase service-role key
- provider verification secrets
- private API keys
- Gemini API keys
- webhook secrets

---

# 96. ERROR SANITIZATION

Server logs may contain controlled technical identifiers when safe.

Browser errors must be sanitized.

Do not expose:

- raw SQL
- table internals unnecessarily
- provider stack traces
- secrets
- private URLs
- JWTs
- purchase tokens

Return stable error codes and useful admin-facing explanations.

---

# 97. PERFORMANCE

Requirements:

- server-side pagination
- server-side filtering where appropriate
- bounded query sizes
- appropriate indexes
- no unnecessary polling
- no excessive real-time listeners
- avoid N+1 backend access patterns
- no loading entire user base into browser memory
- responsive mutations
- efficient dashboard aggregation

Do not prematurely build an elaborate cache layer.

Measure before optimizing.

---

# 98. ACCESSIBILITY

Admin UI must support:

- keyboard navigation
- visible focus states
- semantic labels
- readable contrast
- accessible dialogs
- descriptive buttons
- non-color status indicators
- clear destructive-action warnings

Accessibility does not become optional because the audience is internal.

---

# 99. TESTING STRATEGY

Automated tests should cover at minimum:

### Authentication / Authorization

- authorized admin access
- normal user denied
- forged role denied
- expired session denied
- revoked admin denied

### User / Entitlement Reads

- user search
- no-result search
- user detail
- entitlement detail
- privacy-safe response

### Salon Pilot

- grant Salon Pilot
- duplicate grant behavior
- default 30 allowance
- custom approved initial allowance if allowed
- expiration required
- positive adjustment
- safe negative adjustment
- invalid reduction below committed usage
- expiration extension
- suspension
- reactivation
- revocation

### Usage / Ledger

- committed usage shown
- reserved usage shown
- released usage shown
- remaining matches server authority
- historical usage not rewritten

### Audit

- every mutation creates audit event
- duplicate idempotent request does not create duplicate effect
- audit fields are correct
- audit cannot be edited through normal UI

### Concurrency

- stale adjustment rejected/handled
- concurrent admin mutation safe
- user reservation concurrent with admin adjustment safe

---

# 100. SECURITY TESTS

At minimum verify:

```text
normal user cannot access protected admin data
normal user cannot invoke privileged admin API
forged admin claim is rejected
admin browser contains no service-role key
RLS remains enabled
cross-user admin mutation requires verified admin authority
invalid target user rejected
duplicate privileged request does not double-apply
raw secrets are not logged
private images are not exposed in subscription admin response
```

Security tests are not optional decoration.

---

# 101. INTEGRATION TESTS

After Subscription implementation exists, verify actual cross-system behavior:

```text
Normal FaceTune user
      ↓
Admin grants Salon Pilot
      ↓
FaceTune refreshes entitlement
      ↓
30 AI Looks available
```

Then:

```text
User generates one successful Final Preview
      ↓
Subscription commits 1 AI Look
      ↓
Admin shows 29 remaining
```

Then:

```text
Admin adds +10
      ↓
Effective allowance becomes 40
      ↓
Committed remains 1
      ↓
Remaining becomes 39
```

Then:

```text
Admin suspends
      ↓
new Final Preview generation blocked
```

Then:

```text
Admin reactivates
      ↓
generation allowed if entitlement otherwise valid
```

Then:

```text
Admin revokes
      ↓
new generation blocked
      ↓
existing History remains accessible
```

---

# 102. REAL SALON PILOT QA

Before Web Admin is accepted, perform controlled QA with a test makeup-artist account.

Minimum scenario:

```text
1. Account begins with normal/free state.
2. Admin grants Salon Pilot.
3. App shows 30 AI Looks.
4. One successful Final Preview is generated.
5. App/Admin show 29 remaining.
6. Failed generation is verified not to consume usage.
7. Tutorial opening is verified not to consume another AI Look.
8. Admin adds +10.
9. App/Admin show 39 remaining.
10. Admin suspends entitlement.
11. New Final Preview generation is blocked.
12. Admin reactivates entitlement.
13. Generation becomes available again if valid.
14. Admin revokes entitlement.
15. New generation remains blocked.
16. Existing History/Saved/Preview/Tutorial data remains.
17. Audit history shows every privileged admin action.
```

Do not mark Web Admin complete without real backend evidence for critical mutations.

---

# 103. DEFINITION OF DONE

The Web Admin system is not complete merely because pages render.

A Web Admin phase is complete only when:

- only authorized phase scope was implemented
- current Git branch was verified
- working tree was inspected and preserved
- Subscription and Shared Contract authorities were respected
- architecture remains modular
- admin authentication is correct for the phase
- admin authorization is server-enforced
- RLS remains enabled
- service-role key is not exposed
- mutations are domain-specific
- mutations are audited
- idempotency requirements are met
- concurrency requirements are met
- usage history is preserved
- privacy boundaries are preserved
- relevant code is formatted
- static analysis passes or existing unrelated failures are clearly separated
- relevant tests pass
- integration behavior is proven where required
- no protected AI behavior was rewritten
- no unrelated FaceTune functionality was rewritten
- no next phase was started
- completion evidence is reported

Compilation alone is not enough.

A report claiming `complete` is not enough.

---

# 104. PHASE EXECUTION RULE

Every Web Admin phase must follow:

```text
READ AUTHORITATIVE FILES
        ↓
VERIFY CURRENT GIT BRANCH
        ↓
RUN GIT STATUS
        ↓
INSPECT ACTUAL SUBSCRIPTION IMPLEMENTATION
        ↓
INSPECT ACTUAL WEB/ADMIN ARCHITECTURE
        ↓
STATE CURRENT PHASE OBJECTIVE
        ↓
IDENTIFY MINIMUM FILES
        ↓
IDENTIFY EXPLICITLY FORBIDDEN CHANGES
        ↓
IMPLEMENT CURRENT PHASE ONLY
        ↓
FORMAT
        ↓
STATIC ANALYSIS
        ↓
RELEVANT TESTS
        ↓
BUILD / BACKEND VALIDATION WHEN JUSTIFIED
        ↓
REPORT EVIDENCE
        ↓
STOP
```

Never automatically continue to the next phase.

Never treat successful compilation as permission to begin later work.

---

# 105. STANDARD WEB ADMIN COMPLETION REPORT

Every Web Admin phase must end with:

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

EDGE FUNCTION / API CHANGES:

ADMIN AUTHENTICATION CHANGES:

ADMIN AUTHORIZATION CHANGES:

ENTITLEMENT CHANGES:

USAGE / LEDGER CHANGES:

AUDIT CHANGES:

PRIVACY CHECK:

SECURITY CHECK:

IDEMPOTENCY / CONCURRENCY CHECK:

TESTS / VALIDATION:

REAL BACKEND EVIDENCE:

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

# 106. REQUIRED INSPECTION AND VALIDATION PRINCIPLES

Use the existing project commands and conventions proven by repository inspection.

When Flutter code is touched, use the project's established validation, typically including where appropriate:

```powershell
dart format .
flutter analyze
flutter test
```

When Android compilation is justified, preserve the project's established development configuration.

When Web Admin has its own frontend toolchain, use that toolchain's actual formatter/linter/type-check/test/build commands discovered from the repository.

When backend migrations/functions change:

- inspect migrations before creating new ones
- avoid duplicate schema concepts
- validate SQL
- validate RLS
- validate auth paths
- validate server function behavior
- do not deploy unrelated dirty work

Do not suppress real errors merely to make validation green.

---

# 107. REMOTE DEPLOYMENT RULE

Do not deploy unrelated dirty work.

Before any remote migration / Edge Function / Web Admin deployment:

- inspect `git status`
- inspect exact changed files
- prove they belong to the current phase
- verify correct Supabase project/environment
- verify correct web deployment target
- avoid unrelated CLI/toolchain upgrades unless required and approved

Remote deployment is not a substitute for understanding local changes.

Do not deploy automatically unless the current phase explicitly authorizes deployment and the user has authorized the operation when required.

---

# 108. WORKING APPLICATION PRESERVATION

Web Admin work must not break:

- existing FaceTune authentication
- Beauty Profile
- Standard Mode
- My Makeup Kit
- Final Makeup Preview
- History
- Saved Looks
- Tutorial
- protected V4 AI configuration
- existing navigation
- existing Supabase ownership boundaries

Admin changes must integrate around working systems rather than rewriting them unnecessarily.

---

# 109. PROTECTED SUBSCRIPTION BOUNDARY

Web Admin operates on Subscription capabilities that already exist.

Correct:

```text
Web Admin intent
      ↓
Subscription/Admin API
      ↓
Existing entitlement service
      ↓
Existing usage/ledger rules
```

Incorrect:

```text
Web Admin invents separate entitlement rules
Web Admin computes its own remaining balance
Web Admin writes usage directly
Web Admin bypasses reserve/commit/release
```

The Web Admin does not become a second subscription engine.

---

# 110. FINAL V1 WEB ADMIN CONTRACT

The V1 FaceTune Web Admin is considered correctly scoped when it provides a secure, auditable operational surface for:

```text
AUTHORIZED ADMIN LOGIN
        ↓
DASHBOARD
        ↓
USER SEARCH
        ↓
ENTITLEMENT INSPECTION
        ↓
SALON PILOT GRANT / ADJUST / EXTEND
        ↓
SUSPEND / REACTIVATE / REVOKE
        ↓
USAGE INSPECTION
        ↓
AUDIT INSPECTION
```

while preserving these hard locks:

```text
NO SERVICE ROLE IN BROWSER
NO RLS DISABLE
NO DIRECT DB EDITOR
NO HISTORICAL USAGE REWRITE
NO AI MODEL/PROMPT CONTROL
NO PRIVATE FACIAL IMAGE BROWSING
NO CLIENT-SIDE ENTITLEMENT AUTHORITY
NO SILENT CONTRACT DRIFT
NO AUTOMATIC LATER PHASE
```

---

# 111. FINAL HARD-LOCK SUMMARY

The following are non-negotiable for Web Admin V1:

1. Subscription business rules come from `FACETUNE_SUBSCRIPTION_SOURCE_OF_TRUTH.md`.
2. Shared identifiers/statuses/actions come from `FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md`.
3. Web Admin may operate those rules but may not redefine them.
4. Admin authorization is server-side.
5. Service-role secrets never reach the browser.
6. RLS is never disabled for convenience.
7. Salon Pilot is non-public, complimentary, admin-granted, starts at 30 AI Looks, and is admin-adjustable.
8. Allowance adjustments do not rewrite committed usage history.
9. Every privileged mutation is audited.
10. Duplicate privileged requests must not double-apply.
11. Concurrency/stale writes must be handled safely.
12. Remaining balance is server-authoritative.
13. Paid store subscription truth is not fabricated by Admin.
14. Existing user-generated content remains after entitlement expiration/suspension/revocation according to Subscription retention rules.
15. Web Admin does not control Gemini models, prompts, tutorial logic, or protected AI behavior.
16. Private user facial images are outside normal subscription-admin scope.
17. No generic DB/SQL console exists in V1.
18. One phase at a time. Validate, report, STOP.

---

# 112. DOCUMENT STATUS

**Status:** V1 SOURCE OF TRUTH  
**Scope:** FaceTune Web Admin  
**Dependency:** Subscription system must be implemented and validated before full Web Admin implementation proceeds beyond audit/read-only foundations.  
**Compatible Shared Contract:** `subscription_admin_contract_v1`  

Any future addition such as annual plans, AI Look add-on packs, salon teams, multiple admin roles, enterprise plans, bulk operations, or product-management controls requires an explicit revision of the relevant Source of Truth and Shared Contract before implementation.
