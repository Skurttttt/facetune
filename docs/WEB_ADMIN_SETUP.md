# Web Admin setup (WA-2 through WA-11)

The FaceTune Web Admin is a Flutter Web application built from a separate
entrypoint in this repository. It shares the consumer app's Supabase Auth,
Riverpod, go_router, theme, and test tooling, and nothing else: the admin
bundle contains only what `lib/admin/` reaches.

Contract: `subscription_admin_contract_v1.1`.

## What the implemented phases provide

| Layer | Piece | Purpose |
|---|---|---|
| Database | `public.admin_users` (migration `20260925000100_admin_identity.sql`) | The roster. One row per grant; revocation sets `revoked_at`; re-grant is a new row. RLS enabled, no policy, no client grant. |
| Database | `public.current_user_is_admin()` → boolean | The session's own answer. `security definer`, identity from `auth.uid()`, executable by `authenticated`. |
| Database | `public.is_admin(uuid)` → boolean | The account-addressed answer for server code. Executable by `service_role` only. |
| Edge Function | `admin-session` (`verify_jwt = true`) | The first protected admin endpoint: returns the caller's own admin identity, or 401 / 403 / 503. |
| Edge helper | `_shared/admin_auth.ts` → `requireAdmin(request, userClient)` | The gate every later admin function calls first. Uses the anon key + the caller's JWT; never the service-role key. |
| Flutter | `lib/admin_main.dart`, `lib/admin/` | Login, loading, unauthorized pages; router redirect driven only by the server's answer. |
| Database (WA-4) | `public.admin_dashboard_metrics()` → jsonb (migration `20260926000100_admin_dashboard_metrics.sql`) | Server-side COUNT aggregates for the dashboard: accounts, in-force entitlements per plan, committed/reserved/released AI Looks (today / UTC month, split by allowance source), Salon Pilot in force / expiring within 14 days, active purchased-credit grants. Argument-free; refuses inside unless `is_admin(auth.uid())`; returns totals only. Adds two partial indexes on `usage_ledger(committed_at)` / `(released_at)`. |
| Flutter (WA-4) | `lib/admin/dashboard/` | The Dashboard section: strict decoder, controller (fetches only once authorization is established; refusals hand the whole app to the secure state), page with loading / ready / empty / unavailable states and manual refresh. |
| Database (WA-5) | `public.admin_search_users(text, text)` and `public.admin_get_user(uuid)` (migration `20260927000100_admin_users_search_and_detail.sql`) | Roster-checked, read-only account lookup. Search is exact email or exact User ID; blank search browses fixed newest-first keyset pages of 25. Responses are allowlisted to account identity/status and authoritative subscription state. |
| Flutter (WA-5) | `lib/admin/users/` | Exact account search, one-page-at-a-time results, and `/users/:userId` subscription detail. It never requests or models selfies, previews, tutorial images, storage URLs, prompts, Gemini payloads, or My Makeup Kit inventory. |
| Database (WA-6) | `public.admin_list_entitlements(uuid, text, text, text, integer, text)` and `public.admin_list_usage(uuid, uuid, text, text, text, timestamptz, timestamptz, text)` (migration `20260928000100_admin_entitlements_and_usage.sql`) | Roster-checked, read-only listings. Entitlements: every `user_entitlements` row with the resolver's allowance/usage arithmetic applied per row on the server, an effective status (lapsed-but-stored-active reads `expired`), and optional filters by user, plan, effective status, provider, and `expires_at` window (1–365 days, server clock). Usage: every `usage_ledger` row in its canonical `reserved` / `committed` / `released` state with stamped provenance, lifecycle timestamps, and `sanitized_failure_code`; optional filters by user, entitlement, status, plan, allowance source, and `created_at` range. Both: fixed newest-first keyset pages of 25, cursor bound to the filters, filter values outside the contract vocabulary rejected (SQLSTATE 22023). No image ids, paths, URLs, prompts, or provider references leave the server. Adds `(created_at desc, id desc)` indexes on both tables. |
| Flutter (WA-6) | `lib/admin/entitlements/`, `lib/admin/usage/`, `lib/admin/shared/` | `/entitlements` and `/usage` filter + table + Previous/Next pages (one server page in memory), a shared keyset-list controller, strict fail-closed decoders, and text status badges. `/entitlements?userId=` and `/usage?userId=|entitlementId=` open pre-filtered; user detail links to both. Read-only: no mutation RPC is referenced anywhere in the admin tree. |
| Database (WA-7) | `public.admin_audit_events` (immutable, RLS on, no client grant) and `public.admin_grant_salon_pilot(uuid, timestamptz, text, text, integer, uuid)` (migration `20260929000100_admin_grant_salon_pilot.sql`) | The first privileged mutation. Roster-checked from the session; per-account advisory lock; validates target (existing, non-anonymous), future expiration, allowance any non-negative integer (default 30; no business maximum is defined), reason 1–500, idempotency key 1–128; refuses SALON_PILOT_ALREADY_GRANTED (pilot in force, incl. suspended), PROVIDER_STATE_CONFLICT (store subscription active/grace), IDEMPOTENCY_CONFLICT (same key, different intent); retires a lapsed stored-active pilot as `expired`; inserts the `salon_pilot` / `admin_granted` row and exactly one audit event (before/after snapshots, reason, correlation id, key) in one transaction; returns the consumer resolver's figures with `replayed`. Never touches the Free row, the ledger, or a paid subscription. |
| Edge Function (WA-7) | `admin-grant-salon-pilot` (`verify_jwt = true`) + `_shared/admin_mutations.ts` | `requireAdmin` → parse/validate the intent body (400 `invalid_request` names the field) → call the writer AS THE CALLER → map the contract code to HTTP status. Mints the request correlation id (`x-request-id`). No service-role key. |
| Flutter (WA-7) | `lib/admin/salon_pilot/` | `/users/:userId/grant-salon-pilot`: form (expiration date UTC, allowance default 30, required reason) → preview (idempotency key minted here) → confirm → the server's authoritative state. A retry after a temporary failure reuses the same key; the server replays rather than re-grants. Entry: **Grant Salon Pilot** on user detail. |
| Database (WA-8) | `public.admin_adjust_salon_pilot_allowance(uuid, integer, text, text, integer, uuid)` (migration `20260930000100_admin_adjust_salon_pilot_allowance.sql`) | Roster-checked from the session; per-account advisory lock; target must be an admin-granted Salon Pilot that has not ended (INVALID_ALLOWANCE_ADJUSTMENT / ENTITLEMENT_EXPIRED / ENTITLEMENT_REVOKED); amount is a signed non-zero integer (positive → `increase_allowance`, negative → `decrease_allowance`; no business maximum); optional expectedVersion → CONCURRENT_MODIFICATION when stale; a reduction must keep effective ≥ committed (ALLOWANCE_BELOW_COMMITTED_USAGE) and ≥ committed + reserved (ALLOWANCE_CONFLICTS_WITH_ACTIVE_RESERVATION). The only write is one `entitlement_allowance_adjustments` row — the SUB-12 trigger moves `allowance_adjustment_total` and bumps `version`; `usage_ledger` is never touched — plus exactly one audit event. Idempotent on (entitlement, key) with `replayed`. Returns the consumer resolver's figures. |
| Edge Function (WA-8) | `admin-adjust-salon-pilot-allowance` (`verify_jwt = true`) | Same double gate and parse/map path as WA-7 (`_shared/admin_mutations.ts`). |
| Flutter (WA-8) | `lib/admin/salon_pilot/` (adjust controller + page) | `/users/:userId/adjust-allowance`: +5 / +10 quick actions or a custom signed amount, required reason, informational preview (current → new effective, committed, reserved, new remaining/available, based-on version) with an advisory warning for an unsafe reduction, confirm → the server's authoritative state. Entry: **Adjust allowance** on user detail, shown only for an admin-granted Salon Pilot. |
| Database (WA-9) | `public.admin_extend_salon_pilot_expiration(...)` and `public.admin_set_salon_pilot_lifecycle(...)` (migration `20261001000100_admin_salon_pilot_lifecycle.sql`) | Roster-checked, per-account and row-locked lifecycle writers for admin-granted Salon Pilot only. Extension requires a future timestamp later than the current expiration. Allowed status transitions are active/grace → suspended, suspended → active while unexpired, and active/grace/suspended → revoked. Revocation is terminal. Expected version rejects stale writes; audit-backed idempotency replays the same intent and conflicts on key reuse. Each success writes exactly one immutable audit event. Store-backed and Free targets are refused without mutation. Usage and historical content are never rewritten or deleted. |
| Edge Function (WA-9) | `admin-salon-pilot-lifecycle` (`verify_jwt = true`) | `requireAdmin` and the caller JWT form the same double gate as WA-7/WA-8. Dispatches the approved action vocabulary to the two lifecycle writers, mints a correlation ID, and logs identifiers/outcomes only—never reason text, JWTs, provider data, or private FaceTune content. No service-role key. |
| Flutter (WA-9) | `lib/admin/salon_pilot/` (lifecycle controller + page) | Protected per-user routes for expiration extension, suspend, reactivate, and revoke. User detail exposes state-appropriate controls only for an admin-granted Salon Pilot; provider-backed entitlements receive none. Every flow requires a reason and Preview → Confirm, freezes version/key/date at preview, reuses the key on retry, and displays the server result. Revoke additionally requires an explicit irreversible-action acknowledgement and an unambiguous **Revoke access** confirmation. |
| Database (WA-10) | `public.admin_list_audit_events(...)`, `public.admin_get_audit_event(uuid)`, `public.admin_list_entitlement_history(uuid, text)` (migration `20261002000100_admin_audit_and_entitlement_history.sql`) | Roster-checked, read-only inspection. Audit list uses fixed newest-first keyset pages of 25 with filter-bound cursors and filters by admin, canonical action, target user, target entitlement, source, and half-open date range. Detail projects snapshots through a six-field allowlist. History merges entitlement-scoped admin events with successfully processed provider lifecycle events, sorted by authoritative event time. Provider message IDs, purchase references, notification types, and payloads never leave Postgres. Snapshot constraints prevent future writers from storing arbitrary JSON. No client receives table access and no WA-10 function writes data. |
| Flutter (WA-10) | `lib/admin/audit/` | `/audit` filterable list, `/audit/:eventId` immutable detail, and `/entitlements/:entitlementId/history` readable lifecycle timeline. Entitlement and user pages link into the history/audit views. All decoders fail closed; the UI has no audit edit, delete, or rewrite controls. |
| Flutter (WA-3) | `lib/admin/shell/` | The protected shell: navigation rail (drawer below 760 px), identity + sign-out, and five live sections — Dashboard `/dashboard`, Users `/users`, Entitlements `/entitlements`, Usage `/usage`, Audit `/audit`. A refresh or sign-in returns to the protected section/detail route that was open (`?from=`, exact validated paths only). |

Admin authority is a database row, not a JWT claim, so revoking it takes
effect on the revoked account's next request — no token refresh, no new
build. The Flutter admin also re-asks the server on every token refresh.

## Provisioning an administrator

There is no grant UI and no grant RPC. An administrator is provisioned by the
project operator, as the database owner, in the Supabase SQL editor or via
`supabase db query --linked`:

```sql
-- Grant. The account must already exist (sign up through the consumer app or
-- create it in Authentication → Users), must not be anonymous, and must not be
-- soft-deleted; the trigger refuses otherwise.
insert into public.admin_users (user_id, note)
select id, 'bootstrap'
  from auth.users
 where email = '<the administrator''s email>'
   and is_anonymous = false;
```

```sql
-- Revoke. Takes effect on the next request. The row stays as history.
update public.admin_users
   set revoked_at = timezone('utc', now()),
       revoked_by = (select id from auth.users where email = '<your email>')
 where user_id = (select id from auth.users where email = '<their email>')
   and revoked_at is null;
```

```sql
-- Who is an admin right now.
select u.email, a.granted_at, a.note
  from public.admin_users a
  join auth.users u on u.id = a.user_id
 where a.revoked_at is null
 order by a.granted_at;
```

Email is used above only to *find* the account. Nothing in the application
compares an email to decide anything.

Do not create the admin account as an anonymous guest and do not use a
shared mailbox: the admin is an ordinary Supabase Auth user with a strong
password. Enable email confirmation and, when available for the project,
MFA in Authentication settings before production use.

## Deploying the backend

```powershell
supabase db push          # 20260925000100 through 20261002000100
supabase functions deploy admin-session
supabase functions deploy admin-grant-salon-pilot
supabase functions deploy admin-adjust-salon-pilot-allowance
supabase functions deploy admin-salon-pilot-lifecycle
```

`admin-session` needs no new secret: it reads `SUPABASE_URL` and
`SUPABASE_ANON_KEY`, which the platform provides. Never pass
`--no-verify-jwt`.

Verify after deploying (replace the token with an admin's access token from a
signed-in Flutter session; never a service-role key):

```powershell
curl -X POST "https://usmlwaocafeqnspdsvmv.supabase.co/functions/v1/admin-session" `
  -H "Authorization: Bearer <admin access token>" -H "apikey: <publishable key>"
# → 200 {"ok":true,"contractVersion":"subscription_admin_contract_v1.1","admin":{...}}
# A normal user's token → 403 {"error":{"code":"ADMIN_UNAUTHORIZED",...}}
# No token             → 401
```

## Running and building the Web Admin

Same configuration files as the consumer app (`config/*.json`, git-ignored,
public URL + publishable key only):

```powershell
# Develop
flutter run -d chrome -t lib/admin_main.dart --dart-define-from-file=config/development.json

# Build
flutter build web -t lib/admin_main.dart --dart-define-from-file=config/production.json
# → build/web/
```

URLs use Flutter's default hash strategy (`/#/users`), so the bundle works on
any static host without rewrite rules; a path strategy can be adopted once a
host is chosen.

The bundle must be hosted at its own origin (not inside the consumer app),
and that origin must be added to Supabase Authentication → URL
Configuration → Site URL / Redirect URLs before password sign-in will
persist a session in the browser. Hosting provider is not chosen by WA-2.

## Tests

```powershell
flutter test test/admin                     # controller, gateway, router/pages, source-scan security contract
cd supabase/functions; deno test --allow-env --allow-net _shared/admin_auth_test.ts _shared/admin_mutations_test.ts
supabase test db --local                    # includes WA-2 through WA-11 pgTAP suites
bash supabase/tests/controlled/wa11_admin_concurrency.sh   # two-session admin races (local stack up)
```

## Concurrency, idempotency and stale writes (WA-11)

Every privileged admin writer (`admin_grant_salon_pilot`,
`admin_adjust_salon_pilot_allowance`, `admin_extend_salon_pilot_expiration`,
`admin_set_salon_pilot_lifecycle`) and the usage engine
(`reserve_ai_look` / `commit_ai_look` / `release_ai_look`, and the
adjustment ledger trigger) serialize on the same per-account advisory lock
(`pg_advisory_xact_lock(hashtextextended(user_id, 0))`). Idempotency is a
database uniqueness fact — `(entitlement_id, idempotency_key)` on the
adjustment ledger and `(target_user_id, action, idempotency_key)` on the
audit table — and every writer answers a repeated key with the original
result and `replayed: true`. `expectedVersion`, when the browser supplies
it, is compared under the lock and a mismatch is `CONCURRENT_MODIFICATION`.

What is proven where:

| Scenario | Database-level proof | Live / manual |
| --- | --- | --- |
| Admin double-clicks +10 | pgTAP S1 (applies once); harness R1 (two overlapping sessions, one replay, one ledger row, one audit) | — |
| Two admins, A +10 and B +5 | pgTAP S2; harness R2 (B waits on the lock, sees A's change; total 15, version +2, two audits) | — |
| Stale write (both on the same version) | pgTAP S3; harness R3 (first applies, second `CONCURRENT_MODIFICATION`, nothing lost) | — |
| User reserves while admin reduces | pgTAP S4; harness R4a/R4b in both lock orders: a reduction that would strand a hold is refused, a reservation after a reduction to the floor is refused, available is never negative | — |
| Suspend during generation | pgTAP S5; harness R5: the in-flight reservation survives, no new reservation may start, the already-authorized work still commits (reservation-time attribution, the engine's existing rule; nothing cancels running server work) | — |
| Network timeout, client retries | pgTAP S0/S3 (same key → replay); Flutter controller tests prove a retry reuses the same key and version and that a second confirm while submitting sends nothing | HTTP-level retry through the Edge Function against a deployed instance |
| Revoke duplicate | pgTAP S6; harness R6 (one revocation, one audit, one replay); harness R7 for a duplicate grant | — |
| Audit accuracy | pgTAP S7: one event per applied mutation in version order, none for replays or refusals; row version = number of applied mutations; total = ledger sum | — |

No new backend or frontend hardening was needed: every scenario passed
against the deployed WA-7–WA-9 writers as they were. What remains
live-only is the HTTP layer (Edge Function timeout + browser retry), which
reuses the same key and therefore the same database guarantees.

## Hard locks (enforced by tests)

- No `service_role` string under `lib/admin/` or in `admin-session` / `admin_auth.ts`.
- No email, UUID, or password literal under `lib/admin/`.
- No `localStorage` / `SharedPreferences` / JWT-claim / `app_metadata` inspection under `lib/admin/`.
- `AdminAuthorized` is constructed in exactly one place, from the gateway's answer.
- The consumer entrypoint, router, and features never import the admin tree.
- `admin_users` is unreadable by `anon`, `authenticated`, and `service_role`; `is_admin(uuid)` is not executable by `authenticated`.
- WA-5 search is exact-only, fixed at 25 rows, cursor-paginated, and ordered by account creation time plus User ID.
- WA-5 list/detail JSON key sets are asserted exactly and scanned for prohibited facial, storage, prompt, Gemini, and makeup-kit data.
- WA-6 listings are fixed at 25 rows, cursor-paginated newest first, and refuse a cursor issued for different filters; every filter value is validated against the Shared Contract vocabulary on the server.
- WA-6 row key sets are asserted exactly; usage rows expose `sourceMode` and whether the preview row still exists, never an image id, and a released row is distinguishable from a committed one by `releasedAt` / `sanitizedFailureCode` (never a renamed state).
- WA-7: the grant is refused for non-admins and anonymous callers before any row is read; a duplicate submission creates no second entitlement and no second audit event; audit rows cannot be edited, re-timestamped, or re-attributed; no client role can read or write `admin_audit_events`; the writer is not executable by `anon` or `service_role`.
- WA-8: an adjustment is applied only through `entitlement_allowance_adjustments`; the writer never sets `allowance_adjustment_total` or touches `usage_ledger`; a reduction below committed usage or below committed + reserved is refused with its contract code; a stale expected version is refused; a duplicate submission applies once; every applied adjustment has exactly one audit event.
- WA-9: unauthenticated and normal-user lifecycle calls are denied; the entitlement owner cannot mutate their own lifecycle; Free and provider-backed rows are refused; suspended/revoked Pilot cannot fund a new generation; existing usage/content remains; a valid suspended Pilot can reactivate but an expired one cannot; revocation is terminal while the account may still fall back to another legitimate entitlement; stale versions are refused; retries replay and every applied lifecycle action is audited exactly once.
- WA-10: audit/history reads are denied to unauthenticated and normal users; lists are fixed at 25 rows and cursors are bound to their filters; lifecycle events are newest-first across admin and provider sources; a duplicate mutation remains one event; persisted and returned snapshots contain only status, plan, effective allowance, adjustment total, expiration, and version; provider message IDs and purchase references are absent; the UI exposes no ordinary audit mutation control.
