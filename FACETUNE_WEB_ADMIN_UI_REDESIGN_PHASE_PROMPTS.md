# FACETUNE WEB ADMIN UI REDESIGN — PHASE PROMPTS

**Version:** 1.0.0  
**Companion authority:** `FACETUNE_WEB_ADMIN_UI_REDESIGN_SOURCE_OF_TRUTH.md`  
**Track:** WA-13.5 — Web Admin UI/UX Redesign & Visual Productionization  
**Branch:** `feature/web-admin-ui-redesign-v1`

---

# 0. HOW TO USE THIS FILE

Run exactly one phase at a time.

Every phase is a STOP-gated engineering task.

Do not auto-continue.

Do not infer authorization to commit, push, deploy, change Supabase, add dependencies, change mobile UI, or start the next phase.

Every implementation phase starts from the latest explicitly accepted checkpoint.

The intended sequence is:

```text
WA-13 checkpoint
  ↓
WA-13.5-UI-0
  ↓ checkpoint when separately authorized
WA-13.5-UI-1
  ↓
...
  ↓
WA-13.5-UI-15
  ↓ checkpoint when separately authorized
WA-14 only after explicit authorization
```

---

# 1. GLOBAL EXECUTION CONTRACT FOR EVERY WA-13.5 PHASE

Every prompt below includes this contract conceptually. The engineering agent must obey it even when a phase-specific section is narrower.

## Mandatory authority read

Before edits, read completely and apply in this order:

1. `CODEX_MASTER_GUIDE.md`
2. protected FaceTune Final Preview / Tutorial / My Makeup Kit authorities relevant to preservation
3. canonical Subscription Source of Truth files
4. `FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md`
5. `FACETUNE_WEB_ADMIN_SOURCE_OF_TRUTH.md`
6. `FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md`
7. `FACETUNE_WEB_ADMIN_UI_REDESIGN_SOURCE_OF_TRUTH.md`
8. this file and the exact current phase
9. accepted prior phase reports
10. current code

If a lower authority conflicts with a higher authority, stop and follow the higher authority.

## Git safety

Before edits run:

```powershell
git branch --show-current
git rev-parse HEAD
git status --short
git status --branch
git diff --check
```

Expected branch:

```text
feature/web-admin-ui-redesign-v1
```

Do not:

```text
git reset
git clean
git restore .
git checkout -- .
git stash
git switch
git merge
git rebase
git cherry-pick
git commit
git push
```

unless separately and explicitly authorized.

If unexpected unrelated dirty files exist, STOP and report them. Do not "clean them up."

## Product hard locks

WA-13.5 is presentation-layer work.

Do NOT modify:

- database schema
- Supabase migrations
- RLS
- RPC semantics
- Edge Function behavior
- authentication
- authorization
- admin roster behavior
- subscription resolver
- entitlement semantics
- usage accounting
- Google Play
- pricing
- idempotency
- concurrency
- audit semantics
- Final Preview model/prompt/validator
- Tutorial V4
- Standard Mode
- My Makeup Kit
- mobile UI
- consumer app navigation

No backend changes are authorized in this track.

## Mobile isolation hard lock

If a visual change to a shared theme/widget would alter the mobile app, do not modify that shared surface.

Use/create Web-Admin-specific presentation tokens/components instead.

## Dependency hard lock

Do not add/remove a package unless the current phase explicitly authorizes it or the user separately approves it.

For charting specifically:

- inspect existing dependencies first
- reuse existing chart capability if safe
- if no suitable chart capability exists, STOP and request explicit dependency approval

## Validation minimum

Run the tests appropriate to touched layers.

At minimum for code-changing phases:

```text
dart format / format check
flutter analyze
targeted admin tests
```

For shell/navigation/responsive/final phases also run:

```text
flutter test test/admin
flutter build web -t lib/admin_main.dart
```

Do not mutate the backend simply to produce a more impressive validation report.

## Required completion report

Every phase must return:

```text
PHASE COMPLETED:

BRANCH VERIFIED:

BASE HEAD:

WORKING TREE PRESERVED:

OBJECTIVE ACHIEVED:

AUTHORITY FILES READ:

FILES CREATED:

FILES MODIFIED:

FILES DELETED:

DEPENDENCIES ADDED / REMOVED:

WEB ADMIN PRESENTATION CHANGES:

DASHBOARD / CHART CHANGES:

MOBILE UI CHANGES:
None expected.

BACKEND / DATABASE / SUPABASE CHANGES:
None expected.

AUTH / AUTHORIZATION CHANGES:
None expected.

SUBSCRIPTION / ENTITLEMENT / USAGE CHANGES:
None expected.

PROTECTED AI CHANGES:
None.

RESPONSIVE CHECK:

ACCESSIBILITY CHECK:

PRIVACY CHECK:

SECURITY BOUNDARY CHECK:

TESTS / VALIDATION:

REAL BROWSER EVIDENCE:

KNOWN LIMITATIONS:

ASSUMPTIONS NOT PROVEN:

MANUAL ACTION REQUIRED:

NEXT RECOMMENDED PHASE:

STOP CONFIRMATION:
No later phase was implemented.
No commit, push, deployment, backend mutation, or mobile change was performed unless separately authorized.
```

Then STOP.

---

# WA-13.5-UI-0 — EXISTING UI & DATA CONTRACT INVENTORY

## COPY/PASTE PROMPT

```text
You are implementing ONLY:

WA-13.5-UI-0 — EXISTING UI & DATA CONTRACT INVENTORY

This is an ANALYSIS / INVENTORY phase.
Do not redesign or modify production UI code in this phase.

FIRST:
- verify branch feature/web-admin-ui-redesign-v1
- verify HEAD is the explicitly accepted WA-13 checkpoint
- verify worktree status
- preserve all existing work
- read every mandatory authority completely, including FACETUNE_WEB_ADMIN_UI_REDESIGN_SOURCE_OF_TRUTH.md

OBJECTIVE
Freeze the exact current Web Admin presentation surface and prove which Dashboard V2 metrics/chart series are already available from authoritative WA-13/backend read contracts before any visual implementation begins.

INSPECT ALL WEB ADMIN ROUTES / SCREENS
At minimum inventory:
- login / authorization states
- Dashboard
- Users
- User Detail
- Entitlements
- Usage
- Audit
- Audit detail
- Entitlement history
- Salon Pilot grant
- allowance adjustment
- lifecycle actions
- every confirmation dialog
- loading / empty / error / unavailable states
- pagination controls
- responsive shell behavior

SCREENSHOT / VISUAL BASELINE
Record the current visible structure and known defects:
- excessive unused horizontal space
- inconsistent density
- weak hierarchy
- oversized pill controls
- table clipping / overflow
- status inconsistency
- filter layout inconsistency
- duplicate page titles
- weak surface hierarchy
- mojibake such as â€” / â€¦
- action columns disappearing at the right edge

REPOSITORY INVENTORY
Identify, without redesigning:
- Web Admin-only theme/tokens
- shared theme dependencies that could affect mobile
- shell widgets
- sidebar widgets
- header/page-header widgets
- shared table/form/card widgets
- admin-only tests
- responsive helpers/breakpoints
- existing chart dependencies or chart widgets

DASHBOARD DATA CONTRACT AUDIT
Inspect the accepted WA-13 implementation and existing admin read contracts.
For each desired Dashboard V2 item classify:

AVAILABLE AUTHORITATIVELY
MISSING
AMBIGUOUS
UNSAFE TO DERIVE CLIENT-SIDE

Items:
1. Total Users
2. Active Paid
3. Salon Pilot count
4. AI Looks Today
5. Daily committed AI Looks for last 30 days
6. Optional 7-day committed AI Look series
7. Final Previews delivered by plan across canonical plan codes
8. Current/governing entitlement status distribution
9. Committed vs released operation counts for a bounded period
10. Per-pilot effective allowance / committed / reserved / remaining / expiration for progress presentation

SEMANTIC CHECK
Explicitly verify that preview-only plans use Final Preview Credits, not AI Look units.
Do not approve an "AI Looks by Plan" chart spanning Preview plans unless the metric is relabeled to a common output such as Final Previews Delivered by Plan.

CHART DEPENDENCY CHECK
Inspect pubspec.yaml.
If a chart package already exists, report exact package/version and where it is used.
If none exists, report:
CHART DEPENDENCY = NOT PRESENT
Do not add one.

OUTPUT ARTIFACT
Create or update only an admin UI inventory/planning document, preferably:
docs/WEB_ADMIN_UI_REDESIGN_INVENTORY.md

It must contain:
- route/screen inventory
- current shared presentation architecture
- mobile-sharing risk inventory
- current visual defect inventory
- Dashboard V2 data availability matrix
- chart dependency finding
- phase implementation constraints

DO NOT:
- change UI code
- add chart package
- change backend
- change Supabase
- change auth
- change mobile
- start UI-1

VALIDATE
- git diff --check
- confirm only the inventory/planning document changed

DONE WHEN
The next phase can implement design tokens without guessing about current UI architecture, and Dashboard V2 chart work has an explicit data-contract gate.

RETURN STANDARD COMPLETION REPORT.
STOP.
```

---

# WA-13.5-UI-1 — ADMIN DESIGN SYSTEM FOUNDATION

## COPY/PASTE PROMPT

```text
You are implementing ONLY:

WA-13.5-UI-1 — ADMIN DESIGN SYSTEM FOUNDATION

Start from the accepted UI-0 checkpoint.
Read all authorities and the UI inventory before edits.
Verify branch/HEAD/status first.

OBJECTIVE
Create the Web-Admin-only visual foundation: colors, typography, spacing, radius, borders, semantic states, and interaction-state tokens without changing page structure or mobile rendering.

IMPLEMENT
Use the canonical Operational Dark SaaS system from FACETUNE_WEB_ADMIN_UI_REDESIGN_SOURCE_OF_TRUTH.md.

Baseline roles include:
- page background #0E1116
- sidebar background #101318
- primary surface #151920
- secondary surface #1B2028
- border #2B313B
- strong border #3A424E
- primary text #F4F5F7
- secondary text #AAB2BD
- disabled text #69727F
- accent #C96386
- accent hover #D97194
- success #49B97A
- warning #E5A84B
- error #E46770
- information #5E92E8

Spacing:
4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48

Radius:
6 controls / 8 cards-tables / 10 large sections-dialogs / pill only for semantic badges

Typography hierarchy must match the SOT.

MOBILE ISOLATION
Inspect whether current admin styling relies on mobile/global theme.
If modifying an existing shared token would change consumer/mobile UI:
- do not modify it
- create/use an Admin-specific token/theme abstraction

Do not refactor the consumer theme.

SCOPE
Allowed:
- Web Admin-specific theme/tokens/styles
- Admin presentation helper tests
- minimal wiring necessary for Admin code to access the new tokens without materially changing layouts yet

Not allowed:
- page redesign
- chart implementation
- shell redesign
- mobile style change
- business behavior change

TEST
Add/adjust admin-only tests proving:
- semantic roles exist
- destructive color differs from accent
- status is not architecturally forced to rose
- Admin theme does not mutate consumer/mobile theme contracts

VALIDATE
- dart format check
- flutter analyze
- targeted admin tests
- git diff --check

DONE WHEN
Web Admin has one isolated visual token authority and no visible consumer/mobile regression.

Do not begin UI-2.
Return standard completion report.
STOP.
```

---

# WA-13.5-UI-2 — WEB ADMIN APPLICATION SHELL

## COPY/PASTE PROMPT

```text
You are implementing ONLY:

WA-13.5-UI-2 — WEB ADMIN APPLICATION SHELL

Start from accepted UI-1 checkpoint.
Verify branch/HEAD/status and read authorities first.

OBJECTIVE
Standardize the Web Admin application frame without changing routing, authentication, authorization, page functionality, or backend calls.

TARGET STRUCTURE
Sidebar | Top Utility Bar | Page Header | Main Content

IMPLEMENT PRESENTATION ONLY
- canonical main background/surfaces
- sidebar width baseline 232px expanded
- top utility bar height baseline 64px
- consistent content padding
- page content constraints
- full-width behavior for operational tables
- consistent scroll ownership
- eliminate accidental page-level horizontal overflow

MAIN CONTENT
Use approximately:
- 32–40px wide desktop padding
- 24–32px normal laptop
- 20–24px near 1024
- 16–20px near 768–1023

Do not implement detailed sidebar redesign yet; preserve nav behavior while fitting the shell.
Do not implement detailed header typography yet; preserve account/logout behavior.

ROUTING HARD LOCK
No route names, route guards, redirect rules, auth lifecycle, admin session logic, or destination semantics may change.

MOBILE HARD LOCK
Do not change mobile Scaffold/navigation/theme.

TEST
Prove:
- every existing Admin route still renders inside the shell
- sign out still exists
- protected routing remains protected
- no page-level horizontal overflow from the shell at representative widths

VALIDATE
- targeted shell/router tests
- flutter test test/admin
- flutter analyze
- flutter build web -t lib/admin_main.dart
- git diff --check

DONE WHEN
All Web Admin routes use one consistent shell and functional behavior is unchanged.

Do not begin UI-3.
Return standard completion report.
STOP.
```

---

# WA-13.5-UI-3 — SIDEBAR NAVIGATION

## COPY/PASTE PROMPT

```text
You are implementing ONLY:

WA-13.5-UI-3 — SIDEBAR NAVIGATION

Start from accepted UI-2 checkpoint.
Verify repository state and read authorities.

OBJECTIVE
Professionalize the existing sidebar visually while preserving route order, destinations, authorization, and navigation behavior.

CANONICAL ORDER
Dashboard
Users
Entitlements
Usage
Audit

PRESENTATION TARGET
- 232px expanded
- 64px brand region
- navigation row about 44px high
- icon about 20px
- 12px icon/text gap
- restrained selected background using accent-subtle
- optional 3px selected indicator
- semibold active text
- secondary-surface hover
- visible keyboard focus
- avoid oversized full-pill active navigation

COLLAPSED MODE
Do not add a new complex navigation system.
A compact/icon-only state around 72px may be implemented only if the current architecture supports it without routing changes and tests can prove accessibility.
Otherwise defer compact mode to UI-12 responsive pass.

DO NOT
- add navigation destinations
- rename route semantics
- move logout into a behaviorally different flow
- change mobile navigation

TEST
- current route remains visibly selected
- all existing destinations still navigate correctly
- keyboard traversal works
- labels remain available/accessibly named

VALIDATE
- sidebar/router tests
- full Admin tests if shared shell changed
- analyze
- web build if layout changed materially
- diff check

DONE WHEN
The sidebar looks like one restrained production Admin navigation system without changing what it does.

Do not begin UI-4.
Return standard completion report.
STOP.
```

---

# WA-13.5-UI-4 — HEADER & PAGE HEADER

## COPY/PASTE PROMPT

```text
You are implementing ONLY:

WA-13.5-UI-4 — HEADER & PAGE HEADER

Start from accepted UI-3 checkpoint.
Verify branch/HEAD/status and read authorities.

OBJECTIVE
Remove duplicated page context and establish one consistent hierarchy for global utility header, breadcrumbs/context, page title, subtitle, and optional actions.

TOP UTILITY BAR
- about 64px high
- right side keeps authenticated admin identity and Sign out
- left side may show compact breadcrumb/context where useful
- do not repeat the full page title if PageHeader already renders it

PAGE HEADER
Canonical composition:
Title
Subtitle
Optional right-side action / metadata

Examples:
Dashboard: title + subtitle + last-updated / Refresh
Users: title + search explanation, no duplicate title in top bar
User Detail: breadcrumb "Users / User detail" then page identity

DO NOT
- alter sign-out behavior
- alter session logic
- alter route parsing
- add notifications or global search unless already supported

TEST
- one primary heading per page
- admin identity still shown
- Sign out still functional
- breadcrumb does not become authorization or routing authority

VALIDATE
- header/page tests
- admin suite if shell touched
- analyze
- web build
- diff check

DONE WHEN
Every page has a predictable hierarchy and duplicated page titles are eliminated.

Do not begin UI-5.
Return standard completion report.
STOP.
```

---

# WA-13.5-UI-5 — DASHBOARD V2 + AUTHORITATIVE CHARTS

## COPY/PASTE PROMPT

```text
You are implementing ONLY:

WA-13.5-UI-5 — DASHBOARD V2 + AUTHORITATIVE CHARTS

This phase is presentation-heavy but has a strict data-contract boundary.
Start from accepted UI-4 checkpoint.
Verify branch/HEAD/status and read all authorities plus UI-0 inventory and accepted WA-13 report.

OBJECTIVE
Redesign Dashboard into a professional operational overview using a small number of meaningful charts and progress presentations backed ONLY by authoritative server data already available after WA-13.

MANDATORY PRE-IMPLEMENTATION GATE
Before editing Dashboard:
1. inspect current Dashboard read contract
2. inspect accepted WA-13 metrics contract
3. inspect pubspec.yaml for chart capability
4. confirm each required series is server-authoritative

If a required chart series is absent:
REPORT:
DATA CONTRACT MISSING: <exact metric>
Do NOT add migration/RPC/Edge Function/client-side unbounded aggregation.

If no approved chart package/capability exists:
REPORT:
CHART DEPENDENCY APPROVAL REQUIRED
STOP before adding a dependency.

DASHBOARD V2 LAYOUT

Dashboard                                  [Last updated] [Refresh]

[ Total Users ] [ Active Paid ] [ Salon Pilot ] [ AI Looks Today ]

AI Look Activity
[ LINE CHART — Committed AI Looks — Last 30 Days ]

Plan / Delivery Distribution        Usage Outcome
[ BAR — Final Previews by Plan ]    [ BAR — Committed vs Released ]

Entitlement Status
[ DONUT/PIE only if categories form one meaningful current whole ]

Salon Pilot
[ Active pilots ] [ Remaining AI Looks ] [ Expiring soon ]

Pilot Usage
<progress rows: 18 / 30 AI Looks used, remaining, expiry>

CHART A — LINE
- daily committed AI Look units
- last 30 days by default
- one bounded server-provided data point per day
- 7D/30D toggle only if server already supports both safely
- no fabricated history

CHART B — PLAN
If all canonical plan families are included, use:
"Final Previews Delivered by Plan"
not "AI Looks by Plan" because Preview plans use Final Preview Credits.

Canonical plan labels may include:
Free
Plus
Plus Preview
Pro
Pro Preview
Salon Pro
Salon Preview
Salon Pilot

Do not mix AI Look units and Final Preview Credits as if identical.

CHART C — ENTITLEMENT STATUS
Use donut/pie only if backend provides a meaningful part-to-whole current/governing entitlement population.
Possible categories: Active, Grace period, Suspended, Expired, Revoked, etc.
If the population is not semantically valid for pie/donut, use a bar chart or omit it according to the SOT.

CHART D — USAGE OUTCOME
Committed vs Released over the authoritative reporting window.
Daily two-series bars only if daily series exists.
Otherwise use aggregate two-bar comparison.
Open reservations remain a current statistic, not historical outcome.

SALON PILOT PROGRESS
Use progress bars, not pie charts.
Show explicit numerator/denominator and remaining value.
Use server-provided effective allowance/usage values.
Do not reproduce allowance formulas in Flutter.
Handle zero allowance without divide-by-zero.

VISUAL RULES
- no 3D
- no decorative gradients
- minimal animation
- restrained grid lines
- accessible labels/legends/tooltips
- charts must be understandable without color alone
- chart tooltip may expose only already-authorized aggregate data

NO CHARTS ON
Users
Entitlements
Usage
Audit

NO BACKEND WORK
No Supabase migration, RPC, Edge Function, resolver, ledger, auth, or subscription edits.

TEST
Add dashboard tests for:
- summary card rendering
- chart empty data state
- chart populated state
- canonical plan labels
- preview plans not mislabeled as AI Look units
- zero Salon Pilot allowance
- refresh/loading/error behavior unchanged
- responsive dashboard composition at representative widths
- no private user-image data exposed

VALIDATE
- targeted Dashboard tests
- flutter test test/admin
- flutter analyze
- web build
- diff check

DONE WHEN
Dashboard V2 is visually production-ready, charts are useful rather than decorative, and every number/series is backed by an existing authoritative contract.

Do not begin UI-6.
Return standard completion report.
STOP.
```

---

# WA-13.5-UI-6 — SHARED CARDS & STATISTICS

## COPY/PASTE PROMPT

```text
You are implementing ONLY:

WA-13.5-UI-6 — SHARED CARDS & STATISTICS

Start from accepted UI-5 checkpoint.
Verify state and read authorities.

OBJECTIVE
Standardize bordered surfaces, statistic cards, detail cards, chart cards, and section containers across Web Admin without altering their data or behavior.

CANONICAL SURFACE
AdminCard:
- primary surface
- 1px structural border
- 8px radius
- 20px default padding
- no shadow by default

StatCard:
- compact title
- 26–30px metric
- optional metadata line
- minimum useful width around 220px

ChartCard:
- same surface family
- title / description / plot / legend hierarchy
- no decorative elevation

APPLY WHERE APPROPRIATE
- Dashboard metrics
- User Detail account/subscription sections
- filter panels only if they visually benefit and do not become nested-card clutter

DO NOT
- change Dashboard metric meaning
- change chart data
- alter user/detail business actions
- add new card wrappers around everything

TEST
- consistent padding/radius token use
- no nested-card explosion
- detail content remains readable
- no behavior regression

VALIDATE
- targeted card/page tests
- analyze
- admin tests if shared components changed broadly
- diff check

DONE WHEN
Cards look like one system and visual density improves without bloating the UI.

Do not begin UI-7.
Return standard completion report.
STOP.
```

---

# WA-13.5-UI-7 — TABLES

## COPY/PASTE PROMPT

```text
You are implementing ONLY:

WA-13.5-UI-7 — TABLES

Start from accepted UI-6 checkpoint.
Verify repo state and read authorities.

OBJECTIVE
Create one consistent operational table presentation for Users, Entitlements, Usage, and Audit while preserving server pagination/filter/query semantics exactly.

CRITICAL EXISTING DEFECTS TO FIX VISUALLY
- right columns clipped
- action column lost at edge
- long IDs dominate width
- inconsistent status styling
- weak row hierarchy
- inconsistent table containment

CANONICAL TABLE
- bordered primary-surface container
- header min 44px
- row 52–60px, up to 64px for stacked identity
- 16px horizontal cell padding
- subtle horizontal dividers
- subtle hover surface
- contained horizontal scrolling
- page itself must not horizontally overflow due to the table

IDENTITY
Where existing data permits:
primary: email
secondary: shortened UUID metadata
Do not mutate the ID, only its visual presentation.
Provide full ID through existing safe detail/copy affordance if already supported; do not invent new backend behavior.

STATUS
Use one StatusBadge system with text + semantic indicator.
Do not rely on rose for every state.

ACTIONS
Preserve a consistent rightmost action region.
Do not let it disappear outside visible/contained scroll structure.

PAGINATION
Preserve existing server pagination exactly.
Standardize only visual layout.

SORTING
Do not add sorting if it does not already exist.

MOJIBAKE
If â€” / â€¦ comes from frontend source/formatting, fix presentation safely.
If stored data is corrupt, do not rewrite backend records; report the boundary.

TEST
At minimum cover:
- Users table
- Entitlements table
- Usage table
- Audit table populated state
- Audit no-result state
- horizontal overflow containment
- rightmost action reachability
- status badge semantics
- long ID rendering
- pagination unchanged

VALIDATE
- targeted table tests
- flutter test test/admin
- analyze
- web build
- diff check

DONE WHEN
No operational table causes page-level clipping at supported desktop widths and existing data/query behavior is unchanged.

Do not begin UI-8.
Return standard completion report.
STOP.
```

---

# WA-13.5-UI-8 — FORMS & FILTERS

## COPY/PASTE PROMPT

```text
You are implementing ONLY:

WA-13.5-UI-8 — FORMS & FILTERS

Start from accepted UI-7 checkpoint.
Verify state and read authorities.

OBJECTIVE
Standardize Web Admin search, filters, text fields, dropdowns, date fields, helper text, validation messages, and action hierarchy without altering filter/search semantics.

CANONICAL FORM RULES
- visible labels above controls
- control height 42–44px
- 6px radius
- common surface/border/focus behavior
- helper text 12px
- validation is explicit and readable
- dropdown/text/date controls share visual family
- primary action stronger than Clear/Cancel
- destructive actions use error semantics

FILTER LAYOUT
Users:
Email/User ID exact search + Search

Entitlements:
User ID / Plan / Status / Provider / Expiration
Apply filters / Clear

Usage:
User ID / Entitlement ID / Status / Plan / Source / Created within
Apply filters / Clear

Audit:
Admin ID / Target User / Target Entitlement / Action / Event Source / Date
Apply filters / Clear

Use a deliberate responsive grid rather than arbitrary Wrap spacing.

HARD LOCK
- do not broaden exact-match search
- do not add new query fields
- do not change debounce/request behavior
- do not change validation/business rules
- do not change backend bounds/rate limits

TEST
- values submitted before/after are identical
- Clear behavior unchanged
- labels/help text visible
- keyboard focus visible
- filter wrapping at representative widths

VALIDATE
- form/filter tests
- admin suite if shared form primitives changed broadly
- analyze
- web build if layout changed materially
- diff check

DONE WHEN
All admin forms look like one system while sending exactly the same intent as before.

Do not begin UI-9.
Return standard completion report.
STOP.
```

---

# WA-13.5-UI-9 — INDIVIDUAL ADMIN SCREENS

## COPY/PASTE PROMPT

```text
You are implementing ONLY:

WA-13.5-UI-9 — INDIVIDUAL ADMIN SCREENS

Start from accepted UI-8 checkpoint.
Read the UI inventory and current screenshots/code.

OBJECTIVE
Apply the established shell, design system, cards, tables, and forms to the page-specific compositions without inventing new features.

USERS
- concise PageHeader
- compact exact search toolbar
- standardized Users table
- preserve row opening/detail behavior

ENTITLEMENTS
- coherent filter panel
- standardized table
- preserve authoritative allowance/status values

USAGE
- coherent filter panel
- emphasize Created/User/Plan/Usage/Status scanning hierarchy
- operational IDs become visually secondary where safe
- preserve all ledger data and behavior

AUDIT
- compact filter panel
- table-contained empty/no-result state
- immutable operational framing
- preserve audit read/detail behavior

USER DETAIL
Large desktop preferred structure:
- breadcrumb/context
- user identity + status
- two-column Account / Current Subscription information
- Related links section
- separate Administrative Actions section

At smaller desktop width, stack the information columns.

Administrative actions remain conditionally shown according to existing authorization/lifecycle state.

DO NOT
- change grant eligibility
- change lifecycle eligibility
- change entitlement state
- add charts to operational pages
- add new actions
- remove existing actions

TEST
Page-by-page widget tests for:
- same functional controls exist
- no route/action removed
- detail state remains server-authoritative
- action hierarchy is visual only
- no mobile UI changed

VALIDATE
- page tests
- full admin tests
- analyze
- web build
- diff check

DONE WHEN
Every Web Admin page looks intentionally designed as one product while existing functions remain present and equivalent.

Do not begin UI-10.
Return standard completion report.
STOP.
```

---

# WA-13.5-UI-10 — DIALOGS & CONFIRMATION STATES

## COPY/PASTE PROMPT

```text
You are implementing ONLY:

WA-13.5-UI-10 — DIALOGS & CONFIRMATION STATES

Start from accepted UI-9 checkpoint.
Verify state and read authorities, especially Salon Pilot grant/adjust/lifecycle confirmation contracts.

OBJECTIVE
Standardize dialog presentation for privileged Admin workflows while preserving all existing high-friction confirmation and server-authoritative behavior.

VISUAL STANDARD
- approximately 480–560px max width where practical
- 24px padding
- 10px radius
- strong heading
- short operational explanation
- clear target user/entitlement summary already available to the UI
- reason field presentation where already required
- clear before/after preview where already supported
- primary/secondary/destructive action hierarchy

DESTRUCTIVE ACTIONS
Revoke/destructive confirmation must use error/destructive semantic treatment, not generic rose.
Do not reduce acknowledgement friction.
Do not remove required reason.
Do not bypass preview/confirm stages.

GRANT / ADJUST / EXTEND / SUSPEND / REACTIVATE / REVOKE
Preserve request payloads, idempotency keys, expected versions, retry behavior, and server responses exactly.

TEST
- correct action labels
- Cancel does not mutate
- confirm path sends identical existing intent
- destructive confirmation remains high-friction
- keyboard focus/order usable
- dialogs fit supported viewport

VALIDATE
- lifecycle/grant/adjust admin tests
- analyze
- admin suite if shared dialog component touched broadly
- web build
- diff check

DONE WHEN
Every privileged dialog is visually consistent and no safety friction or mutation contract was weakened.

Do not begin UI-11.
Return standard completion report.
STOP.
```

---

# WA-13.5-UI-11 — LOADING / EMPTY / ERROR / NO-RESULT STATES

## COPY/PASTE PROMPT

```text
You are implementing ONLY:

WA-13.5-UI-11 — LOADING / EMPTY / ERROR / NO-RESULT STATES

Start from accepted UI-10 checkpoint.
Verify state and read authorities.

OBJECTIVE
Make every existing asynchronous state visually deliberate and consistent without changing retry semantics, error classification, authorization behavior, or backend messages/contracts.

STANDARDIZE
LOADING
- use skeleton rows/cards where appropriate
- keep blocking spinner only where bootstrap/authorization truly blocks content

EMPTY
- compact bordered state
- icon
- clear title
- short explanation
- only existing action if already supported

NO RESULTS
Differentiate filtered/search no-result from true empty dataset.
Example:
No matching users
Try another exact email address or User ID.

ERROR
- explicit error state
- sanitized user-facing message
- existing Retry affordance where retry already exists
- never display raw SQL/internal stack data

DISABLED
- readable but reduced emphasis
- preserve reason/tooltip if already supported

DASHBOARD CHART STATES
Each chart must have:
- loading
- empty/no-data
- error
- populated
Do not draw fake zero trends when data is unavailable.

TEST
Cover the principal states on:
- Dashboard
- Users
- Entitlements
- Usage
- Audit
- User Detail
- one privileged action flow

VALIDATE
- targeted state tests
- admin suite
- analyze
- web build
- diff check

DONE WHEN
The Admin never looks broken merely because a legitimate loading/empty/error state occurred.

Do not begin UI-12.
Return standard completion report.
STOP.
```

---

# WA-13.5-UI-12 — RESPONSIVE WEB PASS

## COPY/PASTE PROMPT

```text
You are implementing ONLY:

WA-13.5-UI-12 — RESPONSIVE WEB PASS

Start from accepted UI-11 checkpoint.
Verify state and read authorities.

OBJECTIVE
Make the completed Web Admin usable across supported desktop/laptop browser widths without turning it into a mobile app.

MANDATORY WIDTH CLASSES
>= 1440px
1200–1439px
1024–1199px
768–1023px

VERIFY / IMPLEMENT
SIDEBAR
- expanded on wide screens
- compact/collapsed only where current architecture supports it safely

PAGE PADDING
- 32–40 wide
- 24–32 medium
- 20–24 compact laptop
- 16–20 small browser

DASHBOARD
- 4→3→2→1/2-column behavior as content requires
- charts retain readable minimum height
- no clipped legends/titles/tooltips

FILTERS
- 3–4 columns wide
- deliberate wrap
- 2 columns around 1024
- 1–2 columns near 768

TABLES
- never cause page-level horizontal overflow
- use contained horizontal scrolling
- action controls remain reachable

USER DETAIL
- two columns on large displays
- stack below appropriate threshold

DIALOGS
- stay inside viewport
- preserve scrollability/focus

HEADER
- email may safely truncate visually
- Sign out remains reachable

DO NOT
- create consumer/mobile navigation
- hide essential admin functionality at smaller widths
- alter server pagination to solve layout

TEST
Add/adjust responsive widget tests using representative widths.
Specifically reproduce previous table/action overflow conditions.

VALIDATE
- responsive tests
- full Admin tests
- analyze
- web build
- diff check

DONE WHEN
Every supported width can complete core Admin workflows without clipped controls or page-level horizontal overflow.

Do not begin UI-13.
Return standard completion report.
STOP.
```

---

# WA-13.5-UI-13 — ACCESSIBILITY PASS

## COPY/PASTE PROMPT

```text
You are implementing ONLY:

WA-13.5-UI-13 — ACCESSIBILITY PASS

Start from accepted UI-12 checkpoint.
Verify state and read authorities.

OBJECTIVE
Validate and improve accessibility of the finished Web Admin presentation without changing business behavior.

VALIDATE
- keyboard navigation
- visible focus
- logical tab order
- readable text size
- contrast
- visible labels
- semantic status text
- minimum practical interaction target
- destructive-action clarity
- dialog focus usability
- table readability at browser zoom
- charts understandable without color alone

CONTRAST TARGET
- normal text ~4.5:1 or better
- meaningful UI/focus boundaries ~3:1 or better where applicable

FOCUS BASELINE
2px accent ring with clear offset where appropriate.

CHART ACCESSIBILITY
- textual chart title
- readable legend
- tooltip not sole source of meaning
- series labels not color-only
- summary/no-data text available

DO NOT
- change auth flows
- change semantic business status
- add unrelated new features

TEST
Add semantic/focus/widget checks where practical.
Manually document areas that cannot be fully automated.

VALIDATE
- targeted accessibility tests
- Admin suite
- analyze
- web build
- diff check

DONE WHEN
Core workflows are keyboard-usable and state/action meaning is not dependent on color or pointer-only interaction.

Do not begin UI-14.
Return standard completion report.
STOP.
```

---

# WA-13.5-UI-14 — UI CONSISTENCY & REGRESSION AUDIT

## COPY/PASTE PROMPT

```text
You are implementing ONLY:

WA-13.5-UI-14 — UI CONSISTENCY & REGRESSION AUDIT

Start from accepted UI-13 checkpoint.
Verify state and read authorities.

OBJECTIVE
Audit the complete redesigned Web Admin for visual exceptions and functional regressions. Fix only proven presentation defects within WA-13.5 authority.

AUDIT EVERY PAGE / STATE
- Dashboard
- Users
- User Detail
- Entitlements
- Usage
- Audit
- Audit detail
- Entitlement history
- grant
- adjustment
- lifecycle dialogs
- loading
- empty
- no results
- error
- authorization unavailable

CONSISTENCY AUDIT
- colors use approved roles
- no random rose status usage
- typography hierarchy consistent
- spacing from canonical scale
- border/radius system consistent
- buttons use correct hierarchy
- destructive actions use destructive treatment
- filters/forms consistent
- tables consistent
- page headers consistent
- no duplicate titles
- no page-level overflow
- mojibake absent in presentation-owned strings

FUNCTIONAL REGRESSION AUDIT
Prove presentation work did not change:
- auth
- authorization
- routing
- search semantics
- filters
- pagination
- server reads
- grant
- adjustment
- lifecycle mutation payloads
- idempotency
- audit
- subscription/usage values

MOBILE REGRESSION AUDIT
Inspect diff and tests to prove no consumer/mobile presentation file was unintentionally redesigned.

CHART AUDIT
- authoritative source only
- correct units
- no fabricated history
- preview credits not mislabeled as AI Looks
- no private data exposure

VALIDATE
- dart format check
- flutter analyze
- flutter test test/admin
- relevant subscription/Admin regression tests if presentation integration touches shared abstractions
- flutter build web -t lib/admin_main.dart
- git diff --check
- full changed-file review

DONE WHEN
The redesigned system is visually coherent and functional contracts remain equivalent.

Do not begin UI-15.
Return standard completion report.
STOP.
```

---

# WA-13.5-UI-15 — FINAL VISUAL QA & BASELINE LOCK

## COPY/PASTE PROMPT

```text
You are implementing ONLY:

WA-13.5-UI-15 — FINAL VISUAL QA & BASELINE LOCK

This is the final WA-13.5 phase.
Start from accepted UI-14 checkpoint.
Verify branch/HEAD/status and read authorities.

OBJECTIVE
Perform final real-browser visual acceptance of the intended Web Admin design and lock the screenshot/visual baseline before WA-14 integration testing.

THIS PHASE IS PRIMARILY VALIDATION
Fix only proven presentation defects.
Do not add new product scope.

REAL BROWSER QA
Validate the redesigned Web Admin at representative widths, including approximately:
- 1920 or larger
- 1440
- 1280
- 1024
- 768–900 small browser range where practical

VALIDATE DASHBOARD
- summary cards aligned
- line chart readable
- plan/delivery bar chart readable
- entitlement status chart meaningful
- usage outcome chart readable
- Salon Pilot progress readable
- loading/no-data/error chart states deliberate
- Refresh / last updated readable
- no fake data

VALIDATE OPERATIONAL PAGES
Users
Entitlements
Usage
Audit
User Detail

For each:
- page hierarchy
- filter layout
- table containment
- action reachability
- pagination visibility
- status semantics
- empty/error/loading states
- no mojibake

VALIDATE PRIVILEGED ACTIONS
- grant
- allowance adjustment
- extend
- suspend
- reactivate
- revoke

Confirm visual redesign did not reduce confirmation/reason friction.

ACCESSIBILITY SPOT CHECK
- keyboard navigation
- focus visibility
- readable contrast
- dialog usability
- chart labels
- table readability

MOBILE PROTECTION
Confirm no consumer/mobile screenshot/theme regression from admin redesign.

FINAL VALIDATION
- dart format check
- flutter analyze
- flutter test test/admin
- production web build
- git diff --check
- review all changed paths against the WA-13.5 SOT

SCREENSHOT BASELINE
Capture/document final approved Web Admin screens for:
- Dashboard
- Users
- Entitlements
- Usage
- Audit
- User Detail
- representative dialog
- responsive table state

Do not commit/push unless separately authorized.
Do not deploy.
Do not start WA-14.

FINAL ACCEPTANCE REPORT MUST INCLUDE

WA-13.5 WEB ADMIN UI ACCEPTANCE:

DESIGN SYSTEM:
PASS / FAIL

SHELL:
PASS / FAIL

SIDEBAR:
PASS / FAIL

HEADER:
PASS / FAIL

DASHBOARD:
PASS / FAIL

DASHBOARD DATA AUTHORITY:
PASS / FAIL

CHART SEMANTICS:
PASS / FAIL

USERS:
PASS / FAIL

ENTITLEMENTS:
PASS / FAIL

USAGE:
PASS / FAIL

AUDIT:
PASS / FAIL

USER DETAIL:
PASS / FAIL

DIALOGS:
PASS / FAIL

STATES:
PASS / FAIL

RESPONSIVE:
PASS / FAIL

ACCESSIBILITY:
PASS / FAIL

MOJIBAKE:
NONE / FAIL

MOBILE UI CHANGES:
NONE / FAIL

BACKEND CHANGES DURING WA-13.5:
NONE / FAIL

SUBSCRIPTION SEMANTICS CHANGED:
NO / FAIL

AUTH / AUTHORIZATION CHANGED:
NO / FAIL

PRODUCTION WEB BUILD:
PASS / FAIL

WA-14:
NOT STARTED

STOP CONFIRMATION
WA-13.5 ends here.
Do not begin WA-14 without explicit authorization.
```

---

# 2. FINAL TRACK STOP RULE

After UI-15 is accepted and separately checkpointed:

```text
WA-13.5 = COMPLETE
WA-14 = READY, NOT STARTED
```

No phase in this file authorizes:

- deployment
- remote Supabase mutation
- mobile redesign
- business-rule changes
- chart backend invention
- WA-14 execution

---

# END OF FACETUNE WEB ADMIN UI REDESIGN PHASE PROMPTS
