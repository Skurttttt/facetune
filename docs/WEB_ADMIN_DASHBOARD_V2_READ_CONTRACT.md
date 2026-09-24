# Web Admin Dashboard V2 Read Contract

## Purpose

WA-DASH-1 adds the bounded, aggregate-only database read required by the future Web Admin Dashboard V2. It closes four backend evidence gaps without implementing UI-5, changing product semantics, or replacing the accepted V1 dashboard contract.

This document describes the implemented contract. It does not authorize additional backend behavior.

## Authority position

The authoritative implementation is the database migration for `public.admin_dashboard_v2_metrics()`. Its meanings come from existing database constraints and the final repository definition of `public.resolve_subscription_state()`:

- `usage_ledger` constraints define a committed Final Preview delivery.
- `usage_ledger.plan_code` and `usage_ledger.allowance_unit` preserve reservation-time attribution.
- the final Free-compatible subscription resolver defines which entitlement governs an account.
- the existing Admin roster check defines authorization.

The superseded status-only interpretation is not authoritative across Free-compatible accounts.

## Why WA-DASH-1 exists outside WA-13.5

WA-13.5-UI-5 stopped at its backend gate after identifying four aggregates that the accepted backend did not expose. The UI track did not authorize database work. WA-DASH-1 is the separately authorized, additive backend phase that supplies those aggregates before UI-5 begins.

## Baseline checkpoint

WA-DASH-1 is based on:

`ff964fd08436074d234e833162149a55e048de81`

## RPC and contract version

- RPC: `public.admin_dashboard_v2_metrics()`
- Contract version: `admin_dashboard_v2_contract_v1`
- Migration: `supabase/migrations/20261005000100_admin_dashboard_v2_metrics.sql`

The RPC is read-only and takes no arguments.

## Security posture

The function is:

- `stable`;
- `security definer` because the authorized aggregate read spans protected administrative data;
- locked to `search_path = ''`, with referenced relations and functions schema-qualified;
- executable by `authenticated` so a signed-in browser session can call it;
- guarded inside by the canonical `public.is_admin(auth.uid())` roster authorization;
- denied to `PUBLIC`;
- denied to `anon`;
- denied to `service_role` for client-style RPC execution.

An unauthenticated caller receives `AUTH_REQUIRED`. An authenticated caller outside the active Admin roster receives `ADMIN_UNAUTHORIZED`. The function contains no insert, update, delete, truncate, or indirect mutation path.

## Reporting window and bounds

The activity window is UTC and contains exactly 30 calendar dates: today plus the preceding 29 days. The start is inclusive and the next UTC day is the exclusive upper bound.

The server generates every date and left-joins activity counts. A day with no committed delivery is returned with explicit zeroes; clients do not infer or fill missing dates.

The response is bounded:

- `committedDaily`: exactly 30 items;
- `finalPreviewsByPlan30d`: exactly the eight canonical product plans, including zero-count plans;
- `committedTodayByUnit`: one fixed aggregate object;
- `entitlementStatusDistribution`: two fixed six-state objects and one total;
- no per-user or per-ledger-row collection.

## B-01: committed daily usage

`committedDaily` reports committed deliveries for each UTC day, separated into:

- `aiLook` for `allowance_unit = 'ai_look'`;
- `finalPreviewCredit` for `allowance_unit = 'final_preview_credit'`;
- `unattributed` for legacy rows whose `allowance_unit` is null.

Reserved and released operations are excluded.

## B-02: Final Preview delivery semantics

One committed `usage_ledger` row represents one delivered Final Preview under the current schema:

1. `usage_ledger_usage_type_valid` restricts `usage_type` to `final_makeup_preview`.
2. `usage_ledger_status_timestamps` requires a committed row to have `committed_at`, forbids `released_at`, and keeps reserved/released states distinct.
3. `usage_ledger_committed_requires_source_mode` requires the persisted pipeline mode because a commit is evidence that a usable canonical preview was persisted.

Therefore a committed row is a delivered Final Preview. A reservation is not a delivery, and a released operation produced no delivery.

### Historical plan attribution

`finalPreviewsByPlan30d` groups deliveries by the `plan_code` stored on the ledger reservation. It never joins an account's current entitlement to relabel historical delivery. A later upgrade, downgrade, expiry, or fallback cannot rewrite the plan under which the delivery was reserved.

The canonical product catalogue drives the result, so all eight plan codes appear even when their delivery count is zero.

## Legacy attribution

`usage_ledger.plan_code` and `usage_ledger.allowance_unit` are nullable because rows created before reservation-time attribution was added do not carry those facts. WA-DASH-1 does not guess them or drop those deliveries.

- null historical `plan_code` is counted by `finalPreviewsUnattributed30d`;
- null historical `allowance_unit` is counted by the relevant `unattributed` unit counters.

## B-03: allowance unit is not allowance source

`allowance_unit` says what entitlement unit was spent:

- `ai_look`; or
- `final_preview_credit`.

`allowance_source` says which balance paid:

- `subscription`; or
- `purchased_credit`.

These are independent dimensions. In particular, a purchased credit retains its granted unit class. A purchased-credit operation may consume an `ai_look`; its source does not convert it into a Final Preview Credit. WA-DASH-1 groups B-03 by `allowance_unit`, not `allowance_source`.

## B-04: current governing entitlement

The distribution includes exactly one governing entitlement for every account that has entitlement rows. Selection reuses the final Free-compatible resolver precedence:

1. in-force non-Free entitlement;
2. lifetime Free entitlement;
3. historical or pending non-Free entitlement.

An in-force non-Free row must meet every resolver condition:

- `plan_code <> 'free'`;
- status is `active`, `grace_period`, or `suspended`;
- `starts_at <= now`;
- `expires_at` is null or in the future;
- `period_end` is null or in the future.

The lifetime Free row is the second rank. Ended or pending non-Free rows are the third rank, so paid history cannot displace the permanent Free fallback.

Within those three ranks, the canonical resolver tie order is reused exactly:

1. `active`;
2. `grace_period`;
3. `suspended`;
4. `pending`;
5. `expired`;
6. `revoked`;
7. any otherwise invalid state.

Further ties are resolved by `starts_at DESC`, then `created_at DESC`. The implementation applies the same order per `user_id` and selects one row.

The status-only order above is a tie-breaker inside the three Free-compatible ranks. It is not, by itself, the governing precedence.

## Stored and effective status

`entitlementStatusDistribution` returns both:

- `byStoredStatus`, preserving the canonical stored status; and
- `byEffectiveStatus`, applying the existing Admin expiration normalization.

Both objects contain the six canonical categories: `pending`, `active`, `grace_period`, `expired`, `suspended`, and `revoked`. Each object's categories sum to the shared `total`.

### Effective expiration normalization

If the selected governing row is stored as `active` or `grace_period` and has `expires_at <= now`, its effective status is reported as `expired`. No stored row is changed, no status is renamed, and no new lifecycle state is introduced.

Because the final resolver prefers lifetime Free over ended non-Free history, an expired paid row normally does not govern a Free-compatible account. The normalization still describes a governing row accurately in states where such a row is selected.

## Privacy contract

The result is aggregate-only. It returns no:

- user identifiers or email addresses;
- per-user or per-ledger-row list;
- image or storage paths;
- prompts or analysis content;
- signed URLs;
- purchase tokens or provider references;
- raw provider payloads.

The function does not read image, prompt, receipt, or analysis tables to build the response.

## Performance

The bounded committed-usage reads use the existing partial index:

`usage_ledger_committed_at_idx`

No new index is introduced by WA-DASH-1.

## Existing V1 contract preservation

`public.admin_dashboard_metrics()` remains unchanged. Its accepted `subscription_admin_contract_v1.1` contract, decoder, privileges, and tests are not replaced or revised. Dashboard V2 is a sibling RPC with its own contract version.

## Database test coverage

The dedicated suite is `supabase/tests/wa_dash_1_admin_dashboard_v2_metrics_test.sql`:

- planned assertions: 51;
- passing assertions: 51;
- failed assertions: 0.

The suite expanded from the initial 38 assertions because closure added contract-specific coverage for the privileged function posture, execute grants, authorization refusals, empty-state zero filling, date ordering and window edges, non-delivery states, purchased-credit source-versus-unit behavior, legacy attribution, final Free-compatible governing precedence, privacy bounds, and V1 preservation. Coverage was retained rather than reduced to the earlier estimate.

The full local database regression result for the exact WA-DASH-1 SQL/test tree is:

- files: 17;
- tests: 1,143;
- result: PASS.

## Security test change

The exact authenticated, user-callable `SECURITY DEFINER` allowlist in `supabase/tests/sub14_security_rls_test.sql` increases from 21 to 22 entries by adding only `admin_dashboard_v2_metrics`.

There is no wildcard, pattern relaxation, role expansion, or broader whitelist weakening.

## Supabase advisors

Local-project validation reported:

- security advisor: PASS, no issues;
- performance advisor: PASS, no issues.

These are local results. WA-DASH-1 does not claim a remote production advisor run.

## UI status and future chart dependency

- UI-5: NOT IMPLEMENTED.
- UI-6: BLOCKED.
- Approved future UI-5 chart dependency: `fl_chart ^1.2.0`.
- `fl_chart` was not installed during WA-DASH-1.

WA-DASH-1 changes no Dashboard Flutter source, Admin model, gateway, controller, theme, or mobile application file.

## Remote deployment

None. No remote database migration, Edge Function deployment, hosting deployment, or production deployment is part of WA-DASH-1 closure.
