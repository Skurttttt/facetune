# WA-0 — WEB ADMIN BASELINE & SUBSCRIPTION INTEGRATION AUDIT

**Phase:** WA-0 (READ-ONLY)
**Phase file:** `FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md`
**Branch:** `feature/web-admin-v1`
**HEAD at audit:** `8fece29` (SUB-14 add security and concurrency hardening tests)
**Date of audit:** 2026-09-21
**Contract version referenced:** `subscription_admin_contract_v1`
**Remote project:** `usmlwaocafeqnspdsvmv` (ap-northeast-1)

Every claim below was read out of actual source, migrations, Edge Functions,
configuration, tests, or a recorded read-only command against the linked
remote project. No product feature code, package, migration, policy, role, or
web project was created in this phase.

---

# A. GIT / WORKING TREE

```text
git branch --show-current   → feature/web-admin-v1
git status                  → clean (nothing to commit, working tree clean)
```

Recent history (newest first): `8fece29` SUB-14, `f9cfd58` SUB-13B fix,
`82f122f` SUB-13B, `fed3ffd` SUB-13B, `2f88650` SUB-13, `7b3eea3` SUB-12B,
`bf68ebf` SUB-12, `96fc545`…`a48cab5` SUB-11.

No uncommitted Subscription work exists. Nothing needed preserving beyond
leaving the tree untouched, which was done.

---

# B. SUBSCRIPTION COMPLETION STATUS (proven)

| Phase | Evidence | Status |
|---|---|---|
| SUB-0 … SUB-11 | commits through `96fc545`; migrations `20260907000100` … `20260917000100`; `docs/GOOGLE_PLAY_*_SETUP.md` | complete |
| SUB-12 Free + Salon Pilot compatibility | `bf68ebf`; `20260920000100_free_and_salon_pilot_compatibility.sql` | complete |
| SUB-12B Preview-only paid offers | `7b3eea3`; `20260921000100_preview_only_paid_offers.sql` | complete |
| SUB-13 telemetry | `2f88650`; `20260922000100_subscription_telemetry.sql` | complete |
| SUB-13B purchased top-ups (+ replacement fix) | `fed3ffd`, `82f122f`, `f9cfd58`; `20260923000100`, `20260924000100` | complete |
| SUB-14 hardening | `8fece29`; `supabase/tests/sub14_*.sql`, `supabase/tests/controlled/sub14_concurrency.sh` | complete (tests only, no product code) |
| SUB-15 real-device / sandbox / production readiness | no commit, no report, no file | **not started** |

Consequence: the Web Admin is being started before final Subscription
acceptance (SUB-15). `FACETUNE_SUBSCRIPTION_EXPANSION_SOURCE_OF_TRUTH.md` §25
sequences Web Admin *after* SUB-15 and "only after explicit user approval".
The user's instruction to run WA-0 on `feature/web-admin-v1` is taken as that
approval; it is recorded here so that WA-15 does not assume SUB-15 evidence
exists.

**Deployed state (read-only probes, 2026-09-21):**

```text
supabase db push --linked --dry-run
  → {"upToDate":true, "migrations":[]}   all 32 local migrations are applied remotely

supabase functions list
  → 16 ACTIVE functions. Repo-backed and current:
      analyze-face v12, generate-makeup-recommendation v13,
      generate-makeup-preview v19, delete-history-item v14,
      generate-kit-makeup-recommendation v13, generate-kit-makeup-preview v15,
      analyze-tutorial-manifest-v4 v11, generate-tutorial-step-v4 v16,
      verify-google-play-purchase v6 (verify_jwt=true),
      google-play-rtdn v3 (verify_jwt=false; Pub/Sub OIDC verified in code),
      verify-google-play-top-up v1 (verify_jwt=true)
    Deployed but NO LONGER IN THE REPO (dormant legacy):
      generate-tutorial-step, plan-tutorial-geometry, plan-tutorial-v2,
      map-tutorial-v3-guideline-geometry, plan-tutorial-v3

supabase db query --linked (read-only)
  public tables  = exactly the 31 tables the migrations create (no dashboard-only tables)
  auth.users     = 13   (0 anonymous; 0 with any role/admin/is_admin key in raw_app_meta_data)
  user_entitlements = 28 (0 salon_pilot)   usage_ledger = 9
  entitlement_allowance_adjustments = 0    purchased_credit_grants = 5
  subscription_products = free:1, plus:3:facetune_plus, plus_preview:30:facetune_plus_preview,
                          pro:8:facetune_pro, pro_preview:80:facetune_pro_preview,
                          salon_pro:35:facetune_salon_pro, salon_preview:350:facetune_salon_preview,
                          salon_pilot:30
  pg_policies named *admin* = 0            pg_proc named *admin* = 0
```

---

# C. ACTUAL SUBSCRIPTION IMPLEMENTATION MAP (item 1)

## C.1 Schema (all in `supabase/migrations/`)

| Table | Created | Later altered | Purpose |
|---|---|---|---|
| `subscription_products` | `20260907000100` | `20260921000100` (+`allowance_unit`, `tutorial_enabled`, `final_preview_enabled`; plan-code CHECK widened to 8) | server-side plan configuration; 8 rows seeded |
| `user_entitlements` | `20260907000100` | `20260920000100` (one-current index excludes `free`; Free lifetime guard trigger; `allowance_adjustment_total` guard trigger), `20260921000100` (plan-code CHECK widened) | one row per entitlement; carries `base_ai_look_allowance`, `allowance_adjustment_total`, `version` |
| `usage_ledger` | `20260907000100` | `20260921000100` (+`plan_code`, `allowance_unit`, provenance guard), `20260923000100` (+`allowance_source`, `purchased_credit_grant_id`) | the AI Look billing ledger: `reserved` → `committed` / `released`; committed rows trigger-immutable |
| `provider_purchase_verifications` | `20260910000100` | — | one row per verified Google Play subscription purchase (SHA-256 reference only, never a token) |
| `provider_notification_events` | `20260917000100` | — | RTDN inbox with idempotent claim/finalize |
| `entitlement_allowance_adjustments` | `20260920000100` | — | **the only admin-shaped table that exists**: `admin_user_id`, `adjustment_type`, `amount`, `reason`, `idempotency_key`; BEFORE INSERT trigger applies it and bumps `version`; rows immutable |
| `ai_operation_metrics` | `20260922000100` | — | SUB-13 telemetry; `service_role` select/insert only |
| `top_up_packs`, `purchased_credit_grants` | `20260923000100` | — | SUB-13B purchased credits (2 packs; grants immutable, revocable) |
| `ai_usage_events` | `20260812000100` | — | pre-subscription abuse rate limiter; **not** the billing ledger (SUB-0 §D.1 still holds) |

Every one of these has RLS enabled. `authenticated` holds **no INSERT / UPDATE /
DELETE grant** on any of them; SUB-14 `sub14_security_rls_test.sql` (74
assertions) proves this against the live privilege model.

## C.2 Database functions / RPCs (current definitions)

| Function | Latest definition | Executable by | Role in the system |
|---|---|---|---|
| `resolve_subscription_state()` | `20260923000100` | `authenticated` | the read model: governing entitlement + effective allowance + committed/reserved/available + `generationAuthorized` + `denialReason` + purchased-credit summary; identity from `auth.uid()` only |
| `reserve_ai_look(uuid)` | `20260923000100` | `authenticated` | atomic capacity check + reservation under `pg_advisory_xact_lock(hashtextextended(user_id))`; idempotent on `operation_id` |
| `commit_ai_look(uuid, text, uuid)` / `release_ai_look(uuid, text)` | `20260907000300` | `authenticated` | commit with canonical preview lineage; release with sanitized failure code |
| `reconcile_stale_ai_look_reservations(...)` | `20260907000300` | (owner) | stale-reservation sweep |
| `authorize_tutorial_generation(text, uuid, uuid)` | `20260921000100` | `authenticated` | capability gate for Tutorial V4 |
| `provision_free_entitlement(uuid)` | `20260920000100` | none (trigger-only) | one lifetime Free row per account, from `handle_new_auth_user()` |
| `activate_verified_google_play_subscription(...)` | `20260924000100` | `service_role` | provider → entitlement writer; maps Play states to `pending/active/grace_period/suspended/expired`; supersedes prior paid row; bumps `version` |
| `claim_google_play_notification`, `finalize_google_play_notification`, `google_play_purchase_owner`, `revoke_google_play_subscription` | `20260917000100` | `service_role` | RTDN lifecycle; `revoke_…` is the only writer of `status = 'revoked'` |
| `grant_verified_top_up_purchase`, `mark_top_up_purchase_consumed`, `revoke_top_up_purchase` | `20260923000100` | `service_role` | purchased-credit lifecycle |
| `record_ai_operation_metric(...)` | `20260922000100` | `service_role` | telemetry insert |
| trigger functions: `apply_entitlement_allowance_adjustment`, `reject_allowance_adjustment_mutation`, `guard_allowance_adjustment_total`, `guard_free_entitlement_lifetime`, `guard_usage_ledger_provenance`, `reject_committed_usage_mutation`, `reject_purchased_credit_grant_*` | various | not callable directly | integrity guards |

**There is no function that grants, extends, suspends, reactivates, or revokes
an entitlement administratively, and no function that writes
`entitlement_allowance_adjustments`.** All privileged writers are
`security definer` functions granted to `service_role` only, called from Edge
Functions holding `SUPABASE_SERVICE_ROLE_KEY`.

## C.3 Edge Functions (`supabase/functions/`)

Subscription-relevant: `verify-google-play-purchase`, `verify-google-play-top-up`,
`google-play-rtdn`. Generation functions (`generate-makeup-preview`,
`generate-kit-makeup-preview`, `analyze-tutorial-manifest-v4`,
`generate-tutorial-step-v4`) call reserve/commit/release through
`_shared/ai_look_usage.ts` and `_shared/ai_quota.ts`. Shared helpers live in
`supabase/functions/_shared/` (Deno, `deno.json` strict, `deno.lock` committed,
`nodeModulesDir: auto`). Tests are `*_test.ts` beside each module, run with
`deno test`.

## C.4 Flutter domain (`lib/features/subscription/`)

Clean-architecture layout: `domain/entities`, `domain/errors`,
`domain/catalog`, `domain/repositories`, `domain/usecases`, `data/…`,
`presentation/…`. Vocabulary is already strongly typed as enums with
`code` + `fromCode()` returning `null` on unknown values:

- `SubscriptionPlanCode` — **8 codes** (`free, plus, plus_preview, pro, pro_preview, salon_pro, salon_preview, salon_pilot`)
- `EntitlementStatus` — `pending, active, grace_period, expired, suspended, revoked`
- `BillingProvider` — `none, google_play, apple_app_store, admin_granted`
- `UsageStatus` — `reserved, committed, released`
- `UsageType` — `final_makeup_preview`
- `ResetPolicy` — `none, billing_period`
- `AllowanceUnit` — `ai_look, final_preview_credit` (SUB-12B extension)
- `SubscriptionErrorCode` — exactly the Shared Contract §71 list, including `ADMIN_UNAUTHORIZED`

Flutter reaches the backend only through `client.rpc('resolve_subscription_state')`
(`subscription_remote_data_source.dart:23`) and `client.functions.invoke(...)`
for the two verification functions. Flutter never reads
`user_entitlements`/`usage_ledger` tables directly.

---

# D. ACTUAL DATA SOURCES (items 2–4)

## D.1 Entitlement data source (item 2)

`public.user_entitlements`. Governing-row selection is **not** a column; it is
the ORDER BY in `resolve_subscription_state()` (rank 0 = non-free in force by
status **and** dates; rank 1 = lifetime Free; rank 2 = everything else). Every
account has at least a Free row (provisioned by `handle_new_auth_user()`),
so a user with a live paid plan has two `active` rows. Admin views must apply
the same precedence or call a server function that does; reading "the active
row" naively returns Free.

Effective status is also date-derived: the resolver denies with
`SALON_PILOT_EXPIRED` / `ENTITLEMENT_EXPIRED` when `expires_at` or `period_end`
has passed while the stored `status` may still be `active`. Nothing sweeps
lapsed rows to `expired` except a later activation (`20260924000100:325`) or an
RTDN notification. Admin must display effective status, not raw `status`.

## D.2 Usage-ledger data source (item 3)

`public.usage_ledger`, one row per operation, immutable once committed.
Columns beyond Shared Contract §42: `source_mode`,
`canonical_generated_image_id` / `canonical_kit_generated_image_id` (dual
preview lineage, `ON DELETE SET NULL` so history deletion never refunds),
`plan_code`, `allowance_unit`, `allowance_source` (`subscription` |
`purchased_credit`), `purchased_credit_grant_id`.

## D.3 Remaining-balance source (item 4)

Computed, never stored, by `resolve_subscription_state()`:

```text
effective  = greatest(0, base_ai_look_allowance + allowance_adjustment_total)
committed  = count(usage_ledger where entitlement_id = governing and status='committed'
                    and allowance_source='subscription' and reserved_at >= period_start)
reserved   = same with status='reserved'
available  = greatest(0, effective - committed - reserved)      ← authoritative for a NEW generation
remaining  = greatest(0, effective - committed)                 ← user-facing "N of M"
```

The same arithmetic (without the period filter, which admin-granted rows do
not have) is re-done inside `apply_entitlement_allowance_adjustment()` for
safe reduction. The resolver is `auth.uid()`-scoped, so **an admin cannot
call it for another user**; a server-owned admin read (RPC with a
`p_user_id` argument, `service_role`-only, or a `security definer` function
that checks admin authorization) is required — see §H.

---

# E. ADMIN CAPABILITY (items 5–6)

## E.1 Admin-role capability (item 5)

**None.** Proven by:

- `grep -rn "is_admin|admin_role|app_metadata|user_role|'admin'"` over `lib/`, `supabase/migrations/`, `supabase/functions/` (excluding `node_modules`), `supabase/tests/`, `test/`, `tool/` → 0 hits.
- `profiles` (`20260807000100:18`) has `id, auth_user_id, display_name, avatar_path, timestamps` — no role column.
- Remote: 0 users carry any `role` / `is_admin` / `admin` key in `raw_app_meta_data`; 0 policies and 0 functions named `*admin*`.
- The Shared Contract's `ADMIN_UNAUTHORIZED` exists only as an enum member in Flutter (`subscription_error_code.dart:14`) and is never produced by any server path.

The only admin-shaped artefacts are `entitlement_allowance_adjustments.admin_user_id`
(a bare `references auth.users(id)`, no role check) and the trigger's rule that
`admin_user_id` must be non-null at insert.

## E.2 Available server authorization mechanism (item 6)

The established, repeatedly proven pattern (every Edge Function `index.ts`,
e.g. `verify-google-play-purchase/index.ts:118-145`):

```text
1. require "Authorization: Bearer <user JWT>"
2. createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global.headers.Authorization }) → auth.getUser()
   → identity is the JWT's subject, never a body field
3. (privileged step) createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY).rpc('<service_role-only fn>', {...})
   → the RPC's arguments carry authority; the RPC is never granted to authenticated
4. read back state as the user (anon-key client)
```

Facts relevant to admin:

- JWT verification is **inline in each function** — there is no
  `_shared/require_user.ts`. WA-2 would add the first shared auth helper.
- `supabase/config.toml` sets `verify_jwt = true` per function (gateway-level
  JWT check) except `google-play-rtdn` (`false`, replaced by Pub/Sub OIDC
  verification in `pubsub_auth.ts`). `verify-google-play-top-up` has no
  `[functions.…]` entry and relies on the CLI default (`true`).
- Postgres-side, `auth.uid()` is the only identity primitive used; no
  function reads `auth.jwt()` claims, `request.jwt.claims -> 'role'`, or
  `app_metadata`.
- Anonymous sign-ins are enabled (`docs/AUTH_SETUP.md`); anonymous users hold
  the `authenticated` role. Any admin check must therefore also reject
  `is_anonymous = true` — membership in `authenticated` is not evidence of a
  real account.
- The service-role key is present remotely as a runtime secret and is read
  by exactly four modules: `google-play-rtdn/index.ts:111`,
  `verify-google-play-purchase/index.ts:208`,
  `verify-google-play-top-up/index.ts:181`, `_shared/ai_telemetry.ts:175`.
  It never appears in `lib/`, `config/`, `android/`, or `web/`.

---

# F. WEB ADMIN / FRONTEND STATE (items 7–9)

## F.1 Web Admin framework status (item 7)

**Does not exist.** `find . -type d -iname "*admin*"` (excluding
`node_modules`, `build`, `.dart_tool`) → nothing. No `admin/`, `apps/`,
`packages/`, `web-admin/` directory.

## F.2 Frontend stack (item 8)

- The only application is Flutter (`pubspec.yaml`: Dart SDK `^3.10.0`;
  `flutter_riverpod ^2.5.1`, `go_router ^14.2.0`, `supabase_flutter ^2.17.1`,
  `in_app_purchase ^3.3.0`, `in_app_purchase_android ^0.5.0`,
  `flutter_lints ^6.0.0`).
- `web/` is the stock Flutter web scaffold (`index.html`, `manifest.json`,
  `favicon.png`, `icons/`) — never built or referenced by any doc, tool, or
  test. It is not a web admin.
- **No** `package.json`, `tsconfig.json`, `vite/next/*.config.*`, `.github/`,
  `Dockerfile`, `vercel.json`, `netlify.toml`, or any CI/hosting config
  anywhere outside `node_modules`.
- The only TypeScript in the repo is Deno (Edge Functions). The only
  package manager conventions are `pub` and Deno's lockfile.
- Environment convention: `config/example.json` (committed) with
  `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY`; `config/development.json` /
  `config/production.json` git-ignored and passed via
  `--dart-define-from-file`. Server secrets live only in Supabase Edge
  secrets. Deployment is manual CLI (`supabase db push`,
  `supabase functions deploy <name>`), documented per feature in `docs/`.

## F.3 Existing backend/admin endpoints (item 9)

**None.** No Edge Function, RPC, view, or policy serves an administrative
read or write. The nearest precedents for the admin write path are the three
`service_role`-only RPC families in §C.2, and the nearest precedent for an
audited admin write is the `entitlement_allowance_adjustments` insert trigger.

---

# G. RLS AND SERVICE-ROLE BOUNDARY (items 10–11)

## G.1 RLS implications for Admin (item 10)

- Client roles (`anon`, `authenticated`) can `SELECT` only their own rows
  (`user_entitlements_select_own`, `usage_ledger_select_own`,
  `provider_purchase_verifications_select_own`,
  `purchased_credit_grants_select_own`), with column-level grants withholding
  `provider_subscription_reference` and purchase references. There is no
  policy, and no grant, that would let an `authenticated` admin read another
  user's rows. **Adding an "admin can read all" RLS policy keyed on a role is
  not the established pattern here and would put authorization inside RLS
  predicates that SUB-14 tests currently prove are owner-only.**
- `entitlement_allowance_adjustments`, `provider_notification_events`,
  `ai_operation_metrics`: RLS enabled, **no policy, no client grant at all**.
  They are reachable only by the table owner and, where granted, `service_role`.
- `auth.users.email` (needed for user search per Shared Contract §65) is not
  readable by `authenticated`; `profiles` carries no email. Search/resolve by
  email therefore must be a server-side privileged read.
- Remote `pg_default_acl` (recorded in the SUB-13B preflight) grants
  `anon`/`authenticated`/`service_role` full rights on **new** tables and
  EXECUTE on **new** functions. Every admin migration must `revoke all … from
  public, anon, authenticated` explicitly, exactly as `20260920000100` and
  `20260923000100` do.
- Consequence for architecture: the defense-in-depth model that fits this
  repository is *server authorization in an Edge Function + `security definer`
  RPCs granted to `service_role` only + an admin-membership check inside the
  RPC as well* — not RLS policies that trust a role claim.

## G.2 Service-role usage and security boundary (item 11)

- Service role is used only server-side (§E.2), only to call RPCs, never for
  table reads/writes (`verify-google-play-purchase/index.ts:199-208` states
  this explicitly; `ai_telemetry.ts` inserts via a `service_role`-granted RPC).
- `docs/SECURITY_HARDENING.md`, `.gitignore`, and `config/example.json`
  keep public config to URL + publishable key.
- **Finding (pre-existing, not introduced here):** `NOTES.md` (tracked,
  commit `2c728fe`) contains the plaintext line `SUPABASE PW: facetune_123*`.
  This is a database/dashboard credential committed to the repository. Not
  changed in this read-only phase; see §L manual actions.
- **`NOTES.md` is non-authoritative personal scratch material.** It is not
  application configuration and not a contract source. Its plan-code list
  (5 codes), status list (omits `pending`), and field examples
  (`ai_look_limit` / `ai_look_used` / `ai_look_remaining`) are outdated
  sketches and were **not** used for any conclusion in this audit; §I is
  derived solely from the Shared Contract, the Expansion SOT, the migrations,
  and the Flutter enums. Later Web Admin phases must ignore `NOTES.md` for
  contract decisions. The credential is a separate cleanup item only.

---

# H. MISSING SCHEMA / CONTRACTS NEEDED BY WA-1+ (item 12)

Ordered by the phase that first needs them. None is needed by WA-1 itself
(WA-1 is typed contracts only), so **no migration is authorized for WA-1**.

| # | Gap | First needed | Notes |
|---|---|---|---|
| 1 | **Admin identity persistence** — nothing records who is an admin | WA-2 | Recommend a table (`public.admin_users`: `user_id` PK → `auth.users`, `granted_at`, `granted_by`, `revoked_at`), RLS enabled, no client grant, read by a `security definer` `is_admin(uuid)` helper. A JWT `app_metadata` claim is weaker here: revocation would not take effect until token refresh, violating Web Admin SOT §9 ("removed/revoked admin privilege must take effect without requiring a new app build" / "stale browser state must not preserve admin authority"). Must also reject `auth.users.is_anonymous`. |
| 2 | **Admin read model for another user** — `resolve_subscription_state()` is `auth.uid()`-scoped | WA-4/5/6 | A `service_role`-only RPC taking `p_user_id` that reuses the resolver's precedence and arithmetic (do not duplicate the formula in TypeScript), plus list/search over `auth.users` (email, created_at, `is_anonymous`) joined to `profiles` and governing entitlement. |
| 3 | **Admin audit event table** — none exists; adjustments are self-auditing but grant/extend/suspend/reactivate/revoke have no trail | WA-7 (grant) | Shape per Shared Contract §63: `id, admin_user_id, action, target_user_id, target_entitlement_id, before_state, after_state, reason, request_correlation_id, idempotency_key, created_at`; immutable via trigger like `reject_allowance_adjustment_mutation`; no client grant. |
| 4 | **Salon Pilot grant RPC** — no writer for `plan_code='salon_pilot'` rows | WA-7 | Must satisfy `user_entitlements_salon_pilot_shape` (admin_granted, non-null `expires_at`, no period, no provider fields), the one-current partial unique index (a live paid plan blocks a second active non-free row → `SALON_PILOT_ALREADY_GRANTED` / conflict), and the per-account advisory lock convention. |
| 5 | **Allowance adjustment RPC** — table + trigger exist, no authorized caller | WA-8 | Insert into `entitlement_allowance_adjustments` from a `service_role`-only function that verifies admin membership; the trigger already enforces admin-granted-only, safe reduction, and idempotency `(entitlement_id, idempotency_key)`. |
| 6 | **Typed error mapping for adjustment refusals** — the trigger raises plain-text exceptions (`allowance reduction would invalidate committed or reserved usage`) and cannot distinguish `ALLOWANCE_BELOW_COMMITTED_USAGE` from `ALLOWANCE_CONFLICTS_WITH_ACTIVE_RESERVATION` | WA-8 | Either the RPC pre-checks and returns typed codes, or the trigger is amended to use `ERRCODE`/message constants. Not a WA-1 concern. |
| 7 | **Lifecycle RPCs** — extend expiration, suspend, reactivate, revoke for admin-granted rows; today `suspended` is written only by the Play activation mapping and `revoked` only by `revoke_google_play_subscription` | WA-9 | Must validate transitions against current `status` and bump `version`; must not touch provider-backed rows' provider fields. |
| 8 | **Optimistic concurrency precondition** — `version` exists and is bumped by every writer, but no RPC accepts an expected version | WA-8/9/11 | Add `p_expected_version` → `CONCURRENT_MODIFICATION`. |
| 9 | **Shared JWT/admin helper in `_shared/`** | WA-2 | First extraction of the inline `auth.getUser()` pattern. |

---

# I. SHARED CONTRACT vs ACTUAL IMPLEMENTATION (item 15)

The Shared Contract (dated 2026-09-07) predates SUB-12/12B/13B (2026-09-20/21).
The Expansion SOT §1.3(4) and §23 keep `subscription_admin_contract_v1` as the
baseline and permit "minimal, typed, backward-compatible" extension, but **no
contract revision document has been written**. The Web Admin Phase Prompts
§16 and §20 still forbid exactly the codes and features that now exist.

| # | Shared Contract says | Actual implementation | Severity |
|---|---|---|---|
| 1 | §7 canonical plan codes = 5 (`free, plus, pro, salon_pro, salon_pilot`); §4 new plan codes require a contract revision; WA prompts §16 "use only" the 5 | 8 codes in DB CHECKs (`20260921000100:80-106`), remote products, and `SubscriptionPlanCode` (`plus_preview`, `pro_preview`, `salon_preview` added) | **Blocking for WA-1** — WA-1 cannot define `SubscriptionPlanCode` without deciding which list is canonical |
| 2 | §4 "AI Look add-on packs" / "wallet or credit systems" require a contract revision; WA prompts §20 lists "add-on AI Look packs" as a non-goal | `top_up_packs`, `purchased_credit_grants`, `usage_ledger.allowance_source`/`purchased_credit_grant_id`, resolver fields `purchased*Credits*`, `availablePurchasedCredits`, `nextAllowanceSource/Unit`; 5 live grants remotely | **Contract gap** — admin read model must at least not misreport these (available capacity ≠ subscription-only figure when credits are usable) |
| 3 | §9 allowance = AI Looks only | `subscription_products.allowance_unit` (`ai_look` / `final_preview_credit`), `tutorial_enabled`, `final_preview_enabled`; `AllowanceUnit` enum | contract extension needed (Expansion SOT §23 lists "Tutorial capability / Final Preview capability / allowance unit" as required compatibility fields) |
| 4 | §41 entitlement fields | Actual has all listed plus `allowance_adjustment_total`, `version`; `verified_at` present | compatible |
| 5 | §42 usage fields incl. single `canonical_preview_id` | Dual lineage `canonical_generated_image_id` / `canonical_kit_generated_image_id` + `source_mode`; plus `plan_code`, `allowance_unit`, `allowance_source`, `purchased_credit_grant_id` | compatible; admin read model needs a discriminated preview reference, not one id |
| 6 | §43 adjustment fields; §45 action ids `increase_allowance`/`decrease_allowance` | `entitlement_allowance_adjustments` matches field-for-field; `adjustment_type` CHECK uses exactly those two codes | compatible (already implemented) |
| 7 | §30 `available_ai_looks` authoritative | Resolver returns both `availableAiLooks` (minus reservations) and `remainingAiLooks` (user-facing) | compatible; admin must show `available` as the authoritative capacity and may show `remaining`/`reserved` separately |
| 8 | §12 statuses incl. `pending`; WA prompts §18 "use `pending` only if the actual implementation requires it" | `pending` is written by the Play activation mapping (`SUBSCRIPTION_STATE_PENDING`) | `pending` **is required** in admin vocabulary |
| 9 | §71 error codes | Flutter enum matches exactly; server emits them as `denialReason` / `errorCode` strings in jsonb; adjustment trigger emits untyped exception text (see §H.6) | compatible for reads; gap for WA-8 writes |
| 10 | §73/§74 response shapes (snake_case conceptual) | Server jsonb uses camelCase (`effectiveAllowance`, `committedUsage`, …) — same as Flutter DTO | compatible; WA-1 should adopt the camelCase wire names already in use rather than introduce a second spelling |
| 11 | §32 Salon Pilot `expiration_required = true` | Enforced by `user_entitlements_salon_pilot_shape` CHECK | compatible |
| 12 | §57 RLS assertions | All proven by `sub14_security_rls_test.sql` | compatible |

**Recommended resolution before WA-1 (user decision, not implementable here):**
issue a short amendment — `subscription_admin_contract_v1.1` or an
"Expansion compatibility addendum" — that (a) adopts the 8 plan codes,
(b) adds `allowance_unit` / `tutorial_enabled` / `final_preview_enabled`,
(c) declares purchased-credit summary fields read-only for Admin V1,
(d) updates Web Admin Phase Prompts §16/§20 accordingly. Per Phase Prompts
§1(12) and Shared Contract §94, WA-1 must not "invent compatibility logic"
around this; it needs the ruling.

---

# J. LIKELY MINIMUM FILES / MODULES FOR WA-1 (item 13)

WA-1 is "typed contracts, no auth, no UI, no mutations". Because no web
project exists and WA-0/WA-1 do not authorize creating one, the only place a
*shared* typed contract can live today that both the future admin server
layer and the existing backend tests can exercise is the Deno `_shared/`
module tree. This also matches Shared Contract §90 (one authoritative server
contract, two clients).

```text
supabase/functions/_shared/admin_contract.ts          enums as const-object string unions + parse helpers:
                                                       SubscriptionPlanCode (8, pending §I ruling), BillingProvider,
                                                       EntitlementStatus, UsageType, UsageStatus, ResetPolicy,
                                                       AllowanceUnit, AdminAction (§45), AdminRole (normal_user|admin),
                                                       AdjustmentType, AuditEventSource, SubscriptionErrorCode (§71)
supabase/functions/_shared/admin_contract_test.ts     parsing of every enum; unknown value → typed failure, never a default;
                                                       round-trip of the camelCase wire names in resolve_subscription_state()
supabase/functions/_shared/admin_read_models.ts       AdminUserSummary, AdminUserDetail, AdminEntitlementView (incl.
                                                       effectiveStatus, availableAiLooks/remaining/reserved/committed,
                                                       purchased-credit summary), AdminUsageRecord (discriminated preview
                                                       ref), AdminUsageSummary, AllowanceAdjustment(+Preview), AuditEvent,
                                                       AdminMutationResult (§73), AdminPagination, AdminQuery/Filter
supabase/functions/_shared/admin_read_models_test.ts  mapping from resolver jsonb → view; remaining-balance field semantics
```

Reuse, do not duplicate: the string values already fixed by the DB CHECK
constraints and by `lib/features/subscription/domain/entities/*.dart`. A
Dart-side admin contract is **not** needed for WA-1 (Flutter is not the admin
client), and `test/features/subscription/subscription_vocabulary_test.dart`
already locks the Flutter enums; a WA-1 test asserting the TS lists equal the
Dart lists (string compare against the migration CHECKs) would prevent drift.

Validation commands that exist for this layer: `deno fmt --check`,
`deno check`, `deno test` in `supabase/functions/` (note: `deno test`
rewrites `deno.lock`; restore it with `git show HEAD:supabase/functions/deno.lock > supabase/functions/deno.lock` from bash).

**Framework decision is deferred, not made.** WA-2 requires a "protected
frontend-route foundation", so a web framework must exist by WA-2. Nothing in
the repository constrains the choice (no JS toolchain at all). Whatever is
chosen must consume the `_shared/` contract (or a generated copy of it) rather
than define its own.

---

# K. ASSUMPTIONS REQUIRING RUNTIME PROOF (item 14)

Resolved in this phase (read-only probes recorded in §B):

- Remote schema equals local migrations — **proven** (`db push --dry-run` up to date).
- No admin role/claim/policy/function exists remotely — **proven** (0/0/0/0).
- 8 products with Play ids seeded remotely — **proven**.
- All Edge Functions in the repo are deployed at current versions — **proven**.

Still unproven / to be proven in the phase that depends on them:

1. Whether `pg_default_acl` on the remote still auto-grants on new objects (was true on 2026-09-21 preflight) — re-check before the first WA migration.
2. Behaviour of `auth.getUser()` for an anonymous JWT inside an Edge Function (expected: succeeds with `is_anonymous: true`) — WA-2 must test rejection explicitly.
3. Whether the five dormant deployed functions (`generate-tutorial-step`, `plan-tutorial-*`, `map-tutorial-v3-guideline-geometry`) are still invoked by any shipped app build — irrelevant to admin, but they widen the attack surface; not touched here.
4. SUB-15 acceptance evidence (real device / Play sandbox) does not exist; WA-14/15 cannot cite it.
5. Supabase Auth settings for the admin account type (email confirmation, CAPTCHA, MFA availability) — dashboard-only, not in repo; WA-2 must read them.
6. `flutter test` baseline on this Windows checkout: 12 `test/features/tutorial/*` failures are a CRLF artefact (proven in SUB-14 via an LF worktree). Not re-run in WA-0 (nothing Dart changed); `flutter analyze --no-pub` → **No issues found** (54.2 s).

---

# L. MANUAL ACTIONS REQUIRED

1. **Rotate and remove the committed credential in `NOTES.md`** (`SUPABASE PW: facetune_123*`, tracked since `2c728fe`). Rotation is a dashboard action; removal is a repo edit outside WA-0's read-only rule and should be a deliberate commit (note: history retains it).
2. Decide the Shared Contract amendment described in §I before authorizing WA-1.
3. Decide the admin web framework before WA-2 (not needed for WA-1).

---

# M. STANDARD COMPLETION REPORT

```text
PHASE COMPLETED:
WA-0 — Web Admin Baseline & Subscription Integration Audit (read-only).

BRANCH VERIFIED:
feature/web-admin-v1 at 8fece29.

WORKING TREE PRESERVED:
Yes. Tree was clean at start; the only change is this audit document.

OBJECTIVE ACHIEVED:
Yes. Subscription architecture, admin capability (none), web frontend state
(none), shared-contract gaps, security boundary, and the smallest WA-1 scope
are mapped from actual source and read-only remote probes.

FILES CREATED:
WA_0_BASELINE_AUDIT.md

FILES MODIFIED:
None.

FILES DELETED:
None.

DEPENDENCIES ADDED / REMOVED:
None.

WEB APP / FRONTEND CHANGES:
None. Proven: no web admin, no JS/TS web project, no package.json exists.

DATABASE / MIGRATION CHANGES:
None.

RLS CHANGES:
None.

EDGE FUNCTION / SERVER API CHANGES:
None.

ADMIN AUTHENTICATION CHANGES:
None.

ADMIN AUTHORIZATION CHANGES:
None. Proven: no admin role persistence, claim, policy, or function exists
locally or remotely.

SHARED CONTRACT CHANGES:
None. Gaps documented in §I; an amendment is required before WA-1.

USER MANAGEMENT CHANGES:
None.

ENTITLEMENT CHANGES:
None.

SALON PILOT CHANGES:
None. Remote holds 0 salon_pilot entitlements and 0 adjustments.

ALLOWANCE ADJUSTMENT CHANGES:
None.

USAGE LEDGER CHANGES:
None.

AUDIT LOG CHANGES:
None. Proven: no general admin audit table exists.

SUBSCRIPTION ENGINE CHANGES:
None.

FINAL PREVIEW / AI CHANGES:
None.

PRIVACY CHECK:
Probes read counts and product configuration only; no user content, emails,
tokens, or images were read or recorded.

SECURITY CHECK:
Pre-existing finding: plaintext Supabase password committed in NOTES.md.
Service-role key confined to four server modules; not in any client path.

SERVICE-ROLE EXPOSURE CHECK:
No exposure in lib/, config/, android/, web/. Not used in this phase.

IDEMPOTENCY CHECK:
N/A (no mutations). Existing mechanisms documented in §C/§H.

CONCURRENCY CHECK:
N/A (no mutations). Per-account advisory lock + version column documented.

ACCESSIBILITY CHECK:
N/A (no UI).

TESTS / VALIDATION:
git branch --show-current → feature/web-admin-v1
git status → clean (before writing the audit file)
flutter analyze --no-pub → No issues found (54.2 s)
supabase db push --linked --dry-run → remote up to date (read-only)
supabase functions list → 16 ACTIVE (read-only)
supabase db query --linked (2 read-only SELECTs) → counts in §B

REAL BACKEND / BROWSER EVIDENCE:
Remote schema, function inventory, and row counts recorded in §B. No browser
evidence (no web app exists).

KNOWN LIMITATIONS:
SUB-15 has not been executed; Web Admin starts before final Subscription
acceptance. Five dormant Edge Functions remain deployed outside the repo.

ASSUMPTIONS NOT PROVEN:
Listed in §K (default ACL persistence, anonymous-JWT behaviour in Edge
Functions, dashboard Auth settings, SUB-15 evidence).

MANUAL ACTION REQUIRED:
1. Rotate + remove the NOTES.md credential.
2. Rule on the Shared Contract amendment (§I) before WA-1.
3. Choose the admin web framework before WA-2.

NEXT RECOMMENDED PHASE:
WA-1 — after the §I ruling. Minimum scope in §J (Deno _shared/ typed
contracts + tests; no migration, no framework, no auth).

STOP CONFIRMATION:
No later phase was implemented.
```
