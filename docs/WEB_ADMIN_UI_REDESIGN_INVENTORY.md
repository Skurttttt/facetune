# Web Admin UI Redesign Inventory (WA-13.5-UI-0)

**Phase:** WA-13.5-UI-0 - Existing UI & Data Contract Inventory
**Branch:** `feature/web-admin-ui-redesign-v1`
**Baseline HEAD:** `852623c9a5945fdf663f02526721ce4c6849c6e8`
**Date:** 2026-09-24
**Status:** Inventory only. No production code, dependency, backend, or mobile change.

---

# 1. DOCUMENT PURPOSE

This document freezes the exact Web Admin presentation surface and the exact
server read contracts that exist at the WA-13.5 baseline, so that UI-1 through
UI-15 never have to guess what exists.

It answers four questions with evidence from source, not documentation:

1. What screens, routes and presentation components exist today?
2. Which styling is Web-Admin-only, and which is shared with the consumer app
   (and therefore carries mobile regression risk)?
3. What is visually wrong today, stated as a baseline rather than a complaint?
4. Which Dashboard V2 metrics and chart series can be drawn from data the
   server already returns authoritatively - and which cannot?

Nothing in this document authorizes an implementation. Every recommendation is
a constraint for a later phase, not a decision already taken.

---

# 2. AUTHORITY POSITION

Authority order applied while producing this inventory:

1. `CODEX_MASTER_GUIDE.md`
2. Protected FaceTune Final Preview / Tutorial V4 / My Makeup Kit authorities
3. `FACETUNE_SUBSCRIPTION_SOURCE_OF_TRUTH.md`
4. `FACETUNE_SUBSCRIPTION_EXPANSION_SOURCE_OF_TRUTH.md`
5. `FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md`
6. `FACETUNE_WEB_ADMIN_SOURCE_OF_TRUTH.md`
7. `FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md`
8. `FACETUNE_WEB_ADMIN_UI_REDESIGN_SOURCE_OF_TRUTH.md`
9. `FACETUNE_WEB_ADMIN_UI_REDESIGN_PHASE_PROMPTS.md`
10. Repository implementation (migrations, Dart source, tests)

**Authority conflicts found: NONE.**

The UI redesign authorities subordinate themselves correctly (UI SOT section 2)
and claim presentation authority only. Two observations that are *not*
conflicts but that UI-1..UI-15 must carry:

- The UI SOT's design direction ("Operational Dark SaaS", section 7) is a
  narrowing of, not a contradiction of, Web Admin SOT section 55 ("professional,
  restrained, information-dense, desktop-first"). The parent authority does not
  mandate a light theme, so a pinned dark admin theme is permitted.
- The UI SOT's canonical navigation order (section 11) is identical to Web Admin
  SOT section 54. No navigation item may be added or removed by WA-13.5.

---

# 3. REPOSITORY BASELINE

| Fact | Value |
|---|---|
| Branch | `feature/web-admin-ui-redesign-v1` |
| HEAD | `852623c9a5945fdf663f02526721ce4c6849c6e8` |
| HEAD subject | WA-13.5 correct UI redesign branch authority |
| Upstream | `origin/feature/web-admin-ui-redesign-v1`, 0 ahead / 0 behind |
| Working tree at phase start | clean |
| Admin Dart files | 76 under `lib/admin/`, plus `lib/admin_main.dart` |
| Admin presentation LOC | 7,812 lines across router, shell, pages and controllers |
| Admin test files | 24 under `test/admin/`, 7,483 lines, 240 tests passing |
| Admin entrypoint | `lib/admin_main.dart` -> `FaceTuneAdminApp` |
| Migrations | 43, latest `20261004000100_admin_salon_pilot_research.sql` |

---

# 4. WEB ADMIN ROUTE INVENTORY

18 `GoRoute` declarations in `lib/admin/app/admin_router.dart`, plus `/` which
has no route of its own and is resolved entirely by the redirect.

Routing is navigation, not security: every destination is gated by
`redirectFor()`, a pure function of the server-derived authorization state.

## 4.1 Public routes (no authorized admin session)

| Route | Screen | Purpose | Data source | Actions | State | Responsive | Redesign relevance | Protected behavior |
|---|---|---|---|---|---|---|---|---|
| `/` | none | Initial location; always redirected | none | none | `redirectFor` | n/a | None - never renders | Must keep redirect-only |
| `/login` | `AdminLoginPage` | Email/password sign-in | Supabase Auth via `AdminAuthorizationController` | sign in | `adminAuthorizationControllerProvider` | `maxWidth: 400` centered | High - first impression, form system | Auth flow, `?from=` carry-through |
| `/loading` | `AdminLoadingPage` | Server has not answered yet | none | none | same | centered | Medium - bootstrap state | Nothing privileged may render |
| `/unauthorized` | `AdminUnauthorizedPage` | Signed in, not on the admin roster | none | sign out | same | `maxWidth: 480` centered | Medium | Must not leak why |

## 4.2 Protected section routes (inside `AdminShell`)

| Route | Screen | Purpose | Data source (RPC) | Actions | State | Responsive | Redesign relevance | Protected behavior |
|---|---|---|---|---|---|---|---|---|
| `/dashboard` | `AdminDashboardPage` | Operational overview | `admin_dashboard_metrics()` | refresh, link to research | `adminDashboardControllerProvider` | tiles wrap; shell `maxWidth: 1280` | **Highest** - Dashboard V2 target | Server counts only, nothing derived |
| `/dashboard/salon-pilot` | `AdminSalonPilotResearchPage` | WA-13 pilot research | `admin_salon_pilot_research_metrics()`, `admin_list_salon_pilot_metrics(text)` | refresh, paginate | `adminResearchControllerProvider`, `adminPilotMetricsControllerProvider` | horizontal table scroll | High - pilot progress bars | Cost stays "Not available" |
| `/users` | `AdminUsersPage` | Exact-match account lookup | `admin_search_users(...)` | search, paginate, open detail | `adminUsersControllerProvider` | horizontal table scroll | High - table system | Exact-match only; rate-limited |
| `/entitlements` | `AdminEntitlementsPage` | Entitlement list + filters | `admin_list_entitlements(...)` | filter, apply/clear, paginate | `adminEntitlementsControllerProvider` | horizontal table scroll | High - filter + table system | 25-row keyset; cursor bound to filters |
| `/usage` | `AdminUsagePage` | Usage ledger list + filters | `admin_list_usage(...)` | filter, apply/clear, paginate | `adminUsageControllerProvider` | horizontal table scroll | High | 25-row keyset; no image ids |
| `/audit` | `AdminAuditPage` | Admin audit log + filters | `admin_list_audit_events(...)` | filter, paginate, open detail | `adminAuditControllerProvider` | horizontal table scroll | High | Immutable; no edit control may appear |

## 4.3 Protected detail and workflow routes

| Route | Screen | Purpose | Data source | Actions | Redesign relevance | Protected behavior |
|---|---|---|---|---|---|---|
| `/users/:userId` | `AdminUserDetailPage` | One account, plan, allowance | `admin_get_user(uuid)` | navigate to workflows/related lists | High - detail layout | Privacy-minimal fields only |
| `/audit/:eventId` | `AdminAuditDetailPage` | One immutable audit event | `admin_get_audit_event(uuid)` | none | Medium | No mutation control |
| `/entitlements/:entitlementId/history` | `AdminEntitlementHistoryPage` | Lifecycle timeline | `admin_list_entitlement_history(...)` | paginate | Medium | No provider message ids |
| `/users/:userId/grant-salon-pilot` | `AdminGrantSalonPilotPage` | WA-7 grant workflow | `admin_get_user` + Edge `admin-grant-salon-pilot` | preview, confirm | High - form + confirmation | Idempotency key reused on retry |
| `/users/:userId/adjust-allowance` | `AdminAdjustAllowancePage` | WA-8 allowance adjustment | `admin_get_user` + Edge `admin-adjust-salon-pilot-allowance` | preview, confirm | High | `expectedVersion` stale-write guard |
| `/users/:userId/extend-expiration` | `AdminLifecyclePage` | WA-9 extend | Edge `admin-salon-pilot-lifecycle` | preview, confirm | High | Version + idempotency |
| `/users/:userId/suspend-entitlement` | `AdminLifecyclePage` | WA-9 suspend | same | preview, confirm | High | Version + idempotency |
| `/users/:userId/reactivate-entitlement` | `AdminLifecyclePage` | WA-9 reactivate | same | preview, confirm | High | Expired pilot cannot reactivate |
| `/users/:userId/revoke-entitlement` | `AdminLifecyclePage` | WA-9 revoke | same | stronger confirm | High - destructive hierarchy | Terminal; high-friction confirm |

## 4.4 Routing behaviors that constrain the redesign

- **Return-to (`?from=`)**: `AdminRoutes.sanitizedReturnTo()` accepts only exact
  section paths, `/dashboard/salon-pilot`, user detail, user action, audit
  detail and entitlement history paths. Any new route added by the redesign that
  should survive a refresh must be added there; the redesign is not expected to
  add routes.
- **No `errorBuilder` is configured.** An unknown path is not a 404 screen: the
  redirect runs first, so an authorized admin is sent to `/dashboard` and an
  unauthenticated visitor to `/login`. UI-11 must not invent a 404 state without
  authorization, and must not assume one exists.
- **The shell is composed per route, not via `ShellRoute`.** This is deliberate
  (documented in `admin_router.dart`): a nested Navigator makes the rail
  unreachable by keyboard. UI-2/UI-3 must preserve the single-Navigator
  composition.

---

# 5. SCREEN INVENTORY

16 page widgets exist; 15 are reachable, 1 is dead code.

| # | Screen | File | Reachable | Notes |
|---|---|---|---|---|
| 1 | `AdminLoginPage` | `auth/presentation/pages/admin_login_page.dart` (162) | yes | Centered card, `maxWidth: 400` |
| 2 | `AdminLoadingPage` | `auth/presentation/pages/admin_loading_page.dart` | yes | Bootstrap only |
| 3 | `AdminUnauthorizedPage` | `auth/presentation/pages/admin_unauthorized_page.dart` (86) | yes | `maxWidth: 480` |
| 4 | `AdminShell` | `shell/admin_shell.dart` (281) | yes | Frame: rail / drawer, top bar, content |
| 5 | `AdminDashboardPage` | `dashboard/presentation/pages/admin_dashboard_page.dart` (510) | yes | 4 tile groups + plan table |
| 6 | `AdminSalonPilotResearchPage` | `research/presentation/pages/admin_salon_pilot_research_page.dart` (659) | yes | WA-13; largest page |
| 7 | `AdminUsersPage` | `users/presentation/pages/admin_users_page.dart` (309) | yes | Carries the encoding defect |
| 8 | `AdminUserDetailPage` | `users/presentation/pages/admin_user_detail_page.dart` (388) | yes | Carries the encoding defect |
| 9 | `AdminEntitlementsPage` | `entitlements/presentation/pages/admin_entitlements_page.dart` (406) | yes | Filters + table |
| 10 | `AdminUsagePage` | `usage/presentation/pages/admin_usage_page.dart` (416) | yes | Filters + table |
| 11 | `AdminAuditPage` | `audit/presentation/pages/admin_audit_page.dart` (346) | yes | Filters + table |
| 12 | `AdminAuditDetailPage` | `audit/presentation/pages/admin_audit_detail_page.dart` (222) | yes | Only page with a `LayoutBuilder` |
| 13 | `AdminEntitlementHistoryPage` | `audit/presentation/pages/admin_entitlement_history_page.dart` (221) | yes | Timeline |
| 14 | `AdminGrantSalonPilotPage` | `salon_pilot/presentation/pages/admin_grant_salon_pilot_page.dart` (483) | yes | Preview-before-confirm |
| 15 | `AdminAdjustAllowancePage` | `salon_pilot/presentation/pages/admin_adjust_allowance_page.dart` (558) | yes | Preview-before-confirm |
| 16 | `AdminLifecyclePage` | `salon_pilot/presentation/pages/admin_lifecycle_page.dart` (606) | yes | One widget, four actions |
| - | `AdminSectionPlaceholderPage` | `shell/admin_section_placeholder_page.dart` (59) | **NO** | Unreferenced since WA-10; dead code |

**Dead code note:** `AdminSectionPlaceholderPage` has zero references in `lib/`
and `test/`. Deleting it is a reasonable UI-14 cleanup, but it is not authorized
here and is not required by the redesign.

---

# 6. PRESENTATION COMPONENT INVENTORY

The Web Admin has a *partial* shared presentation layer: seven widgets in
`lib/admin/shared/admin_list_widgets.dart` (212 lines). Everything else is
composed from raw Material widgets and private `_Xxx` classes inside each page,
which is the main source of visual inconsistency.

## 6.1 Genuinely shared admin components

| Component | File | Admin-only / shared | Current users | Visual responsibility | Mobile impact risk | Redesign candidate |
|---|---|---|---|---|---|---|
| `AdminListLoadingRow` | `shared/admin_list_widgets.dart` | Admin-only | list pages | Inline loading row | None | YES |
| `AdminListNotice` | same | Admin-only | list pages | Empty / no-result / error notice | None | YES |
| `AdminStatusBadge` | same | Admin-only | all tables | Status chip | None | YES - becomes `StatusBadge` |
| `AdminIdCell` | same | Admin-only | all tables | Shortened UUID cell | None | YES - identity hierarchy |
| `AdminPaginationBar<T,F>` | same | Admin-only | all list pages | Pagination controls | None | YES |
| `AdminFilterSlot` | same | Admin-only | filter panels | Fixed-width (220) filter slot | None | YES - fixed width is a defect source |
| `AdminSectionHeading` | same | Admin-only | several pages | Section heading | None | YES |
| `AdminKeysetListController<T,F>` | `shared/admin_keyset_list_controller.dart` | Admin-only | 5 list surfaces | Pagination *behavior* (not visual) | None | NO - behavior, must not change |
| `AdminShell` | `shell/admin_shell.dart` | Admin-only | every protected route | Rail/drawer, top bar, content frame | None | YES - UI-2/UI-3 |

## 6.2 Components that do NOT exist and must be created by UI-1..UI-8

Absent from the codebase entirely, despite the UI SOT section 13 naming them:

`AdminPageShell`, `AdminSidebar`, `AdminHeader`, `PageHeader`, `PrimaryButton`,
`SecondaryButton`, `DestructiveButton`, `AdminCard`, `StatCard`, `AdminTable`,
`SearchField`, `FilterControl`, `EmptyState`, `ErrorState`, `LoadingState`,
`AdminDialog`, `ConfirmationDialog`, `AdminTextField`, `AdminDropdown`,
`AdminDateField`, `AdminChartCard`, `PilotUsageProgress`.

Consequence: **UI-1/UI-6/UI-7/UI-8 are genuinely additive component work**, not
restyling of existing shared widgets. Each page currently re-implements its own
private `_Panel`, `_Tile`, `_Group`, `_Field` and similar classes.

## 6.3 Per-page private widgets (the inconsistency surface)

Each page defines its own private presentation classes. Representative examples:

- Dashboard: `_Loading`, `_Empty`, `_Unavailable`, `_Metrics`, `_Group`,
  `_Tile`, `_Panel`, `_PlanTable`
- Research: its own stat tiles, section cards and table
- Grant / Adjust / Lifecycle: their own field, preview and confirmation blocks

These are the direct cause of defects D-01, D-05 and D-07 in section 8.

## 6.4 Tables

All five tables use Material `DataTable` inside
`Scrollbar > SingleChildScrollView(scrollDirection: Axis.horizontal)`:

`admin_users_page.dart:162`, `admin_entitlements_page.dart:262`,
`admin_usage_page.dart:288`, `admin_audit_page.dart:276`,
`admin_salon_pilot_research_page.dart:512`.

Horizontal overflow is therefore already contained **inside the table region**
rather than at page level. This is better than the UI SOT's baseline assumption
and should be preserved rather than rebuilt.

---

# 7. THEME / MOBILE-SHARING RISK INVENTORY

This is the highest-risk finding in the inventory.

## 7.1 How Web Admin styling is produced today

`lib/admin/app/admin_app.dart`:

```dart
theme: AppTheme.lightTheme,
darkTheme: AppTheme.darkTheme,
themeMode: ThemeMode.system,
```

The Web Admin uses **the consumer application's ThemeData, unmodified**, and
follows the operating system's light/dark preference. The same two objects are
used by the consumer app in `lib/app/app.dart:23-24`.

## 7.2 Classification

### SHARED / HIGH MOBILE REGRESSION RISK - DO NOT MODIFY DIRECTLY

| Surface | File | Evidence |
|---|---|---|
| `AppTheme.lightTheme` / `AppTheme.darkTheme` | `lib/theme/app_theme.dart` (13,892 bytes) | Used by BOTH `lib/app/app.dart:23-24` (consumer) and `lib/admin/app/admin_app.dart:23-24` (admin) |
| `AppColors` | `lib/theme/app_tokens.dart:19` | Feeds the shared `ColorScheme` |
| `AppTypography` | `lib/theme/app_typography.dart` | Feeds the shared text theme |
| `AppSemantics` | `lib/theme/app_semantics.dart` | Consumer semantic colors |

Any edit to these files changes the consumer Android/iOS app. **WA-13.5 must not
touch them.**

### SHARED BUT VISUALLY ISOLATABLE - CREATE AN ADMIN-SPECIFIC ABSTRACTION

| Surface | Usage in admin | Usage outside admin | Note |
|---|---|---|---|
| `AppSpacing` (`lib/theme/app_tokens.dart:100`) | 168 references across 16 admin files: `sm` x58, `md` x37, `xs` x32, `lg` x26, `xxs` x13, `xl` x2 | Imported by 78 non-admin Dart files | Admin consumes constants read-only. Changing a value would move the mobile layout. |

`AppSpacing` values today: `xxs 4, xs 8, sm 12, md 16, lg 24, xl 32, xxl 48,
gutter 20`. The UI SOT section 10 requires the scale `4/8/12/16/20/24/32/40/48`
- **20 and 40 do not exist as steps**. An admin-owned spacing scale is therefore
required; extending `AppSpacing` would edit a file 78 consumer files depend on.

`AppRadii` today: `sm 12, md 18, lg 24, xl 32, pill 999`. The UI SOT requires
`6 / 8 / 10`. The admin currently uses **zero** `AppRadii` references, so an
admin radius scale can be introduced with no shared-file contact at all.

### ADMIN-ONLY - SAFE TO REDESIGN

Everything under `lib/admin/` except the imports listed above: all 16 pages, the
shell, the 7 shared admin widgets, and all private per-page widgets.

## 7.3 Mandatory consequence for UI-1

UI-1 must introduce an **admin-owned theme and token set** (for example
`lib/admin/theme/`), and `FaceTuneAdminApp` must stop consuming
`AppTheme.lightTheme` / `AppTheme.darkTheme`. Two further points:

1. `themeMode: ThemeMode.system` means the admin currently renders light on a
   light-mode machine. "Operational Dark SaaS" requires a **pinned** admin
   theme; this is a change to `admin_app.dart` only and touches no shared file.
2. The 168 `AppSpacing` references inside `lib/admin/` should migrate to the
   admin scale. That is a mechanical, admin-only change - but it is UI-1 work,
   not UI-0 work, and is listed here so UI-1 can size it.

---

# 8. CURRENT VISUAL DEFECT BASELINE

Defects are classified **CONFIRMED** (proven from source at this HEAD),
**INFERRED** (strongly implied by source but not visually verified), or
**NEEDS REAL BROWSER VERIFICATION**.

| ID | Area | Defect | Class | Evidence |
|---|---|---|---|---|
| D-01 | Encoding | Mojibake in UI-visible strings | **CONFIRMED** | 5 occurrences, 2 files - see 8.1 |
| D-02 | Theme | Admin follows OS light/dark and uses the consumer theme | **CONFIRMED** | `admin_app.dart:23-25` |
| D-03 | Hierarchy | Page title duplicated: shell top bar renders the section label AND each page renders its own heading | **CONFIRMED** | `admin_shell.dart:171` (`admin-section-title`) + `admin_dashboard_page.dart:37` |
| D-04 | Spacing | No page-level padding scale: content padding is a single `EdgeInsets.all(AppSpacing.lg)` = 24px at every width | **CONFIRMED** | `admin_shell.dart:200` |
| D-05 | Components | No shared card/stat/button/field system; each page defines private equivalents | **CONFIRMED** | Section 6.3 |
| D-06 | Layout | Content is capped at `maxWidth: 1280` and left-aligned, so a wide display shows a large empty right region | **CONFIRMED** | `admin_shell.dart:203-206` |
| D-07 | Filters | Filter controls are fixed at 220px via `AdminFilterSlot(width: 220)` regardless of content or viewport | **CONFIRMED** | `admin_list_widgets.dart:177` |
| D-08 | Typography | Hierarchy comes from Material defaults (`headlineSmall`, `titleMedium`, `bodyMedium`) tuned for a consumer beauty app, not a dense console | **CONFIRMED** | Page sources; shared `AppTypography` |
| D-09 | Tables | Long UUIDs compete with email for scanning priority; `AdminIdCell` shortens but is still a full column | **CONFIRMED** | `admin_list_widgets.dart:122`, table column lists |
| D-10 | Tables | `DataTable` default row height is used everywhere; no deliberate density decision | **CONFIRMED** | No `dataRowMinHeight`/`headingRowHeight` anywhere in `lib/admin/` |
| D-11 | Buttons | Primary/secondary/destructive distinction is Material default; revoke uses the same button family as benign actions | **INFERRED** | Lifecycle page uses standard buttons; no destructive color role applied |
| D-12 | Color | Semantic status colors come from the consumer scheme; the accent is the consumer rose | **INFERRED** | Shared `ColorScheme` via `AppTheme` |
| D-13 | Dashboard | Metrics are a flat list of tile groups plus one plan table; no visual grouping weight, no charts | **CONFIRMED** | `admin_dashboard_page.dart:196-290` |
| D-14 | Loading | Dashboard loading is a spinner + text row, not skeletons | **CONFIRMED** | `admin_dashboard_page.dart:96-110` |
| D-15 | Responsive | Only two breakpoints exist for the whole application (1100 / 760) | **CONFIRMED** | `admin_shell.dart:29-30` |
| D-16 | Responsive | Behavior at 1366 / 1024 / 768 is untested in a browser | **NEEDS REAL BROWSER VERIFICATION** | No browser evidence exists at this HEAD |
| D-17 | A11y | Focus ring styling is Material default; no admin focus token | **NEEDS REAL BROWSER VERIFICATION** | No focus theme in `lib/admin/` |
| D-18 | A11y | Contrast of secondary text on admin surfaces is unmeasured | **NEEDS REAL BROWSER VERIFICATION** | Derived from consumer palette |

## 8.1 Encoding defect - exact findings

Five UI-visible string literals contain double-encoded UTF-8 (a UTF-8 sequence
decoded as CP1252 and re-encoded as UTF-8). Confirmed at byte level with `od`:

| File | Line | Intended | Bytes present | Should be |
|---|---|---|---|---|
| `lib/admin/users/presentation/pages/admin_users_page.dart` | 113 | `Loading accounts...` | `c3 a2 e2 82 ac c2 a6` | `e2 80 a6` (U+2026) |
| `lib/admin/users/presentation/pages/admin_users_page.dart` | 245 | em dash placeholder | `c3 a2 e2 82 ac e2 80 9d` | `e2 80 94` (U+2014) |
| `lib/admin/users/presentation/pages/admin_users_page.dart` | 251 | em dash placeholder | same as above | `e2 80 94` |
| `lib/admin/users/presentation/pages/admin_users_page.dart` | 299 | ellipsis in shortened id | `c3 a2 e2 82 ac c2 a6` | `e2 80 a6` |
| `lib/admin/users/presentation/pages/admin_user_detail_page.dart` | 82 | `Loading user detail...` | `c3 a2 e2 82 ac c2 a6` | `e2 80 a6` |

**Scope is exactly two files, both from WA-5.** Every other admin file uses the
correct glyphs (for example `admin_dashboard_page.dart` contains three correct
U+2026/U+2014 characters). The corruption is therefore **presentation-layer
source only** - it is not stored backend data, so the UI SOT section 26
boundary is not reached and no database rewrite is implicated.

**Not corrected in UI-0** (inventory phase). Correction belongs to UI-9 or
UI-14.

---

# 9. CURRENT DASHBOARD INVENTORY

**File:** `lib/admin/dashboard/presentation/pages/admin_dashboard_page.dart` (510 lines)
**Controller:** `adminDashboardControllerProvider`
**Server source:** `public.admin_dashboard_metrics()` (migration `20260926000100`),
single argument-free call, `stable security definer`, `is_admin(auth.uid())`
checked inside, `authenticated`-callable only.

## 9.1 Current structure

```
Dashboard                        [As of YYYY-MM-DD HH:MM UTC]  [Refresh]
"Live counts from the server. Nothing here is estimated."

Accounts      : Users | Anonymous guests
AI Looks      : Committed today | Committed this month | Open reservations
                | Released today | Released this month
                (caption: purchased credits counted apart)
Salon Pilot   : In force | Expiring within 14 days   [Research metrics ->]
Entitlements  : Pending | Suspended | Active purchased-credit grants

In force by plan
<table: one row per canonical plan>
```

## 9.2 Current states

| State | Implementation | Key |
|---|---|---|
| Loading | Spinner + "Loading counts..." | `admin-dashboard-loading` |
| Ready | Tile groups; `Opacity(0.6)` while refreshing | `admin-dashboard-metrics` |
| Empty | Panel: "No accounts exist yet..." (only when `totalUsers == 0 && anonymousGuests == 0`) | `admin-dashboard-empty` |
| Unavailable | Error panel with contract code + Retry when retryable | - |

Refresh is disabled while loading or refreshing. The "As of" timestamp is the
server's `asOf`, rendered in UTC. These behaviors must survive UI-5.

## 9.3 WA-13 research data sources (already authoritative)

`admin_salon_pilot_research_metrics()` returns `pilots`, `aiLooks`, `operations`,
`billableUsage`, `cost`. `admin_list_salon_pilot_metrics(text)` returns 25-row
keyset pages of per-pilot rows. Both are pilot-scoped only.

---

# 10. DASHBOARD V2 TARGET

Reproduced from `FACETUNE_WEB_ADMIN_UI_REDESIGN_SOURCE_OF_TRUTH.md` section 14
as the target UI-5 is expected to build, subject entirely to section 11's data
findings:

```
Dashboard                                   [Last updated] [Refresh]

[ Total Users ] [ Active Paid ] [ Salon Pilot ] [ AI Looks Today ]

AI Look Activity
[ LINE CHART - Committed AI Looks - Last 30 Days ]

Plan / Delivery Distribution        Usage Outcome
[ BAR - Final Previews by Plan ]    [ BAR - Committed vs Released ]

Entitlement Status
[ DONUT / PIE only when the categories form one meaningful current whole ]

Salon Pilot
[ Active pilots ] [ Remaining AI Looks ] [ Expiring soon ]

Pilot Usage
<progress rows: 18 / 30 AI Looks used, remaining, expiry>
```

Charts are permitted on the Dashboard only. Users, Entitlements, Usage and Audit
remain table/filter pages.

---

# 11. DASHBOARD V2 DATA AVAILABILITY MATRIX

Status vocabulary is restricted to exactly four values:
`AVAILABLE_AUTHORITATIVELY`, `MISSING`, `AMBIGUOUS`, `UNSAFE_TO_DERIVE_CLIENT_SIDE`.

| # | Metric / visual | Status | Authoritative source | Server field(s) | Unit | Time scope | Client derivation allowed? | Privacy / security | Next action |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Total Users (card) | `AVAILABLE_AUTHORITATIVELY` | `admin_dashboard_metrics()` | `accounts.totalUsers`, `accounts.anonymousGuests` | accounts | live `asOf` | Render as-is; do NOT add guests to users | Counts only | Use directly; label "Users" (guests are a separate figure) |
| 2 | Active Paid (card) | `AMBIGUOUS` | `admin_dashboard_metrics()` | `entitlements.inForceByPlan` (all 8 plans) | entitlements (not accounts) | live `asOf` | Summing server per-plan counts is presentation arithmetic, but "paid" is not a server-defined set | Counts only | UI-5 must choose a plan set from the Shared Contract and label it exactly; see 11.1 |
| 3 | Salon Pilot (card) | `AVAILABLE_AUTHORITATIVELY` | `admin_dashboard_metrics()` | `salonPilot.inForce`, `salonPilot.expiringSoon`, `expiringSoonWindowDays` | entitlements | live `asOf` | No | Counts only | Use directly |
| 4 | AI Looks Today (card) | `AMBIGUOUS` | `admin_dashboard_metrics()` | `aiLooks.committedToday.subscription`, `.purchasedCredit` | committed usage rows | UTC day from `todayStartsAt` | Must NOT sum the two buckets into one "AI Looks" number | Counts only | See 11.2 - the aggregate does not separate AI Look units from Final Preview Credits |
| 5 | Daily committed AI Looks - 30 days (line) | `MISSING` | none | - | - | - | Rebuilding from `usage_ledger` client-side is forbidden | - | DATA CONTRACT MISSING (B-01) |
| 6 | Daily committed AI Looks - 7 days (line toggle) | `MISSING` | none | - | - | - | No | - | DATA CONTRACT MISSING (B-01); a 7D toggle cannot exist before a 30D series exists |
| 7 | Final Previews delivered by plan (bar) | `MISSING` | none | `entitlements.inForceByPlan` exists but counts ENTITLEMENTS, not deliveries | - | - | No | - | DATA CONTRACT MISSING (B-02) |
| 8 | Entitlement status distribution (donut/pie) | `MISSING` (global) / `AVAILABLE_AUTHORITATIVELY` (pilot-scoped) | `admin_salon_pilot_research_metrics()` for pilots only | `pilots.inForce`, `.suspended`, `.lapsedOrExpired`, `.revoked`, `.entitlements` | entitlements | live `asOf` | No | Counts only | See 11.3 - pie/donut NOT valid globally |
| 9 | Committed vs released (bar) | `AVAILABLE_AUTHORITATIVELY` | `admin_dashboard_metrics()` | `aiLooks.committedToday.*` vs `releasedToday`; `committedThisMonth.*` vs `releasedThisMonth` | usage rows | UTC day / UTC month, both server-defined | Two-bar comparison only; no daily history | Counts only | Usable for a two-bar aggregate; see 11.4 for the bucket caveat |
| 10 | Salon Pilot progress (progress bars) | `AVAILABLE_AUTHORITATIVELY` | `admin_list_salon_pilot_metrics(text)` | `initialAllowance`, `adminAdjustmentsTotal`, `effectiveAllowance`, `committed`, `reserved`, `remaining`, `available`, `expiresAt`, `effectiveStatus` | AI Look allowance units | per grant, all-time | Render server values; no formula | Row carries email + ids only | Use directly - the best-supported Dashboard V2 element |

## 11.1 "Active Paid" - why AMBIGUOUS

`inForceByPlan` is authoritative and complete (every canonical plan key is
present, zero or not) and its in-force predicate is server-defined:

```sql
status in ('active','grace_period')
and starts_at <= now
and (expires_at is null or expires_at > now)
and (period_end is null or period_end > now)
```

So **grace period counts as in force**, by server definition. What the server
does *not* define is which plans are "paid". Resolving this is a labeling
decision for UI-5, constrained by the Shared Contract, not a data gap:

- `free` is not paid.
- `salon_pilot` is `billing_provider = 'admin_granted'` and complimentary - the
  Web Admin SOT section 68 forbids presenting it as a paid public plan, and it
  already has its own card.
- `plus`, `pro`, `salon_pro` are paid AI-Look-unit plans.
- `plus_preview`, `pro_preview`, `salon_preview` are paid public Play plans with
  `allowance_unit = final_preview_credit`.

A card summing all six paid plans is defensible **only if labeled as
entitlements, not accounts**, and only if the label does not imply an AI Look
unit. UI-5 must state the chosen set in its completion report.

## 11.2 "AI Looks Today" - the unit problem

This is the most important finding of the data audit.

`usage_ledger` **does** carry `plan_code` and `allowance_unit` columns
(confirmed against the live local schema). But `admin_dashboard_metrics()`
groups committed rows **only** by `allowance_source` (`subscription` vs
`purchased_credit`, migration `20260926000100` lines 137-153). It does **not**
group by `allowance_unit`.

Therefore `aiLooks.committedToday.subscription` is **every committed row funded
by a subscription** - which includes Final Preview Credit consumption by
`plus_preview`, `pro_preview` and `salon_preview` accounts. It is not an
AI-Look-unit-only figure.

The current UI is aware of the neighboring distinction and handles it well: the
group caption reads "Committed = a persisted Final Makeup Preview. Purchased
credits are counted apart from included allowance", and purchased credits are
rendered as a separate detail line rather than added in. The imprecision is the
**group heading "AI Looks"**, not the numbers.

Consequences for UI-5:

- A card titled "AI Looks Today" backed by this field would be inaccurate.
- Per UI SOT section 15.1 ("If the backend exposes delivered previews rather than
  AI Look units, relabel the card to match the actual metric"), the correct move
  is to label it **"Final Previews committed today"** (or similar), not to
  invent a filter.
- A true AI-Look-unit-only figure requires an aggregate grouped by
  `allowance_unit`. That is DATA CONTRACT MISSING (B-03).

## 11.3 Entitlement status distribution - pie/donut validity

**PIE / DONUT SEMANTICALLY VALID: NO (globally).**

The existing global aggregate exposes only `inForceByPlan` (a plan breakdown of
in-force rows), `pending` and `suspended`. There is **no** global count of
`expired` or `revoked` entitlements anywhere in the admin read surface. The four
categories the UI SOT sketches (Active / Expired / Suspended / Revoked)
therefore cannot form a part-to-whole whole - three of the four are unavailable
or incomplete, and a chart built from what exists would silently misrepresent
the population.

A **pilot-scoped** status distribution *is* fully available from WA-13
(`pilots.inForce / suspended / lapsedOrExpired / revoked` against
`pilots.entitlements`), and those categories do form a meaningful whole over one
well-defined population. If UI-5 wants a donut, the honest one is
"Salon Pilot entitlements by status", clearly scoped - not a global chart.

Deriving global current status by aggregating historical rows is explicitly
forbidden (UI SOT section 17) and is not attempted here.

## 11.4 Committed vs released - time scope caveat

Both figures come from the same server call and the same server-defined window
(`todayStartsAt` / `monthStartsAt`), so the comparison is scope-safe.

One asymmetry to carry into UI-5: **committed is split by allowance source,
released is not.** `releasedToday` / `releasedThisMonth` are single counts. A
"Committed vs Released" bar pair therefore either compares
`committedToday.subscription` against a released count that includes
purchased-credit releases, or sums the two committed buckets - which the SOT
forbids doing silently. The safe presentation is three labeled bars
(subscription committed, purchased-credit committed, released) or an explicit
note. This is a presentation decision, not a data gap.

Also note `reservedOpen` has **no time bound** - it is a current-state count of
all open reservations. Per UI SOT section 16.4 it must stay a statistic card and
must never be plotted as a historical outcome.

---

# 12. ALLOWANCE UNIT / METRIC SEMANTICS

## 12.1 Canonical plan codes (Shared Contract section 7)

`free`, `plus`, `plus_preview`, `pro`, `pro_preview`, `salon_pro`,
`salon_preview`, `salon_pilot`.

Verified against `SubscriptionPlanCode` in the Flutter domain and against
`subscription_products` in the database. `AdminDashboardMetrics._byPlan` throws
if any canonical plan key is missing or unknown, so the client already fails
closed on contract drift.

## 12.2 The four units that must never be merged

| Unit | Where it lives | Notes |
|---|---|---|
| **AI Look** | `subscription_products.allowance_unit = 'ai_look'` (`free`, `plus`, `pro`, `salon_pro`, `salon_pilot`) | Tutorial-enabled plans |
| **Final Preview Credit** | `subscription_products.allowance_unit = 'final_preview_credit'` (`plus_preview`, `pro_preview`, `salon_preview`) | `tutorial_enabled = false`, enforced by DB constraint |
| **Salon Pilot adjustment** | `entitlement_allowance_adjustments`, surfaced as `adminAdjustmentsTotal` | A signed delta to an allowance, not a consumption event |
| **Purchased top-up credit** | `usage_ledger.allowance_source = 'purchased_credit'`, `purchased_credit_grants` | Shared Contract section 74a: never an included AI Look |

## 12.3 Which Dashboard metrics use which unit

| Metric | Counts |
|---|---|
| Total Users, Anonymous guests | **accounts** (`auth.users`) |
| Active Paid, Salon Pilot in force, Pending, Suspended, In force by plan | **entitlements** |
| Committed today/month, Released today/month, Open reservations | **usage ledger rows (operations)** - mixed allowance units, see 11.2 |
| Active purchased-credit grants | **grants** |
| Pilot allowance figures (WA-13) | **AI Look allowance units** (pilot is an `ai_look` plan) |
| Pilot provider figures (WA-13) | **provider attempts / tokens / images** - never money |

## 12.4 Rule for every later phase

No visualization may place accounts, entitlements, operations, grants or
allowance units on one unlabeled numeric axis. Where a chart spans plan
families, the axis must be named for what is actually counted ("Final Previews
delivered"), never "AI Looks".

The existing code already honors this (`CommittedBySource` is deliberately not
summed, and the WA-13 research page keeps provider usage separate from
allowance). The redesign must not regress it.

---

# 13. CHART DEPENDENCY FINDING

```
CHART DEPENDENCY = NOT PRESENT
```

Evidence:

- `pubspec.yaml` dependencies are: `flutter`, `cupertino_icons`,
  `flutter_riverpod`, `go_router`, `flutter_image_compress`, `image_picker`,
  `path`, `path_provider`, `permission_handler`, `supabase_flutter`, `uuid`,
  `share_plus`, `package_info_plus`, `camera`, `in_app_purchase`,
  `in_app_purchase_android`. None provides charting.
- `pubspec.lock` contains no `fl_chart`, `charts_flutter`, `syncfusion_*`,
  `graphic`, or any plotting package.
- No admin source imports a chart library. The WA-13 contract test
  (`admin_security_contract_test.dart`) actively asserts the research page
  contains neither `fl_chart` nor `charts_flutter`.

**PACKAGE:** none. **VERSION:** n/a. **CURRENT USAGE:** none.

**NEW DEPENDENCY REQUIRED FOR UI-5: YES, if any chart is to be implemented.**

Per UI SOT section 18 and the UI-5 prompt, UI-5 must **STOP and request explicit
dependency approval** before adding one. UI-0 added nothing and recommends
nothing specific.

A hand-rolled `CustomPainter` chart is explicitly forbidden by the UI-0 prompt
and is not proposed here.

---

# 14. RESPONSIVE BASELINE

Only two application-wide breakpoints exist, both in `admin_shell.dart:29-30`:
`wideBreakpoint = 1100`, `compactBreakpoint = 760`.

| Width band | Sidebar | Page padding | Dashboard cards | Filters | Table overflow | Dialog width | Header | Content width | Class |
|---|---|---|---|---|---|---|---|---|---|
| >= 1440px | Extended `NavigationRail`, `minExtendedWidth: 220` | 24px flat | `Wrap` of tiles, reflows by available width | Fixed 220px slots, wrap | Contained in table `SingleChildScrollView` | Workflow panels capped at 640px | 56px top bar with section label | Capped at **1280px**, left-aligned | CONFIRMED (source) |
| 1200-1439px | Extended rail | 24px flat | same | same | same | same | same | Capped at 1280px | CONFIRMED (source) |
| 1024-1199px | Extended rail (>= 1100) or compact icon rail (< 1100) | 24px flat | same | same | same | same | same | Fills, under cap | CONFIRMED (source) |
| 768-1023px | Compact icon rail, `NavigationRailLabelType.all` | 24px flat | same | Fixed 220px slots wrap more | same | 640px cap may exceed viewport | same | Fills | CONFIRMED (source) |
| < 760px | `NavigationDrawer` behind an `AppBar` | 24px flat | same | same | same | same | AppBar + identity | Fills | CONFIRMED (source) |

Notes and gaps:

- **Page padding never changes with width** (D-04). The UI SOT section 12 asks
  for 32-40 / 24-32 / 20-24 / 16-20 by band. This is entirely unimplemented.
- **The 1280px content cap** (D-06) means a 1920px display shows a wide empty
  strip. The UI SOT allows up to ~1480px for dashboard/forms and full width for
  wide tables.
- **No `LayoutBuilder`-driven grid** exists on the Dashboard; tiles rely on
  `Wrap`. Column-count targets (4 / 3 / 2-3) are unimplemented.
- The only per-page responsive logic in the entire admin tree is
  `admin_audit_detail_page.dart:105` (`constraints.maxWidth < 900`).
- Workflow pages use a hard `maxWidth: 640` in 14 places
  (grant / adjust / lifecycle). At 768px with a compact rail this is close to
  the available width. **NEEDS REAL BROWSER VERIFICATION.**
- Actual rendering at 1366 / 1024 / 768 has never been observed in a browser at
  this HEAD. All "behavior" above is read from source, not seen.

---

# 15. ACCESSIBILITY BASELINE

Measured affordances in `lib/admin/`:

| Affordance | Count |
|---|---|
| `Semantics(` wrappers | 27 |
| `header: true` | 19 |
| `semanticsLabel` | 5 |
| `semanticLabel` | 2 |
| `Tooltip(` | 5 |
| `FocusTraversalGroup` | 2 |
| `ExcludeSemantics` | 3 |
| `liveRegion` | 2 |

## CONFIRMED (proven by source and/or passing tests)

- Keyboard reachability of navigation is a deliberate architectural decision:
  `ShellRoute` was rejected precisely because a nested Navigator's focus scope
  made the rail unreachable by Tab. `admin_shell_test.dart` asserts "sections are
  reachable and activatable from the keyboard".
- The rail and content are each wrapped in a `FocusTraversalGroup`, giving one
  predictable traversal order.
- Section and page headings are marked `header: true` (19 sites), so screen
  readers get a heading structure.
- The navigation rail carries `Semantics(container: true, label: 'Admin sections')`
  and content `label: 'Section content'`.
- Loading indicators carry `semanticsLabel` (for example "Loading dashboard").
- Status is never conveyed by color alone today: `AdminStatusBadge` renders
  **text** plus styling, satisfying the UI SOT rule in advance.
- The compact-window drawer and the rail are tested at two widths
  (`admin_shell_test.dart`: "a compact window keeps the rail; a narrow one uses
  a drawer").

## INFERRED (implied, not asserted anywhere)

- Focus visibility relies on Material defaults from the shared consumer theme;
  no admin focus ring token exists. The UI SOT asks for a 2px accent ring with
  2px offset - unimplemented.
- Hit targets: `TextButton.icon` and `IconButton` defaults are generally >= 40px,
  but no minimum is enforced or tested.
- Form fields use Material `InputDecoration` defaults; label/error association
  follows Flutter's built-in semantics rather than explicit wiring.

## NEEDS REAL BROWSER VALIDATION

- Contrast ratios at the target 4.5:1 / 3:1 (no palette measurement exists, and
  the palette is about to change in UI-1).
- Focus ring visibility against the future dark surfaces.
- Screen-reader behavior of `DataTable` across the five tables.
- Browser zoom behavior (the UI SOT requires primary workflows to survive zoom).
- Real keyboard traversal order in a browser, as opposed to widget-test focus
  traversal.

---

# 16. ADMIN TEST INVENTORY

24 files, 7,483 lines, **240 tests, all passing** at this HEAD.

| Group | Files | Coverage | Gaps relevant to the redesign |
|---|---|---|---|
| Auth / routing | `admin_router_test.dart`, `admin_authorization_controller_test.dart`, `admin_session_gateway_test.dart`, `admin_shell_test.dart` | Exhaustive redirect matrix, `?from=` carry-through, rail/drawer switch at two widths, keyboard reachability, sign-out, revocation mid-use | No test pins page padding, content max width, or any band between 760 and 1100 |
| Dashboard | `admin_dashboard_page_test.dart`, `admin_dashboard_controller_test.dart`, `admin_dashboard_metrics_test.dart` | Strict decode of every field, refusal envelopes, loading/ready/empty/unavailable, refresh disabling | No chart tests (nothing to test); no test asserts tile grouping or label wording |
| Users | `admin_users_page_test.dart`, `admin_users_controller_test.dart`, `admin_user_models_test.dart` | Exact-match search, pagination replacing rows, privacy-limited detail fields | No test catches the mojibake strings (D-01) |
| Entitlements | `admin_entitlements_controller_test.dart`, `admin_entitlement_models_test.dart`, `admin_entitlements_usage_pages_test.dart` | Filters, cursor binding, decode | No visual/layout assertions |
| Usage | `admin_usage_models_test.dart`, shared page test above | Decode, filters | Same |
| Audit | `admin_audit_test.dart` | List, detail, history, immutability of the UI surface | Same |
| Salon Pilot | `admin_salon_pilot_test.dart`, `admin_grant_salon_pilot_page_test.dart`, `admin_adjust_allowance_test.dart`, `admin_lifecycle_test.dart` | Preview-before-confirm, idempotency key reuse, version handling, refusal mapping | No test pins destructive-action visual hierarchy |
| Research (WA-13) | `admin_research_page_test.dart`, `admin_research_models_test.dart` | Controller load/refresh, non-admin never queries, cost "Not available", pagination, routing | No progress-bar presentation test (none exists yet) |
| Concurrency | `admin_mutation_concurrency_test.dart` | Double-submit sends once; retry reuses key/version | - |
| Security contract | `admin_security_contract_test.dart`, `admin_web_security_test.dart` | Source scans: no service-role, no image/prompt/kit fields, no currency or price literal, no chart library, HTML/JS sinks | **These will constrain UI-1..UI-15**: they scan admin sources by pattern and will fail on careless additions |
| Responsive / presentation | none dedicated | - | **GAP**: no width-band tests beyond the shell's two |
| Accessibility | partial, inside `admin_shell_test.dart` | Keyboard reachability only | **GAP**: no contrast, focus-ring or target-size tests |

Two specific constraints the security-contract tests impose on the redesign:

1. `admin_security_contract_test.dart` asserts the research page contains
   `'Not available'`, references `cost.available`, contains neither `fl_chart`
   nor `charts_flutter`, and contains no `'/ '` substring. A chart library
   import or a stray division in that file will fail the suite.
2. `wa12_admin_secret_scan.sh` asserts the built bundle names exactly ten read
   RPCs. Any new data call added by the redesign would fail it - which is the
   intended guard, since WA-13.5 must add no backend calls.

---

# 17. IMPLEMENTATION CONSTRAINTS FOR UI-1 THROUGH UI-15

1. **Never edit `lib/theme/`.** `AppTheme`, `AppColors`, `AppTypography` and
   `AppSemantics` are shared with the consumer app (`lib/app/app.dart:23-24`).
   UI-1 creates an admin-owned theme instead and repoints
   `lib/admin/app/admin_app.dart`.
2. **Pin the admin theme.** `themeMode: ThemeMode.system` must become a fixed
   admin theme for "Operational Dark SaaS". This is an admin-only edit.
3. **Introduce an admin spacing/radius scale.** `AppSpacing` lacks the 20 and 40
   steps and `AppRadii` is far larger than the 6/8/10 the SOT wants. 168
   `AppSpacing` references inside `lib/admin/` must migrate to admin tokens.
4. **Preserve single-Navigator shell composition.** Do not convert to
   `ShellRoute`; it breaks keyboard access to the rail (proven, documented).
5. **Preserve the five-section navigation and its order.** No additions.
6. **Resolve the duplicated page title** (shell top bar vs per-page heading)
   deliberately in UI-2/UI-4 - the SOT forbids duplicating a title the
   PageHeader already renders.
7. **Keep table overflow inside the table region.** The current
   `Scrollbar > horizontal SingleChildScrollView > DataTable` containment
   already satisfies the SOT; do not move overflow to page level.
8. **Do not add sorting.** Not currently supported; SOT section 20 forbids adding
   it in WA-13.5.
9. **Do not change pagination semantics.** `AdminKeysetListController` is
   behavior, not presentation; only its rendering may change.
10. **Do not weaken confirmation friction.** Preview-before-confirm, reason
    fields and the stronger revoke acknowledgement are existing contracts.
11. **Add no backend call.** The bundle secret scan pins exactly ten read RPCs.
12. **Add no dependency without explicit approval** - including any chart
    package (section 13).
13. **Charts on the Dashboard only.** Users, Entitlements, Usage and Audit stay
    table/filter pages.
14. **Never merge allowance units** (section 12). Relabel rather than
    misrepresent.
15. **Fix the encoding defect in UI-9 or UI-14**, not before, and only in the two
    presentation files named in 8.1.
16. **Respect the source-scan security tests** when adding files under
    `lib/admin/` (no price/currency literal, no image/prompt/kit field name, no
    chart library in the research page).

---

# 18. DATA CONTRACT BLOCKERS

## B-01

```
DATA CONTRACT MISSING:
Daily committed series (per-reporting-day counts) for the last 30 days,
and consequently for the last 7 days.
```

**Inspected:** `admin_dashboard_metrics()` returns only `committedToday` and
`committedThisMonth` aggregates against server-defined `todayStartsAt` /
`monthStartsAt`; no admin RPC returns a per-day series. `admin_list_usage(...)`
returns 25-row keyset pages of individual ledger rows, which cannot be
aggregated client-side into 30 bounded daily points without unbounded paging -
forbidden by UI SOT section 17.

**IMPACT:** UI-5 cannot implement Chart A (the line chart), and cannot implement
the optional 7D/30D toggle. These are the Dashboard V2 centerpiece.

**FUTURE AUTHORIZATION REQUIRED:** A separately authorized additive read-contract
phase outside WA-13.5, adding a bounded server-side daily series (with its unit
explicitly chosen per section 12). WA-13.5 must not create it.

## B-02

```
DATA CONTRACT MISSING:
Final Previews delivered, grouped by plan, over a bounded reporting window.
```

**Inspected:** `entitlements.inForceByPlan` is a per-plan count of **in-force
entitlements**, not of deliveries - using it for a "delivered by plan" chart
would mislabel one thing as another. `usage_ledger` carries `plan_code`, so the
row-level data exists, but no admin aggregate groups by it.

**IMPACT:** UI-5 cannot implement Chart B.

**FUTURE AUTHORIZATION REQUIRED:** Same additive read-contract phase as B-01.

## B-03

```
DATA CONTRACT MISSING:
Committed operations grouped by allowance_unit (ai_look vs
final_preview_credit).
```

**Inspected:** `usage_ledger.allowance_unit` exists at row level (confirmed
against the live schema), but `admin_dashboard_metrics()` groups committed rows
only by `allowance_source`. No aggregate separates AI Look units from Final
Preview Credits.

**IMPACT:** A card genuinely titled "AI Looks Today" cannot be built. UI-5 must
relabel to what the field actually counts (Final Previews committed today, split
by funding source) per UI SOT section 15.1.

**FUTURE AUTHORIZATION REQUIRED:** Same additive read-contract phase.

## B-04

```
DATA CONTRACT MISSING:
Global current entitlement status distribution (expired and revoked counts).
```

**Inspected:** the admin read surface exposes `inForceByPlan`, `pending` and
`suspended` globally. No global `expired` or `revoked` count exists. WA-13
provides the full status breakdown for `salon_pilot` only.

**IMPACT:** Chart C cannot be a valid global part-to-whole donut. A pilot-scoped
donut is available today and is the only honest version.

**FUTURE AUTHORIZATION REQUIRED:** Same additive read-contract phase, if a global
distribution is wanted.

## Net effect on Dashboard V2

Of the ten target elements, **4 are fully available** (Total Users, Salon Pilot
count, Committed-vs-Released aggregate, Salon Pilot progress), **2 are available
but require an honest relabel** (Active Paid, AI Looks Today), and **4 are
blocked** (30-day line, 7-day toggle, delivered-by-plan bar, global status
donut).

UI-5 can therefore deliver a real Dashboard V2 - summary cards, a
committed-vs-released comparison, a pilot-scoped status view and pilot progress
bars - but **not the 30-day line chart**, which is the visual the target sketch
leads with. That should be decided before UI-5 starts: either accept a
chart-lighter Dashboard, or authorize the additive backend phase first.

---

# 19. ASSUMPTIONS NOT PROVEN

1. **No browser rendering was observed.** Every responsive and visual statement
   is read from source at this HEAD. Nothing in section 14 has been seen in
   Chrome, and no screenshot baseline exists.
2. **Contrast is unmeasured.** No palette contrast ratio has been computed, for
   the current theme or the target one.
3. **Screen-reader behavior is unverified.** Semantics counts prove the wiring
   exists, not that the announced result is correct.
4. **Mojibake is proven in source only.** The five literals are confirmed at byte
   level; that they render as mojibake in a browser is a near-certain inference,
   not an observation.
5. **`AppSpacing` usage counts** (168) come from a symbol-level grep and could
   miss indirect usage through a shared widget.
6. **"One current entitlement per account"** is relied on in section 11.1 as the
   one-current rule from the subscription authority; it was not re-proven here.
7. **Chart library suitability is unassessed.** UI-0 proves absence, not which
   package would be appropriate.
8. **The `maxWidth: 640` workflow pages at 768px** are flagged as tight from
   arithmetic, not from a rendered page.

---

# 20. UI-0 ACCEPTANCE RESULT

| Requirement | Result |
|---|---|
| Exact route inventory | DONE - 18 routes + redirect-only root |
| Exact screen inventory | DONE - 16 page widgets, 1 dead |
| Presentation architecture documented | DONE - 7 shared widgets, 22 absent, per-page privates |
| Shared/mobile styling risk documented | DONE - `AppTheme` high risk, `AppSpacing` isolatable |
| Visual defect baseline documented | DONE - 18 defects, classified |
| Current Dashboard contract documented | DONE |
| Dashboard V2 target documented | DONE |
| All 10 Dashboard data items classified | DONE - 4 available, 2 ambiguous, 4 missing |
| Incompatible allowance units kept separate | DONE - 4 units, per-metric mapping |
| Chart dependency proven | DONE - NOT PRESENT |
| Responsive baseline documented | DONE - 2 breakpoints exist, bands unimplemented |
| Accessibility baseline documented | DONE - confirmed / inferred / needs browser |
| Admin test baseline documented | DONE - 24 files, 240 tests |
| Data blockers explicit | DONE - B-01 to B-04 |
| Exactly one file changed | DONE - this document only |
| No production code changed | DONE |
| No dependency changed | DONE |
| No backend changed | DONE |
| No mobile code changed | DONE |

**UI-0 RESULT: COMPLETE, pending review.**

**Next phase:** WA-13.5-UI-1 - Admin Design System Foundation. Not started.

Before UI-5 is reached, a decision is required on blockers B-01 to B-04: accept a
Dashboard V2 without the 30-day line chart and the by-plan bar chart, or
authorize a separate additive read-contract phase outside WA-13.5.
