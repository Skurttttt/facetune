# FACETUNE_STEP_BY_STEP_TUTORIAL_ROADMAP.md

## Roadmap Purpose

This file contains the phased implementation plan and copy-paste prompts for CodeX or Claude Code.

Use together with:

1. `CODEX_MASTER_GUIDE.md`
2. `FACETUNE_STEP_BY_STEP_TUTORIAL_GUIDE.md`
3. the requested ST phase in this roadmap

Do not execute multiple phases automatically. A pasted, selected, provided, or directly referenced ST phase counts as explicit authorization to execute that specific phase immediately; this rule only prevents automatic continuation into later phases.

---

# Mandatory Git Safety Header

The following rules apply to every phase in this roadmap.

```text
GIT SAFETY CHECK — MANDATORY

Before modifying any file:

1. Run:
   git status
   git branch --show-current

2. Confirm the active branch is exactly:
   feature/step-by-step-tutorial

3. If the active branch is NOT feature/step-by-step-tutorial:
   STOP immediately and report the active branch.
   Do not modify any files.

PROTECTED BASELINE

main is the protected stable FaceTune baseline.

Do NOT:
- develop or commit this feature directly on main;
- merge into main;
- force-push;
- reset or rewrite main;
- delete branches;
- discard existing work without explicit user approval.

SOURCE OF TRUTH

Before implementation, read completely:

1. CODEX_MASTER_GUIDE.md
2. FACETUNE_STEP_BY_STEP_TUTORIAL_GUIDE.md
3. the requested ST phase in FACETUNE_STEP_BY_STEP_TUTORIAL_ROADMAP.md

Inspect the CURRENT repository before implementation.

Do not assume previous work exists unless it is actually present.

The existing Makeup Recommendation flow is frozen.

The existing My Makeup Kit flow is frozen.

The Step-by-Step Tutorial must remain additive, isolated, backward compatible, and cost-aware.

STRICT ENGINEERING RULE

The tutorial image-generation model and output resolution must be configurable server-side and must not be tightly coupled to tutorial business logic or UI.

PHASE EXECUTION AUTHORIZATION — MANDATORY

When the user pastes, provides, selects, or directly references a complete ST phase from this roadmap, that action itself is explicit authorization to execute that specific phase.

Do NOT ask:
- “Do you want me to proceed?”
- “Should I execute this phase?”
- “Would you like me to start?”
- or any equivalent confirmation question.

Immediately execute the provided, selected, or referenced phase after completing the required Git safety check and source-of-truth reading.

If the pasted phase contains the instruction “Execute ST-X”, treat it as a direct execution order.

Implement ONLY the ST phase provided, selected, or referenced by the user. Providing, selecting, or referencing a phase counts as an explicit execution request.

Do NOT automatically continue to the next phase. A new user message providing, selecting, or referencing the next ST phase is required before executing that next phase.

The phrase “Do not execute phases automatically” means:
- do not continue from one ST phase to the next by yourself;
- it does NOT mean extra confirmation is required after the user has already provided, selected, or referenced a phase.

Do not fabricate:
- tests;
- builds;
- migrations;
- deployments;
- device results;
- backend results.

If an environment limitation prevents validation, state it explicitly.

At completion:
- summarize files created/modified;
- summarize architecture changes;
- list validation actually run;
- list manual actions required;
- list known limitations;
- state the next phase;
- STOP.
```

---

# ST-1 — Baseline Audit & Tutorial Architecture Contract

## Goal

Establish the architectural boundaries for the Step-by-Step Tutorial before implementing feature behavior.

## Prompt

```text
Execute ST-1 — Baseline Audit & Tutorial Architecture Contract.

First obey the Mandatory Git Safety Header in this roadmap.

Read:
1. CODEX_MASTER_GUIDE.md
2. FACETUNE_STEP_BY_STEP_TUTORIAL_GUIDE.md
3. ST-1 in FACETUNE_STEP_BY_STEP_TUTORIAL_ROADMAP.md

Inspect the current repository before changing code.

OBJECTIVE

Establish a safe, additive architecture for the Step-by-Step Tutorial without modifying existing behavior.

TASKS

1. Audit the current implementation of:
   - Face Analysis;
   - standard Makeup Recommendation;
   - final Before/After preview;
   - My Makeup Kit;
   - Saved Looks;
   - History;
   - current comparison slider;
   - Supabase repositories and Edge Function conventions;
   - Riverpod conventions;
   - storage and signed URL conventions.

2. Identify the safest integration points for:
   - “How to Apply This Look” entry;
   - tutorial source data;
   - standard recommendation mode;
   - My Makeup Kit mode;
   - reuse/adaptation of the existing comparison slider.

3. Create the feature-first tutorial module structure appropriate for this repository, conceptually under:
   lib/features/step_by_step_tutorial/
   using the project's current Clean Architecture conventions.

4. Add only foundational typed contracts/models needed for future phases, such as:
   - TutorialSourceMode;
   - TutorialSession;
   - TutorialStep;
   - TutorialStepCategory;
   - TutorialInstruction;
   - TutorialGenerationStatus;
   - placement metadata contracts where appropriate.

5. Add repository interfaces / provider scaffolding only if appropriate for the current architecture.

6. Do NOT:
   - implement live AI generation;
   - create database migrations yet;
   - rewrite current recommendation logic;
   - rewrite current preview generation;
   - modify My Makeup Kit behavior;
   - create fake tutorial data that behaves like production.

7. Document any architectural decisions that later phases must respect.

VALIDATION

Run, where supported:
- dart format .
- flutter analyze
- relevant flutter tests
- configured Android debug build used by this project

Do not claim success for anything not actually run.

COMPLETION REPORT

PHASE COMPLETED:
ST-1 — Baseline Audit & Tutorial Architecture Contract

CURRENT BRANCH:
BASELINE AUDITED:
FILES CREATED:
FILES MODIFIED:
ARCHITECTURAL BOUNDARIES:
DOMAIN CONTRACTS:
REUSE / INTEGRATION POINTS:
VALIDATION ACTUALLY RUN:
ANDROID BUILD:
REGRESSION OBSERVATIONS:
KNOWN LIMITATIONS:
MANUAL ACTIONS:
NEXT PHASE:
ST-2 — Supabase Tutorial Schema, Storage & RLS

Then STOP and wait for the user to provide, select, or reference another ST phase. Do not ask whether to execute the next phase.
```

---

# ST-2 — Supabase Tutorial Schema, Storage & RLS

## Goal

Create the persistent backend foundation for tutorial sessions and tutorial steps.

## Prompt

```text
Execute ST-2 — Supabase Tutorial Schema, Storage & RLS.

First obey the Mandatory Git Safety Header.

Read the source-of-truth files and inspect the current Supabase conventions in the repository.

OBJECTIVE

Create secure persistent storage for tutorial sessions, tutorial steps, generation states, and saved result-image references.

TASKS

1. Design additive migrations using existing naming and migration conventions.

2. Create tables or equivalent structures for:
   - tutorial_sessions;
   - tutorial_steps;
   - any minimal additional structure truly required.

3. tutorial_sessions should support, where appropriate:
   - id;
   - authenticated user ownership;
   - source mode: standard recommendation / My Makeup Kit;
   - source analysis reference;
   - source recommendation or result reference;
   - source kit-result reference where applicable;
   - selected style / variation snapshot;
   - total step count;
   - generation status;
   - prompt version;
   - tutorial model;
   - tutorial output size;
   - timestamps.

4. tutorial_steps should support, where appropriate:
   - tutorial session reference;
   - step number;
   - category;
   - title;
   - structured written instructions;
   - placement metadata;
   - placement source image reference;
   - result image path/reference;
   - model / image-size snapshot;
   - prompt version;
   - generation status;
   - timestamps.

5. Add:
   - foreign keys;
   - indexes;
   - uniqueness rules needed to prevent accidental duplicates;
   - RLS;
   - authenticated-user ownership policies.

6. Design private Storage paths for tutorial result images following existing FaceTune storage security patterns.

7. Preserve historical snapshot semantics:
   later edits/deletions to My Makeup Kit inventory must not silently rewrite already-generated tutorial instructions.

8. Do NOT deploy automatically unless the user's workflow explicitly expects deployment in this phase.
   If manual deployment is required, report exact npx Supabase commands.

9. Do not change unrelated existing tables unless strictly necessary and backward compatible.

VALIDATION

Run all repository-supported validation.
Review SQL for RLS and ownership correctness.

COMPLETION REPORT

PHASE COMPLETED:
ST-2 — Supabase Tutorial Schema, Storage & RLS

CURRENT BRANCH:
MIGRATIONS CREATED:
TABLES / FIELDS:
INDEXES / CONSTRAINTS:
RLS:
STORAGE STRATEGY:
SNAPSHOT SEMANTICS:
FILES MODIFIED:
VALIDATION ACTUALLY RUN:
MANUAL SUPABASE ACTIONS:
KNOWN LIMITATIONS:
NEXT PHASE:
ST-3 — Tutorial Domain, Repository & State Foundation

Then STOP and wait for the user to provide, select, or reference another ST phase. Do not ask whether to execute the next phase.
```

---

# ST-3 — Tutorial Domain, Repository & State Foundation

## Goal

Implement the typed Flutter data/domain/state foundation using the schema created in ST-2.

## Prompt

```text
Execute ST-3 — Tutorial Domain, Repository & State Foundation.

Obey the Mandatory Git Safety Header and read all required source-of-truth files.

OBJECTIVE

Create production-oriented typed domain, data, repository, and Riverpod state support for tutorial sessions and steps.

TASKS

1. Implement typed models/entities for:
   - tutorial session;
   - tutorial step;
   - tutorial instruction;
   - source mode;
   - generation status;
   - placement metadata;
   - category.

2. Implement mapping/serialization consistent with current project conventions.

3. Implement repository contracts and Supabase-backed repository implementations for:
   - create/load tutorial session;
   - list/load tutorial steps;
   - persist step metadata;
   - update generation status;
   - load an existing valid tutorial;
   - support future resume/retry behavior.

4. Add Riverpod controller/provider state using existing project patterns.

5. Model explicit states:
   - initial;
   - loading;
   - loaded;
   - generating;
   - partially complete;
   - failed.

6. Ensure user ownership is never trusted from arbitrary client-supplied user IDs.
   Follow existing authenticated Supabase patterns.

7. Do not implement Gemini calls yet.

8. Do not expose unfinished tutorial UI as if generation already works.

VALIDATION

Run:
- dart format .
- flutter analyze
- relevant tests
- configured Android debug build where supported

COMPLETION REPORT

PHASE COMPLETED:
ST-3 — Tutorial Domain, Repository & State Foundation

CURRENT BRANCH:
FILES CREATED:
FILES MODIFIED:
DOMAIN MODELS:
REPOSITORY IMPLEMENTATION:
RIVERPOD STATE:
ERROR MODELING:
VALIDATION ACTUALLY RUN:
ANDROID BUILD:
KNOWN LIMITATIONS:
NEXT PHASE:
ST-4 — Tutorial Entry Points & Navigation

Then STOP and wait for the user to provide, select, or reference another ST phase. Do not ask whether to execute the next phase.
```

---

# ST-4 — Tutorial Entry Points & Navigation

## Goal

Add safe entry points from existing generated looks without changing existing recommendation behavior.

## Prompt

```text
Execute ST-4 — Tutorial Entry Points & Navigation.

Obey the Mandatory Git Safety Header.

OBJECTIVE

Introduce navigation into the tutorial feature from appropriate existing FaceTune result surfaces.

TASKS

1. Inspect current result, saved-look, and history/detail screens.

2. Add an additive CTA such as:
   “How to Apply This Look”
   or an equivalent FaceTune-consistent label.

3. Support safe navigation from:
   - standard generated result;
   - My Makeup Kit generated result;
   - saved look detail where sufficient source context exists;
   - history/detail surface where sufficient source context exists.

4. Pass stable IDs / domain references rather than large raw state blobs wherever appropriate.

5. Handle unavailable source context gracefully.

6. Do not generate AI images yet.

7. Do not alter the existing Before/After slider behavior.

8. Do not break current result/save/history navigation.

VALIDATION

Run normal Flutter validation and smoke-test navigation where possible.

COMPLETION REPORT

PHASE COMPLETED:
ST-4 — Tutorial Entry Points & Navigation

CURRENT BRANCH:
FILES MODIFIED:
ENTRY POINTS:
ROUTES:
SOURCE CONTEXT PASSED:
ERROR / UNAVAILABLE STATES:
VALIDATION ACTUALLY RUN:
ANDROID BUILD:
REGRESSION OBSERVATIONS:
KNOWN LIMITATIONS:
NEXT PHASE:
ST-5 — Tutorial Viewer & Placement/Result Slider UI

Then STOP and wait for the user to provide, select, or reference another ST phase. Do not ask whether to execute the next phase.
```

---

# ST-5 — Tutorial Viewer & Placement/Result Slider UI

## Goal

Build the tutorial screen and reuse/adapt the existing comparison interaction.

## Prompt

```text
Execute ST-5 — Tutorial Viewer & Placement/Result Slider UI.

Obey the Mandatory Git Safety Header.

OBJECTIVE

Build the premium tutorial viewer UI using safe placeholder/domain data only.

REQUIRED UX

Representative screen:

How to Apply This Look

STEP 4 OF N — BLUSH

PLACEMENT  ←────●────→  RESULT

[ aligned comparison image ]

Color
Finish
Placement
Direction
Intensity
Technique / Tip

[ Previous ] [ Next Step ]

TASKS

1. Reuse or safely extract/adapt the current Before/After comparison component where practical.

2. Tutorial labels must be:
   - Placement
   - Result

3. Do not rename the existing final-preview labels.
   Existing preview remains:
   Before / After

4. Add:
   - header;
   - current step title;
   - selected style/variation label where available;
   - dynamic step progress indicator;
   - comparison area;
   - written instruction card;
   - Previous / Next Step;
   - loading state;
   - empty state;
   - error state.

5. Step count must be dynamic.
   Do not hardcode “8”.

6. Maintain FaceTune's existing Material 3 / premium beauty design language.

7. No live AI generation yet.

VALIDATION

Run normal Flutter validation and any widget tests appropriate to the new UI.

COMPLETION REPORT

PHASE COMPLETED:
ST-5 — Tutorial Viewer & Placement/Result Slider UI

CURRENT BRANCH:
FILES CREATED:
FILES MODIFIED:
REUSED COMPONENTS:
NEW COMPONENTS:
DYNAMIC STEP SUPPORT:
UI STATES:
VALIDATION ACTUALLY RUN:
ANDROID BUILD:
KNOWN LIMITATIONS:
NEXT PHASE:
ST-6 — Category-Specific Placement Overlay Engine

Then STOP and wait for the user to provide, select, or reference another ST phase. Do not ask whether to execute the next phase.
```

---

# ST-6 — Category-Specific Placement Overlay Engine

## Goal

Render instructional placement graphics locally without generating a second AI image.

## Prompt

```text
Execute ST-6 — Category-Specific Placement Overlay Engine.

Obey the Mandatory Git Safety Header.

OBJECTIVE

Create a reusable, data-driven Flutter overlay system for the Placement side of each tutorial step.

CORE RULE

V1 Placement is:

previous step result image
+
FaceTune-rendered instructional overlay

Do NOT create a second Gemini generation for Placement.

TASKS

1. Implement typed placement-overlay metadata.

2. Support reusable overlay primitives such as:
   - translucent zones;
   - dots;
   - guide lines;
   - arrows;
   - boundaries.

3. Support category-aware placement behavior for:
   - foundation;
   - concealer;
   - contour / bronzer;
   - blush;
   - highlighter;
   - eyeshadow;
   - eyeliner;
   - eyebrows;
   - lipstick / lip gloss.

4. Keep overlay coordinates responsive to the displayed image dimensions.

5. Do not bake screen-size-specific pixel coordinates into domain data.

6. Make the overlay engine independently testable where practical.

7. Use conservative, clean instructional graphics.
   Avoid visual clutter.

8. Placement source image selection:
   - Step 1 Placement uses original selfie;
   - Step N Placement uses Step N-1 Result.

9. Do not implement AI generation yet.

VALIDATION

Run formatter, analyzer, tests, and Android debug build where supported.

COMPLETION REPORT

PHASE COMPLETED:
ST-6 — Category-Specific Placement Overlay Engine

CURRENT BRANCH:
FILES CREATED:
FILES MODIFIED:
OVERLAY PRIMITIVES:
SUPPORTED CATEGORIES:
COORDINATE / RESPONSIVE STRATEGY:
PLACEMENT SOURCE RULE:
VALIDATION ACTUALLY RUN:
ANDROID BUILD:
KNOWN LIMITATIONS:
NEXT PHASE:
ST-7 — Dynamic Tutorial Planning Engine

Then STOP and wait for the user to provide, select, or reference another ST phase. Do not ask whether to execute the next phase.
```

---

# ST-7 — Dynamic Tutorial Planning Engine

## Goal

Convert an actual recommendation or My Makeup Kit result into the ordered tutorial plan.

## Prompt

```text
Execute ST-7 — Dynamic Tutorial Planning Engine.

Obey the Mandatory Git Safety Header.

OBJECTIVE

Build deterministic application logic that turns a source look into a dynamic ordered tutorial plan.

TASKS

1. Inspect current standard recommendation and My Makeup Kit result structures.

2. Build the planning engine without rewriting either source system.

3. Determine dynamically:
   - included categories;
   - excluded categories;
   - step count;
   - step order;
   - step title;
   - written instruction payload;
   - placement metadata;
   - current product/color/finish;
   - whether the existing final Pro preview can be reused as the final step.

4. Standard Recommendation:
   derive steps only from the actual recommendation.

5. My Makeup Kit:
   derive steps only from products actually selected from the user's owned inventory snapshot.
   Never invent missing products.

6. Incomplete kits are valid.

7. Do not force every tutorial to have the same number of steps.

8. Define a stable ordering policy while allowing omission of unused categories.

9. Preserve source snapshot semantics.

10. No Gemini image generation yet.

VALIDATION

Add unit tests for:
- natural/simple look;
- fuller/glam look;
- incomplete kit;
- kit with only a few categories;
- ordering;
- no fabricated products;
- final-preview reuse decision.

COMPLETION REPORT

PHASE COMPLETED:
ST-7 — Dynamic Tutorial Planning Engine

CURRENT BRANCH:
FILES CREATED:
FILES MODIFIED:
PLANNING RULES:
STANDARD MODE SUPPORT:
MY MAKEUP KIT SUPPORT:
DYNAMIC STEP COUNT:
FINAL PREVIEW REUSE:
TESTS:
VALIDATION ACTUALLY RUN:
ANDROID BUILD:
KNOWN LIMITATIONS:
NEXT PHASE:
ST-8 — Tutorial Persistence, Cache & Duplicate Prevention

Then STOP and wait for the user to provide, select, or reference another ST phase. Do not ask whether to execute the next phase.
```

---

# ST-8 — Tutorial Persistence, Cache & Duplicate Prevention

## Goal

Persist tutorial plans/results and avoid paying twice for valid existing tutorials.

## Prompt

```text
Execute ST-8 — Tutorial Persistence, Cache & Duplicate Prevention.

Obey the Mandatory Git Safety Header.

OBJECTIVE

Implement saved tutorial reuse, resumable state, and duplicate-generation protection before connecting Gemini.

TASKS

1. Persist tutorial sessions and planned steps.

2. Implement lookup for an existing valid tutorial for the same source look/snapshot.

3. Reopening an existing valid tutorial should load stored data instead of creating a new session.

4. Support:
   - partially complete session;
   - completed session;
   - failed step;
   - retryable step;
   - source invalidation where truly required.

5. Add application-level duplicate prevention in addition to database uniqueness where appropriate.

6. Store model and prompt-version snapshots so future model changes do not make old tutorial metadata ambiguous.

7. Define regeneration behavior:
   regeneration must be an explicit user action or a genuine invalid/missing-data recovery path.

8. Do not call Gemini yet.

VALIDATION

Test duplicate prevention and reopening behavior.

COMPLETION REPORT

PHASE COMPLETED:
ST-8 — Tutorial Persistence, Cache & Duplicate Prevention

CURRENT BRANCH:
FILES CREATED:
FILES MODIFIED:
CACHE STRATEGY:
DUPLICATE PREVENTION:
RESUME BEHAVIOR:
REGENERATION RULES:
VALIDATION ACTUALLY RUN:
ANDROID BUILD:
KNOWN LIMITATIONS:
NEXT PHASE:
ST-9 — Secure Tutorial Image Generation Backend

Then STOP and wait for the user to provide, select, or reference another ST phase. Do not ask whether to execute the next phase.
```

---

# ST-9 — Secure Tutorial Image Generation Backend

## Goal

Generate one cumulative Result image per required tutorial step using Gemini 3.1 Flash Image.

## Prompt

```text
Execute ST-9 — Secure Tutorial Image Generation Backend.

Obey the Mandatory Git Safety Header.

OBJECTIVE

Create the secure backend generation path for tutorial Result images.

MODEL STRATEGY

Final existing premium preview:
- keep Gemini 3 Pro Image unchanged.

Tutorial Result images:
- Gemini 3.1 Flash Image;
- start with 512px output;
- make model and output size configurable server-side.

CORE V1 RULE

Generate ONE new AI result image per required tutorial step.

Do NOT generate a separate AI Placement image.

TASKS

1. Create a dedicated Supabase Edge Function or equivalent isolated backend operation for tutorial generation.

2. Follow existing secure backend patterns:
   Flutter → Supabase Auth → Edge Function → Gemini.

3. Never expose GEMINI_API_KEY to Flutter.

4. Authenticate the request and validate source ownership.

5. Validate requested tutorial session and step against server-owned data.

6. Build a versioned tutorial image-generation prompt.

7. Require:
   - same person;
   - strong identity preservation;
   - same facial proportions;
   - same skin tone;
   - same crop/angle/pose where practical;
   - previous makeup retained;
   - only the current step newly applied;
   - realistic skin texture;
   - no unrelated beautification;
   - no facial-feature alteration;
   - no added products that are absent from the planned step.

8. CUMULATIVE SOURCE STRATEGY

Step 1:
source from original selfie / approved source image.

Step N:
use the previous Result image as the immediate cumulative visual reference where architecturally appropriate, while retaining access to the original identity reference if supported by the chosen Gemini request strategy.

Do not allow uncontrolled identity drift across repeated generations.

9. Save generated images to private Supabase Storage.

10. Persist:
   - result image path;
   - model;
   - image size;
   - prompt version;
   - generation status.

11. Add safe timeouts/retry behavior consistent with current project standards.

12. Avoid duplicate generation if a valid result already exists.

13. Log useful timing/status metadata without logging secrets or sensitive image contents.

14. Do not modify existing Pro preview function behavior.

VALIDATION

Run supported local/static validation.
If deployment is not performed, say so.

Provide exact manual commands using:
npx -y supabase ...

COMPLETION REPORT

PHASE COMPLETED:
ST-9 — Secure Tutorial Image Generation Backend

CURRENT BRANCH:
FILES CREATED:
FILES MODIFIED:
EDGE FUNCTION:
MODEL:
OUTPUT SIZE:
PROMPT VERSION:
IDENTITY PRESERVATION STRATEGY:
CUMULATIVE GENERATION STRATEGY:
STORAGE:
DUPLICATE PROTECTION:
VALIDATION ACTUALLY RUN:
MANUAL SUPABASE ACTIONS:
DEPLOYMENT STATUS:
KNOWN LIMITATIONS:
NEXT PHASE:
ST-10 — Flutter Generation Orchestration & Progressive Loading

Then STOP and wait for the user to provide, select, or reference another ST phase. Do not ask whether to execute the next phase.
```

---

# ST-10 — Flutter Generation Orchestration & Progressive Loading

## Goal

Connect the tutorial UI to the real backend and support partial/progressive completion.

## Prompt

```text
Execute ST-10 — Flutter Generation Orchestration & Progressive Loading.

Obey the Mandatory Git Safety Header.

OBJECTIVE

Connect Flutter to the tutorial backend and display real Placement/Result steps.

TASKS

1. Implement generation orchestration through the repository/controller layers.

2. Generate only steps that are missing.

3. Do not regenerate already-valid saved steps.

4. Display progressive state:
   - planning;
   - preparing tutorial;
   - generating current step;
   - completed step available;
   - partially completed tutorial;
   - failed step.

5. Placement side:
   - use original selfie for Step 1;
   - use previous Result image for later steps;
   - apply local category-specific overlays.

6. Result side:
   - load the generated current-step result image.

7. Adapt/reuse the comparison slider so the user can drag:
   Placement ←→ Result

8. Support Previous / Next navigation through already available steps.

9. Handle a not-yet-generated next step cleanly.

10. If the final complete-look step can reuse the existing Gemini 3 Pro Image final preview, reuse it instead of generating a duplicate.

11. Signed URL refresh/loading should follow current private-storage patterns.

VALIDATION

Run Flutter validation and real-device smoke testing if available.
Do not claim device testing unless actually performed.

COMPLETION REPORT

PHASE COMPLETED:
ST-10 — Flutter Generation Orchestration & Progressive Loading

CURRENT BRANCH:
FILES CREATED:
FILES MODIFIED:
GENERATION ORCHESTRATION:
PLACEMENT SOURCE:
RESULT SOURCE:
SLIDER BEHAVIOR:
PROGRESSIVE STATES:
FINAL PREVIEW REUSE:
VALIDATION ACTUALLY RUN:
ANDROID BUILD:
DEVICE TEST:
KNOWN LIMITATIONS:
NEXT PHASE:
ST-11 — Written Instruction Integration & Tutorial Accuracy

Then STOP and wait for the user to provide, select, or reference another ST phase. Do not ask whether to execute the next phase.
```

---

# ST-11 — Written Instruction Integration & Tutorial Accuracy

## Goal

Ensure every tutorial step contains useful, category-specific written guidance consistent with the actual recommendation.

## Prompt

```text
Execute ST-11 — Written Instruction Integration & Tutorial Accuracy.

Obey the Mandatory Git Safety Header.

OBJECTIVE

Complete the instructional layer so every step explains what, where, and how to apply the current makeup.

TASKS

1. For every applicable step support structured fields such as:
   - category;
   - product name when available;
   - color name;
   - HEX where available;
   - finish;
   - placement;
   - direction;
   - intensity;
   - technique;
   - optional tip.

2. Standard Recommendation:
   use the actual recommended colors/finishes/placements.

3. My Makeup Kit:
   use owned-product snapshot data only.

4. Ensure written instructions match:
   - current step;
   - displayed placement overlay;
   - generated Result image intent.

5. Avoid vague filler instructions where structured source data is available.

6. Gracefully omit fields that genuinely do not apply.

7. Ensure terminology is user-friendly.

8. Do not let presentation-layer copy silently invent product facts.

9. Add tests for instruction mapping / category behavior where practical.

VALIDATION

Run standard Flutter validation.

COMPLETION REPORT

PHASE COMPLETED:
ST-11 — Written Instruction Integration & Tutorial Accuracy

CURRENT BRANCH:
FILES CREATED:
FILES MODIFIED:
INSTRUCTION FIELDS:
STANDARD MODE:
MY MAKEUP KIT MODE:
CATEGORY-SPECIFIC RULES:
TESTS:
VALIDATION ACTUALLY RUN:
ANDROID BUILD:
KNOWN LIMITATIONS:
NEXT PHASE:
ST-12 — Save, Reopen, History & Regenerate UX

Then STOP and wait for the user to provide, select, or reference another ST phase. Do not ask whether to execute the next phase.
```

---

# ST-12 — Save, Reopen, History & Regenerate UX

## Goal

Make tutorials durable and useful after the initial generation session.

## Prompt

```text
Execute ST-12 — Save, Reopen, History & Regenerate UX.

Obey the Mandatory Git Safety Header.

OBJECTIVE

Allow users to revisit tutorials without unnecessary Gemini calls.

TASKS

1. Add View Tutorial behavior from appropriate saved-look/history detail surfaces.

2. Reopening an existing valid tutorial must:
   - load stored tutorial session;
   - load stored steps;
   - reuse stored result images;
   - not regenerate automatically.

3. Add explicit regeneration UX where appropriate.

4. Regenerate must clearly communicate that:
   - a new tutorial may require AI generation;
   - existing saved tutorial is otherwise reusable.

5. Decide whether regeneration:
   - replaces the current tutorial;
   - creates a new version;
   based on current FaceTune history/snapshot conventions.
   Prefer preserving historical integrity.

6. Support delete behavior only if it fits existing product conventions and can be implemented safely.

7. Existing Saved and History behavior must remain intact.

VALIDATION

Run relevant tests and regression checks.

COMPLETION REPORT

PHASE COMPLETED:
ST-12 — Save, Reopen, History & Regenerate UX

CURRENT BRANCH:
FILES CREATED:
FILES MODIFIED:
SAVE / REOPEN FLOW:
HISTORY INTEGRATION:
REGENERATION:
DELETE BEHAVIOR:
CACHE REUSE:
VALIDATION ACTUALLY RUN:
ANDROID BUILD:
REGRESSION OBSERVATIONS:
KNOWN LIMITATIONS:
NEXT PHASE:
ST-13 — Resilience, Security, Cost & Performance Hardening

Then STOP and wait for the user to provide, select, or reference another ST phase. Do not ask whether to execute the next phase.
```

---

# ST-13 — Resilience, Security, Cost & Performance Hardening

## Goal

Harden the new feature before final QA.

## Prompt

```text
Execute ST-13 — Resilience, Security, Cost & Performance Hardening.

Obey the Mandatory Git Safety Header.

OBJECTIVE

Audit and harden the entire Step-by-Step Tutorial feature.

REVIEW

1. Authentication / authorization:
   - RLS;
   - session ownership;
   - Storage ownership;
   - Edge Function validation.

2. Secrets:
   - Gemini API key server-side only.

3. Cost protection:
   - no duplicate valid step generation;
   - no duplicate Placement generation;
   - existing final Pro preview reused where applicable;
   - saved tutorial loaded instead of regenerated;
   - retry only failed/missing work.

4. Identity:
   - cumulative prompt strategy;
   - original identity reference strategy;
   - guardrails against facial drift.

5. Error handling:
   - timeouts;
   - partial tutorial;
   - broken signed URLs;
   - missing storage asset;
   - deleted source;
   - failed step;
   - offline saved-tutorial viewing where practical.

6. Performance:
   - avoid loading every full image unnecessarily;
   - image caching;
   - signed URL behavior;
   - controller lifecycle;
   - stale async protection;
   - duplicate taps / concurrent requests.

7. Logging:
   - useful timings;
   - no secrets;
   - no sensitive raw image content.

8. Regression:
   - standard Makeup Recommendation;
   - final Before/After preview;
   - My Makeup Kit;
   - Saved;
   - History.

VALIDATION

Run all supported validation.
Document anything that requires real-device/manual testing.

COMPLETION REPORT

PHASE COMPLETED:
ST-13 — Resilience, Security, Cost & Performance Hardening

CURRENT BRANCH:
SECURITY FINDINGS:
COST CONTROLS:
IDENTITY SAFEGUARDS:
ERROR RECOVERY:
PERFORMANCE:
FILES MODIFIED:
VALIDATION ACTUALLY RUN:
ANDROID BUILD:
DEVICE TEST:
REGRESSION RESULTS:
KNOWN LIMITATIONS:
NEXT PHASE:
ST-14 — End-to-End QA, Final UI Polish & Completion

Then STOP and wait for the user to provide, select, or reference another ST phase. Do not ask whether to execute the next phase.
```

---

# ST-14 — End-to-End QA, Final UI Polish & Completion

## Goal

Perform final feature validation and polish without broadening scope.

## Prompt

```text
Execute ST-14 — End-to-End QA, Final UI Polish & Completion.

Obey the Mandatory Git Safety Header.

OBJECTIVE

Complete final QA and polish for the Step-by-Step Tutorial.

END-TO-END FLOWS TO VERIFY

A. Standard Recommendation
Selfie
→ Analysis
→ Recommendation
→ Gemini 3 Pro final preview
→ How to Apply This Look
→ dynamic tutorial
→ Placement/Result steps
→ saved/reopened tutorial

B. My Makeup Kit
Selfie
→ Analysis
→ My Makeup Kit
→ kit-aware recommendation
→ kit preview
→ How to Apply This Look
→ tutorial using owned products only
→ saved/reopened tutorial

VERIFY

1. Identity remains reasonably consistent throughout.
2. Makeup progression is cumulative.
3. Step N Placement uses the correct previous result.
4. Placement overlay matches the current category.
5. Step N Result contains previous makeup + current makeup.
6. Slider labels are Placement / Result.
7. Existing final preview remains Before / After.
8. Step count is dynamic.
9. Written instructions match the step.
10. Incomplete kits do not invent products.
11. Valid saved tutorials do not regenerate.
12. Final Pro preview is reused where appropriate.
13. Loading/error/partial states are understandable.
14. UI matches FaceTune visual language.
15. No existing core flow is broken.

POLISH

Only make scoped UI/UX improvements necessary for completion.

Do not add:
- video tutorials;
- AR;
- voice;
- unrelated new features.

VALIDATION

Run:
- dart format .
- flutter analyze
- relevant flutter tests
- configured Android debug build
- real-device E2E test if available

Do not fabricate results.

FINAL COMPLETION REPORT

FEATURE:
FaceTune Step-by-Step Tutorial

PHASE COMPLETED:
ST-14 — End-to-End QA, Final UI Polish & Completion

CURRENT BRANCH:
FULL FEATURE STATUS:
STANDARD MODE STATUS:
MY MAKEUP KIT STATUS:
IDENTITY CONSISTENCY:
CUMULATIVE MAKEUP:
PLACEMENT / RESULT:
CACHING / COST CONTROL:
SAVE / REOPEN:
SECURITY:
FILES CREATED:
FILES MODIFIED:
VALIDATION ACTUALLY RUN:
ANDROID BUILD:
DEVICE E2E:
REGRESSION RESULTS:
KNOWN LIMITATIONS:
MANUAL ACTIONS:
RECOMMENDATION BEFORE MERGING TO MAIN:

Then STOP and wait for the user to provide, select, or reference another ST phase. Do not ask whether to execute the next phase.
```

---

# Recommended Phase Sequence

```text
ST-1  Baseline Audit & Architecture Contract
ST-2  Supabase Schema, Storage & RLS
ST-3  Domain, Repository & State Foundation
ST-4  Entry Points & Navigation
ST-5  Tutorial Viewer & Placement/Result Slider UI
ST-6  Category-Specific Placement Overlay Engine
ST-7  Dynamic Tutorial Planning Engine
ST-8  Persistence, Cache & Duplicate Prevention
ST-9  Secure Tutorial Image Generation Backend
ST-10 Flutter Generation Orchestration & Progressive Loading
ST-11 Written Instruction Integration & Tutorial Accuracy
ST-12 Save, Reopen, History & Regenerate UX
ST-13 Resilience, Security, Cost & Performance Hardening
ST-14 End-to-End QA, Final UI Polish & Completion
```

---

# Branch Setup

Before beginning ST-1, create the feature branch from the current stable main branch:

```powershell
git switch main
git pull origin main
git switch -c feature/step-by-step-tutorial
git branch --show-current
git status
```

Expected active branch:

```text
feature/step-by-step-tutorial
```

Push the branch after the first appropriate checkpoint:

```powershell
git push -u origin feature/step-by-step-tutorial
```

Do not develop the tutorial directly on `main`.

---

# Suggested Commit Checkpoints

The user controls commits.

Example:

```powershell
git add .
git commit -m "feat(tutorial): complete ST-1 architecture foundation"
git push origin feature/step-by-step-tutorial
```

Repeat with an appropriate message after each successfully validated phase.

Do not commit known-broken work merely to satisfy the roadmap.
