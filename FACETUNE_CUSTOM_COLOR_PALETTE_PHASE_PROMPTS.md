# FaceTune Beauty
# Custom Color Palette Recommendation Track
## Strict Phase Prompts
### Version 1.0.0

Canonical companion:

`FACETUNE_CUSTOM_COLOR_PALETTE_SOURCE_OF_TRUTH.md`

Execute **exactly one phase at a time**.

No phase authorizes the next phase automatically.

Every phase must end with:

```text
REPORT
STOP
```

---

# GLOBAL EXECUTION CONTRACT

Apply this block to every CCP phase.

```text
======================================================================
FACETUNE — CCP GLOBAL EXECUTION CONTRACT
======================================================================

You are implementing the Custom Color Palette track for FaceTune Beauty.

MANDATORY ROLES

Act simultaneously as:

- Principal Software Architect
- Staff Software Engineer
- Principal Flutter Engineer
- Senior Flutter / Dart Developer
- Senior Riverpod State-Management Engineer
- Senior Mobile Application Engineer
- Senior Android Engineer
- Senior Backend Engineer
- Senior Supabase Engineer
- Senior PostgreSQL Engineer
- Senior RLS / Data-Security Engineer
- Senior AI Systems Engineer
- Senior Generative-AI Engineer
- Senior Prompt Engineer
- Senior AI Evaluation Engineer
- Senior Reliability Engineer
- Senior Distributed-Systems Engineer
- Senior Application Security Engineer
- Senior Privacy Engineer
- Senior QA Automation Engineer
- Senior Integration-Test Engineer
- Senior E2E / Real-Device Test Engineer
- Senior Release Engineer
- Senior Production-Debugging Engineer
- Senior Code Reviewer
- Senior Product Engineer
- Senior UX / HCI Reviewer
- Makeup Workflow / Professional Makeup Domain Reviewer

AUTHORITY

Before editing, read and obey higher authorities.

At minimum locate and read:

- CODEX_MASTER_GUIDE.md
- current protected FaceTune architecture/security contracts
- current subscription/entitlement source-of-truth documents
- current Final Preview protected contracts
- current Tutorial V4 protected contracts
- current Standard Recommendation implementation/contracts
- current My Makeup Kit implementation/contracts
- FACETUNE_CUSTOM_COLOR_PALETTE_SOURCE_OF_TRUTH.md
- FACETUNE_CUSTOM_COLOR_PALETTE_PHASE_PROMPTS.md

Repository evidence is authoritative over stale handoff assumptions.

If authority conflicts:
STOP and report.

TRACK SCOPE

This track adds one new recommendation mode only:
Custom Color Palette.

It does not authorize Booking / Revision 2.

HARD LOCKS

DO NOT modify unless the current phase explicitly authorizes an additive
CCP-specific version or bridge:

- Standard Recommendation behavior
- Standard Final Preview behavior
- Standard Tutorial behavior
- My Makeup Kit recommendation behavior
- My Makeup Kit snapshot/lineage behavior
- kit_preview_mismatch semantics
- Tutorial V4 protected behavior
- tutorial_guideline_v4_7
- tutorial_manifest_v4_1
- historical recommendations/previews/tutorials
- protected Final Preview identity rules
- current authoritative Final Preview model
- RLS security model
- client/server trust boundary
- server-side-only Gemini
- reservation-time usage attribution
- server-authoritative subscription state
- SUB-10 verify → activate → acknowledge
- SUB-11 RTDN / lifecycle / Restore
- Web Admin scope
- Booking / provider / schedule features

DO NOT:

- let AI silently replace user-selected colors
- let AI silently replace selected finishes
- make Custom Color Palette depend on owned products
- use a live UI draft as historical truth
- rewrite historical records
- expose secrets
- call Gemini from Flutter
- weaken RLS
- double-charge one logical user request because of internal retries
- run destructive Git commands
- commit, push, merge, rebase, reset, clean, or stash unless explicitly authorized
- deploy unless explicitly authorized
- auto-start another phase

GIT BASELINE

Before source edits:
- record branch
- record HEAD
- record git status --short
- record git status --branch
- run git diff --check where applicable

If unexpected working-tree changes exist:
STOP and report.

AI CALLS

No real Gemini/provider calls unless the current phase explicitly authorizes them.

No production mutation unless the phase explicitly authorizes it.

READ-ONLY PHASES

If a phase says READ-ONLY or DESIGN:
make ZERO source changes.

STOP CONDITIONS

Stop immediately if:
- Standard Recommendation must change to complete the phase
- My Makeup Kit behavior must change to complete the phase
- Tutorial V4 safety must be weakened
- historical content must be rewritten
- current Final Preview model must change without separate authority
- accounting would double-charge a logical user request
- required authority is missing
- repository baseline is ambiguous
- schema change is needed outside an authorized schema phase
- Booking/Revision 2 changes appear necessary
- a planned assumption is contradicted by repository evidence

Never force a PASS.
======================================================================
```

---

# CCP-0 — BASELINE / AUTHORITY / PROTECTED-SYSTEM AUDIT

```text
======================================================================
FACETUNE
CCP-0 — BASELINE / AUTHORITY / PROTECTED-SYSTEM AUDIT
======================================================================

IMPLEMENT ONLY CCP-0.

MODE:
READ-ONLY

NO SOURCE CHANGES.
NO GEMINI CALLS.
NO PRODUCTION MUTATIONS.
NO COMMIT.
NO PUSH.

OBJECTIVE

Establish the exact current repository baseline and map every implementation
surface that Custom Color Palette may touch before design or coding begins.

TASKS

1. Read every required authority in the Global Execution Contract.

2. Record:

git branch --show-current
git rev-parse HEAD
git status --short
git status --branch
git branch -vv
git diff --check

3. Do NOT assume old PDMK/OMKT branch names are current. Report actual branch/worktree evidence.

4. Inventory the current recommendation-mode flow:
- where user chooses Standard vs My Makeup Kit
- route/page/widget involved
- Riverpod/controller/state objects
- style selection handoff
- facial-analysis handoff
- recommendation request contract
- recommendation response contract

5. Inventory current supported makeup categories across:
- recommendation
- Final Preview
- Tutorial
- History/Saved Looks

6. Inventory current finish-related concepts, if any.

7. Inventory existing color-picker / color-model / theme utilities, if any.

8. Locate current prompt/version routing for:
- Standard Recommendation
- My Makeup Kit Recommendation
- Standard Final Preview
- My Makeup Kit Final Preview
- Tutorial manifest
- Tutorial guideline

9. Confirm current Final Preview model from repository authority.

10. Trace usage lifecycle for Final Preview:
reserve → generate → validate/persist → commit/release

11. Trace History, Saved Looks, and Generate Another Variation lineage.

12. Confirm Standard Mode and My Makeup Kit are separable from an additive third mode.

13. Identify likely implementation surfaces without editing them.

14. Identify any existing tests that must protect Standard and My Makeup Kit.

FINAL REPORT

==================================================
CCP-0 BASELINE REPORT
==================================================

BRANCH:
<exact>

HEAD:
<exact>

WORKING TREE:
<exact>

CURRENT RECOMMENDATION MODES:
<exact>

MODE SELECTION SURFACE:
<exact files/classes/routes>

CURRENT SUPPORTED CATEGORIES:
<exact>

CURRENT FINISH CONCEPTS:
<exact / NONE>

CURRENT COLOR UTILITIES:
<exact / NONE>

CURRENT PROMPT VERSIONS:
<exact>

FINAL PREVIEW MODEL:
<exact>

CURRENT USAGE LIFECYCLE:
<exact>

HISTORY / SAVED LOOKS LINEAGE:
<exact>

VARIATION BEHAVIOR:
<exact>

STANDARD ISOLATION:
PASS / FAIL

MY MAKEUP KIT ISOLATION:
PASS / FAIL

TUTORIAL V4 LOCK:
PASS / FAIL

BOOKING SCOPE TOUCHED:
NO / FAIL

EXPECTED CCP FILE SURFACES:
<exact>

BLOCKERS:
NONE / <exact>

CCP-1:
READY / NOT READY

SOURCE CHANGES:
NONE

GEMINI CALLS:
0

PRODUCTION MUTATIONS:
0

REPORT
STOP
==================================================
```

---

# CCP-1 — PRODUCT / UX / CANONICAL PALETTE CONTRACT DESIGN

```text
======================================================================
FACETUNE
CCP-1 — PRODUCT / UX / CANONICAL PALETTE CONTRACT DESIGN
======================================================================

IMPLEMENT ONLY CCP-1.

MODE:
DESIGN / READ-ONLY

NO SOURCE CHANGES.
NO GEMINI CALLS.
NO PRODUCTION MUTATIONS.

PRECONDITION

CCP-0 accepted.

OBJECTIVE

Design the exact Custom Color Palette product contract before implementation.

TASKS

1. Define the third recommendation mode using the exact source-mode naming convention
   already used by the repository.

2. Define the mode-selection UX:
- Standard Recommendation
- My Makeup Kit
- Custom Color Palette

3. Define exact supported CCP categories based on repository evidence.
Do not invent categories.

4. Define category-aware finish taxonomy.
Examples may include matte, glossy, satin, shimmer, metallic, but approve only
combinations that are coherent and supported.

5. Define color selection UX:
- palette/color picker
- base color
- color adjuster
- final adjusted color
- review state

6. Decide what the color adjuster actually controls based on a deterministic model.
At minimum evaluate:
- lightness/value
- saturation
Do not add hue or opacity controls unless explicitly justified.

7. Define canonical palette logical schema.
At minimum evaluate:

palette_id
palette_version
source_mode
analysis_id
style_code
created_at
category_selections[]
  category_code
  base_color_value
  adjusted_color_value
  color_label
  finish_code
  adjustment_metadata
recommendation_contract_version
preview_prompt_version
validation_contract_version
tutorial_grounding_version

8. Define validation rules for:
- missing required selection
- malformed color
- unsupported category
- unsupported finish
- finish not applicable to category
- duplicate category

9. Define immutability rules.

10. Define edit/new-generation semantics.

11. Define Generate Another Variation semantics:
palette stays frozen unless user explicitly edits it.

12. Define behavior when user navigates backward or app resumes.

13. Define accessibility requirements for color selection:
- do not rely on color alone for selected state
- show readable label/value
- preserve contrast for controls

14. Define Standard/My Makeup Kit isolation proof requirements.

OUTPUT

Produce:
1. final UX flow
2. supported category matrix
3. category-to-finish matrix
4. color model decision
5. canonical palette contract
6. client state contract
7. validation contract
8. variation contract
9. implementation-surface map

FINAL REPORT

==================================================
CCP-1 CONTRACT DESIGN REPORT
==================================================

SOURCE MODE IDENTIFIER:
<exact proposed identifier>

UX FLOW:
<exact>

SUPPORTED CATEGORIES:
<exact>

CATEGORY / FINISH MATRIX:
<exact>

COLOR MODEL:
<exact>

COLOR ADJUSTER CONTRACT:
<exact>

CANONICAL PALETTE SCHEMA:
<exact>

CLIENT DRAFT STATE:
<exact>

VALIDATION RULES:
<exact>

VARIATION RULE:
<exact>

HISTORY RULE:
<exact>

STANDARD IMPACT:
NONE / FAIL

MY MAKEUP KIT IMPACT:
NONE / FAIL

BOOKING IMPACT:
NONE / FAIL

SCHEMA CHANGE EXPECTED:
YES / NO / UNKNOWN UNTIL CCP-2

RISKS:
<exact>

CCP-2:
READY / NOT READY

SOURCE CHANGES:
NONE

REPORT
STOP
==================================================
```

---

# CCP-2 — PERSISTENCE / SCHEMA / RLS / LINEAGE DESIGN

```text
======================================================================
FACETUNE
CCP-2 — PERSISTENCE / SCHEMA / RLS / LINEAGE DESIGN
======================================================================

IMPLEMENT ONLY CCP-2.

MODE:
DESIGN FIRST

NO GEMINI CALLS.
NO PRODUCTION MUTATIONS.
NO SCHEMA MUTATION UNTIL THE DESIGN PROVES IT IS REQUIRED AND THE PHASE IS
EXPLICITLY AUTHORIZED TO APPLY IT.

PRECONDITIONS

CCP-1 accepted.
Repository baseline still valid.

OBJECTIVE

Design the smallest durable persistence model that preserves one immutable
Custom Color Palette across recommendation, preview, Tutorial, History, Saved
Looks, and variations.

TASKS

1. Inspect existing recommendation/look tables and JSON contracts.

2. Determine whether existing tables can safely persist:
- palette_id
- palette_version
- immutable palette snapshot
- source_mode
- recommendation version
- preview version
- validator version
- accepted attempt number
- validation outcome

3. Prefer safe reuse if it does not create competing truth.

4. If reuse is unsafe, design minimal additive schema.

5. Define lineage:

analysis
↓
style
↓
custom palette
↓
recommendation
↓
preview candidate(s)
↓
accepted preview
↓
tutorial
↓
history / saved look

6. Define ownership/RLS for all new records.

7. Define service-role-only writes where required.

8. Define idempotency keys for:
- palette persistence
- recommendation generation
- preview generation
- validation
- accepted preview persistence
- usage commit

9. Cover concurrency:
- double tap
- network retry
- app resume
- duplicate Edge invocation
- provider timeout
- replay after partial success

10. Define historical preservation.

11. Define migration and rollback-safe strategy if schema change is required.

12. Define pgTAP/RLS tests if SQL changes are required.

FINAL REPORT

==================================================
CCP-2 PERSISTENCE DESIGN REPORT
==================================================

EXISTING TABLES REUSABLE:
YES / NO / PARTIAL

SCHEMA CHANGE REQUIRED:
YES / NO

PROPOSED SCHEMA:
<exact / NONE>

PALETTE SNAPSHOT STORAGE:
<exact>

LINEAGE:
<exact>

HISTORY / SAVED LOOKS LINKAGE:
<exact>

VARIATION LINKAGE:
<exact>

IDEMPOTENCY:
<exact>

CONCURRENCY:
<exact>

RLS IMPACT:
NONE / <exact>

MIGRATION PLAN:
NONE / <exact>

PGTAP PLAN:
<exact / NOT APPLICABLE>

STANDARD IMPACT:
NONE / FAIL

MY MAKEUP KIT IMPACT:
NONE / FAIL

SOURCE CHANGES:
NONE unless an explicitly authorized migration sub-step was granted

PRODUCTION MUTATIONS:
0

CCP-3:
READY / NOT READY

REPORT
STOP
==================================================
```

---

# CCP-3 — FLUTTER MODE ENTRY / PALETTE EDITOR / CLIENT STATE

```text
======================================================================
FACETUNE
CCP-3 — FLUTTER MODE ENTRY / PALETTE EDITOR / CLIENT STATE
======================================================================

IMPLEMENT ONLY CCP-3.

NO REAL GEMINI CALLS.
NO PRODUCTION MUTATIONS.

PRECONDITIONS

CCP-1 accepted.
CCP-2 accepted.
Repository baseline clean/authorized.

OBJECTIVE

Implement the additive Flutter user experience and deterministic client-side
palette draft state without changing existing mode behavior.

REQUIREMENTS

1. Add Custom Color Palette to the recommendation-mode selection surface.

2. Do not redesign Standard Recommendation or My Makeup Kit cards/behavior except
   the minimum additive layout change required to present a third option.

3. Implement dedicated Custom Color Palette screen.

4. For every approved category expose:
- color selection control
- color adjustment control
- applicable finish selection

5. Show final selected color clearly using:
- visual swatch
- accessible text label/value
- selected finish

6. Block Generate until the CCP-1 validation contract passes.

7. Preserve a single deterministic draft state using current Riverpod patterns.

8. Implement back/edit behavior defined in CCP-1.

9. Implement app resume/state restoration only according to existing architecture.

10. Do not persist server truth from Flutter directly if server contract requires
    authenticated server processing.

11. Add tests for:
- mode appears
- existing modes unchanged
- supported categories rendered
- finish filtering by category
- valid color adjustment
- invalid state blocked
- edit state preserved
- generate action emits canonical draft payload
- no Booking UI introduced

12. Run formatting/analyze/targeted tests.

FINAL REPORT

==================================================
CCP-3 FLUTTER UI/STATE REPORT
==================================================

FILES MODIFIED:
<exact>

MODE ENTRY:
PASS / FAIL

PALETTE SCREEN:
PASS / FAIL

COLOR PICKER:
PASS / FAIL

COLOR ADJUSTER:
PASS / FAIL

FINISH SELECTION:
PASS / FAIL

CATEGORY-AWARE FINISH FILTERING:
PASS / FAIL

CLIENT STATE:
PASS / FAIL

VALIDATION:
PASS / FAIL

STANDARD MODE REGRESSION:
PASS / FAIL

MY MAKEUP KIT REGRESSION:
PASS / FAIL

BOOKING SCOPE:
UNTOUCHED / FAIL

FLUTTER ANALYZE:
<exact>

TESTS:
<exact>

git diff --check:
PASS / FAIL

REAL GEMINI CALLS:
0

PRODUCTION MUTATIONS:
0

CCP-4:
READY / NOT READY

REPORT
STOP
==================================================
```

---

# CCP-4 — SERVER-SIDE CUSTOM PALETTE RECOMMENDATION CONTRACT

```text
======================================================================
FACETUNE
CCP-4 — SERVER-SIDE CUSTOM PALETTE RECOMMENDATION CONTRACT
======================================================================

IMPLEMENT ONLY CCP-4.

NO REAL GEMINI CALLS.
NO PRODUCTION MUTATIONS.

PRECONDITIONS

CCP-1 accepted.
CCP-2 accepted.
CCP-3 accepted.

OBJECTIVE

Implement additive server-side Custom Color Palette recommendation generation
where user-selected colors/finishes are authoritative and AI cannot re-select a
different palette.

RECOMMENDED ADDITIVE IDENTIFIER

custom_palette_recommendation_v1

Exact identifier must follow repository conventions.

RULES

1. Authenticate user server-side.

2. Validate canonical palette contract server-side.

3. Treat palette values as data, not prompt instructions.

4. Recommendation must preserve:
- selected categories
- adjusted colors
- selected finishes

5. AI may generate:
- placement guidance
- blending guidance
- application technique
- explanatory text

6. AI must not generate authoritative replacement palette values.

7. If structured AI output includes conflicting colors/finishes:
- reject/normalize according to approved contract
- never overwrite canonical palette truth

8. Persist recommendation lineage according to CCP-2.

9. Do not modify Standard or My Makeup Kit recommendation prompts.

10. Add deterministic tests for:
- source mode routing
- valid palette accepted
- invalid category rejected
- invalid finish rejected
- user color preserved
- user finish preserved
- AI conflicting color cannot override truth
- prompt injection resistance
- authenticated ownership
- Standard routing unchanged
- My Makeup Kit routing unchanged

FINAL REPORT

==================================================
CCP-4 RECOMMENDATION REPORT
==================================================

VERSION:
<exact>

FILES MODIFIED:
<exact>

SERVER VALIDATION:
PASS / FAIL

USER COLOR AUTHORITY:
PASS / FAIL

USER FINISH AUTHORITY:
PASS / FAIL

AI REPLACEMENT BLOCKED:
PASS / FAIL

PERSISTED LINEAGE:
PASS / FAIL

STANDARD MODIFIED:
NO / FAIL

MY MAKEUP KIT MODIFIED:
NO / FAIL

RLS CHANGE:
<exact / NONE>

TESTS:
<exact>

DENO:
<exact>

REAL GEMINI CALLS:
0

PRODUCTION MUTATIONS:
0

git diff --check:
PASS / FAIL

CCP-5:
READY / NOT READY

REPORT
STOP
==================================================
```

---

# CCP-5 — PALETTE-CONSTRAINED FINAL PREVIEW + VALIDATOR

```text
======================================================================
FACETUNE
CCP-5 — PALETTE-CONSTRAINED FINAL PREVIEW + VALIDATOR
======================================================================

IMPLEMENT ONLY CCP-5.

NO REAL GEMINI CALLS.
NO PRODUCTION MUTATIONS.

PRECONDITIONS

CCP-4 accepted.
Current Final Preview model/routing audited and protected.

OBJECTIVE

Implement additive Custom Color Palette preview generation and a fail-closed
palette-faithfulness validation contract before an image is accepted as a CCP
Final Makeup Preview.

RECOMMENDED ADDITIVE IDENTIFIERS

custom_palette_preview_v1
custom_palette_validator_v1

Exact identifiers must follow repository conventions.

MODEL LOCK

Use the current authoritative protected Final Preview model from repository.
Do not change it in CCP.

PREVIEW CONTRACT

1. Input includes frozen palette.

2. Prompt must explicitly preserve:
- selected category
- adjusted color
- selected finish
- identity/image safety constraints

3. Prompt must not independently select another palette.

4. Do not introduce live AR behavior.

VALIDATOR CONTRACT

Evaluate original selfie + frozen palette + candidate preview.

At minimum return structured fields for:

outcome
mismatch_categories
color_mismatch_reasons
finish_mismatch_reasons
uncertain_categories
validator_version

Allowed outcomes:

accepted
retryable_palette_mismatch
nonretryable_palette_mismatch
validator_failure
provider_failure

VALIDATION PRINCIPLES

- fail closed
- no arbitrary unevaluated numeric threshold
- do not claim exact colorimetry if provider/image pipeline cannot support it
- distinguish material mismatch from normal rendering variation
- finish validation only where visually judgeable
- malformed validator output never silently accepts

TESTS

- exact palette forwarded to prompt
- selected colors cannot be replaced in prompt contract
- category-aware finishes forwarded
- malformed palette rejected
- mocked faithful result accepted
- mocked materially wrong color rejected/retryable
- mocked wrong finish handled
- validator failure fails closed
- failed candidate cannot persist as accepted
- Standard preview unchanged
- My Makeup Kit preview unchanged

FINAL REPORT

==================================================
CCP-5 PREVIEW + VALIDATOR REPORT
==================================================

PREVIEW VERSION:
<exact>

VALIDATOR VERSION:
<exact>

MODEL:
<exact protected model>

FILES MODIFIED:
<exact>

FROZEN PALETTE INPUT:
PASS / FAIL

COLOR CONSTRAINT:
PASS / FAIL

FINISH CONSTRAINT:
PASS / FAIL

FAIL-CLOSED VALIDATOR:
PASS / FAIL

FAILED CANDIDATE ACCEPTANCE:
BLOCKED / FAIL

STANDARD PREVIEW:
UNCHANGED / FAIL

MY MAKEUP KIT PREVIEW:
UNCHANGED / FAIL

TESTS:
<exact>

REAL GEMINI CALLS:
0

PRODUCTION MUTATIONS:
0

git diff --check:
PASS / FAIL

CCP-6:
READY / NOT READY

REPORT
STOP
==================================================
```

---

# CCP-6 — BOUNDED RETRY / IDEMPOTENCY / USAGE INTEGRATION

```text
======================================================================
FACETUNE
CCP-6 — BOUNDED RETRY / IDEMPOTENCY / USAGE INTEGRATION
======================================================================

IMPLEMENT ONLY CCP-6.

NO REAL GEMINI CALLS.
NO PRODUCTION MUTATIONS.

OBJECTIVE

Integrate palette mismatch handling with existing usage accounting so internal
correction never changes the user's palette and never double-charges one logical
preview request.

TASKS

1. Inspect current retry/accounting orchestration.

2. Define/implement a bounded retry policy compatible with current architecture.

3. If repository already has an approved retry bound, reuse it.

4. If changing the retry bound is required:
STOP and report before changing policy.

5. Every retry must reuse:
- same palette_id
- same palette_version
- same adjusted colors
- same finishes
- same logical usage reservation

6. Retry may tighten instructions using mismatch evidence.

7. Retry may not mutate palette truth.

8. Prove idempotency under:
- double tap
- app retry
- duplicate Edge invocation
- duplicate provider completion
- network timeout

9. Accounting tests:
- accepted first attempt → one user commit
- accepted later attempt → one user commit
- terminal failure → correct release/failure state
- duplicate completion → no duplicate commit

10. Failed candidates remain excluded from History/Saved Looks/Tutorial.

FINAL REPORT

==================================================
CCP-6 RETRY / ACCOUNTING REPORT
==================================================

MAX ATTEMPTS:
<exact current/approved bound>

PALETTE IMMUTABLE ACROSS RETRIES:
PASS / FAIL

ONE LOGICAL RESERVATION:
PASS / FAIL

USER ENTITLEMENT COMMITS:
ONE / FAIL

FAILED CANDIDATES EXCLUDED:
PASS / FAIL

IDEMPOTENCY:
PASS / FAIL

CONCURRENCY:
PASS / FAIL

USAGE RELEASE:
PASS / FAIL

FILES MODIFIED:
<exact>

TESTS:
<exact>

REAL GEMINI CALLS:
0

PRODUCTION MUTATIONS:
0

STANDARD ACCOUNTING:
UNCHANGED / FAIL

MY MAKEUP KIT ACCOUNTING:
UNCHANGED / FAIL

CCP-7:
READY / NOT READY

REPORT
STOP
==================================================
```

---

# CCP-7 — TUTORIAL / HISTORY / SAVED LOOKS / VARIATION LINEAGE

```text
======================================================================
FACETUNE
CCP-7 — TUTORIAL / HISTORY / SAVED LOOKS / VARIATION LINEAGE
======================================================================

IMPLEMENT ONLY CCP-7.

NO REAL GEMINI CALLS.
NO PRODUCTION MUTATIONS.

OBJECTIVE

Carry one accepted Custom Color Palette lineage through Tutorial, History, Saved
Looks, and Generate Another Variation without modifying protected behavior for
other modes.

TUTORIAL

1. Reuse existing Tutorial V4 architecture where possible.

2. Do not overwrite:
- tutorial_manifest_v4_1
- tutorial_guideline_v4_7

3. CCP Tutorial grounding must receive:
- accepted preview
- frozen palette
- selected categories
- adjusted colors
- finishes

4. Tutorial may generate technique/application guidance but may not replace the palette.

HISTORY / SAVED LOOKS

5. Persist/retrieve source mode and palette lineage.

6. Opening a historical CCP look must show the palette that created it.

7. Current UI defaults must never overwrite historical palette truth.

VARIATION

8. Generate Another Variation must reuse the same frozen palette by default.

9. If user edits the palette, create a new palette draft/logical generation.

10. Do not mutate the old accepted look.

TESTS

- Tutorial receives palette lineage
- Tutorial colors/finishes remain constrained
- History restores palette
- Saved Look restores palette
- variation preserves palette
- edit creates new logical palette
- Standard Tutorial unchanged
- My Makeup Kit Tutorial unchanged
- historical Standard/Kit records unchanged

FINAL REPORT

==================================================
CCP-7 LINEAGE INTEGRATION REPORT
==================================================

TUTORIAL BRIDGE:
<exact>

TUTORIAL V4_1 MODIFIED:
NO / FAIL

GUIDELINE V4_7 MODIFIED:
NO / FAIL

HISTORY PALETTE RESTORE:
PASS / FAIL

SAVED LOOK PALETTE RESTORE:
PASS / FAIL

VARIATION PALETTE LOCK:
PASS / FAIL

EDIT CREATES NEW LOGICAL PALETTE:
PASS / FAIL

STANDARD MODE:
UNCHANGED / FAIL

MY MAKEUP KIT:
UNCHANGED / FAIL

FILES MODIFIED:
<exact>

TESTS:
<exact>

REAL GEMINI CALLS:
0

PRODUCTION MUTATIONS:
0

CCP-8:
READY / NOT READY

REPORT
STOP
==================================================
```

---

# CCP-8 — AUTOMATED REGRESSION / SECURITY / ACCOUNTING VALIDATION

```text
======================================================================
FACETUNE
CCP-8 — AUTOMATED REGRESSION / SECURITY / ACCOUNTING VALIDATION
======================================================================

IMPLEMENT ONLY CCP-8.

MODE:
VALIDATION / FIX ONLY CCP DEFECTS DISCOVERED BY THIS PHASE

NO REAL GEMINI CALLS.
NO PRODUCTION MUTATIONS.

OBJECTIVE

Prove structural safety before controlled live AI evaluation.

TEST MATRIX

Include:
- every approved CCP category
- every approved category/finish combination
- light/dark adjusted colors
- high/low saturation within allowed control range
- multi-category palettes
- invalid finish/category combination
- invalid color payload
- duplicate category payload
- Standard mode regression
- My Makeup Kit regression
- History/Saved Looks
- Generate Another Variation
- Tutorial
- subscription/usage lifecycle
- double tap / network retry

SECURITY

Verify:
- server-side Gemini only
- authenticated ownership
- RLS
- no secrets in client
- no cross-user palette access
- prompt injection resistance
- no private-image logs

RUN AS APPLICABLE

- targeted Flutter/Dart tests
- full Flutter test suite
- flutter analyze
- dart format check
- Deno tests
- pgTAP if SQL changed
- RLS tests
- secret scan
- git diff --check
- production Android build validation if appropriate

Known unrelated baseline failures must be classified separately, never hidden.

FINAL REPORT

==================================================
CCP-8 AUTOMATED VALIDATION REPORT
==================================================

CCP CONTRACT:
PASS / FAIL

COLOR AUTHORITY:
PASS / FAIL

FINISH AUTHORITY:
PASS / FAIL

PREVIEW CONSTRAINT:
PASS / FAIL

VALIDATOR:
PASS / FAIL

RETRY / IDEMPOTENCY:
PASS / FAIL

ONE-COMMIT ACCOUNTING:
PASS / FAIL

TUTORIAL LINEAGE:
PASS / FAIL

HISTORY / SAVED LOOKS:
PASS / FAIL

VARIATION:
PASS / FAIL

STANDARD MODE:
PASS / FAIL

MY MAKEUP KIT:
PASS / FAIL

RLS / SECURITY:
PASS / FAIL

FLUTTER ANALYZE:
<exact>

FLUTTER TEST:
<exact>

DENO:
<exact>

PGTAP:
<exact / NOT APPLICABLE>

SECRET SCAN:
<exact>

BUILD:
<exact / NOT RUN>

git diff --check:
PASS / FAIL

CCP-9:
READY / NOT READY

REPORT
STOP
==================================================
```

---

# CCP-9 — CONTROLLED AI EVALUATION PLAN

```text
======================================================================
FACETUNE
CCP-9 — CONTROLLED AI EVALUATION PLAN
======================================================================

IMPLEMENT ONLY CCP-9.

MODE:
READ-ONLY PLANNING

NO GEMINI CALLS.
NO PRODUCTION MUTATIONS.
NO SOURCE CHANGES unless needed only to create an explicitly authorized local
non-production evaluation harness; if harness creation is not authorized, report
its design only.

OBJECTIVE

Design a controlled evaluation that measures whether Gemini respects the user's
Custom Color Palette before any live evaluation begins.

PLAN MUST DEFINE

1. Test selfies approved for non-production evaluation.

2. Style coverage based on actual supported styles.

3. Category coverage.

4. Color coverage:
- clearly distinct colors
- lighter/darker adjustments
- saturation adjustments

5. Finish coverage where visually judgeable.

6. Multi-category combinations such as:
- red lips + orange blush + violet eyeliner + gold eyeshadow
Only use categories/finishes confirmed by CCP-1.

7. Metrics:
- recommendation palette fidelity
- first-attempt preview acceptance
- acceptance within retry bound
- category mismatch rate
- material color mismatch rate
- finish contradiction rate where judgeable
- terminal failure rate
- usage accounting correctness
- Tutorial lineage correctness

8. Define evidence-based pass/fail gates.
Do not invent arbitrary numeric thresholds without rationale.

9. Define maximum provider-call budget.

10. Define stop-loss conditions.

11. Define no-production-mutation controls.

FINAL REPORT

==================================================
CCP-9 CONTROLLED AI EVALUATION PLAN
==================================================

TEST CASE COUNT:
<exact>

SELFIES:
<exact>

STYLE MATRIX:
<exact>

CATEGORY MATRIX:
<exact>

COLOR MATRIX:
<exact>

FINISH MATRIX:
<exact>

METRICS:
<exact>

PASS GATES:
<exact>

PROVIDER CALL CEILING:
<exact>

STOP-LOSS:
<exact>

PRODUCTION MUTATIONS:
0

REAL GEMINI CALLS:
0

CCP-10:
READY / NOT READY

REPORT
STOP
==================================================
```

---

# CCP-10 — CONTROLLED LIVE AI EVALUATION

```text
======================================================================
FACETUNE
CCP-10 — CONTROLLED LIVE AI EVALUATION
======================================================================

IMPLEMENT ONLY CCP-10.

MODE:
CONTROLLED LIVE EVALUATION

REAL GEMINI CALLS:
AUTHORIZED ONLY WITHIN THE ACCEPTED CCP-9 PLAN AND CALL CEILING.

NO PRODUCTION USER MUTATION.
NO DEPLOYMENT.

PRECONDITIONS

CCP-8 PASS.
CCP-9 accepted.
Required credentials/environment confirmed safe for controlled evaluation.

OBJECTIVE

Measure real provider behavior against the approved Custom Color Palette contract.

RULES

1. Run only accepted CCP-9 cases.

2. Never exceed provider-call ceiling.

3. Record each attempt with non-sensitive identifiers.

4. Confirm recommendation preserves selected palette.

5. Confirm preview follows selected colors materially.

6. Confirm selected finishes are not contradicted where visually judgeable.

7. Confirm retry preserves palette.

8. Confirm one logical request never creates multiple user-facing charges.

9. Stop immediately on:
- unexpected production mutation
- secret exposure
- repeated severe palette replacement
- accounting anomaly
- protected-mode regression
- call ceiling reached

10. Do not tune prompts during the same evaluation run.
Report evidence first.

FINAL REPORT

==================================================
CCP-10 LIVE AI EVALUATION REPORT
==================================================

REQUESTS EXECUTED:
<exact>

PROVIDER CALLS:
<exact>

RECOMMENDATION PALETTE FIDELITY:
<evidence>

FIRST-ATTEMPT PREVIEW ACCEPTANCE:
<evidence>

ACCEPTANCE WITHIN RETRY BOUND:
<evidence>

COLOR MISMATCHES:
<exact>

FINISH CONTRADICTIONS:
<exact / NOT JUDGEABLE cases separated>

TERMINAL FAILURES:
<exact>

ACCOUNTING:
PASS / FAIL

STANDARD MODE IMPACT:
NONE / FAIL

MY MAKEUP KIT IMPACT:
NONE / FAIL

PRODUCTION MUTATIONS:
0 / FAIL

BLOCKERS:
NONE / <exact>

CCP-11:
READY / NOT READY

REPORT
STOP
==================================================
```

---

# CCP-11 — REAL-DEVICE / E2E / UX / FAILURE-STATE QA

```text
======================================================================
FACETUNE
CCP-11 — REAL-DEVICE / E2E / UX / FAILURE-STATE QA
======================================================================

IMPLEMENT ONLY CCP-11.

OBJECTIVE

Validate the complete Custom Color Palette experience on a real device or approved
realistic device environment from mode selection through historical retrieval.

REQUIRED JOURNEYS

1. Facial Analysis → Style → Custom Color Palette.

2. Configure multiple categories.

3. Pick colors.

4. Adjust colors.

5. Select valid finishes.

6. Review palette.

7. Generate recommendation.

8. Generate Final Makeup Preview.

9. Open Step-by-Step Tutorial.

10. Save/Favorite.

11. Open History/Saved Look and verify palette restoration.

12. Generate Another Variation and verify palette remains fixed.

13. Edit palette and verify new logical generation rather than historical mutation.

FAILURE UX

Verify:
- network loss
- provider failure
- validator failure
- terminal palette mismatch
- invalid draft
- expired/insufficient entitlement where applicable
- app resume
- double tap

UX CHECKS

- no confusing overlap with My Makeup Kit
- no claim that AI may replace user choices
- selected state readable without relying on color alone
- finish choices understandable
- back navigation predictable
- no hidden Booking UI

FINAL REPORT

==================================================
CCP-11 REAL-DEVICE / E2E REPORT
==================================================

DEVICE / ENVIRONMENT:
<exact>

CORE JOURNEY:
PASS / FAIL

COLOR PICKER UX:
PASS / FAIL

COLOR ADJUSTER UX:
PASS / FAIL

FINISH UX:
PASS / FAIL

PREVIEW FIDELITY:
PASS / FAIL

TUTORIAL LINEAGE:
PASS / FAIL

HISTORY RESTORE:
PASS / FAIL

SAVED LOOK RESTORE:
PASS / FAIL

VARIATION LOCK:
PASS / FAIL

FAILURE UX:
PASS / FAIL

STANDARD REGRESSION:
PASS / FAIL

MY MAKEUP KIT REGRESSION:
PASS / FAIL

BOOKING SCOPE:
UNTOUCHED / FAIL

BLOCKERS:
NONE / <exact>

CCP-12:
READY / NOT READY

REPORT
STOP
==================================================
```

---

# CCP-12 — PRODUCTION-READINESS / CHECKPOINT REVIEW

```text
======================================================================
FACETUNE
CCP-12 — PRODUCTION-READINESS / CHECKPOINT REVIEW
======================================================================

IMPLEMENT ONLY CCP-12.

MODE:
REVIEW / CHECKPOINT READINESS

NO NEW FEATURE WORK.
NO DEPLOYMENT UNLESS SEPARATELY AUTHORIZED.
NO COMMIT/PUSH UNLESS EXPLICITLY AUTHORIZED.

OBJECTIVE

Determine whether Custom Color Palette is complete, isolated, secure, tested, and
ready for an authorized checkpoint/release decision.

REVIEW

1. Re-read Source of Truth and accepted phase reports.

2. Record final branch/HEAD/status/diff.

3. Confirm definition of done item by item.

4. Confirm no Standard behavior changed.

5. Confirm no My Makeup Kit behavior changed.

6. Confirm Tutorial V4 protected contracts remain intact.

7. Confirm subscription/accounting unchanged except authorized CCP integration.

8. Confirm historical content untouched.

9. Confirm RLS/security/privacy.

10. Confirm live evaluation evidence.

11. Confirm real-device evidence.

12. Confirm no Booking/Revision 2 changes included.

13. List every modified file and migration.

14. List every known residual risk.

15. State whether checkpoint is ready.

FINAL REPORT

==================================================
CCP-12 PRODUCTION-READINESS REPORT
==================================================

BRANCH:
<exact>

HEAD:
<exact>

WORKING TREE:
<exact>

DEFINITION OF DONE:
PASS / FAIL

STANDARD MODE:
UNCHANGED / FAIL

MY MAKEUP KIT:
UNCHANGED / FAIL

TUTORIAL V4:
PROTECTED / FAIL

FINAL PREVIEW MODEL:
UNCHANGED / FAIL

SUBSCRIPTION / ACCOUNTING:
PASS / FAIL

RLS / SECURITY / PRIVACY:
PASS / FAIL

HISTORICAL CONTENT:
UNCHANGED / FAIL

CONTROLLED AI EVALUATION:
PASS / FAIL

REAL-DEVICE QA:
PASS / FAIL

BOOKING / REVISION 2:
NOT INCLUDED / FAIL

FILES MODIFIED:
<exact>

MIGRATIONS:
<exact / NONE>

RESIDUAL RISKS:
<exact / NONE>

CHECKPOINT READY:
YES / NO

AUTHORIZED NEXT ACTION:
NONE — WAIT FOR EXPLICIT USER AUTHORIZATION

REPORT
STOP
==================================================
```

---

# EXECUTION ORDER SUMMARY

```text
CCP-0   Baseline / authority audit
CCP-1   Product / UX / canonical palette contract
CCP-2   Persistence / schema / RLS / lineage design
CCP-3   Flutter mode entry + palette editor + client state
CCP-4   Server-side recommendation contract
CCP-5   Palette-constrained preview + validator
CCP-6   Retry / idempotency / usage integration
CCP-7   Tutorial / History / Saved Looks / Variation lineage
CCP-8   Automated regression / security / accounting
CCP-9   Controlled AI evaluation plan
CCP-10  Controlled live AI evaluation
CCP-11  Real-device / E2E / UX / failure QA
CCP-12  Production-readiness / checkpoint review
```

Hard rule:

> **Run exactly one phase. Read its report. Decide whether to authorize the next phase. Never let Claude, Codex, or another coding agent auto-continue.**
