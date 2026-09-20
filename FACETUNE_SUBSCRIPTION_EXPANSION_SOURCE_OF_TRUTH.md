# FACETUNE SUBSCRIPTION EXPANSION SOURCE OF TRUTH

**Document:** `FACETUNE_SUBSCRIPTION_EXPANSION_SOURCE_OF_TRUTH.md`  
**Status:** LOCKED PRODUCT / ARCHITECTURE AUTHORITY  
**Effective Scope:** SUB-12 onward  
**Effective Date:** 2026-09-20  
**Project:** FaceTune — Your AI Makeup Artist  
**Platform:** Android / Flutter  
**Backend:** Supabase  
**Shared Contract:** `subscription_admin_contract_v1`

---

# 0. PURPOSE

This document is the authoritative post-SUB-11 expansion contract for FaceTune subscriptions.

It exists so completed SUB-0 through SUB-11 work can remain frozen as historical implementation evidence while FaceTune adds:

- Free entitlement finalization
- Salon Pilot non-store compatibility
- capability-aware paid subscription offers
- Preview-only paid subscription offers
- subscription telemetry and unit-economics measurement
- purchased top-up credits after a separate commercial approval gate
- complete security/regression hardening
- final real-device / Google Play / production-readiness acceptance

This document defines product and architecture truth.

It does **not** by itself authorize coding.

Implementation is authorized only by:

`FACETUNE_SUBSCRIPTION_PHASE_PROMPTS_SUB12_ONWARD.md`

one phase at a time.

---

# 1. SUPERSESSION / AUTHORITY RULE

## 1.1 Historical files remain frozen

The following existing files remain valid and must not be rewritten merely to make them appear as though the expansion offers existed during SUB-0 through SUB-11:

- `FACETUNE_SUBSCRIPTION_SOURCE_OF_TRUTH.md`
- `FACETUNE_SUBSCRIPTION_PHASE_PROMPTS.md`
- accepted SUB-0 through SUB-11 completion reports
- accepted migrations, code, tests, deployment evidence, provider evidence, and real-device evidence produced by those phases

SUB-0 through SUB-11 remain historical implementation evidence.

## 1.2 Explicit post-SUB-11 supersession

> **From SUB-12 onward, this document supersedes conflicting commercial plan, allowance, capability, Preview-plan, and future-top-up definitions in earlier Subscription documents. SUB-0 through SUB-11 remain authoritative for already-proven architecture and behavior except where this document explicitly extends the product matrix or post-SUB-11 product contract.**

This means older statements such as:

```text
Public plans = Free, Plus, Pro, Salon Pro
```

must not be interpreted as prohibiting the later approved Preview offers.

This document does **not** invalidate already-proven SUB-10/SUB-11 purchase-verification, lifecycle, RTDN, restore, provider-authority, or usage-integrity architecture.

## 1.3 Conflict resolution

When documents conflict:

1. Protected FaceTune / V4 AI authorities govern protected AI behavior.
2. This Expansion SOT governs post-SUB-11 plan offerings, allowances, capabilities, Preview-only semantics, and future top-up architecture.
3. The original Subscription SOT governs original subscription behavior that this document does not explicitly change.
4. `FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md` governs shared identifiers/admin compatibility unless an explicit compatible extension is required by this document.
5. Phase prompts govern implementation scope only.
6. Completion reports are evidence, not authority.
7. Actual code, migrations, provider responses, deployed state, and real-device evidence must be inspected rather than guessed.

If a conflict remains unresolved after applying the rules above:

> **STOP. Report the exact conflict. Do not invent a silent compromise.**

---

# 2. VALIDATED BASELINE THAT MUST REMAIN PRESERVED

Core SUB-11 is accepted as PASS.

Accepted finalization commit:

```text
96fc545beca3edf9dbc1ec9c83e4d61265eb4296
SUB-11 harden Google Play purchase restore flow
```

The following validated architecture is protected:

- Google Play purchase verification is server-authoritative
- verify → activate → acknowledge order
- RTDN is a trigger, not entitlement authority
- Google `SubscriptionPurchaseV2` provider state wins
- cancellation does not equal immediate expiration while verified paid-through time remains
- Restore Purchases is provider-authoritative and idempotent
- provider lifecycle reconciliation is deduplicated
- reservation-time attribution is authoritative for AI Look period usage
- reserve → generate → persist → commit remains the usage lifecycle
- failure without usable persisted Final Preview releases rather than commits
- duplicate logical operations cannot double-charge
- historical content survives expiration
- expired entitlement blocks new generation
- client does not grant entitlement authority
- RLS remains enabled

Do not casually redesign these systems in later phases.

---

# 3. LOCKED SUBSCRIPTION OFFER MATRIX

The following matrix is locked unless the user explicitly changes this Source of Truth.

| Offer | Price | Included allowance | New Tutorial generation |
|---|---:|---:|---|
| Free | ₱0 | 1 lifetime AI Look | Preserve currently approved Free behavior |
| Plus | ₱399 / month | 3 AI Looks / verified billing period | YES |
| Plus Preview | ₱399 / month | 30 Final Preview Credits / verified billing period | NO |
| Pro | ₱899 / month | 8 AI Looks / verified billing period | YES |
| Pro Preview | ₱899 / month | 80 Final Preview Credits / verified billing period | NO |
| Salon Pro | ₱2,999 / month | 35 AI Looks / verified billing period | YES |
| Salon Preview | ₱2,999 / month | 350 Final Preview Credits / verified billing period | NO |
| Salon Pilot | Complimentary / admin-granted | 30 starting AI Looks; admin-adjustable | Preserve currently approved Salon Pilot behavior |

No rollover for recurring included subscription allowance.

The locked Preview allowances are:

```text
plus_preview  = 30 Final Preview Credits / verified billing period
pro_preview   = 80 Final Preview Credits / verified billing period
salon_preview = 350 Final Preview Credits / verified billing period
```

SUB-13 may measure economics and report variance.

SUB-13 must **not** automatically alter the locked 30 / 80 / 350 allowances.

Changing this matrix requires explicit user authorization.

---

# 4. CANONICAL INTERNAL PLAN CODES

Canonical plan codes from SUB-12 onward:

```text
free
plus
plus_preview
pro
pro_preview
salon_pro
salon_preview
salon_pilot
```

Do not invent aliases such as:

```text
plus_no_tutorial
preview_plus
pro_no_tutorial
salon_preview_only
```

unless this Source of Truth is explicitly revised.

Plan identity must not be inferred from price.

Plus and Plus Preview intentionally have the same price.

Pro and Pro Preview intentionally have the same price.

Salon Pro and Salon Preview intentionally have the same price.

Capability and provider product identity, not price, distinguish them.

---

# 5. EXISTING GOOGLE PLAY PRODUCT IDS

The already-proven Google Play products remain:

```text
facetune_plus
facetune_pro
facetune_salon_pro
```

The target provider IDs for the new Preview offers are:

```text
facetune_plus_preview
facetune_pro_preview
facetune_salon_preview
```

These target IDs are the expected mapping for SUB-12B.

Before creating or depending on them, SUB-12B must verify current Google Play Console availability/configuration and current provider rules.

If an ID cannot be used for a documented provider reason:

> STOP and report the exact provider conflict before choosing a different production ID.

No Preview plan may reuse the Tutorial-enabled product ID merely because the retail price is the same.

---

# 6. TWO USER-FACING CONSUMPTION UNITS

The expansion introduces two distinct entitlement units.

## 6.1 AI Look

An **AI Look** is the existing Tutorial-capable allowance unit.

Hard rule:

> **1 AI Look = authorization for 1 new usable persisted Final Makeup Preview under the protected Final Preview flow.**

For Tutorial-enabled plans, the user's entitlement also permits the existing Tutorial workflow for that result according to the protected Tutorial V4 contract.

Tutorial does not consume a second user-facing AI Look.

Used by:

```text
free
plus
pro
salon_pro
salon_pilot
```

subject to the approved capability of each plan.

## 6.2 Final Preview Credit

A **Final Preview Credit** is a Preview-only allowance unit.

Hard rule:

> **1 Final Preview Credit = authorization for 1 new usable persisted Final Makeup Preview and does NOT authorize new Tutorial generation.**

Used by:

```text
plus_preview
pro_preview
salon_preview
```

## 6.3 Critical distinction

```text
AI Look
≠
Final Preview Credit
≠
Salon Pilot admin allowance adjustment
≠
Purchased top-up credit
```

These concepts may share safe infrastructure, but their provenance and capability semantics must remain distinguishable.

Do not collapse everything into an opaque mutable `remaining_looks` balance with no source/capability lineage.

---

# 7. PROTECTED FINAL PREVIEW ARCHITECTURE

Both AI Look and Final Preview Credit generation must use the same protected Final Preview generation architecture.

Locked:

```text
Final Preview model = gemini-3.1-flash-image
```

Also locked:

- fail-closed Final Preview validator
- current Final Preview prompt architecture
- current Final Preview persistence authority
- current Standard Mode
- current My Makeup Kit behavior
- current immutable selected-product snapshots
- current retry rules unless a separately approved fix is proven necessary
- server-side Gemini only
- no Gemini API key in Flutter

Preview-only plans are cheaper commercial/capability offers.

They are **not** permission to create a lower-quality or second Final Preview pipeline.

Do not:

- downgrade the model for Preview plans
- lower resolution by plan
- change prompts merely to hit a cost target
- move Gemini into Flutter
- create a second renderer
- weaken validation

---

# 8. PROTECTED TUTORIAL V4 CONTRACT

Locked:

```text
Tutorial V4
tutorial_guideline_v4_7
tutorial_manifest_v4_1
```

Existing Tutorial generation/rendering architecture remains protected.

## Tutorial-enabled plans

For an authorized Tutorial-capable AI Look:

```text
new Final Preview
↓
1 AI Look committed
↓
Tutorial may be generated/opened under existing V4 rules
↓
0 additional user-facing AI Looks
```

## Preview-only plans

For:

```text
plus_preview
pro_preview
salon_preview
```

new Tutorial generation must be denied server-side.

The client must not be the only enforcement layer.

Existing historical Tutorial content created while previously authorized remains preserved/readable under historical-content rules.

Changing to Preview-only must not delete old Tutorials.

---

# 9. UNIVERSAL USAGE TRANSACTION CONTRACT

The proven lifecycle remains:

```text
AUTHENTICATE
↓
RESOLVE ENTITLEMENT + CAPABILITY
↓
CHECK COMPATIBLE AVAILABLE CAPACITY
↓
RESERVE ONE COMPATIBLE UNIT
↓
GENERATE USING PROTECTED FINAL PREVIEW FLOW
↓
VALIDATE
↓
PERSIST USABLE CANONICAL FINAL PREVIEW
↓
COMMIT EXACTLY ONE RESERVED UNIT
```

Failure:

```text
RESERVED
↓
NO USABLE PERSISTED CANONICAL FINAL PREVIEW
↓
AUTHORITATIVE FAILURE CONFIRMED
↓
RELEASE
```

Hard lock:

> **No usable persisted Final Makeup Preview = no committed user-facing generation unit.**

Client timeout, navigation, app close, or network loss does not itself prove failure.

---

# 10. CAPABILITY-AWARE ENTITLEMENT CONTRACT

Plan behavior must not be implemented as scattered presentation conditionals.

The system must be capable of representing at least:

```text
plan_code
publicly_purchasable
billing/origin type
allowance unit type
base included allowance
reset policy
billing period / expiration semantics
tutorial_enabled
final_preview_enabled
auto_renew where meaningful
provider product mapping where meaningful
```

The exact schema may reuse existing fields or introduce the smallest compatible extension.

Avoid growing code such as:

```text
if plan == plus ...
else if plan == plus_preview ...
else if plan == pro ...
```

through every layer.

Plan codes identify products.

Capabilities authorize behavior.

Do not infer Tutorial capability merely from a substring in the plan code.

---

# 11. FREE CONTRACT

Locked:

```text
plan_code = free
price = ₱0
allowance = 1 lifetime AI Look
reset = never
rollover = not applicable
auto_renew = false
store purchase = none
RTDN lifecycle = none
```

The one complimentary allowance belongs to server-side FaceTune account identity.

It must survive:

- month changes
- year changes
- logout/login
- reinstall
- local-data deletion
- device replacement
- auth refresh
- paid subscription activation
- paid renewal
- paid cancellation
- paid expiration
- Restore Purchases
- re-subscription

None of those events may mint another lifetime Free allowance.

If existing approved Free Tutorial behavior is not explicit in current authority/code, SUB-12 must preserve current behavior rather than silently changing it.

---

# 12. PAID TUTORIAL-ENABLED CONTRACTS

## Plus

```text
plan_code = plus
price = ₱399/month
included allowance = 3 AI Looks / verified billing period
Tutorial = YES
rollover = NO
provider = Google Play
```

## Pro

```text
plan_code = pro
price = ₱899/month
included allowance = 8 AI Looks / verified billing period
Tutorial = YES
rollover = NO
provider = Google Play
```

## Salon Pro

```text
plan_code = salon_pro
price = ₱2,999/month
included allowance = 35 AI Looks / verified billing period
Tutorial = YES
rollover = NO
provider = Google Play
client-session quota = NONE
```

Renewal provides the new verified period's included allowance.

Historical usage is preserved.

No rollover.

---

# 13. PAID PREVIEW-ONLY CONTRACTS

## Plus Preview

```text
plan_code = plus_preview
price = ₱399/month
included allowance = 30 Final Preview Credits / verified billing period
Tutorial = NO
rollover = NO
provider = Google Play
target provider product = facetune_plus_preview
```

## Pro Preview

```text
plan_code = pro_preview
price = ₱899/month
included allowance = 80 Final Preview Credits / verified billing period
Tutorial = NO
rollover = NO
provider = Google Play
target provider product = facetune_pro_preview
```

## Salon Preview

```text
plan_code = salon_preview
price = ₱2,999/month
included allowance = 350 Final Preview Credits / verified billing period
Tutorial = NO
rollover = NO
provider = Google Play
target provider product = facetune_salon_preview
```

A new verified period receives the plan's included Preview allowance.

Historical usage is preserved.

No rollover.

New Tutorial generation is denied.

---

# 14. SALON PILOT CONTRACT

Locked:

```text
plan_code = salon_pilot
origin = admin_granted / approved non-store equivalent
publicly_purchasable = false
starting base allowance = 30 AI Looks
admin-adjustable = true
auto_renew = false
automatic reset = none
expiration = required / admin-controlled
Google Play product = none
RTDN lifecycle = none
unlimited = false
```

Salon Pilot exists to support controlled research/pilot access.

It is not a consumer Google Play product.

It is not a hidden special-email entitlement.

It is not client-grantable.

## Effective allowance

Conceptually:

```text
base_allowance
+
audited_admin_adjustments
-
committed_usage
-
active_reserved_usage
=
available_capacity
```

Example:

```text
base = 30
committed = 18
admin adjustment = +10
reserved = 0

effective allowance = 40
remaining = 22
```

Admin adjustments must remain distinguishable from future purchased credits.

Expiration/suspension/revocation beats remaining allowance.

---

# 15. ENTITLEMENT STATUS / EXPIRATION AUTHORITY

Server/provider time is authoritative.

Client device clock is not billing authority.

New generation must be blocked when the applicable entitlement is:

- expired
- suspended
- revoked
- otherwise not generation-authorized under the verified provider/admin state

For Google Play subscriptions, provider-authoritative SUB-11 rules continue to apply.

For Salon Pilot, admin-controlled expiration/status applies through the Shared Contract.

Historical content remains preserved after loss of new-generation authorization.

---

# 16. ENTITLEMENT COEXISTENCE / PRECEDENCE

The system may contain historical Free and paid entitlements for the same account.

The resolver must choose the currently effective entitlement/capability deterministically.

Required principles:

- active valid paid entitlement must not be displaced by historical Free state
- paid activity must not recreate Free allowance
- paid expiration must not regenerate Free
- Free usage history remains preserved
- historical paid entitlements remain historical
- Preview-only capability must not accidentally inherit Tutorial authorization from stale/historical entitlement state
- top-up balances, once implemented, do not themselves become a subscription entitlement

If current architecture cannot express deterministic precedence safely:

> STOP and report the exact compatibility gap before inventing precedence.

---

# 17. PUBLIC PURCHASE / PROVIDER AUTHORITY

Public Google Play purchase verification may create/update only plans mapped from server-owned approved provider product IDs.

The client may not choose arbitrary internal plan codes.

Submitting:

```text
plan_code = salon_pilot
```

or:

```text
plan_code = free
```

must never make Google Play verification create those non-store entitlements.

Same-price offers remain distinct provider products.

Provider purchase identity determines the mapped plan.

Client price text does not.

---

# 18. TOP-UP ARCHITECTURE — LOCKED PRINCIPLES

Purchased top-ups are owned by SUB-13B and later validation phases.

They are **not** implemented by SUB-12, SUB-12B, or SUB-13.

Locked architecture:

- purchased top-up credits are separate from subscription included allowance
- purchased top-up credits are separate from Salon Pilot admin adjustments
- every purchased credit has auditable provider/provenance identity
- purchase verification is server-authoritative
- duplicate/replayed provider evidence cannot mint duplicate credits
- subscription included allowance is consumed before compatible purchased credits
- purchased credits do not automatically reset on subscription renewal
- purchased-credit history is preserved
- cancellation/expiration does not silently delete stored purchased credits
- consuming purchased credits requires an active eligible paid entitlement unless a later explicit authority changes this
- Free does not gain top-up purchase eligibility automatically
- Salon Pilot does not gain consumer top-up eligibility automatically
- top-ups add quantity, not subscription status
- top-ups do not independently grant a paid plan
- top-ups cannot escalate capability beyond the approved purchased-credit contract
- client cannot grant/increment purchased credits

## 18.1 Capability provenance

A purchased credit must retain sufficient capability/provenance information so future plan changes cannot convert a cheaper credit into a more expensive capability without explicit authority.

Do not implement an opaque universal credit if doing so would allow Preview-only purchased value to become Tutorial-capable accidentally.

The exact commercial top-up product matrix is intentionally gated until SUB-13 evidence and explicit user approval.

---

# 19. TOP-UP COMMERCIAL HUMAN APPROVAL GATE

Top-up architecture is locked.

Top-up **price and pack quantity are not yet production-locked**.

Current planning candidates only:

```text
Tutorial-capable candidate:
₱149 → +1 Tutorial-capable AI Look credit

Preview-only candidate:
₱149 → +10 Preview-only Final Preview Credits
```

These are not production authority.

SUB-13 must measure actual unit economics.

Before SUB-13B creates production/provider products, the user must explicitly approve the commercial matrix.

If no approved top-up matrix has been written into this SOT or an explicitly accepted amendment:

> **SUB-13B MUST STOP AT THE COMMERCIAL GATE.**

Do not infer approval from planning examples.

---

# 20. COST / TELEMETRY PLANNING ASSUMPTIONS

Current hypotheses:

```text
Tutorial-enabled successfully delivered AI Look ≈ ₱45 effective AI/API cost
Preview-only successfully delivered Final Preview ≈ ₱4 effective AI/API cost
```

These assumptions motivated the 30 / 80 / 350 Preview allowances.

They are not runtime billing truth.

They must not be hardcoded into:

- entitlement authorization
- allowance reset
- provider verification
- Flutter plan truth
- credit deduction
- plan capability

SUB-13 measures and reports actual economics.

The locked plan matrix remains unchanged unless the user explicitly revises it.

---

# 21. PRIVACY / OBSERVABILITY

Subscription telemetry may measure technical/business behavior but must not become a second private-user-content database.

Do not log for subscription analytics:

- image bytes
- base64 images
- signed private URLs
- JWTs
- service-role secrets
- provider private credentials
- full Google Play purchase tokens
- raw sensitive provider payloads
- private Gemini prompts
- raw My Makeup Kit user content merely for cost analysis

Prefer sanitized identifiers, operation categories, provider-result classes, plan/capability codes, timestamps, counts, and safe cost-attribution metadata.

---

# 22. SECURITY HARD LOCKS

Never:

- disable RLS
- bypass auth/JWT verification except where an already-approved provider-auth architecture explicitly requires function-level custom verification
- trust client user ID for ownership
- trust client plan code as purchase authority
- trust client remaining allowance
- let Flutter grant entitlement
- let Flutter mutate authoritative usage
- expose Supabase service-role secrets in Flutter/browser
- expose Google private credentials in Flutter/browser
- expose Gemini key in Flutter
- hardcode a Salon Pilot email
- hardcode a privileged user ID
- create a production hidden test grant bypass
- create unlimited Salon Pilot
- create automatic monthly Salon Pilot reset
- create automatic monthly Free reset
- create client-session billing
- create 3-previews-per-client Salon logic
- turn Preview-only plans into Tutorial access through UI-only checks

---

# 23. SHARED CONTRACT REQUIREMENT

`subscription_admin_contract_v1` remains the Shared Contract baseline.

SUB-12 and later phases must preserve or minimally extend compatibility for:

- plan code
- origin/billing provider
- public/non-public classification
- status
- base allowance
- effective allowance
- committed usage
- reserved usage
- available/remaining capacity
- period start/end
- starts_at/expires_at
- auto-renew where meaningful
- Tutorial capability
- Final Preview capability
- allowance unit/capability where needed
- admin adjustment semantics
- future purchased-credit summaries where later approved

Do not create parallel subscription truth just because the current contract needs a small extension.

Any extension must be:

- typed/controlled
- backward compatible where practical
- migration-safe
- tested
- documented

---

# 24. OUT OF SCOPE UNLESS LATER EXPLICITLY AUTHORIZED

- annual subscriptions
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
- multiple Salon Pro seats
- salon employee accounts
- salon branches
- salon CRM
- per-client subscription accounting
- client-session billing
- three-previews-per-client logic
- arbitrary top-up packs not explicitly approved after SUB-13

Web Admin UI is not implemented by the Subscription expansion phases.

Backend compatibility for later Web Admin remains required where explicitly stated.

---

# 25. IMPLEMENTATION ROADMAP AUTHORITY

```text
SUB-12
Free + Salon Pilot backend compatibility
↓
REVIEW / PASS
↓
SUB-12B
Capability-aware paid offer expansion:
Plus Preview / Pro Preview / Salon Preview
↓
REVIEW / PASS
↓
SUB-13
Telemetry / cost measurement / unit economics
↓
REVIEW / PASS
↓
TOP-UP COMMERCIAL HUMAN APPROVAL GATE
↓
SUB-13B
Purchased top-up credits
↓
REVIEW / PASS
↓
SUB-14
Full security / regression / edge-case hardening
↓
REVIEW / PASS
↓
SUB-15
Real-device / Google Play sandbox / production readiness
↓
FINAL SUBSCRIPTION ACCEPTANCE
↓
STOP
↓
Only after explicit user approval:
FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md
```

Completion of one phase never authorizes the next.

---

# 26. FINAL NON-NEGOTIABLE PRODUCT CHECKLIST

Before final Subscription acceptance, prove:

```text
[ ] Free = 1 lifetime AI Look; never automatically resets

[ ] Plus = ₱399 / 3 AI Looks / verified billing period / Tutorial YES

[ ] Plus Preview = ₱399 / 30 Final Preview Credits / verified billing period / Tutorial NO

[ ] Pro = ₱899 / 8 AI Looks / verified billing period / Tutorial YES

[ ] Pro Preview = ₱899 / 80 Final Preview Credits / verified billing period / Tutorial NO

[ ] Salon Pro = ₱2,999 / 35 AI Looks / verified billing period / Tutorial YES

[ ] Salon Preview = ₱2,999 / 350 Final Preview Credits / verified billing period / Tutorial NO

[ ] Salon Pilot = 30 initial AI Looks, admin-adjustable, no auto-reset, required admin-controlled expiration, non-public

[ ] No recurring-plan rollover

[ ] Tutorial-enabled AI Look commits exactly once per new usable persisted Final Preview

[ ] Tutorial consumes zero additional user-facing AI Looks

[ ] Preview-only credit commits exactly once per new usable persisted Final Preview

[ ] Preview-only plan cannot create new Tutorial server-side

[ ] Historical Tutorial/Preview/History/Saved content remains preserved

[ ] Reserve / Generate / Persist / Commit remains server-authoritative

[ ] Technical failure without usable persisted Final Preview consumes zero

[ ] Duplicate operation cannot double-charge

[ ] Concurrent last-unit requests cannot oversubscribe

[ ] Final Preview model remains gemini-3.1-flash-image

[ ] Tutorial V4 remains protected

[ ] tutorial_guideline_v4_7 preserved

[ ] tutorial_manifest_v4_1 preserved

[ ] Standard Mode preserved

[ ] My Makeup Kit preserved

[ ] Google Play purchase verification remains provider-authoritative

[ ] RTDN remains trigger-only

[ ] Restore remains idempotent/provider-authoritative

[ ] Client price/plan is not purchase authority

[ ] Free/Salon Pilot cannot be created by public Google Play purchase verification

[ ] RLS remains enabled

[ ] Normal client cannot self-grant entitlement or usage

[ ] Purchased top-ups, once approved, are separate from subscription allowance/admin adjustments

[ ] Top-up replay cannot duplicate credits

[ ] Purchased credits do not silently reset on renewal

[ ] Capability provenance prevents top-up capability arbitrage

[ ] ₱45 and ₱4 assumptions are not runtime entitlement truth

[ ] Telemetry does not automatically mutate the locked plan matrix

[ ] No hidden production admin/test bypass

[ ] SUB-15 acceptance completed

[ ] No Web Admin implementation started automatically
```

---

# 27. FINAL STOP RULE

At every implementation phase:

```text
IMPLEMENT CURRENT PHASE
↓
VALIDATE
↓
REPORT
↓
STOP
↓
WAIT FOR EXPLICIT USER AUTHORIZATION
```

No phase completion implies permission to begin another phase.
