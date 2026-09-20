# SUB-13B — purchased top-up credits

Status: implemented locally; **not deployed**; Play Console products **not
created**. Provider refund/void ingestion is deferred (see the end); the
accounting model for it is in place and tested.

## Locked production matrix (human authority, 2026-09-21)

| Pack | Play product id | Type | Price | Grants | Credit class | Eligible active paid plans |
| --- | --- | --- | ---: | --- | --- | --- |
| Extra AI Look | `facetune_ai_look_topup_1` | one-time consumable | ₱149 | +1 Tutorial-capable AI Look | `tutorial_capable_ai_look` | `plus`, `pro`, `salon_pro` |
| Preview Boost | `facetune_preview_credit_topup_10` | one-time consumable | ₱149 | +10 Preview-only Final Preview Credits | `preview_only_final_preview` | `plus_preview`, `pro_preview`, `salon_preview` |

Free: no consumer top-ups. Salon Pilot: no consumer top-ups.

The ids, classes, quantities, and eligible plans are written in exactly two
places — the migration's `top_up_packs` rows (locked by a check constraint)
and `TopUpPack` / `TopUpPackCatalog` — with a contract test that keeps them
equal and refuses the earlier assumed ids. Prices live in Play Console only
and are never stored.

## Three buckets, never merged

```text
subscription included allowance   user_entitlements.base_ai_look_allowance
Salon Pilot admin adjustment      user_entitlements.allowance_adjustment_total
purchased top-up credit           purchased_credit_grants
```

## Ledger

* `top_up_packs` — server-owned product → pack mapping. Class and quantity
  are locked by a check constraint to the approved matrix.
* `purchased_credit_grants` — append-only credit side. One row per verified
  purchase, keyed on the SHA-256 purchase reference (never the token).
  Immutable except `provider_consumed_at` and a single, never-cleared
  revocation (`revoked_at`, `revocation_reason`, `revocation_reference`);
  direct deletes refused, the `auth.users` cascade allowed. A trigger
  refuses any row that disagrees with its pack's class or quantity.
* `usage_ledger.allowance_source` / `purchased_credit_grant_id` — the debit
  side. A reservation drawn from a credit names its grant. Remaining =
  granted − committed rows; available = remaining − reserved rows. No
  counter is ever incremented or decremented; a released reservation returns
  its credit by ceasing to count.

RLS: owners may read their own grants (minus the reference); no client role
can insert, update, or delete. `grant_verified_top_up_purchase` and
`mark_top_up_purchase_consumed`, and `revoke_top_up_purchase` are
`service_role`-only.

## Deterministic consumption

1. The governing plan's included allowance for the current period.
2. Purchased credits compatible with the governing plan:
   a. the class matching the plan's own unit, oldest grant first;
   b. any other compatible class, oldest grant first.

Compatibility:

| Governing plan | Tutorial-capable credit | Preview-only credit |
| --- | --- | --- |
| Tutorial-enabled paid | spent as `ai_look` (Tutorial included) | spent as `final_preview_credit` (no Tutorial) |
| Preview-only paid | **preserved, never spent** | spent as `final_preview_credit` |
| Free / Salon Pilot / lapsed / blocked | preserved | preserved |

The credit's class is stamped onto the ledger row as `allowance_unit` at
reservation, which is what `authorize_tutorial_generation` already reads. A
Preview-only credit therefore never yields a Tutorial, on any plan, ever.

`resolve_subscription_state()` reports `purchasedTutorialCreditsRemaining`,
`purchasedPreviewCreditsRemaining`, `purchasedCreditsUsable`,
`availablePurchasedCredits`, `nextAllowanceSource`, and `nextAllowanceUnit`.
The subscription figures (`availableAiLooks` etc.) count subscription rows
only. `generationAuthorized` is also true when the included allowance is
exhausted but a compatible credit is available.

## Provider flow

```text
Flutter: buyConsumable(autoConsume: false)
   ↓ purchase token
verify-google-play-top-up (Edge)
   ↓ purchases.productsv2 GET (token-only)      — the only authority
   ↓ product → pack (SQL), state must be PURCHASED, quantity must be 1
   ↓ grant_verified_top_up_purchase              — exactly once per reference
   ↓ purchases.products:consume (v1)             — only after the grant
   ↓ resolve_subscription_state as the user
Flutter: completeVerifiedTopUp(consumedByServer)
   → device consumes only when the server could not
```

Eligibility at grant: an active, in-force paid store plan that is in the
pack's `eligible_plan_codes` — exact, per the matrix above. (Consumption
compatibility after a later plan change is the separate class rule in the
table above: a Preview Boost bought on Plus Preview is still spendable, as
Preview-only, after an upgrade to Plus.) A refused purchase stays unconsumed and
Google refunds it after three days. Pending purchases grant nothing yet
(`TOP_UP_PENDING`, retryable). A replayed verification returns the existing
grant and retries consumption if needed.

Provider quantity ≠ 1 is refused (`PROVIDER_STATE_CONFLICT`). Multi-quantity
must **not** be enabled on these products in Play Console.

## UI

Top-up packs appear on the Plans page only when the server says purchased
credits are usable, and only the packs the plan can spend. Each card states
its capability in words. The Profile card shows stored credits separately
from the plan's figure, and says "kept for you" when they cannot currently
be spent. Before a look that would spend a purchased credit, the allowance
notice names the credit — including "no Tutorial" for a Preview-only one.

## Manual actions before this can be used

1. Create the two **one-time, consumable** products in Play Console with the
   locked ids above, ₱149 each, single quantity (multi-quantity off).
2. Deploy migration `20260923000100_purchased_top_up_credits.sql` and Edge
   Function `verify-google-play-top-up` (it reads the same secrets as
   `verify-google-play-purchase`).

## Refund / void accounting (locked policy, 2026-09-21)

When the provider authoritatively reports a granted purchase as refunded,
voided, or revoked, `revoke_top_up_purchase(sha256(token), reason)` (service
role only, idempotent) marks the grant revoked. Effects, all by construction
of the derived model rather than by arithmetic:

* credits already consumed (committed usage rows) stay exactly as they are —
  immutable history, never clawed back;
* the grant's unused credits stop being available at once and forever
  (`revoked_at` excludes the grant from every sum);
* no negative figure can arise: revoked grants contribute nothing, and no
  subtraction runs across grants;
* the subscription's included allowance, every other grant, and Salon Pilot
  adjustments are untouched;
* repeating the same revocation is a no-op that returns the same answer;
* the reason and provider reference are recorded on the grant for audit and
  can never be cleared.

Example: Preview Boost granted 10, consumed 3, provider voids → consumed 3
(history), revoked unused 7, available from grant 0. Never −3.

A reservation already in flight on the grant when the revocation lands may
still commit or release on its own terms; it is reported as `inFlight`.

**External ingestion is deferred to a later hardening step.** When it is
built, the provider mechanism — Google Play RTDN `oneTimeProductNotification`
(`ONE_TIME_PRODUCT_CANCELED`, type 2) delivered to the existing
`google-play-rtdn` function, or a scheduled `purchases.voidedpurchases.list`
sweep — needs only the purchase token's SHA-256 and a reason (`refunded` /
`voided` / `revoked`) to call `revoke_top_up_purchase`. Nothing about the
accounting model has to change to connect it.

## Open item

* **Telemetry.** SUB-13's `ai_operation_metrics` accepts four operation
  kinds; top-up verification is not one of them and is not recorded, to
  leave the accepted SUB-13 schema untouched.
