# FaceTune — SUBSCRIPTION UI PRODUCTIONIZATION PHASE PROMPTS

**Project root:** `C:\Users\Kurt\facetune`  
**Branch:** `feature/subscription-v1`  
**Master guide:** `CODEX_MASTER_GUIDE.md`  
**Source of Truth:** `FACETUNE_SUBSCRIPTION_UI_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md`  
**This phase file:** `FACETUNE_SUBSCRIPTION_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md`  
**Primary device:** POCO X3 GT  
**Scope:** Flutter frontend / presentation only  
**Backend changes:** FORBIDDEN  



---

# HOW TO USE THIS FILE

1. Keep this file beside the Subscription UI Source of Truth in the FaceTune project root.
2. Use Claude Code Opus 5 or an equivalent coding agent.
3. Run exactly ONE phase at a time.
4. Paste only the prompt for the phase currently being implemented.
5. Review the completion report and actual diff before starting the next phase.
6. Never tell the coding agent to continue automatically.
7. Never assume a previous phase is correct merely because its report says complete.
8. Runtime/device evidence and actual source code override stale documentation.
9. Do not merge or push automatically.
10. Preserve all existing uncommitted subscription work.

Every phase requires the coding agent to read, in order:

```text
1. CODEX_MASTER_GUIDE.md
2. FACETUNE_SUBSCRIPTION_UI_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md
3. FACETUNE_SUBSCRIPTION_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md
4. relevant prior Subscription UI completion report(s)
5. actual current source code and tests relevant to the phase
6. current Global UI implementation under lib/theme/ and lib/shared/widgets/
```

---

# MANDATORY SYSTEM ROLE FOR EVERY PHASE

Act simultaneously as:

- Principal Flutter Frontend Engineer
- Senior Flutter Engineer
- Senior Dart Engineer
- Senior Design Systems Engineer
- Senior Mobile UI/UX Engineer
- Senior Accessibility Engineer
- Senior Responsive UI Engineer
- Senior Animation / Motion Engineer
- Senior Riverpod Integration Reviewer
- Senior Widget Test Engineer
- Senior Golden Test Engineer
- Senior QA / Regression Engineer
- Senior Production Debugging Engineer
- Senior Code Reviewer

Do not behave as a blind code generator.

Inspect first.

Challenge stale assumptions.

Prefer the smallest production-safe frontend change.

Preserve working subscription behavior.

---

# GLOBAL RULES FOR EVERY PHASE

Before coding:

- run `git branch --show-current`
- run `git status`
- confirm expected branch
- preserve all existing uncommitted work
- inspect the current implementation instead of coding from documentation
- inspect `lib/theme/`
- inspect `lib/shared/widgets/`
- inspect existing Subscription presentation files
- identify reusable existing code
- identify the minimum files that need modification
- identify what the phase explicitly forbids
- do not modify unrelated modules

During implementation:

- preserve Clean Architecture / Repository Pattern / feature-first organization
- keep business logic out of widgets
- preserve existing provider/controller interfaces
- use existing Global UI tokens
- use existing shared components first
- do not create a parallel Subscription theme
- do not add hardcoded design hex values
- do not add new shadows
- do not add new gradient colors
- do not add custom fonts
- do not add SVG/emoji icon language
- do not use fixed card heights
- do not alter Google Play Billing logic
- do not alter Supabase
- do not alter entitlement logic
- do not alter purchase verification
- do not alter product IDs
- do not alter database/RLS/migrations
- do not alter Gemini
- do not touch backend environment variables
- do not expose secrets
- do not automatically start later phases
- do not commit, push, merge, rebase, stash, reset, or clean unless explicitly instructed

After implementation:

- format changed Dart files
- run `flutter analyze`
- run relevant targeted tests
- run broader tests when justified
- fix errors introduced by this phase
- distinguish proven facts from assumptions
- report manual actions exactly
- STOP

- Subscription UI Productionization MUST NOT modify, refactor, migrate, rename, reconfigure, or “clean up” Step-by-Step Tutorial V4. Any file belonging to Tutorial V4 is read-only unless the user explicitly authorizes a separate Tutorial V4 phase.
---

# STRICT NO-BACKEND GUARD

If any implementation idea requires modification to any of these:

```text
supabase/
migrations
Edge Functions
Google Play Developer API
google_play_api.ts
verification.ts
purchase verification
entitlement activation
usage ledger
service account
OAuth/JWT
billing gateway
purchase acknowledgement logic
Gemini
environment variables
production secrets
```

STOP and report:

```text
BACKEND DEPENDENCY DETECTED — OUT OF SCOPE
```

Do not implement a workaround.

---

# STANDARD SUBSCRIPTION UI COMPLETION REPORT

Every phase must end with:

```text
PHASE COMPLETED:

BRANCH VERIFIED:

OBJECTIVE ACHIEVED:

FILES CREATED:

FILES MODIFIED:

FILES DELETED:
None / exact list and justification

GLOBAL UI PRIMITIVES ADDED / EXTENDED:
None / exact list

GLOBAL UI TOKENS ADDED / CHANGED:
None / exact list and justification

SUBSCRIPTION PRESENTATION CHANGES:

RESPONSIVE CHANGES:

ACCESSIBILITY CHANGES:

MOTION CHANGES:

BUSINESS LOGIC CHANGES:
NONE

PURCHASE CONTROLLER CHANGES:
NONE

GOOGLE PLAY BILLING CHANGES:
NONE

SUPABASE CHANGES:
NONE

DATABASE / RLS CHANGES:
NONE

EDGE FUNCTION CHANGES:
NONE

GEMINI CHANGES:
NONE

DEPENDENCIES ADDED / REMOVED:
None / exact list and justification

TESTS ADDED / MODIFIED:

VALIDATION RUN:

FLUTTER ANALYZE:

TARGETED TEST RESULT:

BROADER TEST RESULT:
Not run / exact result

ANDROID BUILD RESULT:
Not run / exact result

REAL DEVICE / SCREEN SIZE EVIDENCE:
Not run / exact evidence

LIGHT THEME VERIFIED:
Yes / No / Not yet

DARK THEME VERIFIED:
Yes / No / Not yet

320PX WIDTH VERIFIED:
Yes / No / Not yet

LARGE TEXT VERIFIED:
Yes / No / Not yet

KNOWN LIMITATIONS:

ASSUMPTIONS NOT PROVEN:

MANUAL ACTION REQUIRED:
None / exact action

NEXT RECOMMENDED PHASE:

GIT MUTATIONS:
NONE unless explicitly authorized

STOP CONFIRMATION:
No later phase was implemented.
```

A vague completion report is not acceptable.

---

# SUB-UI-0 — BASELINE REVALIDATION & IMPLEMENTATION MAP

Read all mandatory authority files completely before making changes.

Implement only **SUB-UI-0 — BASELINE REVALIDATION & IMPLEMENTATION MAP**.

This phase is READ-ONLY.

## Active roles

Especially apply:

- Principal Flutter Frontend Engineer
- Senior Design Systems Engineer
- Senior Code Reviewer
- Senior QA Engineer
- Senior Production Debugging Engineer

## Objective

Revalidate the Subscription UI and Global UI baseline immediately before implementation so the productionization work is based on the actual current working tree, not stale audit assumptions.

## Before coding

- verify current branch
- record `git status`
- inspect current Subscription page
- inspect current plan-card widget
- inspect current plan presentation utility
- inspect current summary card
- inspect current Global UI tokens/theme/shared primitives
- inspect current Subscription widget tests
- inspect whether any files changed since the Global UI audit
- inspect active current-plan, price, loading, unavailable, restore, and purchase state presentation

Do not trust previous audit line numbers blindly.

## Implement

Do not modify product source.

Produce the implementation map in the completion report.

At minimum identify:

- exact Subscription presentation files that will be touched
- exact shared UI primitives likely to be reused
- whether `AppCard` still lacks an emphasized state
- whether Chip is still the correct badge primitive
- current price representation
- current allowance representation
- current feature-list implementation
- current CTA behavior
- current professional plan placement
- current AI Look information copy
- current restore placement
- current loading/error presentation
- current semantics
- current responsive risk areas
- tests already covering the screen

## Non-negotiable rules

- read only
- no source changes
- no format operation
- no dependency changes
- no backend inspection beyond confirming presentation interfaces when needed
- no Git mutation
- actual code wins over stale audit text

## Do NOT implement

- hero
- emphasized cards
- badges
- new price layout
- new plan hierarchy
- responsive fixes
- animations
- tests for future design
- cleanup

## Tests / validation

At minimum:

```text
git branch --show-current
git status
flutter analyze
```

If `flutter analyze` is already known to be expensive in the environment, run it unless there is a concrete blocker and report that blocker.

## Done when

- current frontend baseline is proven
- minimal file-touch map is known
- no source code changed
- SUB-UI-1 boundary is precise

## Completion report

Use the STANDARD SUBSCRIPTION UI COMPLETION REPORT.

Then STOP.

Do not implement SUB-UI-1 unless explicitly instructed.

---

# SUB-UI-1 — SHARED EMPHASIS PRIMITIVE & PRESENTATION CONTRACTS

Read all mandatory authority files completely before making changes.

Implement only **SUB-UI-1 — SHARED EMPHASIS PRIMITIVE & PRESENTATION CONTRACTS**.

Do not redesign the full Subscription page in this phase.

## Active roles

Especially apply:

- Senior Flutter Engineer
- Senior Dart Engineer
- Senior Design Systems Engineer
- Senior Accessibility Engineer
- Senior Widget Test Engineer
- Senior Code Reviewer

## Objective

Add only the minimum frontend capabilities required for later Subscription hierarchy without creating a Subscription-specific design system.

## Before coding

- inspect `AppCard`
- inspect `MakeupStyleCard` selected-state treatment
- inspect themed Chip behavior
- inspect Global UI border, radius, semantic tint, and animation tokens
- inspect existing AppCard tests
- confirm whether the safest architecture is an AppCard extension or a small reusable composition

Do not assume extending `AppCard` is automatically correct.

## Implement

Implement the minimum reusable capability for an emphasized/selected card state.

The intended recipe is:

- global card radius
- existing theme surface
- semantic tint only where appropriate
- `AppBorders.emphasis`
- existing accent role
- no shadow
- no new color
- no new radius
- no new animation language

Preserve default AppCard appearance exactly for existing consumers.

If a presentation-only model/value object is required for plan visual hierarchy, keep it in the presentation layer and do not duplicate business plan identities.

Do not create `SubscriptionTheme`.

## Non-negotiable rules

- existing AppCard default behavior must remain unchanged
- no new hex values
- no new shadows
- no new dependencies
- no backend changes
- do not change `MakeupStyleCard` unless reuse genuinely requires a shared extraction and regression risk is controlled
- color cannot be the only selected-state signal

## Do NOT implement

- full Subscription page redesign
- hero
- new price layout
- professional section
- new purchase flow
- backend changes
- plan copy rewrite
- broad Global UI refactor

## Tests / validation

Test at minimum:

- default AppCard unchanged
- emphasized AppCard light theme
- emphasized AppCard dark theme
- emphasized state semantics if applicable
- border uses global emphasis token
- no elevation/shadow introduced

Run:

```text
dart format <changed files>
flutter analyze
flutter test <targeted relevant tests>
```

## Done when

- one reusable Global-UI-compliant emphasized surface capability exists
- existing consumers remain unchanged by default
- tests protect behavior
- no Subscription screen redesign has started

## Completion report

Use the STANDARD SUBSCRIPTION UI COMPLETION REPORT.

Then STOP.

Do not implement SUB-UI-2 unless explicitly instructed.

---

# SUB-UI-2 — PAGE LEAD & PLAN INFORMATION HIERARCHY

Read all mandatory authority files completely before making changes.

Implement only **SUB-UI-2 — PAGE LEAD & PLAN INFORMATION HIERARCHY**.

## Active roles

Especially apply:

- Senior Flutter Frontend Engineer
- Senior Mobile UI/UX Engineer
- Senior Design Systems Engineer
- Senior Product UI Engineer
- Senior Accessibility Engineer
- Senior Widget Test Engineer

## Objective

Improve the top-of-page value communication and the information hierarchy inside plan cards while preserving current purchase behavior.

## Before coding

- inspect current page title/lead
- inspect Home/Auth existing rose-gradient hero implementations
- inspect `TopLevelPageHeader`, `SectionHeader`, and AppCard
- inspect plan price data type and formatted store price flow
- inspect current allowance copy
- inspect current feature-list rows

## Implement

### Page lead

Keep:

```text
FaceTuneTopBar
PageFrame.scrolling
SafeArea(top:false)
```

Add a more deliberate page lead.

Preferred message intent:

```text
Create more looks. Keep every result.
Same FaceTune AI. Choose how many AI Looks you need.
```

Exact copy may be adjusted for existing product language and fit.

If a hero surface is used:

- only use the existing roseDark → rose recipe
- no new gradient
- no new shadow
- no new palette
- preserve contrast in both themes

If a non-gradient global surface is cleaner, prefer the simpler implementation.

### Plan information hierarchy

Refactor plan-card presentation order to emphasize:

```text
plan identity
purpose/tagline
price
billing period
AI Look allowance
key benefits
CTA
```

Improve price presentation using existing TextTheme roles.

Do not add a new typography scale.

Preserve store/localized formatted price authority.

Improve AI Look allowance scanability using existing tokens/components.

Clean feature rows using:

```text
check_rounded
AppIconSizes
AppSpacing
Theme.of(context).textTheme
```

## Non-negotiable rules

- no hardcoded price authority
- no string parsing that damages localization
- no fake discount
- no crossed-out price
- no annual equivalent
- no trial claims
- no backend changes
- no custom font
- no fixed card height

## Do NOT implement

- recommended badges
- professional Salon section
- selected/current-plan styling beyond what already exists
- motion polish
- responsive hardening beyond avoiding regressions
- backend changes

## Tests / validation

Test at minimum:

- formatted store price displayed unchanged
- fallback price copy still works
- Free price state
- paid monthly price
- long localized price does not crash
- plan allowance visible
- feature rows render
- semantics continue to announce meaningful plan information

Run:

```text
dart format <changed files>
flutter analyze
flutter test <targeted tests>
```

## Done when

- page lead is stronger
- plan card content is more scannable
- price is visually clearer
- allowance is visually clearer
- current purchase callbacks are unchanged

## Completion report

Use the STANDARD SUBSCRIPTION UI COMPLETION REPORT.

Then STOP.

Do not implement SUB-UI-3 unless explicitly instructed.

---

# SUB-UI-3 — PLAN DIFFERENTIATION, BADGES & CTA HIERARCHY

Read all mandatory authority files completely before making changes.

Implement only **SUB-UI-3 — PLAN DIFFERENTIATION, BADGES & CTA HIERARCHY**.

## Active roles

Especially apply:

- Senior Flutter Frontend Engineer
- Senior Design Systems Engineer
- Senior Product UI Engineer
- Senior Accessibility Engineer
- Senior Widget Test Engineer
- Senior QA Engineer

## Objective

Create clear visual hierarchy between Free, Plus, Pro, and the user's current plan without inventing a new premium design system.

## Before coding

- inspect current plan identifiers
- inspect plan-presentation mapping
- inspect current-plan logic already exposed to presentation
- inspect recommended plan requirements from the Source of Truth
- inspect themed Chip
- inspect emphasized surface from SUB-UI-1
- inspect button hierarchy

## Implement

### Free

- normal quiet AppCard
- no premium badge
- no artificial visual penalty

### Plus

Treat as recommended mainstream consumer plan.

Allowed:

```text
MOST POPULAR
```

or equivalent concise copy.

Use themed Chip first.

Use emphasized card treatment where appropriate.

Use PrimaryButton for the recommended purchasable CTA.

### Pro

Treat as strongest consumer usage plan.

May use a concise value-oriented badge only if it does not compete with Current Plan state.

Do not invent price savings.

Do not make Pro visually look like a different application.

### Current plan

Current plan state must override recommendation decoration when both apply.

Use clear words plus appropriate visual treatment.

Do not rely on color alone.

### CTA hierarchy

- recommended purchasable plan → PrimaryButton
- current plan → disabled/secondary clear label
- secondary utility actions → TertiaryButton
- preserve existing callbacks exactly

## Non-negotiable rules

- presentation must not infer entitlement independently
- current plan comes from existing authoritative state
- recommendation status is presentation metadata only
- no purchase state changes
- no provider logic changes
- no custom buttons
- no extra shadows/glows

## Do NOT implement

- Salon professional section restructuring
- AI Look information card
- restore redesign
- global responsive hardening
- broad animation pass
- backend changes

## Tests / validation

Test at minimum:

- Free card
- Plus recommended card
- Pro card
- current Free
- current Plus
- current Pro
- recommendation badge hidden/replaced correctly for current plan
- CTA labels/states
- light theme
- dark theme
- semantics distinguish current vs recommended

Run:

```text
dart format <changed files>
flutter analyze
flutter test <targeted tests>
```

## Done when

- hierarchy is immediately understandable
- Plus reads as recommended mainstream plan
- Pro reads as stronger consumer usage plan
- current plan is unmistakable
- purchase behavior is untouched

## Completion report

Use the STANDARD SUBSCRIPTION UI COMPLETION REPORT.

Then STOP.

Do not implement SUB-UI-4 unless explicitly instructed.

---

# SUB-UI-4 — PROFESSIONAL SALON SECTION, AI LOOK INFO & RESTORE UTILITY

Read all mandatory authority files completely before making changes.

Implement only **SUB-UI-4 — PROFESSIONAL SALON SECTION, AI LOOK INFO & RESTORE UTILITY**.

## Active roles

Especially apply:

- Senior Flutter Frontend Engineer
- Senior Product UI Engineer
- Senior Mobile UI/UX Engineer
- Senior Design Systems Engineer
- Senior Accessibility Engineer
- Senior Widget Test Engineer

## Objective

Separate the professional Salon Pro context from consumer plans and improve bottom-of-page explanatory/utility content using existing Global UI components.

## Before coding

- inspect current Salon Pro placement
- inspect `SectionHeader`
- inspect label typography
- inspect AppNotice
- inspect current AI Look explanatory copy
- inspect Restore Purchases callback and existing TertiaryButton usage

## Implement

### Professional section

Insert a structural section boundary above Salon Pro.

Use copy such as:

```text
FOR MAKEUP PROFESSIONALS
```

or an equivalent concise label consistent with product language.

Use existing typography/tokens.

Salon Pro remains an AppCard using the same global system.

Do not give Salon Pro a black/gold theme.

### AI Look information

Replace the loose explanatory/disclaimer paragraph with:

```text
AppNotice
```

or `AppCard` if content structure justifies it.

Explain user-facing AI Look consumption accurately and concisely.

Do not expose:

- operation IDs
- reservation state
- usage ledger
- provider tokens
- internal cost

### Restore utility

Keep Restore Purchases secondary.

Use existing TertiaryButton and, if useful, an existing Material icon.

Preserve callback logic exactly.

## Non-negotiable rules

- do not invent salon business features
- do not invent multi-user/client management
- do not invent licensing/support benefits
- no backend changes
- restore remains explicit user action
- AI Look wording must remain accurate

## Do NOT implement

- backend restore changes
- subscription lifecycle reconciliation
- SUB-11
- Free entitlement provisioning / SUB-12
- motion pass
- full responsive pass

## Tests / validation

Test at minimum:

- consumer/professional section ordering
- Salon Pro still purchasable through existing callback
- AI Look info renders
- Restore Purchases renders and calls existing callback
- accessibility labels remain meaningful

Run:

```text
dart format <changed files>
flutter analyze
flutter test <targeted tests>
```

## Done when

- Salon Pro is clearly a professional section
- explanatory copy is structured through Global UI
- Restore remains secondary
- no behavior changed

## Completion report

Use the STANDARD SUBSCRIPTION UI COMPLETION REPORT.

Then STOP.

Do not implement SUB-UI-5 unless explicitly instructed.

---

# SUB-UI-5 — PRESENTATION-ONLY STATE POLISH & MOTION

Read all mandatory authority files completely before making changes.

Implement only **SUB-UI-5 — PRESENTATION-ONLY STATE POLISH & MOTION**.

## Active roles

Especially apply:

- Senior Flutter Engineer
- Senior Motion Engineer
- Senior Accessibility Engineer
- Senior Design Systems Engineer
- Senior QA Engineer
- Senior Widget Test Engineer

## Objective

Polish loading, unavailable, in-flight, and visual state transitions using existing frontend state and existing Global UI primitives.

## Before coding

- inspect purchase-controller state exposed to UI
- inspect page AppNotice states
- inspect Subscription summary loading state
- inspect existing AppProgress
- inspect AppDurations/AppCurves
- inspect `MediaQuery.disableAnimationsOf`

Do not change state machines.

## Implement

Presentation-only cleanup may include:

- replace raw Subscription `CircularProgressIndicator` with `AppProgress` where behavior-neutral
- use button `isLoading` only if existing state mapping is unambiguous and does not change event handling
- use `AnimatedSwitcher` / `AnimatedContainer` for visual-state transitions where valuable
- use only global durations/curves
- honor reduced motion

All loading/error/unavailable states must remain driven by existing state.

## Non-negotiable rules

- no new controller states
- no new backend error mapping
- no retry logic changes
- no purchase acknowledgement changes
- no automatic restore
- no looping decorative animation
- no shimmer premium effect
- no animation package

## Do NOT implement

- responsive hardening
- golden test matrix
- backend changes
- business logic changes

## Tests / validation

Test at minimum:

- loading state
- purchase unavailable state
- purchase in-flight state where exposed
- error AppNotice state
- reduced motion behavior where testable
- button cannot be double-triggered due to UI animation changes

Run:

```text
dart format <changed files>
flutter analyze
flutter test <targeted tests>
```

## Done when

- UI states feel deliberate
- raw progress drift in Subscription is removed where appropriate
- motion remains restrained
- purchase behavior is unchanged

## Completion report

Use the STANDARD SUBSCRIPTION UI COMPLETION REPORT.

Then STOP.

Do not implement SUB-UI-6 unless explicitly instructed.

---

# SUB-UI-6 — RESPONSIVE & ACCESSIBILITY HARDENING

Read all mandatory authority files completely before making changes.

Implement only **SUB-UI-6 — RESPONSIVE & ACCESSIBILITY HARDENING**.

## Active roles

Especially apply:

- Senior Responsive Flutter Engineer
- Senior Accessibility Engineer
- Senior Mobile UI/UX Engineer
- Senior Flutter Engineer
- Senior QA Engineer
- Senior Widget Test Engineer

## Objective

Make the productionized Subscription page robust across narrow phones, POCO X3 GT, larger devices, large text, and light/dark themes without changing product behavior.

## Before coding

Inspect every row that can compress:

- plan title + badge
- price + billing period
- allowance treatment
- feature rows
- CTA labels
- professional section label
- notices
- restore action

Inspect existing PageFrame behavior.

Inspect current semantics.

## Implement

Harden layout for:

```text
320px logical width
POCO X3 GT viewport
larger Android phone
720px PageFrame width
large text scaling
light theme
dark theme
```

Rules:

- stack instead of overflow
- do not truncate critical plan/price/allowance information
- do not use fixed card heights
- buttons retain minimum touch sizes
- plan badges wrap/reflow safely
- long localized prices remain legible
- current/recommended states remain understandable without color
- merged semantics remain accurate
- decorative elements are excluded from semantics where appropriate

## Non-negotiable rules

- no layout-specific business logic
- no device-name conditionals
- no hardcoded POCO-only dimensions
- no text scale suppression
- no `FittedBox` that makes important text unreadably small
- no horizontal plan carousel
- no desktop-only comparison table

## Do NOT implement

- new visual concepts
- backend changes
- final broad cleanup outside Subscription

## Tests / validation

Test at minimum:

- width 320
- representative POCO width
- wide phone/tablet-constrained PageFrame
- 2x text scale or repository-standard large-text case
- long localized price string
- light theme
- dark theme
- semantics for current plan
- semantics for recommended plan
- semantics for Restore Purchases

Run:

```text
dart format <changed files>
flutter analyze
flutter test <targeted tests>
```

When practical, also validate on the physical POCO X3 GT.

## Done when

- no overflow in required states
- no clipped critical content
- touch targets remain valid
- semantics are coherent
- both themes remain visually consistent

## Completion report

Use the STANDARD SUBSCRIPTION UI COMPLETION REPORT.

Then STOP.

Do not implement SUB-UI-7 unless explicitly instructed.

---

# SUB-UI-7 — WIDGET / GOLDEN COVERAGE & FINAL UI BASELINE LOCK

Read all mandatory authority files completely before making changes.

Implement only **SUB-UI-7 — WIDGET / GOLDEN COVERAGE & FINAL UI BASELINE LOCK**.

## Active roles

Especially apply:

- Senior Widget Test Engineer
- Senior Golden Test Engineer
- Senior QA / Regression Engineer
- Senior Flutter Engineer
- Senior Accessibility Engineer
- Senior Code Reviewer

## Objective

Lock the final Subscription UI behavior and visual contract with tests, then perform a frontend-only final audit.

## Before coding

- inspect existing Subscription tests
- inspect existing design-system tests
- inspect repository golden-test infrastructure
- inspect all SUB-UI completion reports
- inspect final diff against SUB-UI-0 baseline
- confirm no backend files changed

## Implement

Add or strengthen tests for the final productionized UI.

Required state coverage:

- Free card
- recommended Plus
- Pro
- Salon Pro
- current Free
- current Plus
- current Pro
- current Salon Pro if supported
- unavailable purchase
- loading/in-flight state
- fallback price
- long localized price
- light theme
- dark theme
- 320px width
- large text
- AI Look info
- Restore Purchases
- professional section
- accessibility semantics

Use golden tests only if current repository infrastructure supports them cleanly.

Do not add a new golden framework dependency.

Perform final frontend audit for:

- hardcoded colors
- hardcoded font sizes
- non-token ordinary spacing
- new shadow usage
- unsupported gradients
- raw button recreation
- raw progress indicators in touched Subscription files
- overflow risk
- semantics regression
- backend file changes

## Non-negotiable rules

- tests must assert meaningful behavior, not implementation trivia
- do not update goldens blindly merely to make tests pass
- investigate unexpected visual diffs
- no backend changes
- no dependency additions without explicit justification

## Validation

Run:

```text
dart format <changed files>
flutter analyze
flutter test
```

If the entire suite cannot run for an environmental reason, report the exact reason and run the strongest targeted set possible.

When justified:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

If a physical POCO X3 GT is available, perform a final manual UI verification.

## Final audit

Report exact confirmation that:

```text
BUSINESS LOGIC CHANGES: NONE
PURCHASE CONTROLLER CHANGES: NONE
GOOGLE PLAY BILLING CHANGES: NONE
SUPABASE CHANGES: NONE
DATABASE/RLS CHANGES: NONE
EDGE FUNCTION CHANGES: NONE
GEMINI CHANGES: NONE
```

## Done when

- required UI states have test coverage
- final UI follows Global UI
- responsive/accessibility requirements are met
- no protected system changed
- final audit is clean
- any remaining limitations are explicitly documented

## Completion report

Use the STANDARD SUBSCRIPTION UI COMPLETION REPORT.

Then STOP.

Do not start another feature phase automatically.

---

# FINAL EXECUTION RULE

Run phases in order:

```text
SUB-UI-0
→ SUB-UI-1
→ SUB-UI-2
→ SUB-UI-3
→ SUB-UI-4
→ SUB-UI-5
→ SUB-UI-6
→ SUB-UI-7
```

One phase at a time.

Review actual source changes after every phase.

Do not automatically proceed.

The coding agent must never interpret this file as permission to modify backend subscription architecture.

The final success condition is:

> **A premium, polished Subscription experience that is unmistakably FaceTune, fully aligned with the existing Global UI, and achieved without changing any backend-facing behavior.**
