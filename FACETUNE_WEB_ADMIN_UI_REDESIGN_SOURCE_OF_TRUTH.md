# FACETUNE WEB ADMIN UI REDESIGN SOURCE OF TRUTH

**Version:** 1.0.0  
**Date:** 2026-09-22  
**Status:** AUTHORITATIVE FOR THE WA-13.5 WEB ADMIN UI/UX REDESIGN TRACK  
**Scope:** Flutter Web Admin presentation layer only  
**Project:** FaceTune Beauty  
**Execution window:** After WA-13 is checkpointed and before WA-14 begins

---

# 1. PURPOSE

This file is the canonical visual and presentation authority for the FaceTune Web Admin redesign executed as **WA-13.5**.

The redesign exists to transform the current Web Admin from an engineering-first internal control panel into a production-ready, professional, data-focused SaaS administration interface while preserving all existing business behavior, server authority, subscription semantics, security boundaries, and protected FaceTune systems.

The redesign must improve presentation without quietly becoming an architecture rewrite.

The Web Admin must remain:

- operational rather than decorative
- desktop-first and responsive
- compact and highly readable
- predictable and consistent
- privacy-minimal
- accessible
- safe for privileged administrative work
- visually isolated from the consumer/mobile application where necessary

---

# 2. AUTHORITY ORDER

For every WA-13.5 UI redesign phase, authority is resolved in this order:

1. `CODEX_MASTER_GUIDE.md`
2. protected FaceTune AI / Tutorial / Final Preview authorities
3. canonical Subscription Source of Truth files
4. `FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md`
5. `FACETUNE_WEB_ADMIN_SOURCE_OF_TRUTH.md`
6. `FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md`
7. this file: `FACETUNE_WEB_ADMIN_UI_REDESIGN_SOURCE_OF_TRUTH.md`
8. `FACETUNE_WEB_ADMIN_UI_REDESIGN_PHASE_PROMPTS.md`
9. accepted WA completion reports
10. current repository implementation

This UI source of truth is authoritative only for **Web Admin presentation and visual composition**.

It MUST NOT override higher authorities on:

- authentication
- authorization
- entitlement resolution
- subscription state
- usage accounting
- Google Play behavior
- admin mutation semantics
- RLS
- audit semantics
- idempotency
- concurrency
- privacy boundaries
- protected AI behavior

If a desired visual design conflicts with a higher-order behavior or security contract, the higher-order authority wins and the UI must adapt.

---

# 3. ROADMAP POSITION

The UI redesign is inserted into the main Web Admin roadmap as:

```text
WA-12  Security, Privacy & Abuse Hardening
  ↓
WA-13  Salon Pilot Research Dashboard & Operational Metrics
  ↓
CHECKPOINT
  ↓
WA-13.5  Web Admin UI/UX Redesign & Visual Productionization
  ↓
CHECKPOINT
  ↓
WA-14  End-to-End Subscription / Web Admin Integration & Regression
  ↓
WA-15  Real Browser / Live Backend / Production Readiness QA
```

WA-13.5 must finish before WA-14 so that WA-14 and WA-15 validate the interface intended for production rather than a temporary UI.

---

# 4. HARD SCOPE

## 4.1 IN SCOPE

- Web Admin application shell
- Web Admin-only design tokens
- sidebar
- top utility bar
- page headers
- Dashboard
- Dashboard charts backed by authoritative server data
- cards and statistic surfaces
- tables
- filters
- forms
- dialogs and confirmation surfaces
- status badges
- loading states
- empty states
- error states
- no-result states
- pagination presentation
- responsive Web Admin behavior
- desktop/laptop browser behavior
- accessibility presentation
- hover/focus/pressed/selected/disabled states
- Web Admin-specific reusable presentation components
- visual text formatting defects such as mojibake, provided no backend data rewrite is required

## 4.2 OUT OF SCOPE

- mobile UI redesign
- Android UI changes
- iOS UI changes
- consumer app design system changes
- new business functionality
- subscription business-rule changes
- billing changes
- Google Play changes
- new entitlement behavior
- new usage semantics
- authentication changes
- authorization changes
- RLS changes
- database mutations
- database schema changes during WA-13.5
- new Supabase RPCs during WA-13.5
- Edge Function behavior changes during WA-13.5
- repository/service/domain-model rewrites
- new audit semantics
- pricing changes
- Final Preview changes
- Tutorial V4 changes
- My Makeup Kit changes
- Gemini prompt/model changes

If UI implementation discovers that a required visual needs missing backend data, WA-13.5 must not invent a backend implementation. The phase must report a **DATA CONTRACT MISSING** condition and stop that specific feature until separately authorized.

---

# 5. PROTECTED SYSTEMS

The following are hard locked and must not be modified by the UI redesign:

- Final Preview model `gemini-3.1-flash-image`
- fail-closed Final Preview validator
- Tutorial V4
- `tutorial_guideline_v4_7`
- `tutorial_manifest_v4_1`
- Standard Mode
- My Makeup Kit
- SUB-10 verify → activate → acknowledge
- SUB-11 provider-authoritative RTDN/lifecycle/Restore
- purchased-credit accounting
- reserve → generate → validate → persist → commit
- historical content preservation
- server-authoritative subscription state
- server-authoritative remaining capacity
- Web Admin server-side authorization
- Admin idempotency and concurrency contracts
- immutable audit behavior
- no Gemini client-side
- RLS

---

# 6. MOBILE UI IS STRICTLY PROTECTED

The redesign is **WEB ADMIN ONLY**.

Do not redesign, refactor, standardize, migrate, or modify consumer/mobile presentation as part of WA-13.5.

If Web Admin currently shares colors, theme objects, widgets, constants, utilities, or components with the mobile app, do not modify them in a way that changes mobile rendering.

Preferred rule:

```text
shared component would alter mobile
→ create / use Web-Admin-specific presentation component or token
```

A clean Web Admin redesign is not permission to accidentally reskin the consumer app.

---

# 7. DESIGN DIRECTION

The canonical visual direction is:

## OPERATIONAL DARK SAAS

The interface should feel like a serious subscription/entitlement operations console.

It should be:

- simple
- compact
- calm
- structured
- professional
- data-focused
- understated
- readable
- consistent
- practical
- production-ready
- desktop-first
- responsive
- accessible

Avoid:

- glassmorphism
- neon styling
- excessive gradients
- oversized dashboard cards
- excessive animation
- decorative charts
- giant headings
- excessive shadows
- extreme border radii
- random decorative shapes
- inconsistent icon styles
- excessive accent color
- generic AI-generated dashboard aesthetics

Administrative usability has priority over decoration.

---

# 8. CANONICAL COLOR SYSTEM

The following roles are the WA-13.5 visual baseline. Minor contrast adjustments are allowed during accessibility validation if they preserve the semantic role.

| Role | Baseline | Use |
|---|---|---|
| Page background | `#0E1116` | Main application canvas |
| Sidebar background | `#101318` | Persistent navigation |
| Primary surface | `#151920` | Cards, tables, filter panels, detail sections |
| Secondary surface | `#1B2028` | Inputs, hover surfaces, secondary containers |
| Border | `#2B313B` | Default 1px structural border |
| Strong border | `#3A424E` | Focused/selected control border |
| Primary text | `#F4F5F7` | Main readable content |
| Secondary text | `#AAB2BD` | Descriptions and metadata |
| Disabled text | `#69727F` | Disabled/noninteractive content |
| Primary accent | `#C96386` | Primary action, selected navigation, links |
| Accent hover | `#D97194` | Accent hover state |
| Accent subtle | `rgba(201,99,134,.14)` | Selected nav background / subtle selected state |
| Success | `#49B97A` | Positive state |
| Warning | `#E5A84B` | Warning state |
| Error / destructive | `#E46770` | Errors, revoke/destructive actions |
| Information | `#5E92E8` | Informational state |

Semantic state MUST NOT be communicated by color alone. Pair semantic color with text and/or iconography.

Rose/accent is not a universal status color.

---

# 9. CANONICAL TYPOGRAPHY SYSTEM

Preferred stack:

```text
Inter
Roboto
system sans-serif fallback
```

Do not use a highly condensed display face for dense administration data.

| Role | Size / line height | Weight |
|---|---:|---:|
| Page title | 24 / 32 | 650 |
| Page subtitle | 14 / 21 | 400 |
| Section title | 18 / 26 | 600 |
| Card title | 13 / 18 | 550 |
| Metric value | 26–30 | 650 |
| Table heading | 12.5–13 | 600 |
| Table content | 14 / 20 | 400 |
| Form label | 13 | 550 |
| Helper text | 12 / 18 | 400 |
| Button | 14 | 600 |
| Navigation | 14 | 550 |
| Metadata | 12 | 400 |
| Status badge | 12 | 600 |

Hierarchy must be visible without giant text.

---

# 10. CANONICAL SPACING / RADII / BORDERS

Spacing scale:

```text
4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48
```

Use:

- 4: icon/text micro spacing
- 8: compact internal gap
- 12: field/content micro grouping
- 16: standard component padding
- 20: filter/control grouping
- 24: card padding and small section gap
- 32: standard section gap
- 40: major page region separation
- 48: rare top-level separation

Radius scale:

- controls: 6px
- cards/tables: 8px
- large sections: 10px
- dialogs: 10px
- semantic badges: pill allowed

Buttons should generally use 6–8px radius, not full capsule styling.

Borders:

- 1px subtle structural border by default
- horizontal table dividers
- stronger focused/selected border
- prefer borders over decorative card shadows

Shadows:

- no elevation for most cards/tables
- subtle elevation for dropdowns/popovers/sticky surfaces
- modal elevation for dialogs only

---

# 11. APPLICATION SHELL

Canonical desktop structure:

```text
┌────────────────┬─────────────────────────────────────────────┐
│ Sidebar        │ Top Utility Bar                             │
│                ├─────────────────────────────────────────────┤
│                │ Page Header                                 │
│                │                                             │
│                │ Main Content                                │
│                │                                             │
└────────────────┴─────────────────────────────────────────────┘
```

## Sidebar

- 232px expanded
- 64px brand region
- navigation item height 44px
- 20px icons
- 12px icon/text gap
- restrained selected background
- optional 3px selected indicator
- semibold active text
- secondary-surface hover

Canonical navigation order remains:

1. Dashboard
2. Users
3. Entitlements
4. Usage
5. Audit

Do not add navigation items merely to make the sidebar look fuller.

## Top Utility Bar

- 64px height
- account identity on right
- sign out on right
- breadcrumb/small context on left when useful
- do not duplicate a full page title already rendered by PageHeader

## Main content

- 32px normal desktop padding
- up to 40px on very wide displays
- 24px laptop
- 20px near 1024px
- dashboard/forms may use max width around 1480px
- wide operational tables may use available width

---

# 12. RESPONSIVE CONTRACT

WA-13.5 is desktop-first, not a mobile Web Admin redesign.

## >= 1440px

- sidebar 232px
- page padding 32–40px
- dashboard up to 4 statistic columns
- filters 3–4 columns
- wide table uses full content width

## 1200–1439px

- sidebar expanded unless evidence supports compact mode
- page padding 24–32px
- dashboard 3-column layout where useful
- filters deliberately wrap
- wide tables scroll inside their own container

## 1024–1199px

- sidebar may collapse to approximately 72px if existing routing remains untouched
- page padding 20–24px
- statistic grid 2–3 columns
- filters 2 columns
- table horizontal scrolling mandatory when needed

## 768–1023px

- compact Web Admin shell
- page padding 16–20px
- cards 1–2 columns depending on content
- forms 1–2 columns
- tables remain tables with contained horizontal scrolling
- dialogs stay within viewport
- account email may visually truncate safely

Do not convert the application into a mobile-navigation product.

---

# 13. REUSABLE WEB ADMIN PRESENTATION COMPONENTS

Use/reuse components only when they reduce inconsistency without changing behavior.

Canonical component concepts:

- `AdminPageShell`
- `AdminSidebar`
- `AdminHeader`
- `PageHeader`
- `SectionHeader`
- `PrimaryButton`
- `SecondaryButton`
- `DestructiveButton`
- `AdminCard`
- `StatCard`
- `StatusBadge`
- `AdminTable`
- `SearchField`
- `FilterControl`
- `PaginationControl`
- `EmptyState`
- `ErrorState`
- `LoadingState`
- `AdminDialog`
- `ConfirmationDialog`
- `AdminTextField`
- `AdminDropdown`
- `AdminDateField`
- `AdminChartCard` only if chart data is already authoritative
- `PilotUsageProgress` only if pilot metrics are already authoritative

Component names are conceptual unless repository inspection proves matching existing names. Do not rename large architecture surfaces merely to conform to this list.

---

# 14. DASHBOARD V2 — CANONICAL INFORMATION ARCHITECTURE

The WA-13.5 redesigned Dashboard is the only Web Admin page where charts are encouraged.

Users, Entitlements, Usage, and Audit remain operational table/filter pages. Do not place charts on those pages merely for decoration.

Canonical Dashboard structure:

```text
Dashboard                                   [Last updated] [Refresh]

[ Total Users ] [ Active Paid ] [ Salon Pilot ] [ AI Looks Today ]

AI Look Activity
┌──────────────────────────────────────────────────────────────┐
│ LINE CHART                                                   │
│ Committed AI Looks — Last 30 Days                            │
└──────────────────────────────────────────────────────────────┘

Plan / Delivery Distribution             Usage Outcome
┌──────────────────────────────────┐     ┌──────────────────────────────┐
│ BAR CHART                        │     │ BAR / DONUT                  │
│ Final Previews by Plan           │     │ Committed vs Released       │
└──────────────────────────────────┘     └──────────────────────────────┘

Entitlement Status
┌──────────────────────────────────┐
│ DONUT / PIE, only when meaningful│
└──────────────────────────────────┘

Salon Pilot
[ Active pilots ] [ Remaining AI Looks ] [ Expiring soon ]

Pilot Usage
User / Pilot              Usage
pilot@example.com         ███████████░░░ 18 / 30 AI Looks used
```

The exact number of simultaneous chart cards must remain visually restrained. Prefer 2–4 useful charts rather than filling the Dashboard with chart furniture.

---

# 15. DASHBOARD METRIC CONTRACT

Dashboard UI MUST display server-authoritative values. It must not download large datasets and calculate authoritative subscription metrics in the browser.

## 15.1 Summary cards

### Total Users

Use authoritative aggregated account count already supported by the Web Admin backend.

### Active Paid

Display only if WA-13 or existing server contract provides an authoritative aggregate.

Conceptually this represents accounts with a current access-eligible paid public plan, excluding Free and Salon Pilot. The frontend MUST NOT recreate entitlement-resolution rules from raw rows.

If backend semantics differ, use the backend-defined meaning and label accurately.

### Salon Pilot

Count in-force/current Salon Pilot entitlements only through authoritative server aggregation.

### AI Looks Today

Count committed **AI Look allowance-unit** operations for the current reporting day.

Do not count Final Preview Credits as AI Looks.

If the backend exposes delivered previews rather than AI Look units, relabel the card to match the actual metric instead of lying with typography.

---

# 16. DASHBOARD CHART CONTRACT

## 16.1 Chart A — Committed AI Looks Over Time

Preferred visual:

```text
LINE CHART
```

Default presentation:

```text
Committed AI Looks — Last 30 Days
```

Data requirements:

- one authoritative server-provided point per reporting day
- ordered ascending by date
- committed AI Look units only
- no browser reconstruction from an unbounded usage ledger
- no interpolation or fabricated missing values

If WA-13 supplies both 7-day and 30-day windows, a compact 7D / 30D presentation toggle is allowed. If it does not, do not add a client-only pseudo-toggle.

Zero-activity days may display zero only if the backend contract or bounded server series supports that interpretation.

## 16.2 Chart B — Plan Distribution / Delivery by Plan

The original design idea was "AI Looks by Plan" across:

- Free
- Plus
- Plus Preview
- Pro
- Pro Preview
- Salon Pro
- Salon Preview
- Salon Pilot

However, Preview plans use **Final Preview Credits**, not AI Look units. Therefore a chart spanning both families MUST NOT be labeled "AI Looks by Plan" if it counts all plans.

Canonical safe label when all plan families are included:

```text
Final Previews Delivered by Plan
```

Preferred visual:

```text
BAR CHART
```

This chart may count successfully persisted Final Previews by plan over the authoritative reporting window if WA-13 provides that aggregate.

Alternative allowed form:

```text
AI Looks by Plan
```

only if the series includes AI-Look-unit plans exclusively and explicitly excludes preview-credit plans.

Never combine incompatible allowance units into one unlabeled numerical total.

## 16.3 Chart C — Entitlement Status Distribution

Preferred visual:

```text
DONUT / PIE
```

Allowed only when the categories form a meaningful part-to-whole distribution of one well-defined population, preferably the current/governing entitlement population returned by the server.

Typical categories may include:

- Active
- Grace period
- Suspended
- Expired
- Revoked
- other canonical states when actually present

Do not build the chart from every historical entitlement row if doing so would imply that historical rows are a current account distribution.

If there are too many categories or the whole is not semantically meaningful, use a bar chart instead.

## 16.4 Chart D — Usage Outcome

Preferred visual:

```text
BAR CHART
```

Canonical comparison:

- committed operations
- released operations

Use the same bounded server reporting window.

If WA-13 provides daily outcome series, a two-series daily bar chart is allowed.

If WA-13 provides only aggregate totals, use a simple two-bar comparison. Do not manufacture daily history in the browser.

Open reservations are a current state, not a historical outcome, and should remain a statistic card unless the backend exposes an explicit compatible series.

## 16.5 Salon Pilot Progress

Do NOT use a pie chart for individual pilot consumption.

Use a progress bar / meter with explicit numbers.

Example:

```text
18 / 30 AI Looks used
12 remaining
Expires 2026-10-15
```

Per-pilot presentation may include operational identity already allowed by the Web Admin privacy contract, such as email or user ID, but must not expose private image/user content.

Progress calculation must use authoritative values returned by the backend:

- effective allowance
- committed
- reserved if the server-defined progress meaning includes it
- remaining

Do not invent an alternative allowance formula in Flutter.

If effective allowance is 0, render a stable zero state and do not divide by zero.

---

# 17. CHART IMPLEMENTATION HARD LOCKS

Charts are a presentation of authoritative data, not a new analytics authority.

WA-13.5 MUST NOT:

- create Supabase migrations
- create new RPCs
- create new Edge Functions
- fetch the complete usage ledger just to calculate chart points client-side
- fetch every user to compute counts client-side
- infer current entitlement state from historical rows
- merge AI Look units with Preview Credits as though they are one allowance unit
- fabricate cost information
- fabricate historical points
- fabricate missing categories
- add charts to Users, Entitlements, Usage, or Audit just for decoration

If a required Dashboard chart series does not exist after WA-13:

```text
DATA CONTRACT MISSING
```

The implementation agent must document:

- which exact series/aggregate is missing
- which existing backend contract was inspected
- why the chart cannot be implemented safely

Then leave that chart out or use a clear Not available state according to the phase prompt. Do not cross the presentation-layer boundary.

---

# 18. CHART DEPENDENCY RULE

Before implementing charts, inspect `pubspec.yaml` and current Web Admin code.

Priority:

1. reuse an already-approved chart dependency if one exists
2. reuse an existing safe Web Admin chart abstraction if one exists
3. if no chart capability exists, STOP before adding a new third-party package and request explicit dependency approval

Do not silently add a chart library because a mockup contains a graph.

Any approved chart dependency must:

- support Flutter Web
- support keyboard/semantic accessibility where practical
- not require secrets
- not send telemetry/data externally
- not alter mobile rendering
- not require backend changes
- be actively maintained enough for the project standard

---

# 19. DASHBOARD CHART VISUAL STANDARD

Chart cards follow `AdminCard` structure.

Chart title:

- 14–16px semibold
- short and explicit

Chart description / window:

- 12px secondary text

Chart plotting area:

- no 3D
- no gradients used as data encoding
- no decorative animation
- no excessive grid lines
- no more series than the viewer can reasonably distinguish
- tooltips may expose only the already-authorized aggregate values represented in the chart
- legends must use clear text labels
- semantic colors must remain consistent

A chart must always include an accessible textual title and enough non-color labeling to understand the series.

---

# 20. TABLE STANDARD

All operational tables use one presentation system.

## Container

- bordered primary surface
- horizontal overflow contained inside table region
- page itself must not horizontally overflow due to table width

## Header

- minimum 44px
- secondary text
- semibold
- subtle bottom border

## Rows

- 52–60px typical
- up to 64px when identity is stacked
- subtle hover surface

## Identity

Where practical:

```text
email@example.com
8-character…UUID
```

Email is primary, shortened identifier secondary.

Do not let raw UUID dominate scanning hierarchy.

## Status

Use consistent `StatusBadge` with text plus semantic indicator.

Examples:

- Active
- Expired
- Revoked
- Suspended
- Unconfirmed

## Actions

Reserve a consistent rightmost action region.

Do not allow the action affordance to disappear because the Period/ID columns consumed the viewport.

## Pagination

Keep existing pagination semantics. Standardize only presentation.

## Sorting

If sorting is not currently supported, do not add sorting as part of WA-13.5.

---

# 21. FORM / FILTER STANDARD

- visible labels above controls
- control height 42–44px
- 6px radius
- consistent helper text
- clear error/validation text
- dropdown/text/date controls share one visual family
- primary action visually stronger than Clear/Cancel
- destructive action uses Error semantic treatment
- filters should use deliberate responsive grids rather than arbitrary wrapping

Do not alter search/filter query semantics.

---

# 22. DIALOG / HIGH-IMPACT ACTION STANDARD

Dialog recommendation:

- width approximately 480–560px where practical
- 24px padding
- 10px radius
- strong title
- short operational explanation
- explicit target user / entitlement summary when already available
- preserve required reason field
- preserve preview-before-confirm workflow where already required
- preserve stronger acknowledgement for revoke

Destructive actions use error/destructive styling rather than generic rose styling.

UI redesign must never reduce existing high-friction confirmation requirements.

---

# 23. STATE DESIGN

## Loading

Prefer skeleton rows/cards for read surfaces.

Do not use a blocking page spinner except when bootstrap/authorization genuinely blocks content.

## Empty

Compact bordered state with:

- icon
- clear title
- short explanation
- existing action only if the application already supports one

## No results

Different from empty database state.

Example:

```text
No matching users
Try another exact email address or User ID.
```

## Error

Use explicit error panel and existing Retry action where retry behavior already exists.

Do not expose raw SQL/backend errors.

## Disabled

Reduce emphasis but retain readable text and meaningful reason where currently supported.

---

# 24. ACCESSIBILITY CONTRACT

WA-13.5 must preserve or improve:

- keyboard navigation
- visible focus state
- readable font sizes
- control labels
- semantic status presentation
- sufficient contrast
- minimum practical hit target around 40×40px
- destructive-action clarity
- readable tables at browser zoom
- no color-only meaning

Target contrast:

- normal text approximately 4.5:1 or better
- meaningful UI/focus boundaries approximately 3:1 or better where applicable

Recommended focus style:

```text
2px accent ring
2px outer offset
```

Charts must not be understandable only through color.

---

# 25. PAGE-SPECIFIC CANONICAL STRUCTURE

## Dashboard

Use the Dashboard V2 structure in this file. Charts only here unless separately approved.

## Users

- PageHeader
- exact-match SearchField + Search action
- helper text
- AdminTable
- PaginationControl
- contained horizontal overflow
- stacked identity presentation where practical

No chart.

## Entitlements

- PageHeader
- coherent FilterPanel
- User ID / Plan / Status / Provider / Expiration filters
- Apply / Clear
- AdminTable
- contained horizontal overflow

No chart.

## Usage

- PageHeader
- coherent FilterPanel
- User ID / Entitlement ID / Status / Plan / Source / Created-within
- Apply / Clear
- AdminTable
- operational IDs visually secondary where possible

No chart.

## Audit

- PageHeader
- compact FilterPanel
- Admin ID / Target User / Target Entitlement / Action / Event Source / Date
- Apply / Clear
- Audit table or table-contained no-result state

No chart.

## User Detail

Preferred large-screen arrangement:

```text
Users / User detail

User Detail
user@example.com       [Account status]

┌──────────────────────┬───────────────────────────┐
│ Account              │ Current subscription      │
│ User ID              │ Plan                      │
│ Created              │ Status                    │
│ Status               │ Provider                  │
│                      │ Allowance / Usage          │
└──────────────────────┴───────────────────────────┘

Related
[All entitlements] [Usage] [Audit] [History]

Administrative actions
[Grant / Adjust / Extend / Suspend / Reactivate / Revoke as allowed]
```

At smaller desktop width, stack the two information columns.

Do not change lifecycle eligibility or button authorization logic.

---

# 26. MOJIBAKE / DISPLAY ENCODING RULE

Current screenshots show presentation artifacts such as:

```text
â€”
â€¦
```

WA-13.5 treats visible mojibake as a production-quality blocker.

Allowed:

- fix Web Admin source string encoding
- fix Web Admin-only formatter rendering when the underlying value is correct
- replace malformed visual separator with proper Unicode or plain equivalent

Forbidden without separate authorization:

- rewriting database historical content
- mutating authoritative backend records merely to make a screenshot prettier

If the corruption originates in stored backend data rather than presentation code, STOP and report the boundary.

---

# 27. IMPLEMENTATION PRINCIPLE

The desired implementation path is:

```text
existing behavior
+ admin-only design system
+ shared admin presentation components
+ page composition cleanup
+ safe visualization of already-authoritative WA-13 metrics
=
production-quality Web Admin
```

Not:

```text
UI redesign
→ architecture rewrite
→ backend changes
→ mobile changes
→ new business rules
```

---

# 28. WA-13.5 PHASE MAP

The canonical mini-roadmap is:

```text
WA-13.5-UI-0   Existing UI & Data Contract Inventory
WA-13.5-UI-1   Admin Design System Foundation
WA-13.5-UI-2   Web Admin Application Shell
WA-13.5-UI-3   Sidebar Navigation
WA-13.5-UI-4   Header & Page Header
WA-13.5-UI-5   Dashboard V2 + Authoritative Charts
WA-13.5-UI-6   Shared Cards & Statistics
WA-13.5-UI-7   Tables
WA-13.5-UI-8   Forms & Filters
WA-13.5-UI-9   Individual Admin Screens
WA-13.5-UI-10  Dialogs & Confirmation States
WA-13.5-UI-11  Loading / Empty / Error / No-Result States
WA-13.5-UI-12  Responsive Web Pass
WA-13.5-UI-13  Accessibility Pass
WA-13.5-UI-14  UI Consistency & Regression Audit
WA-13.5-UI-15  Final Visual QA & Baseline Lock
```

Each phase must STOP after its completion report.

No phase automatically authorizes the next phase.

No phase automatically authorizes commit, push, deployment, or backend changes.

---

# 29. GIT / WORKTREE SAFETY

Every phase must begin with:

```text
git branch --show-current
git rev-parse HEAD
git status --short
git status --branch
git diff --check
```

Rules:

- preserve dirty worktree
- do not reset
- do not clean
- do not restore unrelated files
- do not stash
- do not switch branches
- do not merge/rebase/cherry-pick unless separately authorized
- do not commit/push unless separately authorized
- do not deploy

If unexpected unrelated dirty paths exist, STOP and report them before editing.

---

# 30. TESTING HARD LOCK

Presentation work still requires regression proof.

At minimum, after relevant phases:

- targeted Flutter Admin widget/unit tests
- `flutter analyze`
- formatting checks
- existing Admin auth/router/security tests where shell/navigation changes occur
- production Web build after material layout changes
- full Admin suite before final UI checkpoint
- no database/migration test is required solely for presentation changes unless repository code unexpectedly touches those layers

If a phase changes no backend code, do not "improve" backend tests just to make the phase look important.

Final WA-13.5 acceptance must preserve the pre-redesign functional behavior.

---

# 31. FINAL ACCEPTANCE CRITERIA

WA-13.5 may be considered complete only when all of the following are true:

- Web Admin functions remain functionally equivalent unless a separately approved WA-13 data contract explicitly added metrics
- Dashboard charts use authoritative data only
- no chart fabricates history or mixes incompatible allowance units
- no charts were added to operational pages merely for decoration
- no mobile UI change
- no backend API/Supabase change during WA-13.5
- no database business-rule change
- no subscription behavior change
- no auth/authorization change
- all pages use one coherent design system
- page hierarchy is clear
- Dashboard uses a deliberate responsive grid
- tables no longer clip at page level
- wide tables scroll inside their own container
- right-side actions remain reachable
- filters follow one visual form system
- status badges follow one semantic system
- destructive actions are explicit
- visible mojibake is eliminated or proven to originate outside the presentation layer
- loading/empty/error/no-result states are deliberate
- 768px through wide-desktop browser widths remain usable
- browser zoom does not destroy primary workflows
- keyboard focus remains visible
- semantic color is not the only status indicator
- Admin-only styling is isolated from mobile presentation
- production Web build succeeds
- full Admin test suite passes
- final screenshot baseline is reviewed before WA-14 begins

---

# 32. FINAL STOP RULE

After `WA-13.5-UI-15`:

```text
WA-13.5 UI REDESIGN = COMPLETE
```

Then STOP.

Do not begin WA-14 without explicit authorization.

Do not deploy merely because visual QA passed.

Do not touch the consumer/mobile application.

---

# END OF FACETUNE WEB ADMIN UI REDESIGN SOURCE OF TRUTH
