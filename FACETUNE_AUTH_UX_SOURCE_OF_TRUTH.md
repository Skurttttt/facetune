# FaceTune — AUTHENTICATION UX PRODUCTIONIZATION SOURCE OF TRUTH

**Project Name:** FaceTune
**Tagline:** Your AI Makeup Artist
**Primary Platform:** Android
**Primary Test Device:** POCO X3 GT
**Framework:** Flutter
**Language:** Dart
**Backend:** Supabase — HARD PROTECTED
**AI Provider:** Google Gemini API — HARD PROTECTED
**State Management:** Riverpod
**Architecture:** Clean Architecture + Repository Pattern + Feature-First Structure

**Recommended Target Branch:** `feature/auth-ux-v1` — existence/base MUST be proven in AUTHUX-P0; never create/switch/reset automatically without explicit user instruction.
**Accepted Base:** MUST be proven from the current accepted working FaceTune baseline after the completed Profile + Settings UX work. Never assume `main` or any older branch contains the latest accepted UI.
**Source of Truth:** `FACETUNE_AUTH_UX_SOURCE_OF_TRUTH.md`
**Phase Prompt File:** `FACETUNE_AUTH_UX_PHASE_PROMPTS.md`

**Canonical Final Preview Renderer — HARD LOCK:** `gemini-3.1-flash-image`
**Tutorial Guideline Renderer — HARD LOCK:** `gemini-3.1-flash-image`
**Tutorial Guideline Resolution — HARD LOCK:** `1K`
**Tutorial Prompt — HARD LOCK:** `tutorial_guideline_v4_7`
**Manifest Prompt — HARD LOCK:** `tutorial_manifest_v4_1`

**Recommendation Modes:** `standard` + `my_makeup_kit`
**UI Design Direction:** Luminous Beauty Intelligence
**Track Scope:** Login + Sign Up presentation-layer UX productionization only
**Track Principle:** preserve the existing FaceTune visual system; allow page composition and information architecture to improve; preserve all backend/auth/business behavior
**Release Goal:** an intentional, compact, accessible, responsive, industry-ready Login and Sign Up experience that removes the visible guest entry point from Login, improves password guidance, and changes absolutely no authentication backend, auth provider, session, persistence, billing, entitlement, AI, or protected feature behavior.

---

# 0. PURPOSE

This document is the highest authority for the FaceTune **Authentication UX Productionization Track**.

FaceTune already has accepted working authentication and application behavior.

This track exists to improve exactly these presentation areas:

```text
LOGIN
- reduce oversized decorative branding
- make authentication the primary task
- improve hierarchy
- preserve email/password sign-in
- preserve Google sign-in
- preserve forgot-password behavior
- preserve create-account navigation
- remove the visible "Explore as a guest" entry point
- remove guest-only explanatory copy from Login
- preserve all guest/anonymous logic underneath

SIGN UP
- improve hierarchy
- improve field composition
- improve password guidance
- add live password requirement presentation
- improve confirm-password feedback
- improve loading / error / keyboard / autofill presentation
- preserve existing account-creation behavior

CROSS-SCREEN
- preserve FaceTune colors
- preserve FaceTune typography
- preserve FaceTune sizing
- preserve spacing / radius / icon families
- preserve Light / Dark / System
- improve accessibility
- improve responsive behavior
```

The central principle is:

> **PRODUCTIONIZE THE AUTH EXPERIENCE WITHOUT REOPENING AUTHENTICATION.**

A visually attractive implementation that changes Supabase Auth, email/password behavior, Google OAuth, password policy, session behavior, guest/anonymous auth logic, database/security rules, or account creation behavior is a failure.

---

# 1. DOCUMENT AUTHORITY

Before any phase, read completely, in order, when present:

```text
1. CODEX_MASTER_GUIDE.md
2. accepted authentication source-of-truth / phase documents if any exist
3. accepted subscription/billing source-of-truth / phase documents
4. FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_SOURCE_OF_TRUTH.md
5. FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_PHASE_PROMPTS.md
6. FACETUNE_V4_TUTORIAL_QUALITY_SOURCE_OF_TRUTH.md
7. FACETUNE_V4_TUTORIAL_QUALITY_PHASE_PROMPTS.md
8. FACETUNE_UI_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md
9. FACETUNE_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md
10. FACETUNE_TUTORIAL_UI_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md
11. FACETUNE_TUTORIAL_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md
12. FACETUNE_HISTORY_UI_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md
13. FACETUNE_HISTORY_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md
14. FACETUNE_GLOBAL_TOP_LEVEL_UI_POLISH_SOURCE_OF_TRUTH.md
15. FACETUNE_GLOBAL_TOP_LEVEL_UI_POLISH_PHASE_PROMPTS.md
16. FACETUNE_PROFILE_SETTINGS_UX_SOURCE_OF_TRUTH.md
17. FACETUNE_PROFILE_SETTINGS_UX_PHASE_PROMPTS.md
18. FACETUNE_AUTH_UX_SOURCE_OF_TRUTH.md
19. FACETUNE_AUTH_UX_PHASE_PROMPTS.md
20. accepted completion reports relevant to auth/profile/settings/global UI
21. actual current source, tests, routing, validators, providers, theme, and current Git diff
```

Authority rules:

1. This document governs this narrow Authentication UX track.
2. Actual current code beats assumptions.
3. Screenshots are visual evidence, not behavioral proof.
4. Tests are regression evidence, not visual proof.
5. Existing accepted UI authorities govern design tokens and visual identity.
6. Existing auth/domain authorities govern backend authentication behavior.
7. Existing billing/subscription authorities govern entitlement behavior.
8. The active phase prompt authorizes only that phase.
9. A completion report is evidence, not permission for the next phase.
10. A phase may never widen its scope silently.
11. UI convenience never authorizes backend/domain/security changes.
12. If any request conflicts with a protected authority, STOP and report.
13. If an authority file is missing, do not invent its contents.
14. If current behavior is ambiguous, inspect source and report the ambiguity.

---

# 2. SYSTEM ROLE

The coding agent must behave as a disciplined production authentication UI engineering team.

## Architecture / Leadership

- Principal Software Engineer
- Principal Software Architect
- Principal Mobile Architect
- Principal Flutter Architect
- Senior Software Engineer
- Senior Software Developer
- Senior Code Reviewer
- Senior Release Engineer

## Frontend / Flutter

- Senior Frontend Engineer
- Senior Frontend Developer
- Senior Flutter Engineer
- Senior Flutter Developer
- Senior Dart Engineer
- Senior Dart Developer
- Senior Riverpod Engineer
- Senior Mobile Application Engineer
- Senior Mobile Application Developer
- Senior Flutter UI Engineer
- Senior Mobile UI Engineer
- Senior Component Library Engineer
- Senior Responsive Layout Engineer
- Senior Interaction Engineer
- Senior Form UX Engineer
- Senior Authentication UI Engineer

## Product / UX

- Senior Mobile Product Designer
- Senior UI Designer
- Senior UX Designer
- Senior UI/UX Designer
- Senior Interaction Designer
- Senior Information Architecture Designer
- Senior Beauty-App Product Designer
- Senior Content Designer
- Senior UX Writer
- Senior Form Design Specialist

## Accessibility / Quality

- Senior Accessibility Engineer
- Senior Inclusive Design Engineer
- Senior Semantic UI Engineer
- Senior Localization-Readiness Engineer
- Senior QA Engineer
- Senior Regression Engineer
- Senior Widget Test Engineer
- Senior Integration Test Engineer
- Senior End-to-End Test Engineer
- Senior Visual QA Engineer
- Senior Performance Engineer
- Senior Reliability Engineer
- Senior Production Debugging Engineer

## Protection / Security

- Senior Application Security Engineer
- Senior Privacy Engineer
- Senior Supabase Engineer
- Senior Backend Engineer
- Senior Authentication Engineer
- Senior Identity and Access Management Engineer
- Senior OAuth Engineer
- Senior Google Sign-In Engineer
- Senior Session Security Engineer
- Senior Google Play Billing Engineer
- Senior Subscription Systems Engineer

## Protected AI / Domain Awareness

- Senior Gemini AI Engineer
- Senior AI Systems Engineer
- Senior My Makeup Kit Engineer

Protection roles exist to **protect accepted behavior**, not redesign it.

The agent must:

```text
inspect first
challenge stale assumptions
preserve valid working-tree work
reuse accepted components/tokens
prefer the smallest safe presentation-layer change
avoid broad rewrites
avoid architecture refactors
avoid backend refactors
avoid auth refactors
prove behavior before changing presentation
STOP if a UI request requires protected changes
```

---

# 3. TRACK BOUNDARY

Authorized track surface:

```text
Login presentation
Sign Up presentation
auth form composition
labels
descriptions
brand block proportion
spacing
grouping
password requirement presentation
confirm-password presentation
loading presentation
error presentation
keyboard configuration
autofill hints
focus order
responsive behavior
accessibility
UI-only removal of visible guest entry
```

Not authorized:

```text
authentication backend
auth providers
Supabase Auth
Google OAuth
account creation business logic
password backend policy
session logic
guest auth implementation
database
RLS
Storage
Edge Functions
billing
subscriptions
entitlements
AI
recommendations
Final Preview
Tutorial
History
Saved Looks
My Makeup Kit
Standard Mode
```

---

# 4. ABSOLUTE AI / V4 HARD LOCK

Every phase must preserve exactly:

```text
FINAL PREVIEW MODEL
= gemini-3.1-flash-image

TUTORIAL MODEL
= gemini-3.1-flash-image

TUTORIAL RESOLUTION
= 1K

TUTORIAL PROMPT
= tutorial_guideline_v4_7

MANIFEST PROMPT
= tutorial_manifest_v4_1
```

Do NOT modify:

```text
Gemini model names
Gemini model configuration
Gemini prompts
AI request/response contracts
AI retries
AI fallbacks
AI call counts
Final Preview
Tutorial generation
Dynamic Manifest
face analysis
recommendations
Standard authority
My Makeup Kit authority
```

Expected:

```text
AI DIFF = NONE
EXTRA AI CALLS = 0
```

---

# 5. ABSOLUTE BACKEND / SECURITY HARD LOCK

Do NOT modify:

```text
Supabase initialization
Supabase Auth backend
database schema
migrations
tables
columns
views
functions
triggers
RPCs
RLS
RLS policies
grants
Storage
Storage policies
private buckets
signed URLs
Edge Functions
JWT handling
authorization logic
secrets
server-side authentication
repository contracts merely for UI convenience
```

Expected:

```text
git diff -- supabase/
= NONE for this track
```

If a requested UX improvement requires a protected backend/domain/security change:

```text
STOP
REPORT
DO NOT IMPLEMENT
```

---

# 6. ABSOLUTE AUTHENTICATION HARD LOCK

Do NOT modify:

```text
email/password sign-in behavior
email/password sign-up behavior
auth controller business logic
auth repository behavior
auth datasource behavior
Google Sign-In implementation
Google OAuth client configuration
redirect behavior
token exchange
token persistence
session restoration
session ownership
sign-out behavior
password reset backend behavior
email verification behavior
account creation flow
profile bootstrap behavior after registration
auth redirect behavior
router auth guards
```

Expected:

```text
AUTH BACKEND CHANGES = NONE
EMAIL SIGN-IN CHANGES = NONE
EMAIL SIGN-UP CHANGES = NONE
GOOGLE AUTH CHANGES = NONE
SESSION LOGIC CHANGES = NONE
PASSWORD RESET BACKEND CHANGES = NONE
EMAIL VERIFICATION CHANGES = NONE
ACCOUNT CREATION LOGIC CHANGES = NONE
```

Presentation may call the same existing callbacks.

Presentation may not change what those callbacks do.

---

# 7. GUEST / ANONYMOUS AUTH HARD LOCK

The product decision for this track is intentionally conservative:

> **Remove only the visible guest entry point from Login. Preserve all guest/anonymous authentication logic underneath.**

Authorized:

```text
remove "Explore as a guest" from Login UI
remove guest-only explanatory copy from Login UI
adjust spacing after removal
update presentation tests that explicitly expect the guest control
```

Hard locked:

```text
anonymous auth implementation
guest auth provider
guest auth callback
guest route definitions
guest session state
guest persistence
guest data isolation
guest upgrade/conversion logic
Supabase anonymous auth
guest-specific backend rules
guest-specific repositories
guest-specific auth guards
```

Mandatory invariant:

```text
GUEST UI ENTRY POINT = REMOVED
GUEST FEATURE LOGIC = PRESERVED
```

Do NOT interpret removal from the UI as permission to delete guest code.

---

# 8. PASSWORD POLICY HARD LOCK

The password validation component must reflect the existing accepted password contract exactly.

Before any live checklist is implemented, AUTHUX-P0 must prove:

```text
actual password validator owner
actual minimum length
actual letter requirement
actual numeric requirement
any other actual enforced requirements
where validation happens
whether backend/server imposes additional rules
confirm-password validator owner
```

Mandatory invariant:

```text
PASSWORD UI RULES
= EXISTING VALIDATOR RULES

PASSWORD BACKEND POLICY
= UNCHANGED
```

Do NOT invent:

```text
uppercase requirement
lowercase requirement
symbol requirement
special-character requirement
12-character minimum
password score
weak/medium/strong meter
breach lookup
network password validation
```

unless they are already accepted system requirements.

---

# 9. BILLING / SUBSCRIPTION / ENTITLEMENT HARD LOCK

Do NOT modify:

```text
Google Play Billing
billing product IDs
purchase flow
restore-purchase behavior
server-side verification
subscription verification
plan detection
entitlement calculation
Salon Pilot behavior
AI Look allowance
AI Look accounting
usage ledger
expiry calculation
```

Expected:

```text
GOOGLE PLAY BILLING CHANGES = NONE
SUBSCRIPTION LOGIC CHANGES = NONE
ENTITLEMENT LOGIC CHANGES = NONE
AI LOOK ACCOUNTING CHANGES = NONE
```

---

# 10. STANDARD / MY MAKEUP KIT AUTHORITY LOCK

```text
STANDARD BUSINESS AUTHORITY       SEPARATE
MY MAKEUP KIT BUSINESS AUTHORITY  SEPARATE
STANDARD → MY KIT FALLBACK        NEVER
MY KIT → STANDARD FALLBACK        NEVER
CONTROLLERS                       NOT MERGED
REPOSITORIES                      NOT MERGED FOR UI CONVENIENCE
```

This auth track must not touch those systems.

---

# 11. VISUAL DESIGN SYSTEM HARD LOCK

The existing FaceTune visual system is the visual authority.

Preserve:

```text
Luminous Beauty Intelligence
existing ColorScheme
existing AppColors
existing rose/pink accent
existing light/dark visual identity
existing font family
existing AppTypography scale
existing font-size system
existing font weights
existing AppSpacing
existing global gutter
existing AppRadii
existing Material icon family
existing AppIconSizes
existing field treatment
existing button family
existing surface hierarchy
existing border/divider treatment
Light / Dark / System
existing accessibility conventions
```

Avoid:

```text
new brand colors
new font family
arbitrary font sizes
new icon package
emoji icons
gradient redesign
glow
glassmorphism
neon
arbitrary shadows
pill overload
magic screen-specific padding
manual status-bar compensation
raw coordinates
screenshot-specific positioning
unrelated global theme rewrites
```

Core rule:

```text
VISUAL TOKENS = LOCKED
AUTH PAGE COMPOSITION = FLEXIBLE
```

---

# 12. LOGIN CURRENT UX PROBLEM STATEMENT

The Login page should be treated as an authentication task, not a marketing landing page.

Problems this track is authorized to correct:

```text
oversized decorative brand block
authentication task visually secondary
too much dead vertical space
guest entry competing with real account flows
guest explanatory copy adding noise
weak hierarchy between primary/secondary actions
form feels template-like rather than product-specific
```

The solution must not create a new visual language.

---

# 13. LOGIN TARGET INFORMATION ARCHITECTURE

Conceptual target:

```text
[ compact FaceTune branding ]

Welcome back
Sign in to continue.

Email
[ email ]

Password
[ password + visibility ]

Forgot password?

[ Sign in ]

or

[ Continue with Google ]

New here? Create an account
```

Remove from visible Login:

```text
large oversized decorative hero
Explore as a guest
guest-only explanation
```

Do not invent new destinations.

---

# 14. LOGIN BRANDING RULE

Branding remains present but subordinate to the task.

Principle:

```text
BRAND SUPPORTS AUTHENTICATION
BRAND DOES NOT DOMINATE AUTHENTICATION
```

Use the existing FaceTune mark/icon/branding already in the repo.

Do not invent:

```text
new logo
new illustration
new gradient brand system
new marketing tagline system
```

unless already accepted.

---

# 15. LOGIN FIELD RULES

## Email

Preserve actual email validator and sign-in behavior.

Presentation may improve:

```text
email keyboard
no unwanted capitalization
appropriate autofill hints
clear label
clear inline error presentation
next keyboard action
```

Only when supported safely by current Flutter presentation.

## Password

Preserve actual password sign-in behavior.

Presentation may improve:

```text
obscured by default
visibility toggle
no autocorrect
no unwanted capitalization
password autofill hints where appropriate
clear label
```

Do not alter authentication logic.

---

# 16. LOGIN LOADING RULE

If the existing auth controller exposes loading state, reuse it.

Allowed presentation:

```text
Sign in
→ Signing in…
```

During active request, presentation may prevent accidental repeated taps if the current state already proves a request is active.

Do NOT:

```text
create a parallel auth state machine
change request sequencing
change auth retries
change auth timeout logic
```

---

# 17. LOGIN ERROR RULE

Use existing auth errors only.

The UI may map known existing states to clearer user-facing text.

Do not:

```text
change backend errors
swallow security failures
invent account states
invent lockout behavior
change authentication decisions
```

---

# 18. GOOGLE SIGN-IN RULE

Google Sign-In remains secondary to the primary email form unless current product authority says otherwise.

Possible hierarchy:

```text
Sign in

or

Continue with Google
```

Do NOT modify:

```text
OAuth client configuration
Google provider configuration
redirect URI
token handling
Supabase integration
Google callback behavior
```

---

# 19. SIGN UP TARGET INFORMATION ARCHITECTURE

Conceptual target:

```text
Back

[ compact FaceTune branding ]

Create your account
supporting copy

Name
Email
Password
Password requirements
Confirm password
match feedback

Create account

Already have an account? Sign in

existing privacy notice
```

Do not invent fields that do not exist in the accepted model.

---

# 20. NAME FIELD RULE

AUTHUX-P0 must prove what `Name` means.

If it is display name:

```text
preserve display-name semantics
```

Do not silently convert it into:

```text
legal name
first name
last name
full legal name
```

unless current data model already defines that.

---

# 21. SIGN UP EMAIL RULE

Preserve:

```text
existing validator
existing account-creation callback
existing normalization behavior
existing duplicate-account behavior
existing error source
```

Presentation may improve keyboard/autofill/focus behavior only.

---

# 22. PASSWORD REQUIREMENTS COMPONENT

The target is a reusable presentation-layer component that mirrors current password rules.

Example only if the real validator proves these rules:

```text
Password
[ obscured password + visibility ]

✓ At least 8 characters
✓ Contains a letter
○ Contains a number
```

The exact strings and rules must follow the current accepted validator.

The component must not become a second independent password policy.

Preferred design:

```text
cheap
local
deterministic
presentation-only
accessible
uses existing icons/colors/typography
```

---

# 23. PASSWORD REQUIREMENT STATES

Support presentation states such as:

```text
EMPTY
neutral criteria

TYPING
live requirement status

VALID
all actual requirements satisfied

INVALID
clear error after meaningful interaction or submit

OBSCURED
default

VISIBLE
user-selected
```

Do not aggressively show errors on the first keystroke if the current UX can support progressive guidance.

Do not change when the account creation callback considers a password valid.

---

# 24. PASSWORD FEEDBACK ACCESSIBILITY

Validation must not rely on color alone.

Use:

```text
icon + text + semantics
```

Use existing theme semantic colors if available.

Do not add a new validation palette merely for this component.

---

# 25. PASSWORD STRENGTH METER RULE

Do not add an arbitrary:

```text
Weak
Medium
Strong
```

meter.

Reason:

```text
A requirements checklist is tied to actual policy.
An arbitrary score may claim security properties the system does not define.
```

---

# 26. CONFIRM PASSWORD RULE

Use the existing confirm-password validator.

Presentation may show:

```text
Passwords match
Passwords do not match
```

only when logically supported by the existing state.

Do not change account creation rules.

Do not create a second independent confirmation policy.

---

# 27. SIGN UP LOADING RULE

Reuse current auth loading state.

Allowed:

```text
Create account
→ Creating account…
```

Do not add a new state owner.

Do not change account creation sequencing.

---

# 28. SIGN UP ERROR RULE

Map only existing errors.

Examples may include, if current behavior supports them:

```text
email already registered
invalid email
password requirements not met
passwords do not match
network failure
```

Do not invent backend responses.

---

# 29. FORGOT-PASSWORD RULE

If a working password-reset route/action exists:

```text
retain it
make it clear
preserve exact destination/callback semantics
```

If it does not exist:

```text
DO NOT INVENT IT
REPORT
```

---

# 30. SIGN-IN LINK RULE

If the existing Sign In destination exists from Sign Up, the UI may expose it clearly.

Preserve exact route semantics.

Do not invent a new auth navigation architecture.

---

# 31. AUTOFILL / KEYBOARD RULE

Presentation-level improvements may include:

```text
email keyboard
email autofill
username autofill where appropriate
password autofill
new-password autofill
next/done keyboard actions
secure password input
focus traversal
```

Only if supported by existing Flutter widgets and without changing auth behavior.

---

# 32. BACK NAVIGATION RULE

Preserve:

```text
destination
router behavior
history stack behavior
```

The visual treatment may align with accepted FaceTune UI if needed.

Do not rewrite routing.

---

# 33. VERTICAL RHYTHM RULE

Use existing spacing tokens.

Target:

```text
less dead space
stronger hierarchy
comfortable form density
clear grouping
keyboard-safe scrolling
```

Avoid:

```text
giant decorative gaps
magic SizedBox values
raw viewport offsets
fixed-height layouts that break with keyboard
```

---

# 34. RESPONSIVE / ACCESSIBILITY REQUIREMENTS

Validate:

```text
POCO X3 GT
narrow Android
short Android
keyboard open
2x text
long email
long validation text
Light
Dark
System Light
System Dark
```

Requirements:

```text
>=44dp effective touch targets
semantic form labels
visibility-toggle semantics
validation accessible to screen readers
errors not color-only
logical focus order
no clipping
no RenderFlex overflow
all actions reachable with keyboard open
scroll reaches final content
```

---

# 35. PERFORMANCE RULES

Do NOT add:

```text
new network calls
new Supabase calls
new auth calls
new Google calls
new analytics calls
new background work
new AI calls
password validation network calls
expensive build() work
provider-refresh loops
side-effecting validators
```

Password requirement checks should be cheap, local, deterministic presentation logic.

---

# 36. NO NEW DEPENDENCIES

```text
NEW DEPENDENCIES = NONE
```

Do not add:

```text
third-party password validator package
third-party auth UI package
new icon package
new analytics package
new notification package
```

without separate explicit authorization.

If a new dependency appears necessary:

```text
STOP
REPORT
DO NOT ADD
```

---

# 37. GIT SAFETY

Before every phase:

```powershell
git branch --show-current
git log -1 --oneline
git status --short
git diff --stat
git diff --name-only
git diff
```

Do NOT:

```text
reset
reset --hard
clean
stash
discard valid work
restore unrelated files
checkout unrelated files
rebase
merge
cherry-pick
commit
push
force push
delete branches
rewrite history
```

If working-tree ownership is unclear:

```text
STOP
REPORT
```

---

# 38. TESTING PRINCIPLE

At minimum prove, as applicable:

```text
email sign-in callback unchanged
email sign-up callback unchanged
Google callback unchanged
guest logic preserved
guest visible UI absent after P1
forgot-password destination unchanged
create-account destination unchanged
Sign In destination unchanged
password rules mirror actual validator
confirm-password behavior preserved
loading uses existing auth state
error mapping does not change auth decision
Light/Dark/System valid
keyboard-open layout valid
2x text valid
0 new auth calls
0 new AI calls
0 Supabase diff
0 new dependencies
```

Tests do not replace visual QA.

Screenshots do not replace behavior tests.

---

# 39. FORBIDDEN SHORTCUTS

Do NOT:

```text
delete guest code because guest UI is removed
rewrite auth controller
rewrite auth repository
rewrite auth datasource
change Supabase auth
change Google OAuth
change password rules
add password strength scoring
add third-party password package
change account creation flow
change email verification
change password reset backend
change session management
change router auth guards
change database/RLS/Storage/Edge Functions
touch billing/subscription/entitlements
touch Gemini
touch Standard/My Kit authority
touch unrelated pages
perform unrelated cleanup
```

---

# 40. PHASE MODEL

This track has exactly **7 phases**:

```text
AUTHUX-P0
Accepted baseline + read-only auth/guest/validator audit

AUTHUX-P1
Login information architecture + UI-only guest removal

AUTHUX-P2
Sign Up information architecture

AUTHUX-P3
Password requirements + confirm-password presentation

AUTHUX-P4
Interaction / loading / error / keyboard / autofill / copy polish

AUTHUX-P5
Visual consistency + responsive + accessibility + regression QA

AUTHUX-P6
Final protected-diff audit + release freeze
```

Exactly one phase may run at a time.

Every phase must STOP.

No automatic continuation.

---

# 41. DEFINITION OF DONE

This track is accepted only when:

```text
LOGIN BRANDING                       COMPACT / INTENTIONAL
LOGIN AUTH TASK                      PRIMARY
VISIBLE GUEST ENTRY                  REMOVED
GUEST EXPLANATORY COPY               REMOVED
GUEST LOGIC                          PRESERVED
EMAIL SIGN-IN                        PRESERVED
GOOGLE SIGN-IN                       PRESERVED
FORGOT PASSWORD                      PRESERVED
CREATE ACCOUNT NAVIGATION            PRESERVED

SIGN UP HIERARCHY                    CLEAR
NAME SEMANTICS                       PRESERVED
EMAIL SIGN-UP                        PRESERVED
PASSWORD CONTRACT                    PRESERVED
PASSWORD CHECKLIST                   MATCHES REAL RULES
CONFIRM PASSWORD                     PRESERVED
ACCOUNT CREATION                     PRESERVED
EMAIL VERIFICATION                   PRESERVED

COLORS                               PRESERVED
FONT FAMILY                          PRESERVED
TYPOGRAPHY SCALE                     PRESERVED
SPACING SYSTEM                       PRESERVED
RADIUS SYSTEM                        PRESERVED
ICON FAMILY                          PRESERVED
LIGHT / DARK / SYSTEM                PASS
KEYBOARD OPEN                        PASS
2X TEXT                              PASS
ACCESSIBILITY                        PASS
POCO X3 GT                           PASS / PENDING USER

FINAL PREVIEW MODEL                  gemini-3.1-flash-image
TUTORIAL MODEL                       gemini-3.1-flash-image
TUTORIAL RESOLUTION                  1K
TUTORIAL PROMPT                      tutorial_guideline_v4_7
MANIFEST PROMPT                      tutorial_manifest_v4_1

AUTH BACKEND DIFF                    NONE
SUPABASE DIFF                        NONE
DATABASE DIFF                        NONE
RLS DIFF                             NONE
STORAGE DIFF                         NONE
EDGE FUNCTION DIFF                   NONE
GOOGLE OAUTH DIFF                    NONE
SESSION LOGIC DIFF                   NONE
PASSWORD BACKEND POLICY DIFF         NONE
EXTRA AUTH CALLS                     0
EXTRA AI CALLS                       0
NEW DEPENDENCIES                     NONE
FULL FLUTTER TEST                    PASS
ANDROID DEBUG BUILD                  PASS
```

---

# 42. RELEASE PHILOSOPHY

The user should experience:

```text
THE SAME FACETUNE
THE SAME AUTHENTICATION
THE SAME ACCOUNT
THE SAME GOOGLE SIGN-IN
THE SAME PASSWORD RULES
THE SAME GUEST SUPPORT UNDERNEATH
THE SAME BACKEND
THE SAME SECURITY
THE SAME COLORS / FONT / SIZING

BUT

A CLEANER LOGIN
A CLEANER SIGN UP
NO VISIBLE GUEST DISTRACTION
BETTER PASSWORD GUIDANCE
BETTER FORM HIERARCHY
BETTER KEYBOARD BEHAVIOR
BETTER ACCESSIBILITY
```

The user must not see evidence that an auth UX improvement required reopening authentication architecture.
