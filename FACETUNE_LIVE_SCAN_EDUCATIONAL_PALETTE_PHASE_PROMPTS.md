# FaceTune — LIVE SCAN + EDUCATIONAL PALETTE PHASE PROMPTS

**Project root:** `C:\Users\Kurt\facetune`  
**Required branch:** `feature/live-scan-educational-palette`  
**Required base:** latest user-accepted UI Productionization state  
**Primary device:** POCO X3 GT  

**Final Preview Model — LOCKED:** `gemini-3.1-flash-image`  
**Tutorial Model — LOCKED:** `gemini-3.1-flash-image`  
**Tutorial Resolution — LOCKED:** `1K`  
**Tutorial Prompt — LOCKED:** `tutorial_guideline_v4_7`  
**Manifest Prompt — LOCKED:** `tutorial_manifest_v4_1`  
**Face Analysis Model:** preserve current deployed configuration  
**Recommendation Model:** preserve current deployed configuration  

**Live Camera Gemini Calls:** `0`  
**Extra Education Gemini Calls:** `0`  
**Camera Auto Capture:** `NEVER`  
**Face Analysis Per Accepted Still:** `1`  

---

# HOW TO USE THIS FILE

1. Keep this file beside the Live Scan + Educational Palette Source of Truth.
2. Use OpenAI Codex or Claude Code Pro using Opus 5.
3. Execute exactly ONE phase at a time.
4. Paste only the currently authorized phase prompt.
5. Review completion evidence before proceeding.
6. Never auto-continue.
7. Production/device evidence wins over completion reports.
8. Actual source wins over stale assumptions.
9. Never change a model as a quality fix.
10. Never add a paid AI call as a convenience.
11. Never change DB/RLS/storage for UI convenience.
12. Never silently install camera/vision dependencies.
13. Protected subsystem requirement means STOP and report.
14. Never commit/push/merge/rebase unless explicitly authorized.

---

# MANDATORY READ ORDER

Every phase must first read completely, in order:

```text
1. CODEX_MASTER_GUIDE.md
2. FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_SOURCE_OF_TRUTH.md
3. FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_PHASE_PROMPTS.md
4. current canonical UI Productionization Source of Truth
5. current canonical UI Productionization Phase Prompts
6. FACETUNE_LIVE_SCAN_EDUCATIONAL_PALETTE_SOURCE_OF_TRUTH.md
7. FACETUNE_LIVE_SCAN_EDUCATIONAL_PALETTE_PHASE_PROMPTS.md
8. relevant previous completion reports
9. actual relevant source/tests/config/functions
10. device evidence
```

---

# GLOBAL BRANCH GATE

Before editing:

```powershell
git branch --show-current
git log -1 --oneline
git status --short
git diff --stat
```

Required branch:

```text
feature/live-scan-educational-palette
```

If different:

```text
STOP
DO NOT MODIFY SOURCE
REPORT ACTUAL BRANCH
```

Do not automatically switch.

If valid uncommitted UI work prevents safe branch setup:

```text
STOP
REPORT
DO NOT STASH
DO NOT COMMIT
DO NOT RESET
```

---

# GLOBAL SYSTEM ROLE

Act simultaneously as:

- Principal Software Engineer
- Principal Software Architect
- Senior Flutter Engineer
- Senior Dart Engineer
- Senior Riverpod Engineer
- Senior Mobile Engineer
- Senior Camera Pipeline Engineer
- Senior On-Device Validation Engineer
- Senior Async / Concurrency Engineer
- Senior Mobile Performance Engineer
- Senior Gemini AI Engineer
- Senior Prompt Engineer
- Senior AI Cost Engineer
- Senior Supabase Engineer
- Senior Security Engineer
- Senior Privacy Engineer
- Senior Accessibility Engineer
- Senior Mobile UI/UX Engineer
- Senior QA Engineer
- Senior Regression Engineer
- Senior Integration Test Engineer
- Senior Production Debugging Engineer
- Senior Code Reviewer
- Senior Beauty Recommendation Systems Designer

Inspect first.
Challenge stale assumptions.
Prefer the smallest production-safe change.

---

# GLOBAL HARD LOCKS

Preserve:

```text
FINAL PREVIEW
gemini-3.1-flash-image

TUTORIAL
gemini-3.1-flash-image

TUTORIAL RESOLUTION
1K

TUTORIAL PROMPT
tutorial_guideline_v4_7

MANIFEST PROMPT
tutorial_manifest_v4_1

FACE ANALYSIS MODEL
CURRENT DEPLOYED MODEL

RECOMMENDATION MODEL
CURRENT DEPLOYED MODEL

LIVE GEMINI
0

EXTRA EDUCATION AI CALL
0

AUTO CAPTURE
NEVER

FACE ANALYSIS PER ACCEPTED STILL
1
```

Do NOT:

- switch models
- add fallback chains
- use Gemini for live camera validation
- add a second education Gemini call
- delete Placement/Technique data
- move paid work into `build()`
- weaken My Kit authority
- redesign accepted Result
- redesign accepted Tutorial
- disable/weaken RLS
- make storage public
- silently install ML/camera dependencies
- commit/push/merge without permission

---

# GLOBAL COMPLETION REPORT

Every phase must end with:

```text
PHASE COMPLETED:

AGENT:

BRANCH VERIFIED:

HEAD BEFORE:

HEAD AFTER:

WORKING TREE BEFORE:

WORKING TREE AFTER:

OBJECTIVE ACHIEVED:
YES / PARTIAL / NO

SOURCE OF TRUTH COMPLIANCE:
PASS / FAIL

FILES CREATED:

FILES MODIFIED:

FILES DELETED:

DEPENDENCIES ADDED / REMOVED:

DATABASE CHANGES:
NONE / exact finding

RLS CHANGES:
NONE / exact finding

STORAGE CHANGES:
NONE / exact finding

EDGE FUNCTION / AI CHANGES:

FACE ANALYSIS MODEL:

RECOMMENDATION MODEL:

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

MODEL CHANGES:
NONE

LIVE GEMINI CALLS:
0 / FAIL

EXTRA EDUCATION AI CALLS:
0 / FAIL

FACE ANALYSIS PER ACCEPTED STILL:
1 / exact finding

AUTO CAPTURE:
NONE / FAIL

PLACEMENT DATA:
PRESERVED / CHANGED

TECHNIQUE DATA:
PRESERVED / CHANGED

MY MAKEUP KIT AUTHORITY:
PRESERVED / CHANGED

SECURITY CHECK:

PRIVACY CHECK:

COST / DUPLICATE-CALL CHECK:

DART FORMAT:

FLUTTER ANALYZE:

TARGETED TESTS:

FULL FLUTTER TEST:

ANDROID BUILD:

REAL DEVICE:

KNOWN LIMITATIONS:

ASSUMPTIONS NOT PROVEN:

MANUAL ACTION REQUIRED:

NEXT RECOMMENDED PHASE:

STOP CONFIRMATION:
No later phase implemented.
No unauthorized Git mutation.
```

A vague report is not acceptable.

---

# LSEP-0 — BASELINE FREEZE & FEASIBILITY MAP

Read all mandatory authority files completely before making changes.

Implement only:

**LSEP-0 — BASELINE FREEZE & FEASIBILITY MAP**

Then STOP.

## Objective

Establish the actual technical baseline before changing camera, AI contracts, or Palette UI.

This phase is READ-ONLY.

## Audit

Inspect:

```text
Camera implementation
External vs in-app camera
Camera dependencies
Live-frame access
Gallery picker
Local validator
Face count
Face visibility
Lighting
Blur
Angle
Validation thresholds
Face-analysis trigger
Face-analysis model
Analysis persistence/reuse
Recommendation model
Recommendation prompt
Recommendation schema
Reasoning fields
Placement consumers
Technique consumers
Recommendation persistence
Palette UI
Ready-for-preview UI
Final Preview protection
Result protection
Tutorial protection
My Kit protection
```

## Dependency gate

If live validation needs new software:

```text
DEPENDENCY REQUIRED:
YES

MISSING CAPABILITY:

PROPOSED DEPENDENCY:

APK SIZE:

PERFORMANCE:

PRIVACY:

SECURITY:

LICENSE:

ANDROID SUPPORT:

MAINTENANCE:

ALTERNATIVES:

TEST PLAN:
```

Do not install it.

## Non-negotiable rules

- no source changes
- no dependency changes
- no model changes
- no prompt changes
- no DB/RLS/storage changes
- no deployment
- no paid AI calls for this audit

## Validation

```powershell
git branch --show-current
git status --short
flutter analyze
```

## Done when

- camera architecture known
- live-frame feasibility known
- validator capability known
- face-analysis trigger known
- recommendation contract known
- persistence known
- Placement/Technique consumers known
- protected surfaces identified
- no source changed

Then STOP.

---

# LSEP-1 — EDUCATIONAL RECOMMENDATION CONTRACT

Read all mandatory authority files completely before making changes.

Implement only:

**LSEP-1 — EDUCATIONAL RECOMMENDATION CONTRACT**

Then STOP.

## Entry gate

LSEP-0 must have mapped the actual recommendation model, prompt/schema, parser, persistence, historical decode behavior, and downstream Placement/Technique consumers.

If a DB migration is required:

```text
STOP
REPORT EXACT REQUIREMENT
```

## Objective

Support educational content equivalent to:

```text
Your features
The effect
The style
```

inside the existing recommendation operation.

## Critical paid-AI rule

Never:

```text
Recommendation AI
↓
Education AI
```

Required:

```text
ONE RECOMMENDATION AI CALL
```

## Before coding

Inspect:

- current recommendation prompt builder
- actual model config
- structured-output schema
- parser/validation
- domain entity
- persistence format
- historical decode
- Standard Mode authority
- My Makeup Kit authority
- output token limits
- error/fallback behavior

## Implementation priority

1. Reuse current reasoning if it can truthfully support the three education sections.
2. Otherwise extend the SAME structured response.
3. Add typed fields conceptually equivalent to:
   - features explanation
   - visual effect explanation
   - style explanation
4. Preserve Placement.
5. Preserve Technique.
6. Preserve Category/Shade/Finish/Intensity.
7. Preserve actual current recommendation model.

Use project naming conventions rather than blindly copying suggested field names.

## Grounding contract

Education may use only:

```text
actual accepted face analysis
+
actual selected style
+
actual recommendation values
```

Do not invent attributes, skin conditions, product brands, shades, finishes, confidence values, or medical claims.

Do not create a hardcoded beauty-rule engine.

## Historical compatibility

Old records without new education fields:

```text
must decode safely
must not crash
must not generate fake educational copy
must not trigger AI backfill
```

## Prompt versioning

If prompt/schema materially changes, version it according to the current project convention.

Do NOT change Final Preview, Tutorial, or Manifest prompts.

## Token/cost check

Report:

```text
current recommendation output size/tokens
new expected output size/tokens
incremental token delta
estimated incremental cost
additional paid calls = 0
```

## Tests

At minimum prove:

- typed education is representable
- malformed/missing fields handled safely
- old records decode safely
- Placement preserved
- Technique preserved
- Standard remains brand-neutral
- My Kit remains owned-products-only
- no Standard fallback
- no product substitution
- one recommendation call only

## Do NOT implement

- Palette UI
- Camera
- Gallery
- Final Preview changes
- Result changes
- Tutorial changes
- Manifest changes
- model changes
- DB migration

Then STOP.

---

# LSEP-2 — EDUCATIONAL PALETTE UI & PREVIEW CTA SIMPLIFICATION

Read all mandatory authority files completely before making changes.

Implement only:

**LSEP-2 — EDUCATIONAL PALETTE UI & PREVIEW CTA SIMPLIFICATION**

Then STOP.

## Objective

Make Personalized Palette answer:

```text
WHAT
+
WHY
```

not application instructions.

## Default card

Conceptual target only:

```text
● Foundation                 Soft
  Warm Medium Beige
  Dewy

  Why this works for you       ˅
```

## Expanded card

```text
Your features
<grounded explanation>

The effect
<grounded explanation>

The style
<grounded explanation>
```

## Remove from Palette presentation

```text
Placement
Technique
```

## Preserve system data

```text
Placement = PRESERVE
Technique = PRESERVE
```

Do not delete them from recommendation/domain/persistence/Breakdown/tutorial context.

## Progressive disclosure

Cards are collapsed by default.

Expansion/collapse triggers:

```text
0 Gemini calls
0 recommendation calls
0 preview calls
```

Use accepted FaceTune design-system components and Light/Dark/System behavior.

## Ready-for-preview simplification

Reduce oversized generic `Ready for your preview` content.

Target hierarchy:

```text
END OF PALETTE
↓
GENERATE MAKEUP PREVIEW
```

Preserve the exact existing preview-generation callback.

## Do NOT implement

- AI changes
- camera/gallery changes
- Final Preview generation changes
- Result redesign
- Tutorial changes
- DB/RLS/storage changes

## Tests

At minimum prove:

- Placement absent from Palette UI
- Technique absent from Palette UI
- Placement data still preserved
- Technique data still preserved
- collapsed default state
- expansion state
- Your features rendered when authoritative
- The effect rendered when authoritative
- The style rendered when authoritative
- old records without education remain safe
- no invented fallback paragraphs
- large text wraps
- Light/Dark/System pass
- expansion causes zero paid calls
- Generate Preview callback unchanged

Then STOP.

---

# LSEP-3 — LIVE SCAN TECHNICAL FOUNDATION & DEPENDENCY GATE

Read all mandatory authority files completely before making changes.

Implement only:

**LSEP-3 — LIVE SCAN TECHNICAL FOUNDATION & DEPENDENCY GATE**

Then STOP.

## Entry gate

Either:

```text
current dependencies support required live local validation
```

or:

```text
user explicitly approved the dependency proposal from LSEP-0
```

Otherwise STOP.

## Objective

Create the minimum maintainable local live-validation state and concurrency protection.

## Required state

Conceptually support:

```text
unknown
checking
pass
warning
fail
```

Maintain one authoritative state owner for:

- current validation snapshot
- primary guidance message
- capture eligibility
- frame/session generation token
- validation in-flight state

## Concurrency contract

Required:

```text
one validation operation in flight
no unbounded frame queue
stale results discarded
latest-result authority
controlled validation cadence
resource disposal
```

Exact cadence must be measured, not invented.

## AI / privacy lock

```text
LIVE GEMINI CALLS
0

LIVE FRAME UPLOADS
0
```

No live frame persistence/logging.

## Tests

Prove:

- state transitions
- latest-result authority
- stale-result rejection
- no unbounded queue
- capture eligibility mapping
- local-only behavior
- zero paid/network calls from live frames
- proper disposal

## Do NOT implement

- Auto Capture
- complete Camera UI polish
- Gallery rewrite
- AI model changes
- Palette changes
- Result changes
- Tutorial changes

Then STOP.

---

# LSEP-4 — LIVE CAMERA VALIDATION + MANUAL CAPTURE

Read all mandatory authority files completely before making changes.

Implement only:

**LSEP-4 — LIVE CAMERA VALIDATION + MANUAL CAPTURE**

Then STOP.

## Objective

Implement:

```text
LIVE LOCAL VALIDATION
↓
ONE HIGHEST-PRIORITY GUIDANCE MESSAGE
↓
READY
↓
USER MANUALLY CAPTURES
↓
FINAL STILL VALIDATION
↓
ONE FACE ANALYSIS
```

## Auto-capture prohibition

Absolute:

```text
AUTO CAPTURE
NEVER
```

After Ready, the app waits indefinitely for explicit user shutter tap.

A stability window may affect status display only.

## Camera UI

Use accepted FaceTune global presentation.

Show only what is necessary:

```text
Live camera
Face guide
Current primary guidance
Optional compact check count/details
Take photo
Gallery
```

Do not permanently show a large five-row validation report.

## Ready state

```text
Ready
Take the photo when you're happy with your look.
```

## Capture behavior

On explicit user tap:

```text
capture exactly one still
↓
final local validation
↓
PASS
→ face analysis exactly once

FAIL
→ face analysis zero
→ actionable retake state
```

## Analysis transition

Where practical preserve captured image continuity:

```text
Captured image
Checking photo...
↓
Analyzing your features...
```

Do not fake progress percentages.

## Lifecycle lock

Paid analysis must not originate from `build()`.

Rebuilds, theme, orientation, MediaQuery, snackbar, animation, or camera frame updates must cause zero duplicate analysis.

## Tests

At minimum prove:

- each validation guidance state
- Ready
- shutter disabled/enabled according to actual policy
- Ready never auto-captures
- waiting in Ready causes zero capture
- manual tap captures exactly once
- final pass -> one analysis
- final fail -> zero analysis
- stale-result protection
- rebuild -> zero duplicate analysis
- theme/orientation -> zero duplicate analysis
- camera resources disposed
- accessibility semantics
- large-text/no-overflow behavior

## Real-device gate

On POCO X3 GT:

```text
Reach Ready
Wait without touching shutter
Confirm zero capture
Choose preferred expression
Tap manually
Confirm chosen frame
Confirm analysis happens once
```

If unavailable, report `PENDING USER VERIFICATION`.

Then STOP.

---

# LSEP-5 — GALLERY AUTO VALIDATION + ONE-SHOT ANALYSIS

Read all mandatory authority files completely before making changes.

Implement only:

**LSEP-5 — GALLERY AUTO VALIDATION + ONE-SHOT ANALYSIS**

Then STOP.

## Objective

Implement:

```text
Choose gallery photo
↓
automatic local validation
↓
PASS
→ analysis once

FAIL
→ analysis zero
```

## Remove redundant manual gates

For Gallery only, remove the redundant:

```text
Validate selfie
```

step after the user selects an image.

After automatic pass, do not require a separate:

```text
Analyze selfie
```

button.

Selection itself is explicit user intent.

## Failure state

Show concise actual validation problem and allow reselection.

Example structure:

```text
This photo needs another try
<actual validation problem>
[ Choose another photo ]
```

Do not fabricate reasons.

## One-shot contract

A passing selected image triggers exactly one face-analysis request.

Rebuilds do not retrigger it.

## Tests

At minimum prove:

- picker cancel
- automatic validation after selection
- pass -> one analysis
- fail -> zero analysis
- reselect works
- invalid/inaccessible image safe
- Validate button absent in this flow
- Analyze-after-pass button absent
- rebuild causes zero duplicate analysis

Then STOP.

---

# LSEP-6 — BEAUTY PROFILE FRICTION CLEANUP & END-TO-END INTEGRATION

Read all mandatory authority files completely before making changes.

Implement only:

**LSEP-6 — BEAUTY PROFILE FRICTION CLEANUP & END-TO-END INTEGRATION**

Then STOP.

## Objective

Remove obsolete/redundant quality-validation explanations after analysis while preserving every authoritative Beauty Profile value.

Target hierarchy:

```text
YOUR BEAUTY PROFILE

Analysis complete

Face shape
Skin tone
Undertone
Eye shape
Lip shape
Eye color
Hair color
individual confidence values

Choose a makeup style
```

## Confidence lock

Do not aggregate individual confidence values.

Do not invent confidence.

## End-to-end journeys

Validate:

```text
Camera
→ Beauty Profile
→ Style
→ Educational Palette
→ Generate Preview
```

and:

```text
Gallery
→ Beauty Profile
→ Style
→ Educational Palette
→ Generate Preview
```

## Analysis reuse

```text
Profile
→ Style A
→ Back
→ Style B
```

must produce:

```text
0 new face-analysis calls
```

## Protected systems

Do not redesign Result.
Do not change Tutorial.
Do not change My Makeup Kit authority.
Do not change Final Preview generation.

## Tests

At minimum prove:

- Beauty Profile values preserved
- every confidence preserved
- redundant validation paragraph removed/reduced
- style navigation works
- analysis is reused
- Palette uses same accepted analysis
- preview-generation behavior unchanged
- Result regression pass
- Tutorial regression pass
- My Kit regression pass

Then STOP.

---

# LSEP-7 — PRODUCTION QA, COST AUDIT & BASELINE LOCK

Read all mandatory authority files completely before making changes.

Implement only:

**LSEP-7 — PRODUCTION QA, COST AUDIT & BASELINE LOCK**

Then STOP.

No new features are authorized except minimum remediation of defects proven in this phase.

## Required Camera journey

```text
New Scan
↓
Live local validation
↓
Ready
↓
Manual capture
↓
Final still validation
↓
Face analysis
↓
Beauty Profile
↓
Style
↓
Educational Palette
↓
Preview
↓
Result
↓
Show me how
```

## Required Gallery journey

```text
Gallery
↓
Automatic local validation
↓
Face analysis
↓
Beauty Profile
↓
Style
↓
Educational Palette
↓
Preview
↓
Result
↓
Show me how
```

## AI call audit

Must prove:

```text
LIVE GEMINI
0

FACE ANALYSIS PER ACCEPTED STILL
1

FACE ANALYSIS FOR REJECTED STILL
0

EXTRA EDUCATION AI CALL
0

FINAL PREVIEW CALL COUNT
UNCHANGED

MANIFEST CALL COUNT
UNCHANGED

TUTORIAL CALL COUNT
UNCHANGED
```

## Cost audit

Report:

```text
recommendation output/token delta
incremental education cost
new paid calls = 0
```

Do not switch models for cost optimization.

## Performance QA

On POCO X3 GT evaluate:

```text
camera startup
validation responsiveness
guidance stability
frame backlog
memory behavior
shutter responsiveness
repeated scans
resource disposal
```

No fabricated performance claims.

## Privacy/security QA

Prove:

```text
No live frames to Gemini
No live frames to Supabase Storage
No live image-byte/base64 logs
Accepted still uses secure existing pipeline
RLS unchanged
Storage private
Auth/JWT unchanged
```

## Educational QA

Representative recommendations must prove:

```text
Your features grounded in actual analysis
The effect grounded in actual recommendation
The style grounded in selected style
No invented analysis
No invented product
No Placement on Palette
No Technique on Palette
No application instructions leaked into education
```

## Theme/accessibility QA

Test:

```text
Light
Dark
System Light
System Dark
Normal text
Large text
Narrow Android
POCO X3 GT
```

## Validation

Run at minimum:

```powershell
dart format <changed files>
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/development.json
```

## Final lock

PASS requires:

```text
AUTO CAPTURE
NONE

LIVE GEMINI
0

FACE ANALYSIS PER ACCEPTED STILL
1

EXTRA EDUCATION AI CALL
0

FINAL PREVIEW
gemini-3.1-flash-image

TUTORIAL
gemini-3.1-flash-image @ 1K

PLACEMENT DATA
PRESERVED

TECHNIQUE DATA
PRESERVED

PALETTE PLACEMENT
HIDDEN

PALETTE TECHNIQUE
HIDDEN

MY KIT AUTHORITY
PRESERVED
```

## Final decision

Return exactly one:

```text
LSEP BASELINE ACCEPTED

LSEP BASELINE ACCEPTED — PENDING REAL DEVICE

LSEP CORRECTION REQUIRED

LSEP BLOCKED
```

Then STOP.

---

# FINAL EXECUTION RULE

The coding agent must NEVER automatically begin the next phase.

Only a new explicit user instruction authorizes it.

Final architecture:

```text
LIVE CAMERA
LOCAL QUALITY INTELLIGENCE
↓
USER CHOOSES PHOTO
↓
FACE ANALYSIS ONCE
↓
ONE RECOMMENDATION CALL
+
EDUCATIONAL OUTPUT
↓
PERSONALIZED PALETTE
WHAT + WHY
↓
EXISTING FINAL PREVIEW
↓
EXISTING TUTORIAL
WHERE + HOW
```

Complete the authorized phase.
Validate.
Report.
STOP.
