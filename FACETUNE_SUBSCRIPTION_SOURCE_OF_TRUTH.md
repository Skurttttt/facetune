# FaceTune - SUBSCRIPTION SOURCE OF TRUTH

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
**Subscription Authority:** Supabase backend, verified provider state, entitlement state, and usage ledger  
**Primary Billable Unit:** AI Look  
**V1 Pricing Status:** APPROVED PRICING BASELINE  
**Planning Cost Assumption:** PHP 45 effective cost per successfully delivered AI Look, non-runtime business assumption only  

---

# 0. PURPOSE

This document is the highest business and engineering authority for the FaceTune subscription, entitlement, AI Look allowance, quota enforcement, billing lifecycle, and user-facing subscription state.

This document answers:

> **How does FaceTune subscription work?**

It governs:

- FaceTune Free
- FaceTune Plus
- FaceTune Pro
- Salon Pro
- Salon Pilot
- AI Look allowance
- AI Look consumption
- remaining allowance
- reserve / commit / release semantics
- technical failure behavior
- entitlement lifecycle
- monthly resets
- cancellation and expiration
- store purchase verification
- server-side subscription enforcement
- user-facing quota UX
- subscription security
- subscription persistence
- usage-ledger integrity
- cost-control boundaries
- subscription integration with the protected FaceTune AI pipeline

This document does **not** authorize implementation by itself.

Implementation must occur only through the approved `FACETUNE_SUBSCRIPTION_PHASE_PROMPTS.md`, one phase at a time.

This document does **not** define the full Web Admin UI or admin workflow. Those belong to:

```text
FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md
FACETUNE_WEB_ADMIN_SOURCE_OF_TRUTH.md
FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md
```

The Web Admin may operate only within subscription rules authorized by this document.

---

# 1. DOCUMENT AUTHORITY

Before ANY subscription implementation, the coding agent must read the relevant authority files in this order:

1. `CODEX_MASTER_GUIDE.md`
2. the current approved FaceTune V4 / AI architecture authority files
3. `FACETUNE_SUBSCRIPTION_SOURCE_OF_TRUTH.md`
4. `FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md`, once created
5. `FACETUNE_SUBSCRIPTION_PHASE_PROMPTS.md`
6. the latest completion report for the current subscription phase, when one exists
7. the actual source code, migrations, tests, deployed Supabase state, store configuration, and real-device evidence relevant to the phase

Authority rules:

1. Existing approved FaceTune AI/V4 authorities remain highest authority for AI behavior, model choice, canonical Final Preview behavior, Tutorial behavior, My Makeup Kit behavior, and protected AI architecture.
2. **This Subscription Source of Truth** is highest authority for subscription business rules, entitlements, AI Look allowances, quota consumption, and subscription lifecycle.
3. The Shared Contract may define exact shared names and fields but must not override the business meaning defined here.
4. The Web Admin Source of Truth may define administrative controls but must not invent new subscription behavior.
5. The current Subscription Phase Prompt authorizes only that phase.
6. Completion reports are evidence, not truth.
7. Actual code, migrations, test results, deployed state, store responses, and device behavior must be inspected rather than assumed.

If a subscription implementation conflicts with a protected FaceTune AI rule, the protected FaceTune AI rule wins and the subscription integration must be redesigned around it.

Do not silently rewrite AI architecture in order to make subscription easier.

---

# 2. MANDATORY SYSTEM ROLE

The coding agent must act as a production engineering team composed of:

- Principal Software Engineer
- Principal Software Architect
- Principal Backend Engineer
- Senior Backend Engineer
- Senior Backend Developer
- Senior Subscription / Billing Systems Architect
- Senior Entitlements Engineer
- Senior Payments Integration Engineer
- Senior Google Play Billing Engineer
- Senior App Store / In-App Purchase Engineer for future provider compatibility
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
- Senior API Integration Engineer
- Senior Domain Modeling Engineer
- Senior Distributed Systems / Idempotency Engineer
- Senior Async / Concurrency Engineer
- Senior Reliability Engineer
- Senior Application Security Engineer
- Senior Privacy Engineer
- Senior Observability Engineer
- Senior AI Systems Engineer
- Senior AI Cost Optimization / FinOps Engineer
- Senior QA Engineer
- Senior Regression Engineer
- Senior Integration Test Engineer
- Senior Mobile UI/UX Engineer
- Senior Production Debugging Engineer
- Senior Release Engineer
- Senior Code Reviewer

These rules apply equally to OpenAI Codex and Claude Code Pro.

The coding agent must not behave as a blind code generator.

It must:

- inspect first
- prove current behavior from code and deployed evidence
- challenge stale documentation
- preserve valid existing architecture
- prefer the smallest production-safe change
- distinguish business rules from implementation guesses
- distinguish store/provider facts from assumptions
- stop when required information cannot be safely inferred

---

# 3. ENGINEERING PRIORITIES

Every subscription decision must prioritize:

1. correctness
2. entitlement integrity
3. preventing duplicate or incorrect AI Look consumption
4. preserving existing working FaceTune behavior
5. server authority
6. security
7. privacy
8. billing/provider verification integrity
9. idempotency and concurrency safety
10. reliability
11. auditability
12. maintainability
13. testability
14. AI cost control
15. performance
16. user clarity
17. visual polish

Never trade entitlement correctness for a shorter implementation.

Never trade server authority for convenience in Flutter.

Never perform a broad rewrite when a smaller integration is sufficient.

---

# 4. GIT AND WORKING-TREE SAFETY

This Source of Truth does not hardcode a subscription implementation branch.

Before every implementation phase:

- verify the actual current branch
- run `git status`
- preserve valid uncommitted user work
- inspect branch ancestry when it matters
- do not assume `main`, an older feature branch, or a previously reported HEAD is still current
- if the current branch differs from the branch required by the active phase prompt, STOP and report instead of switching automatically

Do not automatically:

- switch branches
- merge branches
- cherry-pick commits
- rebase
- reset Git history
- delete branches
- clean the working tree
- stash valid user work
- drop stashes
- overwrite unrelated files
- commit
- push
- force push

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

---

# 5. CORE SUBSCRIPTION ARCHITECTURE

FaceTune subscription must use this authority model:

```text
USER
  ↓
FLUTTER APP
  ↓
STORE PURCHASE ADAPTER / ENTITLEMENT CLIENT
  ↓
GOOGLE PLAY OR APPROVED PROVIDER
  ↓
SERVER-SIDE PURCHASE VERIFICATION
  ↓
SUPABASE ENTITLEMENT AUTHORITY
  ↓
USAGE / AI LOOK AUTHORIZATION
  ↓
EXISTING FACETUNE FINAL PREVIEW PIPELINE
  ↓
SUCCESSFUL PERSISTENCE
  ↓
USAGE COMMIT
  ↓
FLUTTER DISPLAYS AUTHORITATIVE RESULT
```

For Salon Pilot:

```text
ADMIN-GRANTED SALON PILOT
  ↓
SUPABASE ENTITLEMENT AUTHORITY
  ↓
SAME USAGE / AI LOOK AUTHORIZATION
  ↓
SAME EXISTING FACETUNE FINAL PREVIEW PIPELINE
```

Salon Pilot is **not** a bypass.

It uses the same entitlement and usage engine as paid plans.

The difference is only how the entitlement is granted.

---

# 6. NON-NEGOTIABLE SERVER AUTHORITY

Flutter is never the source of truth for premium access, AI Look allowance, subscription status, or usage consumption.

Prohibited examples:

```dart
bool isPremium = true;
```

```dart
remainingLooks--;
```

when those values are treated as authoritative business state.

Flutter may cache or display server state for UX, but final authorization must occur server-side before expensive AI work begins.

The server must derive the authenticated user from the valid session/JWT.

The client must not be trusted to provide authoritative:

- `user_id`
- plan code
- entitlement status
- AI Look limit
- AI Look used count
- AI Look remaining count
- billing period
- expiration date
- store verification status
- provider purchase validity
- admin-grant status
- usage ledger state
- Final Preview ownership
- canonical image ownership
- model ID
- prompt version
- AI Look cost

---

# 7. V1 APPROVED PRICING BASELINE

The approved V1 business pricing baseline is:

| Plan | Price | AI Look Allowance | Reset |
|---|---:|---:|---|
| FaceTune Free | PHP 0 | 1 one-time AI Look | Never |
| FaceTune Plus | PHP 399/month | 3 AI Looks/month | Billing period |
| FaceTune Pro | PHP 899/month | 8 AI Looks/month | Billing period |
| Salon Pilot | Complimentary | Starts at 30, admin-editable | No automatic reset |
| Salon Pro | PHP 2,999/month | 35 AI Looks/month | Billing period |

These values are the **V1 APPROVED PRICING BASELINE**.

They are business configuration, not permission to scatter literal values throughout widgets, repositories, or Edge Functions.

Public store pricing must remain synchronized with the store product configuration.

When a store provides a localized purchase price, the purchase UI should use the verified/localized store product information rather than blindly trusting stale Flutter copy.

---

# 8. INTERNAL PLAN CODES

Use stable internal plan identities equivalent to:

```text
free
plus
pro
salon_pilot
salon_pro
```

Exact enum/type/database implementation is finalized by the Shared Contract after repository/schema inspection.

Do not infer plan identity from:

- price
- number of AI Looks
- nullable fields
- UI labels
- a loose boolean such as `isPremium`

Plan identity must be explicit.

---

# 9. UNIVERSAL AI LOOK DEFINITION

This rule is universal across every plan:

> **1 AI Look = 1 successfully generated and successfully persisted Final Makeup Preview that becomes a usable canonical Final Preview for the authenticated user.**

Conceptually:

```text
FINAL MAKEUP PREVIEW REQUEST
        ↓
SERVER AUTHORIZES ENTITLEMENT
        ↓
AI LOOK RESERVED
        ↓
EXISTING FINAL PREVIEW GENERATION
        ↓
SUCCESSFUL OUTPUT
        ↓
SUCCESSFUL PERSISTENCE
        ↓
USABLE CANONICAL FINAL PREVIEW EXISTS
        ↓
AI LOOK COMMITTED
```

The charging/consumption boundary is the usable persisted Final Makeup Preview.

Not the button tap.

Not the request start.

Not a partially completed provider call.

Not Tutorial access.

---

# 10. WHAT CONSUMES ONE AI LOOK

Exactly one AI Look is consumed when a genuinely new Final Makeup Preview:

1. is authorized by the server
2. is generated successfully
3. passes the existing Final Preview validity requirements
4. is persisted successfully under the correct user/lineage
5. becomes a usable canonical Final Preview
6. causes the reserved usage operation to be committed exactly once

Examples that consume one AI Look on success:

- first Final Makeup Preview
- another style preview
- another intensity preview
- another bridal variation
- `Try Another` when it creates a genuinely new successful Final Preview
- regeneration requested deliberately by the user when it creates a new successful Final Preview
- a new preview using the same selfie
- a new preview using a different selfie
- a new preview in Standard Mode
- a new preview in My Makeup Kit Mode

The user's reason for generating the new preview does not change the consumption rule.

---

# 11. WHAT DOES NOT CONSUME AN AI LOOK

The following do not consume another AI Look:

- account registration
- login
- Beauty Profile
- face analysis
- Makeup Style selection
- personalized Makeup Plan
- browsing Standard Mode recommendation data
- My Makeup Kit inventory management
- reopening an existing persisted Final Makeup Preview
- viewing History
- viewing Saved Looks
- sharing an existing look
- favoriting/removing favorite state
- opening the Step-by-Step Tutorial for an already consumed AI Look
- reopening that Tutorial later
- navigating between Tutorial steps
- viewing the existing canonical Final Preview from Tutorial
- a technical Final Preview failure that does not produce a usable persisted canonical Final Preview
- a duplicate request that is resolved through idempotency to an already-existing operation/result

Tutorial is included value attached to the AI Look and is not a second user-facing billing unit.

---

# 12. TUTORIAL BILLING RULE

The Tutorial is optional.

Universal user-facing rule:

```text
1 successful Final Makeup Preview
=
1 AI Look consumed

Tutorial for that look
=
included

Open Tutorial
=
0 additional AI Looks

Reopen Tutorial
=
0 additional AI Looks
```

This does **not** mean Tutorial AI work is free to FaceTune.

The backend should track Tutorial technical usage separately for cost analysis when existing architecture permits.

However, Tutorial AI operations must never deduct another AI Look from the user under this V1 subscription model.

Subscription work must not modify the approved Tutorial model, manifest behavior, generation lifecycle, prompt versions, retry behavior, or existing Tutorial cost controls unless separately authorized by the applicable AI Source of Truth.

---

# 13. FAILED FINAL PREVIEW RULE

Hard-lock this rule:

> **No usable persisted Final Makeup Preview = no committed AI Look consumption.**

Conceptually:

```text
RESERVE
  ↓
GENERATE
  ↓
PERSIST
  ↓
USABLE CANONICAL FINAL PREVIEW EXISTS?

YES
  ↓
COMMIT 1 AI LOOK

NO
  ↓
RELEASE RESERVATION
```

Examples that must not permanently consume an AI Look:

- provider request fails before usable output
- response is invalid and rejected by the existing Final Preview pipeline
- image persistence fails
- database persistence fails and no usable canonical result exists
- ownership validation fails
- request is rejected before generation because entitlement is invalid
- request is rejected because quota is exhausted
- duplicate request resolves to an existing operation without creating another successful Final Preview

FaceTune may still incur provider cost during some technical failures.

That is an internal business cost and must not be converted into a user charge when no usable persisted Final Makeup Preview exists.

---

# 14. IMPORTANT CLIENT-TIMEOUT RULE

A client timeout, app navigation, app close, or lost connection does **not** automatically prove that generation failed.

If server-side work later completes and a valid canonical Final Preview is persisted successfully, the AI Look may be committed because a usable result exists for the user to reopen.

Therefore:

- never release usage merely because Flutter timed out
- never start a duplicate paid request merely because Flutter lost the response
- check server-side operation status and persisted result state first
- reconnect/reopen flows must reuse completed persisted work

This prevents both double charging and double provider cost.

---

# 15. RESERVE / COMMIT / RELEASE

The server-side usage engine must support equivalent states:

```text
reserved
committed
released
```

Exact names are finalized in the Shared Contract.

## Reserve

Reserve one AI Look before beginning the expensive Final Preview operation.

A reservation temporarily reduces available generation capacity so concurrent requests cannot overspend the same remaining allowance.

## Commit

Commit exactly one AI Look only after a usable persisted canonical Final Preview exists.

## Release

Release the reservation when the operation definitively ends without a usable persisted canonical Final Preview.

Do not release an operation whose final server state is still unknown.

---

# 16. IDEMPOTENCY

Every expensive Final Preview request must have a stable server-recognized operation identity equivalent to:

```text
operation_id
```

Idempotency must protect against:

- double taps
- network retries
- Flutter retries
- app reconnects
- route rebuilds
- Riverpod rebuilds
- repeated callbacks
- provider callbacks/events delivered more than once
- duplicate server invocation
- concurrent requests for the same intended operation

A duplicate event must not:

- consume another AI Look
- create another reservation
- create another canonical Final Preview accidentally
- trigger duplicate paid AI work

Unique constraints, transactional checks, or equivalent backend protections are required where appropriate.

Client-side button disabling is useful UX but is not sufficient idempotency protection.

---

# 17. CONCURRENCY SAFETY

If a user has one AI Look remaining and two requests arrive concurrently, only one may receive valid capacity unless they represent already-authorized separate capacity.

The usage system must prevent:

```text
remaining = 1
request A sees 1
request B sees 1
both commit
remaining = -1
```

Negative remaining allowance is prohibited.

Quota check + reservation must be atomic or transactionally equivalent.

---

# 18. RESERVATION RECOVERY

Reservations must not remain permanently stuck because of crashes or interrupted server work.

The implementation must provide a safe reconciliation strategy.

Do not blindly expire a reservation based only on client elapsed time.

Before releasing a stale reservation, the backend must inspect whether:

- a canonical Final Preview was already persisted
- the operation is still in progress
- provider/server work may still complete
- an idempotent result already exists

Reconciliation must prefer entitlement correctness over aggressive cleanup.

---

# 19. EFFECTIVE REMAINING ALLOWANCE

For a fixed-limit entitlement, the server must be able to derive an effective allowance equivalent to:

```text
effective_limit
- committed_usage
- active_reservations_that_consume_capacity
=
available_capacity
```

For user-facing display after stable completion, the primary value is:

```text
effective_limit
- committed_usage
=
remaining_ai_looks
```

Do not let Flutter calculate an authoritative remaining balance from local counters.

---

# 20. FACE TUNE FREE

## Price

```text
PHP 0
```

## Allowance

```text
1 AI Look
one-time only
```

## Reset

None.

The Free AI Look never replenishes monthly.

## Intended purpose

The Free AI Look is a deliberate product acquisition / trial cost that allows the user to experience the complete FaceTune value proposition once.

## Maximum planning cost exposure

Using the current planning assumption:

```text
1 x PHP 45
=
PHP 45
```

This is a business planning estimate only.

Do not hardcode PHP 45 into runtime entitlement logic.

## Free includes

- Account
- Beauty Profile
- AI face analysis
- Makeup Style selection
- personalized Makeup Plan
- Standard Mode
- My Makeup Kit
- 1 Final Makeup Preview
- optional Step-by-Step Tutorial
- History
- Saved Looks
- ability to reopen existing results

## Exhausted Free state

```text
FaceTune Free

AI Looks
0 of 1 remaining

Upgrade to create more AI Looks
```

---

# 21. FACETUNE PLUS

## Price

```text
PHP 399 / month
```

## Allowance

```text
3 AI Looks / verified billing period
```

## Intended user

Casual personal users who want occasional personalized makeup previews.

## Planning AI cost at full allowance

```text
3 x PHP 45
=
PHP 135
```

## Gross price per included AI Look

```text
PHP 399 / 3
=
PHP 133
```

## Reset

The allowance resets at the start of the next verified billing period.

No rollover.

Unused AI Looks expire with the completed allowance period.

## Example user display

```text
FaceTune Plus

AI Looks
2 of 3 remaining

Resets Oct 7, 2026
```

---

# 22. FACETUNE PRO

## Price

```text
PHP 899 / month
```

## Allowance

```text
8 AI Looks / verified billing period
```

## Intended user

- frequent personal users
- beauty enthusiasts
- creators
- users who experiment with multiple styles
- heavier My Makeup Kit users

## Planning AI cost at full allowance

```text
8 x PHP 45
=
PHP 360
```

## Gross price per included AI Look

```text
PHP 899 / 8
≈
PHP 112.38
```

## Reset

8 new AI Looks per verified billing period.

No rollover.

## Example user display

```text
FaceTune Pro

AI Looks
5 of 8 remaining

Resets Oct 7, 2026
```

---

# 23. SALON PRO

## Price

```text
PHP 2,999 / month
```

## Allowance

```text
35 AI Looks / verified billing period
```

## Account structure

```text
1 authenticated Makeup Artist account
```

This means one entitlement owner.

V1 does not implement multiple makeup artist seats, team roles, branches, or salon CRM.

This SOT does not introduce special device-count enforcement solely for Salon Pro.

## Intended user

Professional makeup artists using FaceTune during real client consultations.

## No client-session billing

Salon Pro does **not** use:

```text
1 client = 3 looks
```

or:

```text
30 client sessions
```

The makeup artist receives one simple pool:

```text
35 AI Looks / month
```

Examples:

```text
Bridal Client A
5 successful Final Makeup Previews
=
5 AI Looks consumed
```

```text
Client B
1 successful Final Makeup Preview
=
1 AI Look consumed
```

FaceTune does not need to identify whether two previews belong to the same physical client.

## Planning AI cost at full allowance

```text
35 x PHP 45
=
PHP 1,575
```

## Gross price per included AI Look

```text
PHP 2,999 / 35
≈
PHP 85.69
```

## Reset

35 new AI Looks per verified billing period.

No rollover.

## Example user display

```text
Salon Pro

AI Looks
28 of 35 remaining

Resets Oct 7, 2026
```

---

# 24. SALON PILOT

Salon Pilot is a non-public research entitlement.

It is not a normal store subscription.

## Price

```text
Complimentary
```

## Starting allowance

```text
30 AI Looks
```

## Critical rule

The starting 30 is admin-editable.

Example:

```text
Initial allowance: 30
Panel requests more testing
Admin adjustment: +10
Effective allowance: 40
```

## Characteristics

```text
Publicly purchasable: No
Billing provider: admin-granted equivalent
Auto-renew: No
Starting AI Looks: 30
Allowance admin-editable: Yes
Expiration: Admin-controlled
Makeup Artist account: 1
Automatic reset: No
```

## Research purpose

Salon Pilot exists to:

- test the professional workflow
- support the panel/research study
- observe actual preview consumption
- observe Tutorial use
- observe provider failures
- estimate actual cost per successfully delivered AI Look
- validate whether PHP 45 is a reasonable effective cost assumption
- validate whether the commercial Salon Pro allowance/pricing is sustainable

## Planning cost exposure

At 30:

```text
30 x PHP 45
=
PHP 1,350 planning exposure
```

If admin grants 10 additional AI Looks:

```text
10 x PHP 45
=
PHP 450 additional planning exposure
```

These are planning numbers, not runtime billing logic.

---

# 25. SALON PILOT ADJUSTMENT SEMANTICS

Web Admin may later be authorized to adjust Salon Pilot allowance.

The Subscription Source of Truth authorizes the business concept.

The Web Admin Source of Truth will define the UI and authorization flow.

Adjustments must be auditable.

Preferred semantics:

```text
Base grant: 30
Adjustment: +10
Effective allowance: 40
Committed usage: 18
Remaining: 22
```

Do not rewrite committed historical usage from 18 to another number merely to increase remaining balance.

If allowance must be reduced, the effective limit must not normally be reduced below already committed usage.

If access must be stopped, use suspension/revocation rather than corrupting usage history.

Every privileged adjustment must preserve:

- target entitlement
- adjustment amount or new authorized limit
- reason
- admin identity
- timestamp
- before/after value

Exact shared fields belong to the Shared Contract.

---

# 26. VALUE LADDER

The V1 paid plans intentionally provide better gross per-look value at higher commitment:

```text
PLUS
PHP 399 / 3
≈ PHP 133 per included AI Look
```

```text
PRO
PHP 899 / 8
≈ PHP 112.38 per included AI Look
```

```text
SALON PRO
PHP 2,999 / 35
≈ PHP 85.69 per included AI Look
```

Conceptually:

```text
Plus
~PHP 133/look
      ↓
Pro
~PHP 112/look
      ↓
Salon Pro
~PHP 86/look
```

This is commercial rationale only.

It must not become client-side entitlement math.

---

# 27. PHP 45 EFFECTIVE COST ASSUMPTION

For pricing analysis only:

```text
Estimated effective cost per successfully delivered AI Look = PHP 45
```

This is a planning assumption, not a permanent provider price.

It should eventually reflect the real average cost of delivering one usable AI Look, including the broader pipeline where appropriate.

It must be validated using real Salon Pilot data.

Do not:

- hardcode PHP 45 into quota authorization
- deny generation because a local PHP cost estimate changed
- expose internal cost estimates to the customer as entitlement state
- assume provider prices or FX rates never change

Track technical usage so real effective cost can be measured rather than guessed.

---

# 28. SALON PILOT COST VALIDATION

Salon Pilot should produce enough sanitized technical evidence to calculate:

```text
TOTAL RELEVANT AI / PROVIDER COST
/
SUCCESSFULLY DELIVERED AI LOOKS
=
EFFECTIVE COST PER DELIVERED AI LOOK
```

Useful non-private metrics may include:

- successful Final Makeup Previews
- failed Final Preview operations
- released reservations
- committed AI Looks
- Tutorial generations
- Tutorial opens where product analytics already supports them
- model/operation counts
- sanitized provider usage units
- estimated provider cost using a separately maintained cost model
- average AI Looks used per research participant when participant linkage exists outside this subscription SOT

Do not log private image data to perform cost analysis.

---

# 29. MONTHLY RESET RULE

For Plus, Pro, and Salon Pro:

- allowance is period-scoped
- the period comes from verified subscription/provider state
- unused allowance does not roll over
- a new verified billing period receives the plan's configured allowance
- usage from the prior billing period remains historical and auditable

Do not implement monthly reset as a fragile local-device calendar calculation.

Do not use the user's phone clock as billing authority.

Do not simply set a mutable `used = 0` without preserving period history.

Preferred model:

```text
PERIOD A
limit = 8
committed = 6
remaining = 2

PERIOD B
limit = 8
committed = 0
remaining = 8
```

Period A remains in history.

---

# 30. FREE AND SALON PILOT RESET RULE

## Free

The complimentary Free AI Look never automatically resets.

## Salon Pilot

Salon Pilot does not automatically reset monthly.

It remains available until:

- allowance is consumed
- entitlement expires
- admin suspends it
- admin revokes it
- admin adjusts it under authorized rules

---

# 31. NO ROLLOVER

For Plus, Pro, and Salon Pro:

```text
unused current-period AI Looks
DO NOT
add to the next period
```

Example:

```text
Plus limit = 3
used = 1
remaining = 2

next billing period
=
3 available

not 5
```

No rollover logic is included in V1.

---

# 32. ENTITLEMENT LIFECYCLE SEMANTICS

The system must represent explicit entitlement lifecycle state rather than ambiguous booleans.

Conceptual states may include:

```text
pending
active
grace_period
expired
suspended
revoked
```

Exact names are finalized in the Shared Contract.

Semantics:

## pending

Provider/admin state is not yet sufficient to authorize premium generation.

## active

Generation is allowed subject to remaining allowance and all normal server validation.

## grace period

Generation is allowed only when the verified billing provider explicitly considers the subscription entitled during the applicable grace state.

Do not invent a grace period locally.

## expired

No new premium AI Look generation.

Existing historical content remains accessible under normal retention rules.

## suspended

Administrative temporary block on new premium generation.

Historical data is not deleted solely because of suspension.

## revoked

The entitlement is no longer valid for new premium generation.

Historical data remains according to normal retention/deletion rules.

---

# 33. CANCELLATION RULE

Cancellation does not automatically mean immediate loss of already-paid entitlement.

If the verified provider states that the current billing period remains valid until `period_end`, FaceTune keeps the entitlement active until that verified end.

Conceptually:

```text
Auto-renew disabled
+
Current period still valid
=
Premium remains active until verified period end
```

At expiration:

- new premium Final Preview generation is blocked
- existing History remains accessible
- existing Saved Looks remain accessible
- existing canonical Final Previews remain accessible
- existing Tutorials remain accessible under normal data-retention rules

Do not hold historical looks hostage after cancellation.

---

# 34. RESTORE PURCHASES

V1 public subscription architecture must support a restore/reconciliation path appropriate to the active store/provider.

Restore must:

- query/reconcile legitimate provider purchases through approved mechanisms
- verify server-side
- recreate or repair entitlement state from verified provider evidence
- not grant premium because Flutter merely claims a purchase exists
- remain idempotent

Do not duplicate entitlements when restore is repeated.

---

# 35. REFUNDS / REVOKED PURCHASES / PROVIDER EVENTS

Provider lifecycle events must be processed server-side and idempotently.

The system must be able to reconcile events equivalent to:

- purchase verified
- renewal
- cancellation / auto-renew disabled
- expiration
- grace status
- refund
- revocation
- restore/recovery

Exact Google Play event names and API versions must be verified from current provider documentation at implementation time.

Do not hardcode stale provider assumptions from an old tutorial or blog post.

---

# 36. GOOGLE PLAY AND APP STORE RELATIONSHIP

Primary V1 platform is Android.

Public Android subscriptions should use Google Play Billing through a verified production-safe Flutter/provider integration selected after repository and current-policy inspection.

Architecture requirements:

```text
Flutter purchase flow
  ↓
Google Play
  ↓
purchase token / provider evidence
  ↓
FaceTune server verification
  ↓
internal plan mapping
  ↓
entitlement state
```

Flutter purchase success alone does not authorize premium AI generation.

The backend remains the entitlement authority.

For future iOS/App Store support:

- reuse the same internal plan/entitlement model where possible
- verify Apple purchase state server-side
- do not contaminate domain logic with Android-only assumptions

V1 does not require iOS implementation unless explicitly activated by a later phase.

---

# 37. STORE PRODUCT MAPPING

Public store product IDs must map to stable internal plan codes.

Conceptually:

```text
provider product id
  ↓
server-owned mapping
  ↓
plus / pro / salon_pro
```

Do not authorize a plan based on price text.

Do not trust a plan code sent by Flutter without server mapping and provider verification.

Store product identifiers may be present in client purchase configuration as required by the billing SDK, but the backend must still verify and map the purchased product.

---

# 38. PLAN CHANGES

Do not invent custom proration rules in Flutter.

Upgrade/downgrade behavior must follow verified provider lifecycle state and the business rules approved in the active subscription phase.

V1 must not silently maintain two conflicting paid entitlements for the same user.

Until plan-change semantics are fully implemented and tested, do not expose unsupported upgrade/downgrade paths merely because the pricing UI contains multiple cards.

Annual-plan conversion is out of scope for V1.

---

# 39. USER-FACING SUBSCRIPTION STATE

Every user must be able to understand:

- current effective plan
- AI Look limit
- AI Looks used or remaining
- reset date for recurring paid plans
- expiration date for Salon Pilot
- exhausted state

Use the user-facing unit:

> **AI Looks**

Do not use vague credits as the primary V1 language.

Do not show internal operation IDs, reservation states, provider tokens, API cost, or backend jargon to normal users.

---

# 40. PROFILE SUBSCRIPTION CARD

Examples:

## Free

```text
FaceTune Free

AI Looks
0 of 1 remaining

Upgrade to create more AI Looks
```

## Plus

```text
FaceTune Plus

AI Looks
2 of 3 remaining

Resets Oct 7, 2026
```

## Pro

```text
FaceTune Pro

AI Looks
6 of 8 remaining

Resets Oct 7, 2026
```

## Salon Pro

```text
Salon Pro

AI Looks
28 of 35 remaining

Resets Oct 7, 2026
```

## Salon Pilot

```text
Salon Pilot
Research Access

19 of 30 AI Looks remaining

Expires Nov 7, 2026
```

Dates shown above are examples only.

Runtime values must come from authoritative entitlement state.

---

# 41. BEFORE FINAL PREVIEW CTA

Before an expensive Final Makeup Preview request, show a compact non-blocking allowance indicator when appropriate.

Examples:

```text
2 AI Looks remaining this month
```

Salon Pilot:

```text
18 AI Looks remaining in your pilot
```

The display is informational.

The server still performs final authorization at request time.

---

# 42. AFTER SUCCESSFUL FINAL PREVIEW

After a successful committed AI Look, FaceTune may show a subtle confirmation such as:

```text
AI Look created

1 AI Look remaining
```

The displayed remaining value must come from authoritative post-commit state, not `localRemaining - 1` guesswork.

---

# 43. LOW-ALLOWANCE STATE

When exactly one AI Look remains:

```text
1 AI Look remaining
```

The UX may make this slightly more noticeable.

Do not block the final available AI Look.

---

# 44. EXHAUSTED STATE

## Plus / Pro / Salon Pro

When no AI Looks remain:

```text
You've used all your AI Looks.

Your allowance resets on <verified reset date>.
```

Upgrade CTA may be shown only when a valid supported upgrade path exists.

V1 does not require AI Look add-on packs.

## Free

```text
You've used your complimentary AI Look.

Upgrade to create more AI Looks.
```

## Salon Pilot

```text
Salon Pilot allowance used

0 of 30 AI Looks remaining
```

Do not show a normal consumer purchase prompt for Salon Pilot solely because the pilot reaches zero.

The admin may adjust the research allowance through the later Web Admin system.

---

# 45. PAYWALL PLACEMENT

The main commercial gate should occur at the expensive Final Makeup Preview generation boundary, not unnecessarily before users experience FaceTune's analysis/recommendation value.

A user may generally experience the non-billable upstream flow before Final Preview generation, subject to existing product rules.

Subscription implementation must not charge AI Looks for Beauty Profile, analysis, style selection, or Makeup Plan merely to force earlier monetization.

---

# 46. EXISTING HISTORY AFTER EXPIRATION

Subscription state controls permission for **new premium AI generation**.

It does not automatically delete historical user content.

After cancellation, expiration, suspension, or Salon Pilot expiration, existing valid user-owned:

- History
- Saved Looks
- canonical Final Previews
- Tutorials

remain accessible according to existing FaceTune data-retention and ownership rules.

Do not implement subscription cancellation as content deletion.

---

# 47. CONCEPTUAL PERSISTENCE MODEL

Inspect the existing Supabase schema before creating anything.

Do not duplicate existing concepts merely because this document uses conceptual names.

Conceptually, the subscription system needs equivalents for:

```text
subscription_plan_config
user_entitlements
entitlement_periods or equivalent period state
usage_ledger
provider_purchase / provider_event evidence
salon_pilot_adjustments or generic entitlement adjustments
```

Exact table names are not locked until schema audit.

Reuse or extend valid existing tables where appropriate.

---

# 48. PLAN CONFIGURATION

Public plan configuration must support equivalent fields such as:

```text
plan_code
display_name
publicly_purchasable
billing_provider
provider_product_id
billing_interval
ai_look_limit
active
```

Business baseline:

```text
free        -> 1 one-time
plus        -> 3 per month
pro         -> 8 per month
salon_pro   -> 35 per month
salon_pilot -> entitlement-specific starting grant, default 30
```

Salon Pilot allowance is entitlement-specific and admin-adjustable.

Do not model Salon Pilot as a public store SKU.

---

# 49. ENTITLEMENT PERSISTENCE

An entitlement requires enough authoritative state to determine:

- owner
- plan identity
- status
- origin/provider
- provider product when applicable
- current verified period
- expiration
- renewal state when available
- effective allowance
- whether the entitlement is publicly purchased or admin granted
- when it was verified

Conceptual fields may include:

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

Do not treat these exact names as permission to duplicate an existing valid schema.

---

# 50. USAGE LEDGER

AI Look consumption must be ledger-backed or equivalently auditable.

Conceptually track:

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

Usage type for this V1 business unit is equivalent to:

```text
final_makeup_preview
```

The ledger must support proving:

- why allowance changed
- whether a generation was reserved
- whether it committed
- whether it released
- which canonical Final Preview resulted from the committed usage

Do not rely on one mutable integer without an auditable usage trail.

---

# 51. LEDGER INTEGRITY

Committed usage history must not be casually rewritten.

If an administrative business correction is required, use an auditable adjustment rather than falsifying historical usage.

A committed AI Look should link to the resulting canonical Final Preview or equivalent stable lineage when architecture permits.

A released reservation must not count as committed usage.

A duplicate operation must not create duplicate committed ledger entries.

---

# 52. ROW LEVEL SECURITY

Subscription and usage data is private account data.

RLS / authorization must ensure:

- user A cannot read user B's entitlement details
- user A cannot read user B's usage ledger
- user A cannot alter their own entitlement directly from Flutter
- user A cannot insert fake committed usage or fake remaining balance
- user A cannot grant themselves Salon Pilot
- user A cannot modify their plan code
- user A cannot alter verified provider state
- user A cannot attach another user's canonical preview to a usage operation
- normal users cannot perform admin adjustments

Never solve access problems by disabling RLS.

Backend authorization must still validate ownership even when RLS exists.

Defense in depth is required.

---

# 53. PURCHASE / PROVIDER SECRET SAFETY

Do not expose or log:

- service-role credentials
- provider private credentials
- JWTs
- raw purchase tokens when not operationally necessary
- full provider request/response bodies containing sensitive purchase data
- secrets in Flutter assets
- secrets in Android resources
- secrets in client configuration
- secrets in error messages

Provider verification credentials remain server-side.

Store purchase tokens or transaction identifiers only to the minimum degree needed for secure idempotent verification and reconciliation.

---

# 54. ADMIN-GRANTED SALON PILOT SECURITY

Salon Pilot must never be granted by:

- hardcoded email checks in Flutter
- client flags
- hidden UI switches
- local debug preferences in production
- user-editable profile fields
- disabling RLS

Correct concept:

```text
Authenticated admin
  ↓
Protected server operation
  ↓
Admin authorization check
  ↓
Salon Pilot entitlement grant/adjustment
  ↓
Audit record
```

The detailed Web Admin implementation belongs to the Web Admin Source of Truth.

---

# 55. PROTECTED FACETUNE AI BOUNDARY

Subscription is a wrapper around the existing working Final Preview architecture.

Conceptually:

```text
ENTITLEMENT CHECK
  ↓
USAGE RESERVATION
  ↓
EXISTING FACETUNE FINAL PREVIEW FLOW
  ↓
EXISTING PERSISTENCE
  ↓
COMMIT OR RELEASE
```

Subscription implementation must not use quota work as an excuse to rewrite:

- canonical Final Preview behavior
- Final Preview Gemini model
- Final Preview prompt
- My Makeup Kit authority
- recommendation authority
- Tutorial manifest
- Tutorial guideline model
- Tutorial prompt
- Tutorial resolution
- Tutorial category rules
- AI retry policy
- image ownership model
- existing historical lineage

Any required integration change must be the smallest safe boundary change.

---

# 56. LOCKED AI MODEL SAFETY

The subscription system does not select Gemini models.

Model selection remains owned by the existing protected AI configuration.

Subscription must not:

- downgrade a model when quota is low
- switch to a cheaper model for Free users without explicit product approval
- switch model by plan
- allow Flutter to select a model
- create a silent fallback chain
- change Tutorial resolution
- modify AI prompts to reduce cost

Cost optimization must be a separate explicitly approved effort.

---

# 57. STANDARD MODE AND MY MAKEUP KIT

AI Look consumption is the same for both recommendation modes.

```text
Standard Mode successful Final Preview
=
1 AI Look
```

```text
My Makeup Kit successful Final Preview
=
1 AI Look
```

The subscription system must not merge or weaken their different recommendation/business authorities.

My Makeup Kit ownership validation remains server-side.

Standard Mode remains brand-neutral under its existing authority.

---

# 58. FLUTTER RESPONSIBILITIES

Flutter owns presentation and purchase UX such as:

- displaying plan options
- initiating provider purchase flow through approved SDK abstractions
- displaying current authoritative entitlement state
- displaying AI Looks remaining
- displaying reset/expiration dates
- displaying exhausted state
- displaying upgrade CTA when supported
- displaying Salon Pilot research access
- handling loading/error states
- refreshing entitlement state after verified purchase/admin change

Flutter does **not** own:

- purchase verification truth
- entitlement authorization
- quota authorization
- usage commit
- usage release
- AI Look accounting
- provider-event reconciliation
- admin grant authority

Keep business logic out of widgets.

---

# 59. RIVERPOD / ASYNC RULES

Subscription state should have explicit loading/success/error/refresh states consistent with the existing app architecture.

Do not trigger:

- purchase verification
- entitlement mutation
- AI generation
- usage reservation

from widget `build()`.

Rebuilds must not create paid work or duplicate provider requests.

Async lifecycle must be deliberate and idempotent.

---

# 60. ERROR CONTRACT

Subscription/backend errors must be typed or equivalently stable enough for Flutter to distinguish at least:

- authentication required
- entitlement missing
- entitlement pending
- entitlement expired
- entitlement suspended
- entitlement revoked
- quota exhausted
- provider verification failure
- duplicate operation resolved
- generation failure with released usage
- temporary backend failure

Do not expose raw SQL, provider internals, secrets, stack traces, or private token data to the user.

---

# 61. OBSERVABILITY

Allowed sanitized subscription telemetry may include:

- plan code
- entitlement status
- usage operation type
- usage status
- committed AI Look count
- released reservation count
- reservation latency
- Final Preview success/failure category
- provider type
- purchase verification success/failure category
- period transition
- Salon Pilot adjustment amount without private user content
- model/operation cost metadata already permitted by AI observability rules

Do not log:

- image bytes
- base64 images
- signed URLs
- API keys
- JWTs
- private purchase credentials
- full provider receipts/tokens unless a secure operational store requires them
- private prompts
- raw user facial data
- full My Makeup Kit contents merely for subscription analytics

Telemetry measures system behavior, not private user identity/content.

---

# 62. COST CONTROL

The subscription engine must provide a hard allowance boundary without degrading AI quality.

Cost controls include:

- fixed AI Look allowances
- server-side quota enforcement
- reserve / commit / release
- idempotency
- no duplicate paid AI work
- no rollover
- no unlimited plan in V1
- Salon Pilot admin-controlled allowance
- provider usage telemetry
- no silent model downgrade

Do not base sustainability on the assumption that users will fail to consume their allowance.

Plans should remain defensible under full allowance utilization.

---

# 63. PUBLIC PLAN CONFIGURATION CHANGES

Public plan limits/prices may change in a future approved business revision.

When they change:

- update store/provider configuration where required
- update server plan configuration
- version/migrate entitlement behavior safely
- preserve historical period data
- do not silently rewrite old ledger history
- do not scatter new constants through Flutter

A pricing change is a product/business change, not merely a UI text edit.

---

# 64. SALON PILOT CONFIGURATION CHANGES

Salon Pilot differs from public plans.

Its effective allowance may be adjusted per entitlement through audited admin actions.

Example:

```text
starts at 30
admin adds 10
new effective allowance 40
```

No mobile app release should be required solely to add approved Salon Pilot allowance.

---

# 65. OUT OF SCOPE FOR SUBSCRIPTION V1

Do not implement unless a later approved Source of Truth explicitly adds them:

- annual subscriptions
- AI Look add-on packs
- multi-seat Salon Pro
- salon employee accounts
- salon branches
- salon CRM
- client identity tracking for billing
- client-session billing
- 3-previews-per-client rules
- family plans
- referrals
- affiliate billing
- promo codes
- gift subscriptions
- lifetime plans
- unlimited AI
- usage-based invoicing
- dynamic per-image charging
- enterprise billing
- external Stripe checkout for in-app digital functionality
- custom payment gateway bypass of app-store rules
- wallet/coin economy
- rollover

Do not future-proof by prematurely building these systems.

---

# 66. WEB ADMIN BOUNDARY

This Subscription Source of Truth authorizes the following Salon Pilot business capabilities for the later Web Admin:

- search/resolve a user securely
- grant Salon Pilot
- set initial pilot allowance
- add approved AI Look allowance
- reduce allowance safely within business rules
- extend expiration
- suspend
- reactivate when permitted
- revoke
- view entitlement state
- view usage summary
- view auditable adjustments

The exact Admin UI, roles, endpoints, audit screens, and authorization flows belong to `FACETUNE_WEB_ADMIN_SOURCE_OF_TRUTH.md`.

The Web Admin may not override this document.

---

# 67. ADMIN MAY NOT REWRITE USAGE HISTORY

The later Web Admin must not provide casual direct editing of committed usage.

Bad:

```text
used = 18
admin changes used = 3
```

Correct concept:

```text
base limit = 30
committed = 18
admin adjustment = +10
effective limit = 40
remaining = 22
```

Historical truth must remain auditable.

---

# 68. TESTING STRATEGY

Use mocks/fakes for provider purchase verification and Gemini where practical.

Do not make every unit test perform real store purchases or live Gemini calls.

Test at minimum:

## Plan behavior

- Free has 1 one-time AI Look
- Free never auto-resets
- Plus has 3 per verified period
- Pro has 8 per verified period
- Salon Pro has 35 per verified period
- Salon Pilot starts at 30
- Salon Pilot has no automatic reset
- Salon Pilot allowance adjustment changes effective remaining correctly
- no rollover

## AI Look accounting

- successful persisted Final Preview commits exactly one AI Look
- failed generation releases reservation
- persistence failure releases when no usable result exists
- duplicate request does not double-charge
- repeated callback does not double-charge
- user-generated new preview consumes another look
- reopening existing preview consumes zero
- Tutorial open consumes zero
- Tutorial reopen consumes zero
- History open consumes zero
- Saved Looks open consumes zero

## Concurrency

- one remaining AI Look + two concurrent requests cannot commit two looks
- duplicate operation IDs are idempotent
- stale reservations reconcile safely
- client timeout does not automatically release server-completing work

## Lifecycle

- active entitlement allows generation when quota remains
- expired entitlement blocks new generation
- suspended entitlement blocks new generation
- revoked entitlement blocks new generation
- provider-verified grace behavior is honored
- canceled but still-valid period remains active until verified end
- renewal creates correct new period allowance
- restore is idempotent

## Security

- user cannot grant own Salon Pilot
- user cannot edit own entitlement
- user cannot edit own ledger
- user cannot read another user's entitlement
- user cannot read another user's usage
- user cannot attach another user's preview to usage
- RLS remains enabled
- server ownership checks remain present

## Protected AI regression

- Standard Mode still works
- My Makeup Kit still works
- Final Preview model unchanged
- Final Preview prompt unchanged unless explicitly authorized
- Tutorial open still works
- Tutorial does not consume AI Look
- no Gemini call moves into Flutter
- no new rebuild-triggered AI call

## UI

- Profile displays correct plan
- Profile displays authoritative remaining
- reset/expiration date displays correctly
- low allowance state
- zero allowance state
- Salon Pilot display
- purchase refresh state
- offline/error state

---

# 69. SALON PILOT RESEARCH ACCEPTANCE

Salon Pilot must allow the project to observe, without changing the public commercial plans:

- actual AI Looks consumed
- average previews per participant when study data provides that linkage
- Final Preview failure rate
- Tutorial use rate when analytics is intentionally available
- effective provider cost per successfully delivered AI Look
- whether 30 initial AI Looks is sufficient for the panel/research phase

The panel may request a higher allowance.

The admin may increase the pilot allowance without changing the public Salon Pro plan.

---

# 70. REAL-DEVICE VALIDATION

Primary physical validation target remains POCO X3 GT unless the project authority changes it.

Subscription UI and generation-gating behavior must be tested on a real device when the relevant phase reaches device validation.

Performance-sensitive validation should use profile/release-like execution when debug overhead would distort results.

Do not treat debug-only jank as proof of production performance failure without profile/release evidence.

---

# 71. REMOTE DEPLOYMENT RULE

Do not deploy unrelated dirty work.

Before any remote migration, Edge Function, or billing-related deployment:

- inspect Git status
- inspect exact files being deployed
- confirm they belong to the current phase
- verify the correct Supabase project/environment
- verify provider sandbox/production environment
- avoid unrelated CLI/toolchain upgrades
- verify secrets are configured server-side
- verify RLS remains enabled

Remote deployment is not a substitute for understanding local changes.

---

# 72. DEFINITION OF DONE FOR A SUBSCRIPTION PHASE

A subscription phase is complete only when:

- only the authorized phase scope was implemented
- existing FaceTune behavior remains working
- protected AI architecture remains intact
- entitlement rules match this SOT
- architecture remains modular
- relevant files are formatted
- static analysis is checked
- relevant tests are run
- migration/RLS behavior is validated when applicable
- errors introduced by the phase are fixed
- no secret is exposed
- no unrelated code is rewritten
- no next phase is started
- completion evidence is reported

Compilation alone is not enough.

A report claiming completion is not enough.

---

# 73. REQUIRED VALIDATION COMMANDS

Use existing project commands and environment conventions.

When appropriate:

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

For profile-mode real-device performance validation when appropriate:

```powershell
flutter run --profile --dart-define-from-file=config/development.json
```

Do not hide or suppress genuine errors merely to make validation appear green.

Backend/migration/store validation must use the project's established tooling and the correct environment.

---

# 74. PHASE EXECUTION RULE

Every Subscription implementation phase must follow:

```text
READ AUTHORITATIVE FILES
        ↓
VERIFY BRANCH / GIT STATUS
        ↓
INSPECT ACTUAL CODE / SCHEMA / PROVIDER STATE
        ↓
STATE PHASE OBJECTIVE
        ↓
IDENTIFY MINIMUM FILES
        ↓
IMPLEMENT ONLY AUTHORIZED SCOPE
        ↓
FORMAT / ANALYZE / TEST
        ↓
PROVE ENTITLEMENT + REGRESSION BEHAVIOR
        ↓
REPORT EXACT EVIDENCE
        ↓
STOP
```

Do not automatically continue to the next phase.

---

# 75. PROHIBITED IMPLEMENTATION SHORTCUTS

Never:

- trust `isPremium` from Flutter as authority
- decrement quota only in Flutter
- grant entitlement from client code
- expose service-role credentials in the browser/app
- disable RLS
- bypass JWT verification
- trust client-provided user ownership
- trust a store price string as purchase proof
- accept provider purchase without server verification
- charge an AI Look on button tap
- charge an AI Look when no usable persisted Final Preview exists
- double-charge after timeout/retry
- create duplicate paid AI requests from rebuilds
- use local device month as billing authority
- reset usage by deleting history
- rewrite committed ledger history
- hardcode Salon Pilot to a special email
- make Salon Pilot unlimited
- create client-session billing
- restore the old 3-previews-per-client concept
- modify Gemini models to make subscription cheaper
- modify Tutorial behavior to create a second billing unit
- add rollover
- add unlimited AI
- add add-on packs in V1
- auto-continue later phases

---

# 76. PRICING / BUSINESS SUMMARY

Approved V1 baseline:

```text
FACETUNE FREE
PHP 0
1 AI Look one-time
```

```text
FACETUNE PLUS
PHP 399/month
3 AI Looks/month
```

```text
FACETUNE PRO
PHP 899/month
8 AI Looks/month
```

```text
SALON PRO
PHP 2,999/month
35 AI Looks/month
1 Makeup Artist account
```

```text
SALON PILOT
Complimentary
30 AI Looks initial
Admin-editable
Temporary
Non-public
No automatic reset
1 Makeup Artist account
```

Universal rule:

```text
1 successfully generated + persisted usable Final Makeup Preview
=
1 AI Look
```

Tutorial rule:

```text
Tutorial included
Optional to open
0 additional AI Looks
```

Failure rule:

```text
No usable persisted Final Makeup Preview
=
No committed AI Look
```

---

# 77. FINAL NON-NEGOTIABLE CONTRACT

The implementation is correct only if all of the following remain true:

1. Free receives one lifetime complimentary AI Look and no automatic reset.
2. Plus receives 3 AI Looks per verified monthly billing period.
3. Pro receives 8 AI Looks per verified monthly billing period.
4. Salon Pro receives 35 AI Looks per verified monthly billing period.
5. Salon Pilot starts at 30 AI Looks and can be changed only through authorized admin-controlled backend behavior.
6. Salon Pilot is not publicly purchasable and does not auto-renew.
7. One usable persisted new Final Makeup Preview consumes exactly one AI Look.
8. Tutorial never consumes an additional AI Look in V1.
9. Technical failure with no usable persisted Final Makeup Preview does not consume an AI Look.
10. Duplicate/retried requests do not double-charge.
11. Quota enforcement is server-side.
12. Store purchase state is verified server-side.
13. Flutter never becomes subscription authority.
14. RLS remains enabled.
15. Service-role and provider secrets remain server-side.
16. Public monthly allowances do not roll over.
17. Existing user History/Saved Looks/Previews/Tutorials are not deleted merely because entitlement ends.
18. Subscription integration does not rewrite protected FaceTune AI architecture.
19. PHP 45 remains a planning assumption until validated by real pilot data and is not hardcoded into entitlement logic.
20. Every implementation phase is inspected, tested, reported, and stopped before the next phase begins.

If any implementation violates one of these rules, the implementation is not compliant with this Source of Truth.

---

# 78. NEXT DOCUMENTS

After this Source of Truth is approved, create in this order:

```text
1. FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md
2. FACETUNE_WEB_ADMIN_SOURCE_OF_TRUTH.md
3. FACETUNE_SUBSCRIPTION_PHASE_PROMPTS.md
4. FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md
```

Implementation order remains:

```text
SUBSCRIPTION PHASES
        ↓
FULL SUBSCRIPTION QA / PASS
        ↓
WEB ADMIN PHASES
        ↓
FINAL END-TO-END QA
```

Do not implement Web Admin before the subscription entitlement/usage architecture it administers is stable enough to serve as authority.

