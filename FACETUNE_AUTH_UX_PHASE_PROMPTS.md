# FaceTune — AUTHENTICATION UX PRODUCTIONIZATION PHASE PROMPTS

**Project Name:** FaceTune
**Primary Device:** POCO X3 GT
**Framework:** Flutter / Dart
**Backend:** Supabase — HARD PROTECTED
**State Management:** Riverpod
**Architecture:** Clean Architecture + Repository Pattern + Feature-First Structure

**Recommended Target Branch:** `feature/auth-ux-v1` — existence/base MUST be proven in AUTHUX-P0; never create/switch/reset automatically without explicit user instruction.
**Accepted Base:** MUST be proven in AUTHUX-P0 from the current accepted FaceTune baseline after completed Profile + Settings UX work.
**Source of Truth:** `FACETUNE_AUTH_UX_SOURCE_OF_TRUTH.md`
**This Phase File:** `FACETUNE_AUTH_UX_PHASE_PROMPTS.md`

**Final Preview Model — HARD LOCK:** `gemini-3.1-flash-image`
**Tutorial Guideline Model — HARD LOCK:** `gemini-3.1-flash-image`
**Tutorial Resolution — HARD LOCK:** `1K`
**Tutorial Prompt — HARD LOCK:** `tutorial_guideline_v4_7`
**Manifest Prompt — HARD LOCK:** `tutorial_manifest_v4_1`

**Design Direction:** Luminous Beauty Intelligence
**Visual Rule:** existing FaceTune colors/fonts/sizing/tokens locked; Login/Sign Up composition may improve
**Guest Rule:** remove visible guest entry only; preserve all guest/anonymous logic underneath
**Auth Rule:** backend/auth/business/persistence/session/OAuth logic HARD LOCKED

---

# HOW TO USE THIS FILE

1. Keep this file beside `FACETUNE_AUTH_UX_SOURCE_OF_TRUTH.md`.
2. Use Claude Opus 5 / Claude Code.
3. Run exactly ONE phase at a time.
4. Paste only the active phase if using phase-by-phase execution.
5. Review the completion report before authorizing the next phase.
6. Never auto-continue.
7. Never treat screenshots alone as behavioral proof.
8. Never treat tests alone as visual proof.
9. Never change auth/backend/security for UI convenience.
10. Never delete guest logic because the UI entry is removed.
11. Never change password policy for the sake of a richer checklist.
12. Never change Google OAuth for visual cleanup.
13. Never change Gemini/model/prompt behavior.
14. Never merge Standard and My Kit authority.
15. Never add dependencies without explicit authorization.
16. If a UI request requires protected architecture changes, STOP and report.
17. Do not commit/push/merge/rebase unless explicitly instructed.
18. Do not reset/clean/stash/discard valid work.
19. Repository evidence wins over assumptions.

---

# MANDATORY READ ORDER FOR EVERY PHASE

Read completely, in order, when present:

```text
1. CODEX_MASTER_GUIDE.md
2. accepted authentication authority documents if any
3. accepted subscription / Google Play Billing authority documents
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
20. accepted completion reports relevant to current auth/UI baseline
21. actual current source/tests/theme/routing/validators/providers relevant to THIS phase
22. current Git diff
```

If an authority file is missing:

```text
DO NOT INVENT IT
INSPECT CURRENT SOURCE
REPORT THE GAP
```

---

# MANDATORY SYSTEM ROLE FOR EVERY PHASE

Act simultaneously as relevant:

- Principal Software Engineer
- Principal Software Architect
- Principal Mobile Architect
- Principal Flutter Architect
- Senior Software Engineer
- Senior Software Developer
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
- Senior Mobile Product Designer
- Senior UI Designer
- Senior UX Designer
- Senior UI/UX Designer
- Senior Information Architecture Designer
- Senior Beauty-App Product Designer
- Senior Content Designer
- Senior UX Writer
- Senior Accessibility Engineer
- Senior Inclusive Design Engineer
- Senior Semantic UI Engineer
- Senior Localization-Readiness Engineer
- Senior Performance Engineer
- Senior Reliability Engineer
- Senior QA Engineer
- Senior Regression Engineer
- Senior Widget Test Engineer
- Senior Integration Test Engineer
- Senior End-to-End Test Engineer
- Senior Visual QA Engineer
- Senior Production Debugging Engineer
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
- Senior Gemini AI Engineer
- Senior AI Systems Engineer
- Senior My Makeup Kit Engineer
- Senior Release Engineer
- Senior Code Reviewer

Backend/auth/security/AI roles protect accepted behavior. They do not redesign it.

Inspect first.

Challenge stale assumptions.

Prefer the smallest safe presentation-layer change.

---

# GLOBAL GIT SAFETY

Before every phase:

```powershell
git branch --show-current
git log -1 --oneline
git status --short
git diff --stat
git diff --name-only
git diff
```

Record:

```text
CURRENT BRANCH
CURRENT HEAD
WORKING TREE BEFORE
PRE-EXISTING MODIFICATIONS
UNTRACKED FILES
```

Do NOT:

- reset
- reset --hard
- clean
- stash
- discard valid work
- restore unrelated files
- checkout unrelated files
- rebase
- merge
- cherry-pick
- commit
- push
- force push
- delete branches
- rewrite history

If working-tree ownership is unclear:

```text
STOP
REPORT
```

---

# GLOBAL HARD LOCKS

Preserve exactly:

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
Gemini
AI prompts
AI retries/fallbacks
AI call counts
face analysis
recommendations
Final Preview
Tutorial
Dynamic Manifest

Supabase
Supabase Auth backend
DB schema
migrations
RLS
Storage
Edge Functions
JWT/session behavior
auth providers

email sign-in backend behavior
email sign-up backend behavior
Google OAuth
password backend policy
password reset backend behavior
email verification
account creation
router auth guards

guest/anonymous auth implementation
guest session logic
guest routes
guest persistence
guest data isolation
guest conversion

Google Play Billing
subscriptions
entitlements
AI Look accounting

Standard authority
My Makeup Kit authority

bottom-navigation destinations
unrelated accepted screens
```

Expected:

```text
EXTRA AUTH CALLS = 0
EXTRA AI CALLS = 0
SUPABASE DIFF = NONE
AUTH BACKEND DIFF = NONE
GOOGLE OAUTH DIFF = NONE
PASSWORD POLICY DIFF = NONE
NEW DEPENDENCIES = NONE
```

---

# GLOBAL GUEST RULE

This track removes only visible guest presentation from Login.

Allowed:

```text
remove "Explore as a guest"
remove guest-only explanatory Login copy
adjust spacing
update presentation tests
```

Forbidden:

```text
delete anonymous auth
delete guest controller/provider
delete guest route
change guest session behavior
change guest persistence
change guest isolation
change guest conversion
change Supabase anonymous auth
```

Required outcome:

```text
GUEST UI ENTRY POINT = REMOVED
GUEST FEATURE LOGIC = PRESERVED
```

---

# GLOBAL PASSWORD RULE

The UI checklist must mirror the existing validator exactly.

Required:

```text
PASSWORD UI RULES = EXISTING PASSWORD CONTRACT
PASSWORD BACKEND POLICY = UNCHANGED
```

Forbidden unless already part of the existing contract:

```text
new minimum length
uppercase requirement
lowercase requirement
symbol requirement
special character requirement
network password scoring
password strength meter
third-party password validator
```

---

# GLOBAL STANDARD / MY KIT AUTHORITY LOCK

```text
STANDARD BUSINESS AUTHORITY       SEPARATE
MY MAKEUP KIT BUSINESS AUTHORITY  SEPARATE
STANDARD → MY KIT FALLBACK        NEVER
MY KIT → STANDARD FALLBACK        NEVER
CONTROLLERS                       NOT MERGED
REPOSITORIES                      NOT MERGED FOR UI CONVENIENCE
```

---

# GLOBAL UI LOCK

Use accepted:

```text
Luminous Beauty Intelligence
ColorScheme
AppColors
AppTypography
AppSpacing
AppRadii
Material icon family
AppIconSizes
accepted auth field style
accepted buttons
accepted surfaces
Light / Dark / System
accessibility
```

Avoid:

```text
new colors
new font family
new typography sizes
new icon package
emoji UI
gradient redesign
glow
glassmorphism
neon
arbitrary shadows
pill overload
magic per-screen padding
manual status-bar compensation
raw coordinates
screenshot-specific positioning
unrelated component rewrites
```

---

# GLOBAL VALIDATION

After each implementation phase, run as applicable:

```powershell
dart format <changed Dart files>
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/development.json
git diff -- supabase/
git status --short
git diff --stat
git diff --name-only
git diff
```

If `config/development.json` does not exist in the active worktree:

```text
DO NOT INVENT CONFIG
USE ONLY A PROVEN VALID ABSOLUTE CONFIG PATH IF ALREADY AUTHORIZED
OTHERWISE REPORT
```

If POCO X3 GT is unavailable:

```text
REAL DEVICE:
PENDING USER
```

Do not fabricate visual success.

---

# GLOBAL COMPLETION REPORT

Every phase MUST end with exactly this structure:

```text
PHASE:

AGENT:

BRANCH VERIFIED:

HEAD BEFORE:

HEAD AFTER:

WORKING TREE BEFORE:

WORKING TREE AFTER:

OBJECTIVE ACHIEVED:

YES / PARTIAL / NO


----------------------------------
SCOPE
----------------------------------

AUTHORIZED SCOPE:

UNAUTHORIZED SCOPE TOUCHED:

NONE / exact issue


----------------------------------
PROTECTED BASELINE
----------------------------------

FINAL PREVIEW MODEL:

gemini-3.1-flash-image


TUTORIAL MODEL:

gemini-3.1-flash-image


TUTORIAL RESOLUTION:

1K


TUTORIAL PROMPT:

tutorial_guideline_v4_7


MANIFEST PROMPT:

tutorial_manifest_v4_1


AI CHANGES:

NONE


EXTRA AI CALLS:

0 / FAIL


EXTRA AUTH CALLS:

0 / FAIL


DATABASE CHANGES:

NONE


RLS CHANGES:

NONE


STORAGE CHANGES:

NONE


EDGE FUNCTION CHANGES:

NONE


AUTH BACKEND CHANGES:

NONE


EMAIL SIGN-IN LOGIC:

PRESERVED / FAIL


EMAIL SIGN-UP LOGIC:

PRESERVED / FAIL


GOOGLE AUTH:

PRESERVED / FAIL


GOOGLE OAUTH CONFIG:

PRESERVED / FAIL


SESSION LOGIC:

PRESERVED / FAIL


PASSWORD BACKEND POLICY:

PRESERVED / FAIL


PASSWORD RESET BACKEND:

PRESERVED / FAIL


EMAIL VERIFICATION:

PRESERVED / FAIL


ACCOUNT CREATION LOGIC:

PRESERVED / FAIL


GUEST / ANONYMOUS AUTH LOGIC:

PRESERVED / FAIL


GUEST UI ENTRY:

PRESENT / REMOVED / N/A


GOOGLE PLAY BILLING:

PRESERVED / FAIL


SUBSCRIPTION / ENTITLEMENT LOGIC:

PRESERVED / FAIL


STANDARD AUTHORITY:

PRESERVED / FAIL


MY KIT AUTHORITY:

PRESERVED / FAIL


BOTTOM NAV DESTINATIONS:

UNCHANGED / FAIL


----------------------------------
UI / UX
----------------------------------

SCREENS / COMPONENTS CHANGED:

SHARED COMPONENTS CREATED / MODIFIED:

LOGIN INFORMATION ARCHITECTURE:

SIGN UP INFORMATION ARCHITECTURE:

PASSWORD REQUIREMENTS COMPONENT:

CONFIRM-PASSWORD PRESENTATION:

COPY / LABELS CHANGED:

DESIGN TOKENS CHANGED:

NONE / exact authorized change

COLORS:

PRESERVED / FAIL

TYPOGRAPHY FAMILY:

PRESERVED / FAIL

TYPOGRAPHY SCALE:

PRESERVED / FAIL

ICON FAMILY:

PRESERVED / FAIL

SPACING / RADIUS SYSTEM:

PRESERVED / FAIL

LIGHT THEME:

DARK THEME:

SYSTEM THEME:

KEYBOARD-OPEN STATUS:

RESPONSIVE STATUS:

ACCESSIBILITY STATUS:

VISUAL QA:


----------------------------------
FILES
----------------------------------

FILES CREATED:

FILES MODIFIED:

FILES DELETED:

DEPENDENCIES ADDED / REMOVED:

NONE / exact issue


----------------------------------
VALIDATION
----------------------------------

DART FORMAT:

FLUTTER ANALYZE:

TARGETED AUTH TESTS:

TARGETED UI TESTS:

FULL FLUTTER TEST:

ANDROID DEBUG BUILD:

BACKEND DIFF:

NONE / exact issue

SUPABASE DIFF:

NONE / exact issue

REAL DEVICE:

PASS / FAIL / PENDING USER


----------------------------------
KNOWN LIMITATIONS
----------------------------------


----------------------------------
PRE-EXISTING ISSUES
----------------------------------


----------------------------------
ASSUMPTIONS NOT PROVEN
----------------------------------


----------------------------------
MANUAL ACTION REQUIRED
----------------------------------


----------------------------------
NEXT
----------------------------------

NEXT RECOMMENDED PHASE:

Do not implement automatically.


STOP CONFIRMATION:

No later phase implemented.

No valid working-tree work discarded.

No reset performed.

No clean performed.

No stash performed.

No rebase performed.

No merge performed.

No commit performed.

No push performed.

No Gemini model changed.

No AI prompt changed.

No AI call behavior changed.

No Supabase schema/RLS/storage/Edge Function changed.

No authentication backend logic changed.

No email sign-in/sign-up logic changed.

No Google OAuth configuration changed.

No password backend policy changed.

No password-reset backend changed.

No email-verification logic changed.

No guest/anonymous auth logic removed or changed.

No Google Play Billing logic changed.

No subscription/entitlement logic changed.

No Standard/My Kit business authority merged.

No bottom-navigation destination changed.

No new dependency added without authorization.

STOP.
```

---

# AUTHUX-P0 — ACCEPTED BASELINE + READ-ONLY AUTH / GUEST / VALIDATOR AUDIT

Implement only AUTHUX-P0.

Then STOP.

## Objective

Prove the exact current accepted Login/Sign Up/auth baseline and map the narrow presentation-layer implementation surfaces.

This phase is READ-ONLY.

No source changes.

No branch creation/switch.

No dependency changes.

No auth calls required merely for code audit.

No AI generation.

## Before audit

Run Global Git Safety commands.

Prove:

```text
CURRENT BRANCH
CURRENT HEAD
CURRENT VERSION
CURRENT WORKTREE
CURRENT ACCEPTED PROFILE/SETTINGS UI BASE
TARGET AUTHUX BRANCH STATUS
```

Do not assume the correct base is `main`.

If the current branch is not the accepted base:

```text
DO NOT SWITCH AUTOMATICALLY
REPORT
```

## Audit Login

Inspect:

```text
Login page file(s)
current hero/branding owner
FaceTune mark/icon source
email field widget
email validator
password field widget
password visibility state
sign-in callback
sign-in provider/controller
loading owner
error owner
Forgot password callback/route
Google button callback
Google provider/controller
Create account callback/route
Explore as a guest UI owner
guest callback
guest provider/controller
guest route
guest explanatory copy
SafeArea ownership
scroll/keyboard behavior
```

## Audit Sign Up

Inspect:

```text
Sign Up page file(s)
Name field semantics
Name persistence target
Email validator
Password validator
Confirm password validator
Password visibility state
Confirm-password visibility state
Create account callback
Create account provider/controller
loading owner
error owner
Sign In destination
privacy notice source
email verification behavior
post-registration behavior
SafeArea ownership
scroll/keyboard behavior
```

## Audit guest system

Prove:

```text
whether guest uses Supabase anonymous auth
guest provider/controller
guest repository/datasource if any
guest route(s)
guest session state
guest persistence
guest data isolation
guest conversion/upgrade behavior if present
tests that rely on guest behavior
whether hiding the Login entry can be presentation-only
```

Do NOT remove anything.

## Audit password contract

Prove exact existing rules:

```text
minimum length
letter requirement
number requirement
symbol requirement if any
uppercase requirement if any
lowercase requirement if any
other actual rules
where each rule is enforced
whether backend imposes additional rules
confirm-password rule
```

Do not infer rules from helper text alone.

## Audit fields / interaction

Inspect:

```text
keyboardType
textInputAction
autofillHints
autocorrect
enableSuggestions
textCapitalization
obscureText
focus nodes
form validation timing
error presentation
loading disable behavior
double-submit risk
```

## Audit design system

Prove:

```text
ColorScheme
AppColors
font family
AppTypography
AppSpacing
AppRadii
Material icons
AppIconSizes
field component/style
button family
surface/card components
Light/Dark/System
```

## Audit tests

Find:

```text
Login widget tests
Sign Up widget tests
auth controller tests
auth repository tests
guest tests
Google auth tests
password validator tests
password reset tests
routing tests
responsive tests
accessibility tests
copy-coupled tests
```

## Mandatory P0 report additions

```text
SAFE ACCEPTED BASE:

TARGET AUTHUX BRANCH STATUS:

LOGIN PAGE OWNER:

SIGN UP PAGE OWNER:

LOGIN BRANDING OWNER:

GUEST BUTTON UI OWNER:

GUEST AUTH OWNER:

GUEST ROUTES:

GUEST SESSION OWNER:

GUEST PERSISTENCE OWNER:

SAFE TO HIDE GUEST ENTRY UI-ONLY:
YES / NO / NOT PROVEN

PASSWORD CONTRACT:
exact rules

PASSWORD VALIDATOR OWNER:

CONFIRM PASSWORD OWNER:

EMAIL VALIDATOR OWNER:

SIGN-IN CALLBACK OWNER:

SIGN-UP CALLBACK OWNER:

GOOGLE AUTH CALLBACK OWNER:

FORGOT-PASSWORD DESTINATION:

SIGN-UP → SIGN-IN DESTINATION:

NAME FIELD ACTUAL SEMANTICS:

AUTH LOADING OWNER:

AUTH ERROR OWNER:

KEYBOARD / AUTOFILL BASELINE:

DESIGN TOKENS:

AUTH BACKEND IMPACT REQUIRED:
NONE / exact blocker

NEW DEPENDENCY REQUIRED:
NO / exact blocker

TESTS COUPLED TO CURRENT AUTH UI:

PROTECTED FILES:
```

## Validation

```powershell
flutter analyze
git diff -- supabase/
```

Run targeted read-only tests where useful.

Do NOT implement P1.

STOP.

---

# AUTHUX-P1 — LOGIN INFORMATION ARCHITECTURE + UI-ONLY GUEST REMOVAL

Implement only AUTHUX-P1.

Then STOP.

## Entry gate

Before coding:

1. Read accepted AUTHUX-P0 report.
2. Verify branch/HEAD/worktree.
3. Verify correct accepted base.
4. Verify `SAFE TO HIDE GUEST ENTRY UI-ONLY = YES`.
5. Verify guest implementation is protected.
6. Verify no backend/auth change is required.

If guest UI-only removal was not proven safe:

```text
STOP
REPORT
DO NOT IMPLEMENT
```

## Objective

Make Login feel intentional and industry-ready while preserving every auth callback and removing only the visible guest entry.

Target conceptual hierarchy:

```text
compact FaceTune branding

Welcome back
supporting copy

Email
Password
Forgot password

Sign in

or

Continue with Google

New here? Create an account
```

## Authorized

- reduce/remove oversized decorative login hero
- reuse existing FaceTune mark in a compact arrangement
- reorganize Login page structure
- improve section hierarchy
- adjust spacing using existing tokens
- improve safe user-facing copy
- remove visible `Explore as a guest`
- remove guest-only explanatory Login copy
- preserve exact email/password form callbacks
- preserve Google button callback
- preserve Forgot password callback
- preserve Create account navigation
- update presentation tests intentionally

## Forbidden

```text
delete guest provider/controller
delete guest routes
delete anonymous auth
change guest session
change guest persistence
change guest isolation
change sign-in callback
change auth repository
change Supabase Auth
change Google OAuth
change password validator
change forgot-password backend
change router architecture
add package
```

## Brand rule

The page must remain FaceTune.

Do not invent a new logo or brand system.

Use existing colors/font/sizing/tokens.

## Tests

Prove:

```text
Explore as a guest absent
guest explanatory copy absent
guest implementation still exists unchanged
email sign-in callback unchanged
Google callback unchanged
Forgot password unchanged
Create account navigation unchanged
no new auth calls
no new network calls
0 AI calls
```

## Validation

```powershell
dart format <changed Dart files>
flutter analyze
targeted Login/auth tests
relevant responsive/accessibility tests
git diff -- supabase/
git status --short
git diff --stat
git diff --name-only
git diff
```

No P2.

STOP.

---

# AUTHUX-P2 — SIGN UP INFORMATION ARCHITECTURE

Implement only AUTHUX-P2.

Then STOP.

## Entry gate

Require accepted P1 report.

Verify no protected diff.

## Objective

Make Sign Up structurally clear and production-ready while preserving every account-creation rule and callback.

Conceptual target:

```text
Back

compact FaceTune branding

Create your account
supporting copy

Name
Email
Password
existing password guidance baseline
Confirm password

Create account

Already have an account? Sign in

existing privacy notice
```

This phase improves structure only.

Do NOT implement the live password checklist yet unless an existing component already does so and no new behavior is introduced.

## Authorized

- reduce unnecessary dead space
- improve heading/subheading hierarchy
- improve field grouping
- improve section order
- improve Sign In link discoverability if destination already exists
- preserve privacy notice
- align back navigation presentation with accepted FaceTune UI
- use existing design tokens

## Name field hard rule

Use the semantics proven in P0.

Do not rename to a broader legal identity concept.

## Protected

```text
sign-up callback
auth controller
auth repository
Supabase Auth
email verification
post-registration profile creation
user persistence
password policy
confirm-password policy
router behavior
```

## Tests

Prove:

```text
all original fields still bind to same state
Create account callback unchanged
Sign In destination unchanged
privacy notice preserved
Name semantics preserved
email validator unchanged
password validator unchanged
confirm-password validator unchanged
0 auth/backend changes
```

STOP.

---

# AUTHUX-P3 — PASSWORD REQUIREMENTS + CONFIRM-PASSWORD PRESENTATION

Implement only AUTHUX-P3.

Then STOP.

## Entry gate

Require accepted P2 report.

Use only the exact password rules proven in P0.

If rules remain ambiguous:

```text
STOP
REPORT
DO NOT IMPLEMENT CHECKLIST
```

## Objective

Replace static password guidance with a reusable, accessible presentation component that mirrors the existing validator exactly.

## Password requirements component

Conceptual only:

```text
Password
[ input + visibility ]

criterion 1
criterion 2
criterion 3
```

If P0 proved:

```text
>=8 chars
letter
number
```

then use exactly those.

If P0 proved different rules, use the proven rules.

## States

Support presentation states:

```text
empty / neutral
typing / live progress
satisfied
unsatisfied
visible
obscured
```

Do not change form validity rules.

## Accessibility

Every criterion must use more than color:

```text
icon + text + semantics
```

Visibility toggle must have a semantic label.

## Confirm password

Add relationship feedback using the existing confirm validator.

Allowed:

```text
Passwords match
Passwords do not match
```

only when the existing state supports it.

## Forbidden

```text
new password rules
new password strength score
network password check
third-party password package
new auth state owner
new validation backend
change submit eligibility logic
```

## Tests

Prove:

```text
UI criteria exactly match validator
valid password remains valid
invalid password remains invalid
confirm mismatch behavior unchanged
visibility toggle works
no auth call on keystroke
no network call on keystroke
no extra provider refresh
2x text does not clip criteria
```

STOP.

---

# AUTHUX-P4 — INTERACTION / LOADING / ERROR / KEYBOARD / AUTOFILL / COPY POLISH

Implement only AUTHUX-P4.

Then STOP.

## Objective

Productionize form interaction behavior without changing authentication decisions.

Audit and improve presentation for:

```text
Login email
Login password
Sign Up name
Sign Up email
Sign Up password
Confirm password
Sign in button
Create account button
Google button
Forgot password
Sign In link
Create account link
```

## Loading

Reuse existing auth loading state.

Allowed examples:

```text
Sign in → Signing in…
Create account → Creating account…
```

Do not create a parallel loading architecture.

## Double submit

If existing loading state clearly proves an auth request is in progress, the presentation may prevent repeated taps.

Do not alter request sequencing.

## Errors

Use existing error states.

Improve text only if mapping is safe and semantics remain identical.

Do not invent account/security states.

## Keyboard

Use safe presentation-level config where appropriate:

```text
email keyboard
next/done
focus traversal
secure password input
no password autocorrect
no unwanted password capitalization
```

## Autofill

Use appropriate existing Flutter autofill hints if safe:

```text
email
username
password
new password
```

Do not change auth contracts.

## Copy

All text must be:

```text
concise
truthful
user-facing
non-technical
consistent
not broader than actual capability
```

## Tests

Prove:

```text
loading state uses existing owner
no duplicate auth request
errors still map to existing outcomes
keyboard actions do not submit wrong form
autofill does not alter validation
Google callback unchanged
Forgot password unchanged
```

STOP.

---

# AUTHUX-P5 — VISUAL CONSISTENCY + RESPONSIVE + ACCESSIBILITY + REGRESSION QA

Implement only AUTHUX-P5.

Then STOP.

This phase is primarily validation.

Only make the smallest proven presentation correction inside Login/Sign Up scope.

## Visual consistency

Audit:

```text
colors
font family
font sizes
font weights
spacing
radius
field style
button style
icon family
brand mark scale
divider treatment
error text
validation checklist
```

No new design language.

## Device / viewport matrix

Validate:

```text
POCO X3 GT
narrow Android
short Android
keyboard open
2x text
long email
long display name
long validation text
Light
Dark
System Light
System Dark
```

## Login QA

Verify:

```text
compact branding
Welcome back hierarchy
Email reachable
Password reachable
Forgot password reachable
Sign in reachable
Google reachable
Create account reachable
guest UI absent
keyboard does not hide final actions
scroll works if needed
```

## Sign Up QA

Verify:

```text
back action reachable
branding compact
Name readable
Email readable
Password readable
requirements readable
Confirm password readable
Create account reachable
Sign In link reachable
privacy notice reachable
keyboard-safe layout
```

## Accessibility

Verify:

```text
>=44dp touch targets
semantic labels
visibility toggle semantics
logical focus order
errors announced/readable
criteria do not rely only on color
disabled states understandable
2x text usable
no clipping
no overflow
```

## Regression

Run targeted + full tests as appropriate.

No redesign.

STOP.

---

# AUTHUX-P6 — FINAL PROTECTED-DIFF AUDIT + RELEASE FREEZE

Implement only AUTHUX-P6.

Then STOP.

No next phase.

This phase is primarily audit / validation.

No redesign except the smallest proven regression fix inside authorized auth UI scope.

## Protected system audit

Confirm unchanged:

```text
Final Preview model = gemini-3.1-flash-image
Tutorial model = gemini-3.1-flash-image
Tutorial resolution = 1K
Tutorial prompt = tutorial_guideline_v4_7
Manifest prompt = tutorial_manifest_v4_1

Gemini
AI call counts
face analysis
recommendations
Final Preview
Tutorial
Dynamic Manifest

Supabase schema
migrations
RLS
Storage
Edge Functions

Supabase Auth backend
email sign-in logic
email sign-up logic
Google OAuth
session behavior
password backend policy
password reset backend
email verification
account creation
router auth guards

guest/anonymous auth implementation
guest providers/controllers
guest routes
guest session behavior
guest persistence
guest isolation
guest conversion

Google Play Billing
subscription verification
entitlements
AI Look accounting

Standard authority
My Makeup Kit authority

bottom-nav destinations
unrelated accepted screens
```

## Functional acceptance

Confirm:

```text
Login branding compact
Login hierarchy clear
Explore as a guest absent
guest explanatory copy absent
guest logic preserved
email sign-in unchanged
Google sign-in unchanged
forgot password unchanged
create account route unchanged

Sign Up hierarchy clear
Name semantics unchanged
email sign-up unchanged
password policy unchanged
password checklist matches validator
confirm-password logic unchanged
Sign In route unchanged
privacy notice preserved

loading/error/keyboard/autofill presentation accepted
```

## Visual acceptance

Confirm:

```text
FaceTune colors preserved
font family preserved
typography scale preserved
spacing preserved
radius preserved
icons preserved
Light PASS
Dark PASS
System PASS
keyboard-open PASS
2x text PASS
responsive PASS
accessibility PASS
```

## Required validation

```powershell
dart format <changed Dart files>
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/development.json
git diff -- supabase/
git status --short
git diff --stat
git diff --name-only
git diff
```

`git diff -- supabase/` must be NONE for this track except clearly proven unrelated pre-existing work, which must remain untouched and be reported.

## Final POCO X3 GT acceptance

1. Open Login.
2. Confirm branding is compact.
3. Confirm no visible Explore as a guest.
4. Confirm no guest explanatory copy.
5. Confirm Email field works.
6. Confirm Password visibility works.
7. Confirm Forgot password opens the same destination.
8. Confirm Sign in uses the same flow.
9. Confirm Google button uses the same flow.
10. Confirm Create account opens Sign Up.
11. Open Sign Up.
12. Confirm Name semantics unchanged.
13. Confirm Email field works.
14. Confirm live password requirements match the real rules.
15. Confirm Confirm password feedback.
16. Confirm visibility toggles.
17. Confirm Create account uses the same flow.
18. Confirm existing privacy notice.
19. Confirm Sign In link returns correctly.
20. Test keyboard open on Login.
21. Test keyboard open on Sign Up.
22. Test 2x text.
23. Test Light.
24. Test Dark.
25. Test System.
26. Confirm no overflow/clipping.
27. Confirm all actions remain reachable.

## Final status

```text
AUTHENTICATION UX TRACK:
ACCEPTED / PARTIAL / REJECTED

PROTECTED AUTH BASELINE:
PASS / FAIL

GUEST LOGIC:
PRESERVED / FAIL

PASSWORD POLICY:
PRESERVED / FAIL

REAL DEVICE:
PASS / FAIL / PENDING USER

DEFERRED ITEMS:
exact list
```

STOP.

No next phase.

No opportunistic cleanup.

No commit/push/merge/rebase unless separately instructed.
