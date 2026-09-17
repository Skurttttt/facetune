# FaceTune — SUBSCRIPTION UI PRODUCTIONIZATION SOURCE OF TRUTH

**Project Path:** `C:\Users\Kurt\facetune`  
**Project Name:** FaceTune  
**Tagline:** Your AI Makeup Artist  
**Primary Platform:** Android  
**Future Platform:** iOS  
**Primary Test Device:** POCO X3 GT  
**Framework:** Flutter  
**Language:** Dart  
**State Management:** Riverpod  
**Architecture:** Clean Architecture + Repository Pattern + Feature-First Structure  
**Current Development Branch:** `feature/subscription-v1`  
**Current Audited HEAD:** `e8c4484`  
**Feature Scope:** Subscription / Plans frontend UI productionization only  
**Backend Scope:** NONE  
**Google Play Billing Logic Scope:** NONE  
**Supabase Scope:** NONE  
**Entitlement Logic Scope:** NONE  
**Gemini Scope:** NONE  
**Database / RLS Scope:** NONE  

---

# 0. PURPOSE

This document is the highest feature-specific authority for the FaceTune **Subscription UI Productionization** effort.

This effort exists to make the existing Subscription / Plans experience feel more premium, polished, deliberate, responsive, and accessible **without creating a separate visual language and without changing backend behavior**.

This is NOT a subscription architecture rewrite.

This is NOT a Google Play Billing phase.

This is NOT an entitlement phase.

This is NOT a Supabase phase.

This is NOT a pricing-business-rules phase.

This is NOT permission to touch SUB-10 verification logic.

The current Subscription screen already follows the FaceTune Global UI closely. The goal is therefore:

> **Preserve the FaceTune Global UI and extend it only where a missing shared presentation capability is genuinely required.**

The implementation must improve hierarchy, scanability, premium perception, responsive behavior, accessibility, and UI-state quality while keeping all provider and backend behavior intact.

---

# 1. DOCUMENT AUTHORITY

Before ANY implementation under this UI effort, the coding agent must read, in this order:

1. `CODEX_MASTER_GUIDE.md`
2. `FACETUNE_SUBSCRIPTION_UI_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md`
3. `FACETUNE_SUBSCRIPTION_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md`
4. the latest relevant Subscription / Global UI completion report(s)
5. the actual current Flutter source code and tests relevant to the active phase
6. the Global UI / design-system implementation in `lib/theme/` and `lib/shared/widgets/`
7. the current Git working tree and active branch

Authority rules:

1. Actual current repository code, tests, runtime/device evidence, and existing design-system behavior must be inspected rather than assumed.
2. This Source of Truth governs the **Subscription UI productionization scope only**.
3. `CODEX_MASTER_GUIDE.md` governs the rest of FaceTune.
4. The active phase prompt authorizes only that phase.
5. Completion reports are evidence, not truth.
6. If stale documentation conflicts with current source/runtime evidence, current source/runtime evidence wins.
7. If this UI Source of Truth conflicts with protected subscription backend architecture, the protected backend architecture wins and the UI phase must STOP rather than modify backend behavior.

Do not treat design screenshots, verbal descriptions, or completion reports as more authoritative than actual source code.

---

# 2. SYSTEM ROLE

The coding agent must act simultaneously as:

- Principal Flutter Frontend Engineer
- Senior Flutter Engineer
- Senior Dart Engineer
- Senior Mobile Frontend Engineer
- Senior Design Systems Engineer
- Senior Mobile UI/UX Engineer
- Senior Accessibility Engineer
- Senior Responsive UI Engineer
- Senior Animation / Motion Engineer
- Senior Riverpod Integration Reviewer
- Senior QA / Regression Engineer
- Senior Widget Test Engineer
- Senior Golden Test Engineer
- Senior Code Reviewer
- Senior Product UI Engineer
- Senior Production Debugging Engineer

Do not behave as a generic code generator.

Inspect first.

Challenge stale assumptions.

Prefer the smallest production-safe frontend change.

Preserve working application behavior.

---

# 3. ENGINEERING PRIORITIES

Every decision must prioritize:

1. preservation of working subscription behavior
2. strict Global UI consistency
3. accessibility
4. responsive correctness
5. maintainability
6. testability
7. clear plan hierarchy
8. premium visual polish
9. restrained motion
10. implementation simplicity

Do not trade Global UI consistency for decorative novelty.

Do not create a new design system inside Subscription.

Do not perform a broad frontend refactor when a smaller change is sufficient.

---

# 4. GIT / WORKSPACE SAFETY

The audited development branch is:

```text
feature/subscription-v1
```

The audited HEAD is:

```text
e8c4484
```

The working tree contains uncommitted subscription work that must be preserved.

Before every phase:

```text
git branch --show-current
git status
```

The coding agent must STOP if the current branch or workspace state materially differs from the expected implementation context and the difference could make the phase unsafe.

Do not automatically run:

```text
git reset --hard
git clean -fd
git checkout -- .
git restore .
git stash
git rebase
git merge
git cherry-pick
git push --force
git push --force-with-lease
```

Do not commit or push unless explicitly instructed.

Do not switch branches unless explicitly instructed.

Do not discard unrelated changes.

---

# 5. STRICT FRONTEND-ONLY BOUNDARY

This project phase is intentionally isolated from the unresolved Google Play Developer API authorization issue.

Allowed layers:

- Flutter presentation pages
- Flutter presentation widgets
- existing shared UI primitives
- theme/design-system tokens only when a missing shared presentation capability is proven
- frontend-only presentation utilities
- widget tests
- golden tests
- accessibility semantics
- responsive layout logic
- animation/motion behavior
- display copy where it does not change business meaning

Forbidden layers:

- Supabase Edge Functions
- Google Play Developer API code
- Google Play service account configuration
- OAuth/JWT logic
- billing gateway logic
- purchase verification logic
- entitlement activation logic
- purchase acknowledgement order
- subscription database tables
- migrations
- RLS
- RPCs
- provider purchase verification rows
- usage ledger
- AI Look reserve/commit/release semantics
- plan IDs
- product IDs
- Gemini
- backend environment variables
- production secrets
- service role keys
- package name
- Google Cloud IAM configuration

If the desired UI behavior appears to require a backend change, STOP and report:

```text
BACKEND DEPENDENCY DETECTED — OUT OF SCOPE
```

Do not solve it by changing backend behavior.

---

# 6. PROTECTED SUBSCRIPTION ARCHITECTURE

The following are protected and must not be changed by this effort:

```text
Flutter
→ Google Play Billing
→ provider purchase evidence/token
→ Supabase backend
→ Google Play server verification
→ internal plan mapping
→ entitlement activation/update
→ acknowledge purchase
→ refresh authoritative subscription state
```

The protected order remains:

```text
VERIFY
→ ACTIVATE
→ ACKNOWLEDGE
```

Flutter remains non-authoritative for:

- current plan
- verified payment state
- entitlement
- expiration
- remaining AI Looks
- billing reset
- purchase verification

No UI phase may introduce:

```dart
if (purchaseSucceeded) {
  isPremium = true;
}
```

or any equivalent client-authoritative shortcut.

---

# 7. GLOBAL UI AUTHORITY

The FaceTune Global UI is centralized and must remain authoritative.

Confirmed design-system sources include:

```text
lib/theme/app_tokens.dart
lib/theme/app_theme.dart
lib/theme/app_typography.dart
lib/theme/app_semantics.dart
lib/shared/widgets/app_ui.dart
lib/shared/widgets/**
```

The Subscription page must continue to use the existing system rather than recreate local styling.

The design direction is:

> Premium, elegant, minimal, restrained, soft pink/rose accents, neutral backgrounds, Material 3, Apple-inspired polish without imitating iOS controls.

Avoid:

- neon
- glassmorphism
- glow
- arbitrary shadows
- emoji icons
- custom SVG icon language
- screen-specific design systems
- excessive gradients
- excessive pills
- decorative complexity

---

# 8. GLOBAL UI TOKENS — LOCKED BASELINE

Unless current repository evidence proves these values changed, preserve the established system.

## 8.1 Colors

Core confirmed roles:

```text
AppColors.rose        #A94E6B
AppColors.roseDark    #7C354D
AppColors.blush       #F5DDE3
AppColors.petal       #FBEFF2
AppColors.ivory       #FFFBF8
AppColors.sand        #F4ECE7
AppColors.cocoa       #2E2225
AppColors.taupe       #75686B
AppColors.taupeLight  #9C8E92
AppColors.darkSurface #1A1517
AppColors.darkCard    #261F22
```

Use theme-resolved colors whenever possible.

Do not add new hex values merely to make Subscription feel premium.

Do not introduce a gold premium theme.

`AppColors.gold` is not permission to redesign the Subscription page around gold.

## 8.2 Surface philosophy

FaceTune separates surfaces through:

1. page/surface tonal difference
2. hairline border
3. semantic tint when required
4. restrained brand accent

Not through arbitrary elevation.

Default cards:

```text
radius: 24
elevation: 0
border: hairline
```

The app philosophy is:

> **hairline + tint, not shadow**

Do not add new subscription card shadows.

## 8.3 Spacing

Use `AppSpacing.*`.

Confirmed baseline:

```text
xxs    4
xs     8
sm     12
md     16
gutter 20
lg     24
xl     32
xxl    48
```

Do not hardcode ordinary spacing values when a token exists.

## 8.4 Radius

Use only established radii:

```text
sm   12
md   18
lg   24
xl   32
pill 999
```

Cards use `lg`.

Primary/secondary buttons use `md`.

Badges/chips may use `pill`.

## 8.5 Border

Use:

```text
AppBorders.hairline = 1.0
AppBorders.emphasis = 1.5
```

The 1.5 emphasis border is the established selected/focused language.

## 8.6 Typography

Use:

```dart
Theme.of(context).textTheme
```

Do not create local `TextStyle(fontSize: ...)` values.

Use existing typography roles.

No custom font.

No bundled premium font.

No Google Fonts package.

## 8.7 Icons

Material Icons only.

Prefer rounded / outlined variants consistent with the application.

Use `AppIconSizes.*`.

Do not add emoji, custom SVG, custom icon fonts, or decorative premium assets without a separate approved design-system phase.

---

# 9. GLOBAL UI COMPONENTS — REQUIRED REUSE

Where applicable, preserve and reuse:

```text
FaceTuneTopBar
FaceTuneBackButton
PageFrame
PageFrame.scrolling
AppCard
PrimaryButton
SecondaryButton
TertiaryButton
AppNotice
StatusState
LoadingState
AppProgress
SkeletonCard
SectionHeader
showAppSnackBar
showConfirmationDialog
```

Do not recreate equivalent components locally merely to alter appearance.

The current Subscription screen is already highly aligned because it uses these primitives.

The productionization effort must evolve the page, not discard this foundation.

---

# 10. SUBSCRIPTION UI PRODUCT PRINCIPLE

The plans must communicate:

> **Same FaceTune intelligence. More freedom to create.**

Do not imply that higher tiers use a better AI model unless backend product requirements explicitly say so.

Do not invent premium-only AI quality.

Do not invent premium-only recommendation intelligence.

The primary visible plan difference is AI Look allowance and intended usage level.

The UI should make that distinction obvious.

---

# 11. PLAN HIERARCHY — LOCKED PRESENTATION INTENT

The plan hierarchy must visually communicate:

## Free

Role:

```text
ENTRY / TRY THE EXPERIENCE
```

Presentation:

- quietest plan
- normal AppCard treatment
- no artificial premium decoration
- communicates one-time AI Look availability
- establishes full product value

Do not make Free look broken or punitive.

## Plus

Role:

```text
RECOMMENDED MAINSTREAM CONSUMER PLAN
```

Presentation:

- strongest mainstream recommendation cue
- recommended / most popular badge may be used
- emphasized card treatment allowed
- clear price and allowance hierarchy
- strong primary CTA

## Pro

Role:

```text
STRONGEST CONSUMER PLAN
```

Presentation:

- clearly more capable in usage allowance than Plus
- visually premium but not a separate design language
- may use a value-oriented badge if product copy is justified
- do not visually overpower the entire page through unsupported decoration

## Salon Pro

Role:

```text
PROFESSIONAL / CLIENT-WORKFLOW PLAN
```

Presentation:

- separated from consumer plans through section structure
- must still use Global UI primitives
- do not turn it into a gold/black enterprise card
- professional differentiation comes from hierarchy, copy, iconography, and section grouping

---

# 12. PREMIUM PAGE LEAD / HERO

The Subscription page should gain stronger top-of-page value communication.

Required baseline:

- keep `FaceTuneTopBar`
- keep `PageFrame.scrolling`
- keep global page gutter
- keep theme typography
- keep theme-aware light/dark behavior

The page lead may use:

- normal global surface treatment
- OR the existing rose gradient treatment already present in FaceTune

If the rose gradient is used:

```text
roseDark → rose
```

No new gradient colors.

No second gradient family.

No new shadow.

The hero must not become a marketing splash screen that overwhelms plan selection.

Its function is to explain value and orient the user.

Suggested message intent:

```text
Create more looks. Keep every result.
Same FaceTune AI. Choose how many AI Looks you need.
```

Exact copy may be refined for fit, but must not make unsupported product claims.

---

# 13. EMPHASIZED PLAN CARD STATE

A missing Global UI capability has been identified:

```text
AppCard has no shared selected/emphasized state
```

The implementation may introduce the smallest reusable extension necessary.

Reference treatment:

```text
MakeupStyleCard selected-state language
```

Allowed visual recipe:

- existing global card radius
- existing theme surface
- semantic tint where appropriate
- `AppBorders.emphasis` 1.5 border
- existing accent role
- optional existing Material selected/check treatment

Do not create:

- glow
- drop shadow
- gold outline
- neon border
- animated gradient border
- shimmer border
- glass blur

If extending `AppCard`, preserve all existing default behavior for all current consumers.

No existing AppCard consumer should change appearance unless explicitly intended.

---

# 14. PLAN BADGES

Use the existing themed `Chip` first.

Potential labels:

```text
MOST POPULAR
BEST VALUE
CURRENT PLAN
FOR PROFESSIONALS
```

Do not display multiple competing badges on one card unless required by state.

Badge priority:

1. current plan
2. critical state / unavailable when applicable
3. recommended/value indicator

Avoid badge overload.

Do not invent ribbons unless Chip is proven insufficient and a new shared capability is approved inside the active phase.

---

# 15. PRICE PRESENTATION

The current Global UI has no centralized price typography role.

The implementation must improve price hierarchy without creating an independent typography scale.

Required structure conceptually:

```text
₱399      / month
3 AI Looks / month
```

Rules:

- use existing `TextTheme` roles
- use store-provided formatted price strings where current code already does so
- do not hardcode authoritative localized price logic into the widget
- do not parse/reconstruct localized currency strings unless already required by working code
- preserve provider/store price authority
- fallback text such as current "Price shown at checkout" must continue to work

Do not invent:

- crossed-out prices
- discounts
- savings claims
- annual equivalent
- free trial
- countdown
- introductory offer
- percentage savings

unless such data actually exists in the product model and is explicitly authorized.

---

# 16. AI LOOK ALLOWANCE EMPHASIS

The plan allowance is the core plan differentiator.

The UI should make it quickly scannable.

Allowed presentation:

- compact text block
- subtle tinted row
- themed chip/pill
- structured label/value group

Use existing colors, typography, spacing, and borders.

Do not imply rollover where none exists.

Do not call AI Looks generic "credits".

Use the product language:

```text
AI Looks
```

---

# 17. FEATURE LIST ROWS

Use:

- Material `check_rounded`
- `AppIconSizes.*`
- `AppSpacing.*`
- global text styles
- theme-aware accent/muted colors

Feature rows must be concise and scannable.

Do not create new decorative icons per feature.

Do not use emoji checkmarks.

Do not invent backend capabilities to fill visual space.

---

# 18. CTA HIERARCHY

Reuse existing button components.

## Current plan

Use a disabled/secondary presentation with clear label.

## Recommended purchasable plan

Use `PrimaryButton`.

## Other purchasable plans

Use the existing button hierarchy based on intended emphasis.

## Restore purchases

Use `TertiaryButton` or equivalent existing utility treatment.

Do not create custom premium buttons.

Do not bypass existing purchase callbacks.

Do not alter purchase-controller behavior.

The UI may use existing `isLoading` support where compatible with current state wiring, but must not alter the purchase state machine merely to drive animation.

---

# 19. PROFESSIONAL PLAN SECTION

Salon Pro must be separated structurally from consumer tiers.

Required intent:

```text
FOR MAKEUP PROFESSIONALS
```

or equivalent concise copy.

Use existing label/section typography.

Use existing spacing.

No new enterprise theme.

No gold/black redesign.

No separate page.

No custom professional icon family.

The difference should come from:

- section hierarchy
- existing premium Material iconography
- copy
- plan allowance
- CTA

---

# 20. AI LOOK INFORMATION CARD

The bottom explanatory text should become a proper Global UI component.

Prefer:

```text
AppNotice
```

or:

```text
AppCard
```

depending on current content density.

Purpose:

Explain what consumes an AI Look and what does not.

Must preserve product meaning:

An AI Look is consumed by a successfully generated and successfully persisted usable canonical Final Makeup Preview.

Do not imply consumption for:

- face analysis
- recommendation
- tutorial
- reopening existing preview
- saved looks
- history
- sharing
- failed generation

The UI copy must remain concise and user-facing.

Do not expose internal usage-ledger vocabulary.

---

# 21. RESTORE PURCHASES

Restore purchases remains a utility action.

Presentation requirements:

- existing TertiaryButton / global utility action style
- optionally appropriate existing Material icon
- secondary visual priority
- clear label
- accessible semantics

Do not change restore logic.

Do not add new provider calls.

Do not auto-trigger restore on page load as part of this UI effort.

---

# 22. LOADING / ERROR / PURCHASE UI STATES

Use existing shared UI:

```text
LoadingState
AppProgress
AppNotice
StatusState
PrimaryButton.isLoading
SecondaryButton
TertiaryButton
```

Known presentational drift may be cleaned only where directly touched:

- raw `CircularProgressIndicator` in Subscription summary may be replaced by `AppProgress` if this is behavior-neutral

Do not rewrite state management.

Do not change controller transitions.

Do not map new backend error codes.

Do not change purchase retry semantics.

Do not suppress errors.

---

# 23. MOTION LANGUAGE

Subscription may use restrained motion.

Allowed:

- `AnimatedContainer`
- `AnimatedSwitcher`
- existing implicit animations
- existing `AppDurations.quick`
- existing `AppDurations.standard`
- existing `AppCurves.standard`

Motion use cases:

- current/recommended badge transitions
- selected/emphasized card visual changes
- in-flight UI transition where state already exists

Do not add:

- bouncing cards
- looping premium shimmer
- parallax
- animated gradients
- scale-heavy attention animations
- celebratory confetti
- new animation package

Respect:

```dart
MediaQuery.disableAnimationsOf(context)
```

If animations are disabled, the UI must remain correct without transitional effects.

---

# 24. RESPONSIVE REQUIREMENTS

The page must be validated at minimum for:

- 320px logical width
- POCO X3 GT target viewport
- common larger Android phone width
- 720px PageFrame max-width context
- large text scaling
- dark mode
- light mode
- future iOS typography/layout behavior

Specific risk areas:

- plan title + badge row
- localized long price strings
- CTA labels
- professional section header
- AI Look explanation copy
- status notices
- large text scaling

Do not use fixed card heights.

Do not use a horizontal plan carousel.

Do not sacrifice readability for a desktop-like comparison grid.

Cards may remain a vertical list.

If row content cannot safely fit, stack it.

---

# 25. ACCESSIBILITY REQUIREMENTS

Preserve or improve:

- merged card semantics
- plan name announcement
- current-plan announcement
- price announcement
- allowance announcement
- button labels
- disabled-state clarity
- minimum touch sizes
- contrast
- text scaling
- live-region behavior for relevant loading/error states
- reduced-motion behavior

Color must never be the only indicator of:

- current plan
- recommended plan
- error
- loading
- disabled state

Do not use all-caps badge copy as the sole semantic indicator.

---

# 26. LIGHT / DARK THEME REQUIREMENTS

Every new or changed UI must work in both themes.

Do not assume light theme.

Do not place raw `AppColors.rose` text on dark surfaces when a contrast-safe theme helper/role exists.

Use:

```text
AppColors.muted(context)
AppColors.onTint(...)
AppColors.onAccent(...)
AppSemantics
Theme.of(context).colorScheme
```

as appropriate.

No new hardcoded `Colors.white` / `Colors.black` on normal themed surfaces unless the existing fixed-ground pattern explicitly requires it.

---

# 27. NO NEW DESIGN SYSTEM

Subscription may not define:

```text
SubscriptionColors
SubscriptionSpacing
SubscriptionTypography
SubscriptionRadii
SubscriptionButtonTheme
PremiumTheme
SalonTheme
```

unless an existing global token must be extended and the extension is explicitly justified as globally reusable.

Prefer extension of existing primitives over new parallel systems.

---

# 28. REQUIRED UI IMPLEMENTATION SCOPE

The approved feature scope contains exactly these product-facing goals:

1. Premium page lead / hero section.
2. Improved visual hierarchy across Free, Plus, Pro, Salon Pro.
3. Reusable emphasized plan card state.
4. Recommended/current-plan badge treatment.
5. Premium price layout using existing typography.
6. AI Look allowance emphasis.
7. Cleaner feature-list rows.
8. Refined CTA hierarchy.
9. Professional-plan section for Salon Pro.
10. AI Look information card.
11. Restore purchases utility treatment.
12. Purchase/loading/error UI cleanup in presentation only.
13. Subtle token-driven motion.
14. Responsive hardening.
15. Accessibility pass.
16. Widget/golden coverage for key UI states.
17. Zero backend-facing behavior changes.

Any addition outside this list requires explicit approval.

---

# 29. EXPLICITLY FORBIDDEN VISUAL TREATMENTS

Do not add:

- gold premium cards
- black-and-gold salon theme
- neon
- glassmorphism
- blur-glass cards
- outer glow
- multiple new gradients
- floating decorative orbs
- custom premium fonts
- giant price typography that breaks the existing scale
- emoji icons
- SVG crowns
- animated ribbons
- fake "limited time" urgency
- fake discount percentages
- crossed-out prices
- countdown timers
- fake user-review social proof
- "best AI" claims
- artificial feature locking that does not exist in product requirements

---

# 30. COPY SAFETY

UI copy may be polished but must not change business rules.

Do not invent:

- trial duration
- billing frequency
- rollover
- savings
- cancellation policy
- refund policy
- AI quality differences
- features not present
- priority support
- commercial licensing
- multi-user seats
- client management tooling

unless already present in authoritative product requirements.

If copy cannot be proven from current product requirements, write conservative copy or STOP for clarification.

---

# 31. TESTING STRATEGY

At minimum, the final implementation must cover:

## Component tests

- default plan card
- emphasized plan card
- current-plan card
- badge rendering
- price presentation
- AI Look allowance presentation
- feature rows
- disabled/current CTA
- loading CTA if used

## Page states

- Free current
- Plus current
- Pro current
- Salon Pro current where applicable
- recommended Plus
- Pro presentation
- Salon professional section
- purchase unavailable
- purchase loading/in-flight
- price loading/fallback
- error notice
- restore action present

## Responsive

- 320px width
- POCO X3 GT-like viewport
- large text scaling
- long localized price
- light mode
- dark mode

## Accessibility

- semantic labels
- current/recommended state not color-only
- controls remain reachable
- no overflow under text scaling

Golden tests may be added where the repository's current golden-test infrastructure supports them reliably.

Do not introduce a new screenshot-testing dependency merely for this phase unless explicitly approved.

---

# 32. VALIDATION COMMANDS

After implementation phases, run validation appropriate to the changed layer.

At minimum when Dart source changes:

```text
dart format <changed Dart files>
flutter analyze
```

Run targeted tests for changed presentation components.

Run broader `flutter test` when the phase scope justifies it and runtime is practical.

When Android compilation verification is justified:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

Do not run a production deployment.

Do not deploy Supabase functions.

Do not push migrations.

Do not mutate backend configuration.

---

# 33. GLOBAL UI PRIMITIVE EXTENSION RULE

A global primitive may be extended only when all are true:

1. the current shared primitive cannot express the required state cleanly
2. the need is not Subscription-specific decoration
3. the extension preserves all existing defaults
4. the extension is reusable
5. existing consumers remain visually unchanged by default
6. tests protect the existing behavior
7. no parallel design system is created

For this effort, the most likely justified primitive extension is:

```text
AppCard emphasized/selected visual state
```

Do not proactively generalize unrelated UI.

---

# 34. CURRENT GLOBAL UI SOURCE OF TRUTH SUMMARY

Treat this as the expected baseline unless current repository evidence disproves it:

```text
GLOBAL BACKGROUND:
AppColors.ivory / AppColors.darkSurface

GLOBAL SURFACE:
white / AppColors.darkCard

GLOBAL PRIMARY ACCENT:
AppColors.rose

GLOBAL TEXT PRIMARY:
theme ColorScheme.onSurface

GLOBAL TEXT SECONDARY:
AppColors.muted(context)

GLOBAL BORDER:
hairline 1.0
emphasis 1.5

GLOBAL CARD RADIUS:
24

GLOBAL BUTTON RADIUS:
18 primary/secondary

GLOBAL PAGE GUTTER:
20

GLOBAL CARD PADDING:
24 default AppCard

GLOBAL PAGE MAX WIDTH:
720

GLOBAL PRIMARY BUTTON:
PrimaryButton

GLOBAL SECONDARY BUTTON:
SecondaryButton

GLOBAL UTILITY BUTTON:
TertiaryButton

GLOBAL CARD:
AppCard

GLOBAL APP BAR:
FaceTuneTopBar

GLOBAL LOADING:
LoadingState / AppProgress / SkeletonCard

GLOBAL ERROR:
StatusState / AppNotice / showAppSnackBar

GLOBAL MOTION:
AppDurations + AppCurves, restrained implicit animation

GLOBAL SELECTED CARD:
not centralized before this effort

GLOBAL PRICE STYLE:
not centralized before this effort

GLOBAL HERO GRADIENT:
existing roseDark → rose treatment, historically duplicated
```

---

# 35. DEFINITION OF DONE

The Subscription UI productionization is complete only when:

- the page unmistakably still looks like FaceTune
- Global UI tokens are respected
- no new screen-specific theme exists
- plan hierarchy is clearer
- Plus reads as recommended mainstream plan
- Pro reads as strongest consumer plan
- Salon Pro is structurally separated as professional
- pricing is more scannable
- AI Look allowance is more scannable
- current plan is clear without relying only on color
- CTA hierarchy is clear
- restore remains secondary
- AI Look explanation uses a global UI component
- loading/error states use existing shared primitives
- responsive behavior is validated
- accessibility is validated
- light and dark themes are validated
- relevant tests pass
- no backend file is modified
- no billing logic is modified
- no entitlement logic is modified
- no database/RLS code is modified
- no Gemini code is modified
- no unrelated UI cleanup is bundled in
- no Git mutation outside normal local source edits is performed without authorization

---

# 36. PHASE EXECUTION RULE

Implement exactly one authorized phase at a time.

After each phase:

1. run required validation
2. produce the standard completion report
3. STOP

Do not automatically begin the next phase.

Do not combine future cleanup work.

Do not opportunistically fix unrelated Global UI drift.

---

# 37. FINAL ENGINEERING PRINCIPLE

The target is not:

> "Make the Subscription page look different."

The target is:

> **Make the Subscription page feel like the most polished, premium expression of the existing FaceTune Global UI.**

Premium quality must come from:

- hierarchy
- spacing
- typography
- composition
- clear state communication
- restrained emphasis
- responsive quality
- accessibility
- motion discipline

not from decorative excess.

If a proposed change makes the page look like a different application, reject it.

If a proposed change requires backend modification, reject it.

If a proposed change introduces unverified product claims, reject it.

If a smaller Global-UI-compliant implementation can achieve the same result, prefer the smaller implementation.
