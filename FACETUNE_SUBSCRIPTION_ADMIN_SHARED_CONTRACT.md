# FaceTune - SUBSCRIPTION / ADMIN SHARED CONTRACT

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
**Shared Contract Authority:** `FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md`  
**Web Admin Authority:** `FACETUNE_WEB_ADMIN_SOURCE_OF_TRUTH.md`  
**Subscription Phase Authority:** `FACETUNE_SUBSCRIPTION_PHASE_PROMPTS.md`  
**Web Admin Phase Authority:** `FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md`  
**Contract Version:** `subscription_admin_contract_v1`  
**Primary User-Facing Usage Unit:** AI Look  
**Primary V1 Professional Research Entitlement:** Salon Pilot  
**Primary Public Professional Plan:** Salon Pro  

---

# 0. PURPOSE

This document is the shared technical contract between the FaceTune Subscription System and the FaceTune Web Admin.

It exists to ensure that both systems use the same:

- plan identifiers
- entitlement identifiers
- entitlement statuses
- billing-provider identifiers
- usage types
- usage statuses
- allowance semantics
- period semantics
- adjustment semantics
- admin action identifiers
- audit semantics
- error codes
- authorization rules
- idempotency rules
- concurrency rules
- privacy rules
- response contracts
- compatibility rules

Conceptually:

```text
FACETUNE SUBSCRIPTION SYSTEM
        ↕
FACETUNE SUBSCRIPTION / ADMIN SHARED CONTRACT
        ↕
FACETUNE WEB ADMIN
```

This file does **not** own subscription pricing strategy.

This file does **not** own Web Admin visual design.

This file does **not** authorize implementation by itself.

It defines the stable language and technical semantics that both systems must obey.

The Subscription Source of Truth answers:

> **How does FaceTune subscription work?**

The Web Admin Source of Truth answers:

> **What may an authorized FaceTune administrator view and control?**

This Shared Contract answers:

> **What exact concepts, identifiers, states, fields, mutations, and security rules must both systems agree on?**

---

# 1. DOCUMENT AUTHORITY

Before ANY Subscription or Web Admin implementation that touches shared subscription/admin concepts, the coding agent must read the relevant authority files in this order:

1. `CODEX_MASTER_GUIDE.md`
2. the current approved FaceTune V4 / AI architecture authority files
3. `FACETUNE_SUBSCRIPTION_SOURCE_OF_TRUTH.md`
4. `FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md`
5. `FACETUNE_WEB_ADMIN_SOURCE_OF_TRUTH.md`, once created and when the phase concerns Web Admin
6. the active phase prompt file
7. the latest completion report for the active phase, when one exists
8. actual source code, migrations, tests, deployed Supabase state, provider/store configuration, and real-device evidence relevant to the phase

Authority rules:

1. Existing protected FaceTune V4 / AI authorities remain highest authority for AI behavior, model selection, Final Preview generation, Tutorial behavior, My Makeup Kit behavior, and protected AI architecture.
2. `FACETUNE_SUBSCRIPTION_SOURCE_OF_TRUTH.md` is highest authority for subscription business rules, plan pricing, allowances, AI Look consumption, entitlement lifecycle, and subscription UX meaning.
3. **This Shared Contract** is highest authority for common subscription/admin identifiers, states, shared field semantics, mutation semantics, and cross-system compatibility.
4. `FACETUNE_WEB_ADMIN_SOURCE_OF_TRUTH.md` may define admin screens and admin workflows but may not override subscription business rules or this shared contract.
5. A phase prompt authorizes only the current phase.
6. Completion reports are evidence, not truth.
7. Actual code and deployed evidence must be inspected instead of assumed.

If this Shared Contract conflicts with the Subscription Source of Truth on business meaning:

> **The Subscription Source of Truth wins.**

If Web Admin requirements conflict with this Shared Contract:

> **The Web Admin implementation must be corrected to conform to the Shared Contract unless the user explicitly approves a contract revision.**

If current repository structure differs from conceptual names in this document:

- inspect the existing schema and code
- preserve valid existing entities where possible
- map them to the semantics in this document
- do not duplicate concepts merely because names differ
- STOP and report if a safe compatibility mapping cannot be proven

---

# 2. MANDATORY SYSTEM ROLE

The coding agent must act as a production engineering team composed of:

- Principal Software Engineer
- Principal Software Architect
- Principal Backend Engineer
- Senior Backend Engineer
- Senior Backend Developer
- Senior Subscription / Entitlements Systems Engineer
- Senior Billing Systems Engineer
- Senior Payments Integration Engineer
- Senior Google Play Billing Engineer
- Senior App Store / In-App Purchase Compatibility Engineer
- Senior Flutter Engineer
- Senior Flutter Developer
- Senior Dart Engineer
- Senior Mobile Application Engineer
- Senior Riverpod / Product State Engineer
- Senior Supabase Engineer
- Senior PostgreSQL Engineer
- Senior Database Migration Engineer
- Senior Row Level Security Engineer
- Senior TypeScript / Deno Engineer
- Senior API Engineer
- Senior API Integration Engineer
- Senior Domain Modeling Engineer
- Senior Authentication Engineer
- Senior Authorization Engineer
- Senior Application Security Engineer
- Senior Privacy Engineer
- Senior Distributed Systems Engineer
- Senior Idempotency Engineer
- Senior Async / Concurrency Engineer
- Senior Reliability Engineer
- Senior Observability Engineer
- Senior AI Systems Integration Engineer
- Senior AI Cost Optimization / FinOps Engineer
- Senior QA Engineer
- Senior Regression Engineer
- Senior Integration Test Engineer
- Senior Security Test Engineer
- Senior Production Debugging Engineer
- Senior Release Engineer
- Senior Code Reviewer

These rules apply equally to OpenAI Codex and Claude Code Pro.

The coding agent must not behave as a blind code generator.

It must:

- inspect first
- verify current branch and working tree
- prove existing behavior from code and deployed evidence
- challenge stale documentation
- preserve valid current architecture
- reuse existing entities where safe
- prefer the smallest production-safe change
- distinguish business authority from shared protocol semantics
- distinguish verified provider behavior from assumptions
- preserve user data integrity
- preserve auditability
- preserve server authority
- STOP when required information cannot be safely inferred

---

# 3. ENGINEERING PRIORITIES

Every decision governed by this contract must prioritize:

1. correctness
2. entitlement integrity
3. usage-ledger integrity
4. server authority
5. prevention of duplicate consumption
6. preservation of protected FaceTune AI behavior
7. security
8. privacy
9. authorization correctness
10. concurrency safety
11. idempotency
12. auditability
13. reliability
14. maintainability
15. testability
16. AI cost control
17. performance
18. user clarity
19. admin clarity
20. visual polish

Never trade entitlement correctness for convenience.

Never trade auditability for a mutable counter shortcut.

Never trust a client merely because the UI hid a button.

Never perform a broad rewrite when a smaller integration is sufficient.

---

# 4. CONTRACT VERSION

The V1 shared contract identifier is:

```text
subscription_admin_contract_v1
```

Both Subscription and Web Admin implementations must conform to the same contract version.

A future change that materially changes meanings such as:

- new plan codes
- new entitlement states
- annual billing semantics
- AI Look add-on packs
- multi-seat Salon Pro
- wallet or credit systems
- client-session billing
- different user-facing billable units

requires an explicitly approved contract revision.

Do not silently reinterpret an existing field while keeping the same contract version.

---

# 5. GIT AND WORKING-TREE SAFETY

This Shared Contract does not hardcode an implementation branch.

Before every implementation phase:

- run `git branch --show-current`
- run `git status`
- inspect current branch ancestry when relevant
- preserve valid uncommitted user work
- do not assume a previously reported branch or HEAD is still current
- if the active phase requires a different branch, STOP and report instead of switching automatically

Do not automatically:

- switch branches
- merge
- cherry-pick
- rebase
- reset
- clean
- stash valid user work
- drop stashes
- delete branches
- overwrite unrelated files
- commit
- push
- force push

Never run destructive commands such as:

```text
git reset --hard
git clean -fd
git checkout -- .
git restore .
git push --force
git push --force-with-lease
```

unless the user explicitly authorizes the exact operation.

---

# 6. SHARED SYSTEM BOUNDARY

The shared architecture is:

```text
                     FACETUNE MOBILE APP
                              │
                              │ authenticated requests
                              ▼
                    SUBSCRIPTION BACKEND
                              │
                 entitlement + usage authority
                              │
            ┌─────────────────┴──────────────────┐
            │                                    │
            ▼                                    ▼
      PUBLIC STORE FLOW                    ADMIN-GRANTED FLOW
      Google Play / future                 Salon Pilot
      approved provider                         │
            │                                    │
            └─────────────────┬──────────────────┘
                              ▼
                       SHARED CONTRACT
                              │
                  canonical plans / states
                              │
                              ▼
                     SUPABASE PERSISTENCE
                              │
           entitlements / usage / adjustments / audit
                              │
            ┌─────────────────┴──────────────────┐
            │                                    │
            ▼                                    ▼
      FACETUNE MOBILE                       WEB ADMIN
      read own state                    privileged controls
```

The Shared Contract does not give the browser direct database authority.

The Shared Contract does not move subscription authority into Flutter.

---

# 7. CANONICAL PLAN CODES

The canonical V1 plan codes are:

```text
free
plus
pro
salon_pilot
salon_pro
```

These are stable internal identities.

Do not use alternate identifiers such as:

```text
premium
premium_plus
professional
salon
salon_test
salon_research
research_salon
salon_trial
```

unless a future approved contract revision explicitly adds them.

Do not infer `plan_code` from:

- price
- localized store text
- AI Look limit
- whether an expiration date exists
- a boolean such as `isPremium`
- UI label
- product title returned by a provider

`plan_code` must be explicit.

---

# 8. PLAN CLASSIFICATION

V1 public plans:

```text
free
plus
pro
salon_pro
```

V1 non-public plan:

```text
salon_pilot
```

`salon_pilot` is:

- not publicly purchasable
- not a Google Play subscription product
- not auto-renewing
- admin granted
- temporary
- allowance editable through authorized admin operations
- intended for controlled research / pilot use

Do not create public purchase UI for `salon_pilot`.

---

# 9. CANONICAL PLAN CAPABILITY BASELINE

The Shared Contract does not own pricing, but both systems must understand the current V1 allowance mapping authorized by the Subscription Source of Truth.

Current compatibility assertions:

```text
free
  allowance = 1 one-time AI Look
  reset = none

plus
  allowance = 3 AI Looks per verified billing period
  reset = billing_period

pro
  allowance = 8 AI Looks per verified billing period
  reset = billing_period

salon_pro
  allowance = 35 AI Looks per verified billing period
  reset = billing_period

salon_pilot
  initial/default grant = 30 AI Looks
  reset = none
  allowance = admin editable
```

These are not permission to scatter literal values throughout Flutter or Web Admin.

Public-plan allowance values should resolve from controlled server/product configuration.

Salon Pilot effective allowance may be entitlement-specific.

---

# 10. PRICING AUTHORITY BOUNDARY

This Shared Contract does not independently own these prices:

```text
Plus
Pro
Salon Pro
```

Business pricing belongs to:

```text
FACETUNE_SUBSCRIPTION_SOURCE_OF_TRUTH.md
```

Store-localized purchase pricing belongs to verified provider/store configuration.

The Shared Contract owns identifiers such as:

```text
plan_code = plus
plan_code = pro
plan_code = salon_pro
```

Do not make Web Admin an unofficial store-pricing editor.

Do not display manually typed public subscription prices when verified localized store pricing is required for purchase UI.

---

# 11. BILLING PROVIDER CODES

Canonical provider codes:

```text
none
google_play
apple_app_store
admin_granted
```

V1 semantics:

```text
free
→ none

plus on Android
→ google_play

pro on Android
→ google_play

salon_pro on Android
→ google_play

salon_pilot
→ admin_granted
```

`apple_app_store` is a reserved compatibility code for future iOS support.

Its presence in this contract does not authorize iOS implementation in an Android-only phase.

Do not infer provider from plan name.

Do not use `admin_granted` for normal public store purchases merely to bypass provider verification.

---

# 12. ENTITLEMENT STATUS CONTRACT

Canonical entitlement statuses:

```text
pending
active
grace_period
expired
suspended
revoked
```

No system may invent substitute meanings such as:

```text
disabled
blocked
premium_off
inactive
cancelled_entitlement
bad
```

without an approved contract revision.

---

# 13. ENTITLEMENT STATUS - PENDING

`pending` means:

- entitlement creation or provider verification has not reached a final usable state
- premium AI generation must not be assumed available merely because purchase UI completed
- Flutter must show a stable pending/refresh state when relevant
- Web Admin must not misrepresent pending as active

`pending` must not be used as a generic error bucket.

---

# 14. ENTITLEMENT STATUS - ACTIVE

`active` means:

- the entitlement is currently valid
- the authenticated user may perform entitled AI operations if allowance remains
- provider-backed plans must still be within valid verified period semantics
- Salon Pilot must still be within its approved active period and not suspended/revoked

`active` does not imply unlimited usage.

Quota enforcement still applies.

---

# 15. ENTITLEMENT STATUS - GRACE_PERIOD

`grace_period` means:

- a provider-verified subscription is temporarily entitled according to the provider lifecycle
- access behavior follows the verified provider state
- the application must not invent its own grace duration

`grace_period` is not a Salon Pilot state unless a future approved rule explicitly adds such behavior.

---

# 16. ENTITLEMENT STATUS - EXPIRED

`expired` means:

- the valid entitlement period ended
- new paid Final Makeup Preview generation is blocked
- existing historical user content remains available subject to normal retention/deletion policy

Expiration must not delete:

- History
- Saved Looks
- persisted Final Makeup Previews
- persisted Tutorials

---

# 17. ENTITLEMENT STATUS - SUSPENDED

`suspended` means:

- the entitlement is temporarily blocked by an authorized administrative action
- new entitled AI generation is blocked
- historical data is not deleted
- reactivation may be allowed through an authorized admin operation

Suspension must not silently rewrite provider purchase history.

---

# 18. ENTITLEMENT STATUS - REVOKED

`revoked` means:

- entitlement access has been intentionally terminated by an authorized administrative/provider action
- new entitled AI generation is blocked
- the revocation remains auditable
- historical usage remains immutable

Do not use revocation as a substitute for deleting an account.

---

# 19. PURCHASE / PROVIDER LIFECYCLE CONTRACT

Provider/purchase lifecycle is distinct from entitlement status.

Conceptual purchase/provider states may include:

```text
pending
purchased
renewed
cancelled
expired
refunded
revoked
```

Important:

```text
cancelled
≠ immediately expired
```

A cancelled recurring subscription may remain entitled until the verified paid period ends.

The entitlement service translates verified provider lifecycle into entitlement status.

Flutter must not perform that translation as authoritative business logic.

Web Admin must not manually falsify provider lifecycle.

---

# 20. CANONICAL AI USAGE TYPE

V1 user-facing billable usage type:

```text
final_makeup_preview
```

This is the shared technical identity for one AI Look consumption operation.

Do not create user-facing billable usage types such as:

```text
tutorial
manifest
analysis
recommendation
makeup_kit
```

under V1.

Technical AI operations may be metered separately for cost analytics, but they must not become another user-facing AI Look deduction without an approved Subscription SOT revision.

---

# 21. UNIVERSAL AI LOOK DEFINITION

Both Subscription and Web Admin must use this exact business meaning:

> **1 AI Look = 1 successfully generated and successfully persisted Final Makeup Preview that becomes a usable canonical Final Preview for the authenticated user.**

An AI Look is not:

- a button tap
- a request
- a network call
- a Gemini call
- a selfie
- a face analysis
- a recommendation
- a Tutorial
- a Tutorial step
- a manifest analysis

A new successful persisted Final Makeup Preview consumes one AI Look.

Reopening an existing Final Makeup Preview consumes zero additional AI Looks.

---

# 22. TUTORIAL ENTITLEMENT CONTRACT

The Step-by-Step Tutorial is included with the AI Look and is optional.

Shared rule:

```text
Successful Final Makeup Preview
=
1 AI Look committed

Open Tutorial
=
0 additional AI Looks

Reopen Tutorial
=
0 additional AI Looks
```

The Tutorial may still incur internal FaceTune AI cost.

Internal Tutorial cost telemetry is not equivalent to user-facing subscription consumption.

The Shared Contract must never cause Tutorial code to decrement AI Look allowance.

---

# 23. TECHNICAL FAILURE CONTRACT

Hard-lock:

> **No usable persisted Final Makeup Preview = no committed AI Look consumption.**

A failed request may still create provider cost.

Provider cost does not justify charging the user an AI Look when no usable persisted canonical Final Preview exists.

The usage ledger must represent failure through release semantics and sanitized failure metadata rather than falsifying successful consumption.

---

# 24. USAGE LEDGER STATUS CONTRACT

Canonical usage states:

```text
reserved
committed
released
```

Do not add vague states such as:

```text
used
done
finished
failed_charge
cancelled_usage
```

without a contract revision.

A technical failure reason belongs in sanitized metadata on a released operation where appropriate.

---

# 25. USAGE STATUS - RESERVED

`reserved` means:

- entitlement capacity has been atomically held for an intended Final Makeup Preview operation
- the operation has not yet produced a committed user-facing AI Look
- the reserved capacity must reduce currently available capacity
- duplicate requests for the same idempotent operation must reuse the same reservation/result state

A reservation is not yet historical consumption.

---

# 26. USAGE STATUS - COMMITTED

`committed` means:

- a usable canonical Final Makeup Preview exists
- persistence succeeded
- ownership/lineage requirements passed
- the AI Look has been consumed exactly once
- the committed ledger entry must not be casually rewritten

A committed entry should link to the resulting canonical Final Preview or equivalent stable lineage when architecture permits.

---

# 27. USAGE STATUS - RELEASED

`released` means:

- a reservation definitively ended without a usable persisted canonical Final Preview
- the reserved capacity is returned
- no AI Look remains consumed from that failed operation

Do not release merely because the Flutter client timed out or navigated away.

The server must reconcile final server/persistence state first.

---

# 28. RESERVE / GENERATE / PERSIST / COMMIT CONTRACT

Canonical operation semantics:

```text
AUTHENTICATED REQUEST
        ↓
RESOLVE ENTITLEMENT
        ↓
CHECK STATUS
        ↓
CHECK AVAILABLE CAPACITY
        ↓
RESERVE AI LOOK
        ↓
EXISTING FACETUNE FINAL PREVIEW GENERATION
        ↓
VALIDATE EXISTING FINAL PREVIEW SUCCESS
        ↓
PERSIST CANONICAL FINAL PREVIEW
        ↓
COMMIT AI LOOK
```

Failure path:

```text
RESERVE
  ↓
GENERATION / VALIDATION / PERSISTENCE ENDS WITHOUT USABLE RESULT
  ↓
RELEASE
```

Unknown final server state:

```text
DO NOT GUESS
↓
RECONCILE FIRST
```

---

# 29. ACTIVE RESERVATIONS AND AVAILABLE CAPACITY

Active reservations must reduce immediately available generation capacity.

Canonical calculation:

```text
effective_allowance
-
committed_usage
-
active_reserved_usage
=
available_ai_looks
```

Requirements:

- result must never be negative
- quota check and reservation must be atomic or transactionally equivalent
- two concurrent requests cannot spend the same last AI Look
- released reservations restore capacity
- committed reservations become committed usage

---

# 30. USER-FACING REMAINING VS INTERNAL COUNTS

Shared response concepts should distinguish:

```text
effective_allowance
committed_usage
reserved_usage
available_ai_looks
```

`available_ai_looks` is the authoritative number available for a new generation at that moment.

When there are no active reservations:

```text
available_ai_looks
=
effective_allowance
-
committed_usage
```

Web Admin may show reserved count separately.

Flutter should not invent remaining usage from local state.

---

# 31. BASE ALLOWANCE AND ADJUSTMENT SEMANTICS

For entitlements that permit administrative allowance adjustments, distinguish:

```text
base_allowance
adjustment_total
effective_allowance
```

Canonical rule:

```text
base_allowance
+
sum(valid allowance adjustments)
=
effective_allowance
```

Example:

```text
base_allowance = 30
adjustment_total = +10
effective_allowance = 40
committed_usage = 18
reserved_usage = 0
available_ai_looks = 22
```

Do not rewrite committed usage in order to increase available capacity.

---

# 32. SALON PILOT SHARED CONTRACT

Canonical shared semantics:

```text
plan_code = salon_pilot
publicly_purchasable = false
billing_provider = admin_granted
default_initial_ai_look_allowance = 30
auto_renew = false
automatic_reset = false
expiration_required = true
allowance_admin_editable = true
```

Salon Pilot is:

- complimentary
- temporary
- private/non-public
- admin granted
- research/pilot oriented
- one makeup artist account under the current V1 business model
- based on a pool of AI Looks
- not based on client sessions
- not based on 3 previews per client

Do not create hidden client-session billing.

Do not identify or count clients for subscription enforcement.

---

# 33. SALON PILOT ALLOWANCE CHANGE CONTRACT

Example:

```text
initial base allowance = 30
admin adjustment = +10
effective allowance = 40
```

The admin operation must:

- be authorized server-side
- be auditable
- have a stable idempotency identity
- preserve committed usage history
- recompute authoritative available capacity
- reject invalid reductions

Changing Salon Pilot allowance must not require a mobile app release.

---

# 34. SALON PRO SHARED CONTRACT

Current compatibility semantics:

```text
plan_code = salon_pro
publicly_purchasable = true
recurring = true
reset_type = billing_period
monthly_ai_look_limit = 35
billing_provider = verified public provider
```

Salon Pro uses an AI Look pool.

It does not use:

```text
1 client = N previews
client sessions
per-client billing
face identity for billing
```

A bridal user may consume multiple AI Looks.

Each new successful Final Makeup Preview consumes one AI Look.

---

# 35. FREE SHARED CONTRACT

Current compatibility semantics:

```text
plan_code = free
billing_provider = none
ai_look_limit = 1
reset_type = none
recurring = false
rollover = false
```

The one Free AI Look is one-time only.

It never replenishes monthly.

---

# 36. PLUS SHARED CONTRACT

Current compatibility semantics:

```text
plan_code = plus
recurring = true
reset_type = billing_period
monthly_ai_look_limit = 3
rollover = false
```

Public purchase activation must be based on verified provider state.

---

# 37. PRO SHARED CONTRACT

Current compatibility semantics:

```text
plan_code = pro
recurring = true
reset_type = billing_period
monthly_ai_look_limit = 8
rollover = false
```

Public purchase activation must be based on verified provider state.

---

# 38. RESET POLICY CONTRACT

Canonical reset types:

```text
none
billing_period
```

V1 mapping:

```text
free
→ none

plus
→ billing_period

pro
→ billing_period

salon_pro
→ billing_period

salon_pilot
→ none
```

Salon Pilot allowance changes are admin adjustments, not "resets."

Do not model Salon Pilot as a recurring monthly subscription.

---

# 39. NO ROLLOVER CONTRACT

For recurring public paid plans:

```text
rollover_allowed = false
```

Unused AI Looks do not accumulate into a later billing period.

Example:

```text
Plus limit = 3
used = 1
unused = 2

new verified period
→ 3 available

NOT
→ 5 available
```

Salon Pilot is a total grant and therefore has no rollover concept in V1.

---

# 40. ENTITLEMENT PERIOD CONTRACT

Recurring provider-backed plans use:

```text
period_start
period_end
```

Admin-granted temporary entitlements such as Salon Pilot use:

```text
starts_at
expires_at
```

Do not treat these pairs as interchangeable.

Requirements:

- recurring reset follows verified billing period
- Salon Pilot expiration follows admin-granted entitlement dates
- cancellation does not rewrite `period_end`
- expiration must be derived from authoritative provider/admin state
- Flutter does not invent dates

---

# 41. CANONICAL ENTITLEMENT FIELD SEMANTICS

Conceptual shared entitlement fields:

```text
id
user_id
plan_code
status
billing_provider
provider_product_id
provider_subscription_reference
period_start
period_end
starts_at
expires_at
auto_renew
base_ai_look_limit
verified_at
created_at
updated_at
```

Potential additional implementation fields may exist after schema inspection.

Do not treat conceptual names as permission to duplicate existing valid schema.

Each semantic field must have one clear purpose.

---

# 42. CANONICAL USAGE FIELD SEMANTICS

Conceptual shared usage fields:

```text
id
user_id
entitlement_id
usage_type
operation_id
canonical_preview_id
period_start
period_end
status
reserved_at
committed_at
released_at
sanitized_failure_code
created_at
updated_at
```

Requirements:

- `operation_id` must support idempotency
- `canonical_preview_id` is required for committed usage when architecture permits
- released usage must not count as committed
- usage ownership must match entitlement ownership
- period linkage must be stable for recurring plans

---

# 43. CANONICAL ALLOWANCE ADJUSTMENT CONTRACT

Conceptual adjustment fields:

```text
id
entitlement_id
target_user_id
admin_user_id
adjustment_type
amount
reason
idempotency_key
created_at
```

Canonical V1 adjustment types:

```text
increase_allowance
decrease_allowance
```

Expiration changes are lifecycle/admin events, not numerical AI Look adjustments.

Do not use adjustment rows to falsify provider billing periods.

---

# 44. SAFE ALLOWANCE REDUCTION

An admin may reduce an editable Salon Pilot allowance only when the result remains valid.

At minimum:

```text
new_effective_allowance
>= committed_usage
```

The implementation must also account safely for active reservations.

If:

```text
committed = 24
reserved = 1
effective allowance = 30
```

a reduction that would invalidate currently held capacity must be rejected or safely reconciled according to approved backend rules.

Do not create negative available capacity.

Do not delete committed ledger rows to make a reduction fit.

---

# 45. CANONICAL ADMIN ACTION IDENTIFIERS

Shared admin action identifiers:

```text
grant_salon_pilot
increase_allowance
decrease_allowance
extend_expiration
suspend_entitlement
reactivate_entitlement
revoke_entitlement
```

Future actions require an approved contract revision or an explicitly compatible extension.

Do not use arbitrary strings per endpoint.

---

# 46. GRANT SALON PILOT CONTRACT

A valid `grant_salon_pilot` operation must:

- target an existing authenticated FaceTune user identity
- be performed by an authorized admin
- create/activate the appropriate admin-granted entitlement using server authority
- use an approved initial allowance
- require a valid expiration
- create an audit event
- be idempotent
- not create duplicate active Salon Pilot entitlements for the same intended grant
- not expose service-role credentials
- not modify the user's historical AI Look ledger

Do not grant by hardcoded email in application code.

Email may be used for admin search/lookup, not as the authorization key.

---

# 47. EXTEND EXPIRATION CONTRACT

A valid `extend_expiration` operation must:

- target an admin-editable entitlement
- validate the new expiration
- preserve historical expiration/audit evidence
- record before and after values
- require a reason
- be idempotent
- not rewrite unrelated fields

Do not silently extend a provider-backed public subscription using Salon Pilot admin semantics.

---

# 48. SUSPEND ENTITLEMENT CONTRACT

A valid `suspend_entitlement` operation must:

- be authorized server-side
- record an auditable event
- transition to `suspended` only from an allowed state
- block new entitled Final Preview generation
- preserve historical content and ledger history
- preserve provider purchase history
- not delete the user account

---

# 49. REACTIVATE ENTITLEMENT CONTRACT

A valid `reactivate_entitlement` operation must:

- be authorized
- verify the entitlement is eligible for reactivation
- not bypass provider validity for public plans
- restore `active` only when business/provider rules permit
- preserve audit history

Salon Pilot reactivation must still respect `expires_at`.

---

# 50. REVOKE ENTITLEMENT CONTRACT

A valid `revoke_entitlement` operation must:

- be authorized
- be auditable
- block new entitled generation
- preserve historical AI Look usage
- preserve existing user-generated results
- not delete the account
- not silently rewrite provider history

Revocation is not cancellation.

---

# 51. CANCELLATION VS REVOCATION

Cancellation:

```text
provider subscription will not renew
but may remain active until verified period_end
```

Revocation:

```text
entitlement access is intentionally terminated
according to authorized provider/admin rules
```

Do not collapse both into a generic `inactive` value.

---

# 52. EXPIRATION BEHAVIOR

When entitlement expires:

- new paid Final Makeup Preview generation is blocked
- existing Final Makeup Previews remain viewable
- existing Tutorials remain viewable
- History remains
- Saved Looks remain
- normal user retention/deletion rules still apply

Expiration is an entitlement event, not a data-deletion event.

---

# 53. ADMIN AUTHORIZATION CONTRACT

V1 account-level authorization should distinguish at least:

```text
normal_user
admin
```

Exact persistence may use an existing role/claims system after inspection.

Web Admin must never infer admin authority from:

- email address
- email domain
- a hardcoded allowlist in browser code
- Flutter state
- browser localStorage
- a hidden route
- UI visibility
- a query parameter

Admin authorization must be verified server-side for every privileged operation.

---

# 54. ADMIN AUTHENTICATION CONTRACT

Admin must authenticate using an approved FaceTune/Supabase authentication flow or compatible existing secure auth.

Authentication proves identity.

Authorization separately proves admin privilege.

Do not treat successful login as proof of admin authority.

---

# 55. SERVER AUTHORITY CONTRACT

Hard-lock:

```text
Flutter
≠ entitlement authority

Web Admin browser
≠ entitlement authority

Google Play client callback
≠ entitlement authority by itself
```

Server-side trusted logic decides:

- current entitlement
- entitlement status
- provider verification result
- effective allowance
- committed usage
- active reservations
- available AI Looks
- allowed admin mutations
- suspension/revocation effect
- usage commit/release

---

# 56. SERVICE ROLE SAFETY

The Supabase service-role key or equivalent privileged secret must never be exposed in:

- Flutter
- Dart assets
- Android resources
- Web Admin browser JavaScript
- frontend environment bundles
- public config
- logs
- error responses
- screenshots/documentation containing live secrets

Privileged mutations must execute server-side.

---

# 57. ROW LEVEL SECURITY CONTRACT

RLS / authorization must ensure:

- user A cannot read user B's entitlement
- user A cannot read user B's usage ledger
- user A cannot edit their own premium plan directly
- user A cannot increase their own allowance
- user A cannot grant themselves Salon Pilot
- user A cannot modify provider verification state
- user A cannot insert fake committed usage
- user A cannot release real committed usage
- user A cannot attach user B's canonical preview to usage
- normal users cannot perform admin actions
- admin browser cannot bypass server authorization merely because it is an admin UI

Never disable RLS for convenience.

Server-side authorization must still validate ownership even with RLS.

Defense in depth is required.

---

# 58. ADMIN WRITE PATH

Correct privileged path:

```text
WEB ADMIN
   ↓
authenticated admin session
   ↓
protected server / Edge Function / server API
   ↓
verify admin authorization
   ↓
validate requested transition / mutation
   ↓
transaction-safe persistence
   ↓
audit event
   ↓
sanitized typed response
```

Prohibited:

```text
WEB ADMIN BROWSER
   ↓
service_role key
   ↓
direct privileged database mutation
```

---

# 59. IDEMPOTENCY CONTRACT

Idempotency is mandatory where duplicate events could change money, usage, or entitlement state.

Protect at minimum:

- AI Look reservation
- AI Look commit
- AI Look release
- purchase verification
- renewal processing
- refund/revocation processing
- Salon Pilot grant
- allowance increase
- allowance decrease
- expiration extension
- suspension
- reactivation
- revocation

Duplicate invocation must not create duplicate:

- usage
- entitlements
- allowance adjustments
- audit events representing distinct business actions
- paid AI work

Use database uniqueness, transactions, stable operation identifiers, or equivalent safe mechanisms.

Client-side disabling is not enough.

---

# 60. OPERATION AND CORRELATION IDENTIFIERS

Shared technical identifiers should include concepts equivalent to:

```text
operation_id
request_correlation_id
idempotency_key
```

Semantics:

- `operation_id` identifies an AI Look usage operation
- `idempotency_key` identifies a repeat-safe business mutation
- `request_correlation_id` supports sanitized tracing across layers

Do not use private image paths or user content as idempotency keys.

Do not log sensitive provider tokens merely for correlation.

---

# 61. CONCURRENCY CONTRACT

Concurrency safety is required when:

- user taps Generate twice
- two requests race for the last AI Look
- admin changes allowance while generation is reserved
- provider renewal arrives during usage
- provider revocation arrives during generation
- two admins update the same entitlement
- the same admin action is retried
- app reconnects while server work continues

At minimum:

- quota check + reserve is atomic
- allowance adjustment is transaction-safe
- entitlement lifecycle transition is validated against current state
- lost-update behavior is prevented
- duplicate mutation is idempotent
- negative available capacity is prohibited

Use optimistic concurrency, row locking, transactional functions, or equivalent architecture after inspecting the current database.

Do not force a specific primitive before inspection.

---

# 62. HISTORICAL DATA INTEGRITY

Historical committed usage is immutable under normal operations.

Prohibited:

```text
used = 18
admin manually changes used = 3
```

Correct:

```text
base allowance = 30
committed usage = 18
admin adjustment = +10
effective allowance = 40
available = 22
```

If a genuine accounting correction is required later, it must be represented by an approved auditable correction model, not silent history rewriting.

---

# 63. AUDIT EVENT CONTRACT

Every privileged admin mutation must create or participate in an immutable/auditable event trail.

Conceptual fields:

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
idempotency_key
created_at
```

Audit events must be:

- server-created
- tied to authenticated admin identity
- immutable under normal Admin UI
- sanitized
- sufficient to explain entitlement changes

Do not place private face data in audit logs.

---

# 64. AUDIT REASON CONTRACT

High-impact admin mutations require a reason.

Examples:

```text
Additional panel testing
Research extension
Pilot access suspended
Pilot completed
Administrative correction
```

Do not require private client names or sensitive user content in the reason.

Reason text should be operationally useful and privacy-conscious.

---

# 65. WEB ADMIN READ CONTRACT

Subscription Web Admin may read only the information needed to administer entitlement safely.

Conceptually allowed:

```text
user identity reference
email for lookup/display when permitted
user_id
current plan
entitlement id
entitlement status
billing provider
effective allowance
committed usage
reserved usage
available AI Looks
period start/end
starts_at/expires_at
auto-renew indicator when provider data supports it
allowance adjustments
entitlement history
sanitized usage records
admin audit history
```

Subscription Admin screens do not require private facial content.

---

# 66. PRIVACY BOUNDARY FOR WEB ADMIN

Do not expose in subscription administration merely because the admin is privileged:

- original selfie image binaries
- Final Makeup Preview binaries
- Tutorial images
- signed image URLs
- raw Gemini requests
- full prompts
- My Makeup Kit contents
- user-entered product details
- private analysis payloads
- raw provider credentials
- full purchase tokens
- JWTs

Admin privilege is not permission to browse unrelated private user content.

---

# 67. USER-FACING DATA CONTRACT

Safe user-facing subscription state may include:

```text
plan_code
plan_display_name
entitlement_status
effective_allowance
committed_usage
available_ai_looks
period_end
expires_at
renewal/cancellation display state when verified
```

Do not expose:

- admin audit internals
- service-role details
- provider verification secrets
- raw provider responses
- internal SQL errors
- internal stack traces
- privileged role data

---

# 68. PUBLIC PRODUCT CONFIGURATION CONTRACT

Conceptual shared public product configuration:

```text
plan_code
display_name
publicly_purchasable
billing_provider
provider_product_id
ai_look_limit
active
```

Price may be represented server-side for business configuration, but purchase UI must respect verified provider/store localized pricing when applicable.

Do not let Web Admin silently change provider pricing without matching provider configuration.

Do not guess provider product IDs.

---

# 69. PROVIDER REFERENCE CONTRACT

Provider-backed entitlements may require concepts equivalent to:

```text
provider_product_id
provider_purchase_token
provider_subscription_reference
provider_transaction_reference
verified_at
```

Sensitive provider references must be stored and exposed according to least privilege.

Web Admin does not need full raw purchase tokens for ordinary subscription support views.

Flutter must not become the long-term authority for provider tokens.

---

# 70. SALON PILOT PROVIDER CONTRACT

Salon Pilot uses:

```text
billing_provider = admin_granted
```

It has no store purchase token.

It has no recurring provider renewal.

Its authority comes from:

```text
authorized admin mutation
+
server-side entitlement persistence
+
audit trail
```

Do not create fake Google Play records for Salon Pilot.

---

# 71. ERROR CODE CONTRACT

Shared sanitized V1 error codes should support at least:

```text
AUTH_REQUIRED
ADMIN_UNAUTHORIZED

ENTITLEMENT_NOT_FOUND
ENTITLEMENT_PENDING
ENTITLEMENT_INACTIVE
ENTITLEMENT_EXPIRED
ENTITLEMENT_SUSPENDED
ENTITLEMENT_REVOKED

AI_LOOK_LIMIT_REACHED
AI_LOOK_RESERVATION_CONFLICT
USAGE_OPERATION_NOT_FOUND
USAGE_ALREADY_COMMITTED
USAGE_ALREADY_RELEASED
USAGE_STATE_CONFLICT

INVALID_PLAN_CODE
INVALID_ENTITLEMENT_TRANSITION
INVALID_ALLOWANCE_ADJUSTMENT
ALLOWANCE_BELOW_COMMITTED_USAGE
ALLOWANCE_CONFLICTS_WITH_ACTIVE_RESERVATION

SALON_PILOT_ALREADY_GRANTED
SALON_PILOT_EXPIRED

PURCHASE_VERIFICATION_FAILED
PROVIDER_STATE_CONFLICT

IDEMPOTENCY_CONFLICT
CONCURRENT_MODIFICATION

TEMPORARY_BACKEND_FAILURE
```

Exact error type implementation may use enums/sealed classes after inspection.

Do not expose raw SQL/provider internals to Flutter or Web Admin.

---

# 72. MUTATION REQUEST CONTRACT

A privileged mutation request should contain only the minimum required fields.

Conceptual example:

```json
{
  "targetUserId": "<uuid>",
  "action": "increase_allowance",
  "entitlementId": "<uuid>",
  "amount": 10,
  "reason": "Additional panel testing",
  "idempotencyKey": "<stable-random-id>"
}
```

The browser must not send:

- trusted `admin_user_id`
- service-role credentials
- fake current entitlement status
- fake current usage
- trusted before-state
- arbitrary user role
- provider secrets

The server resolves and validates trusted state.

---

# 73. MUTATION RESPONSE CONTRACT

Privileged mutation responses should be typed and consistent.

Conceptually:

```json
{
  "success": true,
  "action": "increase_allowance",
  "entitlementId": "<uuid>",
  "planCode": "salon_pilot",
  "status": "active",
  "effectiveAllowance": 40,
  "committedUsage": 18,
  "reservedUsage": 0,
  "availableAiLooks": 22,
  "expiresAt": "<timestamp>",
  "updatedAt": "<timestamp>"
}
```

Do not return unrelated private user data.

Do not use random response shapes per endpoint.

---

# 74. READ RESPONSE CONTRACT

A shared entitlement summary response should conceptually provide:

```text
entitlement_id
plan_code
display_name
status
billing_provider
effective_allowance
committed_usage
reserved_usage
available_ai_looks
period_start
period_end
starts_at
expires_at
auto_renew
```

Fields not applicable to a plan may be null/absent according to the typed contract.

Do not infer plan type from nulls.

---

# 75. REMAINING BALANCE AUTHORITY

Hard-lock:

> **The authoritative remaining/available AI Look count comes from server-side entitlement + usage state.**

Not:

```text
Flutter decrements local counter
```

Not:

```text
Web Admin browser calculates independently
```

Not:

```text
Google Play product metadata supplies usage
```

The server returns the current authoritative state.

---

# 76. ZERO-ALLOWANCE CONTRACT

When:

```text
available_ai_looks = 0
```

new Final Makeup Preview reservation must be rejected with a stable exhausted/quota error.

The system must not:

- start Gemini work first
- allow negative capacity
- let Flutter bypass quota
- let Salon Pilot silently exceed its grant

Existing content remains viewable.

---

# 77. ACTIVE RESERVATION DISPLAY CONTRACT

Web Admin may display:

```text
reserved_usage
```

to explain temporary capacity holds.

Flutter may use the authoritative `available_ai_looks` without needing to expose technical reservation details to ordinary users unless product UX later requires it.

Do not show misleading "used" counts that include in-progress reservations as permanently consumed.

---

# 78. PURCHASE VERIFICATION CONTRACT

Public provider purchase flow:

```text
Flutter purchase adapter
↓
provider purchase result/token/reference
↓
authenticated backend
↓
provider verification
↓
map provider product to plan_code
↓
create/update entitlement
↓
return authoritative entitlement
```

Flutter must not activate premium merely because client-side purchase UI returned success.

Provider product mapping must be server-controlled or equivalently trusted.

---

# 79. RESTORE PURCHASE CONTRACT

Restore/reconciliation must be idempotent.

It must:

- verify provider state
- map to existing entitlement safely
- avoid duplicate entitlement creation
- avoid resetting usage incorrectly
- preserve historical periods
- return authoritative current state

"Restore" does not mean "grant premium because the user says they paid before."

---

# 80. RENEWAL CONTRACT

A verified renewal may create/advance a new billing period.

Requirements:

- new period dates come from verified provider state
- recurring allowance becomes available for the new period according to Subscription SOT
- unused prior-period allowance does not roll over
- old usage remains linked to old period
- duplicate renewal events are idempotent

Do not rewrite old period usage into the new period.

---

# 81. CANCELLATION CONTRACT

Cancellation means:

- provider indicates future renewal will not occur
- entitlement may remain active through current verified `period_end`
- current allowance remains governed by the valid period
- UI may show cancellation/non-renewal state if provider data supports it

Do not expire immediately unless provider state says entitlement ended.

---

# 82. REFUND / PROVIDER REVOCATION CONTRACT

Refund/revocation processing must:

- be based on verified provider/admin events
- be idempotent
- preserve historical transaction/usage evidence
- transition entitlement according to approved business rules
- avoid silently deleting user content

Do not let Flutter invent refund state.

---

# 83. ADMIN VS PROVIDER AUTHORITY

For public provider-backed plans:

```text
provider-verified state
+
server entitlement rules
=
public entitlement authority
```

For Salon Pilot:

```text
authorized admin grant
+
server entitlement rules
=
pilot entitlement authority
```

Web Admin must not forge Google Play state.

Google Play must not control Salon Pilot.

---

# 84. PROTECTED FACETUNE AI BOUNDARY

This Shared Contract must wrap around the existing approved AI architecture.

It must not modify:

- Final Preview Gemini model
- Final Preview prompt
- canonical Final Preview role
- Final Preview image validation
- existing recommendation architecture
- Standard Mode authority
- My Makeup Kit ownership authority
- Tutorial manifest architecture
- Tutorial guideline model
- Tutorial prompt versions
- Tutorial retry policy
- Tutorial resolution
- private storage rules

Correct integration:

```text
ENTITLEMENT / USAGE CHECK
↓
RESERVE
↓
EXISTING FINAL PREVIEW PIPELINE
↓
EXISTING SUCCESSFUL PERSISTENCE
↓
COMMIT
```

Do not redesign the AI pipeline to simplify billing.

---

# 85. NO AUTOMATIC MODEL FALLBACK

Subscription or Admin work must never introduce a model fallback.

If the approved Final Preview model is unavailable:

- follow the protected AI architecture's failure behavior
- do not silently switch models
- do not alter allowance semantics
- release usage only when the operation definitively ends without a usable persisted result

---

# 86. STANDARD MODE / MY MAKEUP KIT PARITY

AI Look accounting is identical for both recommendation modes.

```text
standard
successful new Final Preview
→ 1 AI Look

my_makeup_kit
successful new Final Preview
→ 1 AI Look
```

Do not give one mode free previews unless explicitly approved.

Do not let subscription work merge their business authorities.

---

# 87. FLUTTER RESPONSIBILITIES

Flutter may:

- request current entitlement
- display current plan
- display available AI Looks
- display reset/expiration state
- initiate approved purchase flow
- request Final Preview generation
- display quota exhausted state
- refresh entitlement after purchase/restore/admin change
- display Salon Pilot state when assigned

Flutter must not:

- grant entitlements
- decide admin privilege
- create committed usage
- release reservations authoritatively
- modify allowance
- calculate provider validity
- write provider verification state
- bypass quota
- expose service-role credentials

---

# 88. WEB ADMIN RESPONSIBILITIES

Web Admin may, only through protected server operations:

- search/resolve user identity
- read entitlement summary
- read sanitized usage summary
- read adjustment history
- read audit history
- grant Salon Pilot
- increase Salon Pilot allowance
- reduce Salon Pilot allowance safely
- extend Salon Pilot expiration
- suspend permitted entitlement
- reactivate when permitted
- revoke permitted entitlement

Web Admin must not:

- rewrite committed usage history
- change Gemini models
- change Gemini prompts
- disable RLS
- expose private face imagery
- directly edit provider purchase state
- forge public plan purchase
- leak service-role credentials

---

# 89. SHARED DOMAIN MODELING RULE

Use strongly typed domain concepts.

Avoid:

```text
Map<String, dynamic>
bool isPremium
String status with arbitrary values
int credits with unclear unit
```

Prefer explicit concepts equivalent to:

```text
PlanCode
EntitlementStatus
BillingProvider
UsageType
UsageStatus
AllowanceSummary
EntitlementSummary
AdminAction
SubscriptionErrorCode
```

Exact implementation follows current project conventions.

Do not create abstractions with no concrete engineering value.

---

# 90. SHARED REPOSITORY / API BOUNDARY

Subscription and Web Admin may use different clients/frontends, but they must converge on one authoritative server contract.

Conceptually:

```text
Mobile Subscription Repository
         │
         ▼
Shared Subscription Server API
         ▲
         │
Web Admin Repository / API Client
```

Do not duplicate business rules independently in both frontends.

---

# 91. LOGGING CONTRACT

Allowed sanitized logging may include:

- contract version
- plan code
- entitlement id
- entitlement status
- billing provider
- usage type
- usage status
- operation id
- request correlation id
- sanitized error code
- latency
- admin action
- allowance adjustment amount
- provider verification result category
- period transition

Do not log:

- API keys
- service-role key
- JWTs
- signed URLs
- image bytes
- base64 images
- full private prompts
- raw Gemini payloads
- full provider purchase tokens
- private facial metadata
- full My Makeup Kit contents
- unnecessary user-entered product names

Telemetry must measure system behavior, not become a shadow copy of private data.

---

# 92. COST TRACKING BOUNDARY

The Shared Contract may expose technical usage counts needed for internal cost measurement.

It must not:

- hardcode PHP 45 into runtime entitlement logic
- deduct more AI Looks because provider cost increased
- charge user for Tutorial technical calls
- silently downgrade AI model quality
- convert internal API attempts directly into user-facing usage

The PHP 45 value remains a planning/business assumption owned by the Subscription Source of Truth, not a runtime ledger rule.

---

# 93. ADMIN DASHBOARD METRIC BOUNDARY

Web Admin may eventually show aggregated subscription metrics such as:

```text
active plan counts
AI Looks committed
AI Looks released
AI Looks reserved
Salon Pilot allowance
Salon Pilot remaining
provider verification failure counts
```

These metrics must derive from authoritative data.

Do not use browser-side guessed totals as operational truth.

---

# 94. CONTRACT COMPATIBILITY RULE

Before implementing a Web Admin feature that depends on Subscription:

- inspect the actual implemented Subscription schema
- inspect the Shared Contract version
- inspect current server functions/API
- prove the required shared field/action exists

If Web Admin expects a field/action the Subscription implementation does not support:

> **STOP and report the incompatibility.**

Do not silently add an incompatible workaround inside Web Admin.

---

# 95. BACKWARD COMPATIBILITY

A later contract version must preserve historical meaning.

Example:

A historical:

```text
usage_type = final_makeup_preview
status = committed
```

must continue to mean one consumed AI Look under the historical contract.

Do not reinterpret old ledger data after adding future products.

Migrations must preserve historical truth.

---

# 96. SHARED ERROR PRESENTATION BOUNDARY

Server returns stable sanitized error codes.

Flutter and Web Admin may map those codes into context-appropriate messages.

They must not parse raw SQL/provider error strings to determine business behavior.

Example:

```text
AI_LOOK_LIMIT_REACHED
```

Mobile may show:

```text
You've used all your AI Looks for this period.
```

Admin may show:

```text
Available AI Looks: 0
```

Same underlying code, different presentation.

---

# 97. INPUT VALIDATION CONTRACT

Server-side privileged endpoints must validate:

- authenticated identity
- admin authorization where required
- target user existence
- target entitlement ownership
- canonical plan code
- allowed state transition
- allowance amount bounds
- expiration bounds
- idempotency key format
- request size
- reason length where required

Do not trust browser validation as security.

---

# 98. OUTPUT VALIDATION CONTRACT

Shared server responses must:

- use canonical plan/status/action identifiers
- use bounded numeric values
- never return negative available allowance
- never return impossible state combinations
- sanitize internal errors
- avoid unnecessary private data
- include enough identifiers for safe client reconciliation

---

# 99. STATE TRANSITION VALIDATION

Entitlement status changes must be explicit.

Conceptually acceptable examples may include:

```text
pending → active
active → grace_period
grace_period → active
active → expired
grace_period → expired
active → suspended
suspended → active
active → revoked
suspended → revoked
```

Exact allowed transition matrix must be finalized after provider/admin lifecycle inspection.

Do not permit arbitrary state assignment such as:

```text
UPDATE entitlement SET status = any_client_string
```

Admin requests an action.

Server decides the valid resulting status.

---

# 100. TIME AUTHORITY

Server/provider timestamps are authoritative for:

- billing period
- entitlement expiration
- reservation time
- commit time
- release time
- admin mutation time
- audit event time

Do not use client device time as entitlement authority.

Flutter and Web Admin may format timestamps for display.

---

# 101. NUMERIC INTEGRITY

AI Look values must use integer semantics.

Prohibited:

```text
3.5 AI Looks
-1 remaining
NaN
Infinity
```

Allowance adjustments must be integral.

Negative adjustments are represented as controlled decreases, not negative usage.

---

# 102. SINGLE SOURCE OF PLAN IDENTITY

One user entitlement must reference a canonical plan identity.

Do not model plan identity through multiple contradictory fields such as:

```text
isPremium = true
isSalon = false
planName = "Pro"
planCode = "plus"
```

If compatibility flags exist temporarily, `plan_code` remains authoritative and flags must be derived or removed safely.

---

# 103. USER OWNERSHIP CONTRACT

Every entitlement and usage record must resolve to an authenticated user identity.

A usage operation may not:

- attach to another user's entitlement
- commit against another user's canonical Final Preview
- be reassigned casually after creation

Server-side ownership validation is mandatory.

---

# 104. ADMIN TARGET RESOLUTION

Admin may search by email or user ID for usability.

The privileged mutation must ultimately target a stable server-resolved user identifier.

Do not use email string alone as permanent entitlement ownership.

If multiple identity sources create ambiguity:

- STOP
- resolve exact user identity
- do not guess

---

# 105. SALON PILOT ONE-ACCOUNT V1 RULE

Salon Pilot currently applies to one makeup artist FaceTune account.

Do not implement:

- multiple artist seats
- child accounts
- client subaccounts
- salon branches
- shared credentials architecture
- client-session billing

unless a future approved Source of Truth adds them.

The makeup artist may use their AI Look pool across real client consultations without FaceTune tracking client identity for billing.

---

# 106. PUBLIC PLAN MANUAL GRANT BOUNDARY

This Shared Contract does not authorize Web Admin to manually grant Plus, Pro, or Salon Pro as a normal V1 admin workflow unless the Web Admin Source of Truth and Subscription Source of Truth explicitly authorize it.

V1 admin-granted plan authority is specifically centered on:

```text
salon_pilot
```

Do not expand admin power merely because the database technically could.

---

# 107. STORE PRODUCT MAPPING SAFETY

A store product must map to exactly one approved plan code within the relevant active configuration.

If provider product mapping is unknown, duplicated, stale, or ambiguous:

> **STOP and fail safely.**

Do not infer plan from price.

Do not infer plan from product title.

---

# 108. PUBLIC PRICE DISPLAY SAFETY

When provider-localized price data is available for purchase UI:

- use provider-approved localized price
- do not perform manual currency conversion for purchase display
- do not assume PHP display outside the intended store context

Business baseline pricing remains documented separately.

---

# 109. SUBSCRIPTION PERIOD USAGE ISOLATION

Recurring usage must remain associated with the correct verified period.

A new period must not:

- delete old committed usage
- convert old usage into current usage
- roll unused usage forward
- reuse an old reservation incorrectly

Period transitions must be auditable.

---

# 110. SALON PILOT USAGE ISOLATION

Salon Pilot does not use recurring billing periods.

Its usage must remain associated with the active pilot entitlement/grant.

Allowance changes modify effective grant capacity.

They do not create fake monthly periods.

---

# 111. RESERVATION RECONCILIATION

A reservation that appears stale must be reconciled against:

- canonical Final Preview persistence
- current operation state
- any server/provider completion evidence
- idempotent operation result

Do not release solely because:

- Flutter closed
- network timed out
- route changed
- device went offline

Correctness beats aggressive cleanup.

---

# 112. ADMIN MUTATION CONFLICTS

If two admin mutations race:

- do not silently let last writer win when that could invalidate business history
- use transaction/concurrency control
- return a stable conflict error when necessary
- require refresh/retry with current state

Example:

```text
Admin A +10 allowance
Admin B -5 allowance
```

The final state must reflect a valid serialized/auditable sequence, not an accidental overwrite.

---

# 113. PROVIDER EVENT CONFLICTS

If provider state changes while an admin action occurs:

- provider-backed public subscription rules remain authoritative for provider lifecycle
- admin actions must not forge provider validity
- conflicts must be reconciled server-side
- ambiguous state must fail safely

Salon Pilot is not provider-backed and follows admin-grant rules.

---

# 114. DATA DELETION BOUNDARY

Subscription expiration, suspension, or revocation must not itself delete user content.

Account deletion, privacy deletion, and retention workflows are separate concerns.

Do not couple entitlement mutation to image deletion without an explicit privacy/deletion Source of Truth.

---

# 115. WEB ADMIN VISUAL DESIGN IS OUT OF CONTRACT

This Shared Contract does not define:

- page layout
- color palette
- typography
- responsive breakpoints
- dashboard card layout
- table styling
- iconography
- navigation design

Those belong to the Web Admin Source of Truth.

Shared fields/actions remain the same regardless of visual presentation.

---

# 116. EXPLICIT V1 NON-GOALS

Do not implement through this Shared Contract:

- annual plans
- AI Look add-on packs
- multi-seat Salon Pro
- salon teams
- salon branches
- salon CRM
- client identity tracking for billing
- client-session billing
- per-client preview limits
- family plans
- referrals
- affiliates
- promo codes
- gift subscriptions
- lifetime plans
- unlimited AI
- dynamic per-image billing
- usage-based invoicing
- wallet/coin economy
- external payment bypass of app-store rules
- manual public-plan entitlement forging
- arbitrary admin database console behavior
- Gemini prompt/model controls in Web Admin

Do not future-proof by building these early.

---

# 117. SHARED TEST REQUIREMENTS

Automated and integration tests should cover at minimum:

## Contract identity

- every canonical plan code is accepted
- unsupported plan code rejected
- Subscription and Web Admin use same plan identifiers
- contract version matches

## Entitlement status

- valid statuses accepted
- unsupported statuses rejected
- suspended blocks generation
- revoked blocks generation
- expired blocks generation
- active permits generation when capacity exists
- grace behavior follows verified provider state

## AI Look accounting

- reserve reduces available capacity
- successful persisted Final Preview commits exactly one
- released reservation restores capacity
- duplicate operation does not double reserve
- duplicate commit does not double charge
- duplicate release does not over-credit
- Tutorial consumes zero AI Looks
- reopening existing preview consumes zero AI Looks

## Allowance

- base + adjustments = effective allowance
- committed + reserved cannot exceed effective allowance
- negative available capacity impossible
- invalid reduction rejected
- Salon Pilot +10 changes remaining correctly
- committed history unchanged after adjustment

## Admin actions

- normal user cannot grant Salon Pilot
- normal user cannot adjust allowance
- grant is idempotent
- adjustment is idempotent
- suspend is auditable
- reactivate validates current state
- revoke is auditable
- extend expiration preserves history

## Security

- RLS remains enabled
- cross-user entitlement read denied
- cross-user usage read denied
- service-role key not in browser bundle
- admin authorization checked server-side
- provider secrets not returned to clients

## Concurrency

- one remaining AI Look + two concurrent generation requests results in at most one new reservation
- concurrent admin adjustments serialize safely
- duplicate provider event is idempotent
- client timeout does not automatically release still-running server work

## Compatibility

- mobile entitlement response matches shared contract
- Web Admin entitlement response matches shared contract
- error codes map consistently
- provider mapping resolves canonical plan code
- Salon Pilot does not appear as public store product

---

# 118. SHARED MANUAL QA REQUIREMENTS

Where relevant, manually validate:

- Free account entitlement summary
- Plus entitlement summary
- Pro entitlement summary
- Salon Pro entitlement summary
- Salon Pilot entitlement summary
- correct remaining display after successful Final Preview
- no deduction after failed Final Preview
- no deduction for Tutorial open/reopen
- Salon Pilot allowance increase visible after refresh
- Salon Pilot suspension blocks new generation
- Salon Pilot reactivation restores valid access
- Salon Pilot revocation blocks new generation
- existing History remains after entitlement loss
- normal user cannot enter privileged admin action flow
- Web Admin never displays private facial content on subscription screens

---

# 119. DEFINITION OF DONE FOR SHARED-CONTRACT IMPLEMENTATION

Any phase implementing concepts from this Shared Contract is complete only when:

- the active phase scope alone was implemented
- canonical plan codes match
- canonical status codes match
- canonical usage states match
- entitlement fields have stable semantics
- usage fields have stable semantics
- remaining allowance is server authoritative
- reserve / commit / release is idempotent
- concurrency protections exist where required
- RLS remains enabled
- admin privilege is server verified
- no service-role secret is exposed
- committed usage history remains auditable
- protected FaceTune AI behavior remains unchanged
- relevant tests pass
- errors introduced by the phase are fixed
- no unrelated system was rewritten
- completion evidence is reported
- no later phase was started

Compilation alone is not enough.

A completion report alone is not enough.

---

# 120. PHASE EXECUTION RULE

Every implementation phase that depends on this contract must follow:

```text
READ AUTHORITATIVE FILES
        ↓
VERIFY CURRENT BRANCH / GIT STATUS
        ↓
INSPECT ACTUAL CODE / SCHEMA / DEPLOYED STATE
        ↓
STATE THE PHASE OBJECTIVE
        ↓
IDENTIFY MINIMUM FILES
        ↓
IMPLEMENT ONLY AUTHORIZED SCOPE
        ↓
VALIDATE
        ↓
REPORT EVIDENCE
        ↓
STOP
```

Do not automatically continue to another phase.

Do not infer permission from the existence of later phase prompts.

---

# 121. REQUIRED COMPLETION EVIDENCE

When a phase modifies shared subscription/admin contracts or their implementation, the completion report must state at minimum:

```text
PHASE COMPLETED:

BRANCH VERIFIED:

OBJECTIVE ACHIEVED:

AUTHORITY FILES READ:

CONTRACT VERSION:

FILES CREATED:

FILES MODIFIED:

FILES DELETED:

DEPENDENCIES ADDED / REMOVED:

DATABASE / MIGRATION CHANGES:

RLS / AUTHORIZATION CHANGES:

EDGE FUNCTION / SERVER API CHANGES:

FLUTTER CHANGES:

WEB ADMIN CHANGES:

PLAN CODE CHANGES:

ENTITLEMENT STATUS CHANGES:

USAGE STATUS CHANGES:

ALLOWANCE SEMANTICS CHANGES:

IDEMPOTENCY / CONCURRENCY CHANGES:

AUDIT LOG CHANGES:

PROVIDER / STORE CHANGES:

PROTECTED AI CHANGES:
None expected unless separately authorized.

SECURITY CHECK:

PRIVACY CHECK:

TESTS / VALIDATION:

REAL DEVICE / LIVE BACKEND EVIDENCE:

KNOWN LIMITATIONS:

ASSUMPTIONS NOT PROVEN:

MANUAL ACTION REQUIRED:

NEXT RECOMMENDED PHASE:

STOP CONFIRMATION:
No later phase was implemented.
```

A vague completion report is not acceptable.

---

# 122. FINAL HARD-LOCKED SHARED RULES

The following rules are hard-locked for V1 unless the user explicitly approves a Source of Truth / contract revision:

1. Canonical plan codes are `free`, `plus`, `pro`, `salon_pilot`, `salon_pro`.
2. Salon Pilot is non-public and admin granted.
3. Salon Pilot starts from the business-approved initial allowance and may be adjusted through audited admin actions.
4. Salon Pro uses an AI Look pool, not client-session billing.
5. 1 AI Look means 1 successfully generated and persisted canonical Final Makeup Preview.
6. Tutorial does not consume another AI Look.
7. Failed Final Preview without usable persisted result does not commit usage.
8. Usage states are `reserved`, `committed`, `released`.
9. Active reservations reduce currently available capacity.
10. Remaining/available capacity is server authoritative.
11. Flutter cannot grant or mutate entitlements.
12. Web Admin browser cannot directly become entitlement authority.
13. Privileged admin writes occur through protected server operations.
14. Service-role credentials never ship to Flutter or Web Admin browser code.
15. RLS is never disabled for convenience.
16. Committed usage history is not casually rewritten.
17. Admin allowance changes are auditable adjustments.
18. Admin authorization is server-side.
19. Duplicate AI/admin/provider events are idempotent.
20. Concurrency must not create negative capacity or lost updates.
21. Public provider subscriptions require verified provider state.
22. Cancellation is not immediate expiration unless verified provider state says so.
23. Suspension/revocation do not delete historical user content.
24. Subscription/Admin work must not modify protected FaceTune AI models, prompts, Tutorial architecture, or My Makeup Kit authority.
25. No client identity tracking is required for Salon billing in V1.
26. No client-session billing or per-client preview limit exists in V1.
27. No automatic rollover exists in V1.
28. No annual plans, add-on packs, multi-seat salon, wallet, unlimited AI, or enterprise billing are implemented through this contract.
29. Shared identifiers and semantics must remain compatible across Subscription and Web Admin.
30. Every phase validates, reports, and STOPs before the next phase.

---

# 123. CONTRACT SUMMARY

This file is the technical treaty between FaceTune Subscription and FaceTune Web Admin.

The Subscription system owns the user's entitlement and usage reality.

The Web Admin may perform only explicitly authorized administrative actions.

This Shared Contract ensures both systems agree on:

```text
WHO
→ authenticated user / authorized admin

WHAT PLAN
→ canonical plan_code

WHAT STATE
→ canonical entitlement status

WHAT COUNTS
→ final_makeup_preview

HOW IT COUNTS
→ reserved / committed / released

HOW MUCH REMAINS
→ server-authoritative available_ai_looks

HOW PILOT CHANGES
→ audited allowance adjustments

WHO MAY CHANGE IT
→ server-verified admin

HOW HISTORY STAYS TRUE
→ immutable/auditable ledger + audit events

HOW DUPLICATES ARE PREVENTED
→ idempotency + concurrency protection

WHAT MUST NOT CHANGE
→ protected FaceTune AI architecture
```

No frontend may invent a competing interpretation.

No admin control may override subscription business authority.

No shared-contract implementation may quietly redesign FaceTune's protected AI systems.

---

# END OF FACETUNE SUBSCRIPTION / ADMIN SHARED CONTRACT
