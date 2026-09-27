# FaceTune Beauty
# Plan-Driven My Makeup Kit Pipeline
## Strict Phase Prompts
### Version 1.0.0

Canonical companion:

`FACETUNE_PLAN_DRIVEN_MAKEUP_KIT_SOURCE_OF_TRUTH.md`

Execute exactly one phase at a time.

No phase authorizes the next phase automatically.

Every phase must end with:

```text
REPORT
STOP
```

---

# GLOBAL EXECUTION CONTRACT

Apply this block to every phase.

```text
======================================================================
FACETUNE — PDMK GLOBAL EXECUTION CONTRACT
======================================================================

You are implementing the Plan-Driven My Makeup Kit track for FaceTune Beauty.

MANDATORY ROLES

Act simultaneously as:

- Principal Software Architect
- Staff Software Engineer
- Principal Flutter Engineer
- Senior Flutter / Dart Developer
- Senior Riverpod Engineer
- Senior Android Engineer
- Senior Mobile Engineer
- Senior Backend Engineer
- Senior Supabase Engineer
- Senior PostgreSQL Engineer
- Senior RLS / Data-Security Engineer
- Senior AI Systems Engineer
- Senior Generative-AI Engineer
- Senior Prompt Engineer
- Senior AI Evaluation Engineer
- Senior ML Quality Engineer
- Senior Computer-Vision Evaluation Engineer
- Senior Reliability Engineer
- Senior Distributed-Systems Engineer
- Senior Application Security Engineer
- Senior Privacy Engineer
- Senior QA Automation Engineer
- Senior Integration-Test Engineer
- Senior E2E / Device-Test Engineer
- Senior Release Engineer
- Senior Production-Debugging Engineer
- Senior Code Reviewer
- Senior Product Engineer
- Makeup Workflow Domain Reviewer

AUTHORITY

Read and obey higher authorities before editing.

At minimum:

- CODEX_MASTER_GUIDE.md
- current protected FaceTune contracts
- subscription source-of-truth documents
- Tutorial V4 protected contracts
- FACETUNE_PLAN_DRIVEN_MAKEUP_KIT_SOURCE_OF_TRUTH.md
- FACETUNE_PLAN_DRIVEN_MAKEUP_KIT_PHASE_PROMPTS.md

If authority conflicts:
STOP and report.

HARD LOCKS

DO NOT modify unless the current phase explicitly authorizes a new
My Makeup Kit-only additive version:

- Standard Mode recommendation
- Standard Mode Final Preview
- Standard Mode Tutorial
- tutorial_guideline_v4_7
- tutorial_manifest_v4_1
- kit_preview_mismatch semantics
- look-specific product-backing semantics
- historical content
- Final Preview model gemini-3.1-flash-image
- RLS security model
- client/server trust boundary
- server-side-only Gemini
- reservation-time usage attribution
- server-authoritative subscription state
- SUB-10 verify → activate → acknowledge
- SUB-11 RTDN / lifecycle / Restore

DO NOT:

- use the current live kit as proof a product was used
- persist a failed preview as accepted
- charge multiple user entitlements for internal retries
- expose secrets
- call Gemini from Flutter
- silently rewrite historical prompt versions
- run destructive Git commands
- commit, push, merge, rebase, reset, clean, or stash unless explicitly
  authorized by the current phase
- deploy unless explicitly authorized
- auto-start another phase

GIT

Before editing:
- record branch
- record HEAD
- record status
- run git diff --check where applicable

If the working tree contains unexpected changes:
STOP.

AI CALLS

No real Gemini/provider calls unless the phase explicitly authorizes them.

No production mutation unless the phase explicitly authorizes it.

If a phase is design/read-only:
make ZERO source changes.

STOP CONDITIONS

Stop immediately if:
- Standard Mode must change to complete the phase
- Tutorial safety must be weakened
- historical content must be rewritten
- accounting would double-charge a logical user request
- required authority is missing
- repository baseline is ambiguous
- schema change is needed outside an authorized schema phase
- a planned hypothesis is contradicted by evidence

Never force a PASS.
======================================================================
```

---

# PDMK-0 — BASELINE / AUTHORITY / CHECKPOINT GATE

```text
======================================================================
FACETUNE
PDMK-0 — BASELINE / AUTHORITY / CHECKPOINT GATE
======================================================================

IMPLEMENT ONLY PDMK-0.

MODE:
READ-ONLY

NO SOURCE CHANGES.
NO GEMINI CALLS.
NO PRODUCTION MUTATIONS.
NO COMMIT.
NO PUSH.

OBJECTIVE

Establish the exact repository and protected-system baseline before any
plan-driven architecture work begins.

TASKS

1. Read all required authorities.

2. Record:

git branch --show-current
git rev-parse HEAD
git status --short
git status --branch
git branch -vv
git diff --check

3. Confirm known protected checkpoint:

00090928daecdbcce7fbe37451710c3f21ea01ea

4. Confirm backup branch:

backup/wa15-complete-20260927

5. Inspect the current status of:

fix/my-makeup-kit-preview-lineage

Classify:

A. absent
B. uncommitted
C. committed locally
D. committed and pushed

6. Inventory current My Makeup Kit pipeline:

- analysis input
- style input
- recommendation generation
- recommendation persistence
- product_snapshot_json
- preview generation
- preview validation
- preview persistence
- Tutorial manifest
- Tutorial steps
- usage reservation
- usage commit/release
- History
- Saved Looks

7. Locate exact current versions/routing for:

kit_makeup_recommendation_v2
kit_makeup_preview_v1
tutorial_manifest_v4_1
tutorial_guideline_v4_7

8. Confirm Standard Mode uses isolated routing.

9. Identify all current retry behavior.

10. Identify whether current preview validation is structural only, visual only,
both, or neither.

FINAL REPORT

==================================================
PDMK-0 BASELINE REPORT
==================================================

BRANCH:
<exact>

HEAD:
<exact>

WORKING TREE:
<exact>

WA-15 CHECKPOINT:
PASS / FAIL

WA-15 BACKUP:
PASS / FAIL

PREVIEW-LINEAGE FIX STATE:
A / B / C / D

CURRENT PIPELINE:
<exact concise map>

CURRENT PROMPT VERSIONS:
<exact>

CURRENT PREVIEW VALIDATION:
<exact>

CURRENT RETRY BEHAVIOR:
<exact>

CURRENT USAGE LIFECYCLE:
<exact>

STANDARD MODE ISOLATION:
PASS / FAIL

TUTORIAL V4 LOCK:
PASS / FAIL

HISTORICAL VERSIONING:
PASS / FAIL / UNKNOWN

BLOCKERS:
NONE / <exact>

PDMK-1:
READY / NOT READY

SOURCE CHANGES:
NONE

GEMINI CALLS:
0

PRODUCTION MUTATIONS:
0

STOP.
==================================================
```

---

# PDMK-1 — CANONICAL MAKEUP PLAN ARCHITECTURE & CONTRACT

```text
======================================================================
FACETUNE
PDMK-1 — CANONICAL MAKEUP PLAN ARCHITECTURE & CONTRACT
======================================================================

IMPLEMENT ONLY PDMK-1.

MODE:
DESIGN / READ-ONLY

NO SOURCE CHANGES.
NO GEMINI CALLS.
NO PRODUCTION MUTATIONS.

OBJECTIVE

Design one authoritative canonical makeup plan for new My Makeup Kit looks.

The plan must remove independent disagreement between recommendation, snapshot,
preview instructions, validation, and Tutorial grounding.

DESIGN THE LOGICAL CONTRACT

At minimum determine exact fields for:

plan_id
plan_version
source_mode
analysis_id
style_code
created_at
selected_items[]
allowed_visual_categories[]
forbidden_visual_categories[]
recommendation_prompt_version
preview_prompt_version
validation_contract_version

For each selected item define exact contract for:

category_code
tutorial_category
product_id
product_snapshot
intended_role
visible_intent
application_intent

Define allowed values for visible_intent.

REQUIRED PLAN INVARIANTS

- source_mode must be my_makeup_kit
- every selected product is owned and eligible
- no duplicate invalid category assignment
- selected product/category identity is immutable for one logical generation
- recommendation is derived from the plan
- snapshot is derived from the plan
- preview instructions are derived from the plan
- validation is evaluated against the plan
- Tutorial grounding references the plan/snapshot
- retries reuse the same plan
- historical looks are not backfilled automatically

STYLE LOGIC

Design how the plan should reason about:

Soft Glam
Party
Date Night
Bridal
Full Glam

and controls:

Natural
Everyday
Office

Do not hard-code "all glam = foundation + concealer."

Define style-aware principles rather than simplistic style-name switches.

OUTPUT

Produce:

1. canonical logical schema
2. invariants
3. category mapping rules
4. plan-generation decision rules
5. compatibility assessment with current code
6. exact expected implementation surfaces

DO NOT IMPLEMENT.

FINAL REPORT

==================================================
PDMK-1 CANONICAL PLAN DESIGN REPORT
==================================================

PLAN VERSION:
<proposed exact identifier>

CANONICAL PLAN SCHEMA:
<exact>

SELECTED ITEM SCHEMA:
<exact>

CATEGORY MAPPING:
<exact>

VISIBLE INTENT VALUES:
<exact>

STYLE-AWARE COMPLEXION RULE:
<exact>

LIGHTER-STYLE RULE:
<exact>

PLAN INVARIANTS:
<exact>

RETRY PLAN IMMUTABILITY:
<exact>

RECOMMENDATION DERIVATION:
<exact>

SNAPSHOT DERIVATION:
<exact>

PREVIEW DERIVATION:
<exact>

TUTORIAL GROUNDING:
<exact>

STANDARD MODE IMPACT:
NONE / FAIL

DATABASE PERSISTENCE NEEDED:
YES / NO / TO BE DECIDED IN PDMK-2

EXPECTED FILE SURFACES:
<exact>

RISKS:
<exact>

PDMK-2:
READY / NOT READY

SOURCE CHANGES:
NONE

STOP.
==================================================
```

---

# PDMK-2 — PERSISTENCE / SCHEMA / LINEAGE DESIGN

```text
======================================================================
FACETUNE
PDMK-2 — PERSISTENCE / SCHEMA / LINEAGE DESIGN
======================================================================

IMPLEMENT ONLY PDMK-2.

MODE:
DESIGN FIRST.
NO SCHEMA MUTATION UNTIL THE DESIGN REPORT PROVES IT IS REQUIRED.

NO GEMINI CALLS.
NO PRODUCTION MUTATIONS.

OBJECTIVE

Determine the smallest durable persistence model needed for canonical-plan
lineage and validation evidence.

INVESTIGATE FIRST

Can existing recommendation/preview records safely persist:

- plan_id
- plan_version
- immutable plan JSON
- validator version
- accepted attempt number
- validation outcome
- mismatch categories

without creating competing truth?

If YES:
prefer minimal reuse.

If NO:
design a minimal additive schema.

REQUIRED LINEAGE

analysis
↓
style
↓
canonical plan
↓
recommendation / snapshot
↓
candidate attempts
↓
accepted preview
↓
validation evidence
↓
Tutorial readiness / manifest

DATA RULES

- failed candidates cannot masquerade as accepted previews
- accepted preview references exactly one canonical plan
- one logical generation request has one frozen plan
- retry attempts are traceable
- historical records remain unchanged
- RLS remains least-privilege
- service-role-only writes stay server-side

IDEMPOTENCY DESIGN

Define idempotency keys for:

- plan creation
- candidate generation request
- validation result
- accepted preview persistence
- usage commit

CONCURRENCY DESIGN

Cover:

- double tap
- network retry
- duplicate Edge invocation
- app resume
- provider timeout
- replay after partial success

If schema change is required:
produce exact migration design and pgTAP/RLS test plan.

DO NOT APPLY MIGRATION IN THIS PHASE unless explicitly authorized separately.

FINAL REPORT

==================================================
PDMK-2 PERSISTENCE DESIGN REPORT
==================================================

EXISTING TABLES REUSABLE:
YES / NO / PARTIAL

SCHEMA CHANGE REQUIRED:
YES / NO

PROPOSED SCHEMA:
<exact or NONE>

LINEAGE:
<exact>

FAILED CANDIDATE STORAGE:
<exact>

ACCEPTED PREVIEW STORAGE:
<exact>

VALIDATION EVIDENCE:
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
<exact>

STANDARD MODE IMPACT:
NONE / FAIL

SOURCE CHANGES:
NONE

PRODUCTION MUTATIONS:
0

PDMK-3:
READY / NOT READY

STOP.
==================================================
```

---

# PDMK-3 — PLAN GENERATOR + RECOMMENDATION V3

```text
======================================================================
FACETUNE
PDMK-3 — PLAN GENERATOR + RECOMMENDATION V3
======================================================================

IMPLEMENT ONLY PDMK-3.

PRECONDITIONS

PDMK-1 accepted.
PDMK-2 accepted.
Repository baseline clean/authorized.

NO REAL GEMINI CALLS IN THIS PHASE.

OBJECTIVE

Implement additive My Makeup Kit-only plan generation and derive the user-facing
recommendation from that plan.

RECOMMENDED VERSION IDENTIFIERS

kit_makeup_plan_v1
kit_makeup_recommendation_v3

Do not overwrite v2.

PLAN GENERATOR RULES

The server-side plan generator must:

- use only eligible owned products
- consider style intent
- explicitly evaluate Foundation
- explicitly evaluate Concealer
- evaluate Contour/Bronzer
- evaluate Highlighter
- avoid forced complexion products in lighter looks
- never invent products
- define allowed/forbidden visual categories
- define visible_intent for selected categories
- freeze the plan for the logical request

RECOMMENDATION RULE

For PDMK looks:

selected product identity must come from the plan.

Do not ask a second AI step to independently re-select products.

Presentation text may be generated or formatted, but it cannot change product
identity.

PROMPT SECURITY

- system instructions server-side
- structured schema
- product names treated as data, not instructions
- sanitize/escape untrusted free text as required
- no client-side prompt authority

TESTS

Add deterministic tests for:

- owned-only products
- no invalid duplicate category
- full kit
- no foundation
- no concealer
- multiple foundations
- natural/everyday/office not forced
- glam intent evaluated
- recommendation equals plan selections
- snapshot derivation contract
- v2 history preserved
- Standard Mode untouched

FINAL REPORT

==================================================
PDMK-3 PLAN + RECOMMENDATION REPORT
==================================================

PLAN VERSION:
<exact>

RECOMMENDATION VERSION:
<exact>

FILES MODIFIED:
<exact>

PLAN GENERATOR:
IMPLEMENTED / FAIL

RECOMMENDATION DERIVED FROM PLAN:
YES / NO

V2 MODIFIED:
NO / FAIL

STANDARD MODE MODIFIED:
NO / FAIL

DATABASE CHANGE:
<exact / NONE>

RLS CHANGE:
<exact / NONE>

TESTS:
<exact>

DENO:
<exact>

FLUTTER:
<exact / NOT APPLICABLE>

REAL GEMINI CALLS:
0

PRODUCTION MUTATIONS:
0

git diff --check:
PASS / FAIL

PDMK-4:
READY / NOT READY

STOP.
==================================================
```

---

# PDMK-4 — PLAN-CONSTRAINED KIT PREVIEW V2

```text
======================================================================
FACETUNE
PDMK-4 — PLAN-CONSTRAINED KIT PREVIEW V2
======================================================================

IMPLEMENT ONLY PDMK-4.

NO REAL GEMINI CALLS.

OBJECTIVE

Create a new additive My Makeup Kit preview prompt/version that renders the
canonical plan and forbids unplanned makeup.

RECOMMENDED VERSION

kit_makeup_preview_v2

MODEL HARD LOCK

gemini-3.1-flash-image

DO NOT change model.

GENERATION CONTRACT

Input must include the frozen canonical plan.

The preview prompt must:

- apply selected categories
- honor intended_role
- honor visible_intent
- forbid forbidden_visual_categories
- preserve identity
- preserve protected image rules
- avoid unplanned retouching that resembles cosmetics

EXPLICIT ABSENCE RULES

If Foundation is not selected:
- no foundation-like global coverage
- no cosmetic skin-tone evening
- no foundation-like smoothing/airbrushing

If Concealer is not selected:
- no concealer-like localized coverage
- no cosmetic under-eye brightening/correction

If Eyeliner is not selected:
- no visible eyeliner

Apply equivalent rules to other absent categories where meaningful.

VERSIONING

Do not change:

kit_makeup_preview_v1

Historical v1 remains historical.

TEST

- v2 routing for new PDMK
- v1 historical routing
- Standard Mode routing unchanged
- prompt contains plan constraints
- prompt excludes live-kit categories not selected in plan
- prompt injection resistance
- protected identity constraints preserved

FINAL REPORT

==================================================
PDMK-4 PREVIEW V2 REPORT
==================================================

VERSION:
kit_makeup_preview_v2

MODEL:
gemini-3.1-flash-image

FILES MODIFIED:
<exact>

PLAN INPUT:
PASS / FAIL

FORBIDDEN CATEGORY RULES:
PASS / FAIL

FOUNDATION ABSENCE RULE:
PASS / FAIL

CONCEALER ABSENCE RULE:
PASS / FAIL

V1 MODIFIED:
NO / FAIL

STANDARD MODE MODIFIED:
NO / FAIL

TESTS:
<exact>

REAL GEMINI CALLS:
0

PRODUCTION MUTATIONS:
0

git diff --check:
PASS / FAIL

PDMK-5:
READY / NOT READY

STOP.
==================================================
```

---

# PDMK-5 — PRE-PERSIST VALIDATOR V1

```text
======================================================================
FACETUNE
PDMK-5 — PRE-PERSIST KIT PREVIEW VALIDATOR V1
======================================================================

IMPLEMENT ONLY PDMK-5.

NO REAL GEMINI CALLS.

OBJECTIVE

Implement a My Makeup Kit-only fail-closed validator that evaluates:

original selfie
+
canonical plan
+
candidate preview

before the candidate can become an accepted Final Preview.

RECOMMENDED VERSION

kit_preview_validator_v1

VALIDATOR OUTPUT

Return structured outcome:

accepted
retryable_mismatch
nonretryable_mismatch
validator_failure
provider_failure

Also return:

planned_present_categories
unexpected_present_categories
missing_required_categories
uncertain_categories
mismatch_reasons
validator_version

ACCEPTANCE LOGIC

Do not accept merely because generation succeeded.

Reject/retry when material unplanned makeup is present.

Respect visible_intent:

required_visible
subtle_allowed

Do not reduce everything to a single numeric threshold.

Use evidence-based classification.

FAIL CLOSED

Malformed/ambiguous validator result:
must not silently accept.

SECURITY

Validator is server-side.

Do not expose private images to Flutter beyond existing authorized display path.

TESTS

- planned categories accepted
- unexpected foundation rejected
- unexpected concealer rejected
- unexpected eyeliner rejected
- subtle allowed handling
- malformed validator response
- provider failure
- Standard Mode untouched
- failed candidate cannot persist as accepted

FINAL REPORT

==================================================
PDMK-5 VALIDATOR V1 REPORT
==================================================

VERSION:
kit_preview_validator_v1

FILES MODIFIED:
<exact>

OUTCOME SCHEMA:
<exact>

FAIL CLOSED:
PASS / FAIL

UNPLANNED CATEGORY DETECTION:
PASS / FAIL

VISIBLE INTENT:
PASS / FAIL

FAILED CANDIDATE ACCEPTANCE:
BLOCKED / FAIL

STANDARD MODE:
UNCHANGED / FAIL

TESTS:
<exact>

REAL GEMINI CALLS:
0

PRODUCTION MUTATIONS:
0

git diff --check:
PASS / FAIL

PDMK-6:
READY / NOT READY

STOP.
==================================================
```

---

# PDMK-6 — BOUNDED REPAIR / REGENERATION ORCHESTRATOR

```text
======================================================================
FACETUNE
PDMK-6 — BOUNDED REPAIR / REGENERATION ORCHESTRATOR
======================================================================

IMPLEMENT ONLY PDMK-6.

NO REAL GEMINI CALLS.

OBJECTIVE

Automatically reconcile retryable preview mismatch without exposing broken
results or consuming multiple user entitlements.

DEFAULT DESIGN TARGET

attempt 1 = initial generation
attempt 2 = first constrained regeneration
attempt 3 = second constrained regeneration
maximum = 3 total candidate attempts

If current architecture requires a different bound:
STOP and report before changing it.

CORE INVARIANTS

- same frozen canonical plan across all attempts
- same logical request / reservation
- no additional user-facing AI Look or Preview Credit per internal retry
- every attempt has attempt_number
- mismatch evidence may tighten retry prompt
- failed candidate is not accepted/persisted as final
- accepted result commits usage once
- terminal authoritative failure follows existing release semantics
- no infinite loop

RETRY INPUT

A retry may use validator evidence such as:

unexpected category = foundation

to add a constrained instruction.

It must not mutate the plan merely to make the preview pass.

IDEMPOTENCY

Prove:

- duplicate request does not create duplicate commits
- app retry does not create a new plan if logical request already exists
- duplicate provider completion does not create duplicate accepted previews

ACCOUNTING TESTS

Explicitly test:

- accepted first attempt → one commit
- accepted second attempt → one commit
- accepted third attempt → one commit
- all attempts fail → correct release/failure state
- duplicate callback → no double commit

FINAL REPORT

==================================================
PDMK-6 ORCHESTRATOR REPORT
==================================================

MAX ATTEMPTS:
<exact>

PLAN IMMUTABLE ACROSS RETRIES:
PASS / FAIL

USER ENTITLEMENT CHARGES:
ONE / FAIL

ATTEMPT TRACKING:
PASS / FAIL

FAILED CANDIDATES EXCLUDED:
PASS / FAIL

IDEMPOTENCY:
PASS / FAIL

CONCURRENCY:
PASS / FAIL

USAGE COMMIT:
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

PDMK-7:
READY / NOT READY

STOP.
==================================================
```

---

# PDMK-7 — TUTORIAL READINESS BRIDGE

```text
======================================================================
FACETUNE
PDMK-7 — TUTORIAL READINESS BRIDGE
======================================================================

IMPLEMENT ONLY PDMK-7.

NO REAL GEMINI CALLS.

OBJECTIVE

Make Tutorial readiness an upstream acceptance condition for new PDMK previews
without weakening Tutorial V4 or modifying Standard Mode.

HARD LOCKS

Do not overwrite:

tutorial_manifest_v4_1
tutorial_guideline_v4_7

Do not remove:

kit_preview_mismatch

Do not use live-kit ownership as backing.

DESIGN

For an accepted PDMK preview, establish readiness using:

canonical plan
+
immutable product snapshot
+
accepted preview
+
validated visual evidence

The normal accepted PDMK preview should reach `Show me how` already known to be
reproducible.

If existing Tutorial manifest infrastructure can be invoked preflight without
changing Standard Mode semantics, reuse it.

If a new My Makeup Kit-only readiness artifact is cleaner, use additive:

kit_tutorial_readiness_v1

The readiness layer must not independently select products.

STEP GENERATION

Full Tutorial steps may remain lazy/on-demand if needed for cost/latency, but
eligibility must already be known.

`Show me how` must not normally discover the first product mismatch.

TESTS

- accepted preview → tutorial ready
- failed preview → no normal tutorial-ready state
- genuine unbacked present category still blocked
- historical previews unchanged
- Standard Mode Tutorial unchanged
- current Tutorial V4 safety unchanged

FINAL REPORT

==================================================
PDMK-7 TUTORIAL READINESS REPORT
==================================================

READINESS CONTRACT:
<exact>

READINESS VERSION:
<exact / EXISTING>

TUTORIAL V4_1 MODIFIED:
NO / FAIL

GUIDELINE V4_7 MODIFIED:
NO / FAIL

KIT_PREVIEW_MISMATCH REMOVED:
NO / FAIL

LIVE KIT USED AS BACKING:
NO / FAIL

STANDARD MODE TUTORIAL:
UNCHANGED / FAIL

TESTS:
<exact>

REAL GEMINI CALLS:
0

PRODUCTION MUTATIONS:
0

PDMK-8:
READY / NOT READY

STOP.
==================================================
```

---

# PDMK-8 — AUTOMATED REGRESSION / SECURITY / ACCOUNTING

```text
======================================================================
FACETUNE
PDMK-8 — AUTOMATED REGRESSION / SECURITY / ACCOUNTING
======================================================================

IMPLEMENT ONLY PDMK-8.

PRIMARILY VALIDATION.

OBJECTIVE

Prove structural safety before live AI evaluation.

TEST MATRIX

Styles:
- Soft Glam
- Party
- Date Night
- Bridal
- Full Glam
- Natural
- Everyday
- Office

Kit compositions:
- complete
- no foundation
- no concealer
- neither
- no contour/bronzer
- no highlighter
- multiple foundations
- multiple lip products
- minimal kit

INVARIANTS

- only owned products
- plan stable
- recommendation equals plan selection
- snapshot equals plan
- preview prompt equals plan constraints
- failed candidate cannot persist
- one usage commit
- no duplicate commit
- Standard Mode unchanged
- Standard Tutorial unchanged
- historical behavior unchanged
- RLS intact

RUN

- targeted Dart/Flutter tests
- full Flutter test suite
- Deno tests
- pgTAP if SQL changed
- secret scans
- flutter analyze
- dart format check
- git diff --check
- production Android build validation if appropriate

Known unrelated CRLF failures:
classify separately, never hide.

FINAL REPORT

==================================================
PDMK-8 AUTOMATED VALIDATION REPORT
==================================================

PLAN CONTRACT:
PASS / FAIL

OWNED-ONLY:
PASS / FAIL

SNAPSHOT:
PASS / FAIL

PREVIEW CONSTRAINT:
PASS / FAIL

VALIDATOR:
PASS / FAIL

RETRY ORCHESTRATOR:
PASS / FAIL

ONE-COMMIT ACCOUNTING:
PASS / FAIL

TUTORIAL READINESS:
PASS / FAIL

STANDARD MODE:
PASS / FAIL

STANDARD TUTORIAL:
PASS / FAIL

HISTORY:
PASS / FAIL

RLS:
PASS / FAIL

SECURITY:
PASS / FAIL

FLUTTER ANALYZE:
<exact>

FLUTTER TEST:
<exact>

DENO:
<exact>

PGTAP:
<exact>

SECRET SCAN:
<exact>

BUILD:
<exact>

git diff --check:
PASS / FAIL

PDMK-9:
READY / NOT READY

STOP.
==================================================
```

---

# PDMK-9 — CONTROLLED AI EVALUATION PLAN

```text
======================================================================
FACETUNE
PDMK-9 — CONTROLLED AI EVALUATION PLAN
======================================================================

IMPLEMENT ONLY PDMK-9.

MODE:
READ-ONLY PLANNING

NO GEMINI CALLS.

OBJECTIVE

Define a bounded evaluation that measures the complete plan → generate →
validate → retry → Tutorial-readiness pipeline.

REQUIRED STYLES

Soft Glam
Party
Date Night
Bridal
Full Glam
Natural
Everyday
Office

DEFINE

For every style:

- kit composition
- number of runs
- expected user entitlement consumption
- maximum provider call amplification
- expected candidate-attempt ceiling
- fields to capture
- success/failure rules

CAPTURE PER LOGICAL REQUEST

request_id
plan_id
plan_version
style
selected products
allowed categories
forbidden categories
preview prompt version
attempt count
validator version
outcome per attempt
unexpected categories
accepted attempt
Tutorial readiness
usage reservation
usage commit
terminal result

Do not include private image bytes in reports.

HUMAN GATE

Return the exact maximum:

- logical user requests
- user entitlements consumed
- preview-generation provider calls
- validator calls
- manifest/readiness calls

No live call is authorized until explicitly approved.

FINAL REPORT

==================================================
PDMK-9 LIVE EVALUATION PLAN
==================================================

LOGICAL REQUESTS:
<number>

USER ENTITLEMENTS MAX:
<number>

PREVIEW GENERATION CALLS MAX:
<number>

VALIDATOR CALLS MAX:
<number>

READINESS CALLS MAX:
<number>

STYLES:
<exact>

RUN MATRIX:
<exact>

CAPTURE FIELDS:
<exact>

SUCCESS METRICS:
<exact>

STOP CONDITIONS:
<exact>

HUMAN AUTHORIZATION:
REQUIRED

REAL GEMINI CALLS:
0

STOP.
==================================================
```

---

# PDMK-10 — CONTROLLED LIVE AI EVALUATION

```text
======================================================================
FACETUNE
PDMK-10 — CONTROLLED LIVE AI EVALUATION
======================================================================

IMPLEMENT ONLY PDMK-10.

PRECONDITION

Human explicitly approved the exact PDMK-9 call budget.

Do not exceed it.

OBJECTIVE

Measure real plan fidelity, retry behavior, Tutorial readiness, latency, and
accounting.

FOR EACH LOGICAL REQUEST

1. create/freeze plan
2. record products/categories
3. generate candidate
4. validate
5. if retryable, regenerate within authorized bound
6. persist accepted candidate only
7. establish Tutorial readiness
8. verify one usage commit
9. record terminal result

DO NOT CHANGE PROMPTS MID-RUN.

If serious defect appears:
stop early.

CLASSIFY EACH REQUEST

- accepted first attempt
- accepted after retry
- terminal plan/render mismatch
- provider failure
- validator failure
- accounting failure
- lineage failure

MEASURE

- first-attempt acceptance
- acceptance within retry bound
- terminal failure
- average attempt count
- unexpected category patterns
- Tutorial readiness among accepted previews
- entitlement correctness
- provider amplification

FINAL REPORT

==================================================
PDMK-10 LIVE EVALUATION REPORT
==================================================

LOGICAL REQUESTS:
<number>

USER ENTITLEMENTS CONSUMED:
<number>

GENERATION CALLS:
<number>

VALIDATOR CALLS:
<number>

READINESS CALLS:
<number>

FIRST-ATTEMPT ACCEPTANCE:
<exact>

ACCEPTED WITHIN RETRY:
<exact>

TERMINAL FAILURE:
<exact>

AVERAGE ATTEMPTS:
<exact>

TUTORIAL READY AMONG ACCEPTED:
<exact>

UNEXPECTED CATEGORY PATTERNS:
<exact>

ACCOUNTING:
PASS / FAIL

LINEAGE:
PASS / FAIL

STANDARD MODE:
UNCHANGED / FAIL

DECISION:
A. READY FOR E2E
B. PREVIEW PROMPT NEEDS REVISION
C. VALIDATOR NEEDS REVISION
D. PLAN GENERATOR NEEDS REVISION
E. ANALYZER FALSE POSITIVE EVIDENCE
F. ACCOUNTING/RELIABILITY BLOCKER

PDMK-11:
AUTHORIZED ONLY IF DECISION E AND HUMAN APPROVAL

STOP.
==================================================
```

---

# PDMK-11 — CONDITIONAL TUTORIAL ANALYZER REFINEMENT

```text
======================================================================
FACETUNE
PDMK-11 — CONDITIONAL TUTORIAL ANALYZER REFINEMENT
======================================================================

DO NOT RUN UNLESS:

PDMK-10 produced clear evidence that:
- plan is correct
- preview is visually faithful
- validator accepts correctly
- Tutorial/manifest still false-detects absent makeup

AND human explicitly authorized this phase.

OBJECTIVE

Create an additive analyzer refinement without weakening safety.

RECOMMENDED VERSION

tutorial_manifest_v4_2

DO NOT MODIFY

tutorial_manifest_v4_1
tutorial_guideline_v4_7
kit_preview_mismatch semantics
product_backed semantics
Standard Mode Tutorial unless separately authorized

FOUNDATION

Require clear evidence of deliberate complexion coverage.

Do not infer solely from:
- lighting
- natural smoothness
- generic AI texture cleanup
- global tone consistency
- mild retouching

Ambiguous:
uncertain

CONCEALER

Require clear localized coverage evidence.

Do not infer solely from:
- lighting
- naturally bright under-eyes
- reduced shadows
- generic smoothing
- AI cleanup

Ambiguous:
uncertain

SAFETY

Do not turn genuine visible unbacked makeup into absent merely to increase
Tutorial availability.

FINAL REPORT

==================================================
PDMK-11 ANALYZER REFINEMENT REPORT
==================================================

EVIDENCE GATE:
PASS / FAIL

NEW VERSION:
<exact>

V4_1 MODIFIED:
NO / FAIL

GUIDELINE V4_7 MODIFIED:
NO / FAIL

PRODUCT BACKING CHANGED:
NO / FAIL

KIT_PREVIEW_MISMATCH CHANGED:
NO / FAIL

STANDARD MODE IMPACT:
NONE / <exact>

TESTS:
<exact>

REAL GEMINI CALLS:
<number>

STOP.
==================================================
```

---

# PDMK-12 — REAL-DEVICE / E2E / FAILURE-UX QA

```text
======================================================================
FACETUNE
PDMK-12 — REAL-DEVICE / E2E / FAILURE-UX QA
======================================================================

IMPLEMENT ONLY PDMK-12.

OBJECTIVE

Validate the complete user experience on a real Android device.

TEST

For:

Soft Glam
Party
Date Night
Bridal
Full Glam
Natural
Everyday
Office

Verify:

1. choose style
2. choose My Makeup Kit
3. recommendation displays products from plan
4. generate Final Preview
5. no broken candidate is shown
6. retries are internal
7. accepted preview renders
8. Show me how
9. Tutorial opens without first discovering an avoidable mismatch
10. History reopens accepted result
11. Saved Looks behavior correct where applicable

FAILURE UX

Force or simulate bounded terminal failure safely.

Verify truthful copy.

The failure message must not falsely claim missing products when the actual
problem is AI reconciliation.

ACCOUNTING

Verify:
- one logical request
- one user entitlement charge
- internal retries do not multiply charges

NETWORK / RESUME

Test:
- background/foreground
- network interruption
- duplicate tap
- app restart where feasible

STANDARD MODE

Run smoke regression:
- recommendation
- preview
- Tutorial

No behavior change allowed.

FINAL REPORT

==================================================
PDMK-12 REAL-DEVICE QA REPORT
==================================================

DEVICE:
<exact>

STYLES TESTED:
<exact>

PDMK SUCCESS PATH:
PASS / FAIL

INTERNAL RETRY UX:
PASS / FAIL

TERMINAL FAILURE UX:
PASS / FAIL

TUTORIAL READY:
PASS / FAIL

HISTORY:
PASS / FAIL

SAVED LOOKS:
PASS / FAIL

DOUBLE TAP:
PASS / FAIL

NETWORK INTERRUPTION:
PASS / FAIL

APP RESUME:
PASS / FAIL

ONE-CHARGE ACCOUNTING:
PASS / FAIL

STANDARD MODE:
PASS / FAIL

STANDARD TUTORIAL:
PASS / FAIL

BLOCKERS:
NONE / <exact>

PDMK-13:
READY / NOT READY

STOP.
==================================================
```

---

# PDMK-13 — PRODUCTION READINESS / CHECKPOINT READINESS

```text
======================================================================
FACETUNE
PDMK-13 — PRODUCTION READINESS / CHECKPOINT READINESS
======================================================================

IMPLEMENT ONLY PDMK-13.

NO NEW FEATURES.
NO PROMPT OPTIMIZATION.
NO LIVE AI CALLS UNLESS A PREVIOUSLY AUTHORIZED CHECK REQUIRES THEM.

OBJECTIVE

Perform final architecture, quality, security, accounting, and regression
review.

VERIFY

- canonical plan is authoritative
- recommendation derives from plan
- snapshot equals plan
- preview is plan-constrained
- validator runs before acceptance
- retry is bounded
- retry does not mutate plan
- failed candidate is not accepted
- accepted preview is Tutorial-ready
- one logical request commits one entitlement
- Standard Mode unchanged
- Standard Tutorial unchanged
- historical content unchanged
- RLS intact
- secrets protected
- no client-side Gemini
- idempotency safe
- telemetry non-sensitive
- real-device QA passed
- controlled evaluation passed

RUN FINAL SUITE

- flutter analyze
- full Flutter tests
- Deno tests
- pgTAP if SQL changed
- secret scan
- build validation
- git diff --check

GIT REPORT

Report exact:
- branch
- HEAD
- working tree
- changed files
- diff summary

Do not commit or push.

FINAL REPORT

==================================================
PDMK FINAL PRODUCTION-READINESS REPORT
==================================================

CANONICAL PLAN:
PASS / FAIL

RECOMMENDATION DERIVATION:
PASS / FAIL

SNAPSHOT:
PASS / FAIL

PREVIEW CONSTRAINT:
PASS / FAIL

PRE-PERSIST VALIDATION:
PASS / FAIL

BOUNDED RETRY:
PASS / FAIL

FAILED CANDIDATE EXCLUSION:
PASS / FAIL

TUTORIAL READINESS:
PASS / FAIL

ONE-CHARGE ACCOUNTING:
PASS / FAIL

STANDARD MODE:
PASS / FAIL

STANDARD TUTORIAL:
PASS / FAIL

HISTORICAL PRESERVATION:
PASS / FAIL

RLS:
PASS / FAIL

SECURITY:
PASS / FAIL

PRIVACY:
PASS / FAIL

IDEMPOTENCY:
PASS / FAIL

CONCURRENCY:
PASS / FAIL

CONTROLLED AI EVALUATION:
PASS / FAIL

REAL-DEVICE QA:
PASS / FAIL

AUTOMATED TESTS:
<exact>

BUILD:
<exact>

UNRESOLVED BLOCKERS:
<number + exact>

FILES CHANGED:
<exact>

WORKING TREE:
CLEAN / DIRTY

CHECKPOINT:
READY / NOT READY

COMMIT:
NONE

PUSH:
NONE

STOP.
==================================================
```

---

# TRACK TERMINATION RULE

After accepted PDMK-13:

```text
PDMK = COMPLETE
CHECKPOINT = READY
CHECKPOINT NOT CREATED
```

Separate explicit authorization is required for:

- commit
- push
- merge
- deployment
- production rollout

Do not invent PDMK-14.

Do not silently begin another prompt-optimization track.
