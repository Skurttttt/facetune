# FACETUNE SUBSCRIPTION PHASE PROMPTS — SUB-12 ONWARD

**Document:** `FACETUNE_SUBSCRIPTION_PHASE_PROMPTS_SUB12_ONWARD.md`  
**Status:** IMPLEMENTATION AUTHORITY — ONE PHASE AT A TIME  
**Effective Scope:** SUB-12 through SUB-15  
**Project:** FaceTune — Your AI Makeup Artist  
**Primary Platform:** Android  
**Primary Test Device:** POCO X3 GT  
**Framework:** Flutter / Dart  
**Backend:** Supabase  
**State Management:** Riverpod  
**Architecture:** Clean Architecture + Repository Pattern + Feature-First  
**Shared Contract:** `subscription_admin_contract_v1`

---

# 0. PURPOSE

This file contains the only authorized implementation prompts for FaceTune Subscription work beginning with SUB-12.

The old:

`FACETUNE_SUBSCRIPTION_PHASE_PROMPTS.md`

is frozen as the historical phase record for SUB-0 through SUB-11.

Do not rewrite completed SUB-0 through SUB-11 prompts merely because later product requirements expanded.

This file implements the post-SUB-11 roadmap defined by:

`FACETUNE_SUBSCRIPTION_EXPANSION_SOURCE_OF_TRUTH.md`

Run exactly one phase at a time.

Never ask the coding agent to implement this entire file in one run.

---

# 1. MANDATORY AUTHORITY ORDER

Before every phase, read/inspect the relevant authorities in this order:

```text
1. CODEX_MASTER_GUIDE.md

2. Current approved FaceTune / V4 authority files
   relevant to Final Preview, Tutorial, My Makeup Kit,
   Standard Mode, model/prompt/configuration, validation,
   persistence, retry, History, Saved Looks

3. FACETUNE_SUBSCRIPTION_SOURCE_OF_TRUTH.md

4. FACETUNE_SUBSCRIPTION_EXPANSION_SOURCE_OF_TRUTH.md

5. FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md

6. Accepted SUB-0 through SUB-11 completion reports/evidence
   relevant to the current work

7. FACETUNE_SUBSCRIPTION_PHASE_PROMPTS_SUB12_ONWARD.md

8. Actual repository source, migrations, tests, policies,
   Supabase deployment state, provider/store state,
   logs/evidence, and real-device behavior relevant to the phase
```

Authority rule:

> Where the original Subscription SOT and the Expansion SOT conflict specifically on post-SUB-11 plan offerings, allowances, Preview capabilities, or future top-up architecture, the Expansion SOT governs from SUB-12 onward.

This does not invalidate already-proven SUB-0 through SUB-11 architecture.

If the remaining authorities cannot be reconciled safely:

> **STOP. Report the exact conflict. Do not invent a compromise.**

---

# 2. ACCEPTED SUB-11 BASELINE

Core SUB-11 is accepted as PASS.

Accepted finalization commit:

```text
96fc545beca3edf9dbc1ec9c83e4d61265eb4296
SUB-11 harden Google Play purchase restore flow
```

Protected validated behavior includes:

- purchase verification
- renewal
- cancellation / paid-through semantics
- expiration
- post-expiry generation blocking
- provider authority
- RTDN deduplication
- Restore Purchases
- reserve → generate → persist → commit
- paid-through Final Preview generation
- usage/data integrity
- historical-content preservation

Do not repeat expensive live SUB-11 tests unless a later phase actually changes the relevant behavior and a targeted re-validation is justified.

---

# 3. GLOBAL PRODUCT MATRIX

From SUB-12 onward:

| Plan | Price | Included allowance | Tutorial |
|---|---:|---:|---|
| Free | ₱0 | 1 lifetime AI Look | Preserve approved Free behavior |
| Plus | ₱399/mo | 3 AI Looks | YES |
| Plus Preview | ₱399/mo | 30 Final Preview Credits | NO |
| Pro | ₱899/mo | 8 AI Looks | YES |
| Pro Preview | ₱899/mo | 80 Final Preview Credits | NO |
| Salon Pro | ₱2,999/mo | 35 AI Looks | YES |
| Salon Preview | ₱2,999/mo | 350 Final Preview Credits | NO |
| Salon Pilot | Admin granted | 30 starting AI Looks, adjustable | Preserve approved Pilot behavior |

Canonical plan codes:

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

No phase may silently change these commercial allowances.

---

# 4. GLOBAL PROTECTED LOCKS

Preserve unless an explicit phase proves a minimal compatible change is required:

```text
Final Preview model = gemini-3.1-flash-image
Tutorial = V4
tutorial_guideline_v4_7
tutorial_manifest_v4_1
```

Also preserve:

- fail-closed Final Preview validation
- protected Final Preview prompt/renderer behavior
- Standard Mode
- My Makeup Kit
- immutable selected-product snapshots
- History
- Saved Looks
- existing canonical Preview persistence
- server-side Gemini only
- reserve → generate → persist → commit
- reservation-time usage attribution
- SUB-10 verify → activate → acknowledge
- SUB-11 provider-authoritative RTDN/lifecycle/restore
- RLS
- server-side entitlement authority
- historical-content preservation

No phase may use pricing/cost work as permission to lower protected AI quality.

---

# 5. GLOBAL GIT / WORKING-TREE SAFETY

Before every phase:

```powershell
git branch --show-current
git status --short
git rev-parse HEAD
git log -1 --oneline
```

Inspect the diff before touching files.

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

- switch branches automatically
- discard unrelated user work
- stage unrelated files
- commit unless explicitly instructed
- push unless explicitly instructed
- mutate stash entries

Known protected unrelated file may exist:

`FACETUNE_SUBSCRIPTION_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md`

If it is dirty due to user-owned work:

- do not modify it
- do not revert it
- do not stage it
- do not commit it

A dirty working tree is not permission to clean it.

---

# 6. GLOBAL SECURITY LOCKS

Never:

- disable RLS
- trust client plan code as purchase proof
- trust client price as purchase proof
- trust client remaining allowance
- trust client user ID for authoritative ownership
- let Flutter grant entitlement
- let Flutter mutate authoritative usage/credits
- expose service-role credentials to Flutter/browser
- expose Google provider credentials to Flutter/browser
- expose Gemini key to Flutter
- log JWTs
- log full purchase tokens
- log image bytes/base64
- log signed private image URLs
- create hardcoded Pilot emails
- create privileged UID bypasses
- create hidden production test/admin grant bypasses
- make Salon Pilot unlimited
- automatically reset Free monthly
- automatically reset Salon Pilot monthly
- implement client-session billing
- implement three-previews-per-client logic

Provider/store behavior must be verified against current official documentation when provider behavior is being changed.

---

# 7. GLOBAL EXECUTION CONTRACT

Every phase follows:

```text
READ AUTHORITIES
↓
VERIFY BRANCH + WORKING TREE
↓
INSPECT CURRENT IMPLEMENTATION
↓
STATE PHASE OBJECTIVE
↓
IDENTIFY MINIMUM FILE SET
↓
IDENTIFY FORBIDDEN CHANGES
↓
IMPLEMENT CURRENT PHASE ONLY
↓
FORMAT / ANALYZE / TEST
↓
PROVE SECURITY + REGRESSION
↓
REPORT EXACT EVIDENCE
↓
STOP
```

No phase completion authorizes the next phase.

---

# 8. STANDARD COMPLETION REPORT

Every phase must end with:

```text
PHASE COMPLETED:

BRANCH VERIFIED:

HEAD BEFORE PHASE:

HEAD AFTER PHASE:
No commit / <hash if explicitly authorized>

WORKING TREE PRESERVED:

AUTHORITY FILES READ:

OBJECTIVE ACHIEVED:

FILES CREATED:

FILES MODIFIED:

FILES DELETED:
None / exact files + justification

DEPENDENCIES ADDED / REMOVED:

DATABASE / MIGRATION CHANGES:

RLS CHANGES:

EDGE FUNCTION / BACKEND CHANGES:

FLUTTER CHANGES:

SUBSCRIPTION DOMAIN CHANGES:

PLAN / PRODUCT CONFIG CHANGES:

ENTITLEMENT CHANGES:

USAGE / CREDIT LEDGER CHANGES:

CAPABILITY CHANGES:

AI LOOK ACCOUNTING CHANGES:

FINAL PREVIEW INTEGRATION CHANGES:

TUTORIAL INTEGRATION CHANGES:

GOOGLE PLAY / PROVIDER CHANGES:

PURCHASE VERIFICATION CHANGES:

LIFECYCLE / RESTORE CHANGES:

SALON PILOT COMPATIBILITY CHANGES:

TOP-UP CHANGES:

TELEMETRY / COST MEASUREMENT CHANGES:

PROTECTED V4 CHECK:

SECURITY CHECK:

IDEMPOTENCY CHECK:

CONCURRENCY CHECK:

PRIVACY CHECK:

TESTS / VALIDATION:

PRE-EXISTING FAILURES:
None / exact failures with evidence they pre-date this phase

REAL DEVICE / LIVE BACKEND / STORE EVIDENCE:

KNOWN LIMITATIONS:

ASSUMPTIONS NOT PROVEN:

MANUAL ACTION REQUIRED:
None / exact single next manual action

NEXT RECOMMENDED PHASE:

STOP CONFIRMATION:
No later Subscription phase was implemented.
```

A completion report is evidence, not proof.

---

# SUB-12 — FREE & SALON PILOT BACKEND COMPATIBILITY

Read all mandatory authorities and prior accepted reports.

Implement ONLY:

**SUB-12 — FREE & SALON PILOT BACKEND COMPATIBILITY**

Do not begin SUB-12B.

## Active roles

Especially apply:

- Senior Subscription Systems Engineer
- Senior Entitlements Engineer
- Senior Supabase/PostgreSQL Engineer
- Senior Database Migration Engineer
- Senior Backend Engineer
- Senior Security Engineer
- Senior Shared-Contract Engineer
- Senior Concurrency / Idempotency Engineer
- Senior QA / Integration Test Engineer
- Senior Code Reviewer

## Objective

Finalize first-class non-store entitlement support for:

```text
free
salon_pilot
```

so they use the safe server-authoritative entitlement / usage engine without pretending to be Google Play purchases.

The design must remain compatible with later:

```text
plus_preview
pro_preview
salon_preview
purchased top-up credits
```

but those later products must not be implemented in SUB-12.

## Preflight

Before changing anything:

1. verify branch/status/HEAD
2. record unrelated dirty files
3. inspect current entitlement schema
4. inspect `subscription_admin_contract_v1`
5. inspect `resolve_subscription_state`
6. inspect reserve / commit / release
7. inspect usage ledger
8. inspect Google Play product→plan mapping
9. inspect current handling of users with no entitlement
10. inspect existing Free/Pilot tests and migrations
11. inspect current server time / period semantics
12. inspect whether allowance adjustments already exist

If the actual implementation materially contradicts the authority:

STOP.

## Free locked contract

```text
plan_code = free
price = ₱0
allowance = 1 lifetime AI Look
reset_policy = never
auto_renew = false
rollover = not applicable
Google Play product = none
RTDN lifecycle = none
```

Free allowance must survive:

- month/year changes
- logout/login
- reinstall
- app-data deletion
- new device
- auth refresh
- paid purchase
- paid renewal
- paid cancellation
- paid expiration
- Restore Purchases
- re-subscription

At most one lifetime complimentary Free allowance for one FaceTune account.

## Free provisioning decision

Inspect before choosing.

Evaluate:

- lazy resolver provisioning
- auth/account lifecycle provisioning
- idempotent server RPC provisioning
- database trigger
- current established account mechanism

Choose the smallest safe mechanism providing:

- server authority
- idempotency
- concurrency safety
- existing-account compatibility
- no client trust
- no duplicate Free entitlement

Two simultaneous first requests must not create two Free entitlements.

Do not fabricate monthly periods for Free merely to reuse paid semantics.

## Paid coexistence

Required:

- valid active paid entitlement wins for current paid functionality
- paid activation does not recreate Free
- renewal does not recreate Free
- expiration does not recreate Free
- restore does not recreate Free
- re-subscription does not recreate Free
- Free historical usage remains preserved
- historical paid usage remains preserved

If the current resolver cannot safely represent coexistence:

STOP and report the exact gap before inventing precedence.

## Salon Pilot locked contract

```text
plan_code = salon_pilot
origin = admin_granted / approved equivalent
publicly_purchasable = false
starting base allowance = 30 AI Looks
admin-adjustable = true
auto_renew = false
automatic reset = none
expiration = required/admin-controlled
Google Play product = none
RTDN lifecycle = none
unlimited = false
```

Conceptual allowance:

```text
base_allowance
+
audited_admin_adjustments
-
committed
-
active_reserved
=
available_capacity
```

Example:

```text
base 30
committed 18
admin adjustment +10
reserved 0
remaining 22
```

Administrative adjustments must not become the future purchased-credit ledger.

## Status enforcement

New generation must be denied for Pilot when applicable status is:

- expired
- suspended
- revoked

Remaining allowance does not override invalid status.

Use server-authoritative time.

## Shared Contract

Make Free and Salon Pilot cleanly representable through `subscription_admin_contract_v1`.

Prefer minimal compatible extension.

Do not build Web Admin.

Do not add production public grant RPCs merely to make tests easier.

Test-only fixtures must not ship as hidden privileged bypasses.

## Store isolation

Prove public Google Play verification cannot create:

```text
free
salon_pilot
```

A malicious client cannot self-select those plan codes.

Do not modify proven SUB-10 provider-authority architecture unless a minimal compatibility fix is genuinely required.

## Future-compatibility requirements

Do not implement Preview offers yet.

But do not introduce architecture that assumes:

```text
plus
pro
salon_pro
```

are the only possible paid store plans forever.

Do not implement capability by scattered plan-name checks.

Do not collapse:

```text
subscription allowance
admin adjustment
future purchased top-up credit
```

into one untraceable balance.

## Do NOT implement

- Plus Preview
- Pro Preview
- Salon Preview
- Preview Google Play products
- purchased top-ups
- top-up ledger
- top-up UI
- Admin Dashboard
- Admin user search
- Admin grant UI
- Admin adjustment UI
- Web Admin frontend
- telemetry beyond what SUB-12 correctness directly requires
- SUB-13 work

## Minimum tests

### Free

1. new eligible account gets exactly one Free entitlement
2. repeated initialization remains exactly one
3. concurrent initialization remains exactly one
4. first reservation succeeds
5. successful commit changes remaining 1 → 0
6. second reservation denied
7. month change does not reset
8. year change does not reset
9. logout/login does not reset
10. reinstall-equivalent server refresh does not reset
11. paid activation does not recreate
12. renewal does not recreate
13. paid expiration does not recreate
14. Restore Purchases does not recreate
15. re-subscription does not recreate
16. failure releases reservation
17. retry after release can consume exactly once
18. duplicate operation remains idempotent
19. normal client cannot self-grant/manipulate Free

### Salon Pilot

20. starting 30 representable
21. 18 committed => 12 remaining
22. conceptual +10 admin adjustment => effective 40 / remaining 22
23. admin adjustment does not rewrite usage history
24. month change does not reset
25. expiration blocks generation
26. suspension blocks if status exists
27. revocation blocks if status exists
28. non-public classification
29. Google Play verification cannot create Pilot
30. normal client cannot self-grant Pilot
31. no production hidden fixture/grant bypass

### Regression

32. Plus unchanged
33. Pro unchanged
34. Salon Pro unchanged
35. purchase verification unchanged
36. RTDN unchanged
37. Restore unchanged
38. reserve → generate → persist → commit unchanged
39. protected V4 systems unchanged

Run the narrowest reliable backend tests plus relevant subscription regressions and `flutter analyze` if Flutter/shared models changed.

## PASS gate

SUB-12 = PASS only if:

- Free is first-class non-store entitlement
- one lifetime allowance cannot reset/recreate incorrectly
- provisioning is concurrency-safe/idempotent
- Salon Pilot is first-class non-store admin-granted entitlement
- Pilot 30 base allowance works
- Pilot supports audited admin adjustment semantics
- Pilot expiration/status blocks generation
- neither Free nor Pilot is publicly purchasable
- Google Play cannot create either
- normal client cannot self-grant either
- future Preview plans are not structurally blocked
- future purchased credits are not forced into admin adjustments
- protected SUB-10/SUB-11/V4 regressions remain green

## Phase-specific completion addendum

Append:

```text
SUB-12 RESULT:
PASS / FAIL

FREE PROVISIONING MECHANISM:

FREE LIFETIME RESET PROTECTION:
PASS / FAIL

FREE CONCURRENT PROVISIONING:
PASS / FAIL

SALON PILOT REPRESENTATION:

SALON PILOT BASE ALLOWANCE:
30 / FAIL

ADMIN-ADJUSTMENT COMPATIBILITY:
PASS / FAIL

EXPIRATION ENFORCEMENT:
PASS / FAIL

PUBLICLY PURCHASABLE:
NO / FAIL

GOOGLE PLAY CAN CREATE FREE:
NO / FAIL

GOOGLE PLAY CAN CREATE SALON PILOT:
NO / FAIL

NORMAL CLIENT CAN SELF-GRANT:
NO / FAIL

PREVIEW-PLAN FUTURE COMPATIBILITY:
PASS / GAP

TOP-UP FUTURE COMPATIBILITY:
PASS / GAP

SUB-12B MAY BEGIN:
YES / NO
```

Then STOP.

---

# SUB-12B — CAPABILITY-AWARE PAID OFFER EXPANSION

Run only after SUB-12 is explicitly accepted.

Implement ONLY:

**SUB-12B — CAPABILITY-AWARE PAID OFFER EXPANSION**

Do not begin SUB-13.

## Active roles

Especially apply:

- Principal Subscription Systems Engineer
- Senior Entitlements Engineer
- Senior Google Play Billing Engineer
- Senior Supabase/PostgreSQL Engineer
- Senior Backend Engineer
- Senior Flutter/Riverpod Engineer
- Senior Product Contract Engineer
- Senior Security Engineer
- Senior Idempotency/Concurrency Engineer
- Senior QA/Integration Engineer
- Senior Code Reviewer

## Objective

Add the three locked Preview-only paid offers without creating a second Final Preview pipeline:

```text
plus_preview
₱399/month
30 Final Preview Credits
Tutorial NO

pro_preview
₱899/month
80 Final Preview Credits
Tutorial NO

salon_preview
₱2,999/month
350 Final Preview Credits
Tutorial NO
```

Existing:

```text
plus
pro
salon_pro
```

remain Tutorial-enabled.

## Provider target IDs

Target:

```text
facetune_plus_preview
facetune_pro_preview
facetune_salon_preview
```

Before implementation depends on them:

- verify current official Google Play subscription/product guidance
- inspect current Play Console test setup
- verify whether target product IDs already exist
- verify base-plan/offer requirements
- verify current in-app-purchase package compatibility

If provider configuration is missing:

prepare the exact required code/config and exact Play Console manual actions, then STOP at the provider gate if live provider evidence is required.

Do not invent fake provider success.

## Capability model

Inspect existing contracts first.

The effective plan contract must be able to distinguish:

```text
allowance_unit
included_allowance
tutorial_enabled
final_preview_enabled
reset_policy
publicly_purchasable
provider product
```

Use the smallest extension.

Do not scatter plan-name-specific Tutorial rules across Flutter/backend.

Server must enforce Tutorial denial for Preview plans.

Client hiding a button is not sufficient.

## Usage semantics

Tutorial-enabled plans:

```text
1 AI Look
→ 1 new usable persisted Final Preview
→ Tutorial capability YES
```

Preview-only plans:

```text
1 Final Preview Credit
→ 1 new usable persisted Final Preview
→ Tutorial capability NO
```

Both use:

```text
reserve
→ protected generation
→ persist
→ commit
```

Do not build a second renderer.

## Paywall / Flutter

Update public plan presentation so users can understand the two offer styles.

Requirements:

- provider/localized price remains display authority where appropriate
- Plus and Plus Preview may share the same price but have clearly different allowance/capability
- Pro pair likewise
- Salon pair likewise
- current plan state must recognize new codes
- remaining unit copy must distinguish AI Looks vs Final Preview Credits
- Preview plan must not imply Tutorial access
- historical Tutorial remains accessible where existing historical rules allow it
- purchase/restore UI must remain idempotent and provider-driven

Do not redesign unrelated app UI.

## Server product mapping

Server-owned mapping must map verified provider IDs to stable internal plan codes.

The client cannot send `plus_preview` and make it true.

Wrong/mismatched product evidence must fail closed.

Existing product mappings remain:

```text
facetune_plus      -> plus
facetune_pro       -> pro
facetune_salon_pro -> salon_pro
```

New target mappings:

```text
facetune_plus_preview  -> plus_preview
facetune_pro_preview   -> pro_preview
facetune_salon_preview -> salon_preview
```

subject to verified Play Console availability.

## Lifecycle

Preview plans must inherit the proven provider-authoritative semantics:

- purchase
- renewal
- cancellation
- cancelled-but-paid-through
- expiration
- restore
- provider authority
- RTDN dedup
- re-subscription
- historical content preservation

Do not reimplement lifecycle logic separately for Preview plans.

## Cross-plan transitions

Automated tests must cover, at minimum, authoritative state transitions between capability families where current Play/provider architecture permits controlled simulation:

- plus → plus_preview
- plus_preview → plus
- pro → pro_preview
- pro_preview → pro
- salon_pro → salon_preview
- salon_preview → salon_pro

Do not infer proration/provider timing.

Provider-verified state wins.

Historical usage must remain historically attributable.

A Preview entitlement must never obtain Tutorial capability from stale prior paid state.

## Do NOT implement

- purchased top-ups
- top-up store products
- cost-based automatic allowance changes
- Tutorial V4 changes
- model changes
- Admin UI
- Salon Pilot UI
- annual plans
- SUB-13 telemetry beyond minimal instrumentation needed for correctness

## Minimum tests

1. all three new plan codes parse/map
2. 30/80/350 allowances exact
3. unit type correct
4. Tutorial capability false
5. Final Preview capability true
6. server denies new Tutorial on Preview plans
7. client cannot forge Tutorial capability
8. Plus remains 3 + Tutorial
9. Pro remains 8 + Tutorial
10. Salon Pro remains 35 + Tutorial
11. provider mapping exact
12. wrong product rejected
13. same-price sibling not confused by price
14. purchase activation
15. renewal
16. cancelled-paid-through
17. expiration
18. restore
19. duplicate verification safe
20. duplicate RTDN safe
21. period reset gives correct Preview allowance
22. no rollover
23. historical usage preserved
24. historical Tutorial preserved
25. Preview generation uses locked Final Preview model/prompt
26. Preview success commits exactly one Preview Credit
27. failure releases
28. concurrent last Preview Credit cannot oversubscribe
29. paywall displays capability difference
30. current-plan state recognizes new plans
31. re-subscription does not duplicate entitlement ownership
32. original plan regressions remain green

## Human/provider gate

If new Play Console products/base plans do not yet exist:

Return exact manual requirements and stop.

Do not claim full SUB-12B PASS until code + provider configuration + required sandbox evidence are sufficient for the accepted phase definition.

## PASS gate

SUB-12B = PASS only if:

- all three Preview plans are first-class
- locked allowances exact
- Tutorial denial is server-enforced
- protected Final Preview pipeline unchanged
- provider mapping is authoritative
- lifecycle uses proven SUB-11 path
- current Flutter state/paywall can represent the offers
- no top-up architecture prematurely implemented
- existing paid plan regressions remain green

## Phase-specific completion addendum

```text
SUB-12B RESULT:
PASS / FAIL / BLOCKED ON MANUAL PROVIDER ACTION

PLUS PREVIEW:
30 / Tutorial NO / PASS-FAIL

PRO PREVIEW:
80 / Tutorial NO / PASS-FAIL

SALON PREVIEW:
350 / Tutorial NO / PASS-FAIL

CAPABILITY MODEL:
<summary>

SERVER-SIDE TUTORIAL DENIAL:
PASS / FAIL

PROVIDER IDS VERIFIED:
YES / NO / MANUAL ACTION REQUIRED

GOOGLE PLAY MAPPING:
PASS / FAIL

LIFECYCLE REUSE:
PASS / FAIL

PROTECTED FINAL PREVIEW:
UNCHANGED / FAIL

TOP-UPS IMPLEMENTED:
NO

SUB-13 MAY BEGIN:
YES / NO
```

Then STOP.

---

# SUB-13 — SUBSCRIPTION TELEMETRY, COST MEASUREMENT & UNIT ECONOMICS

Run only after SUB-12B is explicitly accepted.

Implement ONLY:

**SUB-13 — SUBSCRIPTION TELEMETRY, COST MEASUREMENT & UNIT ECONOMICS**

Do not implement purchased top-ups.

## Active roles

Especially apply:

- Senior Observability Engineer
- Senior AI Cost Optimization / FinOps Engineer
- Senior Data/Analytics Engineer
- Senior Subscription Systems Engineer
- Senior Privacy Engineer
- Senior Backend Engineer
- Senior Reliability Engineer
- Senior QA Engineer
- Senior Code Reviewer

## Objective

Add privacy-safe technical measurement sufficient to distinguish and evaluate:

```text
Tutorial-enabled AI Look economics
vs
Preview-only Final Preview economics
```

and to support a human decision on top-up packs.

Current hypotheses:

```text
Tutorial-enabled delivered AI Look ≈ ₱45 effective cost
Preview-only delivered Final Preview ≈ ₱4 effective cost
```

These are hypotheses, not runtime constants.

## Required measurement dimensions

Where current architecture/provider data safely allows, measure or derive:

- plan code
- capability family
- allowance unit type
- operation count
- reserved count
- committed count
- released count
- successful persisted Final Preview count
- Tutorial-generation technical count
- sanitized failure category
- generation latency
- persistence latency where useful
- provider/model/version metadata that is safe and needed
- retry count where existing architecture safely exposes it
- provider usage/cost inputs where available
- cost model version
- effective cost per successful delivered unit
- cost by plan/capability family
- cost by success/failure category
- subscription allowance utilization distribution where privacy-safe

Do not turn telemetry into entitlement authority.

Telemetry failure must not corrupt entitlement transactions.

## Cost methodology

At minimum report separately:

```text
Preview-only cost per successfully delivered Final Preview

Tutorial-enabled cost per successfully delivered AI Look

Tutorial incremental technical cost where measurable
```

Distinguish:

- raw provider cost
- estimated FX conversion if used
- effective delivered-unit cost
- failed-operation cost
- storage/other included cost only if there is a defensible source

Do not fabricate provider prices.

Keep mutable provider pricing/FX in a maintainable reporting-time cost model, not scattered through runtime entitlement code.

## Locked plan matrix protection

SUB-13 MUST NOT automatically change:

```text
Plus 3
Plus Preview 30
Pro 8
Pro Preview 80
Salon Pro 35
Salon Preview 350
```

The phase may report:

- observed cost
- full-utilization cost
- gross contribution before non-AI expenses where inputs are available
- variance from ₱45/₱4 assumptions
- risk bands
- recommended future review

But changing the matrix requires explicit user authorization.

## Top-up commercial decision report

Produce enough evidence for the user to choose a future top-up matrix.

Evaluate planning candidates without implementing them:

```text
Tutorial candidate:
₱149 → +1 Tutorial-capable AI Look

Preview candidate:
₱149 → +10 Final Preview Credits
```

Also report alternative pack sizes/prices only as analysis.

Do not write them into production/provider configuration.

## Privacy locks

Do not log/store for telemetry:

- image bytes
- base64
- signed URLs
- JWTs
- service-role secrets
- provider credentials
- full purchase tokens
- raw sensitive provider responses
- private Gemini prompts
- raw makeup-kit contents
- user-entered product names merely for cost analysis

Telemetry measures system behavior.

## Do NOT implement

- top-up purchases
- top-up ledger
- top-up provider products
- new Gemini calls merely for telemetry
- model downgrade
- prompt downgrade
- plan allowance changes
- Web Admin analytics UI
- broad third-party analytics migration
- SUB-14 work

## Minimum tests

1. committed vs released distinguishable
2. AI Look vs Final Preview Credit distinguishable
3. Tutorial technical operations separable from Preview
4. duplicate logical operation not double-counted
5. telemetry failure cannot roll back/corrupt entitlement incorrectly
6. sensitive values absent
7. purchase tokens omitted/redacted
8. signed URLs absent
9. image/base64 absent
10. private prompts absent
11. cost model versioned/maintainable
12. plan matrix unchanged
13. no authorization depends on telemetry/cost
14. existing generation regression green
15. existing subscription regression green

## Required business output

Completion report must include:

```text
OBSERVED / MEASURED DATA WINDOW:
<exact period or test sample>

TUTORIAL-ENABLED:
successful delivered units =
estimated/evidenced cost =
effective cost per delivered AI Look =

PREVIEW-ONLY:
successful delivered units =
estimated/evidenced cost =
effective cost per Final Preview =

₱45 HYPOTHESIS:
SUPPORTED / TOO HIGH / TOO LOW / INSUFFICIENT DATA

₱4 HYPOTHESIS:
SUPPORTED / TOO HIGH / TOO LOW / INSUFFICIENT DATA

LOCKED 30/80/350 MATRIX:
NO AUTOMATIC CHANGE

TOP-UP CANDIDATE ANALYSIS:
<analysis only>

TOP-UP COMMERCIAL APPROVAL REQUIRED:
YES
```

## PASS gate

SUB-13 = PASS when:

- technical cost/use telemetry is privacy-safe
- Tutorial and Preview economics are distinguishable
- entitlement integrity is unaffected
- mutable provider cost is not embedded in entitlement logic
- locked plan allowances remain untouched
- a defensible top-up decision report exists

## Human gate

After SUB-13 report:

STOP.

Do not begin SUB-13B until the user explicitly approves the production top-up price/pack matrix.

---

# SUB-13B — PURCHASED TOP-UP CREDITS

Run only after:

1. SUB-13 is explicitly accepted, AND
2. the user explicitly approves a production top-up commercial matrix.

If no approved matrix exists:

> **STOP. Report TOP-UP COMMERCIAL MATRIX MISSING. Do not implement provider products, ledger, UI, or purchase flows.**

Implement ONLY:

**SUB-13B — PURCHASED TOP-UP CREDITS**

Do not begin SUB-14.

## Active roles

Especially apply:

- Principal Subscription Systems Engineer
- Senior Billing/Google Play Engineer
- Senior Entitlements Engineer
- Senior Ledger/Accounting Engineer
- Senior PostgreSQL/Supabase Engineer
- Senior Security Engineer
- Senior Idempotency/Concurrency Engineer
- Senior Flutter/Riverpod Engineer
- Senior QA/Integration Engineer
- Senior Code Reviewer

## Objective

Implement purchased top-up credits as a separate auditable commerce/credit mechanism.

Top-ups are not:

- subscription included allowance
- Salon Pilot admin adjustments
- a new subscription entitlement
- a way to bypass active-plan requirements
- client-grantable balance

## Commercial authority check

Before coding, locate the explicitly approved matrix.

Record exactly:

```text
provider product id
retail/provider-configured price
credit quantity
credit capability/type
eligible active plans
purchase multiplicity rules
```

Do not infer from old planning candidates.

## Required ledger separation

Architecturally distinguish:

```text
subscription included allowance
Salon Pilot administrative adjustment
purchased top-up credit
```

Purchased-credit records must have auditable provenance such as:

- owner
- provider
- provider purchase reference/hash
- provider product
- credit type/capability
- quantity granted
- quantity consumed or immutable credit/debit ledger equivalent
- created/verified time
- status/revocation handling where applicable
- idempotency identity

Avoid one mutable unaudited integer if an append-only/auditable ledger is practical in current architecture.

## Consumption order

Locked:

```text
1. compatible included subscription allowance
2. compatible purchased top-up credits
```

Do not consume purchased credits while compatible included allowance remains.

## Persistence

Purchased credits do not automatically reset on subscription renewal.

Cancellation/expiration must not silently delete stored credits.

Consumption requires an active eligible paid entitlement unless the approved commercial matrix explicitly says otherwise.

Free is not automatically eligible.

Salon Pilot is not automatically eligible.

## Capability preservation

Top-up capability/provenance must not silently escalate after plan switching.

If the approved matrix contains more than one top-up capability family, each purchased credit retains its capability identity.

A cheaper Preview-only credit must never become Tutorial-capable merely because the user later subscribes to a Tutorial-enabled plan.

If a stored credit is incompatible with the user's current plan:

- preserve it
- do not convert it silently
- do not delete it
- do not consume it as a different capability

The exact user-facing behavior must follow the approved commercial matrix.

## Provider authority

Top-up purchase verification must be server-authoritative.

Protect against:

- forged client product
- forged quantity
- replayed purchase token
- duplicate callback
- duplicate verification
- cross-user token reuse
- wrong package/product
- acknowledgement/order errors
- provider-state mismatch

Do not reuse subscription lifecycle semantics blindly if Google Play one-time product semantics differ.

Verify current official provider documentation.

## Refund/revocation

Implement only provider-supported, authority-approved behavior.

Do not create negative user capacity through naive revocation.

If credits were already consumed before provider revocation/refund, define auditable handling consistent with provider rules and Source of Truth.

If business policy is missing:

STOP and report the exact unresolved case rather than invent debt/negative-balance policy.

## Flutter

Expose:

- purchased credit balance separately where useful
- consumption source clearly enough for support/debugging
- purchase CTA only for eligible active paid plans
- provider-localized price
- recoverable purchase state
- duplicate-tap protection

Flutter does not calculate authoritative remaining purchased credits.

## Do NOT implement

- subscription allowance increase disguised as top-up
- Salon Pilot admin adjustment via consumer purchase
- universal capability escalation
- wallet/coins
- dynamic metered billing
- annual subscriptions
- Web Admin
- SUB-14 hardening beyond tests required for SUB-13B

## Minimum tests

1. valid top-up purchase grants exact approved quantity
2. duplicate verification grants once
3. replay token grants once
4. wrong user/token rejected
5. wrong product rejected
6. forged quantity ignored/rejected
7. Free cannot purchase/use unless explicitly approved
8. Salon Pilot cannot purchase/use unless explicitly approved
9. active eligible paid plan can use
10. subscription allowance consumed first
11. purchased credits consumed second
12. renewal does not reset/delete credits
13. cancellation preserves storage
14. expiration preserves storage but blocks consumption if contract requires active paid plan
15. re-subscription makes compatible preserved credits available again
16. plan switching cannot escalate capability
17. incompatible credits preserved
18. concurrent last purchased credit cannot double-spend
19. duplicate generation operation cannot double-consume
20. generation failure releases/reconciles correctly
21. purchase refund/revocation follows approved policy
22. RLS prevents self-increment
23. Flutter cannot grant credits
24. provider secrets absent
25. original subscription lifecycle regression green
26. Preview Tutorial denial still green
27. Free/Pilot regression green

## PASS gate

SUB-13B = PASS only if:

- commercial matrix was explicitly approved
- purchased credits are separate and auditable
- server provider verification is authoritative
- replay cannot duplicate credits
- subscription-first consumption enforced
- persistence across renewal enforced
- active-plan eligibility enforced
- capability provenance prevents arbitrage
- no client self-grant
- no regression to existing subscriptions

## Phase-specific completion addendum

```text
SUB-13B RESULT:
PASS / FAIL

APPROVED COMMERCIAL MATRIX USED:
<exact matrix>

PROVIDER PRODUCTS:
<exact>

PURCHASED CREDIT LEDGER:
<summary>

SUBSCRIPTION-FIRST CONSUMPTION:
PASS / FAIL

RENEWAL PERSISTENCE:
PASS / FAIL

EXPIRATION STORAGE:
PASS / FAIL

ACTIVE-PLAN CONSUMPTION GATE:
PASS / FAIL

CAPABILITY PROVENANCE:
PASS / FAIL

REPLAY PROTECTION:
PASS / FAIL

CLIENT SELF-GRANT:
NO / FAIL

SUB-14 MAY BEGIN:
YES / NO
```

Then STOP.

---

# SUB-14 — FULL SECURITY, REGRESSION & EDGE-CASE HARDENING

Run only after SUB-13B is explicitly accepted, or after the user explicitly declares top-ups deferred and defines the final matrix to harden.

Implement ONLY:

**SUB-14 — FULL SECURITY, REGRESSION & EDGE-CASE HARDENING**

This is primarily a proving/fixing phase.

Do not use it as permission for broad refactoring.

## Active roles

Especially apply:

- Principal Software Engineer
- Principal Security Engineer
- Senior RLS Engineer
- Senior Subscription Systems Engineer
- Senior Google Play Billing Engineer
- Senior Ledger/Accounting Engineer
- Senior Idempotency/Concurrency Engineer
- Senior Reliability Engineer
- Senior QA/Regression Engineer
- Senior Integration Test Engineer
- Senior Production Debugging Engineer
- Senior Code Reviewer

## Objective

Prove the complete approved Subscription system is resilient across:

- entitlement
- capability
- provider lifecycle
- usage accounting
- purchased credits if implemented
- RLS/security
- concurrency
- async failure
- historical-content preservation
- protected FaceTune V4 behavior

## Matrix under test

At minimum:

```text
Free
Plus
Plus Preview
Pro
Pro Preview
Salon Pro
Salon Preview
Salon Pilot
Purchased top-ups if approved/implemented
```

## Required scenarios

### Free

- exactly one lifetime allowance
- first success commits
- exhaustion permanent
- no month/year reset
- reinstall/login does not recreate
- paid activation/renewal/expiry/restore/re-subscribe does not recreate

### Plus / Pro / Salon Pro

- exact allowance
- low/zero allowance
- new verified period resets included period allowance
- historical usage preserved
- Tutorial allowed
- no rollover

### Preview plans

- exact 30/80/350
- Tutorial denied server-side
- Final Preview works through protected pipeline
- exhaustion
- renewal
- cancellation paid-through
- expiration
- restore
- re-subscription
- no rollover

### Salon Pilot

- 30 initial
- no auto reset
- admin adjustment compatibility
- expiration
- suspension/revocation if supported
- non-public
- cannot be self-granted
- cannot be Google Play-created

### Cross-plan capability transitions

- Tutorial plan → Preview plan
- Preview plan → Tutorial plan
- stale state cannot leak capability
- historical Tutorial remains preserved
- current new-generation capability follows current authoritative entitlement
- same-price products never confused by price

### Usage engine

- reserve
- commit
- release
- duplicate reserve
- duplicate commit
- duplicate release
- reopen existing Preview = zero new consumption
- Tutorial reopen = zero new AI Look
- History/Saved reopen = zero
- generation failure releases
- persistence failure without usable result releases
- timeout with server success does not release incorrectly
- timeout with confirmed failure releases
- stale reservation reconciliation

### Concurrency

- one remaining + two simultaneous requests
- multiple devices
- duplicate operation ID
- network retry
- renewal during reservation
- expiration boundary during reservation
- restore during existing entitlement
- provider duplicate lifecycle event

### Provider

- valid purchase
- invalid evidence
- wrong product
- wrong package
- duplicate verification
- cancellation paid-through
- renewal
- expiration
- restore
- duplicate RTDN
- refund/revocation only according to verified current rules

### Top-ups if implemented

- exact grant
- replay prevention
- cross-user protection
- subscription-first consumption
- renewal persistence
- expiration storage
- active-plan gate
- incompatible capability preservation
- no capability escalation
- concurrent last-credit spend
- refund/revocation policy

### Security / RLS

- cannot grant own entitlement
- cannot grant Pilot
- cannot increment own purchased credits
- cannot edit committed usage
- cannot read another user's protected subscription/usage
- cannot attach another user's Preview
- RLS enabled
- no privileged secrets client-side
- no hidden test bypass
- no client plan/price authority
- no client Tutorial capability authority

### Protected FaceTune regression

- Standard Mode works
- My Makeup Kit works
- Final Preview model remains `gemini-3.1-flash-image`
- Final Preview protected prompt/config unchanged unless separately authorized
- Tutorial V4 works for entitled plans
- `tutorial_guideline_v4_7` preserved
- `tutorial_manifest_v4_1` preserved
- Preview plans cannot create Tutorial
- History works
- Saved Looks works
- existing Preview reopens
- existing historical Tutorial reopens
- no Gemini call moved to Flutter
- no build-triggered paid AI work

### Flutter/UI

- loading
- offline/error
- current plan
- correct unit label
- remaining allowance
- low/zero allowance
- reset date vs expiration
- Preview capability copy
- paywall
- Restore
- Pilot non-public
- top-up UX if implemented
- no layout overflow on POCO X3 GT when device testing is available

## Static review

Search for:

- stale hardcoded plan lists
- hardcoded `isPremium`
- duplicated allowance constants
- plan-name capability branching that should use contract fields
- hidden test bypasses
- special Pilot email/UID
- direct privileged writes from Flutter
- secret/token logging
- stale provider assumptions
- duplicated purchase listeners
- race-prone decrement logic
- opaque purchased-credit arithmetic
- Tutorial checks enforced only in UI

## Fix policy

Fix only defects proven by SUB-14 scope.

No broad redesign.

Any security-critical unresolved defect = FAIL.

## PASS gate

SUB-14 = PASS only if:

- all applicable matrix scenarios have explicit evidence
- no known high-severity entitlement/security/capability defect remains
- no known top-up double-spend/replay defect remains if top-ups are implemented
- protected V4 regressions are green or proven pre-existing/unrelated
- provider-authority invariants remain intact

## Phase-specific completion addendum

```text
SUB-14 RESULT:
PASS / FAIL

PLAN MATRIX COVERAGE:
<summary>

CAPABILITY SECURITY:
PASS / FAIL

USAGE ACCOUNTING:
PASS / FAIL

TOP-UP ACCOUNTING:
PASS / FAIL / NOT IMPLEMENTED BY APPROVED ROADMAP

RLS / AUTHORIZATION:
PASS / FAIL

PROVIDER LIFECYCLE:
PASS / FAIL

CONCURRENCY / IDEMPOTENCY:
PASS / FAIL

PROTECTED V4:
PASS / FAIL

KNOWN HIGH-SEVERITY DEFECTS:
None / exact

SUB-15 MAY BEGIN:
YES / NO
```

Then STOP.

---

# SUB-15 — REAL DEVICE, GOOGLE PLAY SANDBOX & PRODUCTION-READINESS ACCEPTANCE

Run only after SUB-14 is explicitly accepted.

Implement/validate ONLY:

**SUB-15 — REAL DEVICE, GOOGLE PLAY SANDBOX & PRODUCTION-READINESS ACCEPTANCE**

This is the final Subscription acceptance phase.

Do not add new product features.

Do not begin Web Admin.

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

Validate the final approved subscription system using:

- real device
- live approved backend
- Google Play test/sandbox evidence where required
- production-like release configuration
- security/release checks

Primary device:

```text
POCO X3 GT
```

Avoid repeating expensive provider/AI tests whose exact behavior was already proven and not changed.

Reuse accepted evidence where architecture is unchanged.

Target live checks to changed post-SUB-11 behavior.

## Preflight

Verify:

- branch/working tree
- accepted prior reports
- current diff
- no unrelated unreviewed changes
- Supabase project/environment
- deployed migrations/functions
- current secrets placement
- current Google Play testing track
- all required subscription products/base plans
- approved top-up products if implemented
- current provider docs for final lifecycle assumptions
- upload/release signing state
- package `io.facetune.app`

Do not upload a stale pre-expansion AAB accidentally.

Any release artifact must be built from the intended accepted commit/state.

## Required journeys

### A. Free

Prove on a clean eligible account:

```text
1 lifetime AI Look
↓
successful Final Preview
↓
0 remaining
↓
reopen Preview works
↓
historical content works
↓
new generation blocked
```

Do not create repeated aliases unnecessarily if server fixtures/accepted evidence can safely prove non-UI invariants.

### B. Plus

Verify:

```text
facetune_plus
→ plus
→ 3 AI Looks
→ Tutorial YES
```

One controlled successful generation is enough if arithmetic/exhaustion is already automated.

### C. Plus Preview

Verify:

```text
facetune_plus_preview
→ plus_preview
→ 30 Final Preview Credits
→ Tutorial NO
```

Prove one Final Preview can be generated and that new Tutorial generation is denied.

Do not burn 30 live generations to prove integer arithmetic.

### D. Pro

Verify provider mapping/state:

```text
facetune_pro
→ pro
→ 8 AI Looks
→ Tutorial YES
```

Use minimal cost-safe live evidence.

### E. Pro Preview

Verify:

```text
facetune_pro_preview
→ pro_preview
→ 80 Final Preview Credits
→ Tutorial NO
```

Use minimal cost-safe evidence.

### F. Salon Pro

Verify:

```text
facetune_salon_pro
→ salon_pro
→ 35 AI Looks
→ Tutorial YES
```

Do not exhaust 35 live calls merely to prove quota arithmetic.

### G. Salon Preview

Verify:

```text
facetune_salon_preview
→ salon_preview
→ 350 Final Preview Credits
→ Tutorial NO
```

Do not exhaust 350 live calls.

### H. Salon Pilot

Without building Web Admin, prove approved backend/test-fixture behavior:

```text
30 initial
admin-adjustable representation
non-public
no auto-reset
expiration supported
```

No hidden production grant bypass.

### I. Lifecycle / Restore

For new Preview products, obtain sufficient controlled/provider evidence that the proven SUB-11 lifecycle generalizes correctly:

- purchase
- cancellation paid-through
- expiration
- restore
- provider authority
- dedup

Do not automatically repeat every historical SUB-11 scenario for every product if shared mapping/lifecycle code plus targeted evidence is sufficient.

Document why coverage is sufficient.

### J. Top-ups if implemented

Use the approved pack matrix.

Prove at least:

- valid purchase grants exact quantity
- duplicate/replay safe
- subscription allowance consumed first
- purchased credits persist across renewal
- active-plan eligibility enforced
- capability provenance enforced
- no client self-grant

Avoid wasteful repeated purchases.

## Upgrade / migration checks

Validate realistic existing-user states:

- old Free user
- old Plus/Pro/Salon Pro user
- expired paid user
- cancelled-paid-through user where reproducible
- user with historical Tutorial
- user switching to Preview-only
- user returning to Tutorial-enabled
- user with purchased credits if implemented

Historical content must remain available.

No migration may fabricate new usage or reset historical usage.

## Performance / UX

On POCO X3 GT verify:

- subscription/paywall opens smoothly
- new plan matrix is understandable
- correct unit labels
- no provider query loops
- no duplicate listener side effects
- generation loading remains acceptable
- quota refresh after commit
- Tutorial denial UX for Preview plan is clear
- no layout overflow
- Profile/History/Saved remain acceptable

Use profile/release-like mode if debug overhead would distort performance.

## Security release checks

Verify:

- service-role secret absent from APK/client
- Google private credentials absent from APK/client
- Gemini key absent from Flutter
- RLS enabled
- protected functions auth as designed
- normal user cannot mutate entitlement/usage/purchased credits
- logs sanitized
- test fixtures/bypasses not exposed in production
- provider product mappings server-owned
- client cannot unlock Tutorial on Preview plan

## Release artifact checks

Before any Play upload:

- verify versionName/versionCode
- verify signing certificate expected for the current upload-key state
- verify build came from accepted code
- verify environment/config
- compute artifact hash
- record exact artifact path
- confirm no stale AAB lacking post-SUB-11 changes is used

Do not upload unless explicitly authorized.

## Final acceptance report

In addition to the standard report:

```text
SUBSCRIPTION EXPANSION FINAL STATUS:
PASS / FAIL / CONDITIONAL

FREE:
PASS / FAIL

PLUS:
PASS / FAIL

PLUS PREVIEW:
PASS / FAIL

PRO:
PASS / FAIL

PRO PREVIEW:
PASS / FAIL

SALON PRO:
PASS / FAIL

SALON PREVIEW:
PASS / FAIL

SALON PILOT:
PASS / FAIL

TOP-UPS:
PASS / FAIL / DEFERRED BY EXPLICIT AUTHORITY

GOOGLE PLAY PRODUCT MAPPING:
PASS / FAIL

PROVIDER LIFECYCLE:
PASS / FAIL

RESTORE:
PASS / FAIL

AI LOOK ACCOUNTING:
PASS / FAIL

FINAL PREVIEW CREDIT ACCOUNTING:
PASS / FAIL

TUTORIAL CAPABILITY ENFORCEMENT:
PASS / FAIL

PURCHASED CREDIT ACCOUNTING:
PASS / FAIL / NOT APPLICABLE

PROTECTED V4:
PASS / FAIL

REAL DEVICE:
PASS / FAIL

SECURITY:
PASS / FAIL

RELEASE ARTIFACT:
<path/hash/status or NOT BUILT>

OUTSTANDING BLOCKERS:
None / exact

PRODUCTION MANUAL ACTIONS:
None / exact ordered actions

READY FOR FINAL USER ACCEPTANCE:
YES / NO

READY TO BEGIN FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md:
YES / NO
```

## PASS gate

SUB-15 can return PASS only if:

- the complete approved subscription matrix is demonstrably stable
- Preview-only capability is enforced server-side
- provider mapping is correct
- entitlement/usage accounting remains safe
- top-up accounting is safe if implemented
- protected V4 remains intact
- security release checks pass
- outstanding manual/provider actions do not contradict a PASS claim

Then STOP.

Do not begin Web Admin automatically.

---

# FINAL PHASE FLOW

```text
SUB-12
Free + Salon Pilot
↓
REVIEW / PASS
↓
SUB-12B
Preview paid offers
↓
REVIEW / PASS
↓
SUB-13
Telemetry / cost / economics
↓
REVIEW / PASS
↓
HUMAN TOP-UP COMMERCIAL APPROVAL
↓
SUB-13B
Purchased top-up credits
↓
REVIEW / PASS
↓
SUB-14
Security / regression / edge cases
↓
REVIEW / PASS
↓
SUB-15
Real device / sandbox / production readiness
↓
FINAL SUBSCRIPTION REPORT
↓
STOP
↓
WAIT FOR EXPLICIT USER ACCEPTANCE
```

No automatic phase progression.
