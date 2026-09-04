# FaceTune — LIVE SCAN + EDUCATIONAL PALETTE SOURCE OF TRUTH

**Project Path:** `C:\Users\Kurt\facetune`  
**Project Name:** FaceTune  
**Tagline:** Your AI Makeup Artist  
**Primary Platform:** Android  
**Primary Test Device:** POCO X3 GT  
**Framework:** Flutter  
**Language:** Dart  
**Backend:** Supabase  
**AI Provider:** Google Gemini API  
**State Management:** Riverpod  
**Architecture:** Clean Architecture + Repository Pattern + Feature-First Structure  

**Current Accepted UI Track:** `feature/ui-productionization`  
**Required Implementation Branch:** `feature/live-scan-educational-palette`  
**Required Branch Base:** latest user-accepted UI Productionization state  

**Canonical Final Preview Renderer — LOCKED:** `gemini-3.1-flash-image`  
**Tutorial Guideline Renderer — LOCKED:** `gemini-3.1-flash-image`  
**Tutorial Guideline Resolution — LOCKED:** `1K`  
**Accepted Tutorial Prompt — LOCKED:** `tutorial_guideline_v4_7`  
**Accepted Manifest Prompt — LOCKED:** `tutorial_manifest_v4_1`  
**Face Analysis Model:** PRESERVE ACTUAL CURRENT DEPLOYED CONFIGURATION  
**Recommendation Model:** PRESERVE ACTUAL CURRENT DEPLOYED CONFIGURATION  
**Manifest Analyzer Model:** PRESERVE ACTUAL CURRENT DEPLOYED CONFIGURATION  

**Live Camera Gemini Calls:** `0`  
**Camera Auto Capture:** `NEVER`  
**Camera Capture:** `MANUAL ONLY`  
**Final Still Validation:** `AUTOMATIC`  
**Face Analysis Per Accepted Still:** `EXACTLY 1 NORMAL REQUEST`  
**Extra Education Gemini Calls:** `0`  

---

# 0. PURPOSE

This document is the highest authority for the FaceTune **Live Scan + Educational Palette** improvement track.

The track contains exactly two product features:

```text
FEATURE A
Live Scan + Manual Capture

FEATURE B
Educational Personalized Palette
```

The objective is:

```text
LESS MANUAL FRICTION
+
SMART LOCAL CAMERA GUIDANCE
+
USER-CONTROLLED PHOTO CAPTURE
+
BETTER MAKEUP EDUCATION
+
NO DUPLICATED TUTORIAL CONTENT
+
NO EXTRA PAID AI LOOP
```

Canonical journey:

```text
NEW LOOK
↓
CAMERA OR GALLERY
↓
LOCAL QUALITY VALIDATION
↓
ACCEPTED STILL IMAGE
↓
ONE FACE ANALYSIS
↓
BEAUTY PROFILE
↓
STYLE SELECTION
↓
PERSONALIZED PALETTE
WHAT + WHY
↓
FINAL PREVIEW
↓
SHOW ME HOW
WHERE + HOW
```

This track does NOT rebuild FaceTune, replace V4 Tutorial, redesign the accepted Final Result experience, merge Standard and My Makeup Kit business authority, or introduce subscription/billing/paywall/pricing/quota/entitlement work.

---

# 1. DOCUMENT AUTHORITY

Before ANY implementation, read completely and in order:

1. `CODEX_MASTER_GUIDE.md`
2. `FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_SOURCE_OF_TRUTH.md`
3. `FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_PHASE_PROMPTS.md`
4. current canonical FaceTune UI Productionization Source of Truth
5. current canonical FaceTune UI Productionization Phase Prompts
6. `FACETUNE_LIVE_SCAN_EDUCATIONAL_PALETTE_SOURCE_OF_TRUTH.md`
7. `FACETUNE_LIVE_SCAN_EDUCATIONAL_PALETTE_PHASE_PROMPTS.md`
8. relevant completion/debug reports
9. actual source, tests, configuration, deployed functions, and device evidence relevant to the active phase

Authority rules:

- this Source of Truth governs Live Scan + Educational Palette
- accepted V4 authority governs protected tutorial architecture
- accepted UI Productionization authority governs the global UI baseline
- `CODEX_MASTER_GUIDE.md` governs the remaining application
- active phase prompt authorizes ONLY that phase
- completion reports are evidence, not truth
- actual source/runtime behavior wins over assumptions
- production/device evidence wins over stale reports
- no phase may silently widen its own scope

If a protected subsystem appears necessary:

```text
STOP
REPORT EXACT DEPENDENCY
DO NOT CHANGE IT
```

---

# 2. MANDATORY SYSTEM ROLE

Act simultaneously as Principal Software Engineer, Principal Software Architect, Senior Flutter Engineer, Senior Dart Engineer, Senior Riverpod Engineer, Senior Camera/Media Pipeline Engineer, Senior On-Device Validation Engineer, Senior Mobile Performance Engineer, Senior Async/Concurrency Engineer, Senior Supabase Engineer, Senior Gemini AI Engineer, Senior Prompt Engineer, Senior AI Cost Engineer, Senior Security Engineer, Senior Privacy Engineer, Senior Accessibility Engineer, Senior Mobile UI/UX Engineer, Senior QA/Regression Engineer, Senior Integration Test Engineer, Senior Production Debugging Engineer, Senior Code Reviewer, Senior Beauty Recommendation Systems Designer, and Senior Makeup Education UX Designer.

These rules apply equally to OpenAI Codex and Claude Code Pro using Opus 5.

Inspect first. Challenge stale assumptions. Prefer the smallest production-safe change. Preserve working FaceTune behavior.

---

# 3. ENGINEERING PRIORITIES

Prioritize, in order:

1. correctness
2. preservation of accepted working behavior
3. user control over photo capture
4. no accidental paid-AI duplication
5. privacy
6. security
7. reliability
8. educational truthfulness
9. maintainability
10. testability
11. performance
12. accessibility
13. user experience
14. visual polish

Do not trade correctness for implementation speed.

---

# 4. GIT / BRANCH SAFETY

Required implementation branch:

```text
feature/live-scan-educational-palette
```

Required base: latest user-accepted UI Productionization state.

Before any implementation:

```powershell
git branch --show-current
git log -1 --oneline
git status --short
git diff --stat
```

Do NOT automatically switch, stash, commit, reset, clean, restore, rebase, merge, cherry-pick, discard valid work, push, or rewrite history.

If branch/worktree is unsafe:

```text
STOP
REPORT EXACT GIT STATE
DO NOT MUTATE GIT
```

---

# 5. PROTECTED WORKING BASELINE

Protected pipeline:

```text
SELFIE / STILL IMAGE
↓
FACE ANALYSIS
↓
BEAUTY PROFILE
↓
STYLE SELECTION
↓
RECOMMENDATION
↓
CANONICAL FINAL PREVIEW
↓
RESULT EXPERIENCE
↓
DYNAMIC MANIFEST
↓
STEP-BY-STEP TUTORIAL
```

This track improves only selfie acquisition/quality validation and recommendation education.

---

# 6. ABSOLUTE MODEL / PROMPT LOCKS

Preserve:

```text
FINAL PREVIEW MODEL
gemini-3.1-flash-image

TUTORIAL MODEL
gemini-3.1-flash-image

TUTORIAL RESOLUTION
1K

TUTORIAL PROMPT
tutorial_guideline_v4_7

MANIFEST PROMPT
tutorial_manifest_v4_1

FACE ANALYSIS MODEL
CURRENT DEPLOYED CONFIGURATION

RECOMMENDATION MODEL
CURRENT DEPLOYED CONFIGURATION
```

Do NOT switch models as a quality fix, add silent fallbacks, create per-screen substitutions, let Flutter choose a model, alter Final Preview prompt/request behavior, alter Tutorial prompt/resolution, or alter Manifest prompt.

---

# 7. ABSOLUTE AI CALL LOCKS

```text
LIVE CAMERA FRAMES
→ 0 Gemini calls

ONE ACCEPTED STILL
→ exactly one normal face-analysis request

EDUCATIONAL PALETTE
→ 0 additional Gemini calls
```

Never create:

```text
Recommendation Gemini
↓
Education Gemini
```

Preferred:

```text
ONE EXISTING RECOMMENDATION CALL
↓
recommendation + educational structured output
```

UI expansion/collapse, scrolling, rebuild, theme, orientation, and animation must trigger zero paid AI calls.

---

# 8. CANONICAL CAMERA FLOW

```text
OPEN CAMERA
↓
LIVE LOCAL VALIDATION
↓
ONE HIGHEST-PRIORITY GUIDANCE MESSAGE
↓
READY
↓
TAKE PHOTO ENABLED
↓
USER CHOOSES WHEN TO TAP
↓
CAPTURE ONE STILL
↓
FINAL LOCAL STILL VALIDATION
↓
PASS
→ EXISTING FACE ANALYSIS ONCE

FAIL
→ ZERO PAID ANALYSIS
→ ACTIONABLE GUIDANCE
→ RETAKE
```

Core principle:

```text
SMART VALIDATION
+
MANUAL CAPTURE
```

---

# 9. MANUAL CAPTURE HARD LOCK

The camera must NEVER automatically capture.

Prohibited:

- countdown auto shutter
- delayed automatic shutter
- capture after Ready timer
- capture after stable-pass timer
- hidden automatic capture
- automatic burst

Required:

```text
CHECKS ACCEPTABLE
↓
READY
↓
USER TAPS TAKE PHOTO
```

A stability window may stabilize the validation display. It must NEVER become an auto-capture timer.

---

# 10. LIVE LOCAL VALIDATION CONTRACT

Target checks:

1. One person only
2. Face fully visible
3. Good / usable lighting
4. Sharp enough / no heavy blur
5. No extreme angle

Reuse existing validated quality semantics and thresholds where possible. Do not weaken current acceptance rules for UI convenience.

Each check should support an explicit state equivalent to:

```text
unknown
checking
pass
warning
fail
```

---

# 11. USER GUIDANCE CONTRACT

Do not permanently show a large wall of five changing checks.

Default experience emphasizes one actionable issue, such as:

```text
Position your face in the frame
Move slightly closer
Center your face
Move toward better light
Hold the camera steady
Face the camera more directly
```

Ready state:

```text
Ready
Take the photo when you're happy with your look.
```

An optional secondary control such as `4 of 5 checks ready` may expose details. Detailed checks remain secondary.

---

# 12. HARD BLOCKERS VS QUALITY WARNINGS

The baseline audit must inspect the existing validator before changing policy.

Conceptually:

```text
BLOCKING FAILURE
→ shutter disabled

QUALITY WARNING
→ guidance shown
→ capture allowed only if current policy permits

PASS
→ Ready
```

Possible blockers and warnings in this document are examples, not permission to weaken current production validation.

The captured still remains the authoritative quality gate.

---

# 13. VALIDATION STABILITY / CONCURRENCY

Avoid flicker and stale async results.

Required principles:

```text
controlled sampling
one expensive validation operation in flight
no unbounded frame queue
latest-result authority
stale-result rejection
short display stability
resource disposal
```

Do NOT blindly validate every 30/60 FPS camera frame.

Exact cadence must be measured, not guessed.

POCO X3 GT is the primary performance quality bar.

---

# 14. PRIVACY LOCK

Live frames remain local.

Do NOT:

- send live frames to Gemini
- upload live frames to Supabase
- call Edge Functions with live frames
- log image bytes/base64
- create signed URLs for live frames
- persist transient frames unnecessarily

Only the manually captured still may enter the existing secure still-image pipeline.

---

# 15. CAMERA / COMPUTER-VISION DEPENDENCY GATE

Before implementing Live Scan, audit current camera and validation capabilities:

```text
Current camera plugin
External vs in-app camera
Live-frame access
Current local validator
Face-count capability
Face-visibility capability
Lighting capability
Blur capability
Angle capability
```

No new dependency is automatically authorized.

Do NOT silently add MediaPipe, OpenCV, TensorFlow Lite, a new ML runtime, a new face detector, or a new camera plugin.

If required:

```text
STOP
REPORT DEPENDENCY PROPOSAL
```

Report missing capability, proposed dependency, APK-size impact, performance impact, privacy/security impact, license, maintenance burden, Android compatibility, alternatives, and test strategy.

---

# 16. FINAL STILL VALIDATION

Live validation is advisory. The captured still is authoritative.

```text
USER TAPS
↓
CAPTURE STILL
↓
FINAL LOCAL VALIDATION
```

Pass:

```text
ACCEPT
↓
FACE ANALYSIS ONCE
```

Fail:

```text
0 FACE ANALYSIS
0 PAID AI
↓
SHOW ACTUAL REASON
↓
RETAKE
```

---

# 17. GALLERY FLOW

```text
CHOOSE FROM GALLERY
↓
USER SELECTS PHOTO
↓
AUTOMATIC LOCAL VALIDATION
↓
PASS
→ FACE ANALYSIS ONCE

FAIL
→ ZERO FACE ANALYSIS
→ SHOW ACTUAL ISSUE
→ CHOOSE ANOTHER PHOTO
```

Remove redundant gallery `Validate selfie` and post-pass `Analyze selfie` steps.

---

# 18. FACE ANALYSIS ONE-SHOT CONTRACT

Required lifecycle:

```text
acceptedStill
↓
analysisNotStarted
↓
analysisRequested
↓
analyzing
↓
analysisComplete
```

Once requested, rebuilds must not issue another request.

Never trigger paid analysis directly from `build()`.

Theme changes, orientation, MediaQuery, animation, snackbar, camera frames, validation changes, and accessibility updates must cause zero duplicate face-analysis calls.

---

# 19. ANALYSIS REUSE

Same accepted scan:

```text
Analysis complete
↓
Style A
↓
Back
↓
Style B
```

must not rerun face analysis.

Only a changed authoritative source selfie may trigger a new analysis under current business rules.

---

# 20. BEAUTY PROFILE ROLE

Beauty Profile answers:

> What did FaceTune learn about me?

Preserve Face shape, Skin tone, Undertone, Eye shape, Lip shape, Eye color, Hair color, and every individual confidence value.

Do not aggregate confidence values.

Do not repeat a large quality-validation checklist after analysis is complete.

---

# 21. PERSONALIZED PALETTE ROLE

Personalized Palette answers:

> What makeup is FaceTune recommending for me, and why does it work?

Canonical separation:

```text
PERSONALIZED PALETTE
WHAT + WHY

FINAL RESULT
WHAT THE COMPLETE LOOK LOOKS LIKE

MAKEUP TAB
DETAILED SHADE / FINISH / PRODUCT METADATA

SHOW ME HOW
WHERE + HOW
```

---

# 22. PALETTE PRESENTATION CONTRACT

Palette may display:

- category
- shade/color
- finish
- intensity
- `Why this works for you`

Remove from Personalized Palette presentation:

```text
Placement
Technique
```

---

# 23. PLACEMENT / TECHNIQUE DATA HARD LOCK

Do NOT delete Placement or Technique from recommendation data, validated look plan, persistence, Makeup Breakdown, historical records, or tutorial support context.

```text
REMOVE FROM PALETTE PRESENTATION
≠
REMOVE FROM SYSTEM DATA
```

Required:

```text
Placement data     PRESERVED
Technique data     PRESERVED
Placement on Palette HIDDEN
Technique on Palette HIDDEN
```

---

# 24. EDUCATIONAL PALETTE CONTRACT

Every recommendation should teach three concepts:

```text
YOUR FEATURES
THE EFFECT
THE STYLE
```

**Your features** explains which real detected attributes influenced the recommendation.

**The effect** explains what the actual shade, finish, intensity, tonal contrast, or color family does visually.

**The style** explains why the actual recommendation supports the actual selected makeup style.

---

# 25. EDUCATIONAL GROUNDING

Education must be grounded in:

```text
ACTUAL FACE ANALYSIS
+
ACTUAL SELECTED STYLE
+
ACTUAL RECOMMENDATION
```

Never invent acne, skin sensitivity, dark circles, age, unobserved proportions, cheekbone prominence, eye depth, lip asymmetry, missing confidence values, products, shades, or finishes.

Avoid absolute claims like `perfect`, `guaranteed`, `always best`, or `definitely`.

Do not create a hardcoded Dart beauty-rule engine. Education explains the recommendation. It does not independently choose it.

---

# 26. RECOMMENDATION AI CONTRACT

First preference:

```text
ENRICH THE EXISTING RECOMMENDATION CALL
```

Never:

```text
RECOMMENDATION CALL
+
SECOND EDUCATION AI CALL
```

If current output is insufficient, extend the same structured response with typed fields conceptually equivalent to:

```text
features_explanation
visual_effect_explanation
style_explanation
```

Use project naming conventions.

Preserve Category, Shade, Finish, Intensity, Placement, and Technique.

The current deployed recommendation model remains locked.

---

# 27. PROMPT VERSIONING / COST CONTROL

If recommendation prompt/schema changes:

- version it according to project conventions
- test malformed output
- preserve historical compatibility
- do not alter Final Preview prompt
- do not alter Tutorial prompt
- do not alter Manifest prompt

Measure current versus new output size/tokens and incremental cost.

No second AI call. No model switch.

---

# 28. PERSISTENCE / HISTORICAL COMPATIBILITY GATE

Inspect current recommendation persistence first.

Do not create a DB migration merely for UI convenience.

If migration is genuinely required:

```text
STOP
REPORT EXACT MINIMUM MIGRATION
DO NOT IMPLEMENT WITHOUT EXPLICIT APPROVAL
```

Old recommendations without education fields must decode safely.

If education is absent:

```text
SHOW COMPACT RECOMMENDATION
DO NOT INVENT EDUCATION
DO NOT CALL AI TO BACKFILL
```

---

# 29. PROGRESSIVE DISCLOSURE

Do not make every recommendation card expanded by default.

Collapsed:

```text
● Foundation                 Soft
  Warm Medium Beige
  Dewy

  Why this works for you       ˅
```

Expanded:

```text
Your features
...

The effect
...

The style
...
```

Expansion is presentation-only and causes zero paid calls.

Target each subsection at roughly 1-2 concise sentences; approximately 60-120 total words per expanded category is a UX target, not a hard server rejection rule.

---

# 30. READY-FOR-PREVIEW SIMPLIFICATION

Reduce the oversized `Ready for your preview` explanation.

Target:

```text
END OF PALETTE
↓
GENERATE MAKEUP PREVIEW
```

Preserve the exact existing preview-generation callback and behavior.

---

# 31. UI / ACCESSIBILITY LOCK

Use the accepted FaceTune production design system: typography, colors, spacing, radii, buttons, cards, global Back, vector icons, Light/Dark/System behavior, and accessibility conventions.

No emoji UI icons. No separate camera theme. No separate palette theme.

Live Scan must not rely on color alone, must avoid per-frame screen-reader spam, and must expose meaningful shutter/guidance semantics.

Palette expansion must expose expanded/collapsed state, logical reading order, textual shade meaning, and large-text wrapping.

---

# 32. SECURITY / MY KIT / RESULT / TUTORIAL PROTECTION

Preserve Auth, JWT, RLS, private storage, server-side secrets/model config, upload ownership, and analysis ownership.

My Makeup Kit remains:

```text
OWNED PRODUCTS ONLY
SERVER VALIDATED
IMMUTABLE SNAPSHOT
NO STANDARD FALLBACK
NO PRODUCT SUBSTITUTION
```

Do not redesign the accepted Result experience.

Do not change Dynamic Manifest, Tutorial model, Tutorial 1K resolution, `tutorial_guideline_v4_7`, Guide Key, redraw architecture, tutorial persistence, or canonical-preview grounding.

Palette education must not duplicate Show Me How.

---

# 33. TEST STRATEGY

Minimum eventual coverage:

## Camera

- live validation
- each failure state
- Ready
- no auto capture
- manual capture
- final still validation
- one face-analysis request per accepted still
- zero analysis for rejected still
- no duplicate analysis from rebuild
- stale-result protection
- resource disposal

## Gallery

- automatic validation
- pass -> one analysis
- fail -> zero analysis
- reselect
- no redundant Validate button
- no redundant Analyze button

## Palette

- Placement hidden
- Technique hidden
- Placement data preserved
- Technique data preserved
- compact card
- education expansion
- Your features
- The effect
- The style
- long-copy behavior
- historical compatibility
- Generate Preview unchanged

## AI / Cost

- Live Gemini = 0
- Extra education Gemini = 0
- Face analysis = 1 per accepted still
- Final Preview call count unchanged
- Manifest call count unchanged
- Tutorial call count unchanged

---

# 34. REAL DEVICE BAR

POCO X3 GT is required for final acceptance.

Automated tests do not prove camera responsiveness, guidance flicker, shutter responsiveness, live-frame performance, real permission behavior, or educational expansion ergonomics.

If unavailable:

```text
REAL DEVICE
PENDING USER VERIFICATION
```

Never fabricate device evidence.

---

# 35. PHASE ROADMAP

```text
LSEP-0 — Baseline Freeze & Feasibility Map
LSEP-1 — Educational Recommendation Contract
LSEP-2 — Educational Palette UI & Preview CTA Simplification
LSEP-3 — Live Scan Technical Foundation & Dependency Gate
LSEP-4 — Live Camera Validation + Manual Capture
LSEP-5 — Gallery Auto Validation + One-Shot Analysis Handoff
LSEP-6 — Beauty Profile Friction Cleanup & End-to-End Integration
LSEP-7 — Production QA, Cost Audit & Baseline Lock
```

---

# 36. GLOBAL STOP CONDITIONS

STOP before modifying unless the active phase explicitly authorizes it:

- Final Preview model
- Tutorial model
- Tutorial resolution
- Face-analysis model
- Recommendation model
- Final Preview prompt
- Tutorial prompt
- Manifest prompt
- database schema
- RLS
- storage policy
- authentication
- My Makeup Kit authority
- Dynamic Manifest architecture
- Tutorial architecture
- new camera dependency
- new computer-vision dependency
- new paid AI call
- subscription/billing

---

# 37. FINAL SOURCE-OF-TRUTH LOCK

```text
LIVE CAMERA VALIDATION
LOCAL

LIVE GEMINI
0

CAMERA CAPTURE
MANUAL ONLY

AUTO CAPTURE
NEVER

FINAL STILL VALIDATION
AUTOMATIC

FACE ANALYSIS
EXACTLY ONCE AFTER ACCEPTED STILL

GALLERY VALIDATION
AUTOMATIC

EDUCATIONAL PALETTE
WHAT + WHY

EDUCATION SECTIONS
YOUR FEATURES + THE EFFECT + THE STYLE

TUTORIAL
WHERE + HOW

EXTRA EDUCATION AI CALL
0

PLACEMENT DATA
PRESERVED

TECHNIQUE DATA
PRESERVED

PLACEMENT ON PALETTE
HIDDEN

TECHNIQUE ON PALETTE
HIDDEN

FINAL PREVIEW MODEL
gemini-3.1-flash-image

TUTORIAL MODEL
gemini-3.1-flash-image

TUTORIAL RESOLUTION
1K

MY MAKEUP KIT AUTHORITY
PRESERVED
```

No phase may reinterpret these locks without explicit user approval.
