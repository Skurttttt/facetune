# FACETUNE SUBSCRIPTION OFFER MATRIX — LOCKED AUTHORITY

Status: LOCKED for the subscription offerings below.
Purpose: Commercial/product authority for SUB-12 through SUB-15.
This file does not authorize implementation of later phases by itself.

## 1. Locked subscription offer matrix

| Offer | Price | Included user-facing allowance | Tutorial capability |
|---|---:|---:|---|
| Free | ₱0 | 1 lifetime AI Look | Preserve current approved Free behavior; SUB-12 must not silently change it |
| Plus | ₱399 / month | 3 AI Looks / verified billing period | YES |
| Plus Preview | ₱399 / month | 30 Final Preview credits / verified billing period | NO |
| Pro | ₱899 / month | 8 AI Looks / verified billing period | YES |
| Pro Preview | ₱899 / month | 80 Final Preview credits / verified billing period | NO |
| Salon Pro | ₱2,999 / month | 35 AI Looks / verified billing period | YES |
| Salon Preview | ₱2,999 / month | 350 Final Preview credits / verified billing period | NO |
| Salon Pilot | Admin-granted / non-public | 30 starting AI Looks, admin-adjustable | Preserve current approved contract behavior unless separately changed |

## 2. Locked allowance semantics

### Tutorial-enabled plans

One user-facing AI Look authorizes one new usable Final Makeup Preview under the existing server-authoritative reserve → generate → persist → commit flow.

Tutorial creation/opening must not consume an additional user-facing AI Look.

Existing Tutorial V4 behavior is preserved.

### Preview-only plans

One Final Preview credit authorizes one new usable persisted Final Makeup Preview.

Preview-only plans MUST NOT authorize new Tutorial generation.

Existing historical Tutorial content created while previously entitled remains preserved and readable according to existing historical-content rules.

Preview-only plans MUST use the same locked Final Preview renderer/model/prompt architecture as Tutorial-enabled plans.

## 3. Locked Preview allowances

```text
plus_preview       = 30 Final Preview credits / verified billing period
pro_preview        = 80 Final Preview credits / verified billing period
salon_preview      = 350 Final Preview credits / verified billing period
```

No rollover.

A new verified paid billing period receives the plan's period allowance while historical usage remains preserved.

## 4. Locked protected systems

The following remain locked unless a later explicit authority changes them:

- Final Preview model: `gemini-3.1-flash-image`
- fail-closed Final Preview validation
- Tutorial V4
- `tutorial_guideline_v4_7`
- `tutorial_manifest_v4_1`
- Standard Mode
- My Makeup Kit
- reserve → generate → persist → commit
- reservation-time usage attribution
- SUB-10 verify → activate → acknowledge Google Play subscription architecture
- SUB-11 provider-authoritative RTDN/lifecycle/restore architecture
- Google Play provider state remains authoritative for store subscriptions
- no Gemini/provider secret in Flutter
- RLS remains enabled
- no client-side entitlement authority

## 5. Planning cost assumptions — NOT runtime truth

Current planning hypotheses to measure in SUB-13:

```text
Tutorial-enabled delivered AI Look ≈ ₱45 effective AI/API cost
Preview-only delivered Final Preview ≈ ₱4 effective AI/API cost
```

These are product-planning assumptions only.

They MUST NOT be embedded into entitlement authorization, billing authority, allowance reset logic, or client code.

The locked 30 / 80 / 350 Preview allowances MUST NOT be changed automatically by SUB-13.
SUB-13 may report unit economics and variance; changing the locked matrix requires explicit user authorization.

## 6. Top-up architecture authority

Top-ups are IN SCOPE only for SUB-13B and later phases.

Locked architectural rules:

- top-ups are purchased credits, not subscription allowance adjustments
- top-ups are not Salon Pilot admin adjustments
- purchased credits require server-authoritative provider verification
- purchased-credit provenance must be auditable
- subscription allowance is consumed before compatible purchased credits
- purchased credits do not reset on monthly subscription renewal
- purchased credits survive cancellation/expiration in storage, but consumption requires an active eligible paid entitlement
- a top-up never grants a capability that the active plan does not allow
- Preview-only purchased credits must never become Tutorial-capable merely because the user later changes plan
- capability/provenance must be preserved so future plan changes cannot create credit arbitrage
- no top-up may be client-granted or client-incremented
- replay/duplicate purchase tokens must not duplicate credits

## 7. Top-up commercial pack status

The subscription matrix above is LOCKED.

Top-up price/pack quantities are NOT locked by this file because the Preview allowances were materially changed to 30 / 80 / 350 and SUB-13 is specifically responsible for validating the ₱45 vs ₱4 unit-cost hypothesis.

Current planning candidates only:

```text
Tutorial-capable top-up candidate:
₱149 → +1 Tutorial-capable AI Look credit

Preview-only top-up candidate:
₱149 → +10 Preview-only Final Preview credits
```

These candidates MUST NOT become production products until explicitly approved after SUB-13 evidence.

SUB-13B must stop at its commercial gate if no approved top-up pack matrix exists.

## 8. Phase ownership

```text
SUB-12
Free + Salon Pilot non-store compatibility

SUB-12B
Plus Preview / Pro Preview / Salon Preview implementation

SUB-13
Telemetry + cost measurement + unit economics

SUB-13B
Purchased top-up credit implementation, only after commercial pack approval

SUB-14
Full security / regression / edge-case hardening across the complete matrix

SUB-15
Real-device / Google Play sandbox / production-readiness acceptance
```

Completion of one phase never authorizes the next phase automatically.
# SUB-12 — FREE & SALON PILOT BACKEND COMPATIBILITY

Read all current repository authorities, handoffs, migrations, shared contracts, prior phase completion reports, and `00_FACETUNE_SUBSCRIPTION_OFFER_MATRIX_LOCKED.md` before changing anything.

Implement ONLY SUB-12.

## Active roles

Especially apply:

- Senior Subscription Systems Engineer
- Senior Entitlements Engineer
- Senior Supabase/PostgreSQL Engineer
- Senior Backend Engineer
- Senior Security Engineer
- Senior Shared-Contract Engineer
- Senior Concurrency Engineer
- Senior QA / Integration Test Engineer

## Starting authority

Expected branch:

```text
feature/subscription-v1
```

Expected accepted SUB-11 completion commit:

```text
96fc545beca3edf9dbc1ec9c83e4d61265eb4296
SUB-11 harden Google Play purchase restore flow
```

If HEAD has advanced only through explicitly accepted post-SUB-11 work, report it and continue only if the authority is clear.
If branch/history materially conflicts, STOP.

## Global hard locks

Preserve unless this phase explicitly requires a minimal compatible extension:

- Final Preview model = `gemini-3.1-flash-image`
- fail-closed Final Preview validator
- Tutorial V4
- `tutorial_guideline_v4_7`
- `tutorial_manifest_v4_1`
- Standard Mode
- My Makeup Kit
- reserve → generate → persist → commit
- reservation-time usage attribution
- SUB-10 verify → activate → acknowledge
- SUB-11 provider-authoritative lifecycle / RTDN / restore
- historical content preservation
- RLS
- server-side entitlement authority
- no Gemini key in Flutter
- no provider private credentials in Flutter/browser
- no client-side plan/allowance grant
- no destructive Git operations

Protected working-tree rule:

`FACETUNE_SUBSCRIPTION_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md` may contain user-owned changes.
Do not revert, stage, or commit those changes unless explicitly instructed.

Do not touch unrelated stashes.

## Objective

Finalize backend compatibility for the two non-store entitlement types:

1. Free
2. Salon Pilot

They must use the same safe entitlement / AI Look usage engine without pretending to be Google Play purchases.

This phase MUST leave the architecture cleanly extensible for:

- `plus_preview`
- `pro_preview`
- `salon_preview`
- capability-based Tutorial authorization
- purchased top-up credits

But SUB-12 MUST NOT implement those later commercial features.

## Free contract

```text
plan_code = free
publicly purchasable = false
Google Play product = none
billing/provider origin = non-store/system equivalent supported by current contract
allowance = 1 lifetime AI Look
automatic reset = never
rollover = not applicable
auto_renew = false
RTDN lifecycle = none
purchase reference = none
```

Tutorial behavior for Free must preserve the currently approved V1 Free behavior.
SUB-12 must not silently change Free Tutorial capability.

## Free lifetime invariant

A FaceTune account receives at most ONE lifetime complimentary Free AI Look.

That state must survive:

- month changes
- year changes
- logout/login
- app reinstall
- app-data deletion
- device replacement
- session refresh
- paid purchase
- renewal
- cancellation
- expiration
- Restore Purchases
- re-subscription

None of those events may recreate or reset Free allowance.

Server-side account identity and historical ledger state are authoritative.

## Free + paid coexistence

Trace the current resolver and implement deterministic precedence.

Required invariants:

- a valid paid entitlement must not be accidentally shadowed by Free
- activating paid does not recreate Free
- renewal does not recreate Free
- Restore does not recreate Free
- expiration does not recreate Free
- re-subscription does not recreate Free
- if Free was consumed, it remains consumed forever
- if Free exists but is unused when paid becomes active, preserve its historical state; do not silently delete or consume it
- no client request can choose which entitlement wins

Document the exact precedence rule.

## Salon Pilot contract

```text
plan_code = salon_pilot
origin = admin_granted
publicly purchasable = false
Google Play product = none
starting base allowance = 30
admin-adjustable = true
auto_renew = false
automatic reset = none
rollover = not applicable
expiration = required / admin-controlled
RTDN lifecycle = none
purchase reference = none
```

Salon Pilot is NOT unlimited.

## Salon Pilot allowance semantics

Support the current canonical equivalent of:

```text
base allowance
+ audited administrative adjustment
- committed usage
- currently reserved usage
= effective remaining allowance
```

Conceptual example:

```text
base = 30
committed = 18
admin adjustment = +10
effective allowance = 40
remaining = 22
```

Administrative allowance adjustment MUST remain conceptually separate from future purchased top-up credits.

Do not create a generic `extra credits` bucket that erases provenance.

## Salon Pilot status semantics

Generation must be denied when authoritative state is:

- expired
- suspended, if represented by current contract
- revoked, if represented by current contract

Remaining allowance never overrides a denied status.

Use authoritative server time.

Expiration is admin-controlled and required.

## Shared Contract

Inspect `subscription_admin_contract_v1` before implementation.

Prefer existing contract vocabulary for:

- plan code
- origin/provider
- status
- public purchasability
- base allowance
- effective allowance
- committed usage
- reserved usage
- remaining allowance
- expiration
- auto-renew
- administrative adjustment

Do not duplicate concepts under new names without necessity.

If the Shared Contract cannot cleanly represent Free or Salon Pilot, implement the smallest backward-compatible extension and test it.

## Free provisioning discovery

Before choosing a mechanism, evaluate the current account architecture for:

- lazy idempotent provisioning
- resolver-driven provisioning
- signup/account provisioning
- database trigger
- another existing lifecycle mechanism

Choose the mechanism that best satisfies:

- server authority
- concurrency safety
- idempotency
- existing-user compatibility
- no client trust
- minimal disruption

Two simultaneous first requests from different devices must not create two Free entitlements.

## Existing user classification

Explicitly classify and test:

1. brand-new no-history users
2. users with no entitlement but historical usage
3. current paid users
4. expired paid users
5. cancelled-but-paid-through users
6. Salon Pilot users
7. historical paid users
8. SUB-10 / SUB-11 test accounts

Do not accidentally grant an additional complimentary AI Look merely because a user predates SUB-12.

If backfill is required:

- make it deterministic
- make it idempotent
- preserve paid history
- preserve usage history
- do not duplicate entitlements
- do not reset Free lifetime usage

## Store isolation

The Google Play verification path MUST NOT be capable of creating:

```text
free
salon_pilot
```

Verify the server-owned product → plan mapping remains authoritative.

A malicious client supplying `plan_code=free` or `plan_code=salon_pilot` must not create those entitlements.

## Future Preview-plan compatibility lock

SUB-12 does NOT implement:

```text
plus_preview
pro_preview
salon_preview
```

However:

- do not introduce a closed-world assumption that current paid plan codes are the only possible store plans
- avoid new plan-name conditionals when a capability/contract field is more appropriate
- do not hard-code Tutorial entitlement into Free/Salon Pilot branching in a way that blocks capability-based paid plans
- preserve room for Tutorial-enabled and Preview-only paid offerings

If the current architecture lacks a capability model, document the gap.
Do not expand SUB-12 into SUB-12B unless required for correctness.

## Future top-up compatibility lock

SUB-12 does NOT implement purchased top-ups.

Administrative Salon Pilot adjustments MUST NOT be designed as the future purchased-credit ledger.

Keep these concepts separable:

```text
subscription/non-store base allowance
administrative adjustment
purchased top-up credits
```

## Minimum tests

### Free

1. new eligible user gets exactly one Free entitlement
2. repeated initialization remains one entitlement
3. concurrent initialization remains one entitlement
4. first Free reservation succeeds
5. successful commit changes remaining 1 → 0
6. second Free reservation denied
7. month change does not reset
8. year change does not reset
9. logout/login does not reset
10. reinstall-equivalent refresh does not reset
11. paid activation does not recreate Free
12. paid renewal does not recreate Free
13. paid expiration does not recreate Free
14. Restore does not recreate Free
15. re-subscription does not recreate Free
16. failed generation releases reservation without consuming lifetime credit
17. successful retry consumes exactly once
18. duplicate operation id idempotent
19. normal client cannot self-grant Free
20. paid entitlement precedence does not accidentally select Free

### Salon Pilot

21. 30 starting allowance representable
22. 18 committed → 12 remaining
23. conceptual +10 admin adjustment → 22 remaining
24. adjustment does not rewrite historical usage
25. month change does not reset Pilot
26. expiration blocks generation
27. suspension blocks if supported
28. revocation blocks if supported
29. Pilot is not publicly purchasable
30. Google Play verification cannot create Pilot
31. normal user cannot self-grant Pilot
32. no hidden production grant endpoint created for testing

### Regression

33. Plus unchanged
34. Pro unchanged
35. Salon Pro unchanged
36. Google Play verify/activate/ack unchanged
37. RTDN lifecycle unchanged
38. Restore unchanged
39. reserve → generate → persist → commit unchanged
40. Tutorial V4/guideline/manifest unchanged
41. Final Preview model remains `gemini-3.1-flash-image`

## Implementation discipline

Before modifying:

1. baseline `git status --short`, branch, HEAD
2. inspect schema and migrations
3. inspect resolver
4. inspect allowance arithmetic
5. inspect usage ledger
6. inspect RLS
7. inspect Shared Contract
8. inspect store product mapping
9. inspect existing tests
10. document the chosen Free provisioning model before implementation

Do not create parallel architecture if the current engine safely supports the requirement.

## Do NOT implement

- Admin Dashboard
- Admin user search
- Admin grant UI
- Admin +5/+10 UI
- Admin suspend/revoke UI
- Web Admin frontend
- Plus Preview
- Pro Preview
- Salon Preview
- new Preview Google Play products
- purchased top-ups
- top-up products
- SUB-13 telemetry work beyond compatibility needs
- SUB-14
- SUB-15

## Acceptance gate

SUB-12 = PASS only if:

- Free is first-class, server-authoritative, one-time lifetime
- Free never automatically resets
- provisioning is concurrency-safe and idempotent
- Salon Pilot is first-class, non-store, admin-granted
- Salon Pilot starts at 30
- Pilot expiration/status blocks generation correctly
- future admin adjustments are representable without hacks
- Google Play cannot create Free/Pilot
- normal client cannot self-grant them
- Shared Contract represents them cleanly
- no top-up/admin-adjustment conflation introduced
- no Preview-plan blocking architecture introduced
- paid regressions pass
- locked V4/model systems are unchanged

## Completion report

Use the standard project completion report plus:

```text
SUB-12 RESULT:
PASS / FAIL

FREE
Provisioning mechanism:
Representation:
Lifetime reset protection:
PASS / FAIL
Concurrent provisioning:
PASS / FAIL
Paid precedence:
PASS / FAIL

SALON PILOT
Representation:
Base allowance:
30
Adjustment compatibility:
PASS / FAIL
Expiration enforcement:
PASS / FAIL
Publicly purchasable:
NO

STORE ISOLATION
Google Play can create Free:
YES / NO
Google Play can create Salon Pilot:
YES / NO
Normal client can self-grant Pilot:
YES / NO

FUTURE COMPATIBILITY
Preview-plan compatibility:
PASS / GAP IDENTIFIED
Purchased-top-up compatibility:
PASS / GAP IDENTIFIED
Top-ups modeled as admin adjustments:
YES / NO

LOCKS
Final Preview model:
Tutorial V4:
SUB-10 impact:
SUB-11 impact:

TESTS
Automated tests:
flutter analyze:
Diff audit:
Production mutation/deployment:

NEXT PHASE AUTHORIZED:
NO
```

Then STOP.

Do not implement SUB-12B automatically.
# SUB-12B — CAPABILITY-AWARE PAID OFFER EXPANSION

Read all current repository authorities, prior completion reports, and `00_FACETUNE_SUBSCRIPTION_OFFER_MATRIX_LOCKED.md` before changing anything.

Implement ONLY SUB-12B.

## Active roles

- Senior Subscription Systems Engineer
- Senior Google Play Billing Engineer
- Senior Entitlements Engineer
- Senior Shared-Contract Engineer
- Senior Supabase/PostgreSQL Engineer
- Senior Flutter Architect
- Senior Security Engineer
- Senior QA / Integration Test Engineer

## Starting gate

Begin only after an explicitly accepted SUB-12 PASS.
Use the accepted SUB-12 completion commit as baseline.

## Global hard locks

Preserve:

- Final Preview model `gemini-3.1-flash-image`
- fail-closed Final Preview validator
- Tutorial V4
- `tutorial_guideline_v4_7`
- `tutorial_manifest_v4_1`
- Standard Mode
- My Makeup Kit
- reserve → generate → persist → commit
- reservation-time attribution
- SUB-10 verify → activate → acknowledge
- SUB-11 provider-authoritative RTDN/lifecycle/restore
- RLS and server-side entitlement authority
- no Gemini/provider secret in Flutter

Do not revert/stage/commit the user's unrelated dirty prompt file.
No destructive Git operations.

## Objective

Implement the locked paid offer matrix while preserving the proven subscription lifecycle engine.

### Existing Tutorial-enabled offers

```text
PLUS
₱399/month
3 AI Looks / verified billing period
Tutorial = YES

PRO
₱899/month
8 AI Looks / verified billing period
Tutorial = YES

SALON PRO
₱2,999/month
35 AI Looks / verified billing period
Tutorial = YES
```

### New Preview-only offers — LOCKED

```text
PLUS PREVIEW
₱399/month
30 Final Preview credits / verified billing period
Tutorial = NO

PRO PREVIEW
₱899/month
80 Final Preview credits / verified billing period
Tutorial = NO

SALON PREVIEW
₱2,999/month
350 Final Preview credits / verified billing period
Tutorial = NO
```

Do not automatically change these prices/allowances.

## Canonical plan codes

```text
plus
plus_preview
pro
pro_preview
salon_pro
salon_preview
```

Do not silently rename existing codes.

## Google Play product IDs — human gate

Do not invent production product IDs.

Before any Play Console mutation or production mapping:

1. inspect current repo/Play configuration
2. identify whether approved IDs already exist
3. if exact approved IDs are absent, STOP and request them

Suggested names may be reported, but suggestions are not authority.

## Capability model

The authoritative plan contract must be able to answer at minimum:

```text
can_generate_final_preview
can_generate_tutorial
period_allowance
allowance_unit
publicly_purchasable
billing_provider/origin
```

Expected:

```text
plus          tutorial = true
plus_preview  tutorial = false
pro           tutorial = true
pro_preview   tutorial = false
salon_pro     tutorial = true
salon_preview tutorial = false
```

Avoid plan-name branching sprawl where one authoritative capability definition can safely drive behavior.

## Allowance-unit semantics

Tutorial-enabled plans:

```text
1 AI Look
= 1 new authorized Final Preview reservation/commit
Tutorial consumes 0 additional user-facing allowance
```

Preview-only plans:

```text
1 Final Preview credit
= 1 new authorized Final Preview reservation/commit
Tutorial authorization = false
```

The ledger may reuse the current reservation accounting if safe, but API/UI semantics must not mislabel Preview-only quota as Tutorial-enabled AI Looks.

## Locked Final Preview behavior

Preview-only plans MUST use:

- same Standard/My Makeup Kit Final Preview path where applicable
- `gemini-3.1-flash-image`
- same locked Final Preview prompt architecture
- same fail-closed validation
- same reserve → generate → persist → commit
- same reservation-time attribution

No cheaper/lower-quality model path is authorized.

## Tutorial authorization

Preview-only plans MUST be denied NEW Tutorial generation server-side.

Required:

- server authorization denies new Tutorial generation for Preview-only plans
- Flutter reflects capability
- direct endpoint/RPC attempts cannot bypass it
- historical Tutorial content already generated while previously authorized remains accessible
- reopening historical Tutorial consumes no new credit

Do not delete Tutorial history when a user changes to Preview-only.

## Period/reset semantics

For all store-paid plans:

- verified provider period is authoritative
- no rollover
- renewal establishes new period allowance exactly once
- historical usage is preserved
- client clock is not authority

Locked allowances:

```text
plus = 3
plus_preview = 30
pro = 8
pro_preview = 80
salon_pro = 35
salon_preview = 350
```

## Plan transitions

Inspect actual Google Play replacement/transition support.

Where provider configuration permits, support:

- Tutorial-enabled → Preview-only
- Preview-only → Tutorial-enabled
- Plus-family ↔ Pro-family only if approved provider configuration supports it
- Salon transitions only if approved provider configuration supports them

Do not fabricate unsupported provider behavior.

Required transition invariants:

- provider evidence determines canonical plan
- historical content preserved
- historical usage preserved
- no duplicate entitlement
- no double allowance grant
- Preview-only period never gains Tutorial capability
- client labels never override verified product identity

## Public paywall / UX

Clearly distinguish:

```text
Tutorial-enabled:
fewer AI Looks
Tutorial included

Preview-only:
higher Final Preview allowance
Tutorial not included
```

Do not imply Preview-only includes Tutorial.
Use current FaceTune Material 3 design language.

## Store authority

Server-owned product → plan mapping is authoritative.

The client must not be trusted for:

- plan code
- allowance
- Tutorial capability
- product price

## Restore / RTDN / lifecycle

All Preview plans must reuse:

- verify → activate → acknowledge
- RTDN → provider re-verification → reconciliation
- paid-through cancellation
- renewal
- expiration
- Restore Purchases
- deduplication/idempotency

Do not build a second lifecycle path.

## Top-up compatibility

Do not implement top-ups here.

Ensure capability representation can later distinguish purchased-credit classes without changing plan identity.
Do not overload Salon Pilot admin adjustments for future top-ups.

## Minimum tests

### Plan configuration

1. Plus = 3 + Tutorial
2. Plus Preview = 30 + no Tutorial
3. Pro = 8 + Tutorial
4. Pro Preview = 80 + no Tutorial
5. Salon Pro = 35 + Tutorial
6. Salon Preview = 350 + no Tutorial

### Authorization

7. Preview-only Final Preview reservation succeeds within allowance
8. Preview-only Tutorial generation denied server-side
9. direct client call cannot bypass Tutorial denial
10. Tutorial-enabled plan still allows Tutorial under existing rules
11. historical Tutorial reopen remains allowed under Preview-only
12. historical Preview reopen consumes zero

### Accounting

13. Plus Preview 30→29
14. Pro Preview 80→79
15. Salon Preview arithmetic at 350 without live exhaustion
16. duplicate operation no double-charge
17. technical failure releases reservation
18. no rollover
19. renewal grants new period allowance once

### Provider

20. each approved Preview product maps to one canonical plan
21. wrong product rejected
22. client-supplied plan ignored
23. duplicate verification idempotent
24. cancel paid-through works
25. expiration blocks
26. Restore idempotent
27. RTDN dedup works

### Transition

28. Tutorial → Preview capability changes only from provider-verified state
29. Preview → Tutorial capability changes only from provider-verified state
30. historical content preserved
31. no duplicate entitlement
32. no duplicate allowance

### Security/regression

33. Free unchanged
34. Salon Pilot unchanged
35. Plus/Pro/Salon Pro unchanged
36. Final Preview model unchanged
37. Tutorial V4/guideline/manifest unchanged
38. Standard Mode unchanged
39. My Makeup Kit unchanged
40. no new client authority/secret
41. RLS remains enabled

## Do NOT implement

- top-up purchases
- purchased-credit ledger
- Admin UI
- Web Admin
- automatic cost-based plan changes
- model downgrade
- Tutorial V5
- annual subscriptions
- seat billing
- per-client salon accounting
- SUB-13 telemetry beyond compatibility needs

## Acceptance gate

SUB-12B = PASS only if:

- all six paid offers are represented correctly
- 30/80/350 are authoritative per verified period
- Preview-only Tutorial denial is server-enforced
- Final Preview quality/model/prompt path remains locked
- store mapping is server authoritative
- lifecycle reuses SUB-10/SUB-11
- historical content survives plan changes
- no top-up implementation leaked into this phase
- no unjustified plan-name branching sprawl
- automated/regression tests pass

## Completion report

Use the standard report plus:

```text
SUB-12B RESULT:
PASS / FAIL

OFFER MATRIX
Plus:
Plus Preview:
Pro:
Pro Preview:
Salon Pro:
Salon Preview:

CAPABILITIES
Authoritative capability source:
Preview Tutorial authorization:
PASS / FAIL
Historical Tutorial preservation:
PASS / FAIL

PROVIDER
Approved Preview product IDs:
Product → plan mapping:
Restore:
RTDN:
Renewal:
Expiration:

ACCOUNTING
Plus Preview allowance: 30
Pro Preview allowance: 80
Salon Preview allowance: 350
No rollover:
PASS / FAIL

LOCKS
Final Preview model:
Tutorial V4:
SUB-10 impact:
SUB-11 impact:
SUB-12 impact:

TESTS
Automated tests:
flutter analyze:
Diff audit:
Production/Play mutations:

NEXT PHASE AUTHORIZED:
NO
```

Then STOP.

Do not begin SUB-13 automatically.
# SUB-13 — SUBSCRIPTION TELEMETRY, COST MEASUREMENT & UNIT ECONOMICS

Read all current authorities, prior completion reports, and `00_FACETUNE_SUBSCRIPTION_OFFER_MATRIX_LOCKED.md` before changing anything.

Implement ONLY SUB-13.

## Active roles

- Senior Observability Engineer
- Senior AI FinOps / Cost Optimization Engineer
- Senior Subscription Systems Engineer
- Senior Privacy Engineer
- Senior Backend Engineer
- Senior Reliability Engineer
- Senior Data/Analytics Engineer
- Senior QA Engineer

## Starting gate

Begin only after an explicitly accepted SUB-12B PASS.
Use the accepted SUB-12B completion commit as baseline.

## Global hard locks

Preserve:

- `gemini-3.1-flash-image`
- fail-closed Final Preview validation
- Tutorial V4
- `tutorial_guideline_v4_7`
- `tutorial_manifest_v4_1`
- Standard Mode
- My Makeup Kit
- reserve → generate → persist → commit
- reservation-time attribution
- SUB-10 / SUB-11 provider authority
- RLS / server-side entitlement authority
- locked subscription prices and allowances

Do not revert/stage/commit unrelated user-owned prompt-file changes.
No destructive Git operations.

## Objective

Add privacy-safe technical measurement required to understand:

- subscription behavior
- user-facing quota usage
- Preview-only vs Tutorial-enabled delivery cost
- provider verification/lifecycle reliability
- whether current planning cost assumptions are directionally accurate

Do not turn telemetry into a second database of private makeup content.

## Locked commercial matrix

DO NOT modify automatically:

```text
Plus          ₱399   3 AI Looks          Tutorial YES
Plus Preview  ₱399   30 Final Previews   Tutorial NO

Pro           ₱899   8 AI Looks          Tutorial YES
Pro Preview   ₱899   80 Final Previews   Tutorial NO

Salon Pro     ₱2,999 35 AI Looks         Tutorial YES
Salon Preview ₱2,999 350 Final Previews  Tutorial NO
```

SUB-13 may report economic concerns/recommendations.
Changing prices/allowances requires explicit user authorization.

## Planning cost hypotheses — not runtime truth

Measure against:

```text
Tutorial-enabled delivered AI Look ≈ ₱45 effective AI/API cost
Preview-only delivered Final Preview ≈ ₱4 effective AI/API cost
```

These MUST NOT become entitlement logic.
Do not hardcode them throughout runtime code.

If a cost model is needed, make it separately maintainable/reporting-time.

## User-facing unit model

Telemetry must distinguish at minimum:

```text
Tutorial-enabled user-facing AI Look
Preview-only Final Preview credit
```

Do not combine materially different operations into one ambiguous metric without plan/capability dimensions.

Where Tutorial generation is technically separate from Final Preview generation, preserve only the safe linkage needed to estimate total delivered Tutorial-enabled AI Look cost.

## Technical measurements

Where current architecture safely supports them, measure/expose:

- canonical plan code
- capability class
- billing provider/origin
- entitlement state transitions
- sanitized billing-period identity/correlation
- operation kind
- reserved count
- committed count
- released count
- successful persisted Final Preview count
- Tutorial technical operation count separately
- sanitized failure category
- operation latency
- model/version metadata where safe
- provider verification success/failure category
- RTDN reconciliation counts/categories
- Restore verification counts/categories
- retry/duplicate suppression counts
- provider usage units useful for cost estimation where safely available
- reporting-time provider price / FX inputs through maintainable configuration where justified

## Cost analysis outputs

Support reporting of:

```text
effective cost per successfully delivered Preview-only Final Preview

effective cost per successfully delivered Tutorial-enabled AI Look

cost per plan at observed usage

theoretical maximum AI/API cost if all included allowance is consumed

failure/retry overhead

variance vs planning assumptions
```

For the locked matrix, report theoretical cost under the maintained model for:

- 3 Tutorial AI Looks
- 30 Preview-only Final Previews
- 8 Tutorial AI Looks
- 80 Preview-only Final Previews
- 35 Tutorial AI Looks
- 350 Preview-only Final Previews

Do not change the matrix automatically.

## Privacy rules

Never log/store merely for telemetry:

- image bytes
- base64 images
- signed URLs
- JWTs
- service-role credentials
- Google private credentials
- full purchase tokens
- raw provider responses containing sensitive purchase data
- private Gemini prompts
- raw My Makeup Kit contents
- user-entered makeup/product names merely for cost measurement
- full email addresses unless already required by an approved operational contract

Telemetry measures system behavior, not makeup content.

## Transaction safety

Telemetry must never become part of entitlement correctness.

If telemetry/reporting fails:

- reserve/commit/release correctness remains intact
- provider verification result remains authoritative
- no user is double-charged or denied solely because telemetry failed

Use out-of-band / best-effort patterns where appropriate.

## Top-up commercial-gate preparation

SUB-13 does NOT implement top-ups.

It must produce evidence for SUB-13B commercial approval.

At completion, report:

```text
Measured/estimated Tutorial AI Look unit cost:
Measured/estimated Preview-only Final Preview unit cost:

Top-up candidate A:
₱149 → +1 Tutorial-capable AI Look

Top-up candidate B:
₱149 → +10 Preview-only Final Preview credits

Economic assessment:
SAFE / NEEDS ADJUSTMENT / INSUFFICIENT DATA
```

This is a recommendation gate only.
Do not create Google Play top-up products.

## Minimum tests

1. committed vs released distinguishable
2. duplicate operation does not double-count logical usage
3. Preview-only vs Tutorial-enabled dimensions distinguishable
4. successful Final Preview delivery counted once
5. Tutorial technical operation counted separately
6. failure category sanitized
7. secrets absent
8. image data absent
9. signed URLs absent
10. provider tokens absent/redacted
11. private prompts absent
12. telemetry failure does not corrupt reserve
13. telemetry failure does not corrupt commit
14. telemetry failure does not corrupt release
15. provider verification telemetry cannot change entitlement result
16. duplicate RTDN does not double-count canonical lifecycle transition
17. Restore replay does not create misleading duplicate entitlement count
18. cost-model change does not change entitlement authorization
19. locked plan allowances remain unchanged
20. locked model/Tutorial V4 paths unchanged

## Do NOT implement

- new Gemini calls solely for telemetry
- model downgrade
- prompt downgrade
- price/allowance changes
- top-up purchase
- top-up credit ledger
- Web Admin analytics UI
- broad analytics-platform migration
- user-content analytics
- SUB-14 hardening beyond defects directly introduced/proven by this phase

## Acceptance gate

SUB-13 = PASS only if:

- usage can be measured safely
- Preview-only and Tutorial-enabled economics are distinguishable
- privacy locks hold
- telemetry failure cannot corrupt entitlement correctness
- locked offer matrix is unchanged
- a top-up commercial recommendation can be produced
- no runtime entitlement rule depends on ₱45/₱4 assumptions
- regressions pass

## Completion report

Use the standard report plus:

```text
SUB-13 RESULT:
PASS / FAIL

UNIT ECONOMICS
Tutorial-enabled effective cost:
Preview-only effective cost:
Planning ₱45 variance:
Planning ₱4 variance:

LOCKED MATRIX ECONOMICS
Plus:
Plus Preview:
Pro:
Pro Preview:
Salon Pro:
Salon Preview:

TOP-UP COMMERCIAL REVIEW
₱149 +1 Tutorial AI Look:
SAFE / NEEDS ADJUSTMENT / INSUFFICIENT DATA

₱149 +10 Preview-only Final Previews:
SAFE / NEEDS ADJUSTMENT / INSUFFICIENT DATA

Recommended top-up matrix:
<recommendation only>

PRIVACY
Sensitive telemetry found:
YES / NO

TRANSACTION SAFETY
Telemetry affects entitlement authority:
YES / NO

LOCKS
Offer matrix changed:
YES / NO
Final Preview model:
Tutorial V4:

TESTS
Automated tests:
flutter analyze:
Diff audit:
Production mutation/deployment:

NEXT PHASE AUTHORIZED:
NO

TOP-UP COMMERCIAL HUMAN APPROVAL REQUIRED BEFORE SUB-13B:
YES
```

Then STOP.

Do not begin SUB-13B automatically.
# SUB-13B — PURCHASED AI LOOK / FINAL PREVIEW TOP-UP CREDITS

Read all current authorities, prior completion reports, and `00_FACETUNE_SUBSCRIPTION_OFFER_MATRIX_LOCKED.md` before changing anything.

Implement ONLY SUB-13B.

## Active roles

- Senior Commerce Systems Engineer
- Senior Google Play Billing Engineer
- Senior Entitlements Engineer
- Senior Ledger / Accounting Engineer
- Senior Supabase/PostgreSQL Engineer
- Senior Security Engineer
- Senior Idempotency / Concurrency Engineer
- Senior QA / Integration Test Engineer

## Starting gates — BOTH required

Begin only after:

1. explicitly accepted SUB-13 PASS
2. explicit human approval of the top-up commercial pack matrix

If approved pack price/quantity/product IDs are not present in current authority:

STOP.

Do not invent them.

## Global hard locks

Preserve:

- `gemini-3.1-flash-image`
- fail-closed Final Preview validation
- Tutorial V4
- `tutorial_guideline_v4_7`
- `tutorial_manifest_v4_1`
- Standard Mode
- My Makeup Kit
- reserve → generate → persist → commit
- reservation-time attribution
- SUB-10 / SUB-11 provider-authoritative subscription lifecycle
- SUB-12 Free / Salon Pilot semantics
- SUB-12B locked 3/30/8/80/35/350 subscription matrix
- RLS / server-side entitlement authority

Do not revert/stage/commit unrelated user-owned prompt-file changes.
No destructive Git operations.

## Objective

Implement repeatable purchased top-up credits without corrupting:

- subscription allowance
- Salon Pilot admin adjustments
- billing-period reset semantics
- plan capabilities
- provider authority
- historical usage

## Architectural lock

These are distinct accounting concepts:

```text
subscription/non-store base allowance
administrative adjustment
purchased top-up credits
```

Never collapse them into one provenance-free mutable integer.

## Top-up capability class

A purchased credit must retain a capability/provenance class.

Minimum conceptual classes:

```text
tutorial_capable_ai_look
preview_only_final_preview
```

Rules:

- a Preview-only credit may NEVER become Tutorial-capable after a plan change
- a top-up never grants capability beyond the active plan
- effective usable capability is bounded by both the credit class and current active plan capability
- switching plans must not create credit arbitrage

Example:

```text
Preview-only credit + Tutorial-enabled active plan
= Final Preview only for that credit

Tutorial-capable credit + Preview-only active plan
= preserved, but must not authorize Tutorial while current plan forbids Tutorial
```

Document exact deterministic consumption behavior.

## Active-plan requirement

Purchased credits persist in the account until consumed according to the approved contract.

New generation using top-up credits requires an active eligible paid entitlement.

If paid subscription expires:

- purchased credits remain stored
- they are not deleted/reset
- generation remains blocked until an eligible paid entitlement is active again

Free alone does not unlock paid top-up consumption unless a later explicit product authority changes this.

## Consumption order

Unless the approved commercial contract says otherwise:

```text
1. current-period included subscription allowance
2. compatible purchased top-up credits
```

Do not consume purchased value while compatible included allowance remains.

## Provider authority

Top-ups must use the approved Google Play one-time/repeatable digital purchase mechanism supported by current project/provider architecture.

Do not invent a provider API.

Inspect current Google Play Billing / Android Publisher support before implementation.

Required conceptual order:

```text
provider purchase evidence
→ server-side verification
→ idempotent transactional credit grant
→ provider acknowledgement/consumption as appropriate
→ authoritative credit refresh
```

The exact verification/consume API must match current approved Google Play behavior.

Do not trust client:

- price
- quantity
- credit class
- product-to-credit mapping

Server-owned product mapping is authoritative.

## Purchase-token idempotency

Each top-up purchase token/reference may grant exactly once.

Required:

- replay does not duplicate credits
- concurrent verification does not duplicate credits
- retry after network failure is safe
- provider follow-up failure after committed grant is recoverable without double grant
- cross-user ownership rejected

## Purchased-credit ledger

Prefer append-only/auditable provenance-safe accounting.

Must preserve enough safe data to prove:

- provider purchase identity/reference
- user owner
- credit class
- quantity granted
- quantity consumed / remaining semantics
- timestamps
- provider verification state
- consuming generation operation linkage where required

Do not store raw sensitive tokens where current architecture uses hashes/references.

## Period-reset isolation

Subscription renewal/reset MUST NOT erase purchased credits.

Purchased credits MUST NOT become the next period's included allowance.

Period allowance and purchased-credit accounting remain distinct.

## Salon Pilot isolation

Salon Pilot admin adjustments are NOT purchased top-ups.

Top-up products must not mutate the administrative allowance-adjustment bucket unless the approved schema explicitly has provenance-safe typed adjustments that preserve the distinction.

No Web Admin work here.

## Reserve / commit / release source-awareness

Generation reservation must know which allowance source it reserved from.

If generation fails before usable persisted result:

- release the exact reserved source
- restore purchased credit if that source was reserved
- do not duplicate balances

If generation commits:

- consume exactly once from the reserved source

## UI

Show clearly:

- included current-period remaining
- purchased-credit remaining
- approved top-up pack offer(s) only to eligible paid users
- capability of pack
- Preview-only pack does not include Tutorial

Do not introduce wallet/coin gamification unless explicitly approved.

## Commercial matrix gate

Use ONLY the explicitly approved top-up matrix from the post-SUB-13 human gate.

If the approved authority adopts the current planning candidate, it may be:

```text
Tutorial top-up:
₱149 → +1 Tutorial-capable AI Look

Preview top-up:
₱149 → +10 Preview-only Final Preview credits
```

But these values are NOT authoritative unless explicitly marked APPROVED in project authority.

## Minimum tests

1. verified top-up grants exact approved quantity
2. replayed purchase grants zero additional credits
3. concurrent verification grants once
4. wrong product rejected
5. client-supplied quantity ignored
6. client-supplied credit class ignored
7. cross-user token ownership rejected
8. included subscription allowance consumed first
9. compatible top-up consumed only after included allowance exhausted
10. top-up reservation commits exactly once
11. failed generation releases top-up reservation
12. duplicate operation does not double-consume
13. renewal preserves top-up balance
14. cancellation preserves stored top-up balance
15. expiration preserves stored balance but blocks generation
16. re-subscription restores eligibility without duplicating balance
17. Preview-only credit cannot gain Tutorial on plan upgrade
18. Tutorial-capable credit cannot bypass active Preview-only Tutorial denial
19. Salon Pilot admin adjustment remains separate
20. Free cannot self-buy/use paid top-up if policy forbids
21. provider acknowledgement/consumption retry safe
22. provider failure after grant cannot double-grant
23. no raw provider token leaked
24. RLS prevents client credit mutation
25. normal user cannot self-grant top-up
26. existing subscription Restore unaffected
27. paid renewal unaffected
28. locked 3/30/8/80/35/350 matrix unchanged
29. Final Preview model unchanged
30. Tutorial V4 unchanged

## Do NOT implement

- wallet/coin economy
- dynamic metered billing
- arbitrary user-entered top-up quantity
- admin top-up UI
- promotional/free credit campaigns
- referral credits
- annual subscriptions
- external Stripe checkout for in-app digital functionality
- model downgrade
- unrelated SUB-14 refactors

## Acceptance gate

SUB-13B = PASS only if:

- provider-verified credit grant is exactly once
- purchased credits are provenance-safe and separate from admin adjustments
- plan capability cannot be escalated by credits
- monthly renewal cannot erase purchased credits
- expiration cannot consume them but preserves them
- reserve/commit/release is source-aware
- store/security/idempotency tests pass
- locked subscription matrix unchanged
- V4/model locks unchanged

## Completion report

Use the standard report plus:

```text
SUB-13B RESULT:
PASS / FAIL

APPROVED TOP-UP MATRIX
Tutorial pack:
Preview-only pack:

PROVIDER
Products:
Verification mechanism:
Grant order:
Acknowledge/consume behavior:

LEDGER
Purchased-credit representation:
Capability class representation:
Consumption order:
Period-reset isolation:

SECURITY
Replay grant:
PASS / FAIL
Cross-user protection:
PASS / FAIL
Client self-grant:
YES / NO

PLAN CHANGE SAFETY
Preview credit becomes Tutorial-capable:
YES / NO
Tutorial credit bypasses Preview-only plan:
YES / NO

REGRESSION
Locked 3/30/8/80/35/350 matrix:
PASS / FAIL
SUB-10 impact:
SUB-11 impact:
SUB-12/12B impact:

TESTS
Automated tests:
flutter analyze:
Diff audit:
Production/Play mutations:

NEXT PHASE AUTHORIZED:
NO
```

Then STOP.

Do not begin SUB-14 automatically.
# SUB-14 — FULL SECURITY, REGRESSION & EDGE-CASE HARDENING

Read all current authorities, prior completion reports, and `00_FACETUNE_SUBSCRIPTION_OFFER_MATRIX_LOCKED.md` before changing anything.

Implement ONLY SUB-14.

## Active roles

- Principal Software Engineer
- Senior Application Security Engineer
- Senior RLS Engineer
- Senior Idempotency / Concurrency Engineer
- Senior Subscription Systems Engineer
- Senior Google Play Billing Engineer
- Senior Commerce / Ledger Engineer
- Senior Reliability Engineer
- Senior QA / Regression Engineer
- Senior Integration Test Engineer
- Senior Production Debugging Engineer
- Senior Code Reviewer

## Starting gate

Begin only after explicitly accepted:

- SUB-12 PASS
- SUB-12B PASS
- SUB-13 PASS
- SUB-13B PASS

Use accepted completion commits as baseline.

## Global hard locks

Preserve:

- Final Preview model `gemini-3.1-flash-image`
- fail-closed Final Preview validation
- Tutorial V4
- `tutorial_guideline_v4_7`
- `tutorial_manifest_v4_1`
- Standard Mode
- My Makeup Kit
- reserve → generate → persist → commit
- reservation-time attribution
- SUB-10 / SUB-11 provider authority
- Free / Salon Pilot semantics
- locked 3/30/8/80/35/350 matrix
- approved top-up commercial matrix from SUB-13B
- RLS / server-side entitlement authority

Do not revert/stage/commit unrelated user-owned prompt-file changes.
No destructive Git operations.

## Objective

Prove the COMPLETE FaceTune monetization system is resilient across:

- Free
- Plus
- Plus Preview
- Pro
- Pro Preview
- Salon Pilot
- Salon Pro
- Salon Preview
- purchased top-ups
- billing lifecycle
- AI Look / Final Preview accounting
- capability authorization
- RLS/security
- concurrency
- provider retries
- historical content preservation

This is primarily hardening/testing, not permission for broad redesign.

## Required automated / controlled scenarios

### Free

- 1 lifetime allowance
- first success commits one
- exhausted remains exhausted
- month/year change no reset
- login/reinstall no reset
- paid purchase/renewal/expiry/restore does not recreate Free

### Plus — Tutorial

- 3/3
- 2/3
- 1/3
- 0/3
- new verified period resets included allowance to 3
- Tutorial allowed
- Tutorial consumes no additional user-facing credit

### Plus Preview

- 30/30
- 29/30
- exhaustion arithmetic
- new verified period resets included allowance to 30
- Tutorial denied server-side
- historical Tutorial remains readable
- no model/prompt downgrade

### Pro — Tutorial

- 8/8
- exhaustion
- new period
- Tutorial allowed

### Pro Preview

- 80/80
- exhaustion arithmetic
- new period
- Tutorial denied

### Salon Pro — Tutorial

- 35/35
- high-volume sequential accounting
- exhaustion arithmetic
- new period
- Tutorial allowed

### Salon Preview

- 350/350
- high-volume arithmetic through automated tests
- do NOT live-generate 350 merely to prove integer math
- new period
- Tutorial denied

### Salon Pilot

- 30 initial
- no automatic reset
- expiration
- suspension/revocation if supported
- admin adjustment compatibility
- non-public behavior
- no Google Play creation

### Plan transitions

Where actual provider configuration supports them:

- Plus → Plus Preview
- Plus Preview → Plus
- Pro → Pro Preview
- Pro Preview → Pro
- Salon Pro → Salon Preview
- Salon Preview → Salon Pro
- provider-authoritative capability change
- historical Preview preserved
- historical Tutorial preserved
- no duplicate entitlement
- no double allowance grant
- no client-forged transition

Do not invent unsupported Google Play transition behavior.

### AI Look / Final Preview accounting

- success commits once
- generation failure releases
- persistence failure releases when no usable result exists
- duplicate operation no double-charge
- duplicate commit safe
- duplicate release safe
- reopen existing Preview consumes zero
- Tutorial reopen consumes zero
- History open consumes zero
- Saved Looks open consumes zero
- Preview-only operation consumes one Preview credit
- Tutorial-enabled operation consumes one AI Look, not an additional Tutorial credit

### Top-ups

Using the approved SUB-13B matrix:

- provider-verified grant exact quantity
- replay safe
- concurrent verification safe
- included allowance consumed before compatible top-up
- source-aware reserve/commit/release
- renewal preserves top-up balance
- cancellation preserves top-up balance
- expiration preserves balance but blocks consumption
- re-subscription restores eligibility without duplicate credits
- Preview-only credits never become Tutorial-capable
- Tutorial-capable credits cannot bypass Preview-only active-plan denial
- wrong product rejected
- cross-user token rejected
- client cannot mutate purchased balance
- Salon Pilot admin adjustment remains distinct

### Concurrency

- one included credit remaining + two simultaneous requests
- one top-up credit remaining + two simultaneous requests
- multiple devices
- network retry
- duplicate operation ID
- client timeout while server succeeds
- client timeout while server fails
- renewal during reservation
- expiration boundary during reservation
- plan transition around reservation
- stale reservation recovery
- late provider event
- duplicate provider event

### Provider — subscriptions

- valid purchase
- invalid token/evidence
- wrong product
- duplicate verification
- cancelled but paid-through
- renewal
- expiration
- current supported grace semantics
- refund/revocation
- Restore
- duplicate lifecycle event
- Preview product mapping
- client plan spoof ignored

### Provider — top-up

- valid one-time/repeatable purchase
- invalid evidence
- duplicate/replay
- acknowledge/consume retry
- grant committed but provider follow-up fails
- cross-user ownership
- wrong product
- wrong credit class
- client quantity spoof ignored

### Security

- user cannot grant own entitlement
- user cannot grant Salon Pilot
- user cannot edit own usage ledger
- user cannot edit purchased-credit ledger
- user cannot edit admin adjustment
- user cannot read another user's entitlement
- user cannot read another user's usage
- user cannot read another user's purchased credits
- cross-user Preview association rejected
- RLS enabled
- JWT bypass absent
- service-role key absent from Flutter/browser
- provider secrets absent from client
- Gemini key absent from Flutter
- no special pilot email/UID
- no hidden test bypass
- no client Tutorial-capability flag treated as authority

### Protected FaceTune regression

- Standard Mode works
- My Makeup Kit works
- Final Preview renderer/model remains `gemini-3.1-flash-image`
- Final Preview prompt architecture unchanged
- Tutorial V4 opens for entitled plans
- Tutorial denied for Preview-only new generation
- historical Tutorial reopen works
- `tutorial_guideline_v4_7` preserved
- `tutorial_manifest_v4_1` preserved
- History works
- Saved Looks works
- existing Preview reopens
- no Gemini call moved into Flutter
- no build-triggered paid AI work
- accepted navigation/loading stable

### Flutter / UX

- loading
- offline/error
- current plan
- current capability
- included remaining
- top-up remaining
- low allowance
- zero allowance
- reset date only for period-reset plans
- Free shows no fake reset date
- Salon Pilot shows expiration semantics
- Preview-only clearly says no Tutorial
- paywall lists 3/30/8/80/35/350 correctly
- Restore feedback works
- top-up purchase state clear
- no layout overflow

## Static / security review

Search for:

- hardcoded `isPremium`
- hardcoded plan/allowance duplication
- hidden test bypasses
- hardcoded pilot emails
- direct privileged Supabase writes from client
- logs with secrets/tokens
- stale provider assumptions
- duplicated billing listeners
- race-prone decrement logic
- generic mutable `extra credits` bucket with lost provenance
- Tutorial authorization based only on client/UI
- cost assumptions used as runtime entitlement logic

## Fix policy

Fix only defects proven by this hardening scope.

Do not redesign unrelated UI/AI systems.

Any change to locked model/Tutorial architecture requires explicit approval.

## Acceptance gate

SUB-14 = PASS only if:

- critical matrix/edge cases have explicit evidence
- no known high-severity entitlement or purchased-credit defect remains
- provider authority holds
- capability enforcement holds server-side
- purchased-credit provenance/idempotency holds
- protected FaceTune regressions are green or documented pre-existing/unrelated
- no locked commercial value changed

## Completion report

Use the standard report plus:

```text
SUB-14 RESULT:
PASS / FAIL

PLAN MATRIX
Free:
Plus:
Plus Preview:
Pro:
Pro Preview:
Salon Pilot:
Salon Pro:
Salon Preview:

TOP-UP HARDENING:
PASS / FAIL

CAPABILITY SECURITY:
PASS / FAIL

PROVIDER SUBSCRIPTION:
PASS / FAIL

PROVIDER TOP-UP:
PASS / FAIL

RLS / SECURITY:
PASS / FAIL

CONCURRENCY:
PASS / FAIL

PROTECTED V4 REGRESSION:
PASS / FAIL

FINAL PREVIEW MODEL:
gemini-3.1-flash-image / CHANGED

AUTOMATED TESTS:
<passed>/<failed>

CONTROLLED TESTS:
<summary>

OUTSTANDING DEFECTS:
<list>

NEXT PHASE AUTHORIZED:
NO
```

Then STOP.

Do not begin SUB-15 automatically.
# SUB-15 — REAL DEVICE, GOOGLE PLAY SANDBOX & PRODUCTION-READINESS QA

Read all current authorities, every prior completion report, and `00_FACETUNE_SUBSCRIPTION_OFFER_MATRIX_LOCKED.md` before changing anything.

Implement ONLY SUB-15.

This is FINAL Subscription V1 acceptance.

## Active roles

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

## Starting gate

Begin only after an explicitly accepted SUB-14 PASS.

SUB-15 is acceptance, not a feature-development phase.

## Global hard locks

Preserve:

- `gemini-3.1-flash-image`
- fail-closed Final Preview validation
- Tutorial V4
- `tutorial_guideline_v4_7`
- `tutorial_manifest_v4_1`
- Standard Mode
- My Makeup Kit
- reserve → generate → persist → commit
- SUB-10 / SUB-11 provider authority
- Free / Salon Pilot semantics
- locked 3/30/8/80/35/350 subscription matrix
- approved top-up matrix from SUB-13B
- RLS / server-side entitlement authority

Do not use this phase to add new features.
Do not revert/stage/commit unrelated user-owned prompt-file changes.
No destructive Git operations.

## Objective

Validate the complete locked monetization system using:

- real-device evidence
- approved live backend
- Google Play test/sandbox evidence
- production-like release configuration
- minimal-cost controlled operations

Do not begin Web Admin here.

## Before validation

- verify branch / working tree
- inspect all prior completion reports
- inspect current diff
- confirm no unreviewed unrelated changes
- verify Supabase environment
- verify Google Play test/internal track
- verify approved subscription products/base plans
- verify approved top-up products
- verify provider docs/config
- verify release signing
- verify no production secret bundled in client
- verify locked offer matrix authority
- verify model/Tutorial locks

## Primary device

```text
POCO X3 GT
```

Use release/profile-like execution where debug overhead would distort results.

## Required end-to-end journeys

### A. Free

```text
eligible Free account
→ exactly 1 lifetime AI Look
→ successful Final Preview
→ 0 remaining
→ reopen Preview allowed
→ current approved Free Tutorial behavior preserved
→ History allowed
→ Saved Looks allowed
→ new Final Preview blocked/paywall
→ logout/login does not reset
```

### B. Plus — ₱399 / 3 / Tutorial YES

```text
approved Google Play test purchase
→ server verify
→ Plus active
→ 3 AI Looks
→ one controlled successful generation
→ 2 remaining
→ Tutorial allowed with no extra user-facing charge
```

### C. Plus Preview — ₱399 / 30 / Tutorial NO

```text
approved Preview product purchase
→ server verify
→ Plus Preview active
→ 30 Final Preview credits
→ one generation
→ 29 remaining
→ new Tutorial generation denied server-side
→ historical Tutorial reopen remains safe
```

Do not live-exhaust 30 if automated quota tests already prove arithmetic.

### D. Pro — ₱899 / 8 / Tutorial YES

Verify active Pro, 8 allowance, capability, and one controlled accounting operation if needed.

### E. Pro Preview — ₱899 / 80 / Tutorial NO

Verify 80 allowance, one controlled generation, Tutorial denial.
Do not live-exhaust 80.

### F. Salon Pro — ₱2,999 / 35 / Tutorial YES

Verify 35 allowance and capability.
Do not exhaust 35 live merely to prove arithmetic.

### G. Salon Preview — ₱2,999 / 350 / Tutorial NO

Verify 350 allowance and Preview-only capability.
Do not generate hundreds of live requests.
Use automated arithmetic plus minimal live-safe evidence.

### H. Salon Pilot

Without Web Admin:

```text
salon_pilot
30 initial
non-public
no automatic reset
authoritative expiration
admin-adjustment-compatible backend
```

Use approved server/test fixture only.
Do not ship a hidden production grant bypass.

### I. Failure handling

Prove with controlled fake plus live-safe evidence:

```text
failure before usable persisted Final Preview
→ reservation released
→ no user-facing included/top-up credit consumed
```

### J. Duplicate / retry

Prove duplicate logical request does not double-charge included or purchased credits.

### K. Cancellation / expiration

For representative Tutorial and Preview subscription families:

- cancelled but verified-valid period remains entitled
- expiration blocks new Final Preview
- Preview-only remains no-Tutorial
- History/Saved/Preview/Tutorial history preserved

Do not redundantly repeat every SUB-11 proof if provider equivalence + automated tests already establish identical lifecycle behavior.
Collect enough real evidence to validate new mappings.

### L. Restore

- valid subscription restore/reconciliation
- Preview-product restore
- duplicate restore safe
- Restore UI feedback remains functional
- no extra allowance

### M. Top-up

Using approved SUB-13B products:

- purchase one minimal Tutorial-capable top-up pack on eligible Tutorial plan
- server verifies/grants exact quantity
- no duplicate grant
- included allowance consumed first where practical to validate without waste
- purchase one minimal Preview-only pack on eligible Preview plan if required by acceptance evidence
- Preview top-up does not grant Tutorial
- balance persists through refresh/relogin
- do not generate large volumes merely to prove arithmetic

If sandbox/provider limitations make both live top-up classes unnecessarily costly, use one live provider proof plus automated evidence for the second class and document the limitation.

### N. Plan capability transitions

Where approved Play configuration supports them:

- Tutorial plan → Preview plan
- Preview plan → Tutorial plan
- server capability changes only from verified provider state
- historical content preserved
- top-up capability does not escalate

Do not invent unsupported transitions.

## Performance / UX checks

On POCO X3 GT:

- Plans opens smoothly
- all six paid offers render correctly
- no repeated provider-query loops
- no duplicate listeners
- Final Preview loading accepted
- quota updates after commit
- Tutorial denial on Preview-only is clear
- top-up balance display clear
- Restore progress/result clear
- no layout overflow
- Profile smooth
- Saved/History accepted

## Security release checks

Verify:

- no service-role key in APK/client
- no provider private credential in APK
- no Gemini key in Flutter
- RLS enabled
- server functions auth-protected as designed
- normal user cannot mutate entitlement/usage/purchased-credit ledger
- logs sanitized
- test-only bypasses removed/disabled
- no hardcoded pilot identity
- no client capability authority
- no cost assumption controls entitlement

## Release / configuration checks

Verify:

- package id
- versionName/versionCode
- signing path
- Supabase project
- Google Play product IDs
- prices shown from approved configuration/provider
- offer matrix matches locked authority
- release build contains intended commits
- no unrelated dirty changes
- no development-only bypass
- migrations/functions deployed exactly as approved
- top-up product setup matches approved commercial matrix

## Final acceptance report

Use the standard report plus:

```text
SUBSCRIPTION V1 FINAL STATUS:
PASS / FAIL / CONDITIONAL

FREE JOURNEY:

PLUS JOURNEY:
₱399 / 3 / Tutorial YES

PLUS PREVIEW JOURNEY:
₱399 / 30 / Tutorial NO

PRO JOURNEY:
₱899 / 8 / Tutorial YES

PRO PREVIEW JOURNEY:
₱899 / 80 / Tutorial NO

SALON PRO JOURNEY:
₱2,999 / 35 / Tutorial YES

SALON PREVIEW JOURNEY:
₱2,999 / 350 / Tutorial NO

SALON PILOT BACKEND COMPATIBILITY:

TOP-UP JOURNEY:

GOOGLE PLAY SANDBOX EVIDENCE:

AI LOOK / FINAL PREVIEW ACCOUNTING:

FAILURE / RELEASE EVIDENCE:

DUPLICATE / IDEMPOTENCY EVIDENCE:

LIFECYCLE / RESTORE EVIDENCE:

CAPABILITY / TUTORIAL EVIDENCE:

PROTECTED V4 REGRESSION:

FINAL PREVIEW MODEL:

REAL DEVICE EVIDENCE:

SECURITY EVIDENCE:

OUTSTANDING BLOCKERS:

PRODUCTION MANUAL ACTIONS:

READY TO BEGIN FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md:
YES / NO
```

## Done when

- complete locked subscription matrix is demonstrably stable
- Preview-only capability is server-enforced
- top-up ledger/provider behavior is stable
- outstanding provider/manual actions are explicit
- no Web Admin code started
- no new feature work hidden in acceptance

Then STOP.

Do not begin `FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md` automatically.
# UPDATED SUBSCRIPTION PHASE COMPLETION FLOW

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
SUB-12B Capability-Aware Paid Offer Expansion
       Plus Preview 30
       Pro Preview 80
       Salon Preview 350
 ↓
Review / PASS
 ↓
SUB-13 Telemetry / Cost / Unit Economics
 ↓
Review / PASS
 ↓
TOP-UP COMMERCIAL HUMAN APPROVAL GATE
 ↓
SUB-13B Purchased Top-Up Credits
 ↓
Review / PASS
 ↓
SUB-14 Full Security + Regression Hardening
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

Testing occurs after every phase.

Completion of a phase never authorizes the next phase automatically.

# UPDATED OUT-OF-SCOPE AFTER ROADMAP CHANGE

The following remain out of scope unless a later approved authority explicitly changes them:

- Web Admin UI during SUB-12 through SUB-15 except compatibility contracts
- annual subscriptions
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
- lifetime paid plans
- unlimited AI
- dynamic usage billing
- enterprise billing
- external Stripe checkout for in-app digital functionality
- wallet/coin economy
- rollover
- model downgrade by plan
- ad-supported quota replenishment
- arbitrary/unapproved top-up products beyond the SUB-13B approved matrix

IMPORTANT CHANGE:

`AI Look add-on packs` are no longer globally out of scope.
Purchased top-ups are explicitly owned by SUB-13B and must follow its provider/ledger/capability rules.

# UPDATED FINAL NON-NEGOTIABLE CHECKLIST

```text
[ ] Free = 1 lifetime AI Look; never automatically resets

[ ] Plus = ₱399 / 3 AI Looks / verified billing period / Tutorial YES

[ ] Plus Preview = ₱399 / 30 Final Preview credits / verified billing period / Tutorial NO

[ ] Pro = ₱899 / 8 AI Looks / verified billing period / Tutorial YES

[ ] Pro Preview = ₱899 / 80 Final Preview credits / verified billing period / Tutorial NO

[ ] Salon Pro = ₱2,999 / 35 AI Looks / verified billing period / Tutorial YES

[ ] Salon Preview = ₱2,999 / 350 Final Preview credits / verified billing period / Tutorial NO

[ ] Salon Pilot = 30 initial, admin-adjustable later, no automatic reset, non-public

[ ] No rollover

[ ] Tutorial-enabled AI Look = one authorized new Final Preview; Tutorial consumes 0 additional user-facing allowance

[ ] Preview-only credit = one authorized new Final Preview; new Tutorial generation denied server-side

[ ] Historical Tutorial content preserved across plan changes

[ ] Reopening existing Preview consumes 0

[ ] History/Saved reopen consumes 0

[ ] Technical failure without usable persisted Preview consumes 0

[ ] Reserve / Commit / Release server-authoritative

[ ] Duplicate operation cannot double-charge

[ ] Concurrent last-credit requests cannot oversubscribe

[ ] Flutter cannot self-grant premium/capability

[ ] Google Play subscription purchase verified server-side

[ ] Client plan/price/allowance is not purchase authority

[ ] Cancellation != immediate expiration while verified paid period remains

[ ] Renewal grants exactly one new period allowance and preserves old history

[ ] Restore provider-authoritative and idempotent

[ ] Expiration blocks new generation but preserves historical content

[ ] Preview-only plan cannot create new Tutorial

[ ] Final Preview model remains gemini-3.1-flash-image

[ ] Tutorial V4 remains locked

[ ] tutorial_guideline_v4_7 preserved

[ ] tutorial_manifest_v4_1 preserved

[ ] Standard Mode preserved

[ ] My Makeup Kit preserved

[ ] Purchased top-ups separate from subscription allowance and admin adjustments

[ ] Top-up purchase verification server-authoritative

[ ] Top-up replay cannot duplicate credits

[ ] Purchased credits do not reset on subscription renewal

[ ] Expired subscription preserves stored top-up credits but blocks consumption until eligible paid entitlement active

[ ] Preview-only purchased credit can never escalate to Tutorial capability

[ ] Subscription allowance consumed before compatible purchased credits

[ ] RLS remains enabled

[ ] Normal user cannot edit entitlement / usage / admin adjustment / purchased-credit ledger

[ ] Service-role key absent from Flutter/browser

[ ] Google provider private credentials absent from Flutter/browser

[ ] Gemini key absent from Flutter

[ ] No hidden production admin/test bypass

[ ] No build-triggered paid AI work

[ ] ₱45 and ₱4 cost assumptions are not runtime entitlement logic

[ ] Locked prices/allowances were not automatically changed by telemetry

[ ] SUB-15 final acceptance completed

[ ] No Web Admin implementation started automatically
```

# FINAL STOP RULE

At the end of every phase:

```text
REPORT
↓
STOP
↓
WAIT FOR EXPLICIT USER AUTHORIZATION
```

At the end of SUB-15:

```text
FINAL SUBSCRIPTION REPORT
↓
STOP
↓
WAIT FOR EXPLICIT USER AUTHORIZATION
```

Only after the user explicitly accepts the final Subscription result may work proceed to:

```text
FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md
```
