# Web Admin setup (WA-2 through WA-6)

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
| Flutter (WA-3) | `lib/admin/shell/` | The protected shell: navigation rail (drawer below 760 px), identity + sign-out, and one placeholder per section — Dashboard `/dashboard`, Users `/users`, Entitlements `/entitlements`, Usage `/usage`, Audit `/audit`. A refresh or a sign-in returns to the section that was open (`?from=`, exact section paths only). |

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
supabase db push          # 20260925000100 through 20260928000100
supabase functions deploy admin-session
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
cd supabase/functions; deno test --allow-env --allow-net _shared/admin_auth_test.ts
supabase test db --local                    # includes WA-2, WA-4, WA-5, and WA-6 pgTAP suites
```

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
